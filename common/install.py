import hashlib
import json
import os
from pathlib import Path
import tarfile
import urllib.request
from settings import BASE, CONFIG, VERSIONS


def install(name, target, algorithm):
    spec = VERSIONS[name]
    archive = Path(BASE) / "tmp" / (name + "-" + spec[algorithm] + ".tar.gz")
    target = Path(target)
    marker = target / ".verified-install.json"
    if marker.exists():
        if json.loads(marker.read_text()) != spec:
            raise RuntimeError("Existing installation does not match versions.json")
        print(name + ": existing verified installation")
        return
    if target.is_symlink() or target.parent.is_symlink() or archive.is_symlink():
        raise RuntimeError("Participant runtime path contains a symlink")
    if target.exists() and any(target.iterdir()):
        raise RuntimeError("Incomplete installation requires inspection: " + str(target))
    if not archive.exists():
        partial = archive.with_suffix(".part")
        with urllib.request.urlopen(spec["url"], timeout=60) as source, partial.open("wb") as dest:
            while chunk := source.read(1024 * 1024):
                dest.write(chunk)
        partial.replace(archive)
    digest = hashlib.new(algorithm)
    with archive.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    if digest.hexdigest() != spec[algorithm]:
        raise RuntimeError("Checksum mismatch: " + str(archive))
    target.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as bundle:
        for member in bundle.getmembers():
            parts = Path(member.name).parts
            if not parts or member.name.startswith("/") or ".." in parts:
                raise RuntimeError("Unsafe archive entry")
            if len(parts) == 1:
                continue
            member.name = str(Path(*parts[1:]))
            if member.issym():
                link_target = (target / member.name).parent.joinpath(member.linkname).resolve()
                if not link_target.is_relative_to(target.resolve()):
                    raise RuntimeError("Archive symlink escapes target")
            if member.islnk():
                source_parts = Path(member.linkname).parts
                if len(source_parts) < 2 or ".." in source_parts:
                    raise RuntimeError("Unsafe archive hard link")
                member.linkname = str(Path(*source_parts[1:]))
            bundle.extract(member, target, filter="data")
    marker.write_text(json.dumps(spec, indent=2) + "\n")
    print(name + ": installed; checksum verified")


if __name__ == "__main__":
    import pwd
    if pwd.getpwuid(os.geteuid()).pw_name != CONFIG["linux_user"]:
        raise SystemExit("Run with sudo -iu dpe_ksenia")
    for directory in ("software", "tmp", "conf", "logs", "pids", "data"):
        if Path(BASE, directory).is_symlink():
            raise SystemExit("Participant path is a symlink: " + directory)
        Path(BASE, directory).mkdir(parents=True, exist_ok=True)
    install("java", BASE + "/software/java11", "sha256")
    install("hadoop", BASE + "/software/hadoop-" + VERSIONS["hadoop"]["version"], "sha512")

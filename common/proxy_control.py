import json
import os
from pathlib import Path
import pwd
import secrets
import signal
import socket
import subprocess
import sys
import time
from settings import BASE, CONFIG, ROOT, web_endpoints

private = Path(BASE) / "conf/hw2/web"
pidfile = Path(BASE) / "pids/hw2/web-proxy.pid"
readyfile = Path(BASE) / "pids/hw2/web-proxy.ready"


def check_pid(pid):
    proc = Path("/proc") / str(pid)
    if not proc.exists():
        return False
    try:
        status = (proc / "status").read_text()
        if "State:\tZ" in status:
            return False
        if proc.stat().st_uid != os.getuid() or str(ROOT / "common/proxy.py").encode() not in (proc / "cmdline").read_bytes():
            raise RuntimeError("PID belongs to another process; refusing to signal it")
    except FileNotFoundError:
        return False
    return True


def start():
    if pidfile.exists() and check_pid(int(pidfile.read_text())):
        raise RuntimeError("Proxy is already running")
    private.mkdir(parents=True, exist_ok=True, mode=0o700)
    credentials = private / "credentials.json"
    if credentials.is_symlink():
        raise RuntimeError("Credential path is a symlink")
    if not credentials.exists():
        credentials.write_text(json.dumps({"username": "dpe_ksenia", "password": secrets.token_urlsafe(24)}) + "\n")
        credentials.chmod(0o600)
    cert, key = private / "server.crt", private / "server.key"
    if cert.is_symlink() or key.is_symlink():
        raise RuntimeError("Certificate path is a symlink")
    if not cert.exists() or not key.exists():
        public = CONFIG["public_host"]
        import ipaddress
        try:
            ipaddress.ip_address(public)
            public_san = "IP:" + public
        except ValueError:
            public_san = "DNS:" + public
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-days", "7",
                        "-nodes", "-keyout", str(key), "-out", str(cert), "-subj", "/CN=ksenia-homework",
                        "-addext", "subjectAltName=" + public_san + ",DNS:localhost,IP:127.0.0.1"],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        key.chmod(0o600)
    logfile = Path(BASE) / "logs/hw2/web-proxy.log"
    readyfile.unlink(missing_ok=True)
    with logfile.open("ab") as output:
        child = subprocess.Popen([sys.executable, str(ROOT / "common/proxy.py")],
                                 stdout=output, stderr=output, start_new_session=True)
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if child.poll() is not None:
            raise RuntimeError("HTTPS proxy exited during startup; inspect " + str(logfile))
        if readyfile.exists() and readyfile.read_text().strip() == str(child.pid):
            break
        time.sleep(0.1)
    else:
        child.terminate()
        raise RuntimeError("HTTPS proxy did not bind every port; inspect " + str(logfile))
    pidfile.write_text(str(child.pid) + "\n")
    print("Proxy started; PID=" + str(child.pid))
    print("Credentials are stored locally in " + str(credentials))
    print("Trust certificate explicitly: " + str(cert))


def stop():
    if not pidfile.exists():
        print("Proxy is already stopped")
        return
    pid = int(pidfile.read_text())
    if check_pid(pid):
        os.kill(pid, signal.SIGTERM)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline and check_pid(pid):
            time.sleep(0.1)
        if check_pid(pid):
            raise RuntimeError("Proxy did not stop; PID file retained for review")
    deadline = time.monotonic() + 5
    while True:
        active = []
        for endpoint in web_endpoints().values():
            with socket.socket() as check:
                check.settimeout(0.3)
                if check.connect_ex(("127.0.0.1", endpoint["external_port"])) == 0:
                    active.append(endpoint["external_port"])
        if not active:
            break
        if time.monotonic() >= deadline:
            raise RuntimeError("HTTPS listener still active; PID file retained")
        time.sleep(0.1)
    pidfile.unlink()
    readyfile.unlink(missing_ok=True)
    print("Only the participant HTTPS proxy was stopped")


if __name__ == "__main__":
    if pwd.getpwuid(os.geteuid()).pw_name != CONFIG["linux_user"]:
        raise SystemExit("Run as dpe_ksenia")
    {"proxy-start": start, "proxy-stop": stop}[sys.argv[1]]()

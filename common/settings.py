import ipaddress
import json
import re
import shlex
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / "common/cluster.json").read_text())
VERSIONS = json.loads((ROOT / "common/versions.json").read_text())
BASE = CONFIG["base"]
PORTS = CONFIG["ports"]
NODES = CONFIG["nodes"]
DATA_ROLES = ("edge", "worker0", "worker1")


def validate():
    if (CONFIG["participant"], CONFIG["linux_user"], BASE) != (
        "ksenia", "dpe_ksenia", "/srv/dpe/ksenia"
    ):
        raise ValueError("This deployment is allocated to ksenia only")
    for node in NODES.values():
        if not re.fullmatch(r"[a-zA-Z0-9.-]+", node["host"]):
            raise ValueError("Invalid hostname")
        ipaddress.ip_address(node["ip"])
    if not re.fullmatch(r"[a-zA-Z0-9.-]+", CONFIG["public_host"]):
        raise ValueError("Invalid public hostname")
    fixed = list(PORTS.values()) + list(CONFIG["external_ports"].values())
    if len(fixed) != len(set(fixed)) or any(not 22000 <= p <= 22999 for p in fixed):
        raise ValueError("Duplicate port or port outside ksenia allocation")
    for name in ("am_rpc_range", "am_web_range"):
        low, high = map(int, CONFIG[name].split("-"))
        if not 22000 <= low <= high <= 22999 or any(low <= p <= high for p in fixed):
            raise ValueError("Invalid ApplicationMaster port range")


def web_endpoints():
    endpoints = {
        "namenode": ("namenode", "nn_http"),
        "secondarynamenode": ("edge", "snn_http"),
        "resourcemanager": ("edge", "rm_http"),
        "historyserver": ("edge", "history_http"),
        "webappproxy": ("edge", "web_proxy"),
    }
    for role in DATA_ROLES:
        endpoints["datanode_" + role] = (role, "dn_http")
        endpoints["nodemanager_" + role] = (role, "nm_http")
    return {
        name: {"role": role, "host": NODES[role]["host"] if name == "secondarynamenode" else NODES[role]["ip"],
               "port": PORTS[port], "external_port": CONFIG["external_ports"][name]}
        for name, (role, port) in endpoints.items()
    }


validate()
if __name__ == "__main__":
    exports = {"DPE_BASE": BASE, "DPE_USER": CONFIG["linux_user"],
               "DPE_NAME": CONFIG["participant"]}
    for role, node in NODES.items():
        exports[role.upper() + "_HOST"] = node["host"]
    for name, value in exports.items():
        print("export " + name + "=" + shlex.quote(value))

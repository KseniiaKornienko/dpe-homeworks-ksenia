from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "common"))

from install import install
from settings import BASE, VERSIONS

install("hive", BASE + "/software/hive-" + VERSIONS["hive"]["version"], "sha256")
install("derby", BASE + "/software/derby-" + VERSIONS["derby"]["version"], "sha256")

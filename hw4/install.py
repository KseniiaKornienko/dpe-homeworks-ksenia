from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "common"))

from install import install
from settings import BASE, VERSIONS

install("spark", BASE + "/software/spark-" + VERSIONS["spark"]["version"], "sha512")
install("hive", BASE + "/software/hive-" + VERSIONS["hive"]["version"], "sha256")

#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
action=${1:?start or stop}
case "$action" in
  start|stop) exec bash "$ROOT/common/cluster.sh" "hdfs-$action" ;;
  *) echo 'Usage on edge: hdfs.sh start|stop' >&2; exit 2 ;;
esac

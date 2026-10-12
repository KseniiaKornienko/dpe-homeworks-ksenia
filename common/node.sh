#!/usr/bin/env bash
set -euo pipefail
COMMON=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
eval "$(python3 "$COMMON/settings.py")"
[[ $(id -un) == "$DPE_USER" ]] || { echo "Run as $DPE_USER" >&2; exit 1; }
[[ ! -L "$DPE_BASE" && $(stat -c %U "$DPE_BASE") == "$DPE_USER" ]] || exit 1
action=${1:?Action required}; shift

if [[ "$action" == install ]]; then
  python3 "$COMMON/install.py"
  exit
fi
if [[ "$action" == configure ]]; then
  role=${1:?Node role required}
  for hw in hw1 hw2; do
    for parent in conf logs pids tmp data; do
      [[ ! -L "$DPE_BASE/$parent" && ! -L "$DPE_BASE/$parent/$hw" ]] || exit 1
      install -d -m 700 "$DPE_BASE/$parent/$hw"
    done
  done
  python3 "$COMMON/render.py" "$role"
  exit
fi

hw=${1:?Homework scope required}; shift
[[ "$hw" == hw1 || "$hw" == hw2 ]] || exit 1
source "$DPE_BASE/conf/$hw/hadoop-env.sh"

if [[ "$action" == format ]]; then
  [[ "$hw" == hw1 && $(hostname -s) == "$NAMENODE_HOST" ]] || exit 1
  target=$DPE_BASE/data/hw1/namenode
  configured=$("$HADOOP_HOME/bin/hdfs" getconf -confKey dfs.namenode.name.dir)
  [[ "$configured" == "file://$target" && ! -L "$target" ]] || exit 1
  printf 'FORMAT TARGET=%s OWNER=%s CONF=%s\n' "$target" "$DPE_USER" "$HADOOP_CONF_DIR"
  if [[ -f "$target/current/VERSION" ]]; then
    echo "NameNode already formatted; preserving storage"
    exit
  fi
  [[ ! -d "$target" || -z $(ls -A "$target") ]] || { echo "Nonempty storage; refusing format" >&2; exit 1; }
  "$HADOOP_HOME/bin/hdfs" namenode -format -clusterid CID-dpe-ksenia-hw1 -nonInteractive
elif [[ "$action" == daemon ]]; then
  operation=${1:?start or stop}; family=${2:?hdfs, yarn or mapred}; daemon=${3:?daemon name}
  [[ "$operation" == start || "$operation" == stop ]] || exit 1
  case "$family:$daemon" in
    hdfs:namenode|hdfs:datanode|hdfs:secondarynamenode) [[ "$hw" == hw1 ]] || exit 1 ;;
    yarn:resourcemanager|yarn:nodemanager|yarn:proxyserver|mapred:historyserver) [[ "$hw" == hw2 ]] || exit 1 ;;
    *) echo "Daemon is not allowed" >&2; exit 1 ;;
  esac
  case "$family:$daemon" in
    hdfs:namenode) class=org.apache.hadoop.hdfs.server.namenode.NameNode ;;
    hdfs:datanode) class=org.apache.hadoop.hdfs.server.datanode.DataNode ;;
    hdfs:secondarynamenode) class=org.apache.hadoop.hdfs.server.namenode.SecondaryNameNode ;;
    yarn:resourcemanager) class=org.apache.hadoop.yarn.server.resourcemanager.ResourceManager ;;
    yarn:nodemanager) class=org.apache.hadoop.yarn.server.nodemanager.NodeManager ;;
    yarn:proxyserver) class=org.apache.hadoop.yarn.server.webproxy.WebAppProxyServer ;;
    mapred:historyserver) class=org.apache.hadoop.mapreduce.v2.hs.JobHistoryServer ;;
  esac
  for pidfile in "$HADOOP_PID_DIR"/*"-$daemon.pid"; do
    [[ -f "$pidfile" ]] || continue
    pid=$(cat "$pidfile")
    [[ "$pid" =~ ^[0-9]+$ ]] || exit 1
    if [[ -d /proc/$pid ]]; then
      [[ $(stat -c %U "/proc/$pid") == "$DPE_USER" ]] || exit 1
      cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
      [[ "$cmdline" == *"$DPE_BASE/software/java11/bin/java"* &&
         "$cmdline" == *"-Djava.io.tmpdir=$DPE_BASE/tmp/$hw"* &&
         "$cmdline" == *"$class"* ]] || exit 1
    fi
  done
  "$HADOOP_HOME/bin/$family" --daemon "$operation" "$daemon"
elif [[ "$action" == exec ]]; then
  command=${1:?hdfs, yarn or hadoop}; shift
  [[ "$command" == hdfs || "$command" == yarn || "$command" == hadoop ]] || exit 1
  "$HADOOP_HOME/bin/$command" "$@"
else
  echo "Unknown node action: $action" >&2
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
eval "$(python3 "$ROOT/common/settings.py")"
ALL_ROLES=(edge namenode worker0 worker1)
ALL_HOSTS=("$EDGE_HOST" "$NAMENODE_HOST" "$WORKER0_HOST" "$WORKER1_HOST")
DATA_HOSTS=("$EDGE_HOST" "$WORKER0_HOST" "$WORKER1_HOST")
[[ $(hostname -s) == "$EDGE_HOST" ]] || { echo "Run on edge $EDGE_HOST" >&2; exit 1; }
[[ $(id -un) == team ]] || { echo "Administrative controller must run as team" >&2; exit 1; }

quote() { printf '%q ' "$@"; }
node() {
  local host=$1; shift
  if [[ "$host" == "$EDGE_HOST" ]]; then
    bash -c "$1"
  else
    ssh -i /home/team/.ssh/team_internal -o BatchMode=yes -o StrictHostKeyChecking=yes "team@$host" "$1"
  fi
}
participant() {
  local host=$1; shift
  node "$host" "sudo -iu $DPE_USER bash $(quote "$DPE_BASE/homeworks/common/node.sh" "$@")"
}
check_ports() {
  local host=$1 low=${2:-22000} high=${3:-22999}
  node "$host" "python3 -c $(quote 'import subprocess,re,sys; low=int(sys.argv[1]); high=int(sys.argv[2]); s=subprocess.check_output(["ss","-ltnH"],text=True); conflicts=[x for x in s.splitlines() if any(low <= int(p) <= high for p in re.findall(r":([0-9]{2,5})(?:\s|$)",x))]; print("\n".join(conflicts) or "Requested port band is free"); sys.exit(bool(conflicts))') $low $high"
}
action=${1:-check}
case "$action" in
  check)
    for host in "${ALL_HOSTS[@]}"; do
      node "$host" 'hostname; free -m; df -h /srv; getent passwd dpe_ksenia || true'
      check_ports "$host"
    done
    ;;
  setup)
    for i in "${!ALL_HOSTS[@]}"; do
      host=${ALL_HOSTS[$i]}
      node "$host" "sudo bash -s -- $DPE_USER $DPE_BASE" <<'SETUP'
set -euo pipefail
participant_user=$1; participant_base=$2
[[ "$participant_user" == dpe_ksenia && "$participant_base" == /srv/dpe/ksenia ]] || exit 1
[[ ! -L "$participant_base" ]] || exit 1
if ! id "$participant_user" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$participant_user"
fi
if [[ -e "$participant_base" && $(stat -c %U "$participant_base") != "$participant_user" ]]; then
  echo 'Existing base belongs to someone else' >&2; exit 1
fi
for path in "$participant_base" "$participant_base"/{homeworks,conf,logs,pids,tmp,data,bin,software} "$participant_base/homeworks"/{common,hw1,hw2,hw4}; do
  [[ ! -L "$path" ]] || { echo "Symlink in participant path: $path" >&2; exit 1; }
done
install -d -o "$participant_user" -g "$participant_user" -m 755 "$participant_base" "$participant_base/homeworks"
for dir in conf logs pids tmp data bin software; do
  install -d -o "$participant_user" -g "$participant_user" -m 700 "$participant_base/$dir"
done
participant_home=$(getent passwd "$participant_user" | cut -d: -f6)
[[ -d "$participant_home" && ! -L "$participant_home" && $(stat -c %U "$participant_home") == "$participant_user" ]] || exit 1
[[ ! -L "$participant_home/.dpe_env" && ! -L "$participant_home/.bashrc" ]] || exit 1
if [[ ! -e "$participant_home/.dpe_env" ]]; then
  cat > "$participant_home/.dpe_env" <<'ENV'
export DPE_NAME=ksenia
export DPE_BASE=/srv/dpe/ksenia
export DPE_CONF_DIR=/srv/dpe/ksenia/conf
export DPE_LOG_DIR=/srv/dpe/ksenia/logs
export DPE_PID_DIR=/srv/dpe/ksenia/pids
export DPE_TMP_DIR=/srv/dpe/ksenia/tmp
export DPE_DATA_DIR=/srv/dpe/ksenia/data
export DPE_HOMEWORK_DIR=/srv/dpe/ksenia/homeworks
ENV
  chown "$participant_user:$participant_user" "$participant_home/.dpe_env"
  chmod 600 "$participant_home/.dpe_env"
fi
if ! grep -qxF 'source ~/.dpe_env' "$participant_home/.bashrc"; then
  printf '\nsource ~/.dpe_env\n' >> "$participant_home/.bashrc"
fi
SETUP
      if [[ "$host" != "$EDGE_HOST" ]]; then
        tar -C "$ROOT" --exclude='__pycache__' --exclude='*.pyc' -cf - common hw1 hw2 hw4 README.md | \
          node "$host" "sudo -u $DPE_USER tar -xf - -C $DPE_BASE/homeworks"
      fi
      participant "$host" install
      participant "$host" configure "${ALL_ROLES[$i]}"
    done
    ;;
  hdfs-start)
    for host in "${ALL_HOSTS[@]}"; do check_ports "$host"; done
    participant "$NAMENODE_HOST" format hw1
    participant "$NAMENODE_HOST" daemon hw1 start hdfs namenode
    for host in "${DATA_HOSTS[@]}"; do participant "$host" daemon hw1 start hdfs datanode; done
    participant "$EDGE_HOST" daemon hw1 start hdfs secondarynamenode
    ;;
  hdfs-stop)
    participant "$EDGE_HOST" daemon hw1 stop hdfs secondarynamenode
    for host in "${DATA_HOSTS[@]}"; do participant "$host" daemon hw1 stop hdfs datanode; done
    participant "$NAMENODE_HOST" daemon hw1 stop hdfs namenode
    ;;
  yarn-start)
    for host in "${ALL_HOSTS[@]}"; do check_ports "$host" 22100 22299; done
    participant "$EDGE_HOST" exec hw2 hdfs dfs -mkdir -p \
      /user/dpe_ksenia/hw2/history/done /user/dpe_ksenia/hw2/history/intermediate \
      /user/dpe_ksenia/hw2/staging /user/dpe_ksenia/hw2/app-logs
    participant "$EDGE_HOST" daemon hw2 start yarn resourcemanager
    for host in "${DATA_HOSTS[@]}"; do participant "$host" daemon hw2 start yarn nodemanager; done
    participant "$EDGE_HOST" daemon hw2 start mapred historyserver
    participant "$EDGE_HOST" daemon hw2 start yarn proxyserver
    ;;
  yarn-stop)
    participant "$EDGE_HOST" daemon hw2 stop yarn proxyserver
    participant "$EDGE_HOST" daemon hw2 stop mapred historyserver
    for host in "${DATA_HOSTS[@]}"; do participant "$host" daemon hw2 stop yarn nodemanager; done
    participant "$EDGE_HOST" daemon hw2 stop yarn resourcemanager
    ;;
  hw4-run)
    node "$EDGE_HOST" "sudo -iu $DPE_USER bash $DPE_BASE/homeworks/hw4/run.sh"
    ;;
  proxy-start|proxy-stop)
    node "$EDGE_HOST" "sudo -iu $DPE_USER python3 $DPE_BASE/homeworks/common/proxy_control.py $action"
    ;;
  *) echo 'Actions: check setup hdfs-start yarn-start hw4-run proxy-start proxy-stop yarn-stop hdfs-stop' >&2; exit 2 ;;
esac

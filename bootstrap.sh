#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
eval "$(python3 "$ROOT/common/settings.py")"
KEY=${DPE_SSH_KEY:-$HOME/.ssh/mts_course}
KNOWN_HOSTS=${DPE_KNOWN_HOSTS:-$ROOT/common/known_hosts}
PUBLIC_HOST=$(python3 -c 'import sys; sys.path.insert(0,sys.argv[1]); from settings import CONFIG; print(CONFIG["public_host"])' "$ROOT/common")
SSH_ARGS=(-i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$KNOWN_HOSTS")
action=${1:-check}
case "$action" in
  check)
    ssh "${SSH_ARGS[@]}" "team@$PUBLIC_HOST" 'hostname; id; sudo -n true'
    ;;
  setup)
    ssh "${SSH_ARGS[@]}" "team@$PUBLIC_HOST" 'sudo bash -s' <<'SETUP'
set -euo pipefail
participant_user=dpe_ksenia
participant_base=/srv/dpe/ksenia
[[ ! -L "$participant_base" ]] || exit 1
if ! id "$participant_user" >/dev/null 2>&1; then useradd -m -s /bin/bash "$participant_user"; fi
if [[ -e "$participant_base" && $(stat -c %U "$participant_base") != "$participant_user" ]]; then exit 1; fi
[[ ! -L "$participant_base/homeworks" ]] || exit 1
for component in common hw1 hw2; do
  [[ ! -L "$participant_base/homeworks/$component" ]] || exit 1
done
install -d -o "$participant_user" -g "$participant_user" -m 755 "$participant_base" "$participant_base/homeworks"
SETUP
    tar -C "$ROOT" --exclude='__pycache__' --exclude='*.pyc' -cf - common hw1 hw2 README.md | \
      ssh "${SSH_ARGS[@]}" "team@$PUBLIC_HOST" 'sudo -u dpe_ksenia tar -xf - -C /srv/dpe/ksenia/homeworks'
    ssh "${SSH_ARGS[@]}" "team@$PUBLIC_HOST" 'bash /srv/dpe/ksenia/homeworks/common/cluster.sh setup'
    ;;
  run)
    action=${2:?Controller action required}
    [[ "$action" =~ ^[a-z-]+$ ]] || exit 1
    ssh "${SSH_ARGS[@]}" "team@$PUBLIC_HOST" "bash /srv/dpe/ksenia/homeworks/common/cluster.sh $action"
    ;;
  tunnel)
    TUNNEL_ARGS=()
    while IFS= read -r port; do
      TUNNEL_ARGS+=(-L "127.0.0.1:$port:127.0.0.1:$port")
    done < <(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from settings import CONFIG; print(*sorted(CONFIG["external_ports"].values()), sep="\n")' "$ROOT/common")
    ssh "${SSH_ARGS[@]}" -N -o ExitOnForwardFailure=yes "${TUNNEL_ARGS[@]}" "team@$PUBLIC_HOST"
    ;;
  *) echo 'Usage: bash bootstrap.sh check | setup | run <action> | tunnel' >&2; exit 2 ;;
esac

#!/usr/bin/env bash
# spawn-and-install.sh — Ensure an expert exists locally, register it, then invoke it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

AGENCY_DEST="${AGENCY_DEST:-${HOME}/.openclaw/agency-agents}"
CONFIG_PATH="$(openclaw_config_path)"
TIMEOUT=300
TMP_DIR=""
STAGE_DIR=""

usage() {
  cat <<'EOF'
Usage: ./scripts/spawn-and-install.sh <agent-id> <task> [--timeout N]

Examples:
  ./scripts/spawn-and-install.sh engineering-code-reviewer "Review this repo"
  ./scripts/spawn-and-install.sh marketing-content-creator "Draft 3 post ideas" --timeout 600
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

[[ $# -ge 2 ]] || { usage >&2; exit 1; }
AGENT_ID="$1"
shift
TASK="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! "$AGENT_ID" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  error "Invalid agent ID: $AGENT_ID"
  exit 1
fi
if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  error "--timeout must be an integer number of seconds"
  exit 1
fi

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

require_cmd openclaw python3 git
ensure_openclaw_config_exists
mkdir -p "$AGENCY_DEST"
AGENCY_DEST="$(expand_path "$AGENCY_DEST")"
CONFIG_PATH="$(expand_path "$CONFIG_PATH")"
TMP_DIR="$(mktemp -d)"
STAGE_DIR="$TMP_DIR/generated"
mkdir -p "$STAGE_DIR"

is_healthy_install() {
  python3 - "$CONFIG_PATH" "$AGENCY_DEST" "$AGENT_ID" <<'PYEOF'
import json, os, sys
from pathlib import Path
config_path = Path(sys.argv[1])
agency_dest = Path(sys.argv[2]).resolve()
agent_id = sys.argv[3]
expected = str((agency_dest / agent_id).resolve())
agent_md = agency_dest / agent_id / 'AGENTS.md'
if not agent_md.is_file():
    raise SystemExit(1)
with config_path.open('r', encoding='utf-8') as f:
    config = json.load(f)
agent_list = config.get('agents', {}).get('list', [])
entry = next((item for item in agent_list if isinstance(item, dict) and item.get('id') == agent_id), None)
if entry is None:
    raise SystemExit(1)
workspace = entry.get('workspace')
if not isinstance(workspace, str):
    raise SystemExit(1)
resolved = str(Path(os.path.expanduser(workspace)).resolve())
raise SystemExit(0 if resolved == expected else 1)
PYEOF
}

sync_target_agent() {
  header "Agent missing or unhealthy — fetching staged upstream snapshot"
  AGENCY_DEST="$STAGE_DIR" "$SCRIPT_DIR/convert.sh"

  python3 "$SCRIPT_DIR/sync_stage_to_workspace.py" \
    --current "$AGENCY_DEST" \
    --stage "$STAGE_DIR" \
    --agent "$AGENT_ID"

  header "Sync config"
  python3 "$SCRIPT_DIR/sync_openclaw_config.py" \
    --agency-dest "$AGENCY_DEST" \
    --config "$CONFIG_PATH" \
    --agent "$AGENT_ID" \
    --backup

  header "Restart gateway"
  restart_gateway_and_wait || true
}

header "=== agencyteam spawn-and-install ==="
info "Agent: $AGENT_ID"
info "Config: $CONFIG_PATH"

if is_healthy_install; then
  info "Agent already installed, registered, and healthy"
else
  sync_target_agent
fi

header "Invoke agent"
openclaw agent --agent "$AGENT_ID" --message "$TASK" --timeout "$TIMEOUT"

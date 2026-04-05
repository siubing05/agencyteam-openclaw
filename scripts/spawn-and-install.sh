#!/usr/bin/env bash
# spawn-and-install.sh — Ensure an expert exists locally, register it, then invoke it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

AGENCY_DEST="${AGENCY_DEST:-${HOME}/.openclaw/agency-agents}"
CONFIG_PATH="$(openclaw_config_path)"
TIMEOUT=300

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

require_cmd openclaw python3 git
ensure_openclaw_config_exists
mkdir -p "$AGENCY_DEST"
AGENCY_DEST="$(expand_path "$AGENCY_DEST")"
CONFIG_PATH="$(expand_path "$CONFIG_PATH")"

is_registered() {
  python3 - "$CONFIG_PATH" "$AGENT_ID" <<'PYEOF'
import json, sys
from pathlib import Path
config_path = Path(sys.argv[1])
agent_id = sys.argv[2]
with config_path.open("r", encoding="utf-8") as f:
    config = json.load(f)
agent_list = config.get("agents", {}).get("list", [])
ids = {entry.get("id") for entry in agent_list if isinstance(entry, dict)}
raise SystemExit(0 if agent_id in ids else 1)
PYEOF
}

header "=== agencyteam spawn-and-install ==="
info "Agent: $AGENT_ID"
info "Config: $CONFIG_PATH"

if ! is_registered || [[ ! -d "$AGENCY_DEST/$AGENT_ID" ]]; then
  header "Agent missing locally — fetching upstream snapshot"
  AGENCY_DEST="$AGENCY_DEST" "$SCRIPT_DIR/convert.sh"

  if [[ ! -d "$AGENCY_DEST/$AGENT_ID" ]]; then
    error "Agent not found upstream after conversion: $AGENT_ID"
    exit 1
  fi

  header "Sync config"
  python3 "$SCRIPT_DIR/sync_openclaw_config.py" \
    --agency-dest "$AGENCY_DEST" \
    --config "$CONFIG_PATH" \
    --agent "$AGENT_ID" \
    --backup

  header "Restart gateway"
  restart_gateway_and_wait || true
else
  info "Agent already installed and registered"
fi

header "Invoke agent"
openclaw agent --agent "$AGENT_ID" --message "$TASK" --timeout "$TIMEOUT"

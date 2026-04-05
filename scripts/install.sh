#!/usr/bin/env bash
# install.sh — Install and register agencyteam-managed experts for OpenClaw.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

AGENCY_DEST="${AGENCY_DEST:-${HOME}/.openclaw/agency-agents}"
CONFIG_PATH="$(openclaw_config_path)"
INSTALL_ALL=true
REQUESTED_IDS=()

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [OPTIONS]

Options:
  --all                 Install/register all converted agents (default)
  --agents "ID ..."     Install/register only the listed agent IDs
  --help                Show this help

Environment:
  AGENCY_DEST           Destination for generated workspaces (default: ~/.openclaw/agency-agents)
  OPENCLAW_CONFIG_PATH  Override openclaw.json path for testing
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      INSTALL_ALL=true
      shift
      ;;
    --agents)
      INSTALL_ALL=false
      read -r -a REQUESTED_IDS <<< "${2:-}"
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

if [[ "$INSTALL_ALL" == false && ${#REQUESTED_IDS[@]} -eq 0 ]]; then
  error "--agents requires at least one agent ID"
  exit 1
fi

require_cmd openclaw python3 git
ensure_openclaw_config_exists
mkdir -p "$AGENCY_DEST"
AGENCY_DEST="$(expand_path "$AGENCY_DEST")"
CONFIG_PATH="$(expand_path "$CONFIG_PATH")"

step_convert() {
  header "Step 1: Fetch + convert upstream experts"
  info "Skill dir: $SKILL_DIR"
  info "Output: $AGENCY_DEST"
  AGENCY_DEST="$AGENCY_DEST" "$SCRIPT_DIR/convert.sh"
}

step_register() {
  header "Step 2: Sync agents.list"
  local args=(--agency-dest "$AGENCY_DEST" --config "$CONFIG_PATH" --backup)

  if [[ "$INSTALL_ALL" == true ]]; then
    args+=(--prune-missing)
  else
    local agent_id
    for agent_id in "${REQUESTED_IDS[@]}"; do
      args+=(--agent "$agent_id")
    done
  fi

  python3 "$SCRIPT_DIR/sync_openclaw_config.py" "${args[@]}"
}

step_restart() {
  header "Step 3: Restart gateway"
  restart_gateway_and_wait || true
}

main() {
  header "=== agencyteam installer ==="
  info "Config: $CONFIG_PATH"
  info "Workspace root: $AGENCY_DEST"
  if [[ "$INSTALL_ALL" == false ]]; then
    info "Requested IDs: ${REQUESTED_IDS[*]}"
  fi

  step_convert
  step_register
  step_restart

  header "Install complete"
  info "List agents: openclaw agents list"
  info "Verify config: openclaw gateway status"
}

main "$@"

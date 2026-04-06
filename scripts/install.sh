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
TMP_DIR=""
STAGE_DIR=""
WORKSPACE_SYNC_SUMMARY=""

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
WORKSPACE_SYNC_SUMMARY="$TMP_DIR/workspace-sync.json"
mkdir -p "$STAGE_DIR"

step_stage() {
  header "Step 1: Build staged upstream snapshot"
  info "Skill dir: $SKILL_DIR"
  info "Stage: $STAGE_DIR"
  AGENCY_DEST="$STAGE_DIR" "$SCRIPT_DIR/convert.sh"
}

step_sync_workspace() {
  header "Step 2: Sync staged workspaces into destination"
  local args=(--current "$AGENCY_DEST" --stage "$STAGE_DIR" --summary-json "$WORKSPACE_SYNC_SUMMARY")

  if [[ "$INSTALL_ALL" == true ]]; then
    args+=(--prune-managed-missing)
  else
    local agent_id
    for agent_id in "${REQUESTED_IDS[@]}"; do
      args+=(--agent "$agent_id")
    done
  fi

  python3 "$SCRIPT_DIR/sync_stage_to_workspace.py" "${args[@]}"
}

step_register() {
  header "Step 3: Sync agents.list"
  local args=(--agency-dest "$AGENCY_DEST" --config "$CONFIG_PATH" --backup)
  local selected_ids=()
  local removed_ids=()
  mapfile -t selected_ids < <(python3 - "$WORKSPACE_SYNC_SUMMARY" <<'PYEOF'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for item in data.get('selected', []):
    print(item)
PYEOF
)
  mapfile -t removed_ids < <(python3 - "$WORKSPACE_SYNC_SUMMARY" <<'PYEOF'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for item in data.get('pruned', []):
    print(item)
PYEOF
)

  local agent_id
  for agent_id in "${selected_ids[@]}"; do
    args+=(--agent "$agent_id")
  done
  for agent_id in "${removed_ids[@]}"; do
    args+=(--remove-agent "$agent_id")
  done

  python3 "$SCRIPT_DIR/sync_openclaw_config.py" "${args[@]}"
}

step_restart() {
  header "Step 4: Restart gateway"
  restart_gateway_and_wait || true
}

main() {
  header "=== agencyteam installer ==="
  info "Config: $CONFIG_PATH"
  info "Workspace root: $AGENCY_DEST"
  if [[ "$INSTALL_ALL" == false ]]; then
    info "Requested IDs: ${REQUESTED_IDS[*]}"
  fi

  step_stage
  step_sync_workspace
  step_register
  step_restart

  header "Install complete"
  info "List agents: openclaw agents list"
  info "Verify config: openclaw gateway status"
}

main "$@"

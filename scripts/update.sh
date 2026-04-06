#!/usr/bin/env bash
# update.sh — Refresh agencyteam-managed experts from upstream.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

AGENCY_DEST="${AGENCY_DEST:-${HOME}/.openclaw/agency-agents}"
CONFIG_PATH="$(openclaw_config_path)"
DRY_RUN=false
PRUNE_REMOVED=false
TMP_DIR=""
STAGE_DIR=""
WORKSPACE_SYNC_SUMMARY=""

usage() {
  cat <<'EOF'
Usage: ./scripts/update.sh [OPTIONS]

Options:
  --dry-run         Show what would change without writing files or config
  --prune-removed   Remove managed agent workspaces/config entries no longer present upstream
  --help            Show this help

Environment:
  AGENCY_DEST               Destination for generated workspaces (default: ~/.openclaw/agency-agents)
  OPENCLAW_CONFIG_PATH      Override openclaw.json path for testing
  AGENCYTEAM_UPSTREAM_REF   Override upstream ref (branch/tag/commit-ish)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --prune-removed)
      PRUNE_REMOVED=true
      shift
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

header "=== agencyteam update ==="
info "Config: $CONFIG_PATH"
info "Workspace root: $AGENCY_DEST"
info "Prune removed: $PRUNE_REMOVED"

header "Step 1: Build staged upstream snapshot"
AGENCY_DEST="$STAGE_DIR" "$SCRIPT_DIR/convert.sh"

header "Step 2: Compare staged snapshot vs current workspace"
COMPARE_OUT="$TMP_DIR/compare.json"
python3 - "$AGENCY_DEST" "$STAGE_DIR" "$PRUNE_REMOVED" "$COMPARE_OUT" <<'PYEOF'
import json, sys
from pathlib import Path

MARKER = 'AGENCYTEAM_MANAGED'
current = Path(sys.argv[1])
stage = Path(sys.argv[2])
prune_removed = sys.argv[3].lower() == 'true'
out_path = Path(sys.argv[4])


def load_map(root: Path):
    mapping = {}
    if not root.exists():
        return mapping
    for child in root.iterdir():
        if not child.is_dir():
            continue
        agents_md = child / 'AGENTS.md'
        text = agents_md.read_text(encoding='utf-8') if agents_md.exists() else ''
        mapping[child.name] = {
            'text': text,
            'managed': (child / MARKER).is_file(),
        }
    return mapping

current_map = load_map(current)
stage_map = load_map(stage)
current_ids = set(current_map)
stage_ids = set(stage_map)
managed_current_ids = {agent_id for agent_id, meta in current_map.items() if meta['managed']}
new_ids = sorted(stage_ids - current_ids)
removed_ids = sorted(managed_current_ids - stage_ids)
changed_ids = sorted(x for x in stage_ids & current_ids if stage_map[x]['text'] != current_map[x]['text'])
unchanged_ids = sorted(x for x in stage_ids & current_ids if stage_map[x]['text'] == current_map[x]['text'])
unmanaged_extra_ids = sorted((current_ids - stage_ids) - managed_current_ids)

summary = {
    'new': new_ids,
    'changed': changed_ids,
    'unchanged': unchanged_ids,
    'removed': removed_ids,
    'unmanagedExtra': unmanaged_extra_ids,
    'pruneRemoved': prune_removed,
}
out_path.write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(f"New: {len(new_ids)}  Changed: {len(changed_ids)}  Unchanged: {len(unchanged_ids)}  Removed upstream: {len(removed_ids)}")
if new_ids:
    print('New IDs: ' + ', '.join(new_ids[:20]) + (' ...' if len(new_ids) > 20 else ''))
if changed_ids:
    print('Changed IDs: ' + ', '.join(changed_ids[:20]) + (' ...' if len(changed_ids) > 20 else ''))
if removed_ids:
    suffix = ' (will be pruned)' if prune_removed else ' (left untouched unless --prune-removed)'
    print('Removed managed IDs: ' + ', '.join(removed_ids[:20]) + (' ...' if len(removed_ids) > 20 else '') + suffix)
if unmanaged_extra_ids:
    print('Unmanaged dirs left untouched: ' + ', '.join(unmanaged_extra_ids[:20]) + (' ...' if len(unmanaged_extra_ids) > 20 else ''))
PYEOF

if [[ "$DRY_RUN" == true ]]; then
  header "Step 3: Dry-run config sync"
  python3 - "$CONFIG_PATH" "$AGENCY_DEST" "$STAGE_DIR" "$COMPARE_OUT" "$PRUNE_REMOVED" <<'PYEOF'
import json, sys
from pathlib import Path

config_path = Path(sys.argv[1])
agency_dest = Path(sys.argv[2]).resolve()
stage_dir = Path(sys.argv[3]).resolve()
compare_out = Path(sys.argv[4])
prune_removed = sys.argv[5].lower() == 'true'

with config_path.open('r', encoding='utf-8') as f:
    config = json.load(f)
with compare_out.open('r', encoding='utf-8') as f:
    compare = json.load(f)

agent_list = config.get('agents', {}).get('list', [])
existing_by_id = {entry.get('id'): entry for entry in agent_list if isinstance(entry, dict) and entry.get('id')}
stage_ids = sorted(child.name for child in stage_dir.iterdir() if child.is_dir())
pruned_ids = set(compare.get('removed', [])) if prune_removed else set()

would_add = 0
would_update = 0
for agent_id in stage_ids:
    target_ws = str((agency_dest / agent_id).resolve())
    entry = existing_by_id.get(agent_id)
    if entry is None:
        would_add += 1
    elif entry.get('workspace') != target_ws or entry.get('model') is None:
        would_update += 1

would_remove = sum(1 for agent_id in pruned_ids if agent_id in existing_by_id)

print(f"Would add: {would_add}  Would update: {would_update}  Would remove: {would_remove}")
PYEOF
  header "Dry run complete"
  exit 0
fi

header "Step 3: Apply workspace updates"
SYNC_ARGS=(--current "$AGENCY_DEST" --stage "$STAGE_DIR" --summary-json "$WORKSPACE_SYNC_SUMMARY")
if [[ "$PRUNE_REMOVED" == true ]]; then
  SYNC_ARGS+=(--prune-managed-missing)
fi
python3 "$SCRIPT_DIR/sync_stage_to_workspace.py" "${SYNC_ARGS[@]}"
info "Workspace files refreshed"

header "Step 4: Sync agents.list"
SYNC_ARGS=(--agency-dest "$AGENCY_DEST" --config "$CONFIG_PATH" --backup)
mapfile -t STAGED_IDS < <(python3 - "$WORKSPACE_SYNC_SUMMARY" <<'PYEOF'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for item in data.get('selected', []):
    print(item)
PYEOF
)
mapfile -t PRUNED_IDS < <(python3 - "$WORKSPACE_SYNC_SUMMARY" <<'PYEOF'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for item in data.get('pruned', []):
    print(item)
PYEOF
)
for agent_id in "${STAGED_IDS[@]}"; do
  SYNC_ARGS+=(--agent "$agent_id")
done
for agent_id in "${PRUNED_IDS[@]}"; do
  SYNC_ARGS+=(--remove-agent "$agent_id")
done
python3 "$SCRIPT_DIR/sync_openclaw_config.py" "${SYNC_ARGS[@]}"

header "Step 5: Restart gateway"
restart_gateway_and_wait || true

header "Update complete"
info "Tip: run ./scripts/update.sh --dry-run before the next live update"

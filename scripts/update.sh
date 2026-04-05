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
import json, os, sys
from pathlib import Path

current = Path(sys.argv[1])
stage = Path(sys.argv[2])
prune_removed = sys.argv[3].lower() == "true"
out_path = Path(sys.argv[4])


def load_map(root: Path):
    mapping = {}
    if not root.exists():
        return mapping
    for child in root.iterdir():
        if not child.is_dir():
            continue
        agents_md = child / "AGENTS.md"
        text = agents_md.read_text(encoding="utf-8") if agents_md.exists() else ""
        mapping[child.name] = text
    return mapping

current_map = load_map(current)
stage_map = load_map(stage)
current_ids = set(current_map)
stage_ids = set(stage_map)
new_ids = sorted(stage_ids - current_ids)
removed_ids = sorted(current_ids - stage_ids)
changed_ids = sorted(x for x in stage_ids & current_ids if stage_map[x] != current_map[x])
unchanged_ids = sorted(x for x in stage_ids & current_ids if stage_map[x] == current_map[x])

summary = {
    "new": new_ids,
    "changed": changed_ids,
    "unchanged": unchanged_ids,
    "removed": removed_ids,
    "pruneRemoved": prune_removed,
}
out_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(f"New: {len(new_ids)}  Changed: {len(changed_ids)}  Unchanged: {len(unchanged_ids)}  Removed upstream: {len(removed_ids)}")
if new_ids:
    print("New IDs: " + ", ".join(new_ids[:20]) + (" ..." if len(new_ids) > 20 else ""))
if changed_ids:
    print("Changed IDs: " + ", ".join(changed_ids[:20]) + (" ..." if len(changed_ids) > 20 else ""))
if removed_ids:
    suffix = " (will be pruned)" if prune_removed else " (left untouched unless --prune-removed)"
    print("Removed upstream IDs: " + ", ".join(removed_ids[:20]) + (" ..." if len(removed_ids) > 20 else "") + suffix)
PYEOF

if [[ "$DRY_RUN" == true ]]; then
  header "Step 3: Dry-run config sync"
  python3 - "$CONFIG_PATH" "$AGENCY_DEST" "$STAGE_DIR" "$PRUNE_REMOVED" <<'PYEOF'
import json, os, sys
from pathlib import Path

config_path = Path(sys.argv[1])
agency_dest = Path(sys.argv[2]).resolve()
stage_dir = Path(sys.argv[3]).resolve()
prune_removed = sys.argv[4].lower() == "true"

with config_path.open("r", encoding="utf-8") as f:
    config = json.load(f)
agent_list = config.get("agents", {}).get("list", [])
existing_by_id = {entry.get("id"): entry for entry in agent_list if isinstance(entry, dict) and entry.get("id")}
stage_ids = sorted(child.name for child in stage_dir.iterdir() if child.is_dir())

would_add = 0
would_update = 0
for agent_id in stage_ids:
    target_ws = str((agency_dest / agent_id).resolve())
    entry = existing_by_id.get(agent_id)
    if entry is None:
        would_add += 1
    elif entry.get("workspace") != target_ws or entry.get("model") is None:
        would_update += 1

would_remove = 0
if prune_removed:
    prefix = str(agency_dest)
    stage_set = set(stage_ids)
    for entry in agent_list:
        if not isinstance(entry, dict):
            continue
        if entry.get("id") == "main":
            continue
        workspace = entry.get("workspace")
        if not isinstance(workspace, str):
            continue
        resolved = str(Path(os.path.expanduser(workspace)).resolve())
        managed = resolved == prefix or resolved.startswith(prefix + os.sep)
        if managed and entry.get("id") not in stage_set:
            would_remove += 1

print(f"Would add: {would_add}  Would update: {would_update}  Would remove: {would_remove}")
PYEOF
  header "Dry run complete"
  exit 0
fi

header "Step 3: Apply workspace updates"
python3 - "$AGENCY_DEST" "$STAGE_DIR" "$PRUNE_REMOVED" <<'PYEOF'
import os, shutil, sys
from pathlib import Path

current = Path(sys.argv[1])
stage = Path(sys.argv[2])
prune_removed = sys.argv[3].lower() == "true"
current.mkdir(parents=True, exist_ok=True)

stage_ids = {child.name for child in stage.iterdir() if child.is_dir()}
current_ids = {child.name for child in current.iterdir() if child.is_dir()}

for agent_id in sorted(stage_ids):
    src = stage / agent_id
    dst = current / agent_id
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / "AGENTS.md", dst / "AGENTS.md")

if prune_removed:
    for agent_id in sorted(current_ids - stage_ids):
        shutil.rmtree(current / agent_id)
PYEOF
info "Workspace files refreshed"

header "Step 4: Sync agents.list"
SYNC_ARGS=(--agency-dest "$AGENCY_DEST" --config "$CONFIG_PATH" --backup)
if [[ "$PRUNE_REMOVED" == true ]]; then
  SYNC_ARGS+=(--prune-missing)
fi
python3 "$SCRIPT_DIR/sync_openclaw_config.py" "${SYNC_ARGS[@]}"

header "Step 5: Restart gateway"
restart_gateway_and_wait || true

header "Update complete"
info "Tip: run ./scripts/update.sh --dry-run before the next live update"

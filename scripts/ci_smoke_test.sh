#!/usr/bin/env bash
# ci_smoke_test.sh — Deterministic local/CI smoke test without a real OpenClaw daemon.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
UPSTREAM_DIR="$TMP_ROOT/upstream"
FAKE_BIN_DIR="$TMP_ROOT/bin"
CONFIG_PATH="$TMP_ROOT/openclaw.json"
AGENCY_DEST="$TMP_ROOT/agency-agents"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$UPSTREAM_DIR/engineering" "$UPSTREAM_DIR/testing" "$UPSTREAM_DIR/marketing" "$FAKE_BIN_DIR"

cat >"$UPSTREAM_DIR/engineering/engineering-code-reviewer.md" <<'EOF'
# engineering-code-reviewer
Initial reviewer prompt.
EOF

cat >"$UPSTREAM_DIR/testing/testing-accessibility-auditor.md" <<'EOF'
# testing-accessibility-auditor
Initial accessibility prompt.
EOF

cat >"$UPSTREAM_DIR/marketing/marketing-email-writer.md" <<'EOF'
# marketing-email-writer
Initial email prompt.
EOF

git -C "$UPSTREAM_DIR" init -q -b main
git -C "$UPSTREAM_DIR" config user.name "CI"
git -C "$UPSTREAM_DIR" config user.email "ci@example.com"
git -C "$UPSTREAM_DIR" add .
git -C "$UPSTREAM_DIR" commit -qm "initial upstream"

cat >"$CONFIG_PATH" <<'EOF'
{
  "agents": {
    "list": [
      {
        "id": "main",
        "workspace": "~/.openclaw/workspace",
        "subagents": {
          "allowAgents": []
        }
      }
    ]
  }
}
EOF

cat >"$FAKE_BIN_DIR/openclaw" <<'EOF'
#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

config_path = Path(os.environ.get("OPENCLAW_CONFIG_PATH", str(Path.home() / ".openclaw" / "openclaw.json"))).expanduser()
argv = sys.argv[1:]

if argv[:2] == ["gateway", "restart"]:
    print("fake gateway restart")
    raise SystemExit(0)
if argv[:2] == ["gateway", "status"]:
    print("fake gateway status")
    raise SystemExit(0)
if argv[:2] == ["agents", "list"]:
    with config_path.open("r", encoding="utf-8") as f:
        config = json.load(f)
    print("Agents:")
    for entry in config.get("agents", {}).get("list", []):
        if isinstance(entry, dict) and entry.get("id"):
            print(f"- {entry['id']}")
    raise SystemExit(0)
if argv and argv[0] == "agent":
    print("FAKE_AGENT_OK")
    raise SystemExit(0)
print("unsupported fake openclaw invocation:", " ".join(argv), file=sys.stderr)
raise SystemExit(1)
EOF
chmod +x "$FAKE_BIN_DIR/openclaw"

export PATH="$FAKE_BIN_DIR:$PATH"
export OPENCLAW_CONFIG_PATH="$CONFIG_PATH"
export AGENCY_DEST="$AGENCY_DEST"
export AGENCYTEAM_UPSTREAM_URL="$UPSTREAM_DIR"
export AGENCYTEAM_UPSTREAM_REF="main"

case "$OPENCLAW_CONFIG_PATH" in
  "$TMP_ROOT"/*) ;;
  *)
    echo "Refusing to run smoke test against non-temp config: $OPENCLAW_CONFIG_PATH" >&2
    exit 1
    ;;
esac

cd "$SKILL_DIR"
chmod +x scripts/*.sh scripts/*.py

bash -n scripts/*.sh
python3 -m py_compile scripts/*.py
./scripts/install.sh --all

python3 - <<'PYEOF' "$CONFIG_PATH" "$AGENCY_DEST"
import json, os, sys
config_path, dest = sys.argv[1], sys.argv[2]
with open(config_path, 'r', encoding='utf-8') as f:
    data = json.load(f)
agent_list = {entry['id']: entry for entry in data['agents']['list'] if isinstance(entry, dict) and entry.get('id')}
for agent_id in ('engineering-code-reviewer', 'testing-accessibility-auditor', 'marketing-email-writer'):
    assert agent_id in agent_list
    workspace = os.path.realpath(os.path.join(dest, agent_id))
    assert agent_list[agent_id]['workspace'] == workspace
    assert os.path.isfile(os.path.join(workspace, 'AGENTS.md'))
    assert os.path.isfile(os.path.join(workspace, 'AGENCYTEAM_MANAGED'))
allow = agent_list['main']['subagents']['allowAgents']
for agent_id in ('engineering-code-reviewer', 'testing-accessibility-auditor', 'marketing-email-writer'):
    assert agent_id in allow
print('install smoke ok')
PYEOF

BAD_CONFIG_PATH="$TMP_ROOT/bad-openclaw.json"
cat >"$BAD_CONFIG_PATH" <<'EOF'
{
  "agents": {
    "list": [
      {
        "id": "main",
        "workspace": "~/.openclaw/workspace",
        "subagents": {
          "allowAgents": ["engineering-code-reviewer", 123]
        }
      }
    ]
  }
}
EOF

if python3 ./scripts/sync_openclaw_config.py --agency-dest "$AGENCY_DEST" --config "$BAD_CONFIG_PATH" --agent engineering-code-reviewer --dry-run >/tmp/agencyteam-bad.out 2>/tmp/agencyteam-bad.err; then
  echo "expected malformed allowAgents validation to fail" >&2
  exit 1
fi
grep -q 'allowAgents must contain only strings' /tmp/agencyteam-bad.err

mkdir -p "$AGENCY_DEST/custom-local-agent"
printf '%s\n' 'local custom content' > "$AGENCY_DEST/custom-local-agent/README.md"

PRUNE_TEST_CONFIG_PATH="$TMP_ROOT/prune-test-openclaw.json"
cp "$CONFIG_PATH" "$PRUNE_TEST_CONFIG_PATH"
python3 - <<'PYEOF' "$PRUNE_TEST_CONFIG_PATH" "$AGENCY_DEST"
import json, os, sys
config_path, dest = sys.argv[1], sys.argv[2]
with open(config_path, 'r', encoding='utf-8') as f:
    data = json.load(f)
data['agents']['list'].append({
    'id': 'custom-local-agent',
    'workspace': os.path.realpath(os.path.join(dest, 'custom-local-agent')),
    'model': 'minimax/MiniMax-M2.7',
})
with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF

HELPER_PRUNE_OUTPUT="$(python3 ./scripts/sync_openclaw_config.py --agency-dest "$AGENCY_DEST" --config "$PRUNE_TEST_CONFIG_PATH" --agent engineering-code-reviewer --dry-run --prune-missing)"
printf '%s\n' "$HELPER_PRUNE_OUTPUT"
printf '%s\n' "$HELPER_PRUNE_OUTPUT" | grep -q 'removed=2'
if printf '%s\n' "$HELPER_PRUNE_OUTPUT" | grep -q 'custom-local-agent'; then
  echo "helper prune unexpectedly targeted custom-local-agent" >&2
  exit 1
fi

cat >"$UPSTREAM_DIR/engineering/engineering-code-reviewer.md" <<'EOF'
# engineering-code-reviewer
Updated reviewer prompt.
EOF
rm -f "$UPSTREAM_DIR/marketing/marketing-email-writer.md"
git -C "$UPSTREAM_DIR" add -A
git -C "$UPSTREAM_DIR" commit -qm "update reviewer and remove marketing"

DRY_RUN_OUTPUT="$(./scripts/update.sh --dry-run --prune-removed)"
printf '%s\n' "$DRY_RUN_OUTPUT"
printf '%s\n' "$DRY_RUN_OUTPUT" | grep -q 'Changed: 1'
printf '%s\n' "$DRY_RUN_OUTPUT" | grep -q 'Removed upstream: 1'
printf '%s\n' "$DRY_RUN_OUTPUT" | grep -q 'Unmanaged dirs left untouched: custom-local-agent'

./scripts/update.sh --prune-removed

grep -q 'Updated reviewer prompt.' "$AGENCY_DEST/engineering-code-reviewer/AGENTS.md"
[[ ! -d "$AGENCY_DEST/marketing-email-writer" ]]
[[ -d "$AGENCY_DEST/custom-local-agent" ]]

python3 - <<'PYEOF' "$CONFIG_PATH"
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
ids = {entry['id'] for entry in data['agents']['list'] if isinstance(entry, dict) and entry.get('id')}
assert 'marketing-email-writer' not in ids
assert 'custom-local-agent' not in ids
print('prune smoke ok')
PYEOF

rm -f "$AGENCY_DEST/engineering-code-reviewer/AGENTS.md"
./scripts/spawn-and-install.sh engineering-code-reviewer "Reply with exactly: FAKE_AGENT_OK" --timeout 30 | grep -q 'FAKE_AGENT_OK'
[[ -f "$AGENCY_DEST/engineering-code-reviewer/AGENTS.md" ]]

echo 'CI_SMOKE_OK'

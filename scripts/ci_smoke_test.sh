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

mkdir -p "$UPSTREAM_DIR/engineering" "$UPSTREAM_DIR/testing" "$FAKE_BIN_DIR"

cat >"$UPSTREAM_DIR/engineering/engineering-code-reviewer.md" <<'EOF'
# engineering-code-reviewer
Initial reviewer prompt.
EOF

cat >"$UPSTREAM_DIR/testing/testing-accessibility-auditor.md" <<'EOF'
# testing-accessibility-auditor
Initial accessibility prompt.
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
./scripts/install.sh --agents "engineering-code-reviewer testing-accessibility-auditor"

python3 - <<'PYEOF' "$CONFIG_PATH" "$AGENCY_DEST"
import json, os, sys
config_path, dest = sys.argv[1], sys.argv[2]
with open(config_path, 'r', encoding='utf-8') as f:
    data = json.load(f)
agent_list = {entry['id']: entry for entry in data['agents']['list'] if isinstance(entry, dict) and entry.get('id')}
assert 'engineering-code-reviewer' in agent_list
assert 'testing-accessibility-auditor' in agent_list
allow = agent_list['main']['subagents']['allowAgents']
assert 'engineering-code-reviewer' in allow
assert 'testing-accessibility-auditor' in allow
for agent_id in ('engineering-code-reviewer', 'testing-accessibility-auditor'):
    workspace = os.path.realpath(os.path.join(dest, agent_id))
    assert agent_list[agent_id]['workspace'] == workspace
print('install smoke ok')
PYEOF

cat >"$UPSTREAM_DIR/engineering/engineering-code-reviewer.md" <<'EOF'
# engineering-code-reviewer
Updated reviewer prompt.
EOF
git -C "$UPSTREAM_DIR" add engineering/engineering-code-reviewer.md
git -C "$UPSTREAM_DIR" commit -qm "update reviewer"

DRY_RUN_OUTPUT="$(./scripts/update.sh --dry-run)"
printf '%s\n' "$DRY_RUN_OUTPUT"
printf '%s\n' "$DRY_RUN_OUTPUT" | grep -q 'Changed: 1'

./scripts/update.sh

grep -q 'Updated reviewer prompt.' "$AGENCY_DEST/engineering-code-reviewer/AGENTS.md"
./scripts/spawn-and-install.sh engineering-code-reviewer "Reply with exactly: FAKE_AGENT_OK" --timeout 30 | grep -q 'FAKE_AGENT_OK'

echo 'CI_SMOKE_OK'

#!/usr/bin/env bash
# convert.sh — Fetch agency-agents and convert supported expert prompts into OpenClaw workspaces.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

AGENCY_DEST="${AGENCY_DEST:-${HOME}/.openclaw/agency-agents}"
REPO_URL="${AGENCYTEAM_UPSTREAM_URL:-https://github.com/msitarzewski/agency-agents.git}"
UPSTREAM_REF="$(agencyteam_upstream_ref)"
SOURCE_DIR=""
TMP_DIR=""

CATEGORIES=(
  academic
  design
  engineering
  game-development
  marketing
  paid-media
  product
  project-management
  sales
  spatial-computing
  specialized
  support
  testing
)

usage() {
  cat <<'EOF'
Usage: ./scripts/convert.sh [OPTIONS]

Options:
  --output DIR      Destination for generated workspaces (default: $AGENCY_DEST or ~/.openclaw/agency-agents)
  --source DIR      Use an already-cloned upstream repo instead of cloning
  --ref REF         Override upstream branch, tag, or commit-ish
  --help            Show this help

Defaults:
  Upstream URL defaults to https://github.com/msitarzewski/agency-agents.git
  Upstream ref defaults to AGENCYTEAM_UPSTREAM_REF or the pinned ref in ./UPSTREAM_REF

Environment:
  AGENCY_DEST               Default output directory
  AGENCYTEAM_UPSTREAM_URL   Override upstream git URL
  AGENCYTEAM_UPSTREAM_REF   Override upstream ref (branch/tag/commit-ish)
  AGENCYTEAM_UPSTREAM_REF_FILE  Override file containing the pinned ref
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      AGENCY_DEST="$2"
      shift 2
      ;;
    --source)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --ref)
      UPSTREAM_REF="$2"
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

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

is_full_commit_ref() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]]
}

require_cmd python3 cp mkdir basename
mkdir -p "$AGENCY_DEST"
AGENCY_DEST="$(expand_path "$AGENCY_DEST")"

if [[ -n "$SOURCE_DIR" ]]; then
  SOURCE_DIR="$(expand_path "$SOURCE_DIR")"
  [[ -d "$SOURCE_DIR" ]] || { error "Source repo not found: $SOURCE_DIR"; exit 1; }
else
  require_cmd git
  TMP_DIR="$(mktemp -d)"
  SOURCE_DIR="$TMP_DIR/upstream"

  info "Cloning upstream: $REPO_URL"
  if is_full_commit_ref "$UPSTREAM_REF"; then
    git clone "$REPO_URL" "$SOURCE_DIR" >/dev/null 2>&1
    git -C "$SOURCE_DIR" checkout --quiet "$UPSTREAM_REF"
  else
    if ! git clone --depth=1 --branch "$UPSTREAM_REF" "$REPO_URL" "$SOURCE_DIR" >/dev/null 2>&1; then
      git clone "$REPO_URL" "$SOURCE_DIR" >/dev/null 2>&1
      git -C "$SOURCE_DIR" checkout --quiet "$UPSTREAM_REF"
    fi
  fi
fi

[[ -d "$SOURCE_DIR" ]] || { error "Resolved source repo missing: $SOURCE_DIR"; exit 1; }

resolved_rev="unknown"
if command -v git >/dev/null 2>&1 && [[ -d "$SOURCE_DIR/.git" ]]; then
  resolved_rev="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
  if is_full_commit_ref "$UPSTREAM_REF" && [[ "$resolved_rev" != "$UPSTREAM_REF" ]]; then
    error "Pinned upstream commit mismatch"
    error "Expected: $UPSTREAM_REF"
    error "Resolved: $resolved_rev"
    exit 1
  fi
fi

header "Convert agency-agents → OpenClaw workspaces"
info "Source: $SOURCE_DIR"
info "Output: $AGENCY_DEST"
info "Requested ref: $UPSTREAM_REF"
info "Resolved revision: $resolved_rev"

declare -A seen_ids=()
count=0
for category in "${CATEGORIES[@]}"; do
  cat_dir="$SOURCE_DIR/$category"
  [[ -d "$cat_dir" ]] || continue

  for md_file in "$cat_dir"/*.md; do
    [[ -f "$md_file" ]] || continue

    agent_id="$(basename "$md_file" .md)"
    if [[ ! "$agent_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      error "Invalid upstream agent id derived from filename: $agent_id ($md_file)"
      exit 1
    fi
    if [[ -n "${seen_ids[$agent_id]:-}" ]]; then
      error "Duplicate agent id detected: $agent_id"
      error "First seen at: ${seen_ids[$agent_id]}"
      error "Again at:      $md_file"
      exit 1
    fi
    seen_ids[$agent_id]="$md_file"

    dest="$AGENCY_DEST/$agent_id"
    mkdir -p "$dest"
    cp "$md_file" "$dest/AGENTS.md"
    ((count+=1))
  done
done

info "Done — converted $count agents"

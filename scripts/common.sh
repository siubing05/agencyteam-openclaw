#!/usr/bin/env bash
# common.sh — Shared helpers for agencyteam scripts.

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BOLD=''; RESET=''
fi

info()   { printf "${GREEN}[OK]${RESET}  %s\n" "$*"; }
warn()   { printf "${YELLOW}[!!]${RESET}  %s\n" "$*"; }
error()  { printf "${RED}[ERR]${RESET} %s\n" "$*" >&2; }
header() { printf "\n${BOLD}%s${RESET}\n" "$*"; }
bold()   { printf "${BOLD}%s${RESET}\n" "$*"; }

require_cmd() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error "Missing required command: $cmd"
      exit 1
    fi
  done
}

expand_path() {
  python3 - "$1" <<'PYEOF'
import os, sys
print(os.path.realpath(os.path.expanduser(sys.argv[1])))
PYEOF
}

skill_root_dir() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$script_dir/.." && pwd
}

openclaw_config_path() {
  printf '%s\n' "${OPENCLAW_CONFIG_PATH:-${HOME}/.openclaw/openclaw.json}"
}

agencyteam_upstream_ref_file() {
  printf '%s\n' "${AGENCYTEAM_UPSTREAM_REF_FILE:-$(skill_root_dir)/UPSTREAM_REF}"
}

agencyteam_upstream_ref() {
  local ref_file ref_value
  if [[ -n "${AGENCYTEAM_UPSTREAM_REF:-}" ]]; then
    printf '%s\n' "$AGENCYTEAM_UPSTREAM_REF"
    return 0
  fi

  ref_file="$(agencyteam_upstream_ref_file)"
  if [[ -f "$ref_file" ]]; then
    ref_value="$(awk 'NF && $1 !~ /^#/ { print $1; exit }' "$ref_file")"
    if [[ -n "$ref_value" ]]; then
      printf '%s\n' "$ref_value"
      return 0
    fi
  fi

  printf 'main\n'
}

ensure_openclaw_config_exists() {
  local config_path
  config_path="$(expand_path "$(openclaw_config_path)")"
  if [[ ! -f "$config_path" ]]; then
    error "OpenClaw config not found: $config_path"
    error "Create your OpenClaw setup first, or set OPENCLAW_CONFIG_PATH to a valid config file."
    exit 1
  fi
}

restart_gateway_and_wait() {
  local config_path default_path attempt max_attempts
  config_path="$(expand_path "$(openclaw_config_path)")"
  default_path="$(expand_path "${HOME}/.openclaw/openclaw.json")"

  if [[ "$config_path" != "$default_path" ]]; then
    warn "Skipping gateway restart because OPENCLAW_CONFIG_PATH override is set"
    return 0
  fi

  if ! openclaw gateway restart >/dev/null 2>&1; then
    warn "openclaw gateway restart returned non-zero; continuing to health check"
  fi

  max_attempts=20
  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    if openclaw agents list >/dev/null 2>&1; then
      info "Gateway is responding"
      return 0
    fi
    sleep 1
  done

  warn "Gateway did not become healthy within ${max_attempts}s"
  return 1
}

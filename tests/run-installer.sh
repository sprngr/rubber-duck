#!/usr/bin/env bash
# Installer behavioral tests: fresh install, reinstall, sync, prune, allowlist.
# Runs the real bash installer against local dist/, in isolated tmp workspaces.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
sh_installer="$repo_root/scripts/rubber-duck.sh"

failures=0
tests_run=0

setup_workspace() {
  local ws
  ws="$(mktemp -d -t rd-installer-test.XXXXXX)"
  echo "$ws"
}

teardown_workspace() {
  local ws="$1"
  [[ -n "$ws" && -d "$ws" && "$ws" == /tmp/* ]] && rm -rf "$ws"
}

run_test() {
  local name="$1" fn="$2"
  tests_run=$((tests_run + 1))
  local ws
  ws="$(setup_workspace)"
  local rc=0
  ( cd "$ws" && "$fn" "$ws" >/dev/null 2>&1 ) || rc=$?
  teardown_workspace "$ws"
  if [[ $rc -eq 0 ]]; then
    printf 'ok  %s\n' "$name"
  else
    printf 'FAIL %s\n' "$name"
    failures=$((failures + 1))
  fi
}

# Fresh install writes pins block populated with sha256 entries.
test_fresh_install_writes_pins() {
  bash "$sh_installer" install --opencode --source local --skip-skills --project || return 1
  [[ -f .rubber-duck/manifest.json ]] || return 1
  python3 -c '
import json, sys
d = json.load(open(".rubber-duck/manifest.json"))
pins = d.get("pins", {})
if len(pins) < 2: sys.exit(1)
if not all(v.startswith("sha256:") for v in pins.values()): sys.exit(1)
'
}

# Reinstall against same source: pins stable and dest files not touched
# (skip-unchanged optimization keeps mtime constant).
test_reinstall_pins_verify() {
  bash "$sh_installer" install --opencode --source local --skip-skills --project || return 1
  local before_pins before_mtime
  before_pins=$(python3 -c 'import json; d=json.load(open(".rubber-duck/manifest.json")); print(sorted(d.get("pins",{}).items()))')
  before_mtime=$(stat -c '%Y' .opencode/agents/rubber-duck.md 2>/dev/null || stat -f '%m' .opencode/agents/rubber-duck.md)
  sleep 1
  bash "$sh_installer" install --opencode --source local --skip-skills --project || return 1
  local after_pins after_mtime
  after_pins=$(python3 -c 'import json; d=json.load(open(".rubber-duck/manifest.json")); print(sorted(d.get("pins",{}).items()))')
  after_mtime=$(stat -c '%Y' .opencode/agents/rubber-duck.md 2>/dev/null || stat -f '%m' .opencode/agents/rubber-duck.md)
  [[ "$before_pins" == "$after_pins" ]] || return 1
  [[ "$before_mtime" == "$after_mtime" ]] || return 1
}

# Install opencode, edit manifest to disable opencode + enable claude, sync prune.
test_sync_round_trip() {
  bash "$sh_installer" install --opencode --source local --skip-skills --project || return 1
  [[ -f .opencode/agents/rubber-duck.md ]] || return 1
  python3 -c '
import json
p = ".rubber-duck/manifest.json"
d = json.load(open(p))
d["targets"]["opencode"]["enabled"] = False
d["targets"]["claude"] = {"enabled": True, "scope": "project", "installAgentsMd": True, "installSkills": False, "extras": False}
open(p, "w").write(json.dumps(d, indent=2, sort_keys=True) + "\n")
'
  bash "$sh_installer" sync --project --prune --source local --skip-skills || return 1
  [[ -f .claude/agents/rubber-duck.md ]] || return 1
  [[ ! -f .opencode/agents/rubber-duck.md ]] || return 1
}

# Non-allowlisted rawBase blocked; --allow-untrusted-source warns and bypasses.
test_rawbase_allowlist() {
  if bash "$sh_installer" install --opencode --source web --raw-base "https://evil.example/foo" --skip-skills --project 2>/dev/null; then
    return 1
  fi
  local out
  out=$(bash "$sh_installer" install --opencode --source web --raw-base "https://evil.example/foo" --skip-skills --project --allow-untrusted-source 2>&1 || true)
  echo "$out" | grep -q "allowlist bypassed" || return 1
}

# Claude install: agent only, no policy file, no managed block.
test_claude_install_agent_only() {
  bash "$sh_installer" install --claude --source local --skip-skills --project || return 1
  [[ -f .claude/agents/rubber-duck.md ]] || return 1
  # 3.x: no CLAUDE.md / AGENTS.md managed block is written.
  [[ ! -f CLAUDE.md ]] || return 1
  python3 -c '
import json
d = json.load(open(".rubber-duck/manifest.json"))
pins = d.get("pins", {})
assert "dist/claude/agents/rubber-duck.md" in pins, "claude agent pin missing"
'
}

# Dry-run install creates no files/dirs and reports [dry-run] markers.
test_dry_run_no_writes() {
  bash "$sh_installer" install --opencode --source local --skip-skills --project --dry-run || return 1
  [[ ! -e .rubber-duck/manifest.json ]] || return 1
  [[ ! -e .opencode ]] || return 1
  [[ ! -e AGENTS.md ]] || return 1
  compgen -G "AGENTS.md.bak.*" >/dev/null && return 1
  return 0
}

# Multi-target dry-run: banner + version + per-target [name] + 🦆 quack, no writes.
test_dry_run_multi_target_layout() {
  local out
  out=$(bash "$sh_installer" install --harness opencode,claude,copilot --source local --skip-skills --project --dry-run 2>&1) || return 1
  echo "$out" | grep -Fq "version: " || return 1
  echo "$out" | grep -Fq "[opencode]" || return 1
  echo "$out" | grep -Fq "[claude]" || return 1
  echo "$out" | grep -Fq "[copilot]" || return 1
  echo "$out" | grep -Fq "[dry-run] pins update" || return 1
  echo "$out" | grep -Fq "🦆 quack" || return 1
  [[ ! -e .rubber-duck/manifest.json ]] || return 1
  [[ ! -e .opencode ]] || return 1
  [[ ! -e .claude ]] || return 1
  [[ ! -e .github/agents ]] || return 1
  return 0
}

# Sync with default source (auto). Regression guard for RAW_BASE ordering bug:
# sync path used to call rawBase allowlist before RAW_BASE default was applied.
test_sync_default_source() {
  bash "$sh_installer" install --opencode --source local --skip-skills --project || return 1
  bash "$sh_installer" sync --project --source local --skip-skills || return 1
}

# Install writes sync wrapper with correct scope and URL substitution.
test_sync_wrapper_content() {
  bash "$sh_installer" install --opencode --source local --skip-skills --project || return 1
  [[ -f .rubber-duck/sync-latest.sh ]] || return 1
  grep -qE '^SYNC_SCOPE_FLAG="--project"$' .rubber-duck/sync-latest.sh || return 1
  grep -qE '^SYNC_INSTALLER_URL=".+"$' .rubber-duck/sync-latest.sh || return 1
  grep -q '{{SYNC_SCOPE_FLAG}}' .rubber-duck/sync-latest.sh && return 1
  grep -q '{{SYNC_INSTALLER_URL}}' .rubber-duck/sync-latest.sh && return 1
  grep -q 'RUBBER_DUCK_VERSION:' .rubber-duck/sync-latest.sh || return 1
}

# Legacy managed block on upgrade: block stripped, no .bak backup written.
test_managed_block_migration_strips_without_backup() {
  cat > AGENTS.md <<'EOF'
Preamble line

<!-- RUBBER_DUCK_MANAGED_BLOCK START -->
USER CUSTOM MARKER
<!-- RUBBER_DUCK_MANAGED_BLOCK END -->

Trailer line
EOF
  local out
  out=$(bash "$sh_installer" install --opencode --source local --skip-skills --project 2>&1) || return 1
  echo "$out" | grep -q "Legacy managed policy block detected" || return 1
  grep -q "RUBBER_DUCK_MANAGED_BLOCK" AGENTS.md && return 1
  grep -q "USER CUSTOM MARKER" AGENTS.md && return 1
  grep -q "Preamble line" AGENTS.md || return 1
  grep -q "Trailer line" AGENTS.md || return 1
  compgen -G "AGENTS.md.bak.*" >/dev/null && return 1
  return 0
}

# Fresh install (no prior AGENTS.md): no spurious backup files.
test_fresh_install_no_spurious_backup() {
  rm -f AGENTS.md AGENTS.md.bak.* CLAUDE.md CLAUDE.md.bak.*
  bash "$sh_installer" install --opencode --source local --skip-skills --project || return 1
  ls AGENTS.md.bak.* >/dev/null 2>&1 && return 1
  return 0
}

# bash < 4 (macOS default /bin/bash 3.2) fails fast with a clear message,
# not 'declare: -A: invalid option'. Skips when no bash 3 is installed.
test_version_guard_rejects_bash3() {
  local old_bash=""
  for b in /bin/bash /usr/bin/bash; do
    if [[ -x "$b" ]] && [[ "$("$b" -c 'printf %s "${BASH_VERSINFO[0]}"')" == "3" ]]; then
      old_bash="$b"
      break
    fi
  done
  [[ -n "$old_bash" ]] || return 0  # no bash 3 available: skip
  if "$old_bash" "$sh_installer" --help >/dev/null 2>&1; then
    return 1  # guard missing: bash 3 ran the script
  fi
  local out
  out=$("$old_bash" "$sh_installer" --help 2>&1 || true)
  echo "$out" | grep -q "requires bash 4+" || return 1
  echo "$out" | grep -q "declare: -A" && return 1
  return 0
}

# --- Test runner ---
run_test "fresh install writes pins"        test_fresh_install_writes_pins
run_test "reinstall verifies pins silently" test_reinstall_pins_verify
run_test "sync round-trip"                  test_sync_round_trip
run_test "rawBase allowlist"                test_rawbase_allowlist
run_test "claude install agent only"        test_claude_install_agent_only
run_test "dry-run no writes"                test_dry_run_no_writes
run_test "dry-run multi-target layout"      test_dry_run_multi_target_layout
run_test "sync default source"              test_sync_default_source
run_test "sync wrapper content"             test_sync_wrapper_content
run_test "managed block migration strips without backup" test_managed_block_migration_strips_without_backup
run_test "fresh install no spurious backup" test_fresh_install_no_spurious_backup
run_test "bash3 version guard"              test_version_guard_rejects_bash3

# --- version_gt() unit tests (inline from sync-latest.sh.tmpl) ---
version_gt() {
  local IFS='.'
  local a=(${1#v}) b=(${2#v})
  for i in 0 1 2; do
    local na=${a[$i]:-0} nb=${b[$i]:-0}
    if [[ ! "${na}" =~ ^[0-9]+$ || ! "${nb}" =~ ^[0-9]+$ ]]; then
      return 2
    fi
    if (( na > nb )); then return 0; fi
    if (( na < nb )); then return 1; fi
  done
  return 1
}

test_version_gt_equal() { ! version_gt "v2.2.0" "v2.2.0"; }
test_version_gt_newer() { version_gt "v2.3.0" "v2.2.0"; }
test_version_gt_older() { ! version_gt "v2.1.0" "v2.2.0"; }
test_version_gt_patch() { version_gt "v2.2.1" "v2.2.0"; }
test_version_gt_major() { version_gt "v3.0.0" "v2.9.9"; }
test_version_gt_no_v_prefix() { version_gt "2.3.0" "2.2.0"; }
test_version_gt_invalid() { ! version_gt "" "v2.2.0"; }
test_version_gt_prerelease_incomparable() {
  version_gt "v2.3.0-beta" "v2.3.0" && return 1
  [[ $? -eq 2 ]] || return 1
}
test_version_gt_prerelease_higher_core() { version_gt "v2.4.0-rc1" "v2.3.0"; }

run_test "version_gt equal"           test_version_gt_equal
run_test "version_gt newer"           test_version_gt_newer
run_test "version_gt older"           test_version_gt_older
run_test "version_gt patch"           test_version_gt_patch
run_test "version_gt major"           test_version_gt_major
run_test "version_gt no v prefix"     test_version_gt_no_v_prefix
run_test "version_gt invalid"         test_version_gt_invalid
run_test "version_gt prerelease incomparable" test_version_gt_prerelease_incomparable
run_test "version_gt prerelease higher core"  test_version_gt_prerelease_higher_core

# End-to-end remote sync: web install from local HTTP server, wrapper
# downloads the installer from the same base and runs sync.
test_sync_wrapper_remote_sync() {
  local ws="$1" port server_pid rc i
  mkdir -p "$ws/remote"
  cp -r "$repo_root/scripts" "$ws/remote/"
  cp -r "$repo_root/dist" "$ws/remote/"
  cp "$repo_root/VERSION" "$ws/remote/"
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$ws/remote" >/dev/null 2>&1 &
  server_pid=$!
  trap 'kill "${server_pid:-}" 2>/dev/null || true' EXIT
  for i in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:$port/VERSION" >/dev/null 2>&1; then break; fi
    sleep 0.2
  done

  bash "$sh_installer" install --opencode --source web --raw-base "http://127.0.0.1:$port" --skip-skills --allow-untrusted-source --project || return 1
  local wrapper=".rubber-duck/sync-latest.sh"
  [[ -f "$wrapper" ]] || return 1
  grep -Fq "http://127.0.0.1:$port/scripts/rubber-duck.sh" "$wrapper" || return 1

  # Same version: no prompt, sync runs (raw-base forwarded by wrapper).
  bash "$wrapper" --allow-untrusted-source || return 1
  return 0
}

# Upgrade path: version bump prompts; accepting syncs the new installer.
test_sync_wrapper_upgrade() {
  local ws="$1" port server_pid out rc i cur_ver next_ver
  mkdir -p "$ws/remote"
  cp -r "$repo_root/scripts" "$ws/remote/"
  cp -r "$repo_root/dist" "$ws/remote/"
  cp "$repo_root/VERSION" "$ws/remote/"
  cur_ver="$(tr -d '[:space:]' < "$repo_root/VERSION")"
  next_ver="$(printf '%s' "$cur_ver" | awk -F. '{printf "%s.%s.%d", $1, $2, $3+1}')"
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$ws/remote" >/dev/null 2>&1 &
  server_pid=$!
  trap 'kill "${server_pid:-}" 2>/dev/null || true' EXIT
  for i in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:$port/VERSION" >/dev/null 2>&1; then break; fi
    sleep 0.2
  done

  bash "$sh_installer" install --opencode --source web --raw-base "http://127.0.0.1:$port" --skip-skills --allow-untrusted-source --project || return 1
  local wrapper=".rubber-duck/sync-latest.sh"
  [[ -f "$wrapper" ]] || return 1

  # Release next version: bump VERSION + change installer bytes.
  echo "$next_ver" > "$ws/remote/VERSION"
  echo "# $next_ver" >> "$ws/remote/scripts/rubber-duck.sh"

  out=$(printf 'y\n' | bash "$wrapper" --allow-untrusted-source 2>&1) && rc=0 || rc=$?
  [[ $rc -eq 0 ]] || return 1
  echo "$out" | grep -q "New version available: ${cur_ver} -> ${next_ver}" || return 1
  return 0
}

run_test "sync wrapper remote sync" test_sync_wrapper_remote_sync
run_test "sync wrapper upgrade"     test_sync_wrapper_upgrade

printf '\n%d/%d passed, %d failed\n' "$((tests_run - failures))" "$tests_run" "$failures"
exit $((failures > 0 ? 1 : 0))

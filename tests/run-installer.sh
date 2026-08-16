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
if len(pins) < 3: sys.exit(1)
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

# Claude install: two-file layout (CLAUDE.md + sibling AGENTS.md) with pins.
test_claude_install_two_file_layout() {
  bash "$sh_installer" install --claude --source local --skip-skills --project || return 1
  [[ -f CLAUDE.md ]] || return 1
  [[ -f AGENTS.md ]] || return 1
  [[ -f .claude/agents/rubber-duck.md ]] || return 1
  python3 -c '
import json
d = json.load(open(".rubber-duck/manifest.json"))
pins = d.get("pins", {})
assert "dist/claude/CLAUDE.md" in pins, "claude policy pin missing"
assert "dist/claude/agents/rubber-duck-lite.md" in pins, "claude lite agent pin missing"
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
  bash "$sh_installer" install --opencode --source local --skip-skills --policy self --project || return 1
  bash "$sh_installer" sync --project --source local --skip-skills --policy self || return 1
}

# Install writes sync wrapper with correct scope and URL substitution.
test_sync_wrapper_content() {
  bash "$sh_installer" install --opencode --source local --skip-skills --project || return 1
  [[ -f .rubber-duck/sync-latest.sh ]] || return 1
  grep -q '\-\-project' .rubber-duck/sync-latest.sh || return 1
  grep -q '{{SYNC_SCOPE_FLAG}}' .rubber-duck/sync-latest.sh && return 1
  grep -q '{{SYNC_INSTALLER_URL}}' .rubber-duck/sync-latest.sh && return 1
  grep -q 'RUBBER_DUCK_VERSION:' .rubber-duck/sync-latest.sh || return 1
}

# --- Test runner ---
run_test "fresh install writes pins"        test_fresh_install_writes_pins
run_test "reinstall verifies pins silently" test_reinstall_pins_verify
run_test "sync round-trip"                  test_sync_round_trip
run_test "rawBase allowlist"                test_rawbase_allowlist
run_test "claude two-file layout"           test_claude_install_two_file_layout
run_test "dry-run no writes"                test_dry_run_no_writes
run_test "dry-run multi-target layout"      test_dry_run_multi_target_layout
run_test "sync default source"              test_sync_default_source
run_test "sync wrapper content"             test_sync_wrapper_content

printf '\n%d/%d passed, %d failed\n' "$((tests_run - failures))" "$tests_run" "$failures"
exit $((failures > 0 ? 1 : 0))

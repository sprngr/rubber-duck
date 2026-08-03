#!/usr/bin/env python3
"""Automated validation test runner for Rubber Duck behavior regression checks.

Invokes opencode per test in an isolated temp directory, parses JSONL response
events, matches expected signals case-insensitively, and saves full responses
to RESULTS_DIR for inspection. Real execution by default; use --filter or
--severity to narrow runs.

Usage:
    python3 validation/run-validation-tests.py
    python3 validation/run-validation-tests.py --filter=V02,V03,V11
    python3 validation/run-validation-tests.py --severity=Critical
    python3 validation/run-validation-tests.py --keep-workspaces

Environment:
    RUBBER_DUCK_AGENT       opencode agent name (default: 🦆)
    RUBBER_DUCK_MODEL       opencode model id (default: empty = agent default)
    RESULTS_DIR             output directory (default: /tmp/rubber-duck-validation)

Exit codes:
    0  all passed (or no tests executed)
    1  one or more tests failed signal match
    2  runner error (opencode missing, test file missing, test errored)
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TEST_FILE = REPO_ROOT / "validation" / "test-prompts.json"
DEFAULT_RESULTS_DIR = Path(os.environ.get("RESULTS_DIR", "/tmp/rubber-duck-validation"))
DEFAULT_AGENT = os.environ.get("RUBBER_DUCK_AGENT", "🦆")
DEFAULT_MODEL = os.environ.get("RUBBER_DUCK_MODEL", "")
RUN_TIMEOUT_SECONDS = 300
FIXTURES_DIR = REPO_ROOT / "validation" / "fixtures"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Run Rubber Duck validation tests via opencode harness.",
    )
    p.add_argument("--filter", default="", help="Comma-separated test IDs to run (e.g. V02,V03)")
    p.add_argument("--severity", default="", help="Run only tests with this severity")
    p.add_argument("--interactive", action="store_true", help="Prompt to continue after each test")
    p.add_argument(
        "--test-file",
        type=Path,
        default=DEFAULT_TEST_FILE,
        help="Test prompts JSON file (default: validation/test-prompts.json)",
    )
    p.add_argument(
        "--results-dir",
        type=Path,
        default=DEFAULT_RESULTS_DIR,
        help="Output directory for full responses (default: /tmp/rubber-duck-validation)",
    )
    p.add_argument("--agent", default=DEFAULT_AGENT, help="opencode agent name to invoke")
    p.add_argument("--model", default=DEFAULT_MODEL, help="opencode model id (optional)")
    p.add_argument(
        "--keep-workspaces",
        action="store_true",
        help="Keep per-test workspace dirs for debugging (default: clean up)",
    )
    p.add_argument(
        "--max-follow-up-turns",
        type=int,
        default=5,
        help="Cap on follow-up turns per test (default: 5, prevents runaway)",
    )
    p.add_argument(
        "--sandbox",
        choices=("none", "bwrap"),
        default="bwrap",
        help="Sandbox mode (default: bwrap if available, else none with warning)",
    )
    p.add_argument(
        "--sandbox-bwrap-bin",
        default="bwrap",
        help="Bubblewrap executable path (default: bwrap)",
    )
    p.add_argument(
        "--matcher",
        choices=("hybrid", "substring", "judge"),
        default="hybrid",
        help="Signal matcher: hybrid (substring + judge fallback, default), substring (fast), judge (LLM all signals)",
    )
    return p.parse_args()


def parse_jsonl_events(raw: str) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            events.append(payload)
    return events


def extract_last_text(events: list[dict[str, Any]]) -> str:
    last_text = ""
    for event in events:
        if event.get("type") != "text":
            continue
        part = event.get("part")
        if isinstance(part, dict):
            text = part.get("text")
            if isinstance(text, str):
                last_text = text
    return last_text


def extract_session_id(events: list[dict[str, Any]]) -> str | None:
    for event in events:
        value = event.get("sessionID")
        if isinstance(value, str) and value:
            return value
        part = event.get("part")
        if isinstance(part, dict):
            part_value = part.get("sessionID")
            if isinstance(part_value, str) and part_value:
                return part_value
    return None


def ensure_sandbox(sandbox_mode: str, bwrap_bin: str) -> None:
    if sandbox_mode == "none":
        return
    if shutil.which(bwrap_bin) is None:
        raise FileNotFoundError(
            f"--sandbox {sandbox_mode} requested but '{bwrap_bin}' not found in PATH"
        )


def prefix_with_sandbox(
    command: list[str],
    run_dir: Path,
    sandbox_mode: str,
    bwrap_bin: str,
) -> list[str]:
    if sandbox_mode == "none":
        return command
    if sandbox_mode != "bwrap":
        raise ValueError(f"Unsupported sandbox mode: {sandbox_mode}")
    run_dir_abs = run_dir.resolve()
    run_dir_str = str(run_dir_abs)
    home_dir = os.environ.get("HOME", run_dir_str)
    xdg_config_home = os.environ.get("XDG_CONFIG_HOME", f"{home_dir}/.config")
    wrapped: list[str] = [
        bwrap_bin,
        "--die-with-parent",
        "--new-session",
        "--unshare-all",
        "--share-net",
        "--ro-bind", "/", "/",
        "--proc", "/proc",
        "--dev", "/dev",
        "--tmpfs", "/tmp",
        "--tmpfs", "/run",
        "--bind", run_dir_str, run_dir_str,
        "--chdir", run_dir_str,
        "--setenv", "HOME", home_dir,
        "--setenv", "XDG_CONFIG_HOME", xdg_config_home,
        "--setenv", "XDG_CACHE_HOME", f"{run_dir_str}/.cache",
        "--setenv", "XDG_DATA_HOME", f"{run_dir_str}/.local/share",
        "--setenv", "XDG_STATE_HOME", f"{run_dir_str}/.local/state",
        "--setenv", "TMPDIR", "/tmp",
        "--",
    ]
    wrapped.extend(command)
    return wrapped


def run_follow_up(
    session_id: str,
    message: str,
    workspace: Path,
    agent: str,
    model: str,
    sandbox_mode: str = "none",
    bwrap_bin: str = "bwrap",
) -> dict[str, Any]:
    command = [
        "opencode",
        "run",
        "--dir",
        str(workspace.resolve()),
        "--agent",
        agent,
        "--format",
        "json",
        "--auto",
        "--session",
        session_id,
        message,
    ]
    if model:
        command.extend(["--model", model])
    command = prefix_with_sandbox(command, workspace, sandbox_mode, bwrap_bin)
    try:
        completed = subprocess.run(
            command,
            cwd=workspace,
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            check=False,
            timeout=RUN_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return {
            "returncode": 124,
            "stdout": "",
            "stderr": f"timeout after {RUN_TIMEOUT_SECONDS}s",
            "last_text": "",
            "session_id": session_id,
            "error": "timeout",
        }
    events = parse_jsonl_events(completed.stdout)
    last_text = extract_last_text(events)
    return {
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "last_text": last_text,
        "session_id": session_id,
        "error": None if completed.returncode == 0 else f"opencode exit {completed.returncode}",
    }


def prepare_workspace(repo_root: Path, fixture_name: str | None = None) -> Path:
    """Copy fixture (if any) + .opencode + .agents + AGENTS.md into temp workspace."""
    ws = Path(tempfile.mkdtemp(prefix="rdval-"))
    if fixture_name:
        fixture_src = FIXTURES_DIR / fixture_name
        if fixture_src.is_dir():
            shutil.copytree(fixture_src, ws, symlinks=False, dirs_exist_ok=True)
        else:
            print(f"  ⚠️  Fixture not found: {fixture_src}", file=sys.stderr)
    for name in (".opencode", ".agents"):
        src = repo_root / name
        if src.is_dir():
            shutil.copytree(src, ws / name, symlinks=False, dirs_exist_ok=True)
    agents_md = repo_root / "AGENTS.md"
    if agents_md.is_file():
        shutil.copy2(agents_md, ws / "AGENTS.md")
    return ws


def run_one(
    prompt: str,
    workspace: Path,
    agent: str,
    model: str,
    follow_ups: list[str] | None = None,
    max_follow_up_turns: int = 5,
    sandbox_mode: str = "none",
    bwrap_bin: str = "bwrap",
) -> dict[str, Any]:
    first_command = [
        "opencode",
        "run",
        "--dir",
        str(workspace.resolve()),
        "--agent",
        agent,
        "--format",
        "json",
        "--auto",
        prompt,
    ]
    if model:
        first_command.extend(["--model", model])
    first_command = prefix_with_sandbox(first_command, workspace, sandbox_mode, bwrap_bin)
    try:
        completed = subprocess.run(
            first_command,
            cwd=workspace,
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            check=False,
            timeout=RUN_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return {
            "returncode": 124,
            "stdout": "",
            "stderr": f"timeout after {RUN_TIMEOUT_SECONDS}s",
            "last_text": "",
            "session_id": None,
            "turns": [],
            "error": "timeout",
        }
    events = parse_jsonl_events(completed.stdout)
    last_text = extract_last_text(events)
    session_id = extract_session_id(events)

    turns_log = [{
        "turn": 1,
        "returncode": completed.returncode,
        "last_text": last_text,
        "error": None if completed.returncode == 0 else f"opencode exit {completed.returncode}",
    }]

    if follow_ups and session_id and completed.returncode == 0:
        capped = follow_ups[:max_follow_up_turns]
        for i, msg in enumerate(capped, start=2):
            print(f"  Follow-up turn {i}: sending", flush=True)
            fu_result = run_follow_up(
                session_id, msg, workspace, agent, model,
                sandbox_mode=sandbox_mode,
                bwrap_bin=bwrap_bin,
            )
            turns_log.append({
                "turn": i,
                "returncode": fu_result["returncode"],
                "last_text": fu_result["last_text"],
                "error": fu_result["error"],
            })
            if fu_result["error"]:
                break
            last_text = fu_result["last_text"]

    return {
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "last_text": last_text,
        "session_id": session_id,
        "turns": turns_log,
        "error": None if completed.returncode == 0 else f"opencode exit {completed.returncode}",
    }


def match_signals_substring(response_text: str, expected: list[str]) -> tuple[bool, list[str]]:
    haystack = response_text.lower()
    missing = [s for s in expected if s.lower() not in haystack]
    return (not missing, missing)


def judge_one_signal(
    response_text: str,
    signal: str,
    notes: str,
    model: str,
) -> tuple[bool, str]:
    """Neutral LLM judge for one signal. Returns (passed, reason)."""
    judge_prompt = (
        "Validation judge. Does the response exhibit the behavior described below?\n\n"
        f"Behavior: {notes}\n"
        f"Reference label: {signal} (response need not use this exact word)\n\n"
        f"Response:\n{response_text[:2000]}\n\n"
        "First line: YES or NO. Second line: one-sentence reason."
    )
    judge_dir = Path(tempfile.mkdtemp(prefix="rdval-judge-"))
    try:
        command = [
            "opencode", "run",
            "--dir", str(judge_dir.resolve()),
            "--format", "json",
            judge_prompt,
        ]
        if model:
            command.extend(["--model", model])
        try:
            completed = subprocess.run(
                command,
                cwd=judge_dir,
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
                check=False,
                timeout=RUN_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            return (False, "judge timeout")
        events = parse_jsonl_events(completed.stdout)
        judge_text = extract_last_text(events)
        lines = judge_text.strip().splitlines() if judge_text.strip() else []
        first_line = lines[0].strip() if lines else ""
        reason = lines[1].strip() if len(lines) > 1 else ""
        if first_line.upper().startswith("YES"):
            return (True, reason or "judge: yes")
        if first_line.upper().startswith("NO"):
            return (False, reason or "judge: no")
        return (False, f"judge ambiguous: {first_line[:80]}")
    finally:
        shutil.rmtree(judge_dir, ignore_errors=True)


def match_signals_judge(
    response_text: str,
    expected: list[str],
    notes: str,
    model: str,
) -> tuple[bool, list[str], dict[str, str]]:
    verdicts: dict[str, str] = {}
    missing: list[str] = []
    for signal in expected:
        passed, reason = judge_one_signal(response_text, signal, notes, model)
        verdicts[signal] = ("PASS: " if passed else "FAIL: ") + reason
        if not passed:
            missing.append(signal)
    return (not missing, missing, verdicts)


def match_signals_hybrid(
    response_text: str,
    expected: list[str],
    notes: str,
    model: str,
) -> tuple[bool, list[str], dict[str, str]]:
    verdicts: dict[str, str] = {}
    haystack = response_text.lower()
    to_judge: list[str] = []
    for signal in expected:
        if signal.lower() in haystack:
            verdicts[signal] = "PASS: substring"
        else:
            to_judge.append(signal)
    missing: list[str] = []
    for signal in to_judge:
        passed, reason = judge_one_signal(response_text, signal, notes, model)
        verdicts[signal] = ("PASS: " if passed else "FAIL: ") + reason
        if not passed:
            missing.append(signal)
    return (not missing, missing, verdicts)


def main() -> int:
    args = parse_args()

    if not args.test_file.is_file():
        print(f"Error: test file not found: {args.test_file}", file=sys.stderr)
        return 2

    if shutil.which("opencode") is None:
        print("Error: opencode not found in PATH", file=sys.stderr)
        return 2

    try:
        ensure_sandbox(args.sandbox, args.sandbox_bwrap_bin)
    except FileNotFoundError as e:
        print(f"Warning: {e}. Falling back to --sandbox none.", file=sys.stderr)
        args.sandbox = "none"

    args.results_dir.mkdir(parents=True, exist_ok=True)

    tests = json.loads(args.test_file.read_text())["tests"]
    filter_ids = {x.strip() for x in args.filter.split(",") if x.strip()}
    severity_filter = args.severity.strip()

    print("Rubber Duck Validation Test Runner")
    print("===================================")
    print(f"Agent: {args.agent}")
    print(f"Test file: {args.test_file}")
    print(f"Results dir: {args.results_dir}")
    if filter_ids:
        print(f"Filter: {','.join(sorted(filter_ids))}")
    if severity_filter:
        print(f"Severity filter: {severity_filter}")
    print(f"Matcher: {args.matcher}")
    print()

    passed = 0
    failed = 0
    skipped = 0
    errored = 0

    for test in tests:
        tid = test["id"]
        area = test["area"]
        prompt = test["prompt"]
        expected = test["expected_signals"]
        severity = test["severity"]

        if filter_ids and tid not in filter_ids:
            skipped += 1
            continue
        if severity_filter and severity != severity_filter:
            skipped += 1
            continue

        print(f"[{tid}] {area} ({severity})")
        preview = prompt.replace("\n", " ")[:80]
        print(f"Prompt: {preview}...")
        print(f"Expected signals: {', '.join(expected)}")

        workspace = prepare_workspace(REPO_ROOT, fixture_name=test.get("fixture"))
        try:
            result = run_one(
                prompt,
                workspace,
                args.agent,
                args.model,
                follow_ups=test.get("follow_ups"),
                max_follow_up_turns=args.max_follow_up_turns,
                sandbox_mode=args.sandbox,
                bwrap_bin=args.sandbox_bwrap_bin,
            )
        finally:
            if not args.keep_workspaces:
                shutil.rmtree(workspace, ignore_errors=True)

        response_file = args.results_dir / f"{tid}.json"
        verdicts: dict[str, str] = {}
        if result["error"]:
            errored += 1
            print(f"  ❌ ERROR: {result['error']}")
        else:
            notes = test.get("notes", "")
            if args.matcher == "substring":
                ok, missing = match_signals_substring(result["last_text"], expected)
            elif args.matcher == "judge":
                ok, missing, verdicts = match_signals_judge(result["last_text"], expected, notes, args.model)
            else:  # hybrid
                ok, missing, verdicts = match_signals_hybrid(result["last_text"], expected, notes, args.model)
            snippet = result["last_text"].strip().split("\n")[0][:120]
            if ok:
                passed += 1
                print("  ✅ PASS")
                print(f"  Snippet: {snippet}")
            else:
                failed += 1
                print(f"  ❌ FAIL — missing: {', '.join(missing)}")
                print(f"  Snippet: {snippet}")
                for sig in missing:
                    v = verdicts.get(sig)
                    if v:
                        print(f"    {sig}: {v}")
        response_file.write_text(
            json.dumps(
                {
                    "test_id": tid,
                    "area": area,
                    "prompt": prompt,
                    "expected_signals": expected,
                    "severity": severity,
                    "matcher": args.matcher,
                    "verdicts": verdicts,
                    "result": result,
                },
                indent=2,
                ensure_ascii=False,
            )
        )
        print(f"  Response: {response_file}")

        if args.interactive:
            try:
                input("Press enter to continue...")
            except KeyboardInterrupt:
                print("\nAborted.", file=sys.stderr)
                return 2

        print()

    print("Results")
    print("=======")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Errored: {errored}")
    print(f"Skipped: {skipped}")
    print()

    if errored > 0:
        print("❌ Some tests errored")
        return 2
    if failed > 0:
        print("❌ Some tests failed")
        return 1
    if passed == 0:
        print("⚠️ No tests executed")
        return 0
    print("✅ All tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

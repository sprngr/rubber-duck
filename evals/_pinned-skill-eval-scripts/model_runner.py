#!/usr/bin/env python3
"""Provider adapter for run_fresh.py.

Reads one request JSON from stdin and writes one response JSON to stdout.
Current provider implementation: opencode CLI with Copilot-backed model IDs.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import tempfile
from typing import Any


def fail(request_id: str, code: str, message: str, duration_ms: int = 0) -> dict[str, Any]:
    return {
        "request_id": request_id,
        "status": "error",
        "output": {"text": ""},
        "usage": {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0},
        "timing": {"duration_ms": duration_ms},
        "model": {"id": "unknown", "provider": "copilot"},
        "error": {"code": code, "message": message[:1200]},
    }


def build_message(req: dict[str, Any]) -> str:
    mode = req.get("mode", "without_skill")
    prompt = req.get("input", {}).get("prompt", "")
    skill_text = req.get("input", {}).get("skill_text")
    purpose = str(req.get("meta", {}).get("purpose", "")).lower()

    if purpose == "calibration":
        return "Using the attached context, reply with exactly: OK"

    if mode == "with_skill" and skill_text:
        return (
            "Use the attached file content as the full skill instructions + task prompt. "
            "Follow the skill instructions first. Return only your final response text."
        )
    return prompt


def build_attachment_text(req: dict[str, Any]) -> str:
    mode = req.get("mode", "without_skill")
    prompt = req.get("input", {}).get("prompt", "")
    skill_text = req.get("input", {}).get("skill_text")
    if mode == "with_skill" and skill_text:
        return (
            "[SKILL INSTRUCTIONS]\n"
            f"{skill_text}\n\n"
            "[TASK]\n"
            f"{prompt}\n"
        )
    return f"[TASK]\n{prompt}\n"


def parse_opencode_events(stdout_text: str) -> tuple[str, dict[str, int], int]:
    text_parts: list[str] = []
    usage = {
        "input_tokens": 0,
        "output_tokens": 0,
        "reasoning_tokens": 0,
        "cache_read_tokens": 0,
        "cache_write_tokens": 0,
        "total_tokens": 0,
    }
    step_start = None
    step_finish = None

    for line in stdout_text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue

        et = ev.get("type")
        ts = ev.get("timestamp")
        part = ev.get("part", {})
        if et == "step_start" and isinstance(ts, int):
            step_start = ts
        elif et == "text":
            txt = part.get("text")
            if isinstance(txt, str) and txt:
                text_parts.append(txt)
        elif et == "step_finish":
            if isinstance(ts, int):
                step_finish = ts
            tok = part.get("tokens", {})
            if isinstance(tok, dict):
                usage["total_tokens"] = int(tok.get("total", 0) or 0)
                usage["input_tokens"] = int(tok.get("input", 0) or 0)
                usage["output_tokens"] = int(tok.get("output", 0) or 0)
                usage["reasoning_tokens"] = int(tok.get("reasoning", 0) or 0)
                cache = tok.get("cache", {})
                if isinstance(cache, dict):
                    usage["cache_read_tokens"] = int(cache.get("read", 0) or 0)
                    usage["cache_write_tokens"] = int(cache.get("write", 0) or 0)

    output_text = "\n".join(text_parts).strip()
    duration_ms = 0
    if isinstance(step_start, int) and isinstance(step_finish, int) and step_finish >= step_start:
        duration_ms = step_finish - step_start
    return output_text, usage, duration_ms


def main() -> int:
    started = time.time()
    raw = sys.stdin.read()
    try:
        req = json.loads(raw)
    except json.JSONDecodeError:
        print(json.dumps(fail("unknown", "invalid_request", "stdin is not valid JSON")))
        return 0

    request_id = str(req.get("request_id", "unknown"))
    model_id = str(req.get("model", {}).get("id", "github-copilot/gpt-5.3-codex"))
    timeout_sec = int(req.get("limits", {}).get("timeout_sec", 180) or 180)
    message = build_message(req)

    attachment = build_attachment_text(req)
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as tf:
        tf.write(attachment)
        attach_path = tf.name

    cmd = [
        "opencode",
        "run",
        "--model",
        model_id,
        "--format",
        "json",
        "--file",
        attach_path,
        "--",
        message,
    ]

    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_sec,
            env=os.environ.copy(),
            check=False,
        )
    except subprocess.TimeoutExpired:
        duration_ms = int((time.time() - started) * 1000)
        try:
            os.unlink(attach_path)
        except OSError:
            pass
        print(json.dumps(fail(request_id, "timeout", "opencode run timed out", duration_ms)))
        return 0

    duration_ms = int((time.time() - started) * 1000)
    try:
        os.unlink(attach_path)
    except OSError:
        pass
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", errors="ignore")
        print(json.dumps(fail(request_id, "provider_error", err or f"opencode exited {proc.returncode}", duration_ms)))
        return 0

    stdout_text = proc.stdout.decode("utf-8", errors="ignore")
    text, usage, event_duration_ms = parse_opencode_events(stdout_text)
    if not text:
        print(json.dumps(fail(request_id, "empty_output", "no text returned by opencode", duration_ms)))
        return 0

    resp = {
        "request_id": request_id,
        "status": "ok",
        "output": {"text": text},
        "usage": usage,
        "timing": {
            "duration_ms": int(event_duration_ms or duration_ms),
        },
        "model": {
            "id": model_id,
            "provider": "copilot",
        },
        "error": None,
    }
    print(json.dumps(resp))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

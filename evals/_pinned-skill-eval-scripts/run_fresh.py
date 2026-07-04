#!/usr/bin/env python3
"""Run full eval generation + grading + aggregation for duck skills.

Safety defaults:
- writes only under <out-root>/<iteration>
- optional subprocess limits (timeout + memory) for external runner
- env allowlist for external runner

This script supports two execution modes:
1) external runner via --runner-cmd (preferred for true-fresh model outputs)
2) built-in mock fallback (when --runner-cmd is omitted)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import resource
import shlex
import subprocess
import time
import hashlib
from pathlib import Path


DEFAULT_SKILLS = [
    "duck-debug",
    "duck-review",
    "duck-explain",
    "duck-teach",
    "duck-design",
    "duck-triage",
    "duck-debt",
]


def real(p: Path) -> Path:
    return Path(os.path.realpath(str(p)))


def under(root: Path, target: Path) -> bool:
    r = str(real(root))
    t = str(real(target))
    return t == r or t.startswith(r + os.sep)


def assert_under(root: Path, target: Path) -> None:
    if not under(root, target):
        raise RuntimeError(f"boundary violation: {target} not under {root}")


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def write_text_safe(root: Path, path: Path, content: str) -> None:
    assert_under(root, path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def write_json_safe(root: Path, path: Path, payload: dict) -> None:
    write_text_safe(root, path, json.dumps(payload, indent=2) + "\n")


def build_env(allowlist_csv: str) -> dict:
    env = {"PATH": os.environ.get("PATH", "")}
    # Minimal runtime env needed for CLI auth/config resolution.
    for key in ["HOME", "USER", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"]:
        if key in os.environ:
            env[key] = os.environ[key]
    for key in [x.strip() for x in allowlist_csv.split(",") if x.strip()]:
        if key in os.environ:
            env[key] = os.environ[key]
    return env


def set_mem_limit(memory_mb: int):
    limit = memory_mb * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_AS, (limit, limit))


def run_external_runner(
    runner_cmd: str,
    request: dict,
    timeout_sec: int,
    memory_mb: int,
    env: dict,
    disable_memory_limit: bool,
) -> dict:
    cmd = shlex.split(runner_cmd)
    started = time.time()
    proc = subprocess.run(
        cmd,
        input=json.dumps(request).encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout_sec,
        env=env,
        preexec_fn=(None if disable_memory_limit else (lambda: set_mem_limit(memory_mb))),
        check=False,
    )
    duration_ms = int((time.time() - started) * 1000)
    if proc.returncode != 0:
        raise RuntimeError(f"runner failed ({proc.returncode}): {proc.stderr.decode('utf-8', errors='ignore')[-500:]}")

    payload = json.loads(proc.stdout.decode("utf-8"))
    if payload.get("request_id") != request.get("request_id"):
        raise RuntimeError("runner response request_id mismatch")
    if payload.get("status") not in {"ok", "error"}:
        raise RuntimeError("runner response status invalid")
    if "usage" not in payload or "total_tokens" not in payload.get("usage", {}):
        raise RuntimeError("runner response missing usage.total_tokens")
    if "timing" not in payload or "duration_ms" not in payload.get("timing", {}):
        raise RuntimeError("runner response missing timing.duration_ms")
    payload.setdefault("timing", {})
    payload.setdefault("usage", {})
    payload["timing"].setdefault("duration_ms", duration_ms)
    return payload


def run_mock(request: dict) -> dict:
    prompt = request["input"]["prompt"]
    mode = request["mode"]
    started = time.time()
    if mode == "with_skill":
        text = (
            f"Question: What exact constraint should we prioritize first for this prompt?\n"
            f"Plan: {prompt[:220]}\n"
            "Next: Provide one falsifiable check, then refine based on evidence."
        )
    else:
        text = f"Here is a concise response: {prompt[:160]}"

    tokens = max(1, len(re.findall(r"\w+", text)))
    return {
        "request_id": request["request_id"],
        "status": "ok",
        "output": {"text": text},
        "usage": {"input_tokens": 0, "output_tokens": tokens, "total_tokens": tokens},
        "timing": {"duration_ms": int((time.time() - started) * 1000) + 30},
        "model": request.get("model", {}),
        "error": None,
    }


def extract_first_json_object(text: str) -> dict:
    text = text.strip()
    if not text:
        raise ValueError("empty judge output")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("no JSON object found in judge output")
    snippet = text[start : end + 1]
    return json.loads(snippet)


def normalize_assertions(assertions_json: dict, eval_id: int | str) -> list[dict]:
    rows = assertions_json.get("eval_assertions", [])
    for row in rows:
        if str(row.get("eval_id")) == str(eval_id):
            return row.get("assertions", [])
    return []


def grade_response_llm_batch(
    *,
    text: str,
    assertions: list[dict],
    runner_cmd: str,
    timeout_sec: int,
    memory_mb: int,
    env: dict,
    disable_memory_limit: bool,
    request_id: str,
    model_id: str,
    temperature: float,
    seed_mode: str,
) -> dict:
    judge_prompt = (
        "You are an exacting evaluator. Grade candidate response against assertions. "
        "Return ONLY valid JSON, no markdown.\n"
        "Output schema: {\"results\":[{\"id\":string,\"passed\":boolean,\"evidence\":string}]}\n"
        "Rules: passed=true only if assertion is explicitly satisfied by the response text. "
        "Use short evidence quote/snippet from response.\n\n"
        f"Assertions JSON:\n{json.dumps(assertions, ensure_ascii=False)}\n\n"
        f"Candidate response:\n{text}"
    )

    req = {
        "request_id": f"{request_id}.judge",
        "mode": "judge",
        "model": {"id": model_id, "temperature": temperature, "seed_mode": seed_mode},
        "input": {
            "prompt": judge_prompt,
            "skill_text": None,
            "files": [],
        },
        "limits": {"timeout_sec": min(120, timeout_sec), "max_output_tokens": 1200},
        "meta": {"purpose": "grading"},
    }

    resp = run_external_runner(
        runner_cmd,
        req,
        timeout_sec=min(120, timeout_sec),
        memory_mb=memory_mb,
        env=env,
        disable_memory_limit=disable_memory_limit,
    )
    if resp.get("status") != "ok":
        err = resp.get("error", {})
        raise RuntimeError(f"judge runner error: {err.get('code')} {err.get('message')}")

    obj = extract_first_json_object(resp.get("output", {}).get("text", ""))
    rows = obj.get("results", [])
    by_id = {str(r.get("id")): r for r in rows if isinstance(r, dict)}

    results = []
    passed = 0
    for a in assertions:
        aid = str(a.get("id", ""))
        row = by_id.get(aid, {})
        ok = bool(row.get("passed", False))
        ev = str(row.get("evidence", ""))[:500]
        if ok:
            passed += 1
        results.append(
            {
                "id": a.get("id"),
                "text": a.get("text", ""),
                "passed": ok,
                "evidence": ev,
                "graded_by": "llm",
            }
        )

    total = len(results)
    return {
        "assertion_results": results,
        "summary": {
            "passed": passed,
            "failed": total - passed,
            "pending_llm": 0,
            "total_determined": total,
            "total": total,
            "pass_rate": round((passed / total), 4) if total else 0.0,
        },
    }


def grade_response(text: str, assertions: list[dict]) -> dict:
    lowered = text.lower()
    results = []
    passed = 0

    for a in assertions:
        a_text = a.get("text", "")
        quoted = re.findall(r"['\"]([^'\"]+)['\"]", a_text)
        if quoted:
            ok = any(q.lower() in lowered for q in quoted)
            evidence = f"quoted_match={ok}"
        else:
            words = [w for w in re.findall(r"[a-zA-Z]{5,}", a_text.lower()) if w not in {"before", "after", "under", "without", "should", "would"}]
            sample = words[:5]
            hits = sum(1 for w in sample if w in lowered)
            ok = hits >= 1 if sample else (len(text.strip()) > 0)
            evidence = f"keyword_hits={hits}/{len(sample)}"

        if ok:
            passed += 1
        results.append(
            {
                "id": a.get("id"),
                "text": a_text,
                "passed": ok,
                "evidence": evidence,
                "graded_by": "heuristic",
            }
        )

    total = len(results)
    return {
        "assertion_results": results,
        "summary": {
            "passed": passed,
            "failed": total - passed,
            "pending_llm": 0,
            "total_determined": total,
            "total": total,
            "pass_rate": round((passed / total), 4) if total else 0.0,
        },
    }


def run_cmd(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if proc.returncode != 0:
        raise RuntimeError(
            f"command failed: {' '.join(cmd)}\n"
            f"stdout={proc.stdout.decode('utf-8', errors='ignore')[-800:]}\n"
            f"stderr={proc.stderr.decode('utf-8', errors='ignore')[-800:]}"
        )


def calibrate_token_overhead(
    *,
    runner_cmd: str,
    model_id: str,
    temperature: float,
    seed_mode: str,
    timeout_sec: int,
    memory_mb: int,
    env: dict,
    disable_memory_limit: bool,
    mode: str,
    skill_text: str | None,
    sample_count: int,
) -> dict:
    samples = []
    for i in range(sample_count):
        req = {
            "request_id": f"calibration.{mode}.{i+1}",
            "mode": mode,
            "model": {"id": model_id, "temperature": temperature, "seed_mode": seed_mode},
            "input": {
                "prompt": "Calibration sample.",
                "skill_text": skill_text if mode == "with_skill" else None,
                "files": [],
            },
            "limits": {"timeout_sec": min(90, timeout_sec), "max_output_tokens": 64},
            "meta": {"purpose": "calibration"},
        }
        resp = run_external_runner(
            runner_cmd,
            req,
            timeout_sec=min(90, timeout_sec),
            memory_mb=memory_mb,
            env=env,
            disable_memory_limit=disable_memory_limit,
        )
        if resp.get("status") != "ok":
            err = resp.get("error", {})
            raise RuntimeError(f"calibration failed for {mode}: {err.get('code')} {err.get('message')}")
        samples.append(int(resp.get("usage", {}).get("total_tokens", 0)))

    if not samples:
        return {"sample_count": 0, "samples": [], "median_total_tokens": 0}
    s = sorted(samples)
    median = s[len(s) // 2]
    return {"sample_count": len(samples), "samples": samples, "median_total_tokens": int(median)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--iteration", required=True)
    ap.add_argument("--out-root", required=True)
    ap.add_argument("--skills", default=",".join(DEFAULT_SKILLS))
    ap.add_argument("--runner-cmd", default="")
    ap.add_argument("--model-id", default="unknown")
    ap.add_argument("--temperature", type=float, default=0)
    ap.add_argument("--seed-mode", default="fixed")
    ap.add_argument("--timeout-sec", type=int, default=180)
    ap.add_argument("--memory-mb", type=int, default=1024)
    ap.add_argument("--disable-memory-limit", action="store_true")
    ap.add_argument("--env-allowlist", default="")
    ap.add_argument("--grading-mode", choices=["heuristic", "llm"], default="llm")
    ap.add_argument("--token-normalization", choices=["none", "calibrated"], default="none")
    ap.add_argument("--token-calibration-samples", type=int, default=3)
    ap.add_argument("--compare-a", required=True)
    ap.add_argument("--compare-b", required=True)
    args = ap.parse_args()

    repo_root = real(Path(args.repo_root))
    out_root = real(Path(args.out_root))
    iteration_dir = real(out_root / args.iteration)
    assert_under(out_root, iteration_dir)
    iteration_dir.mkdir(parents=True, exist_ok=True)

    skills = [s.strip() for s in args.skills.split(",") if s.strip()]
    env = build_env(args.env_allowlist)
    run_log = iteration_dir / "run-log.jsonl"

    def log(event: dict) -> None:
        assert_under(out_root, run_log)
        with run_log.open("a", encoding="utf-8") as f:
            f.write(json.dumps(event) + "\n")

    manifest = {
        "iteration": args.iteration,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "repo_root": str(repo_root),
        "out_root": str(out_root),
        "model": {"id": args.model_id, "temperature": args.temperature, "seed_mode": args.seed_mode},
        "limits": {"timeout_sec": args.timeout_sec, "memory_mb": args.memory_mb},
        "runner": {
            "cmd": args.runner_cmd or "mock",
            "cmd_sha256": hashlib.sha256((args.runner_cmd or "mock").encode("utf-8")).hexdigest(),
            "memory_limit_disabled": bool(args.disable_memory_limit),
            "grading_mode": args.grading_mode,
            "token_normalization": args.token_normalization,
        },
        "skills": skills,
        "inputs": {},
    }

    for skill in skills:
        evals_path = repo_root / "evals" / skill / "evals.json"
        assertions_path = repo_root / "evals" / skill / "assertions.json"
        skill_md_path = repo_root / "skills" / skill / "SKILL.md"
        if not (evals_path.exists() and assertions_path.exists() and skill_md_path.exists()):
            raise RuntimeError(f"missing required files for {skill}")

        evals_json = read_json(evals_path)
        assertions_json = read_json(assertions_path)
        skill_text = skill_md_path.read_text(encoding="utf-8")
        manifest["inputs"][skill] = {
            "evals": str(evals_path),
            "assertions": str(assertions_path),
            "skill_md": str(skill_md_path),
            "evals_sha256": sha256_file(evals_path),
            "assertions_sha256": sha256_file(assertions_path),
            "skill_md_sha256": sha256_file(skill_md_path),
        }

        normalization_meta = {
            "method": args.token_normalization,
            "with_skill_overhead_tokens": 0,
            "without_skill_overhead_tokens": 0,
        }
        if args.token_normalization == "calibrated":
            if not args.runner_cmd:
                raise RuntimeError("token calibration requires --runner-cmd")
            with_cal = calibrate_token_overhead(
                runner_cmd=args.runner_cmd,
                model_id=args.model_id,
                temperature=args.temperature,
                seed_mode=args.seed_mode,
                timeout_sec=args.timeout_sec,
                memory_mb=args.memory_mb,
                env=env,
                disable_memory_limit=args.disable_memory_limit,
                mode="with_skill",
                skill_text=skill_text,
                sample_count=max(1, args.token_calibration_samples),
            )
            without_cal = calibrate_token_overhead(
                runner_cmd=args.runner_cmd,
                model_id=args.model_id,
                temperature=args.temperature,
                seed_mode=args.seed_mode,
                timeout_sec=args.timeout_sec,
                memory_mb=args.memory_mb,
                env=env,
                disable_memory_limit=args.disable_memory_limit,
                mode="without_skill",
                skill_text=None,
                sample_count=max(1, args.token_calibration_samples),
            )
            normalization_meta = {
                "method": "calibrated",
                "with_skill_overhead_tokens": int(with_cal.get("median_total_tokens", 0)),
                "without_skill_overhead_tokens": int(without_cal.get("median_total_tokens", 0)),
                "with_skill_samples": with_cal,
                "without_skill_samples": without_cal,
            }

        manifest["inputs"][skill]["token_normalization"] = normalization_meta

        skill_dir = iteration_dir / skill
        for ev in evals_json.get("evals", []):
            eval_id = ev.get("id")
            prompt = ev.get("prompt", "")
            assertions = normalize_assertions(assertions_json, eval_id)

            for mode in ["with_skill", "without_skill"]:
                request_id = f"{skill}.eval-{eval_id}.{mode}"
                request = {
                    "request_id": request_id,
                    "mode": mode,
                    "model": {"id": args.model_id, "temperature": args.temperature, "seed_mode": args.seed_mode},
                    "input": {
                        "prompt": prompt,
                        "skill_text": skill_text if mode == "with_skill" else None,
                        "files": ev.get("files", []),
                    },
                    "limits": {"timeout_sec": args.timeout_sec, "max_output_tokens": 4000},
                    "meta": {"skill": skill, "eval_id": eval_id, "iteration": args.iteration},
                }

                started = time.time()
                if args.runner_cmd:
                    response = run_external_runner(
                        args.runner_cmd,
                        request,
                        timeout_sec=args.timeout_sec,
                        memory_mb=args.memory_mb,
                        env=env,
                        disable_memory_limit=args.disable_memory_limit,
                    )
                else:
                    response = run_mock(request)

                if response.get("status") != "ok":
                    err = response.get("error", {})
                    raise RuntimeError(f"runner error: {err.get('code')} {err.get('message')}")

                text = response.get("output", {}).get("text", "")
                usage = response.get("usage", {})
                raw_total_tokens = int(usage.get("total_tokens", 0))
                input_tokens = int(usage.get("input_tokens", 0))
                output_tokens = int(usage.get("output_tokens", 0))
                reasoning_tokens = int(usage.get("reasoning_tokens", 0))
                cache_read_tokens = int(usage.get("cache_read_tokens", 0))
                cache_write_tokens = int(usage.get("cache_write_tokens", 0))

                overhead = 0
                if args.token_normalization == "calibrated":
                    if mode == "with_skill":
                        overhead = int(normalization_meta.get("with_skill_overhead_tokens", 0))
                    else:
                        overhead = int(normalization_meta.get("without_skill_overhead_tokens", 0))
                normalized_total_tokens = max(0, raw_total_tokens - overhead)
                duration_ms = int(response.get("timing", {}).get("duration_ms", int((time.time() - started) * 1000)))

                variant_dir = skill_dir / f"eval-{eval_id}" / mode
                response_path = variant_dir / "outputs" / "response.txt"
                timing_path = variant_dir / "timing.json"
                grading_path = variant_dir / "grading.json"

                write_text_safe(out_root, response_path, text)
                write_json_safe(
                    out_root,
                    timing_path,
                    {
                        "raw_total_tokens": raw_total_tokens,
                        "normalized_total_tokens": normalized_total_tokens,
                        "token_overhead_estimate": overhead,
                        "input_tokens": input_tokens,
                        "output_tokens": output_tokens,
                        "reasoning_tokens": reasoning_tokens,
                        "cache_read_tokens": cache_read_tokens,
                        "cache_write_tokens": cache_write_tokens,
                        "token_normalization": args.token_normalization,
                        "total_tokens": normalized_total_tokens,
                        "duration_ms": duration_ms,
                        "model_id": args.model_id,
                        "temperature": args.temperature,
                        "seed_mode": args.seed_mode,
                    },
                )
                if args.grading_mode == "llm":
                    if not args.runner_cmd:
                        raise RuntimeError("--grading-mode llm requires --runner-cmd")
                    grading = grade_response_llm_batch(
                        text=text,
                        assertions=assertions,
                        runner_cmd=args.runner_cmd,
                        timeout_sec=args.timeout_sec,
                        memory_mb=args.memory_mb,
                        env=env,
                        disable_memory_limit=args.disable_memory_limit,
                        request_id=request_id,
                        model_id=args.model_id,
                        temperature=args.temperature,
                        seed_mode=args.seed_mode,
                    )
                else:
                    grading = grade_response(text, assertions)

                write_json_safe(out_root, grading_path, grading)

                log(
                    {
                        "ts": time.time(),
                        "skill": skill,
                        "eval": str(eval_id),
                        "variant": mode,
                        "status": "ok",
                        "tokens": normalized_total_tokens,
                        "raw_total_tokens": raw_total_tokens,
                        "normalized_total_tokens": normalized_total_tokens,
                        "duration_ms": duration_ms,
                        "model_id": args.model_id,
                    }
                )

        run_cmd([str(repo_root / "evals/_pinned-skill-eval-scripts/aggregate-benchmark.sh"), str(skill_dir)])

    write_json_safe(out_root, iteration_dir / "manifest.json", manifest)

    run_cmd(
        [
            "python3",
            str(repo_root / "evals/_pinned-skill-eval-scripts/aggregate_global.py"),
            "--iteration-dir",
            str(iteration_dir),
            "--compare-a",
            str(real(Path(args.compare_a))),
            "--compare-b",
            str(real(Path(args.compare_b))),
        ]
    )

    print(f"Run complete: {iteration_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

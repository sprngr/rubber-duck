#!/usr/bin/env python3
"""Aggregate per-skill benchmark.json files into global + comparison deltas.

Usage:
  aggregate_global.py --iteration-dir <dir> --compare-a <global.json> --compare-b <global.json>
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")


def r4(v: float) -> float:
    return round(float(v), 4)


def r1(v: float) -> float:
    return round(float(v), 1)


def r2(v: float) -> float:
    return round(float(v), 2)


def to_key(iteration_name: str) -> str:
    return iteration_name.replace("-", "_")


def build_global(iteration_dir: Path) -> dict:
    skill_benchmarks = sorted(iteration_dir.glob("*/benchmark.json"))
    if not skill_benchmarks:
        raise RuntimeError(f"No per-skill benchmark files found under {iteration_dir}")

    skills = {}
    pass_deltas: list[float] = []
    token_deltas: list[float] = []
    time_deltas: list[float] = []

    for bench_path in skill_benchmarks:
        skill = bench_path.parent.name
        b = read_json(bench_path)
        summary = b.get("run_summary", {})
        delta = summary.get("delta", {})
        pass_deltas.append(float(delta.get("pass_rate", 0.0)))
        token_deltas.append(float(delta.get("tokens", 0.0)))
        time_deltas.append(float(delta.get("time_seconds", 0.0)))

        skills[skill] = {
            "eval_count": b.get("eval_count", 0),
            "with_skill": summary.get("with_skill", {}),
            "without_skill": summary.get("without_skill", {}),
            "delta": {
                "pass_rate": r4(delta.get("pass_rate", 0.0)),
                "tokens": r1(delta.get("tokens", 0.0)),
                "time_seconds": r2(delta.get("time_seconds", 0.0)),
            },
        }

    count = len(pass_deltas)
    global_payload = {
        "iteration": iteration_dir.name,
        "skills": skills,
        "aggregate": {
            "count": count,
            "mean_delta": {
                "pass_rate": r4(sum(pass_deltas) / count),
                "tokens": r1(sum(token_deltas) / count),
                "time_seconds": r2(sum(time_deltas) / count),
            },
        },
    }
    return global_payload


def build_comparison(current: dict, baseline: dict) -> dict:
    curr_iter = current.get("iteration", "current")
    base_iter = baseline.get("iteration", "baseline")
    curr_key = to_key(curr_iter)
    base_key = to_key(base_iter)

    curr_mean = current.get("aggregate", {}).get("mean_delta", {})
    base_mean = baseline.get("aggregate", {}).get("mean_delta", {})

    payload = {
        "iteration": curr_iter,
        "compared_to": base_iter,
        f"{curr_key}_mean_delta": {
            "pass_rate": r4(curr_mean.get("pass_rate", 0.0)),
            "tokens": r1(curr_mean.get("tokens", 0.0)),
            "time_seconds": r2(curr_mean.get("time_seconds", 0.0)),
        },
        f"{base_key}_mean_delta": {
            "pass_rate": r4(base_mean.get("pass_rate", 0.0)),
            "tokens": r1(base_mean.get("tokens", 0.0)),
            "time_seconds": r2(base_mean.get("time_seconds", 0.0)),
        },
        f"change_vs_{base_key}": {
            "pass_rate": r4(float(curr_mean.get("pass_rate", 0.0)) - float(base_mean.get("pass_rate", 0.0))),
            "tokens": r1(float(curr_mean.get("tokens", 0.0)) - float(base_mean.get("tokens", 0.0))),
            "time_seconds": r2(float(curr_mean.get("time_seconds", 0.0)) - float(base_mean.get("time_seconds", 0.0))),
        },
        "skills": {},
    }

    curr_skills = current.get("skills", {})
    base_skills = baseline.get("skills", {})
    all_skills = sorted(set(curr_skills.keys()) | set(base_skills.keys()))
    for skill in all_skills:
        c_delta = curr_skills.get(skill, {}).get("delta", {})
        b_delta = base_skills.get(skill, {}).get("delta", {})
        change = {
            "pass_rate": r4(float(c_delta.get("pass_rate", 0.0)) - float(b_delta.get("pass_rate", 0.0))),
            "tokens": r1(float(c_delta.get("tokens", 0.0)) - float(b_delta.get("tokens", 0.0))),
            "time_seconds": r2(float(c_delta.get("time_seconds", 0.0)) - float(b_delta.get("time_seconds", 0.0))),
        }
        payload["skills"][skill] = {
            f"{base_key}_delta": {
                "pass_rate": r4(b_delta.get("pass_rate", 0.0)),
                "tokens": r1(b_delta.get("tokens", 0.0)),
                "time_seconds": r2(b_delta.get("time_seconds", 0.0)),
            },
            f"{curr_key}_delta": {
                "pass_rate": r4(c_delta.get("pass_rate", 0.0)),
                "tokens": r1(c_delta.get("tokens", 0.0)),
                "time_seconds": r2(c_delta.get("time_seconds", 0.0)),
            },
            "change": change,
            "token_delta_improved": change["tokens"] <= 0,
            "pass_rate_maintained": change["pass_rate"] >= 0,
            "time_delta_improved": change["time_seconds"] <= 0,
        }

    return payload


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--iteration-dir", required=True)
    ap.add_argument("--compare-a", required=True)
    ap.add_argument("--compare-b", required=True)
    args = ap.parse_args()

    iteration_dir = Path(args.iteration_dir).resolve()
    compare_a = Path(args.compare_a).resolve()
    compare_b = Path(args.compare_b).resolve()

    global_payload = build_global(iteration_dir)
    global_path = iteration_dir / "global-benchmark.json"
    write_json(global_path, global_payload)

    a_payload = read_json(compare_a)
    b_payload = read_json(compare_b)

    a_delta = build_comparison(global_payload, a_payload)
    b_delta = build_comparison(global_payload, b_payload)

    write_json(iteration_dir / f"delta-vs-{a_payload.get('iteration', 'compare-a')}.json", a_delta)
    write_json(iteration_dir / f"delta-vs-{b_payload.get('iteration', 'compare-b')}.json", b_delta)

    print(f"Wrote {global_path}")
    a_name = a_payload.get("iteration", "compare-a")
    b_name = b_payload.get("iteration", "compare-b")
    print(f"Wrote {iteration_dir / ('delta-vs-' + a_name + '.json')}")
    print(f"Wrote {iteration_dir / ('delta-vs-' + b_name + '.json')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

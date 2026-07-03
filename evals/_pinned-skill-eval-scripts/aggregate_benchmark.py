
#!/usr/bin/env python3
"""Aggregate grading and timing data into benchmark.json.

Reads all grading.json and timing.json files under an iteration directory.
Computes mean, stddev for pass_rate, tokens, duration. Writes delta.
"""

import json
import sys
import os
import glob
import math
from pathlib import Path


def load_json_files(pattern: str) -> list[dict]:
    results = []
    for path in glob.glob(pattern, recursive=True):
        try:
            with open(path) as f:
                results.append(json.load(f))
        except (json.JSONDecodeError, OSError) as e:
            print(f"Warning: could not load {path}: {e}", file=sys.stderr)
    return results


def mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def stddev(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0
    m = mean(values)
    variance = sum((x - m) ** 2 for x in values) / (len(values) - 1)
    return math.sqrt(variance)


def percentile(values: list[float], p: float) -> float:
    """Simple percentile with linear interpolation."""
    if not values:
        return 0.0
    if len(values) == 1:
        return values[0]
    s = sorted(values)
    k = (len(s) - 1) * p
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return s[int(k)]
    d0 = s[f] * (c - k)
    d1 = s[c] * (k - f)
    return d0 + d1


def drop_high_outliers(values: list[float], p: float = 0.95) -> list[float]:
    """Drop values above percentile threshold."""
    if len(values) < 4:
        return values
    cutoff = percentile(values, p)
    return [v for v in values if v <= cutoff]


def extract_metrics(grading_list: list[dict], timing_list: list[dict]) -> dict:
    pass_rates = []
    tokens = []
    durations = []

    for g in grading_list:
        summary = g.get("summary", {})
        total = summary.get("total", 0)
        passed = summary.get("passed", 0)
        if total > 0:
            pass_rates.append(passed / total)

    for t in timing_list:
        tokens.append(t.get("total_tokens", 0))
        durations.append(t.get("duration_ms", 0))

    # Reject obvious timing instrumentation artifacts.
    original_duration_count = len(durations)
    durations = [float(d) for d in durations if isinstance(d, (int, float)) and d > 0]

    pre_outlier_count = len(durations)
    durations_filtered = drop_high_outliers(durations, 0.95)

    return {
        "pass_rate": {
            "mean": round(mean(pass_rates), 4),
            "stddev": round(stddev(pass_rates), 4),
            "samples": len(pass_rates),
        },
        "tokens": {
            "mean": round(mean(tokens), 1),
            "stddev": round(stddev(tokens), 1),
            "samples": len(tokens),
        },
        "time_seconds": {
            "mean": round(mean(durations_filtered) / 1000, 2),
            "stddev": round(stddev(durations_filtered) / 1000, 2),
            "samples": len(durations_filtered),
            "raw_samples": len(durations),
            "excluded_invalid_samples": original_duration_count - len(durations),
            "excluded_outlier_samples": pre_outlier_count - len(durations_filtered),
        },
    }


def main():
    if len(sys.argv) != 2:
        print("Usage: aggregate_benchmark.py <iteration-dir>", file=sys.stderr)
        sys.exit(1)

    iter_dir = sys.argv[1]
    if not os.path.isdir(iter_dir):
        print(f"Error: {iter_dir} not found", file=sys.stderr)
        sys.exit(1)

    # Load all grading.json files split by with_skill vs without_skill
    with_gradings = load_json_files(os.path.join(iter_dir, "**/with_skill/grading.json"))
    without_gradings = load_json_files(os.path.join(iter_dir, "**/without_skill/grading.json"))

    with_timing = load_json_files(os.path.join(iter_dir, "**/with_skill/timing.json"))
    without_timing = load_json_files(os.path.join(iter_dir, "**/without_skill/timing.json"))

    with_metrics = extract_metrics(with_gradings, with_timing)
    without_metrics = extract_metrics(without_gradings, without_timing)

    # Compute deltas
    delta = {
        "pass_rate": round(with_metrics["pass_rate"]["mean"] - without_metrics["pass_rate"]["mean"], 4),
        "tokens": round(with_metrics["tokens"]["mean"] - without_metrics["tokens"]["mean"], 1),
        "time_seconds": round(with_metrics["time_seconds"]["mean"] - without_metrics["time_seconds"]["mean"], 2),
    }

    benchmark = {
        "iteration": os.path.basename(iter_dir),
        "eval_count": len({
            Path(g).parents[1].name
            for g in glob.glob(os.path.join(iter_dir, "**/grading.json"), recursive=True)
        }),
        "run_summary": {
            "with_skill": with_metrics,
            "without_skill": without_metrics,
            "delta": delta,
        },
    }

    output_path = os.path.join(iter_dir, "benchmark.json")
    with open(output_path, "w") as f:
        json.dump(benchmark, f, indent=2)

    print(f"Benchmark written to {output_path}")
    print(json.dumps(delta, indent=2))


if __name__ == "__main__":
    main()

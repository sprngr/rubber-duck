#!/usr/bin/env python3
"""Build a markdown comparison document across baseline global-benchmark summaries.

Example:
  python3 evals/_pinned-skill-eval-scripts/compare_baselines.py \
    --entry "iteration-2=evals/baselines/iteration-2-summary.json" \
    --entry "norm-v4=evals/baselines/iteration-4-fresh-copilot-llmgrade-norm-v4-summary.json" \
    --entry "norm-v5=/tmp/opencode/duck-skill-evals/iteration-4-fresh-copilot-llmgrade-norm-v5/global-benchmark.json" \
    --entry "norm-v6=evals/baselines/iteration-4-fresh-copilot-llmgrade-norm-v6-summary.json" \
    --progression "norm-v4,norm-v5,norm-v6" \
    --output-md evals/BASELINE_COMPARISON.md
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path


@dataclass
class Baseline:
    label: str
    path: Path
    payload: dict


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def parse_entry(raw: str, repo_root: Path) -> tuple[str, Path]:
    if "=" not in raw:
        raise ValueError(f"invalid --entry (expected LABEL=PATH): {raw}")
    label, raw_path = raw.split("=", 1)
    label = label.strip()
    raw_path = raw_path.strip()
    if not label or not raw_path:
        raise ValueError(f"invalid --entry (blank label/path): {raw}")
    p = Path(raw_path)
    if not p.is_absolute():
        p = (repo_root / p).resolve()
    else:
        p = p.resolve()
    if not p.exists():
        raise FileNotFoundError(f"baseline file not found: {p}")
    return label, p


def extract_aggregate(payload: dict) -> tuple[float, float, float]:
    mean = payload.get("aggregate", {}).get("mean_delta", {})
    return (
        float(mean.get("pass_rate", 0.0)),
        float(mean.get("tokens", 0.0)),
        float(mean.get("time_seconds", 0.0)),
    )


def fmt4(v: float) -> str:
    return f"{v:.4f}"


def fmt1(v: float) -> str:
    return f"{v:.1f}"


def fmt2(v: float) -> str:
    return f"{v:.2f}"


def signed(v: float, digits: int) -> str:
    f = f"{{v:+.{digits}f}}"
    return f.format(v=v)


def build_markdown(
    baselines: list[Baseline],
    progression_labels: list[str],
    include_methodology_note: bool,
) -> str:
    by_label = {b.label: b for b in baselines}
    lines: list[str] = []
    lines.append("# Duck Skill Eval Baseline Comparison")
    lines.append("")
    lines.append(f"Updated: {date.today().isoformat()}")
    lines.append("")
    lines.append("## Aggregate Mean Delta Comparison")
    lines.append("")
    lines.append("Higher `pass_rate` is better. Lower `tokens` and `time_seconds` are better.")
    lines.append("")
    lines.append("| Baseline | pass_rate | tokens | time_seconds |")
    lines.append("|---|---:|---:|---:|")
    for b in baselines:
        p, t, s = extract_aggregate(b.payload)
        lines.append(f"| {b.label} | {fmt4(p)} | {fmt1(t)} | {fmt2(s)} |")

    if progression_labels:
        missing = [x for x in progression_labels if x not in by_label]
        if missing:
            raise ValueError(f"--progression labels not found in --entry: {', '.join(missing)}")
        lines.append("")
        lines.append("## Progression")
        lines.append("")
        for a, b in zip(progression_labels, progression_labels[1:]):
            p1, t1, s1 = extract_aggregate(by_label[a].payload)
            p2, t2, s2 = extract_aggregate(by_label[b].payload)
            dp, dt, ds = (p2 - p1, t2 - t1, s2 - s1)
            lines.append(f"- {a} → {b}:")
            lines.append(f"  - pass_rate: `{signed(dp, 4)}`")
            lines.append(f"  - tokens: `{signed(dt, 1)}`")
            lines.append(f"  - time_seconds: `{signed(ds, 2)}`")

    if include_methodology_note:
        lines.append("")
        lines.append("## Methodology Change Note")
        lines.append("")
        lines.append(
            "Legacy baselines and normalized Copilot true-fresh runs are not strictly apples-to-apples. "
            "Methodology changed (runner path, LLM grading mode, and calibrated token normalization). "
            "Use normalized-track comparisons for primary optimization decisions."
        )

    lines.append("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", default=".")
    ap.add_argument("--entry", action="append", required=True, help="LABEL=PATH (repeatable)")
    ap.add_argument("--progression", default="", help="Comma list of labels, e.g. norm-v4,norm-v5,norm-v6")
    ap.add_argument("--include-methodology-note", action="store_true")
    ap.add_argument("--output-md", required=True)
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_md = Path(args.output_md)
    if not output_md.is_absolute():
        output_md = (repo_root / output_md).resolve()
    else:
        output_md = output_md.resolve()

    baselines: list[Baseline] = []
    seen = set()
    for raw in args.entry:
        label, path = parse_entry(raw, repo_root)
        if label in seen:
            raise ValueError(f"duplicate label: {label}")
        seen.add(label)
        baselines.append(Baseline(label=label, path=path, payload=read_json(path)))

    progression_labels = [x.strip() for x in args.progression.split(",") if x.strip()]
    md = build_markdown(
        baselines=baselines,
        progression_labels=progression_labels,
        include_methodology_note=bool(args.include_methodology_note),
    )

    output_md.parent.mkdir(parents=True, exist_ok=True)
    output_md.write_text(md, encoding="utf-8")
    print(f"Wrote {output_md}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

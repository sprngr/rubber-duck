#!/usr/bin/env python3
"""Freeze an iteration global benchmark into repo baselines.

Example:
  python3 evals/_pinned-skill-eval-scripts/freeze_baseline.py \
    --repo-root /mnt/f/workspace/rubber-duck \
    --iteration iteration-4-fresh-copilot-llmgrade-norm-v6 \
    --out-root /tmp/opencode/duck-skill-evals
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", default=".")
    ap.add_argument("--iteration", required=True)
    ap.add_argument("--out-root", required=True)
    ap.add_argument("--force", action="store_true", help="overwrite existing baseline file")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_root = Path(args.out_root).resolve()

    src = (out_root / args.iteration / "global-benchmark.json").resolve()
    dst = (repo_root / "evals" / "baselines" / f"{args.iteration}-summary.json").resolve()

    if not src.exists():
        raise FileNotFoundError(f"source benchmark not found: {src}")
    if dst.exists() and not args.force:
        raise FileExistsError(f"destination exists (use --force to overwrite): {dst}")

    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    print(f"Wrote {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

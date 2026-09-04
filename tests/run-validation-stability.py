#!/usr/bin/env python3
"""Unit checks for validation/stability.py quarantine mechanics.

Usage: python3 tests/run-validation-stability.py
Exit 0 = all pass, 1 = failure.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "validation"))

import stability  # noqa: E402


def check(name: str, cond: bool) -> None:
    if not cond:
        print(f"FAIL: {name}")
        sys.exit(1)
    print(f"ok: {name}")


# classify_tier window semantics
h: dict[str, list[bool]] = {}
check("empty history -> uncalibrated", stability.classify_tier(h, "V01") == "uncalibrated")
stability.record_result(h, "V01", True)
stability.record_result(h, "V01", True)
check("two consecutive passes -> stable", stability.classify_tier(h, "V01") == "stable")
stability.record_result(h, "V01", False)
check("any recent failure -> flaky", stability.classify_tier(h, "V01") == "flaky")
stability.record_result(h, "V02", True)
check("one pass < window -> uncalibrated", stability.classify_tier(h, "V02") == "uncalibrated")
check("window param honored", stability.classify_tier(h, "V02", window=1) == "stable")

# record / save / load round-trip
with TemporaryDirectory() as tmp:
    path = Path(tmp) / "history.json"
    stability.save_history(path, h)
    check("save/load round-trip equality", stability.load_history(path) == h)

# corrupt and missing history files
check("missing file -> empty history", stability.load_history(Path("/nonexistent/x.json")) == {})
with TemporaryDirectory() as tmp:
    bad = Path(tmp) / "history.json"
    bad.write_text("{not json")
    check("corrupt file -> empty history", stability.load_history(bad) == {})

# non-list entries dropped, bool coercion
mixed = {"V03": [1, 0, "yes"], "V04": "not-a-list"}
with TemporaryDirectory() as tmp:
    path = Path(tmp) / "history.json"
    path.write_text(json.dumps(mixed))
    loaded = stability.load_history(path)
    check("bool coercion", loaded == {"V03": [True, False, True]})
    check("non-list entry dropped", "V04" not in loaded)

print("all stability checks passed")
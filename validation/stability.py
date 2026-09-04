#!/usr/bin/env python3
"""Pass-history + stable/flaky tier classification for the validation runner.

Records per-test verdict history, classifies tests into stable / flaky /
uncalibrated tiers, and exposes a filter for CI gate runs.

Phase 2: persistence glue (load/record/save) + window classification wired.
"""

from __future__ import annotations

import json
from pathlib import Path

STABLE_WINDOW_DEFAULT = 2  # consecutive passes required for stable tier


def load_history(path: Path) -> dict[str, list[bool]]:
    """Load pass-history JSON. Missing or corrupt file -> empty history.

    Values coerced to bool; non-list entries dropped.
    """
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(data, dict):
        return {}
    return {
        str(k): [bool(v) for v in vals]
        for k, vals in data.items()
        if isinstance(vals, list)
    }


def record_result(
    history: dict[str, list[bool]],
    test_id: str,
    passed: bool,
) -> None:
    """Append one verdict to the test's history list.

    Key created on first record.
    """
    history.setdefault(test_id, []).append(bool(passed))


def save_history(path: Path, history: dict[str, list[bool]]) -> None:
    """Persist history JSON.

    Parent dir created if absent.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(history, indent=2))


def classify_tier(
    history: dict[str, list[bool]],
    test_id: str,
    window: int = STABLE_WINDOW_DEFAULT,
) -> str:
    """Return 'stable' (window consecutive passes), 'flaky' (any recent
    failure), or 'uncalibrated' (insufficient history).

    Semantics: any failure in the recent window -> flaky immediately;
    window of consecutive passes -> stable; fewer records than window with
    no failure -> uncalibrated.
    """
    verdicts = history.get(test_id, [])
    if not verdicts:
        return "uncalibrated"
    recent = verdicts[-window:]
    if any(not v for v in recent):
        return "flaky"
    if len(verdicts) >= window:
        return "stable"
    return "uncalibrated"
#!/usr/bin/env python3
"""Run duck-skill skill-check with local exception rules.

Exceptions:
1) Treat top-level evals/<skill>/evals.json as satisfying eval-presence gate.
2) Ignore no_windows_paths failures when evidence suggests regex/example literal.

Writes:
  <out-root>/<run-id>/consolidated-report.md
  <out-root>/<run-id>/manifest.json
  <out-root>/<run-id>/per-skill/<skill>.json
"""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime
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


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def run_json(cmd: list[str]) -> object:
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(cmd)}\n{proc.stderr[-800:]}")
    return json.loads(proc.stdout.strip() or "{}")


def as_dict(value: object) -> dict:
    return value if isinstance(value, dict) else {}


def as_list(value: object) -> list:
    return value if isinstance(value, list) else []


def score_grade(overall: float) -> str:
    if overall >= 90:
        return "A"
    if overall >= 80:
        return "B"
    if overall >= 70:
        return "C"
    if overall >= 60:
        return "D"
    return "F"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--out-root", required=True)
    ap.add_argument("--run-id", default="")
    ap.add_argument("--skills", default=",".join(DEFAULT_SKILLS))
    # Uses skill-check from sprngr/cantrips
    ap.add_argument("--validate-script", default="~/.agents/skills/skill-check/scripts/validate-structure.sh")
    ap.add_argument("--compare-script", default="~/.agents/skills/skill-check/scripts/compare-structure.sh")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_root = Path(args.out_root).resolve()
    run_id = args.run_id.strip() or f"skill-check-duck-second-pass-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}"
    out_dir = out_root / run_id
    per_dir = out_dir / "per-skill"
    per_dir.mkdir(parents=True, exist_ok=True)

    validate_script = Path(args.validate_script).resolve()
    compare_script = Path(args.compare_script).resolve()
    skills = [s.strip() for s in args.skills.split(",") if s.strip()]

    results: list[dict] = []

    for skill in skills:
        skill_dir = repo_root / "skills" / skill
        skill_text = read_text(skill_dir / "SKILL.md")
        lower = skill_text.lower()
        line_count = len(skill_text.splitlines())

        validate_rows = as_list(run_json([str(validate_script), str(skill_dir)]))
        compare_obj = as_dict(run_json([str(compare_script), str(skill_dir)]))

        ignored_findings = []
        filtered_validate = []
        for row in validate_rows:
            row_dict = as_dict(row)
            check = str(row_dict.get("check", ""))
            passed = bool(row_dict.get("pass", False))
            detail = str(row_dict.get("detail", ""))
            if check == "no_windows_paths" and not passed:
                if "\\s+" in detail or "<" in detail or "regex" in lower or "pattern" in lower:
                    ignored_findings.append(
                        {
                            "check": check,
                            "reason": "ignored regex/example-literal style match",
                            "detail": detail,
                        }
                    )
                    filtered_validate.append(
                        {
                            "check": check,
                            "pass": True,
                            "detail": f"Ignored false-positive (regex/example literal): {detail}",
                        }
                    )
                    continue
            filtered_validate.append(row_dict)

        skill_local_evals = (skill_dir / "evals" / "evals.json").exists()
        top_level_evals = (repo_root / "evals" / skill / "evals.json").exists()
        has_evals = skill_local_evals or top_level_evals

        warnings = [str(w) for w in compare_obj.get("warnings", [])]
        if top_level_evals:
            warnings = [w for w in warnings if "No evals/ directory found" not in w]

        found = list(compare_obj.get("found", []))
        if top_level_evals and not skill_local_evals:
            found.append("evals/evals.json (top-level accepted)")
        missing_recommended = list(compare_obj.get("missing_recommended", []))

        required_missing = 0 if any(x == "SKILL.md" for x in found) else 1
        structure_score = len(found) - 2 * required_missing - len(warnings)
        structure_score = max(0, min(10, int(structure_score)))

        has_step = any(k in lower for k in ["step-by-step", "workflow", "method", "process"])
        has_examples = "example" in lower or "examples" in lower
        has_edge = any(k in lower for k in ["edge case", "watch out", "gotcha", "pitfall"])
        line_ok = line_count <= 500
        progressive = (skill_dir / "references").exists() and ("references/" in lower or "reference" in lower)
        has_default = any(k in lower for k in ["default", "recommended"])
        has_validation = any(k in lower for k in ["validate", "verify", "checklist", "check"])

        extra_checks = [
            {"check": "body_step_by_step", "pass": has_step, "detail": "Found workflow/step markers" if has_step else "No clear step-by-step workflow markers"},
            {"check": "body_examples", "pass": has_examples, "detail": "Found example markers" if has_examples else "No explicit example markers"},
            {"check": "body_edge_cases", "pass": has_edge, "detail": "Found edge-case/gotcha markers" if has_edge else "No explicit edge-case/gotcha markers"},
            {"check": "body_line_limit", "pass": line_ok, "detail": f"{line_count} lines"},
            {"check": "progressive_disclosure", "pass": progressive, "detail": "references/ present + referenced" if progressive else "No references/ usage signal"},
        ]

        bp_warnings = []
        if not has_examples:
            bp_warnings.append("No explicit examples section/markers")
        if not has_edge:
            bp_warnings.append("No explicit edge-case/gotcha section")
        if not has_default:
            bp_warnings.append("No explicit default/recommended guidance marker")
        if not has_validation:
            bp_warnings.append("No clear validation/check loop marker")

        spec_total = len(filtered_validate) + len(extra_checks)
        spec_pass = sum(1 for r in filtered_validate if r.get("pass")) + sum(1 for r in extra_checks if r.get("pass"))
        bp_total = 5
        bp_pass = max(0, bp_total - len(bp_warnings))

        spec_pct = (spec_pass / spec_total * 100.0) if spec_total else 0.0
        bp_pct = (bp_pass / bp_total * 100.0) if bp_total else 0.0
        struct_pct = structure_score / 10.0 * 100.0
        overall = round(spec_pct * 0.5 + bp_pct * 0.25 + struct_pct * 0.25, 1)

        fixes = []
        failed_rows = [r for r in filtered_validate if not r.get("pass")] + [r for r in extra_checks if not r.get("pass")]
        for r in failed_rows:
            check = str(r.get("check", "unknown"))
            detail = str(r.get("detail", ""))
            if check in {"name_present", "description_valid", "frontmatter_starts", "frontmatter_closes", "frontmatter_parse"}:
                fixes.append({"priority": "high", "description": f"Add valid YAML frontmatter requirement: {check}", "evidence": detail})
            elif check in {"description_use_when", "description_third_person", "name_matches_dir", "no_unknown_fields"}:
                fixes.append({"priority": "medium", "description": f"Adjust frontmatter metadata rule: {check}", "evidence": detail})
            else:
                fixes.append({"priority": "low", "description": f"Improve body/spec coverage: {check}", "evidence": detail})
        for w in warnings:
            fixes.append({"priority": "low", "description": "Structure warning", "evidence": w})
        for w in bp_warnings:
            fixes.append({"priority": "low", "description": "Best-practice gap", "evidence": w})

        dedup = []
        seen = set()
        for f in fixes:
            key = (f["priority"], f["description"], f["evidence"])
            if key in seen:
                continue
            seen.add(key)
            dedup.append(f)

        artifact = {
            "skill": skill,
            "target_path": str(skill_dir),
            "audit_date": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "grade": score_grade(overall),
            "scores": {
                "overall_pct": overall,
                "spec": {"score": spec_pass, "total": spec_total, "pct": round(spec_pct, 1)},
                "best_practices": {"score": bp_pass, "total": bp_total, "pct": round(bp_pct, 1)},
                "structure": {"score": structure_score, "total": 10, "pct": round(struct_pct, 1)},
            },
            "spec_checks": {
                "validate_structure": filtered_validate,
                "extended_body": extra_checks,
                "ignored_findings": ignored_findings,
            },
            "has_evals": has_evals,
            "structure": {
                "structure_score": structure_score,
                "found": found,
                "missing_recommended": missing_recommended,
                "warnings": warnings,
                "exception_rules_applied": {
                    "top_level_evals_exception": bool(top_level_evals and not skill_local_evals),
                    "windows_path_false_positive_filter": bool(ignored_findings),
                },
            },
            "best_practice_warnings": bp_warnings,
            "fixes": dedup,
        }

        (per_dir / f"{skill}.json").write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
        results.append(artifact)

    lines = [
        "# Duck Skills Skill-Check Consolidated Report (Second Pass)",
        "",
        f"Run: `{run_id}`",
        f"Generated: `{datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')}`",
        "",
        "Applied exceptions:",
        "- Treat top-level `evals/<skill>/evals.json` as satisfying eval-presence gate.",
        "- Ignore `no_windows_paths` failures when evidence indicates regex/example-literal false positive.",
        "",
        "## Summary Table",
        "",
        "| Skill | Grade | Overall % | Spec | BP | Structure | High fixes | Medium fixes | Low fixes |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]

    for row in sorted(results, key=lambda x: x["skill"]):
        high = sum(1 for f in row["fixes"] if f["priority"] == "high")
        medium = sum(1 for f in row["fixes"] if f["priority"] == "medium")
        low = sum(1 for f in row["fixes"] if f["priority"] == "low")
        s = row["scores"]
        lines.append(
            f"| {row['skill']} | {row['grade']} | {s['overall_pct']:.1f} | {s['spec']['pct']:.1f} | {s['best_practices']['pct']:.1f} | {s['structure']['pct']:.1f} | {high} | {medium} | {low} |"
        )

    lines.extend([
        "",
        "## Top Improvement Opportunities (severity-ranked)",
        "",
    ])

    all_high, all_medium, all_low = [], [], []
    for row in results:
        for f in row["fixes"]:
            item = f"{row['skill']}: {f['description']} — {f['evidence']}"
            if f["priority"] == "high":
                all_high.append(item)
            elif f["priority"] == "medium":
                all_medium.append(item)
            else:
                all_low.append(item)

    def emit(title: str, items: list[str]) -> None:
        lines.append(f"### {title}")
        if not items:
            lines.append("- none")
        else:
            for item in items[:15]:
                lines.append(f"- {item}")
            if len(items) > 15:
                lines.append(f"- ... and {len(items) - 15} more")
        lines.append("")

    emit("High", all_high)
    emit("Medium", all_medium)
    emit("Low", all_low)

    lines.append("## Per-Skill JSON Artifacts")
    lines.append("")
    for row in sorted(results, key=lambda x: x["skill"]):
        lines.append(f"- `per-skill/{row['skill']}.json`")

    (out_dir / "consolidated-report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (out_dir / "manifest.json").write_text(
        json.dumps(
            {
                "run_id": run_id,
                "out_dir": str(out_dir),
                "skills": skills,
                "consolidated_report": str(out_dir / "consolidated-report.md"),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(str(out_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

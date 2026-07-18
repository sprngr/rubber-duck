#!/usr/bin/env python3
"""Shared rules checker for assembly scripts.

Validates:
- checks.required_files
- checks.required_dir_file_sets
- checks.text_assertions
- optional grouped assertions (skills/agents)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate build rules JSON")
    p.add_argument("rules_file", type=Path)
    p.add_argument("repo_root", type=Path)
    p.add_argument("--groups-key", default=None, help="checks key containing grouped members")
    p.add_argument(
        "--group-file-template",
        default=None,
        help="Path template for grouped assertion targets, e.g. src/skills/{item}/SKILL.md",
    )
    p.add_argument(
        "--group-assertions-key",
        default="group_assertions",
        help="checks key containing grouped assertion substrings",
    )
    return p.parse_args()


def assert_file_contains_substrings(
    repo_root: Path,
    file_rel: str,
    substrings: list[str],
    *,
    missing_prefix: str,
    failed_prefix: str,
) -> int:
    target = repo_root / file_rel
    if not target.exists():
        print(f"{missing_prefix}: {file_rel}", file=sys.stderr)
        return 1

    content = target.read_text(encoding="utf-8")
    errors = 0
    for contains in substrings:
        if contains not in content:
            print(
                f"{failed_prefix}: {file_rel} missing substring: {contains}",
                file=sys.stderr,
            )
            errors += 1

    return errors


def iter_files_for_glob(repo_root: Path, pattern: str) -> list[Path]:
    return sorted(p for p in repo_root.glob(pattern) if p.is_file())


def check_duplicate_markdown_headings(file_path: Path, min_level: int = 2) -> int:
    heading_re = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
    seen: dict[tuple[int, str], int] = {}
    errors = 0

    for line_no, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), start=1):
        m = heading_re.match(line)
        if not m:
            continue

        level = len(m.group(1))
        if level < min_level:
            continue

        # normalize trailing markdown heading markers + whitespace/case
        heading_text = re.sub(r"\s+#+\s*$", "", m.group(2)).strip().lower()
        key = (level, heading_text)
        if key in seen:
            first_line = seen[key]
            print(
                (
                    "RULES: duplicate markdown heading: "
                    f"{file_path} lines {first_line} and {line_no}"
                ),
                file=sys.stderr,
            )
            errors += 1
        else:
            seen[key] = line_no

    return errors


def is_asset_like_ref(target: str) -> bool:
    if "/" not in target:
        return False

    # Limit to local artifact-relative refs to avoid false positives
    # for repo-level path mentions in prose.
    if target.startswith(("./", "../", "references/", "evals/")):
        return True

    return False


def normalize_link_target(raw: str) -> str:
    token = raw.strip().strip("<>")
    if not token:
        return ""

    # markdown links can include optional title after a space
    token = token.split()[0]
    return token


def check_markdown_asset_refs(file_path: Path, repo_root: Path) -> int:
    content = file_path.read_text(encoding="utf-8")
    errors = 0

    refs: list[str] = []

    refs.extend(m.group(1) for m in re.finditer(r"\[[^\]]*\]\(([^)]+)\)", content))
    refs.extend(m.group(1) for m in re.finditer(r"`([^`]+)`", content))

    checked: set[str] = set()
    for raw in refs:
        target = normalize_link_target(raw)
        if not target or target in checked:
            continue
        checked.add(target)

        if target.startswith(("http://", "https://", "mailto:", "#", "/")):
            continue
        if "|" in target:
            continue
        if not is_asset_like_ref(target):
            continue

        resolved = (file_path.parent / target).resolve()
        if not resolved.exists():
            rel_path = file_path.relative_to(repo_root)
            print(
                (
                    "RULES: dangling markdown asset reference: "
                    f"{rel_path} -> {target}"
                ),
                file=sys.stderr,
            )
            errors += 1

    return errors


def main() -> int:
    args = parse_args()
    rules_path = args.rules_file
    repo_root = args.repo_root

    if not rules_path.exists():
        print(f"RULES: missing rules file: {rules_path}", file=sys.stderr)
        return 1

    with rules_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    checks = data.get("checks", {})
    required_files = checks.get("required_files", [])
    required_dir_file_sets = checks.get("required_dir_file_sets", [])
    text_assertions = checks.get("text_assertions", [])
    markdown_duplicate_heading_checks = checks.get("markdown_duplicate_heading_checks", [])
    markdown_asset_ref_checks = checks.get("markdown_asset_ref_checks", [])

    errors = 0

    for rel in required_files:
        target = repo_root / rel
        if not target.exists():
            print(f"RULES: missing required file: {rel}", file=sys.stderr)
            errors += 1

    if not isinstance(required_dir_file_sets, list):
        print("RULES: required_dir_file_sets must be a list", file=sys.stderr)
        errors += 1
    else:
        for idx, item in enumerate(required_dir_file_sets, start=1):
            if not isinstance(item, dict):
                print(
                    f"RULES: malformed required_dir_file_sets entry #{idx}",
                    file=sys.stderr,
                )
                errors += 1
                continue

            dirs_glob = item.get("dirs_glob")
            required_in_dir = item.get("required_files")

            if not isinstance(dirs_glob, str) or not dirs_glob:
                print(
                    f"RULES: required_dir_file_sets entry #{idx} missing dirs_glob",
                    file=sys.stderr,
                )
                errors += 1
                continue

            if not isinstance(required_in_dir, list) or not required_in_dir:
                print(
                    f"RULES: required_dir_file_sets entry #{idx} missing required_files list",
                    file=sys.stderr,
                )
                errors += 1
                continue

            if not all(isinstance(name, str) and name for name in required_in_dir):
                print(
                    f"RULES: required_dir_file_sets entry #{idx} has invalid required_files value",
                    file=sys.stderr,
                )
                errors += 1
                continue

            matched_dirs = sorted(
                p for p in repo_root.glob(dirs_glob) if p.is_dir()
            )
            if not matched_dirs:
                print(
                    f"RULES: required_dir_file_sets no directories matched: {dirs_glob}",
                    file=sys.stderr,
                )
                errors += 1
                continue

            for directory in matched_dirs:
                for file_name in required_in_dir:
                    target = directory / file_name
                    if not target.exists():
                        rel_target = target.relative_to(repo_root)
                        print(
                            f"RULES: missing required file in directory: {rel_target}",
                            file=sys.stderr,
                        )
                        errors += 1

    for idx, assertion in enumerate(text_assertions, start=1):
        file_rel = assertion.get("file")
        contains = assertion.get("contains")

        if (
            not file_rel
            or not isinstance(contains, str)
            or contains == ""
        ):
            print(f"RULES: malformed text_assertion #{idx}", file=sys.stderr)
            errors += 1
            continue

        errors += assert_file_contains_substrings(
            repo_root,
            file_rel,
            [contains],
            missing_prefix="RULES: text_assertion file missing",
            failed_prefix="RULES: text_assertion failed",
        )

    if not isinstance(markdown_duplicate_heading_checks, list):
        print("RULES: markdown_duplicate_heading_checks must be a list", file=sys.stderr)
        errors += 1
    else:
        for idx, check in enumerate(markdown_duplicate_heading_checks, start=1):
            if not isinstance(check, dict):
                print(
                    f"RULES: malformed markdown_duplicate_heading_checks entry #{idx}",
                    file=sys.stderr,
                )
                errors += 1
                continue

            files_glob = check.get("files_glob")
            min_level = check.get("min_level", 2)
            if not isinstance(files_glob, str) or not files_glob:
                print(
                    f"RULES: markdown_duplicate_heading_checks entry #{idx} missing files_glob",
                    file=sys.stderr,
                )
                errors += 1
                continue
            if not isinstance(min_level, int) or min_level < 1 or min_level > 6:
                print(
                    f"RULES: markdown_duplicate_heading_checks entry #{idx} has invalid min_level",
                    file=sys.stderr,
                )
                errors += 1
                continue

            files = iter_files_for_glob(repo_root, files_glob)
            if not files:
                print(
                    f"RULES: markdown_duplicate_heading_checks no files matched: {files_glob}",
                    file=sys.stderr,
                )
                errors += 1
                continue

            for file_path in files:
                errors += check_duplicate_markdown_headings(file_path, min_level=min_level)

    if not isinstance(markdown_asset_ref_checks, list):
        print("RULES: markdown_asset_ref_checks must be a list", file=sys.stderr)
        errors += 1
    else:
        for idx, check in enumerate(markdown_asset_ref_checks, start=1):
            if not isinstance(check, dict):
                print(
                    f"RULES: malformed markdown_asset_ref_checks entry #{idx}",
                    file=sys.stderr,
                )
                errors += 1
                continue

            files_glob = check.get("files_glob")
            if not isinstance(files_glob, str) or not files_glob:
                print(
                    f"RULES: markdown_asset_ref_checks entry #{idx} missing files_glob",
                    file=sys.stderr,
                )
                errors += 1
                continue

            files = iter_files_for_glob(repo_root, files_glob)
            if not files:
                print(
                    f"RULES: markdown_asset_ref_checks no files matched: {files_glob}",
                    file=sys.stderr,
                )
                errors += 1
                continue

            for file_path in files:
                errors += check_markdown_asset_refs(file_path, repo_root)

    # Optional grouped assertions
    if args.groups_key and args.group_file_template:
        groups = checks.get(args.groups_key, {})
        group_assertions = checks.get(args.group_assertions_key, {})

        if not isinstance(groups, dict):
            print(f"RULES: {args.groups_key} must be an object", file=sys.stderr)
            errors += 1
        elif not isinstance(group_assertions, dict):
            print(f"RULES: {args.group_assertions_key} must be an object", file=sys.stderr)
            errors += 1
        else:
            for group_name, members in groups.items():
                if not isinstance(members, list):
                    print(f"RULES: {args.groups_key}.{group_name} must be a list", file=sys.stderr)
                    errors += 1
                    continue

                assertions = group_assertions.get(group_name, [])
                if not isinstance(assertions, list):
                    print(
                        f"RULES: {args.group_assertions_key}.{group_name} must be a list",
                        file=sys.stderr,
                    )
                    errors += 1
                    continue

                for member in members:
                    if not isinstance(member, str) or not member:
                        print(
                            f"RULES: {args.groups_key}.{group_name} contains invalid entry",
                            file=sys.stderr,
                        )
                        errors += 1
                        continue

                    file_rel = args.group_file_template.format(item=member)
                    for contains in assertions:
                        if not isinstance(contains, str) or contains == "":
                            print(
                                f"RULES: {args.group_assertions_key}.{group_name} contains invalid substring",
                                file=sys.stderr,
                            )
                            errors += 1
                    valid_assertions = [s for s in assertions if isinstance(s, str) and s != ""]
                    if not valid_assertions:
                        continue

                    errors += assert_file_contains_substrings(
                        repo_root,
                        file_rel,
                        valid_assertions,
                        missing_prefix="RULES: grouped assertion file missing",
                        failed_prefix="RULES: grouped assertion failed",
                    )

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())

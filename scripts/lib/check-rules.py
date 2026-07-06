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

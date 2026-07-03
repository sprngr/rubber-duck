
#!/usr/bin/env python3
"""Generate subagent dispatch instructions for eval runs.

Reads evals.json and produces ready-to-paste dispatch prompts for each
with-skill and without-skill run.
"""

import json
import sys
import os


def main():
    if len(sys.argv) != 4:
        print("Usage: spawn_runs.py <iteration-dir> <evals-json> <skill-snapshot>", file=sys.stderr)
        sys.exit(1)

    iter_dir = sys.argv[1]
    evals_json_path = sys.argv[2]
    skill_snapshot = sys.argv[3]

    with open(evals_json_path) as f:
        data = json.load(f)

    skill_name = data.get("skill_name", "unknown-skill")
    evals = data.get("evals", [])

    print(f"# Dispatch instructions for {skill_name}")
    print(f"# Copy each block into a fresh subagent session")
    print()

    for ev in evals:
        ev_id = ev.get("id", "?")
        prompt = ev.get("prompt", "")
        files = ev.get("files", [])
        slug = f"eval-{ev_id}"

        files_list = ""
        if files:
            files_list = "\n".join(f"  - {f}" for f in files)

        # With-skill run
        print(f"--- WITH-SKILL: {slug} ---")
        print(f"Execute this task:")
        print(f"  Skill path: {skill_snapshot}")
        print(f"  Task: {prompt}")
        if files_list:
            print(f"  Input files to copy into working directory:")
            print(files_list)
        print(f"  Save outputs to: {iter_dir}/{slug}/with_skill/outputs/")
        print(f"  On completion save timing.json with total_tokens and duration_ms")
        print()

        # Without-skill run
        print(f"--- WITHOUT-SKILL (baseline): {slug} ---")
        print(f"Execute this task WITHOUT loading any skill:")
        print(f"  Task: {prompt}")
        if files_list:
            print(f"  Input files to copy into working directory:")
            print(files_list)
        print(f"  Save outputs to: {iter_dir}/{slug}/without_skill/outputs/")
        print(f"  On completion save timing.json with total_tokens and duration_ms")
        print()


if __name__ == "__main__":
    main()

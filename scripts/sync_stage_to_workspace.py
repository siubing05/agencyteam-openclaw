#!/usr/bin/env python3
"""Copy staged agencyteam workspaces into the live destination safely."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

MARKER_FILE = "AGENCYTEAM_MANAGED"


def is_managed_workspace(path: Path) -> bool:
    return (path / MARKER_FILE).is_file()


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def list_stage_ids(stage: Path) -> list[str]:
    if not stage.exists():
        return []
    return sorted(child.name for child in stage.iterdir() if child.is_dir())


def validate_requested_agents(requested: list[str], stage_ids: set[str]) -> None:
    missing = [agent_id for agent_id in requested if agent_id not in stage_ids]
    if missing:
        raise SystemExit("Requested agent(s) not found in staged snapshot: " + ", ".join(missing))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--current", required=True, help="Live destination directory")
    parser.add_argument("--stage", required=True, help="Staged snapshot directory")
    parser.add_argument("--agent", dest="agents", action="append", default=[], help="Only sync this agent ID (repeatable)")
    parser.add_argument("--prune-managed-missing", action="store_true", help="Remove managed live dirs missing from the selected staged set")
    parser.add_argument("--summary-json", help="Write copied/pruned IDs summary to this JSON file")
    args = parser.parse_args()

    current = Path(args.current).expanduser().resolve()
    stage = Path(args.stage).expanduser().resolve()

    if not stage.is_dir():
        raise SystemExit(f"Stage directory not found: {stage}")

    current.mkdir(parents=True, exist_ok=True)

    stage_ids = list_stage_ids(stage)
    stage_set = set(stage_ids)
    selected_ids = sorted(set(args.agents)) if args.agents else stage_ids
    validate_requested_agents(selected_ids, stage_set)

    copied: list[str] = []
    for agent_id in selected_ids:
        src = stage / agent_id
        dst = current / agent_id
        if dst.exists():
            remove_path(dst)
        shutil.copytree(src, dst)
        copied.append(agent_id)

    pruned: list[str] = []
    if args.prune_managed_missing:
        selected_set = set(selected_ids)
        for child in sorted(current.iterdir()):
            if not child.is_dir():
                continue
            if child.name in selected_set:
                continue
            if is_managed_workspace(child):
                shutil.rmtree(child)
                pruned.append(child.name)

    summary = {
        "copied": copied,
        "pruned": pruned,
        "selected": selected_ids,
    }
    if args.summary_json:
        summary_path = Path(args.summary_json).expanduser().resolve()
        summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(
        "Workspace sync: "
        f"copied={len(copied)} "
        f"pruned={len(pruned)}"
    )
    if copied:
        print("Copied IDs: " + ", ".join(copied[:20]) + (" ..." if len(copied) > 20 else ""))
    if pruned:
        print("Pruned managed IDs: " + ", ".join(pruned[:20]) + (" ..." if len(pruned) > 20 else ""))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

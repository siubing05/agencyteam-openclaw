#!/usr/bin/env python3
"""Sync agencyteam-generated agents into OpenClaw config safely."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path
from typing import Iterable

DEFAULT_MODEL = "minimax/MiniMax-M2.7"
MARKER_FILE = "AGENCYTEAM_MANAGED"


def eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def expand(path: str) -> Path:
    return Path(os.path.expanduser(path)).resolve()


def read_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise SystemExit(f"Config root must be an object: {path}")
    return data


def write_config_atomic(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(prefix="openclaw.", suffix=".json.tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp_path, path)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def backup_file(path: Path) -> Path:
    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup = path.with_name(f"{path.name}.bak.{stamp}")
    shutil.copy2(path, backup)
    return backup


def load_agent_list(config: dict) -> list[dict]:
    agents = config.setdefault("agents", {})
    if not isinstance(agents, dict):
        raise SystemExit("config.agents must be an object")
    agent_list = agents.setdefault("list", [])
    if not isinstance(agent_list, list):
        raise SystemExit("config.agents.list must be an array")
    for idx, entry in enumerate(agent_list):
        if not isinstance(entry, dict):
            raise SystemExit(f"config.agents.list[{idx}] must be an object")
    return agent_list


def list_disk_agents(agency_dest: Path) -> list[str]:
    if not agency_dest.exists():
        return []
    ids = []
    for child in sorted(agency_dest.iterdir()):
        if child.is_dir() and child.name != ".git":
            ids.append(child.name)
    return ids


def validate_requested_agents(requested: Iterable[str], disk_ids: set[str]) -> None:
    missing = [agent_id for agent_id in requested if agent_id not in disk_ids]
    if missing:
        raise SystemExit("Requested agent(s) not found on disk: " + ", ".join(missing))


def ensure_main(agent_list: list[dict]) -> dict:
    for entry in agent_list:
        if entry.get("id") == "main":
            return entry
    raise SystemExit("Could not find a 'main' agent entry in config.agents.list")


def normalize_entry(entry: dict, agent_id: str, workspace: str) -> tuple[dict, bool]:
    changed = False
    if entry.get("workspace") != workspace:
        entry["workspace"] = workspace
        changed = True
    if entry.get("model") is None:
        entry["model"] = DEFAULT_MODEL
        changed = True
    return entry, changed


def is_managed_workspace_for_entry(agency_dest: Path, agent_id: object, workspace: object) -> bool:
    if not isinstance(agent_id, str) or not isinstance(workspace, str):
        return False

    resolved_workspace = expand(workspace)
    expected_workspace = (agency_dest / agent_id).resolve()
    if resolved_workspace != expected_workspace:
        return False

    if not resolved_workspace.exists():
        return False

    return (resolved_workspace / MARKER_FILE).is_file()


def sync_agents(
    agent_list: list[dict],
    agency_dest: Path,
    selected_ids: list[str],
    prune_missing: bool,
    remove_ids: list[str],
    update_allowlist: bool,
) -> tuple[list[dict], dict[str, list[str] | int]]:
    existing_by_id = {entry.get("id"): entry for entry in agent_list if entry.get("id")}

    added: list[str] = []
    updated: list[str] = []
    unchanged: list[str] = []
    removed: list[str] = []

    for agent_id in selected_ids:
        workspace = str((agency_dest / agent_id).resolve())
        entry = existing_by_id.get(agent_id)
        if entry is None:
            agent_list.append({"id": agent_id, "workspace": workspace, "model": DEFAULT_MODEL})
            added.append(agent_id)
            continue
        before = json.dumps(entry, sort_keys=True, ensure_ascii=False)
        normalize_entry(entry, agent_id, workspace)
        after = json.dumps(entry, sort_keys=True, ensure_ascii=False)
        if before != after:
            updated.append(agent_id)
        else:
            unchanged.append(agent_id)

    removed_set: set[str] = set()

    if prune_missing:
        selected_set = set(selected_ids)
        kept: list[dict] = []
        for entry in agent_list:
            agent_id = entry.get("id")
            if agent_id == "main":
                kept.append(entry)
                continue
            workspace = entry.get("workspace")
            managed = is_managed_workspace_for_entry(agency_dest, agent_id, workspace)
            if managed and agent_id not in selected_set:
                removed_set.add(str(agent_id))
                continue
            kept.append(entry)
        agent_list = kept

    explicit_remove = {agent_id for agent_id in remove_ids if agent_id and agent_id != "main"}
    if explicit_remove:
        kept = []
        for entry in agent_list:
            agent_id = entry.get("id")
            if agent_id in explicit_remove:
                removed_set.add(str(agent_id))
                continue
            kept.append(entry)
        agent_list = kept

    removed = sorted(removed_set)

    if update_allowlist:
        main_entry = ensure_main(agent_list)
        subagents = main_entry.setdefault("subagents", {})
        if not isinstance(subagents, dict):
            raise SystemExit("main.subagents must be an object if present")
        allow_agents = subagents.get("allowAgents")
        if allow_agents == ["*"]:
            pass
        else:
            if allow_agents is None:
                merged: list[str] = []
            elif isinstance(allow_agents, list):
                invalid_entries = [repr(x) for x in allow_agents if not isinstance(x, str)]
                if invalid_entries:
                    raise SystemExit(
                        "main.subagents.allowAgents must contain only strings; "
                        "invalid entries: " + ", ".join(invalid_entries)
                    )
                merged = list(allow_agents)
            else:
                raise SystemExit("main.subagents.allowAgents must be an array if present")
            for agent_id in selected_ids:
                if agent_id not in merged:
                    merged.append(agent_id)
            if removed:
                merged = [x for x in merged if x not in removed_set]
            subagents["allowAgents"] = merged

    return agent_list, {
        "added": added,
        "updated": updated,
        "unchanged": unchanged,
        "removed": removed,
        "selected": len(selected_ids),
        "total": len(agent_list),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agency-dest", required=True, help="Directory containing generated agent workspaces")
    parser.add_argument("--config", default="~/.openclaw/openclaw.json", help="Path to openclaw.json")
    parser.add_argument("--agent", dest="agents", action="append", default=[], help="Only sync this agent ID (repeatable)")
    parser.add_argument("--prune-missing", action="store_true", help="Remove managed agent entries missing from disk")
    parser.add_argument("--backup", action="store_true", help="Create a timestamped backup before writing")
    parser.add_argument("--dry-run", action="store_true", help="Print summary without writing")
    parser.add_argument("--remove-agent", dest="remove_agents", action="append", default=[], help="Explicitly remove this agent ID from config (repeatable)")
    parser.add_argument("--skip-main-allowlist", action="store_true", help="Do not merge IDs into main.subagents.allowAgents")
    args = parser.parse_args()

    agency_dest = expand(args.agency_dest)
    config_path = expand(args.config)

    if not config_path.is_file():
        raise SystemExit(f"Config file not found: {config_path}")
    if not agency_dest.exists():
        raise SystemExit(f"Agency destination not found: {agency_dest}")

    config = read_config(config_path)
    agent_list = load_agent_list(config)
    disk_ids = list_disk_agents(agency_dest)
    disk_set = set(disk_ids)
    selected_ids = sorted(set(args.agents)) if args.agents else disk_ids
    validate_requested_agents(selected_ids, disk_set)

    agent_list, summary = sync_agents(
        agent_list=agent_list,
        agency_dest=agency_dest,
        selected_ids=selected_ids,
        prune_missing=args.prune_missing,
        remove_ids=sorted(set(args.remove_agents)),
        update_allowlist=not args.skip_main_allowlist,
    )
    config["agents"]["list"] = agent_list

    backup_path: Path | None = None
    if not args.dry_run:
        if args.backup:
            backup_path = backup_file(config_path)
        write_config_atomic(config_path, config)

    if backup_path:
        print(f"Backup: {backup_path}")
    print(
        "Summary: "
        f"selected={summary['selected']} "
        f"added={len(summary['added'])} "
        f"updated={len(summary['updated'])} "
        f"unchanged={len(summary['unchanged'])} "
        f"removed={len(summary['removed'])} "
        f"total={summary['total']}"
    )
    if summary["added"]:
        print("Added IDs: " + ", ".join(summary["added"]))
    if summary["updated"]:
        print("Updated IDs: " + ", ".join(summary["updated"]))
    if summary["removed"]:
        print("Removed IDs: " + ", ".join(summary["removed"]))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

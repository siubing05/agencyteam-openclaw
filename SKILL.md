---
name: agencyteam
description: Coordinate multi-expert work in OpenClaw using agency-agents style specialists. Use when tasks benefit from specialist decomposition, parallel perspectives, reviewer/builder splits, structured synthesis, or on-demand expert installation and update workflows.
---

# agencyteam

Use this skill when the user wants a small expert team instead of a single answer.

## When to use it

Trigger on requests like:
- 「我需要幾個專家幫手」
- 「幫我拆解然後分配」
- 「想搵 code reviewer + security + UX 一齊睇」
- multi-perspective review, builder/reviewer split, or expert-team planning

## Core workflow

1. **Assess** — decide whether the task is L1, L2, or L3
2. **Compose** — choose the smallest expert team that covers the task
3. **Brief** — send scoped, outcome-focused tasks to each expert
4. **Merge** — resolve conflicts, preserve caveats, remove duplication
5. **Deliver** — provide one integrated answer in your own voice

## L1 / L2 / L3 rule of thumb

- **L1**: one expert viewpoint is enough → answer directly, no subagent
- **L2**: 2–4 experts can work in parallel → spawn them, then merge
- **L3**: many experts or multi-wave work → run wave 1, synthesize, then run targeted follow-ups

See `references/routing.md` for expert selection and `references/workflows.md` for usage patterns.

## Brief format

Use a scoped brief like:

```text
## Goal
...

## Scope
...

## Output
...

## Done
...

## Constraints
...
```

## Installation / maintenance scripts

Use these scripts when the user wants to set up or maintain the expert roster:

- `scripts/install.sh` — fetch upstream prompts, convert them, sync `agents.list`, merge installed IDs into `main.subagents.allowAgents`, and restart the gateway
- `scripts/update.sh --dry-run` — preview upstream additions / changes / removals
- `scripts/update.sh [--prune-removed]` — refresh generated workspaces and synced config
- `scripts/spawn-and-install.sh <agent-id> <task>` — ensure a single agent exists locally, register it, then invoke it
- `UPSTREAM_REF` — default pinned upstream commit used for reproducible conversion unless overridden by env or `--ref`

### Important behavior

- agencyteam-managed workspaces live under `~/.openclaw/agency-agents/` by default
- upstream conversion is pinned by default via `UPSTREAM_REF`; use `AGENCYTEAM_UPSTREAM_REF` or `convert.sh --ref` only when you intentionally want a different revision
- installer/config sync uses `agents.list`; it does **not** write arbitrary keys under `agents`
- installer preserves non-agency agents already present in config
- installer merges specific IDs into `main.subagents.allowAgents`; it does **not** automatically set `allowAgents: ["*"]`, but it preserves an existing wildcard if your config already uses one
- `update.sh` refreshes generated `AGENTS.md` files from upstream; if the user customized those generated files locally, updates can overwrite them

## Missing expert workflow

If an expert is needed but not installed yet, and the user intent allows local setup, run:

```bash
./scripts/spawn-and-install.sh <agent-id> "<task>"
```

Do not claim this is automatic unless you actually execute that script or equivalent steps.

## Constraints

1. Keep the expert set as small as possible.
2. Do not delegate destructive or irreversible actions to experts by default.
3. Do not present raw specialist output as the final user answer.
4. If experts disagree, explain the trade-off and your chosen synthesis.

# Concept — Leader / Expert Protocol

## What agencyteam preserves from ClawTeam-style orchestration

| Concept | agencyteam mapping |
|--------|---------------------|
| Leader / coordinator | `main` agent |
| Worker experts | Registered OpenClaw agents in `agents.list`; bundled scripts invoke them with `openclaw agent --agent <expert>`, while in-agent orchestration may use equivalent OpenClaw session tooling |
| Isolated specialist identity | Each expert workspace under `~/.openclaw/agency-agents/<agent-id>/` |
| Task brief | Goal + scope + output + done criteria |
| Synthesis loop | `main` merges expert outputs before replying |
| Confidence handling | Keep low-confidence claims out of the final answer unless labelled |

## What agencyteam does *not* depend on

- tmux subprocess orchestration
- git worktree isolation
- a custom board / inbox protocol
- special runtime patches in OpenClaw

It is a routing + install + invoke workflow on top of standard OpenClaw agent configuration.

## Coordination Rules

### Leader → Expert

Implementation note: the reference scripts in this skill install/repair experts locally and invoke them through `openclaw agent --agent <id> --message <task>`. If you orchestrate experts from inside an OpenClaw session instead of the bundled scripts, use the equivalent session/subagent tooling deliberately rather than assuming the scripts do that for you.

Give each expert enough context to act independently:

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

### Expert → Leader

Expect structured outputs such as:

```text
## Conclusion
...

## Evidence / reasoning
...

## Risks / unknowns
...

[confidence: 0.X]
```

## Anti-patterns

1. Do not dump raw expert output to the user unchanged.
2. Do not spawn experts for trivial L1 work.
3. Do not give multiple experts the same vague brief.
4. Do not hide uncertainty when experts disagree.

# Concept — Leader / Expert Protocol

## What agencyteam preserves from ClawTeam-style orchestration

| Concept | agencyteam mapping |
|--------|---------------------|
| Leader / coordinator | `main` agent |
| Worker experts | `sessions_spawn(agentId=<expert>)` |
| Isolated specialist identity | Each expert workspace under `~/.openclaw/agency-agents/<agent-id>/` |
| Task brief | Goal + scope + output + done criteria |
| Synthesis loop | `main` merges expert outputs before replying |
| Confidence handling | Keep low-confidence claims out of the final answer unless labelled |

## What agencyteam does *not* depend on

- tmux subprocess orchestration
- git worktree isolation
- a custom board / inbox protocol
- special runtime patches in OpenClaw

It is just a routing + install + spawn workflow on top of standard OpenClaw agent configuration.

## Coordination Rules

### Leader → Expert

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

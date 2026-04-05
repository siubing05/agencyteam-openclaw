# Workflows — L1 / L2 / L3 Usage Patterns

## L1 — 即時單兵

**When to use:** 1 個專家視角已足夠，唔值得開 subagent。

**Pattern:** 直接用相關 expert 思路回答，唔做 `sessions_spawn`。

Example:
- User: 「想優化電商網站 loading speed，點做好？」
- Answer from `engineering-frontend-developer` viewpoint:
  - image compression / next-gen formats
  - lazy loading
  - bundle splitting
  - CDN + caching
  - Core Web Vitals fixes

## L2 — 小隊協作

**When to use:** 需要 2–4 個專家視角，而且可以並行。

**Pattern:**
1. Assess task boundaries
2. Pick the minimum expert set
3. Send scoped briefs in parallel
4. Wait for completion events
5. Merge into one final answer

Example expert brief:

```text
## Goal
Design an MVP plan for a solo founder.

## Scope
Focus on system shape, tech stack, and trade-offs.
Do not write production code.

## Output
Bullet plan + recommended stack + top risks.

## Done
A solo founder can start implementation today.
```

Example spawn pattern:

```python
sessions_spawn(
  agentId="engineering-rapid-prototyper",
  task=brief,
  timeoutSeconds=600,
  runTimeoutSeconds=600,
)

sessions_spawn(
  agentId="engineering-frontend-developer",
  task=brief,
  timeoutSeconds=600,
  runTimeoutSeconds=600,
)
```

## L3 — 專案攻堅

**When to use:** 5+ experts, cross-domain work, or multi-wave exploration.

**Pattern:**
1. First wave: broad decomposition
2. Synthesize gaps / conflicts
3. Second wave: targeted follow-up specialists
4. Final merge with explicit trade-offs

Example:
- Wave 1: `marketing-douyin-strategist`, `marketing-content-creator`, `marketing-seo-specialist`
- Wave 2: `marketing-wechat-official-account`, `marketing-short-video-editing-coach`

## Merge Template

```text
## Integrated conclusion

### Strong consensus
- Item
- Item

### Trade-offs
- Expert A suggested X
- Expert B suggested Y
- Final decision: choose X because ...

### Needs validation
- Hypothesis / low-confidence item
```

## Confidence Rule of Thumb

- `>= 0.7` → usually safe to carry into final answer
- `0.5–0.69` → keep with caveats
- `< 0.5` → treat as hypothesis / follow-up item

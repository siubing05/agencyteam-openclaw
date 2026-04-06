# Routing — Expert Selection Table

Use this as a practical shortlist, not a hard rulebook. Pick the smallest team that covers the task.

These expert IDs are meant to map to registered OpenClaw agent IDs under `agents.list`. In the bundled workflow, invoke them via `openclaw agent --agent <id>` (or `scripts/spawn-and-install.sh` when the local install may be missing or unhealthy).

## L1 Single-Expert Routing

| Task Type | Primary Expert | Backup Expert | Level |
|-----------|----------------|---------------|-------|
| 網頁前端 / React / UI 工程 | `engineering-frontend-developer` | `engineering-senior-developer` | L1 |
| API / 後端架構 | `engineering-backend-architect` | `engineering-software-architect` | L1 |
| iOS / Android App | `engineering-mobile-app-builder` | `engineering-senior-developer` | L1 |
| 系統設計 / DDD | `engineering-software-architect` | `engineering-backend-architect` | L1 |
| MVP / POC / Hackathon | `engineering-rapid-prototyper` | `engineering-frontend-developer` | L1 |
| 複雜代碼 / 高級實作 | `engineering-senior-developer` | `engineering-code-reviewer` | L1 |
| PR / Code Review | `engineering-code-reviewer` | `engineering-senior-developer` | L1 |
| SQL / 索引 / Schema | `engineering-database-optimizer` | `engineering-backend-architect` | L1 |
| Git 規範 / Flow | `engineering-git-workflow-master` | `engineering-devops-automator` | L1 |
| 技術文件 / API 文件 | `engineering-technical-writer` | `engineering-senior-developer` | L1 |
| CI / CD / Pipeline | `engineering-devops-automator` | `engineering-sre` | L1 |
| SLO / Observability / Reliability | `engineering-sre` | `engineering-devops-automator` | L1 |
| Security / OWASP / Threat Review | `engineering-security-engineer` | `engineering-incident-response-commander` | L1 |
| Incident / Production Trouble | `engineering-incident-response-commander` | `engineering-sre` | L1 |
| UI Visual Design | `design-ui-designer` | `design-brand-guardian` | L1 |
| UX Architecture / IA | `design-ux-architect` | `design-ux-researcher` | L1 |
| User Research / Behavior | `design-ux-researcher` | `design-ux-architect` | L1 |
| Brand Consistency | `design-brand-guardian` | `design-ui-designer` | L1 |
| Data Viz / Slides / Visual Story | `design-visual-storyteller` | `design-ui-designer` | L1 |
| Delight / Micro-interactions | `design-whimsy-injector` | `design-ui-designer` | L1 |
| AI Image Prompting | `design-image-prompt-engineer` | `design-visual-storyteller` | L1 |
| Inclusive Visuals / Localization | `design-inclusive-visuals-specialist` | `design-brand-guardian` | L1 |
| Game Design / Core Loop | `game-designer` | `level-designer` | L1 |
| Level / Encounter / Difficulty | `level-designer` | `game-designer` | L1 |
| Narrative / Dialogue / Worldbuilding | `narrative-designer` | `game-designer` | L1 |
| Shader / VFX / Art Tools | `technical-artist` | `game-designer` | L1 |
| Audio / Interactive Sound | `game-audio-engineer` | `narrative-designer` | L1 |
| Content Calendar / Multi-platform Content | `marketing-content-creator` | `marketing-social-media-strategist` | L1 |
| Cross-channel Marketing Strategy | `marketing-social-media-strategist` | `marketing-content-creator` | L1 |
| Google SEO / Content Optimization | `marketing-seo-specialist` | `marketing-content-creator` | L1 |
| 小紅書內容 / 種草 | `marketing-xiaohongshu-specialist` | `marketing-content-creator` | L1 |
| 抖音短視頻 / 演算法 | `marketing-douyin-strategist` | `marketing-short-video-editing-coach` | L1 |
| 微信公眾號 / WeChat Content | `marketing-wechat-official-account` | `marketing-social-media-strategist` | L1 |
| 短視頻剪輯優化 | `marketing-short-video-editing-coach` | `marketing-douyin-strategist` | L1 |

## L2 Multi-Expert Patterns

| 複合任務 | Suggested Team |
|---------|----------------|
| 新產品功能上線 | `engineering-frontend-developer` + `engineering-backend-architect` + `design-ui-designer` + `engineering-code-reviewer` |
| 內容營銷 campaign | `marketing-content-creator` + `marketing-douyin-strategist` + `marketing-seo-specialist` |
| 遊戲 prototype | `game-designer` + `engineering-rapid-prototyper` + `narrative-designer` + `technical-artist` |
| 安全事件響應 | `engineering-incident-response-commander` + `engineering-security-engineer` + `engineering-sre` |
| SEO 全面審計 | `marketing-seo-specialist` + `design-ux-researcher` + `engineering-backend-architect` |
| UX 全面評審 | `design-ux-researcher` + `design-ui-designer` + `design-inclusive-visuals-specialist` + `testing-accessibility-auditor` |

## L3 Multi-Wave Work

When the task spans many domains or needs iteration, run a first wave of 2–4 experts, synthesize, then launch the second wave only where uncertainty remains.

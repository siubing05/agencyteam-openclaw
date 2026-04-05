# agencyteam — 面向 OpenClaw 的专家编排框架

🌐 [English](README.md) | **简体中文** | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

`agencyteam` 会把一组 specialist agent workspace 组织成一套可复用、适合 OpenClaw 的 expert orchestration workflow。

`agency-agents` 指的是上游公开 expert roster：[`msitarzewski/agency-agents`](https://github.com/msitarzewski/agency-agents)，而 `agencyteam` 会把它转换成 OpenClaw 可直接使用的 workspaces 和可安装 specialists。

适合用于：
- 并行 specialist review
- builder / reviewer 分工
- code + security + product 多视角综合
- 按需安装 [`agency-agents`](https://github.com/msitarzewski/agency-agents) upstream 专家

## 功能

- 将支持的 upstream prompts 转成 OpenClaw workspace：`~/.openclaw/agency-agents/<agent-id>/`
- 将 experts 注册到 `agents.list`
- 保留原有 config 中不属于 agencyteam 的 agents
- 将已安装 expert IDs merge 到 `main.subagents.allowAgents`（如果你原本已经使用 `['*']` wildcard，会保留）
- 提供 install / update / on-demand spawn scripts
- 用 `UPSTREAM_REF` 固定默认 upstream revision，让 install 更可复现
- 内置 GitHub Actions smoke test，降低 script regression

## 需求

- `openclaw`
- `git`
- `python3`

## Quick start

```bash
git clone https://github.com/siubing05/agencyteam-openclaw.git \
  ~/.openclaw/workspace/skills/agencyteam

cd ~/.openclaw/workspace/skills/agencyteam
./scripts/install.sh
```

## 安装选项

安装全部支持 experts：

```bash
./scripts/install.sh
# 或
./scripts/install.sh --all
```

只安装指定 experts：

```bash
./scripts/install.sh --agents "engineering-code-reviewer engineering-security-engineer design-ui-designer"
```

## Pinned upstream policy

默认会使用 `UPSTREAM_REF` 中记录的 commit。

- install 结果更可复现
- 比起隐式跟随 `main`，供应链漂移更小
- 如果你想刻意改 revision，可以用 `AGENCYTEAM_UPSTREAM_REF=<tag-or-commit>` 或 `./scripts/convert.sh --ref <tag-or-commit>` override

## Installer 实际会做什么

1. 将 upstream `agency-agents` clone 到临时目录
2. 将支持 category 转成 OpenClaw workspaces
3. 将对应 entries sync 到 `agents.list`
4. 将已安装 IDs merge 到 `main.subagents.allowAgents`
5. 备份 `openclaw.json`
6. 重启 gateway 并等待恢复响应

## 更新流程

先预览 upstream 变更：

```bash
./scripts/update.sh --dry-run
```

正式应用 upstream 变更：

```bash
./scripts/update.sh
```

如果要连 upstream 已移除的 agencyteam-managed agents 一起清理：

```bash
./scripts/update.sh --prune-removed
```

### 更新注意事项

- `update.sh` 会刷新生成出来的 `AGENTS.md`
- 如果你手改过 `~/.openclaw/agency-agents/` 里的生成文件，更新可能会覆盖
- 非 agencyteam agents 会保留
- `--prune-removed` 是 opt-in，避免静默删除

## 即装即用（缺失就补装）

```bash
./scripts/spawn-and-install.sh engineering-code-reviewer "Review this repository for correctness and maintainability" --timeout 600
```

## 验证

```bash
openclaw agents list
openclaw gateway status
```

## 高级环境变量

```bash
AGENCY_DEST=/tmp/agency-agents ./scripts/install.sh --agents "engineering-code-reviewer"
OPENCLAW_CONFIG_PATH=/tmp/openclaw.json ./scripts/update.sh --dry-run
AGENCYTEAM_UPSTREAM_REF=<tag-or-commit> ./scripts/install.sh
./scripts/convert.sh --ref <tag-or-commit>
```

## 定位

当你希望 OpenClaw 更像一个小型 expert panel，而不是单一 generalist assistant 时，就用 `agencyteam`。

## CI

GitHub Actions 会运行 `.github/workflows/ci.yml`，包括：
- bash syntax check
- python syntax check
- 使用 fake `openclaw` shim + 本地 upstream git repo 做 deterministic smoke test

另见：
- `SKILL.md`
- `references/routing.md`
- `references/workflows.md`

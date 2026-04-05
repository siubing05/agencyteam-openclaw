# agencyteam — 面向 OpenClaw 的專家編排框架

🌐 [English](README.md) | [简体中文](README.zh-CN.md) | **繁體中文** | [日本語](README.ja.md) | [한국어](README.ko.md)

`agencyteam` 會將一批 specialist agent workspace 組織成一套可重用、適合 OpenClaw 嘅 expert orchestration workflow。

`agency-agents` 係指上游公開 expert roster：[`msitarzewski/agency-agents`](https://github.com/msitarzewski/agency-agents)，而 `agencyteam` 會將佢轉成 OpenClaw 可直接使用嘅 workspaces 同可安裝 specialists。

適合用喺：
- 並行 specialist review
- builder / reviewer 分工
- code + security + product 多視角整合
- 按需安裝 [`agency-agents`](https://github.com/msitarzewski/agency-agents) upstream 專家

## 功能

- 將支援嘅 upstream prompts 轉成 OpenClaw workspace：`~/.openclaw/agency-agents/<agent-id>/`
- 將 experts 註冊到 `agents.list`
- 保留原本 config 入面唔屬於 agencyteam 嘅 agents
- 將已安裝 expert IDs merge 入 `main.subagents.allowAgents`（如果你原本已經用 `['*']` wildcard，會保留）
- 提供 install / update / on-demand spawn scripts
- 用 `UPSTREAM_REF` pin 住預設 upstream revision，令 install 更可重現
- 內置 GitHub Actions smoke test，減少 script regression

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

## 安裝選項

安裝全部支援 experts：

```bash
./scripts/install.sh
# 或
./scripts/install.sh --all
```

只安裝指定 experts：

```bash
./scripts/install.sh --agents "engineering-code-reviewer engineering-security-engineer design-ui-designer"
```

## Pinned upstream policy

預設會使用 `UPSTREAM_REF` 入面記錄嘅 commit。

- install 結果更可重現
- 比起默默追 `main`，供應鏈漂移更細
- 如果你想刻意改 revision，可以用 `AGENCYTEAM_UPSTREAM_REF=<tag-or-commit>` 或 `./scripts/convert.sh --ref <tag-or-commit>` override

## Installer 實際會做乜

1. 將 upstream `agency-agents` clone 去 temporary directory
2. 將支援 category 轉成 OpenClaw workspaces
3. 將對應 entries sync 入 `agents.list`
4. 將已安裝 IDs merge 入 `main.subagents.allowAgents`
5. 幫你 backup `openclaw.json`
6. restart gateway 並等待恢復回應

## 更新流程

先 preview upstream 變更：

```bash
./scripts/update.sh --dry-run
```

正式套用 upstream 變更：

```bash
./scripts/update.sh
```

如果想連 upstream 已移除嘅 agencyteam-managed agents 一齊清走：

```bash
./scripts/update.sh --prune-removed
```

### 更新注意事項

- `update.sh` 會 refresh 生成出嚟嘅 `AGENTS.md`
- 如果你手改過 `~/.openclaw/agency-agents/` 入面生成檔案，更新可能會覆蓋
- 非 agencyteam agents 會保留
- `--prune-removed` 係 opt-in，避免默默刪除

## 即裝即用（missing 就補裝）

```bash
./scripts/spawn-and-install.sh engineering-code-reviewer "Review this repository for correctness and maintainability" --timeout 600
```

## 驗證

```bash
openclaw agents list
openclaw gateway status
```

## 進階環境變數

```bash
AGENCY_DEST=/tmp/agency-agents ./scripts/install.sh --agents "engineering-code-reviewer"
OPENCLAW_CONFIG_PATH=/tmp/openclaw.json ./scripts/update.sh --dry-run
AGENCYTEAM_UPSTREAM_REF=<tag-or-commit> ./scripts/install.sh
./scripts/convert.sh --ref <tag-or-commit>
```

## 定位

當你想 OpenClaw 表現得似一個細型 expert panel，而唔係單一 generalist assistant，就用 `agencyteam`。

## CI

GitHub Actions 會跑 `.github/workflows/ci.yml`，包括：
- bash syntax check
- python syntax check
- 用 fake `openclaw` shim + 本地 upstream git repo 做 deterministic smoke test

另見：
- `SKILL.md`
- `references/routing.md`
- `references/workflows.md`

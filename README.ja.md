# agencyteam — OpenClaw 向けエキスパート・オーケストレーション・フレームワーク

🌐 [English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | **日本語** | [한국어](README.ko.md)

`agencyteam` は、複数の specialist agent workspace を OpenClaw 向けの再利用可能な expert orchestration workflow にまとめるフレームワークです。

`agency-agents` は上流の公開 expert roster で、[`msitarzewski/agency-agents`](https://github.com/msitarzewski/agency-agents) を指します。`agencyteam` はそれを OpenClaw ですぐ使える workspace と installable specialists に変換します。

## 主な機能

- upstream prompts を `~/.openclaw/agency-agents/<agent-id>/` の OpenClaw workspace に変換
- experts を `agents.list` に同期
- 既存の非 agencyteam agents を保持
- インストール済み IDs を `main.subagents.allowAgents` にマージ
- install / update / on-demand spawn scripts を提供
- `UPSTREAM_REF` で既定の upstream revision を固定し、再現性を高める
- GitHub Actions smoke test を同梱し、script regression を検出しやすくする

## 必要条件

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

## インストール

全 expert を登録:

```bash
./scripts/install.sh
```

特定 expert のみ登録:

```bash
./scripts/install.sh --agents "engineering-code-reviewer engineering-security-engineer"
```

## Pinned upstream policy

デフォルトでは `UPSTREAM_REF` に記録された commit を使います。

- install の再現性が高まる
- 暗黙に `main` を追従するより supply-chain drift を抑えられる
- 意図的に変えたい場合は `AGENCYTEAM_UPSTREAM_REF=<tag-or-commit>` または `./scripts/convert.sh --ref <tag-or-commit>` を使います

## 更新

変更をプレビュー:

```bash
./scripts/update.sh --dry-run
```

更新を適用:

```bash
./scripts/update.sh
```

upstream から消えた agencyteam-managed agents も削除:

```bash
./scripts/update.sh --prune-removed
```

## 即時インストール + 実行

```bash
./scripts/spawn-and-install.sh engineering-code-reviewer "Review this repository" --timeout 600
```

## 検証

```bash
openclaw agents list
openclaw gateway status
```

## CI

GitHub Actions は `.github/workflows/ci.yml` を実行し、以下を確認します。
- bash syntax check
- python syntax check
- fake `openclaw` shim とローカル upstream git repo を使う deterministic smoke test

詳細:
- `SKILL.md`
- `references/routing.md`
- `references/workflows.md`

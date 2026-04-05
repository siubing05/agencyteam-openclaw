# agencyteam — OpenClaw용 전문가 오케스트레이션 프레임워크

🌐 [English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | **한국어**

`agencyteam`은 여러 specialist agent workspace를 OpenClaw용으로 재사용 가능한 expert orchestration workflow로 묶어 주는 프레임워크입니다.

`agency-agents`는 상위 공개 expert roster인 [`msitarzewski/agency-agents`](https://github.com/msitarzewski/agency-agents)를 뜻하며, `agencyteam`은 이를 OpenClaw에서 바로 쓸 수 있는 workspaces와 설치 가능한 specialists로 변환합니다.

## 주요 기능

- upstream prompts를 `~/.openclaw/agency-agents/<agent-id>/` OpenClaw workspace로 변환
- experts를 `agents.list`에 동기화
- 기존의 non-agency agents 보존
- 설치된 IDs를 `main.subagents.allowAgents`에 병합
- install / update / on-demand spawn scripts 제공
- `UPSTREAM_REF`로 기본 upstream revision을 고정해 재현성을 높임
- GitHub Actions smoke test를 포함해 script regression을 더 빨리 잡음

## 요구 사항

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

## 설치

전체 expert 등록:

```bash
./scripts/install.sh
```

특정 expert만 등록:

```bash
./scripts/install.sh --agents "engineering-code-reviewer engineering-security-engineer"
```

## Pinned upstream policy

기본적으로 `UPSTREAM_REF`에 기록된 commit을 사용합니다.

- install 재현성이 높아짐
- 암묵적으로 `main`을 따라가는 것보다 supply-chain drift를 줄임
- 의도적으로 바꾸려면 `AGENCYTEAM_UPSTREAM_REF=<tag-or-commit>` 또는 `./scripts/convert.sh --ref <tag-or-commit>` 를 사용합니다

## 업데이트

변경 사항 미리보기:

```bash
./scripts/update.sh --dry-run
```

업데이트 적용:

```bash
./scripts/update.sh
```

upstream에서 사라진 agencyteam-managed agents도 제거:

```bash
./scripts/update.sh --prune-removed
```

## 즉시 설치 + 실행

```bash
./scripts/spawn-and-install.sh engineering-code-reviewer "Review this repository" --timeout 600
```

## 검증

```bash
openclaw agents list
openclaw gateway status
```

## CI

GitHub Actions는 `.github/workflows/ci.yml` 을 실행하여 아래를 확인합니다.
- bash syntax check
- python syntax check
- fake `openclaw` shim + 로컬 upstream git repo 기반 deterministic smoke test

자세한 내용:
- `SKILL.md`
- `references/routing.md`
- `references/workflows.md`

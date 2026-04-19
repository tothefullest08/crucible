---
name: using-harness
description: "하네스 6축 런북 / Harness 6-axis runbook — SessionStart 시 자동 주입되는 현재 세션의 6축 진입 가이드"
---

# using-harness — 하네스 6축 런북 / Harness 6-Axis Runbook

> 본 문서는 `hooks/session-start.sh`에 의해 **세션 시작 시 1회 자동 주입**된다.
> Injected once at session start by `hooks/session-start.sh`.
> 다른 스킬은 `Skill` 도구로 호출하되, 본 런북은 별도 호출이 필요 없다.
> Other skills must be invoked via the `Skill` tool; this runbook is delivered automatically.

---

## 1. 하네스 6축 개요 / 6-Axis Overview

| # | 축 / Axis | 한 줄 정의 / One-line definition |
|---|-----------|----------------------------------|
| 1 | **구조 / Structure** | 코드·산출물을 담을 뼈대와 파일 배치를 고정한다. Lock the skeleton and file layout that holds the work. |
| 2 | **맥락 / Context** | 결정에 필요한 기존 자산·히스토리·제약을 수집한다. Gather prior artifacts, history, and constraints. |
| 3 | **계획 / Plan** | 목표를 단계·태스크·검증 게이트로 분해한다. Decompose the goal into phases, tasks, and gates. |
| 4 | **실행 / Execute** | 계획된 단위를 실제로 구현·편집·배포한다. Actually implement the planned units. |
| 5 | **검증 / Verify** | 산출물이 의도·스펙·계약을 만족하는지 확인한다. Confirm outputs match intent, spec, and contracts. |
| 6 | **개선 / Compound** | 반복·실패·재지시를 KU(Knowledge Unit)로 승격해 미래 세션에 재투입한다. Promote repeats and corrections into Knowledge Units that compound across sessions. |

---

## 2. 진입 명령 매핑 / Entry-Command Mapping

| 축 / Axis | 명령 / Command | 상태 / Status |
|-----------|----------------|---------------|
| 계획 / Plan | `/brainstorm` → `/plan` | W3 도입 예정 / planned W3 |
| 실행 / Execute | (사용자 수동 작업 / user-driven manual work) | — |
| 검증 / Verify | `/verify` | W4 도입 예정 / planned W4 |
| 개선 / Compound | `/compound` | W6 도입 예정 / planned W6 |
| 오케스트레이션 / Orchestration | `/orchestrate` | W7 Stretch |

실행 축(4)은 명령이 아니라 **사용자가 직접 코드를 수정·배포하는 단계**이다. 하네스는 그 앞뒤의 계획·검증·개선만을 고정한다.
Axis 4 has no command — it is the human-driven editing/deploy step. Harness only fixes the axes around it.

---

## 3. 언제 무엇을 쓰나 / When to Use What

| 시나리오 / Scenario | 권장 진입점 / Recommended entry |
|---------------------|---------------------------------|
| 요구가 모호하고 탐색이 먼저 필요하다 / Requirement is vague, needs exploration | `/brainstorm` → `/plan` |
| 요구는 명확하나 단계·게이트 설계가 필요하다 / Clear requirement but needs phased plan | `/plan` |
| 산출물이 스펙을 만족하는지 확인해야 한다 / Must confirm outputs meet spec | `/verify` |
| 반복·실패·재지시 패턴이 감지되어 학습을 남기고 싶다 / Loops/failures/corrections detected, want to learn from them | `/compound` |
| 계획부터 개선까지 한 번에 파이프라인으로 돌리고 싶다 / Full pipeline in one shot | `/orchestrate` (Stretch) |
| 단발성 질문·짧은 작업 / One-off question, short task | 하네스 생략 가능 / harness optional |

---

## 4. 승격 게이트 원칙 / Promotion-Gate Principles

*근거 / Reference: final-spec v3.1 §3 (승격 게이트 UX).*

- **자동 저장 금지 / No silent persistence** — `/compound`가 감지한 KU 후보는 즉시 메모리에 기록되지 **않는다**. 사용자 승인 단계를 반드시 거친다. Candidate KUs detected by `/compound` are never auto-saved; explicit user approval is mandatory.
- **승격 단위 = KU 한 건 / Unit of promotion is one KU** — 배치 승격은 거부 근거 추적을 흐리므로 권장하지 않는다. Batch promotion obscures rejection traces and is discouraged.
- **거부 기록 보존 / Preserve rejections** — 사용자가 거절한 KU도 `.claude/memory/corrections/skip-log.md`에 사유와 함께 기록해 재제안을 방지한다. Rejected KUs are logged with reasons to prevent re-suggestion.
- **세션 말미 트리거 / End-of-session trigger** — 승격 프롬프트는 대화 중간이 아니라 `Stop` 이벤트 직후 한 번만 띄운다. The promotion prompt fires once on `Stop`, never mid-conversation.

---

## 5. 6축 강제 적용 범위 / 6-Axis Enforcement Matrix

*근거 / Reference: final-spec v3.1 §3.5.*

| 진입점 / Entry | 1 구조 | 2 맥락 | 3 계획 | 4 실행 | 5 검증 | 6 개선 |
|----------------|:------:|:------:|:------:|:------:|:------:|:------:|
| `/plan`         | **ON** | **ON** | **ON** | 힌트 / hint | **ON** | 힌트 / hint |
| `/verify`       | **ON** | **ON** | 힌트 / hint | **ON** | **ON** | **ON** |
| `/orchestrate`  | **ON** | **ON** | **ON** | **ON** | **ON** | **ON** |
| `/brainstorm`   | 힌트 / hint | 힌트 / hint | 힌트 / hint | — | — | — |
| `/compound`     | — | 힌트 / hint | — | — | 힌트 / hint | **ON** |
| 일반 Q&A / General Q&A | — | — | — | — | — | — |

- **ON** — 축 통과 없이 산출물 배출 차단 (HARD-GATE). Hard gate; no output is emitted until the axis passes.
- **힌트 / hint** — 체크리스트만 제안, 강제 없음. Checklist suggestion only, no enforcement.
- **— / dash** — 해당 진입점에서 해당 축은 비활성. Axis inactive for this entry point.

**이스케이프 해치 / Escape hatch**: `/plan [...] --skip-axis 2,3` (N=1~6). 검증 축(5) 스킵은 `--acknowledge-risk`를 추가로 요구한다. Skipping axis 5 additionally requires `--acknowledge-risk`.

---

## 6. 한국어 / 영어 UX / Bilingual UX

*근거 / Reference: final-spec v3.1 §3.3.*

- **description 한·영 병기 / Bilingual description** — 모든 스킬·에이전트의 `description` 필드는 한국어와 영어 트리거를 같이 둔다. Every `description` field lists Korean and English triggers together.
- **README 이중 유지 / Dual README** — 영어 `README.md` + 한국어 `README.ko.md`. English README plus a Korean sibling.
- **스킬 본문 / Skill body** — 오픈소스 호환을 위해 영어 고정이 원칙. 예외: 본 런북처럼 한국어 사용자를 1차 청자로 하는 운영 문서는 한·영 병기. Default to English for OSS interop; bilingual only where Korean users are the primary audience (e.g., this runbook).
- **`--lang ko` 플래그 / `--lang ko` flag** — 에이전트 응답 언어 분기는 향후 도입 예정 (Phase 2). Agent-response language switch is a future flag.

---

## 7. 에러·제한사항 / Errors & Limitations

*근거 / Reference: final-spec v3.1 §4.2 degradation.*

- **JSONL 스키마 변화 시 컴파운딩 비활성화 / Compounding disabled on JSONL schema drift** — `scripts/schema-adapter.sh`가 알 수 없는 `schema_version`을 감지하면 해당 세션의 `/compound` 동작을 중단하고 stderr에 경고만 남긴다. 사용자 작업은 차단하지 않는다. When an unknown `schema_version` is seen, `/compound` is skipped for that session; user flow is never blocked.
- **SessionStart 훅 실패 시 / If SessionStart hook fails** — `hooks/session-start.sh`는 어떤 오류에서도 `exit 0`으로 종료해 세션 진입을 막지 않는다. 페이로드 주입이 빠진 세션에서는 본 런북을 명시적으로 읽지 않는다. The hook always exits 0; sessions without payload injection simply do not auto-load this runbook.
- **SHA256 무결성 / Payload integrity** — `plugin.json`에 `.harness.payload_sha256`가 선언된 경우에만 검사하며, MVP 단계에서는 필드 부재 시 스킵한다. Checked only when declared in `plugin.json`; skipped in MVP if absent.
- **외부 도구 금지 / No external tooling** — 훅·스크립트는 `bash + jq`만 사용한다. Python/Node 의존성을 끌어오지 않는다. Hooks and scripts use `bash + jq` only; no Python/Node dependencies.
- **본 런북 범위 / Scope of this runbook** — 6축의 "왜"와 "언제"만 다룬다. 각 명령의 상세 사용법은 개별 스킬(`/plan`, `/verify`, `/compound` …)의 `SKILL.md`를 참조한다. Covers only the "why" and "when" of the axes; detailed command semantics live in each command's own `SKILL.md`.

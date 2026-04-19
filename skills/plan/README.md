# `/plan` — Implementation Planning with Hybrid Markdown + YAML Frontmatter

> Turn a requirements document into a structured, file-backed implementation plan at
> `.claude/plans/YYYY-MM-DD-{slug}-plan.md`.
> 요구사항 문서를 구조화된 구현 계획 파일로 변환합니다.

The skill runs the CE `ce-plan` **5-Phase protocol** (Intake → Decomposition →
Evaluation Principles → Gap Analysis → Finalize) adapted to harness' 6-axis
Plan axis. Output is a hybrid artifact: **Markdown body** (phases, tasks, gaps)
with **YAML frontmatter** (goal, constraints, AC, evaluation_principles,
exit_conditions). See [`SKILL.md`](./SKILL.md) for the authoritative protocol
and [`templates/plan-template.md`](./templates/plan-template.md) for the output
schema.

- **Input path**: `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` (from `/brainstorm`) — any absolute or relative path accepted.
- **Output path**: `.claude/plans/YYYY-MM-DD-{slug}-plan.md`
- **Slug whitelist**: `[a-zA-Z0-9_-]` (enforced by `scripts/plan-slug-hook.sh`)
- **Ambiguity Gate**: `scripts/ambiguity-gate.sh` at Phase 1 — score ≥ 0.2 rejects and requests re-`/brainstorm`.
- **Weight assertion**: `evaluation_principles[].weight` sum must equal `1.0 ± 0.001`.
- **Self-check**: frontmatter `validate_prompt` triggers a PostToolUse advisory via `hooks/validate-output.sh` when required sections are missing.
- **Pipeline**: [`/brainstorm`](../brainstorm/README.md) → `/plan` → `/verify` → `/compound`.

---

## English Examples

### Example 1 — Feature Plan · Login feature from `/brainstorm` output

This example demonstrates the golden path: a requirements document emitted by
`/brainstorm` is decomposed into implementation units, evaluation principles
are weighted to `1.0`, gaps are surfaced, and the plan is saved.

#### Input

The user has already produced
`.claude/plans/2026-04-19-login-feature-requirements.md` via
[`/brainstorm`](../brainstorm/README.md). The requirement file's frontmatter
and body look like:

```markdown
---
lens: vague
topic: "add a login feature"
date: 2026-04-19
decisions:
  - question: Authentication method
    decision: OAuth (Google) + Magic link fallback
    reasoning: Removes password storage + matches returning-user flow.
open_questions: []
---

# Login feature — Requirements

## Goal
Returning customers log in without re-entering payment information.

## Scope
- Included: OAuth Google, magic link fallback, session persistence.
- Excluded: SAML SSO, mobile-only paths, password reset UX (v2).

## Constraints
- Must not store raw passwords.
- p95 login latency < 500 ms.

## Success Criteria
- Account-creation success ≥ 99 %.
- 0 password-storage incidents at audit.
```

The user then invokes:

```
/plan .claude/plans/2026-04-19-login-feature-requirements.md
```

#### Claude's Phases

**Phase 1 — Intake** — parses frontmatter (`yq`) and body (`awk`) for Goal /
Scope / Constraints / Success Criteria. Calls
`bash scripts/ambiguity-gate.sh "$REQUIREMENTS_PATH"`. Example verdict:

```json
{ "score": 0.08, "verdict": "pass", "reasons": [] }
```

Score is below the `0.2` threshold → proceed to Phase 2.

**Phase 2 — Decomposition** — splits the Goal into atomic implementation units
and assigns `model_tier` hints (porting asset #15):

| id | goal | files | depends_on | model_tier |
|----|------|-------|------------|------------|
| U1 | OAuth Google redirect handler | `app/auth/oauth.ts` | — | subagent |
| U2 | Magic link token issuance | `app/auth/magic.ts` | U1 | subagent |
| U3 | Session persistence cookie | `app/session/cookie.ts` | U1 | subagent |
| U4 | Integration test harness | `__tests__/auth.test.ts` | U1, U2, U3 | validator |

**Phase 3 — Evaluation Principles** — maps Success Criteria to weights.
`jq` asserts `sum(weight) == 1.0`:

```yaml
evaluation_principles:
  - name: correctness
    weight: 0.5
    description: Auth flow matches specification end-to-end.
    metric: "AC.hard 4/4 pass"
  - name: security
    weight: 0.3
    description: No raw passwords stored, token expiry enforced.
    metric: "security-reviewer 0 CRITICAL"
  - name: latency
    weight: 0.2
    description: p95 login < 500 ms.
    metric: "k6 load test p95 < 500"
```

**Phase 4 — Gap Analysis** — `bash scripts/gap-analyzer.sh "$REQUIREMENTS_PATH"`
returns a list. Example output:

```json
[
  { "gap": "Missing rate-limit constraint", "category": "Constraint" },
  { "gap": "No rollback plan on OAuth provider outage", "category": "Ops" }
]
```

The user decides: **gap #1** integrated into Phase 2 (new unit U5 — rate limit
middleware); **gap #2** deferred to `open_questions` frontmatter.

**Phase 5 — Finalize + Save** — loads
[`templates/plan-template.md`](./templates/plan-template.md), computes
`slug = "login-feature"`, passes through `scripts/plan-slug-hook.sh`
(whitelist `[a-zA-Z0-9_-]`), re-asserts weight sum, then writes to disk.

#### Output

File created at `.claude/plans/2026-04-19-login-feature-plan.md` with the
following frontmatter skeleton (abbreviated):

```yaml
---
goal: "Returning customers log in without re-entering payment info"
constraints:
  - "Must not store raw passwords"
  - "p95 login latency < 500 ms"
AC:
  hard:
    - "OAuth Google flow completes in < 500 ms p95"
    - "Magic link token expires after 15 min"
    - "Session cookie is HttpOnly + Secure"
    - "0 password-storage incidents at audit"
  stretch:
    - "Rate-limit per-IP 10/min"
evaluation_principles:
  - { name: correctness,    weight: 0.5, metric: "AC.hard 4/4 pass" }
  - { name: security,       weight: 0.3, metric: "security-reviewer 0 CRITICAL" }
  - { name: latency,        weight: 0.2, metric: "k6 p95 < 500ms" }
exit_conditions:
  success: "All AC.hard pass + security-reviewer clean"
  failure: "Any raw-password incident OR > 2 CRITICAL issues"
  timeout: "3d"
parent_seed_id: null
slug: "login-feature"
date: "2026-04-19"
open_questions:
  - "Rollback plan when OAuth provider outage exceeds 5 min"
---
```

Claude's final response echoes the absolute path of the saved plan on its last
line and suggests the next step: `/verify`.

---

### Example 2 — Refactor Plan · Legacy `utils/` cleanup

This example demonstrates tighter weighting for maintainability and explicit
`exit_conditions` tailored to a refactor (no new feature). The Ambiguity
Gate passes because the requirements spelled out what is *excluded*.

#### Input

Requirements file `.claude/plans/2026-04-19-legacy-utils-refactor-requirements.md`:

```markdown
---
lens: vague
topic: "refactor legacy utils/"
date: 2026-04-19
decisions:
  - question: Should we rewrite or incrementally split?
    decision: Incremental split by domain (date/currency/dom)
    reasoning: Lower merge-conflict risk + reviewable per-PR diff.
---

# Legacy utils/ — Requirements

## Goal
Split `src/utils.ts` (1420 lines) into 4 domain-scoped modules without behavior change.

## Scope
- Included: date/, currency/, dom/, guard/ folders; call-site migration.
- Excluded: API redesign, TypeScript strict-mode upgrade.

## Constraints
- Zero behavior change — every existing test must pass unchanged.
- No public API rename in this pass.

## Success Criteria
- All existing tests pass (300+).
- No file > 400 lines post-split.
- Bundle size delta within ±2 %.
```

Invocation:

```
/plan .claude/plans/2026-04-19-legacy-utils-refactor-requirements.md
```

#### Claude's Phases

**Phase 1 — Intake** — Ambiguity Gate returns
`{ "score": 0.05, "verdict": "pass" }`. All fields present, `Excluded`
is explicit.

**Phase 2 — Decomposition** — 4 units, mostly parallel (no hard
`depends_on` chain across domains):

- U1 — extract `date/` module (≈ 320 lines) — `subagent`.
- U2 — extract `currency/` module (≈ 280 lines) — `subagent`.
- U3 — extract `dom/` module (≈ 190 lines) — `subagent`.
- U4 — call-site migration (IDE-driven) — `validator`.

Test expectation: `U1-U3` carry no new tests (non-feature-bearing); U4
reruns the existing 300+ test suite unchanged.

**Phase 3 — Evaluation Principles** — weights tilt toward correctness and
maintainability because the refactor's value is structural, not
behavioral:

```yaml
evaluation_principles:
  - name: correctness
    weight: 0.5
    description: No behavior change — every existing test passes.
    metric: "npm test exit 0 + 300+ pass unchanged"
  - name: clarity
    weight: 0.3
    description: Each file's responsibility is obvious from its path.
    metric: "1 domain per file, file names match folder names"
  - name: maintainability
    weight: 0.2
    description: Lower cost to modify per domain.
    metric: "no file > 400 lines, no cross-domain import cycle"
```

**Phase 4 — Gap Analysis** — gap-analyzer flags "no rollback plan for
call-site migration"; user decides to add U5 (git tag before U4) into
Phase 2.

**Phase 5 — Finalize + Save** — `slug = "legacy-utils-refactor"`
passes the whitelist; `exit_conditions` record strict rollback/abort
rules befitting a refactor:

```yaml
exit_conditions:
  success: "All 300+ tests pass + no file > 400 lines + bundle delta ≤ 2%"
  failure: "Any test regression OR bundle delta > 2%"
  timeout: "5d — if exceeded, revert to pre-refactor git tag"
```

#### Output

File written to
`.claude/plans/2026-04-19-legacy-utils-refactor-plan.md` containing the
frontmatter above plus a Markdown body with Phase sections, a Tasks
table (U1–U5 with time estimates), a Gaps section, and a Mermaid
dependency graph (4 units → 1 validator).

---

## 한국어 예제

### 예제 1 — 기능 계획 · 로그인 기능

이 예제는 `/brainstorm` 한국어 출력에서 시작해 `/plan` 이 한국어 요구사항도
동일하게 처리함을 보여줍니다. frontmatter/본문 파싱은 언어 비의존적이며,
Claude 응답만 한국어로 렌더링됩니다.

#### Input / 입력

`/brainstorm` 산출 파일
`.claude/plans/2026-04-19-login-feature-requirements.md`:

```markdown
---
lens: vague
topic: "로그인 기능 추가해줘"
date: 2026-04-19
decisions:
  - question: 인증 방식
    decision: OAuth (Google) + 매직 링크 백업
    reasoning: 비밀번호 저장 제거 + 재방문 흐름과 정합
---

# 로그인 기능 — 요구사항

## Goal / 목표
재방문 고객이 결제 정보를 재입력하지 않도록 지속 세션 로그인 제공.

## Scope / 범위
- Included: OAuth Google, 매직 링크 fallback, 세션 쿠키.
- Excluded: SAML SSO, 모바일 전용 경로.

## Constraints / 제약
- 원시 비밀번호를 절대 저장하지 않는다.
- p95 로그인 지연 < 500 ms.

## Success Criteria / 성공 기준
- 계정 생성 성공률 ≥ 99 %.
- 감사 시 비밀번호 저장 인시던트 0건.
```

호출:

```
/plan .claude/plans/2026-04-19-login-feature-requirements.md
```

#### Claude's Phases / Claude의 단계

**Phase 1 — Intake (수집)** — frontmatter/본문을 파싱하고
`scripts/ambiguity-gate.sh` 를 호출.

```json
{ "score": 0.08, "verdict": "pass", "reasons": [] }
```

모호도 점수가 임계(0.2) 미만이므로 Phase 2 진행.

**Phase 2 — Decomposition (분해)** — 목표를 원자적 구현 단위로 나누고
`model_tier` 를 부여:

- U1 — OAuth Google redirect 핸들러 (`subagent`)
- U2 — 매직 링크 토큰 발급 (`subagent`, `depends_on: [U1]`)
- U3 — 세션 쿠키 지속성 (`subagent`, `depends_on: [U1]`)
- U4 — 통합 테스트 하네스 (`validator`, `depends_on: [U1, U2, U3]`)

**Phase 3 — Evaluation Principles (평가 원칙)** — 가중치 합 = 1.0.
`evaluation_principles` 의 한·영 병기 설명:

```yaml
evaluation_principles:
  - name: correctness
    weight: 0.5
    description: "명세대로 auth 흐름이 동작한다 / Auth flow matches spec"
    metric: "AC.hard 4/4 pass"
  - name: security
    weight: 0.3
    description: "비밀번호 저장 0건·토큰 만료 강제 / 0 raw-password storage"
    metric: "security-reviewer 0 CRITICAL"
  - name: latency
    weight: 0.2
    description: "p95 로그인 지연 < 500 ms / p95 login < 500 ms"
    metric: "k6 load test p95 < 500"
```

`jq` 로 `sum(weight) == 1.0 ± 0.001` 검증 통과.

**Phase 4 — Gap Analysis (격차 분석)** — 사용자에게 한국어로 프롬프트:

> 다음 격차가 감지되었습니다. 어떻게 처리할까요?
> 1. **속도 제한 제약 누락** — ① 계획에 통합 ② open_questions 이월 ③ scope.excluded 로 명시
> 2. **OAuth 제공자 장애 시 롤백 전략 부재** — 동일 3지선다

사용자 선택을 받아 `gap_resolutions[]` 에 기록하고 Phase 2·3 보강.

**Phase 5 — Finalize + Save (확정·저장)** — `slug = "login-feature"`,
템플릿 [`templates/plan-template.md`](./templates/plan-template.md) 를 로드,
하이브리드 포맷으로 `.claude/plans/2026-04-19-login-feature-plan.md` 저장.

#### Output / 산출물

```yaml
---
goal: "재방문 고객이 결제 정보 재입력 없이 지속 세션 로그인"
constraints:
  - "원시 비밀번호 저장 금지"
  - "p95 로그인 지연 < 500 ms"
AC:
  hard:
    - "OAuth Google 흐름 p95 < 500 ms 완료"
    - "매직 링크 토큰 15분 만료"
    - "세션 쿠키 HttpOnly + Secure"
    - "감사 시 비밀번호 저장 인시던트 0건"
  stretch:
    - "IP당 10/min 속도 제한"
evaluation_principles:
  - { name: correctness, weight: 0.5, metric: "AC.hard 4/4 pass" }
  - { name: security,    weight: 0.3, metric: "security-reviewer 0 CRITICAL" }
  - { name: latency,     weight: 0.2, metric: "k6 p95 < 500ms" }
exit_conditions:
  success: "AC.hard 전부 pass + security-reviewer clean"
  failure: "비밀번호 저장 인시던트 1건 OR CRITICAL > 2건"
  timeout: "3d"
parent_seed_id: null
slug: "login-feature"
date: "2026-04-19"
open_questions:
  - "OAuth 제공자 5분 이상 장애 시 롤백 절차"
---
```

Claude 의 마지막 응답 줄은 저장된 절대 경로이며, 다음 단계로
`/verify` 호출을 제안합니다.

---

### 예제 2 — 리팩터링 계획 · Ambiguity Gate 거부 시나리오

이 예제는 Ambiguity Gate 가 **`reject`** 평결을 내리고 Claude 가
재-`/brainstorm` 을 권고하는 경로를 보여줍니다. v3.1 §4.3 보안 제약에 따라
자동 진행하지 않고 사용자 확인을 받습니다.

#### Input / 입력

불완전한 요구사항 파일
`.claude/plans/2026-04-19-legacy-cleanup-requirements.md`:

```markdown
---
lens: vague
topic: "레거시 코드 정리해줘"
date: 2026-04-19
decisions: []
open_questions:
  - "범위가 어디까지인가?"
  - "어떤 모듈을 먼저 건드릴까?"
---

# 레거시 코드 정리 — 요구사항

## Goal / 목표
오래된 코드 정리.

## Scope / 범위
- Included: TBD
- Excluded: TBD

## Constraints / 제약
- TBD

## Success Criteria / 성공 기준
- 코드가 깔끔해진다.
```

호출:

```
/plan .claude/plans/2026-04-19-legacy-cleanup-requirements.md
```

#### Claude's Phases / Claude의 단계

**Phase 1 — Intake (수집)** — Ambiguity Gate 호출 결과:

```json
{
  "score": 0.72,
  "verdict": "reject",
  "reasons": [
    "decisions[] 비어 있음",
    "Scope Included/Excluded 모두 TBD",
    "Success Criteria 측정 불가 ('깔끔해진다')",
    "Constraints TBD",
    "open_questions 2건 (미결)"
  ]
}
```

점수 `0.72 ≥ 0.2` → **Phase 2 진입 금지**.

Claude 의 응답:

> 요구사항 문서의 모호도 점수가 **0.72**(임계 `0.2`)로 너무 높아
> `/plan` 이 계획을 수립할 수 없습니다. 다음 중 하나를 선택해주세요:
>
> 1. `/brainstorm 레거시 코드 정리 범위 명확화` 로 재브레인스토밍 (권장)
> 2. 요구사항 파일을 직접 수정 후 `/plan` 재실행
> 3. 진행 중단
>
> (이유: `decisions[]` 0건, `Scope` TBD, `Success Criteria` 측정 불가,
>  `Constraints` TBD, `open_questions` 2건 미결.)

`AskUserQuestion` 툴이 있으면 3지선다로 제시, 없으면 번호 옵션 텍스트로
출력 후 대기합니다.

**Phase 2~5 — Skipped (건너뜀)** — Ambiguity Gate 가 `reject` 이므로
후속 Phase 는 실행되지 않습니다. Phase 2 분해, Phase 3 가중치 계산,
Phase 4 gap 분석, Phase 5 저장 **모두 수행되지 않습니다**.
자동 정규화·자동 추측·자동 저장은 전부 금지됩니다 (v3.1 §4.3).

#### Output / 산출물

**파일이 생성되지 않습니다.** 사용자가 재-`/brainstorm` 을 선택하면
[`/brainstorm`](../brainstorm/README.md) 이 시작되며, 새 요구사항 파일이
완성된 후 `/plan` 을 다시 호출해야 합니다. 이 경로는 실패 fallback
(SKILL.md Phase 1 §실패 시 fallback 참조) 이며 **정상적 동작** 입니다 —
잘못된 입력에 근거한 계획 파일이 디스크에 남지 않도록 하는 방어선입니다.

---

## Integration Points / 연동 지점

| 단계 | 입력 | 출력 | 다음 |
|------|------|------|------|
| [`/brainstorm`](../brainstorm/README.md) | 모호한 주제 | `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` | `/plan` |
| **`/plan`** | requirements.md | `.claude/plans/YYYY-MM-DD-{slug}-plan.md` | `/verify` |
| `/verify` | plan.md | 검증 보고 + qa-judge 스코어 | `/compound` (학습 승격) |
| `/compound` | 승격된 학습 | `MEMORY.md` 업데이트 | — |

- **Pre-gate**: Ambiguity Score Gate — 점수 ≥ 0.2 시 `reject`, 재-`/brainstorm`.
- **Schema source**: [`templates/plan-template.md`](./templates/plan-template.md).
- **Validation script**: `skills/plan/templates/validate-weights.sh` — frontmatter `evaluation_principles[].weight` 합이 `1.0 ± 0.01` 임을 assert.
- **Self-check**: `validate_prompt` frontmatter 필드 → `hooks/validate-output.sh` PostToolUse 권고.

## Next Step / 다음 단계

생성된 plan 파일은 `/verify` 의 입력이 됩니다. `/verify` 는 frontmatter
`evaluation_principles` 와 `exit_conditions` 를 읽어 qa-judge 점수를 산출하고
회색지대(0.40–0.80) 재검증 여부를 판정합니다. 승격된 학습은 `/compound` 가
`MEMORY.md` 로 컴파운딩합니다.

The saved plan file feeds directly into `/verify`, which reads the frontmatter
`evaluation_principles` and `exit_conditions` to compute a qa-judge score and
decide whether a grey-zone (0.40–0.80) re-evaluation is needed. Accepted
learnings then flow into `/compound` for `MEMORY.md` compounding.

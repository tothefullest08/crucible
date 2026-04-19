# `/brainstorm` — Requirement Brainstorming with Embedded Clarify 3-Lens

> Turn a vague topic into a concrete, file-backed requirements document at
> `.claude/plans/YYYY-MM-DD-{slug}-requirements.md`.
> 모호한 주제를 구체적인 요구사항 파일로 변환합니다.

The skill auto-selects one of three lenses (**vague · unknown · metamedium**)
and runs a 3-round clarifying dialogue before writing the spec. The detailed
protocol lives in [`SKILL.md`](./SKILL.md) — this README focuses on
copy-pasteable examples for everyday use.

- **Output path**: `.claude/plans/YYYY-MM-DD-{slug}-requirements.md`
- **Slug whitelist**: `[a-zA-Z0-9_-]` (enforced by `templates/slug-validator.sh`)
- **Self-check**: `validate_prompt` frontmatter triggers a PostToolUse advisory
  via `hooks/validate-output.sh` when mandatory sections are missing.
- **Downstream**: feed the generated requirements file into `/plan` for task
  decomposition.

---

## English Examples

### Example 1 — Vague lens · simple feature request

**Input**

```
/brainstorm add a login feature
```

**Claude’s clarifying questions** (Round 1, batched via `AskUserQuestion`)

1. Which authentication method should the login use? — Email + Password /
   OAuth (Google/GitHub) / Magic link / Other
2. What should happen after registration? — Immediate access /
   Email verification first / Other
3. Who is the primary user? — Returning customers / First-time visitors /
   Internal staff / Other
4. What is the must-have scope for v1? — Auth only / Auth + profile /
   Auth + profile + billing / Other

Round 2 drills into whichever option was marked *Other* or contradictory.

**Final artifact**

`.claude/plans/2026-04-19-login-feature-requirements.md`

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
...

## Scope
Included: OAuth Google, magic link fallback
Excluded: SAML SSO, mobile-only paths

## Success Criteria
- p95 login latency < 500 ms
- Account-creation success ≥ 99%

## Decisions Made
| Ambiguity | Chosen | Reasoning |
|-----------|--------|-----------|
| Auth method | OAuth + magic link | Minimal friction for repeat users |
| Post-signup | Immediate access | Verification via email fallback |
```

---

### Example 2 — Unknown lens · strategy review

**Input**

```
/brainstorm review our growth strategy
```

**Claude’s clarifying questions** (Round 1)

1. What is the primary revenue source today? — Self-serve PLG /
   Outbound sales / Marketplace / Other
2. Which of these connections feels weakest? *(multiSelect)* — ICP clarity /
   Activation funnel / Pricing tiers / Retention
3. What existing asset is under-leveraged? *(from CLAUDE.md + prior docs)* —
   Design partner list / Community / Internal tooling / Other
4. What is your biggest fear if nothing changes? — Runway / Churn /
   Competitor moat / Other

**Final artifact**

`.claude/plans/2026-04-19-growth-strategy-requirements.md`

```markdown
---
lens: unknown
topic: "review our growth strategy"
date: 2026-04-19
stop_doing:
  - "Sponsor webinars with <3% conversion"
  - "Generic outbound to long-tail industries"
---

# Growth Strategy — Known/Unknown Quadrant Analysis

## Quadrant Matrix (60/25/10/5)
- **Known Knowns (~60%)**: PLG funnel, retention cohort baselines
- **Known Unknowns (~25%)**: pricing elasticity on mid-market tier
- **Unknown Knowns (~10%)**: 47 design-partner transcripts unused
- **Unknown Unknowns (~5%)**: vertical-specific compliance shifts

## Stop Doing
1. Sponsor webinars below 3% conversion.
2. Generic outbound to long-tail industries.

## Execution Roadmap (weeks)
...
```

---

## 한국어 예제

### 예제 1 — vague 렌즈 · 모호한 요구사항

**입력**

```
/brainstorm 로그인 기능 추가해줘
```

**Claude의 명확화 질문** (Round 1, `AskUserQuestion` 배치 호출)

1. 어떤 인증 방식을 사용할까요? — 이메일+비밀번호 / OAuth (Google/GitHub) /
   매직 링크 / 기타
2. 가입 직후 흐름은? — 즉시 접속 / 이메일 확인 후 접속 / 기타
3. 주요 사용자는? — 재방문 고객 / 첫 방문자 / 내부 직원 / 기타
4. v1 스코프 최소 집합은? — 인증만 / 인증+프로필 / 인증+프로필+결제 / 기타

Round 2에서는 '기타' 응답이나 충돌된 선택을 깊게 파고듭니다.

**최종 산출물**

`.claude/plans/2026-04-19-login-feature-requirements.md`

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
- Included: OAuth Google, 매직 링크 fallback
- Excluded: SAML SSO, 모바일 전용 경로

## Success Criteria / 성공 기준
- p95 로그인 지연 < 500 ms
- 계정 생성 성공률 ≥ 99%
```

---

### 예제 2 — unknown 렌즈 · 전략 점검

**입력**

```
/brainstorm 우리 전략 점검해줘
```

**Claude의 명확화 질문** (Round 1)

1. 현재 주력 매출원은? — Self-serve PLG / 아웃바운드 세일즈 /
   마켓플레이스 / 기타
2. 가장 약한 연결 고리는? *(multiSelect)* — ICP 명확성 / 활성화 퍼널 /
   가격 체계 / 리텐션
3. 덜 활용 중인 기존 자산은? *(CLAUDE.md / 과거 문서 기반)* —
   디자인 파트너 명단 / 커뮤니티 / 내부 툴 / 기타
4. 아무것도 바꾸지 않을 때 가장 두려운 시나리오는? — 런웨이 / 이탈률 /
   경쟁사 해자 / 기타

**최종 산출물**

`.claude/plans/2026-04-19-growth-strategy-requirements.md`

```markdown
---
lens: unknown
topic: "우리 전략 점검해줘"
date: 2026-04-19
stop_doing:
  - "전환율 3% 미만인 웨비나 후원"
  - "롱테일 산업 대상 일괄 아웃바운드"
---

# 성장 전략 — Known/Unknown 4분면 분석

## 4분면 매트릭스 (60/25/10/5)
- **Known Knowns (~60%)**: PLG 퍼널, 리텐션 코호트 기준선
- **Known Unknowns (~25%)**: 중견시장 요금제의 가격 탄력성
- **Unknown Knowns (~10%)**: 디자인 파트너 47건 인터뷰 스크립트 미활용
- **Unknown Unknowns (~5%)**: 버티컬별 규제 변화

## Stop Doing / 중단할 것
1. 전환율 3% 미만 웨비나 후원
2. 롱테일 산업 대상 일괄 아웃바운드
```

---

## Next Step / 다음 단계

Once the requirements file is written, hand off to `/plan` — it reads the YAML
frontmatter (`lens`, `decisions`, `stop_doing`, `open_questions`) to compute an
Ambiguity Score and decompose the work into tasks.
산출된 요구사항 파일은 `/plan`의 입력으로 사용되며, frontmatter를 읽어 작업
분해와 Ambiguity Score 게이트를 수행합니다.

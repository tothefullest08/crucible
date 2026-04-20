# `/brainstorm`

> 모호한 기능 요청을 3-lens 패스로 구체적 requirements 문서로 명확화하고, 거기서 **멈춥니다** — 계획은 세우지 않습니다.

[English](./brainstorm.md) · 한국어

## 패러다임 (Paradigm)

`/brainstorm`이 존재하는 이유: Claude Code 세션에서 가장 비싼 실수는 모호한 프롬프트 위에 지어진 계획에 커밋하는 것이기 때문입니다. 스킬 내 모든 lens는 프롬프트를 서로 다른 방향에서 심문하고, 세 가지가 전부 돌기 전에는 requirements 문서를 emit하지 않습니다. 출력은 의도적으로 계획이 아닙니다 — `/plan`이 소비할 수 있는 `*-requirements.md` 파일입니다. "무엇을 만들 것인가?"와 "어떻게 만들 것인가?"를 분리하는 것이 `/brainstorm`이 독립 스킬인 이유입니다.

## 판정 (Judgment)

입력은 자유 형식의 사용자 의도(영어 또는 한국어). 출력은 `.claude/plans/YYYY-MM-DD-{slug}-requirements.md`에 있는 단일 파일로, 고정된 frontmatter 스키마(`slug`, `type: requirements`, `date`, `source_skill: clarify:vague`, `audience`)와 본문 섹션(`Goal` · `Scope {Included / Excluded}` · `Constraints` · `Success Criteria` · `Non-goals` · `Artifacts` · `Open Questions`)을 가집니다.

스킬은 다음 세 게이트에서 블록합니다:

1. **각 lens는 최소 하나의 해결된 모호점을 산출.** lens가 명확화할 것을 찾지 못하면 "이 lens에서는 모호점 없음"을 명시 기록합니다 — 침묵은 허용되지 않습니다.
2. **Open Questions 리스트는 비어있지 않음.** 모든 requirements 문서는 plan 단계가 결정할 사항들을 명명한 채 `/plan`으로 핸드오프됩니다.
3. **Goal 라인은 ≤ 1문장.** 단일 검증 가능한 결과를 강제합니다 — `/plan`의 Ambiguity Score Gate가 읽는 값입니다.

## 설계 선택 (Design Choices)

- **3 lens, 1개가 아님.** 하나의 lens(순수 "vague → concrete")는 전략적 블라인드 스팟과 형식-수준 리프레이밍을 놓칩니다. 3개 lens는 저렴하게 돌면서 더 깊은 단일 패스보다 넓은 표면을 커버합니다.
  - `vague` — 부정확한 표현을 검증 가능한 주장으로 전환.
  - `unknown` — Known/Unknown 4-분면 프레임을 적용해 숨은 가정 드러내기.
  - `metamedium` — 내용(*what*)만 바꿀지, 형식(*how*)도 바꿔야 할지 질문.
- **Phase는 1 → 4 순차, 병렬 아님.** Phase 1 raw 요청 수집, Phase 2 lens 실행, Phase 3 문서 초안, Phase 4 Open Questions 게이트. lens 병렬화를 시도했으나 초안에서 머지 충돌이 발생 — 순차가 더 단순합니다.
- **plan emit 없음.** 스킬은 의도적으로 `*-requirements.md`에서 멈춥니다. `/brainstorm`에서 `plan.md`를 쓰려 하면 `/plan`의 Plan-axis 게이트가 붕괴됩니다.
- **한국어 + 영어 트리거 parity.** "브레인스토밍"과 "spec this out" 둘 다 같은 스킬을 같은 스키마로 fire합니다. 이중언어 정확도 상한은 [`../thresholds.ko.md` §4](../thresholds.ko.md#4-description-트리거-정확도--δko--en--5-) 참조.
- **Audience 명시.** frontmatter의 `audience` 필드(예: `plugin_users_developer_primary`)는 `/plan`이 Success Criteria를 scope할 때 사용됩니다.

## Thresholds

모든 이중언어·트리거 정확도 수치는 [`../thresholds.ko.md`](../thresholds.ko.md)에 거주:

- Description 트리거 Δ ≤ 5 %pp — [§4](../thresholds.ko.md#4-description-트리거-정확도--δko--en--5-).
- `validate_prompt` fire/response rate — [§3](../thresholds.ko.md#3-validate_prompt--fire_rate--099-response_rate--090) (`/brainstorm` 포함 모든 스킬에 적용).

## 참고

- 상류 `p4cn` (plugins-for-claude-natives) — clarify 3-lens 패턴과 `requirements.md` 스키마.
- 상류 `ouroboros` — `/plan`이 Open Questions에서 읽는 Ambiguity Gate 개념.
- [`../axes.ko.md`](../axes.ko.md) — `/brainstorm`의 축 매트릭스 행 (Context ON, Plan/Execute/Verify OFF, Improve log-only).
- [`../../skills/brainstorm/SKILL.md`](../../skills/brainstorm/SKILL.md) — SKILL 계약 (frontmatter + 훅).

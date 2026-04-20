# `/plan`

> requirements 문서를 사람과 `qa-judge`가 동시에 파싱할 수 있는 Markdown + YAML 하이브리드 플랜으로 전환합니다.

[English](./plan.md) · 한국어

## 패러다임 (Paradigm)

`/plan`은 단일 입력(`/brainstorm`이 낸 `*-requirements.md`)을 받아 두 명의 독자를 동시에 섬기는 단일 파일을 생성합니다: Markdown 본문을 읽는 사람 리뷰어, 그리고 YAML frontmatter를 읽는 `qa-judge` Evaluator. 이 **이중 독자 제약**이 핵심 — 사람만 파싱할 수 있는 플랜은 검증되지 않고, 기계만 파싱할 수 있는 플랜은 리뷰되지 않습니다. 하이브리드 포맷은 양쪽을 정직하게 유지하는 계약입니다.

## 판정 (Judgment)

입력은 requirements 문서 경로. 출력은 `.claude/plans/YYYY-MM-DD-{slug}-plan.md`로 다음을 포함:

- **YAML frontmatter** — `goal`, `slug`, `date`, `parent_seed_id`, `source_requirements`, `ambiguity_verdict`, `ambiguity_score`, `constraints`, `acceptance_criteria {hard, stretch}`, `evaluation_principles [{name, weight, description, metric}]`, `exit_conditions {success, failure, timeout}`.
- **Markdown 본문** — `Ambiguity Score Gate`, `Decisions`, `Tasks` (의존성 그래프 포함), `Gaps`, `Exit Conditions`, `Next Steps`.

스킬은 다음 지점에서 블록합니다:

1. **Ambiguity Score Gate.** `ambiguity_score > 0.20`이면 스킬은 거부하고 `/brainstorm`으로 리디렉트. 게이트는 해결되지 않은 Open Questions 수를 정규화 상수로 나눠 계산.
2. **Evaluation principles 합 = `1.00`.** 합이 깔끔하지 않은 가중치 세트는 emit 전에 거부.
3. **모든 Hard AC는 최소 1개 task에 매핑.** task 없는 AC는 통과할 수 없는 AC — 스킬은 emit을 거부.

## 설계 선택 (Design Choices)

- **Markdown + YAML 하이브리드, 두 파일 아님.** 두 파일(`plan.md` + `plan.yaml`)은 실무에서 갈라집니다 — 누군가 하나만 수정하고 다른 하나를 잊습니다. frontmatter가 붙은 단일 파일은 **생성 단계부터 자기 일관적**입니다.
- **Ambiguity Score Gate `0.20`.** `0.20` 아래면 open question이 충분히 작아 `/plan`이 inline으로 결정할 수 있음 (모든 플랜이 내는 `Decisions` 표 참조). `0.20` 위면 정직한 조치는 `/brainstorm`으로 돌아가는 것. 게이트는 휴리스틱이 아니라 경계선입니다.
- **가중치 기반 `evaluation_principles`, 합 = 1.00.** 가중치는 플랜 작성자가 트레이드오프를 **명시적으로** 선언하도록 강제합니다. `qa-judge`는 같은 가중치로 산출물을 채점 — 플랜과 검증이 같은 대상을 측정합니다.
- **`exit_conditions`는 1개 필드가 아닌 3개 필드.** `success`, `failure`, `timeout`은 구별됩니다 — success criteria는 우리가 달성하려는 것, failure criteria는 stop-and-rework를 강제하는 것, timeout은 예산. 합치면 "시간이 떨어졌으니 P0만 출고" 분기를 잃습니다.
- **Task 의존성 그래프는 명시.** 각 task는 `depends_on: [task_ids]`를 나열. 그래프는 파싱 가능하지만 산문은 아닙니다. 이것이 `/orchestrate`가 독립 브랜치를 병렬화할 수 있게 해줍니다.
- **플랜은 requirements 문서를 수정하지 않음.** `/plan`이 소비한 시점부터 requirements 문서는 불변; drift는 근거와 함께 `Decisions` 표로 들어갑니다.

## Thresholds

모든 정량 값은 [`../thresholds.ko.md`](../thresholds.ko.md)에 거주:

- Ambiguity Score Gate `0.20` — 설계-파생 경계선 (`1/√n` 가독성 bound 계열의 §2 파생 참조).
- `/plan` 출력이 채점되는 `qa-judge` 판정 밴드 `0.80 / 0.40` — [§1](../thresholds.ko.md#1-qa-judge-판정-밴드--promote--080-retry-040080-reject--040).
- `validate_prompt` fire/response rate — [§3](../thresholds.ko.md#3-validate_prompt--fire_rate--099-response_rate--090).

## 참고

- 상류 `ouroboros` — Seed YAML 스키마, Ambiguity Gate, `evaluation_principles` 가중치.
- 상류 `hoyeon` — `validate_prompt` 훅 패턴 (AC-to-task 매핑 강제에 사용).
- [`../axes.ko.md`](../axes.ko.md) — `/plan`의 축 매트릭스 행 (Improve 제외 모든 6축 ON).
- [`../../skills/plan/SKILL.md`](../../skills/plan/SKILL.md) — SKILL 계약.
- 내부: Markdown + YAML 선택 근거는 final-spec v3.1 §2.2 Decision #10.

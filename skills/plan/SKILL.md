---
name: plan
description: |
  구현 계획 수립 (한·영) / Implementation planning with hybrid Markdown + YAML frontmatter.
  Use when a requirements document is ready for task decomposition, evaluation principles, and exit conditions.
  트리거: "plan this", "계획 세워줘", "구현 계획", "implementation plan", "break this down", "태스크 분해"
when_to_use: "요구사항 문서에서 구현 태스크 · 평가 원칙 · exit 조건을 정리할 때"
input: "요구사항 문서 (.claude/plans/YYYY-MM-DD-{slug}-requirements.md 혹은 임의 경로)"
output: ".claude/plans/YYYY-MM-DD-{slug}-plan.md (Markdown 본문 + YAML frontmatter)"
validate_prompt: |
  /plan 산출물 자기검증 (계획 축):
  1. goal이 한 줄(≤ 120자)로 명확하게 기술되어 있는가?
  2. evaluation_principles weight 합이 1.0 ± 0.01 인가? (validate-weights.sh 통과)
  3. AC.hard 기준이 측정 가능한 형태로 기술되어 있는가?
  4. exit_conditions 의 success / failure / timeout 3개 필드가 모두 채워져 있는가?
  5. Phase 1~5 본문이 각각 "목표 / 입력 / 동작 / 출력 / 실패 시 fallback" 5개 섹션을 포함하는가?
  6. parent_seed_id 가 null 이 아니면 해당 상위 plan 파일이 실제 디스크에 존재하는가?
---

# Plan

> `/brainstorm` 산출물(requirements)을 받아 Markdown 본문 + YAML frontmatter 하이브리드 플랜으로 정제. v3 Dec 10 결정.

## When to Use

구체화된 요구사항이 있지만 구현 태스크로 분해되지 않았을 때. `/brainstorm`이 선행됐거나 수동으로 준비한 requirements.md 경로를 입력으로 받음.

## Protocol

### Phase 1: Intake
(T-W3-02에서 확장 예정 — 요구사항 문서 파싱 + Ambiguity Score Gate 호출)

### Phase 2: Decomposition
(T-W3-02에서 확장 예정 — CE ce-plan 5-Phase 패턴 차용)

### Phase 3: Evaluation Principles
(T-W3-02에서 확장 예정 — evaluation_principles weight 합 1.0 assertion)

### Phase 4: Gap Analysis
(T-W3-02·04에서 확장 예정 — hoyeon gap-analyzer 호출 레이어)

### Phase 5: Finalize + Save
(T-W3-02·06에서 확장 예정 — output slug 화이트리스트 + 템플릿 기반 저장)

## Integration Points

- **입력**: `/brainstorm`의 requirements.md (또는 수동 작성)
- **출력**: `.claude/plans/YYYY-MM-DD-{slug}-plan.md` — Markdown 본문 + YAML frontmatter 하이브리드
- **다음 단계**: `/verify` (plan 산출물 검증), `/compound` (학습 승격)
- **사전 게이트**: Ambiguity Score Gate (T-W3-05, 0.2 임계)

## Output Schema

output 파일의 frontmatter 구조는 `skills/plan/templates/plan-template.md` 참조 (T-W3-03 산출).
주요 필드: `goal`, `constraints`, `AC`, `evaluation_principles` (weight 합 1.0), `exit_conditions`, `parent_seed_id`.

## TODO (후속 주차 작업)

| 태스크 | 범위 | 주차 |
|-------|------|------|
| T-W3-02 | Phase 1~5 본문 완성 (CE 5-Phase) | W3 |
| T-W3-03 | `templates/plan-template.md` YAML 스키마 | W3 |
| T-W3-04 | gap-analyzer 호출 레이어 | W3 |
| T-W3-05 | Ambiguity Score Gate (0.2 임계) | W3 |
| T-W3-06 | output slug hook | W3 |
| T-W3-07 | `validate_prompt` frontmatter 필드 (계획 축 자기검증) | W3 |
| T-W3-08 | 3 샘플 unit test → AC-3 | W3 |
| T-W3-09 | 한·영 사용 예제 README | W3 |

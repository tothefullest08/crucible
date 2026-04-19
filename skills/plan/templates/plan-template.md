---
# plan.md frontmatter 스키마 (ouroboros Seed YAML 포팅, v3 Dec 10 하이브리드)
# 실제 /plan 산출 파일에서는 아래 필드를 모두 채워야 함. 빈 placeholder는 자리표시자.
goal: "{한 줄 목표, ≤ 120자}"
constraints:
  - "{제약 1}"
  - "{제약 2}"
AC:
  hard:
    - "{하드 게이트 기준 1 (측정 가능)}"
    - "{하드 게이트 기준 2}"
  stretch:
    - "{스트레치 기준 (미달 시 2차 연기)}"
evaluation_principles:
  - name: "correctness"
    weight: 0.4
    description: "{기능이 명세대로 동작하는가}"
    metric: "{측정 방법, 예: AC.hard 모두 통과}"
  - name: "clarity"
    weight: 0.3
    description: "{읽는 사람이 의도를 즉시 이해하는가}"
    metric: "{측정 방법, 예: 새 기여자 리뷰 1회 통과}"
  - name: "maintainability"
    weight: 0.3
    description: "{향후 수정 비용이 낮은가}"
    metric: "{측정 방법, 예: 파일 ≤ 400 라인 / 중복 제거}"
exit_conditions:
  success: "{성공 종료 조건 (측정 가능)}"
  failure: "{실패 종료 조건 (abort 기준)}"
  timeout: "{시간 한도, 예: 4h}"
parent_seed_id: null
slug: "{a-zA-Z0-9_- 만, 1~64자}"
date: "{YYYY-MM-DD}"
---

# {goal}

> `/plan` 산출물. Markdown 본문 + YAML frontmatter 하이브리드. frontmatter 스키마 검증은 `skills/plan/templates/validate-weights.sh` 등 보조 스크립트로 수행.

## Phase 1: Intake

- **목표**: 요구사항 문서에서 범위·제약·성공 기준 추출.
- **입력**: `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` 경로.
- **동작**: 파싱 → Ambiguity Score 계산 → 0.2 미만이면 Phase 2로 진행.
- **출력**: frontmatter `goal`, `constraints`, `AC` 초안.
- **실패 시 fallback**: Ambiguity Score ≥ 0.2 → `/brainstorm` 재호출 제안 후 중단.

## Phase 2: Decomposition

- **목표**: 목표를 구현 태스크로 분해.
- **입력**: Phase 1 산출.
- **동작**: CE `ce-plan` 5-Phase 패턴 차용 — 역의존 그래프로 태스크 순서화.
- **출력**: Markdown 본문의 "Tasks" 섹션 (T-XX 번호 + 범위 + 추정 시간).
- **실패 시 fallback**: 태스크가 1개뿐이면 분해 없이 단일 구현 플랜으로 축약.

## Phase 3: Evaluation Principles

- **목표**: 산출물 평가 축 정의 + 가중치 할당.
- **입력**: Phase 2 태스크 목록.
- **동작**: `correctness / clarity / maintainability` 기본 3축 + 도메인 추가. weight 합은 정확히 1.0 (±0.01).
- **출력**: frontmatter `evaluation_principles` 배열.
- **실패 시 fallback**: weight 합 ≠ 1.0 → `validate-weights.sh` assertion 실패로 중단.

## Phase 4: Gap Analysis

- **목표**: 현재 코드베이스와 목표 상태 간 격차 식별.
- **입력**: Phase 2 태스크 + 현재 repo 상태.
- **동작**: hoyeon gap-analyzer (T-W3-04) 호출 — missing files / outdated patterns / dependency gaps 리스팅.
- **출력**: Markdown 본문의 "Gaps" 섹션.
- **실패 시 fallback**: gap-analyzer 미가용 → 수동 checklist로 대체.

## Phase 5: Finalize + Save

- **목표**: 플랜 파일 저장 + slug 검증.
- **입력**: Phase 1~4 산출.
- **동작**: `output-slug-hook.sh`로 slug 생성 및 화이트리스트 검증 → `.claude/plans/YYYY-MM-DD-{slug}-plan.md`로 저장.
- **출력**: 디스크 상의 plan.md 파일.
- **실패 시 fallback**: slug 무효 → stderr로 사유 출력 후 사용자 입력 재요청.

## Evaluation Principles

> frontmatter `evaluation_principles` 자동 요약 렌더링 (예시):
>
> | Name | Weight | Metric |
> |------|--------|--------|
> | correctness | 0.4 | AC.hard 모두 통과 |
> | clarity | 0.3 | 신규 기여자 리뷰 1회 통과 |
> | maintainability | 0.3 | 파일 ≤ 400 라인 |
>
> **Assertion**: `sum(weight) == 1.0 ± 0.01` — `validate-weights.sh`로 강제.

## Exit Conditions

> frontmatter `exit_conditions` 기반:
>
> - **Success**: frontmatter `exit_conditions.success` 문자열
> - **Failure**: frontmatter `exit_conditions.failure` 문자열
> - **Timeout**: frontmatter `exit_conditions.timeout` 문자열

## Parent Seed

> `parent_seed_id` 가 null 이 아니면 상위 plan과 연결 — 상위 plan 파일의 존재를 `validate_prompt` 자기검증 #6에서 확인.

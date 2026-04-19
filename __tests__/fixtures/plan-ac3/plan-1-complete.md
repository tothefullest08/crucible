---
test_expected: PASS
goal: "하이브리드 plan.md 포맷 AC-3 Hard Gate 검증용 완전 픽스처"
constraints:
  - "bash + jq + yq 만 사용"
  - "shellcheck 통과"
  - "eval 금지, 모든 변수 쌍따옴표 보간"
AC:
  hard:
    - "7개 체크 모두 통과"
    - "evaluation_principles weight 합 = 1.0 ± 0.01"
    - "exit_conditions 3필드 모두 non-null"
  stretch:
    - "shellcheck -S style 경고 0개"
evaluation_principles:
  - name: "correctness"
    weight: 0.5
    description: "스펙대로 7개 체크가 정확히 동작하는가"
    metric: "AC.hard 3개 모두 통과"
  - name: "clarity"
    weight: 0.3
    description: "신규 기여자가 실패 원인을 즉시 파악할 수 있는가"
    metric: "실패 로그에 체크 번호 + 원인 노출"
  - name: "maintainability"
    weight: 0.2
    description: "향후 체크 추가 시 수정 범위가 국소적인가"
    metric: "check_plan 함수 ≤ 80라인"
exit_conditions:
  success: "3/3 fixture 기대 매칭 → AC-3 PASS 출력"
  failure: "1개 이상 기대 불일치 → AC-3 FAIL 출력"
  timeout: "4h"
parent_seed_id: null
slug: "plan-ac3-complete-fixture"
date: "2026-04-19"
---

# 하이브리드 plan.md 포맷 AC-3 Hard Gate 검증용 완전 픽스처

> `/plan` 산출물 스키마 검증용. 모든 필수 필드·weight 합·Phase 1~5 구조 완비.

## Phase 1: Intake

- **목표**: 요구사항 문서에서 범위·제약·성공 기준 추출.
- **입력**: `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` 경로.
- **동작**: 파싱 → Ambiguity Score 계산 → 0.2 미만이면 Phase 2로 진행.
- **출력**: frontmatter `goal`, `constraints`, `AC` 초안.
- **실패 시 fallback**: Ambiguity Score ≥ 0.2 → `/brainstorm` 재호출 제안 후 중단.
- **세부 1**: requirements.md 프론트매터 추출 → goal 단문 선별.
- **세부 2**: constraints 목록에서 bash/jq/yq 외 의존성 탐지 시 경고.
- **세부 3**: AC.hard 배열 길이 1 미만 → Ambiguity Score +0.1.
- **세부 4**: AC.stretch 누락은 경고만 (score 미가산).
- **세부 5**: `/brainstorm` 재호출 대신 수동 편집 선택지도 제공.
- **세부 6**: Phase 1 자체 로그는 stderr로 분리하여 stdout 파이프 보존.
- **세부 7**: Ambiguity Score 임계값 0.2는 final-spec.md §10에서 확정.
- **세부 8**: parent_seed_id 비어 있으면 최상위 plan으로 처리.
- **세부 9**: slug 후보는 goal 선두 5단어에서 생성 후 slug-validator 적용.
- **세부 10**: date 필드는 Phase 5 저장 직전 ISO 8601로 재계산.
- **세부 11**: 파싱 실패 시 원본 경로 + 라인 번호로 에러.
- **세부 12**: intake 결과는 in-memory로만 유지 (임시 파일 미생성).

## Phase 2: Decomposition

- **목표**: 목표를 구현 태스크로 분해.
- **입력**: Phase 1 산출.
- **동작**: CE `ce-plan` 5-Phase 패턴 차용 — 역의존 그래프로 태스크 순서화.
- **출력**: Markdown 본문의 "Tasks" 섹션 (T-XX 번호 + 범위 + 추정 시간).
- **실패 시 fallback**: 태스크가 1개뿐이면 분해 없이 단일 구현 플랜으로 축약.
- **세부 1**: 태스크 ID 체계는 T-W{주}-{번호} (두자리 제로 패딩).
- **세부 2**: 역의존 그래프는 최소 간선 수로 구성 (DAG).
- **세부 3**: 순환 검출 시 Phase 2 실패 + 원본 태스크 목록 stderr 출력.
- **세부 4**: 추정 시간은 30분 단위로 반올림.
- **세부 5**: 4h 초과 태스크는 경고 + 분해 제안.
- **세부 6**: 태스크별 산출물 경로를 명시 (상대 경로).
- **세부 7**: 병렬 가능 태스크는 같은 level로 묶어 표기.
- **세부 8**: Phase 2 결과는 Markdown 테이블로 직렬화.
- **세부 9**: 테이블 컬럼: ID · Scope · Est · Deps · Output.
- **세부 10**: 1개 태스크만 있을 때 단일 계획 모드로 축약 (Tasks 섹션 생략 허용).

## Phase 3: Evaluation Principles

- **목표**: 산출물 평가 축 정의 + 가중치 할당.
- **입력**: Phase 2 태스크 목록.
- **동작**: `correctness / clarity / maintainability` 기본 3축 + 도메인 추가.
- **출력**: frontmatter `evaluation_principles` 배열.
- **실패 시 fallback**: weight 합 ≠ 1.0 → `validate-weights.sh` assertion 실패로 중단.
- **세부 1**: weight 합은 정확히 1.0 (±0.01).
- **세부 2**: 기본 3축 weight 프리셋: (0.5 / 0.3 / 0.2).
- **세부 3**: 도메인 축 추가 시 기본 3축 weight를 비례 축소.
- **세부 4**: 각 principle은 `metric` 필드 필수.
- **세부 5**: metric은 측정 가능한 동사 + 수치.
- **세부 6**: 중복 name 금지.
- **세부 7**: name은 lowercase + '-' 만 허용.
- **세부 8**: weight 수치 포맷은 소수점 2자리 권장.
- **세부 9**: `validate-weights.sh` 호출은 Phase 3 말미에 1회.
- **세부 10**: assertion 실패 시 failing diff stderr 출력.
- **세부 11**: correctness weight 최소 0.3 권장 (하드 룰 아님).

## Phase 4: Gap Analysis

- **목표**: 현재 코드베이스와 목표 상태 간 격차 식별.
- **입력**: Phase 2 태스크 + 현재 repo 상태.
- **동작**: gap-analyzer 호출 — missing files / outdated patterns / dependency gaps.
- **출력**: Markdown 본문의 "Gaps" 섹션.
- **실패 시 fallback**: gap-analyzer 미가용 → 수동 checklist로 대체.
- **세부 1**: gap-analyzer.sh 경로는 repo root `scripts/gap-analyzer.sh` 고정.
- **세부 2**: 결과는 3 카테고리로 분류: missing_files · outdated_patterns · dependency_gaps.
- **세부 3**: 각 항목은 경로 + 현재 상태 + 기대 상태 triple로 기록.
- **세부 4**: 경로는 repo-relative.
- **세부 5**: 의존성 갭은 package-level까지만 기록.
- **세부 6**: gap이 0개면 Gaps 섹션에 "no gap detected" 고정 문자열.
- **세부 7**: gap-analyzer 종료 코드 비제로면 Phase 4 실패로 간주.
- **세부 8**: 수동 fallback 모드 플래그: `--manual-gap` (미구현 시 기본값).
- **세부 9**: 결과는 Phase 5 frontmatter에는 포함하지 않음 (본문 전용).

## Phase 5: Finalize + Save

- **목표**: 플랜 파일 저장 + slug 검증.
- **입력**: Phase 1~4 산출.
- **동작**: `output-slug-hook.sh`로 slug 생성·검증 후 `.claude/plans/YYYY-MM-DD-{slug}-plan.md`로 저장.
- **출력**: 디스크 상의 plan.md 파일.
- **실패 시 fallback**: slug 무효 → stderr로 사유 출력 후 사용자 입력 재요청.
- **세부 1**: slug 길이 1~64자.
- **세부 2**: 화이트리스트 `^[a-zA-Z0-9_-]+$`.
- **세부 3**: 파일명 충돌 시 `-v2`, `-v3` 접미사 추가.
- **세부 4**: date 필드 재계산은 저장 직전 1회.
- **세부 5**: 저장 후 stdout에 절대 경로 1줄 출력.
- **세부 6**: 저장 실패 시 부분 파일 미생성 보장 (tmp → rename).
- **세부 7**: 권한 0644 고정.
- **세부 8**: parent_seed_id 링크 검증은 `validate_prompt` 자기검증 #6에서 수행.
- **세부 9**: Phase 5 완료 후 종료 코드 0.
- **세부 10**: 예외 발생 시 stderr에 Phase 번호 + 원본 에러 출력 후 exit 1.

## Evaluation Principles

> frontmatter `evaluation_principles` 자동 요약 렌더링:
>
> | Name | Weight | Metric |
> |------|--------|--------|
> | correctness | 0.5 | AC.hard 3개 모두 통과 |
> | clarity | 0.3 | 실패 로그에 체크 번호 + 원인 노출 |
> | maintainability | 0.2 | check_plan 함수 ≤ 80라인 |
>
> **Assertion**: `sum(weight) == 1.0 ± 0.01` — `validate-weights.sh`로 강제.

## Exit Conditions

> frontmatter `exit_conditions` 기반:
>
> - **Success**: 3/3 fixture 기대 매칭 → AC-3 PASS 출력.
> - **Failure**: 1개 이상 기대 불일치 → AC-3 FAIL 출력.
> - **Timeout**: 4h (초과 시 부분 결과 + 진단 로그).

## Parent Seed

> `parent_seed_id: null` — 최상위 plan. 상위 연결 없음.

## Tasks

| ID | Scope | Est | Deps | Output |
|----|-------|-----|------|--------|
| T-W3-08a | fixture 3개 작성 | 1h | — | `__tests__/fixtures/plan-ac3/*.md` |
| T-W3-08b | 검증 스크립트 구현 | 2h | T-W3-08a | `__tests__/integration/test-ac3-plan-format.sh` |
| T-W3-08c | shellcheck + AC-3 PASS 확인 | 1h | T-W3-08b | 로그 `AC-3 PASS (3/3)` |

## Gaps

- **missing_files**: 해당 없음 (모두 신규 산출물).
- **outdated_patterns**: 해당 없음.
- **dependency_gaps**: 해당 없음 (bash + jq + yq 만 사용).

# 하네스 플러그인 개발 도구 추천

> `/guide` 스킬 실행 결과 — 브레인스토밍 & planning 하네스 Claude 플러그인 개발을 위한 도구/스킬/에이전트 추천

- **작성일**: 2026-04-19
- **기반 문서**: `/Users/ethan/Desktop/personal/harness/requirement.md`
- **필수 준수**: `/Users/ethan/Desktop/personal/harness/lecture/harness-day2-summary.md` (하네스 6가지 축)
- **레퍼런스 위치**: `/Users/ethan/Desktop/personal/harness/references`

---

## 1. 현재 상황 분석

- **태스크**: 브레인스토밍 & planning 하네스 Claude 플러그인 개발 (메타 플러그인)
- **규모**: 대규모 — 복수 스킬/에이전트/훅, 다수 레퍼런스 통합, 컴파운딩 루프 설계
- **방향**: 탐색적(초반 WHAT) → 확정적(후반 HOW/구현)
- **특이점**:
  - 하네스 6축 준수 필수
  - 레퍼런스 다수 (superpower / CE / hoyeon / ouroboros / team-attention / oh-my-claudecode)
  - 자체 결과 검증 루프 요구사항
  - 컴파운딩(학습 → 저장 → 재활용) 요구사항
- **결론**: 단계별 파이프라인 필요

---

## 2. 단계별 추천 파이프라인

### Phase 1 — 요구사항 명확화 (WHAT 고정)

**추천: `/clarify:vague`**

- requirement.md가 다수 모호점 내포
  - 하네스 6가지 축의 구체적 적용 방법
  - 결과 스코어링 기준 및 실패 판정 임계값
  - 암묵지 저장 포맷
  - 컴파운딩 트리거 조건
- 호출: `/clarify:vague`

**병렬로 함께**: `/clarify:unknown`

- "하네스 플러그인이 기존 플러그인과 왜 달라야 하는가" 식의 숨은 가정 발견
- 호출: `/clarify:unknown`

---

### Phase 2 — 레퍼런스 & 하네스 6축 리서치 (병렬 실행)

**추천: CE `repo-research-analyst` 에이전트 × 다중 병렬**

- `/Users/ethan/Desktop/personal/harness/references` 하위 각 레퍼런스 독립 분석
  - superpower (brainstorming)
  - compound-engineering-plugin (ce-ideate / ce-brainstorm / ce-plan / ce-review)
  - hoyeon
  - ouroboros
  - team-attention (agent-council / clarify)
  - oh-my-claudecode
- **단일 메시지 내 병렬 실행** — 각 레퍼런스마다 Agent 호출 1개씩 동시 발사
- 각 플러그인의 구조/패턴/훅 사용법 파악
- 호출: `Agent(subagent_type="compound-engineering:research:repo-research-analyst")` × N

**추가 리서치 에이전트**:

- `compound-engineering:research:best-practices-researcher` — Claude Code 플러그인/스킬/훅 베스트 프랙티스
- `compound-engineering:research:learnings-researcher` — `docs/solutions/` 사전 해결 사례 조회

---

### Phase 3 — 브레인스토밍 (WHAT → 범위 정의)

**추천: CE `/ce-brainstorm`**

- 6축 + 3대 요구사항(암묵지 해소 / 검증 루프 / 컴파운딩)을 어떻게 기능으로 풀어낼지 협업 대화로 결정
- 적정 크기 요구사항 문서 산출
- 호출: `/compound-engineering:ce-brainstorm`

**보완: `/ce-ideate`**

- 레퍼런스 조합 기반 개선 아이디어 도출
- 예: superpower brainstorming + ouroboros 루프 + agent-council 관점 통합
- 호출: `/compound-engineering:ce-ideate`

---

### Phase 4 — 설계 & 구현 계획 (HOW)

**추천: CE `/ce-plan`**

- 브레인스토밍 결과물을 구조화된 구현 단위로 분해
  - 스킬 단위
  - 에이전트 단위
  - 훅 단위
- 호출: `/compound-engineering:ce-plan`

**아키텍처 관점 보강**:

- CE `architecture-strategist` 에이전트 — 하네스 6축과 충돌하지 않는지 검증

**에이전트-네이티브 설계**:

- `/compound-engineering:agent-native-architecture`
- "유저가 할 수 있는 모든 동작을 에이전트도 할 수 있게" 원칙 반영
- 컴파운딩 루프 설계에 필수

---

### Phase 5 — 설계 문서 리뷰 (병렬 페르소나)

**추천: CE `/document-review`**

- 아래 페르소나가 병렬로 설계 결함 조기 발견
  - coherence (일관성)
  - feasibility (실현 가능성)
  - scope-guardian (범위)
  - adversarial (반대 관점)
  - design-lens (디자인 관점)
- 호출: `/compound-engineering:document-review`

**보완: `/agent-council`**

- "하네스 6축을 어떻게 해석해야 하는가" 같은 해석형 결정에 멀티 AI 관점 수집
- 호출: `/agent-council`

---

### Phase 6 — 구현

**추천: `skill-creator` + CE `/ce-work`**

- `skill-creator` — 각 스킬 파일 생성 (SKILL.md 프론트매터, description 최적화 포함)
  - 호출: `/skill-creator:skill-creator`
- `/ce-work` — 계획 기반 통합 실행 (내장 리뷰 + 커밋 포함)
  - 호출: `/compound-engineering:ce-work`

---

### Phase 7 — 검증 루프 설계 (요구사항 2번)

**추천: CE `/ce-optimize`**

- "결과 스코어링 → 실패 시 자체 루프" 요구사항은 본질적으로 metric-driven optimization loop
- `/ce-optimize` 패턴이 그대로 템플릿 역할
- 호출: `/compound-engineering:ce-optimize` (참고용 패턴 추출 또는 직접 실행)

---

### Phase 8 — 코드 리뷰 & 커밋

**추천: CE `/ce-review` → `/git-commit-push-pr`**

- 멀티 페르소나 리뷰 후 PR 생성
- 호출 순서:
  1. `/compound-engineering:ce-review`
  2. `/compound-engineering:git-commit-push-pr`

---

## 3. 핵심 추천 TL;DR

| 순서 | Phase | 도구 | 왜 |
|------|-------|------|---|
| 1 | 요구사항 명확화 | `/clarify:vague` + `/clarify:unknown` (병렬) | 요구사항의 모호점·숨은 가정 제거 |
| 2 | 리서치 | CE `repo-research-analyst` × N (병렬) | 레퍼런스 동시 분석 |
| 3 | 브레인스토밍 | `/ce-brainstorm` → `/ce-ideate` | WHAT 정의 + 조합 아이디어 |
| 4 | 설계 | `/ce-plan` + `agent-native-architecture` | 에이전트-네이티브 설계 |
| 5 | 리뷰 | `/document-review` + `/agent-council` (병렬) | 설계 검증 |
| 6 | 구현 | `skill-creator` + `/ce-work` | 스킬 생성 + 실행 |
| 7 | 검증 루프 | `/ce-optimize` | 스코어링 루프 패턴 참조 |
| 8 | PR | `/ce-review` → `/git-commit-push-pr` | 리뷰 + PR |

---

## 4. 대안 옵션

### 파일 기반 추적이 필요한 경우
- **`/planning-with-files`**
  - 장기 진행 상황을 `task_plan.md` / `findings.md` / `progress.md`로 관리
  - 컴파운딩 요구사항의 "저장" 부분 구현에 직접 참고 가능

### 암묵지 저장 포맷 설계 시
- **`auto memory` 시스템** 참조
  - `MEMORY.md` (인덱스) + 타입별(user/feedback/project/reference) 분리 구조
  - 이미 설계가 잘 되어 있어 포팅 용이

### 컴파운딩 구현 패턴
- **`/ce-compound` 스킬 내부 로직** 참조
  - "해결한 문제를 팀 지식으로 축적" 패턴을 그대로 포팅 가능

---

## 5. 주요 매핑: 요구사항 ↔ 도구

| 요구사항 | 직접 대응 도구 | 보조 도구 |
|----------|--------------|-----------|
| 브레인스토밍 | `/ce-brainstorm`, superpower | `/clarify:*`, `/ce-ideate` |
| Planning | `/ce-plan`, `/planning-with-files` | `agent-native-architecture` |
| 암묵지 해소 | (직접 개발 필요) | `auto memory` 시스템, `/clarify:unknown` |
| 틀린 부분 기록 | (직접 개발 필요) | `feedback` 타입 메모리 포맷 참고 |
| 결과 검증 루프 | `/ce-optimize` | ouroboros 레퍼런스 |
| Compounding | `/ce-compound`, `hoyeon` 레퍼런스 | `MEMORY.md` 인덱스 패턴 |

---

## 6. 다음 액션 선택지

1. **Phase 1부터 순차 시작** → `/clarify:vague` 실행
2. **레퍼런스 병렬 분석 먼저** → Phase 2 바로 진입
3. **순서 커스터마이즈** → 우선할 Phase 지정

---

*이 문서는 `/guide` 스킬의 추천 결과입니다. 실제 도구 실행은 각 Phase에서 해당 스킬/에이전트를 명시적으로 호출해야 진행됩니다.*

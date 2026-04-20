# Phase 2: 레퍼런스 병렬 리서치 지시서

## 📖 필수 컨텍스트 (먼저 모두 읽을 것)

1. `/Users/ethan/Desktop/personal/harness/requirement.md` — 원본 요구사항
2. `/Users/ethan/Desktop/personal/harness/lecture/harness-day2-summary.md` — 하네스 6축 정의
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/00-recommendations/tool-recommendations.md` — Phase 1에서 도출된 도구 추천
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/01-requirements/clarified-spec.md` — Phase 1에서 명확화된 스펙 (10개 결정 매트릭스 포함)

## 🎯 태스크

`/Users/ethan/Desktop/personal/harness/references/` 하위 6개 레퍼런스를 **병렬로 분석**하세요.

### 레퍼런스 목록 (병렬 실행 대상)
1. `references/superpowers` — brainstorming 워크플로우 참조
2. `references/compound-engineering-plugin` — 멀티 페르소나·오케스트레이션 참조
3. `references/hoyeon` — verify 에이전트 구조 참조
4. `references/ouroboros` — 검증 루프 패턴 참조
5. `references/agent-council` — 멀티 에이전트 합의 패턴 참조
6. `references/plugins-for-claude-natives` — clarify/session-wrap 등 포함

### 실행 방식 (필수)
- 각 레퍼런스마다 **`compound-engineering:research:repo-research-analyst` 에이전트 1개씩 병렬 spawn**
- 단일 메시지 내 **Agent 도구 호출 6번 동시** 배치
- 각 에이전트는 독립 컨텍스트 유지 (메인 컨텍스트 오염 방지 — 하네스 6축 중 "맥락" 원칙)

## 🔎 각 레퍼런스 분석 포인트 (공통 템플릿)

각 분석은 아래 5개 섹션을 반드시 포함:

### 1. 디렉토리 구조
- `.claude-plugin/plugin.json` 유무와 구성
- `skills/` 디렉토리 구조와 파일 수
- `agents/`, `hooks/`, `commands/` 디렉토리 구성
- 루트 레벨 주요 파일 (README, CLAUDE.md 등)

### 2. SKILL.md 프론트매터 패턴
- `name`, `description`, 기타 메타데이터 규칙
- description 최적화 (트리거 키워드 패턴)
- 다국어(한국어) 지원 여부

### 3. 핵심 워크플로우
- 브레인스토밍·planning·verify·compound 관련 기능이 어떻게 구현되어 있는지
- 사용된 디자인 패턴 (Generator/Evaluator 분리, Ralph Loop, Agent Council 등)

### 4. 재사용/포팅 가능한 자산 (UK 관점)
- 그대로 포팅 가능한 구조·템플릿·패턴 목록
- 우리 플러그인에서 어떻게 재사용할지

### 5. 6축 매핑
- 이 레퍼런스의 어떤 기능이 하네스 6축(구조/맥락/계획/실행/검증/개선) 중 어디에 해당하는지 매트릭스

## 📊 차별점 매핑 (모든 레퍼런스 공통 분석 질문)

우리 플러그인의 4가지 차별점 관점에서 각 레퍼런스를 평가:
1. **기존 도구 오케스트레이션** — 이 레퍼런스는 다른 도구를 조합하는가, 독립형인가?
2. **하네스 6축 강제** — 이 레퍼런스는 6축을 어떻게 다루는가?
3. **개인화 컴파운딩** — 이 레퍼런스의 학습·축적 메커니즘은?
4. **한국어 대화 최적화** — 한국어 지원 수준은?

## 📁 산출물

각 에이전트가 개별 파일 생성:
- `.claude/plans/2026-04-19/02-research/superpowers.md`
- `.claude/plans/2026-04-19/02-research/compound-engineering-plugin.md`
- `.claude/plans/2026-04-19/02-research/hoyeon.md`
- `.claude/plans/2026-04-19/02-research/ouroboros.md`
- `.claude/plans/2026-04-19/02-research/agent-council.md`
- `.claude/plans/2026-04-19/02-research/plugins-for-claude-natives.md`

6개 에이전트 완료 후 **종합 문서 생성** (메인 세션):
- `.claude/plans/2026-04-19/02-research/synthesis.md`
  - 6개 레퍼런스 매트릭스 (구조/SKILL 패턴/워크플로우/재사용성/6축 매핑)
  - 차별점별 레퍼런스 순위
  - **우리 플러그인에 포팅할 UK 자산 Top N 리스트** (우선순위 포함)
  - KU(실험 설계) 업데이트 — 레퍼런스 분석 결과로 채워지는 부분

## ⚙️ 실행 제약

- **병렬 실행 필수** — 6개 Agent 호출을 단일 메시지에 담아 동시 실행
- **한국어 문서** — 모든 산출물 한국어
- **읽기 전용** — references/ 하위 파일은 수정하지 말 것 (분석만)
- **`.claude/plans/`에만 쓰기** — 산출물은 반드시 이 경로에 저장
- **세션 독립성** — 각 에이전트는 자기 레퍼런스만 집중, 다른 레퍼런스 파일 읽지 말 것 (병렬 독립성 보장)

## ✅ 완료 기준

1. 6개 레퍼런스 분석 문서 모두 생성 완료
2. 각 문서가 위 5개 섹션 + 4개 차별점 평가 포함
3. 종합 문서(synthesis.md)에 포팅 우선순위 Top N 명시
4. 메인 세션에서 "Phase 2 완료" 알림 + 다음 단계 추천 (`/ce-brainstorm` or `/ce-plan`)

## 🛑 금지 사항

- 구현 코드 작성 금지 (이 Phase는 **리서치 전용**)
- 레퍼런스 파일 수정 금지
- 6개 Agent를 순차 실행 금지 (반드시 병렬)
- 산출물 외 파일 생성 금지

시작하세요.

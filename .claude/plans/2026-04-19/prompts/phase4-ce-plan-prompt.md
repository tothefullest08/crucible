# Phase 4: `/ce-plan` 실행 지시서

## 📖 필수 컨텍스트 (먼저 모두 읽을 것)

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — **v2 최종 스펙** (Phase 1+2+3 + review 반영, 단일 진실 소스)
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec-review.md` — 7-페르소나 review 결과 (P0 9건·P1 10건, 일부 v2에 반영, 잔여는 §11에 등재)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/02-research/synthesis.md` — 포팅 Top-32 자산 로드맵
4. `/Users/ethan/Desktop/personal/harness/requirement.md` — 원본 요구사항
5. `/Users/ethan/Desktop/personal/harness/lecture/harness-day2-summary.md` — 하네스 6축 정의

## 🎯 태스크

v2 최종 스펙을 입력으로 `/compound-engineering:ce-plan` 스킬을 실행해서 **구현 태스크 분해**를 수행하세요.

### 분해 대상 범위

- **W0** (프리미스 재검증, 1일): 각 조사 스텝을 구체 태스크로
- **W1~W8 + W7.5** (MVP 구현): 주차별 구현 태스크 (각 스킬 파일 작성, 훅 스크립트 구현, 테스트)
- **§11 설계 미결 승격 과제**: 각 §11 섹션을 "해당 주차 이전 승격" 태스크로 스케줄링
  - §11-1 (JSONL 안정성) → W1 이전
  - §11-2 (보안 완전 사양) → W4 이전
  - §11-3 (승격 게이트 UX) → W5 이전
  - §11-4 (KU 실행 상세) → W7.5 이전
  - §11-5 (6축 강제 범위), §11-6 (라이선스), §11-7 (기타) → W8 이전

### 태스크 분해 원칙

1. **주차별 그룹핑** — W0 / W1 / W2 / ... / W8 로 명확한 구분
2. **각 태스크에 다음 메타 포함**:
   - 의존성 (선행 태스크 ID)
   - 예상 공수 (시간 또는 pt)
   - 검증 방법 (어떻게 "완료" 판정?)
   - 관련 포팅 자산 (synthesis Top-N의 # 참조)
   - 관련 §11 승격 과제 여부
3. **위험 플래그** — P0-2(JSONL 스키마 리스크), P0-5(secrets), P0-8(훅 보안) 관련 태스크에는 🚨 표시
4. **Stretch 구분** — 10.2 Stretch AC (예: `/orchestrate`)에 해당하는 태스크는 `[Stretch]` 태그

## 📁 산출물

1. **메인 태스크 분해 문서**: `.claude/plans/2026-04-19/04-planning/implementation-plan.md`
   - 주차별 섹션
   - 각 주차 내부 태스크는 Markdown 체크리스트
   - 태스크 ID 체계: `T-W{주차}-{순번}` (예: `T-W4-03`)
   - 의존성 그래프 (Mermaid 또는 ASCII)

2. **포팅 매트릭스 문서**: `.claude/plans/2026-04-19/04-planning/porting-matrix.md`
   - synthesis Top-32 자산을 W0~W8 주차에 배정
   - 원본 경로 · 우리 위치 · 상류 커밋 해시(미상이면 "TBD") · 재작성 필요 여부(P0-1 bash+jq)
   - §11-6 라이선스 호환성 초안 (MIT/Apache-2.0/GPL 분류)

3. **§11 승격 체크리스트**: `.claude/plans/2026-04-19/04-planning/section11-promotion-tracker.md`
   - §11-1 ~ §11-7 각 항목에 대해
   - 승격 deadline (주차)
   - 책임자 (본인 / 유저 판단 필요)
   - 승격 게이트 기준 ("이것이 확정되면 스펙 문서 해당 섹션으로 승격")

## ⚙️ 실행 제약

- **구현 코드 작성 금지** — 이 Phase는 **태스크 분해 전용**. 실제 코드·파일 생성 금지
- **한국어** — 모든 산출물 한국어
- **주차별 공수 합계** — W0~W8 전체 공수 합계가 9주 이내인지 체크
- **단일 메시지 여러 `Write`** — 산출물 3개 생성은 병렬 가능하면 병렬
- **`/ce-plan` 스킬이 자체 대화를 요구하면** 내부적으로 결정 가능한 것은 기본값으로 채우고 진행 (유저 확인 최소화). 중요한 분기는 산출물 내 "결정 필요" 섹션으로 남길 것

## ✅ 완료 기준

1. 3개 산출물 파일 모두 생성
2. 각 주차 태스크가 `T-W{주차}-{순번}` 체계로 일관되게 ID 부여
3. Top-32 포팅 자산이 모두 어느 주차엔 배정되거나, 2차 릴리스로 명시 분류
4. §11 승격 과제 7개 모두 deadline 있음
5. Hard AC(§10.1) 8개가 어느 태스크로 충족되는지 추적 가능

## 🛑 금지

- 실제 `.claude-plugin/`·`skills/`·`hooks/` 파일 생성 금지 (태스크 분해만)
- v2 스펙 문서 수정 금지 (계획 변경은 별도 이터레이션)
- §11 항목을 "열린 주제"라는 이유로 생략 금지 (승격 deadline 추적이 핵심 산출물)

시작하세요.

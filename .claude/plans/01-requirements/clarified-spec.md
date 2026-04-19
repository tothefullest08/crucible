# 하네스 플러그인 — 요구사항 명확화 + 블라인드 스팟 분석

> `/clarify:vague` + `/clarify:unknown` 스킬 병렬 실행 결과
> 10개 질문(R1 4 · R2 3 · R3 3)을 통한 가설 중심 스펙 정제

- **작성일**: 2026-04-19
- **원본 요구사항**: `/Users/ethan/Desktop/personal/harness/requirement.md`
- **하네스 6축 참조**: `/Users/ethan/Desktop/personal/harness/lecture/harness-day2-summary.md`
- **레퍼런스 위치**: `/Users/ethan/Desktop/personal/harness/references`

---

## 🎯 Before / After

### Before (원본)
> 브레인스토밍 & planning 을 위한 하네스 클로드 플러그인 만들기
> 추가 기능: 암묵지 해소 / 결과 검증 루프 / compounding
> 필수: 하네스 6가지 축 준수
> 참조 레퍼런스: superpower, compound-engineering, hoyeon, ouroboros, team-attention 등

### After (정제 스펙)

**형태**: `.claude-plugin/` **공용 플러그인** (오픈소스 배포 목표)

**중심축(primary)**: **하네스 6축 강제** — 플러그인 구조 자체가 6축(구조·맥락·계획·실행·검증·개선)을 자연스레 따르도록 설계

**차별점 (복수, 모두 적용)**:
1. 기존 도구 오케스트레이션 (superpower/CE/hoyeon 조합 상위 레이어)
2. 하네스 6축 강제 ← **primary**
3. 개인화 컴파운딩 (유저별 암묵지 누적)
4. 한국어 대화 최적화

**진입점**:
- 단계별: `/brainstorm`, `/plan`, `/verify`, `/compound`
- 통합: `/orchestrate` — 전체 파이프라인 자동 실행

**결과 검증 루프**:
- **Evaluator**: 다른 관점 서브에이전트 (Generator vs Evaluator 분리, 회의적 튜닝)
- Anthropic 권장 패턴 준수

**암묵지 저장 포맷**:
```
.claude/memory/
├── MEMORY.md          # 1줄 포인터 인덱스
├── tacit/             # 일반 암묵지
├── corrections/       # 유저가 "틀렸다" 한 것
└── preferences/       # 작업 습관
```

**컴파운딩 트리거 (하이브리드)**:
1. 패턴 3회 반복 자동 감지 → "스킬/룰로 승격할까요?" 제안
2. 유저 "틀렸다" 발언 시 → `corrections/`에 저장 후보
3. 세션 종료 시 `/session-wrap` 호출

**오염 방지 메커니즘**:
- **승격 게이트**: 학습 후보 → 검증 → 저장 (즉시 저장 금지)
- **세션 격리**: 신규 세션은 독립 스크래치, `/session-wrap` 통과만 영구화
- (+유저 명시 승인은 게이트 일부로 포함)

**타겟**: 오픈소스 배포 — 오픈소스 배포 가능한 범용 형태 + 한국어 UX 공존 필요

---

## 📐 4분면 Playbook (Known/Unknown)

```
                 | KNOWN                          | UNKNOWN
─────────────────|────────────────────────────────|──────────────────────────────
KNOWN (의식)     | KK: 시스템화 (60%)             | KU: 실험 설계 (25%)
                 | - 공용 플러그인 형태           | - 한국어 ↔ 오픈소스 균형
                 | - 6축 강제 구조                | - 패턴 3회 감지 알고리즘
                 | - 단계별 + 오케스트레이터      | - 승격 게이트 임계값
                 | - Evaluator 서브에이전트       | - 6축 "형식 vs 실효" 판정
                 | - MEMORY.md 인덱스             |
─────────────────|────────────────────────────────|──────────────────────────────
UNKNOWN (무의식) | UK: 자산 활용 (10%)            | UU: 안테나 (5%)
                 | - CE 플러그인 구조 포팅        | - Evaluator 편향 (자가 평가 오류)
                 | - auto-memory 포맷 재사용      | - 모델 개선 시 6축 일부 불필요화
                 | - superpower brainstorm 흐름   | - 한국어 특화가 오픈소스 확산 방해
                 | - ouroboros 루프 패턴          | - 암묵지 누적 과적합 (퍼스널리티 편향)
                 | - hoyeon verify 구조           |
```

### KK — 시스템화 (60%)
이미 결정된 것. 바로 설계/구현 단계로.
- 공용 플러그인 (`.claude-plugin/`) 구조
- `skills/brainstorm.md`, `skills/plan.md`, `skills/verify.md`, `skills/compound.md`, `skills/orchestrate.md`
- 6축별 디렉토리 대응: `scaffold/` `context/` `planning/` `execution/` `verify/` `compound/`
- Evaluator 서브에이전트 (회의적 튜닝)
- 메모리 포맷: `MEMORY.md` + `tacit/` + `corrections/` + `preferences/`

### KU — 실험 설계 (25%)
**각 항목마다 진단 → 실험 → 성공 기준 → 승격/중단 조건 필요**

| KU | 실험 | 성공 기준 | 승격/중단 조건 |
|----|------|-----------|-----------|
| 한국어 vs 오픈소스 | 영어 기본 + 한국어 프리셋 | 영어 유저 3명·한국 유저 3명 테스트 시 둘 다 OK | 한쪽만 OK → 이중 모드 분리 |
| 패턴 3회 감지 | 단순 카운터 → 의미 유사도 | 오검지율 < 20% | 오검지율 ≥ 20% → 유저 확인 강제 |
| 승격 게이트 기준 | LLM-as-judge 점수 + 유저 확인 | 승격 후 철회율 < 10% | 철회율 ≥ 10% → 기준 강화 |
| 6축 실효성 판정 | 6축별 self-check 메타 스킬 | 체크리스트 만점 ≠ 실효, 디퍼런셜 평가 | 형식만 됨 → 6축별 effect metric 재설계 |

### UK — 자산 활용 (10%)
이미 가진 것 중 덜 쓰이는 것.
- **CE 플러그인** 구조 — `.claude-plugin/` 템플릿과 `SKILL.md` 프론트매터 패턴 그대로 포팅
- **auto-memory 시스템** — `MEMORY.md` 인덱스 + 타입별 분리가 이미 잘 설계되어 있음, 포맷 그대로 재사용
- **superpower** — brainstorming 대화 흐름 차용
- **ouroboros** — 검증 루프 패턴 차용
- **hoyeon** — verify 에이전트 구조 차용
- **team-attention clarify** — 방금 사용한 vague/unknown 스킬이 "암묵지 해소"의 직접적 레퍼런스

### UU — 안테나 (5%)
**모니터링만, 지금 해결하지 말 것.**
- ⚠️ **Evaluator 편향**: 같은 모델군이면 같은 맹점. Codex/Gemini 교차 검증 준비
- ⚠️ **모델 업데이트 리스크**: 6축 일부(특히 context 관리)가 모델 개선으로 자동화될 가능성
- ⚠️ **한국어 특화의 양날**: 오픈소스 글로벌 확산의 장벽이 될 리스크
- ⚠️ **개인화 컴파운딩 과적합**: 유저 취향이 반영되면서 다양성 감소

---

## 🛑 Stop Doing (명시적 제외)

1. **처음부터 모든 6축 완벽 구현** — KU 영역(실효성 판정)이 먼저 검증되어야
2. **새로 작성 중심** — UK 자산(CE/auto-memory)을 최대한 포팅/재사용
3. **즉시 학습 저장** — 승격 게이트 없이 저장 금지
4. **단일 Evaluator 모델** — 자가 평가 금지 원칙 준수
5. **체크리스트식 6축 준수** — 실효성 평가 지표 없는 형식적 포함 금지

---

## 🗓️ 실행 로드맵 (제안)

| 주차 | 단계 | 산출물 |
|------|------|--------|
| W1 | 레퍼런스 리서치 병렬 | 각 레퍼런스 분석 문서 (repo-research-analyst × N) |
| W2 | 플러그인 스캐폴드 + 6축 구조 | `.claude-plugin/plugin.json`, `skills/` 기본 뼈대 |
| W3 | 단계별 스킬 구현 (brainstorm/plan) | 2개 스킬 작동 |
| W4 | 검증 루프 + Evaluator 서브에이전트 | verify + 서브에이전트 통합 |
| W5 | 메모리 시스템 + 승격 게이트 | `MEMORY.md` + `tacit/` 작동 + 게이트 검증 |
| W6 | 컴파운딩 트리거 3종 | 패턴 감지 + "틀렸다" 훅 + `/session-wrap` |
| W7 | 오케스트레이터 + E2E 통합 | `/orchestrate` 파이프라인 검증 |
| W8 | 문서화 + 오픈소스 배포 | README, 한국어/영어 예시 |

---

## 🧭 핵심 결정 원칙 (3줄)

1. **6축 강제가 primary** — 다른 차별점은 이것을 뒷받침
2. **Evaluator 분리 + 승격 게이트** — 자동 저장 없음, 검증 통과만 영구화
3. **UK 자산 최대 활용** — 새로 만들기 전 CE/auto-memory/superpower 먼저 포팅

---

## 📋 결정 매트릭스 (10개 질문 요약)

| # | 질문 | 결정 |
|---|------|------|
| 1 | 결과물 형태 | 공용 플러그인 |
| 2 | 차별점 (복수) | 오케스트레이션 + 6축 강제 + 개인화 컴파운딩 + 한국어 최적화 |
| 3 | 타겟 사용자 | 오픈소스 배포 |
| 4 | 주요 리스크 (복수) | 암묵지 오염 + 체크리스트化 + 기존 도구 중복 |
| 5 | 중심축(primary) | 하네스 6축 강제 |
| 6 | Evaluator | 다른 관점 서브에이전트 |
| 7 | 오염 방지 (복수) | 승격 게이트 + 세션 격리 |
| 8 | 메모리 포맷 | `MEMORY.md` 인덱스 + 타입별 분리 |
| 9 | 컴파운딩 트리거 (복수) | 3회 반복 감지 + "틀렸다" 발언 + `/session-wrap` |
| 10 | 진입점 | 단계별 명령 + 오케스트레이터 |

---

## ➡️ 다음 Phase

이 명확화된 스펙을 기반으로 다음 단계 진행:

- **Phase 2 (레퍼런스 리서치)**: `compound-engineering:research:repo-research-analyst` × N 병렬
  - `references/` 하위 각 레퍼런스(superpower / CE / hoyeon / ouroboros / team-attention / oh-my-claudecode) 동시 분석
- **Phase 3 (브레인스토밍)**: `/ce-brainstorm` 또는 `/ce-ideate`로 6축 강제 방식 구체화
- **Phase 4 (설계)**: `/ce-plan`으로 KU 실험 설계를 구현 계획으로 전환

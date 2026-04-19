# W0 프리미스 재검증 — T-W0-01 + T-W0-02 실행 지시서

## 📖 필수 컨텍스트 (먼저 모두 읽을 것)

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v2 스펙 §1 TL;DR + §7.1 W0 정의
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W0 — T-W0-01·02 구체 검증 기준
4. `/Users/ethan/Desktop/personal/harness/lecture/harness-day2-summary.md` — 6축 정의 (비교 기준)

## 🎯 태스크

final-spec v2 §1 TL;DR의 핵심 프리미스 — **"기존 플러그인이 6축 메타-프레임워크를 표면화한 레퍼런스가 없다"** — 를 W0의 T-W0-01·T-W0-02 두 태스크로 **재검증**합니다.

(T-W0-03 강의 원저자 검색 / T-W0-04 유저 인터뷰 / T-W0-05 게이트 판정은 이 세션에서 수행하지 않음. 별도 이터레이션.)

### T-W0-01 — Anthropic Cookbook `harness` 패턴 검색 (2h)

**목표**: Anthropic 공식 Cookbook에 "harness" 개념이 얼마나 표면화되어 있는지, 우리 6축과 얼마나 중첩되는지 확인.

**실행 단계**:
1. WebSearch로 `site:github.com/anthropics/anthropic-cookbook harness` 검색
2. WebFetch로 cookbook repo의 README + 디렉토리 구조 조회
3. 관련 notebook(예: `multimodal/`, `skills/`, `tool_use/`) 5개 정도 샘플링
4. "harness"·"scaffold"·"agent framework"·"meta-framework" 키워드 grep
5. 각 notebook에서 우리 6축(구조·맥락·계획·실행·검증·개선)과 유사한 구조화 시도 여부 평가

**산출물**: `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/w0-results/t-w0-01-anthropic-cookbook.md`
- 발견된 harness 관련 문서 개수 · 제목 · URL
- 각 문서의 "6축 유사 레이어" 매핑 표 (축 × 문서 매트릭스)
- 유사도 점수: **High(명시적 6축 유사)** / Moderate(부분 중첩) / Low(관련성 낮음) / None
- 최종 판정: 프리미스 **훼손 / 강화 / 중립**

### T-W0-02 — DSPy / Inspect-AI / LangGraph / AutoGen "meta-framework" 섹션 탐색 (2h)

**목표**: 4개 대표 AI agent framework가 "6축 유사 메타 레이어"를 표면화하는지 조사.

**실행 단계 (4개 프레임워크 각각)**:
1. WebFetch로 공식문서 홈(혹은 GitHub README) 조회:
   - DSPy: https://dspy.ai 또는 https://github.com/stanfordnlp/dspy
   - Inspect-AI: https://inspect.ai-safety-institute.org.uk/ 또는 https://github.com/UKGovernmentBEIS/inspect_ai
   - LangGraph: https://langchain-ai.github.io/langgraph/
   - AutoGen: https://microsoft.github.io/autogen/
2. 목차·README에서 다음 키워드 탐색:
   - "harness" / "framework" / "meta" / "scaffold"
   - "evaluate" / "verify" (검증축)
   - "memory" / "compound" / "learn" (개선축)
   - "planning" / "orchestrate" (계획·실행축)
3. 각 프레임워크가 명시적으로 "6축 유사 레이어"를 제공하는지 평가
4. **2026-04 스냅샷** — 최신 버전 기준 기록 (버전 번호 명시)

**산출물**: `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/w0-results/t-w0-02-framework-comparison.md`

```markdown
# 4개 AI Agent Framework "6축 유사 레이어" 존재/부재 매트릭스

## 조사 일시: 2026-04-19
## 버전 스냅샷
- DSPy: v{X}
- Inspect-AI: v{X}
- LangGraph: v{X}
- AutoGen: v{X}

## 매트릭스

| 프레임워크 | 구조 | 맥락 | 계획 | 실행 | 검증 | 개선 | 메타 레이어 명시? |
|-----------|:----:|:----:|:----:|:----:|:----:|:----:|:---------------:|
| DSPy      |  ●   |      |      |  ●   |  ●   |      | No (optimize 중심)|
| ... (각 축별 ● = 명시 제공, △ = 부분, 빈칸 = 미제공) |

## 각 프레임워크별 상세 1쪽

### DSPy
- 공식 위치: URL
- 6축 커버: ...
- 메타 레이어 표면화: Yes/No. 근거: 문서 URL 인용
- 우리 프리미스와의 관계: 훼손 / 무관 / 강화

(나머지 3개 동일 구조)

## 최종 판정
- 프리미스 훼손 프레임워크 수: N/4
- 판정: 훼손 / 강화 / 중립
```

## ⚙️ 실행 제약

- **한국어 산출물**
- **웹 검색 적극 활용** — WebSearch + WebFetch 도구 사용
- **병렬 실행** — 단일 메시지 내 여러 WebFetch 병렬 가능
- **구현 코드 작성 금지** — 조사 전용
- **T-W0-03·04·05 건드리지 말 것** — 이 세션 범위 밖
- **유저에게 확인 질문 최소화** — 조사·판단 자동 진행, 최종 결과만 보고

## ✅ 완료 기준

1. `w0-results/` 디렉토리 생성 (없으면 mkdir)
2. `t-w0-01-anthropic-cookbook.md` 생성 — 발견 개수·매핑표·유사도·판정
3. `t-w0-02-framework-comparison.md` 생성 — 4개 프레임워크 매트릭스·스냅샷·판정
4. 두 산출물 말미에 **"통합 판정 제안"** 1단락 — T-W0-03·04 수행 여부에 대한 권고

## 🛑 금지

- final-spec.md 수정 (수정은 별도 패널에서 v3 이터레이션이 진행 중)
- implementation-plan.md 수정
- T-W0-05 게이트 판정 독자 수행 (유저 최종 판단 필요)

시작하세요.

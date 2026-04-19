# T-W0-01 — Anthropic Cookbook `harness` 패턴 검색 결과

> **작성일**: 2026-04-19
> **담당**: Claude Opus 4.7 (1M context)
> **입력**: final-spec v2 §7.1 W0 게이트
> **목적**: "Anthropic 공식 Cookbook에 6축 메타 프레임워크가 표면화되어 있는가" 를 재검증하여 프리미스 훼손/강화/중립 판정

---

## 1. 조사 스코프

- **대상**: `github.com/anthropics/anthropic-cookbook` → **현재는 `github.com/anthropics/claude-cookbooks`로 리네이밍**
- **검색 키워드**: `harness`, `scaffold`, `agent framework`, `meta-framework`, `orchestrate`, `verify`, `compound`, `memory`
- **샘플링 디렉토리**: `patterns/agents/`, `skills/`, `claude_agent_sdk/`, `managed_agents/`, `tool_evaluation/`, `observability/`
- **주변 맥락**: Anthropic 자체 엔지니어링 블로그 + InfoQ 2026-04 기사 + 커뮤니티 선별 목록(`ai-boost/awesome-harness-engineering`)

---

## 2. 검색 결과 요약

### 2.1 Cookbook repo 본문 자체 (README + 디렉토리)

| 키워드 | README 명시? | 디렉토리 구조 명시? | 비고 |
|--------|:-----------:|:-----------------:|------|
| `harness` | ❌ 없음 | ❌ 없음 | Cookbook 본문에 직접 등장하지 않음 |
| `scaffold` | ❌ 없음 | ❌ 없음 | skills는 "Progressive Disclosure Architecture" 용어 사용 |
| `agent framework` | △ 간접 | `claude_agent_sdk/`, `managed_agents/` 존재 | 프레임워크 **구현**은 있지만 "프레임워크로서" 강조하지 않음 |
| `meta-framework` | ❌ 없음 | ❌ 없음 | — |
| `orchestrate` | ✔ 본문 | `patterns/agents/orchestrator_workers.ipynb` | "orchestrator-workers" 패턴명 |
| `evaluator / verify` | ✔ 본문 | `patterns/agents/evaluator_optimizer.ipynb` + `tool_evaluation/` | Evaluator 루프 명시 |
| `memory / compound` | △ 부분 | `tool_use/memory_cookbook.ipynb` | tool memory만. 학습 compounding 레이어 없음 |

### 2.2 Cookbook 디렉토리 전수 관찰

```
claude-cookbooks/
├── capabilities/          (Classification · RAG · Summarization)
├── claude_agent_sdk/      ← SDK 사용 예시
├── coding/
├── extended_thinking/
├── finetuning/
├── images/
├── managed_agents/        ← Managed Agent 구현 예시
├── misc/                  (prompt caching 등)
├── multimodal/
├── observability/
├── patterns/agents/       ← ★ 가장 근접 — 4개 노트북
├── scripts/
├── skills/                ← Progressive Disclosure 스킬 (xlsx/pptx/pdf/docx)
├── tests/
├── third_party/
├── tool_evaluation/
└── tool_use/              (memory_cookbook 포함)
```

### 2.3 `patterns/agents/` 핵심 노트북 4개

| 파일 | 커버 축 (우리 6축 기준) | 메타 레이어? |
|------|------------------------|:-----------:|
| `README.md` | (Building Effective Agents 링크) | No |
| `basic_workflows.ipynb` | 실행(prompt chaining / routing / parallelization) | No — 개별 패턴 |
| `orchestrator_workers.ipynb` | 계획 + 실행 (orchestrator → subagent) | No — 단일 패턴 |
| `evaluator_optimizer.ipynb` | **계획 + 실행 + 검증 + 개선** 루프 | △ — 4축 묶음, 하지만 "6축" 라벨 없음 |

### 2.4 `skills/` 디렉토리

- "Progressive Disclosure Architecture" 용어 사용 (컨텍스트 축 일부)
- 내장 스킬: `xlsx`, `pptx`, `pdf`, `docx` (문서 생성 4종) — 도메인 스킬, 메타 프레임워크 아님
- 6축 라벨 전혀 없음

---

## 3. 6축 × Cookbook 문서 매핑 매트릭스

| 축 | 명시 여부 | 해당 Cookbook 문서/디렉토리 | 비고 |
|----|:--------:|----------------------------|------|
| **구조 (Scaffolding)** | △ | `skills/` (Progressive Disclosure), `.claude-plugin/` 예시 없음 | 스킬 레이어로 간접 등장 |
| **맥락 (Context)** | △ | `tool_use/memory_cookbook.ipynb` (tool memory), `extended_thinking/` | 대화 맥락 관리 레이어 없음 |
| **계획 (Planning)** | △ | `patterns/agents/orchestrator_workers.ipynb` | "planning" 어휘로 노출 안 됨, 오케스트레이션 패턴으로만 |
| **실행 (Execution)** | ● | `patterns/agents/basic_workflows.ipynb`, `tool_use/`, `claude_agent_sdk/` | 가장 풍부한 축 |
| **검증 (Verification)** | ● | `patterns/agents/evaluator_optimizer.ipynb`, `tool_evaluation/`, `observability/` | Evaluator 패턴 명시 |
| **개선 (Compounding)** | ❌ | 없음 (evaluator_optimizer는 "루프"지만 "학습/메모리 축적" 아님) | 본 Cookbook의 최대 공백 |

**유사도 점수**: **Moderate (부분 중첩)**
- 실행·검증 축은 명시적 패턴으로 표면화.
- 계획 축은 "오케스트레이션"으로 우회 표현.
- 구조·맥락은 Progressive Disclosure + tool memory로 얕게 다룸.
- **개선 축은 부재** — 세션 간 학습·3회 반복→스킬화·"틀렸다"→Rule 같은 컴파운딩 메카닉 없음.
- **6축을 하나의 체계로 표면화한 문서는 0건**.

---

## 4. Cookbook 주변의 Anthropic 공식 입장 (중요 — 프리미스 재해석 필요)

Cookbook 본문은 "harness"를 쓰지 않지만, **Anthropic 자체는 2025-2026년에 공식적으로 "harness"를 핵심 용어로 사용**한다. 이는 우리 프리미스 논증에 영향을 준다.

### 4.1 Anthropic 엔지니어링 블로그
- `anthropic.com/engineering/demystifying-evals-for-ai-agents` 에서 **두 종류의 harness 정의**:
  1. **Evaluation Harness**: "인프라가 evals를 end-to-end로 실행한다. 명령·도구를 공급하고, 태스크를 병렬 실행하고, 단계를 기록하고, 출력을 채점하고, 결과를 집계한다."
  2. **Agent Harness (= Scaffold)**: "모델이 에이전트로 동작하게 하는 시스템. 입력을 처리하고, 도구 호출을 오케스트레이션하고, 결과를 반환한다."
- `anthropic.com/research/building-effective-agents` → 우리 Cookbook `patterns/agents/`의 원출처
- 추가 공식 에세이: **"Harness Design for Long-Running Application Development"**, **"Writing Effective Tools for Agents"**, **"Beyond Permission Prompts"** (커뮤니티 선별 목록에서 확인)

### 4.2 Anthropic "Three-Agent Harness" (InfoQ, 2026-04-04)
- **Planning Agent / Generation Agent / Evaluation Agent** 3축 분리
- "Separating planning, generation, and evaluation" = 우리 6축의 **계획·실행·검증** 3축을 선명화
- **구조적 handoff artifacts** + **context reset mechanism** (맥락 축 부분 커버)
- 5~15 iteration 루프, 4+시간 장기 실행
- 발표자 Prithvi Rajasekaran (Anthropic Labs): *"Separating the agent doing the work from the agent judging it proves to be a strong lever"* — 우리 "Evaluator 분리"(결정 #5)와 정확히 일치

### 4.3 커뮤니티 선별 목록 `ai-boost/awesome-harness-engineering`
- "Harness engineering"을 **12개 design primitive categories**로 분류:
  1. Agent Loop
  2. Planning & Task Decomposition
  3. Context Delivery & Compaction
  4. Tool Design
  5. Skills & MCP
  6. Permissions & Authorization
  7. Memory & State
  8. Task Runners & Orchestration
  9. Verification & CI Integration
  10. Observability & Tracing
  11. Debugging & Developer Experience
  12. Human-in-the-Loop
- 6축과의 대응: 구조↔(5), 맥락↔(3,7), 계획↔(2), 실행↔(1,4,8), 검증↔(9,10), 개선↔(없음)
- **12축 분류의 "개선/컴파운딩" 축 자체가 부재** — 우리의 차별화 여지

---

## 5. 판정

### 5.1 축별 중첩 요약
| 우리 6축 | Cookbook 직접 | Anthropic 공식 주변 | 커뮤니티 awesome-harness (12축) |
|---------|:-----------:|:------------------:|:-----------------------------:|
| 구조 | △ (skills PDA) | △ (scaffold 언급) | ● (Skills & MCP) |
| 맥락 | △ (tool memory) | △ (context reset) | ● (Context Delivery, Memory) |
| 계획 | △ (orchestrator) | ● (Planning Agent) | ● (Planning & Task Decomp) |
| 실행 | ● (basic_workflows) | ● (Generation Agent) | ● (Agent Loop, Tool, Runners) |
| 검증 | ● (evaluator_optimizer) | ● (Evaluation Agent) | ● (Verification, Observability) |
| **개선** | ❌ | △ (evals "compound") | ❌ |

### 5.2 유사도 점수
- **Cookbook 본문**: Moderate — 5/6 축에 부분 흔적, 하지만 6축을 **하나의 체계**로 표면화한 문서는 0건.
- **Anthropic 공식 주변**: High for 3-agent (계획/실행/검증) — "Three-Agent Harness"가 우리 primary differentiator 중 **오케스트레이션 + 검증** 축을 차감.
- **커뮤니티**: High for 5/6축 — 12축 분류가 이미 존재, 단 **개선(컴파운딩)** 축은 빠져 있음.

### 5.3 프리미스 판정
> final-spec v2 §1: "기존 플러그인이 6축 메타-프레임워크를 표면화한 레퍼런스가 없다"

**판정**: **🟡 부분 훼손 + 부분 유지 (중립-훼손 쪽)**

**근거**:
1. **Cookbook 본문 자체**는 6축 메타 레이어를 명시적으로 표면화하지 않음 → 프리미스 유지
2. **Anthropic 공식 엔지니어링 블로그 + Three-Agent Harness**는 "harness" 용어를 대중화하고 **계획/실행/검증 3축**을 이미 레이어로 분리 → 프리미스의 "6축 × 메타 프레임워크 레퍼런스 없음" 부분이 **축소**됨 (3축은 이미 공식 레퍼런스 존재)
3. **커뮤니티 선별 목록**(awesome-harness-engineering)은 **12 primitive 분류**로 이미 체계화 — 6축 → 12축으로 **세분화된 분류가 선행 공개**되어 있음. 우리 6축이 "새로운 분류"라는 주장은 무리
4. **유일하게 여전히 공백인 축**: **개선(Compounding)** — 12축에도 없고, 3-agent harness에도 없음. 3회 반복→Skill, "틀렸다"→Rule 자동 승격 메카닉은 우리 고유 영역

**리스코프 권고**:
- Primary differentiator를 **"6축 메타 프레임워크"** → **"개선 축(컴파운딩) 중심 + 6축 통합 UX"** 로 좁힐 것.
- final-spec §1 TL;DR 문구: "6축 메타-프레임워크를 표면화한 레퍼런스가 없다" → **"6축 중 `개선(Compounding)` 축을 구조적으로 강제하는 플러그인이 없다. 나머지 5축을 `개선`과 연결된 단일 UX로 통합한 레퍼런스도 없다"** 로 수정 검토.
- Hard AC에 **"6축 자체의 신규성 주장 금지 + 개선 축 + 통합 UX 증거 필수"** 추가.

---

## 6. 발견 문서 총괄 URL 리스트

### Cookbook 본문
- [anthropics/claude-cookbooks](https://github.com/anthropics/claude-cookbooks) — repo root
- [patterns/agents/](https://github.com/anthropics/anthropic-cookbook/tree/main/patterns/agents) — 4 notebooks
- [patterns/agents/evaluator_optimizer.ipynb](https://github.com/anthropics/anthropic-cookbook/blob/main/patterns/agents/evaluator_optimizer.ipynb) — 검증·개선 루프 (가장 근접)
- [tool_use/memory_cookbook.ipynb](https://github.com/anthropics/anthropic-cookbook/blob/main/tool_use/memory_cookbook.ipynb) — tool memory (맥락 축 부분)
- [tool_evaluation/tool_evaluation.ipynb](https://github.com/anthropics/anthropic-cookbook/blob/main/tool_evaluation/tool_evaluation.ipynb) — 도구 평가 (검증 축)

### Anthropic 공식 블로그 / 리서치
- [anthropic.com/research/building-effective-agents](https://www.anthropic.com/research/building-effective-agents)
- [anthropic.com/engineering/demystifying-evals-for-ai-agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- [InfoQ 2026-04-04: Three-Agent Harness](https://www.infoq.com/news/2026/04/anthropic-three-agent-harness-ai/)

### 커뮤니티
- [ai-boost/awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering) — 12 primitive 카테고리

---

## 7. 통합 판정 제안 (T-W0-01 단일 뷰)

**본 태스크 단독 결론**:
- Cookbook 본문만 보면 프리미스 유지 가능 (Moderate 유사도, 6축 통합 문서 0건)
- 하지만 Anthropic 공식·커뮤니티 주변까지 보면 "6축 × 메타 프레임워크" 주장은 **신규성이 약함** (3축은 Anthropic 공식, 12축은 커뮤니티 공개)
- **개선(Compounding) 축**은 명백한 공백으로 남아 있음 → 차별화 가능 지점

**T-W0-03·04 수행 여부 권고**:
- **T-W0-03 (강의 원저자 공개 구현체 검색)**: **수행 권장**. 이호연/AI Native Camp 자체 구현체가 이미 존재할 경우 프리미스 훼손 가능성 크며, 본 세션에서는 그 공개 여부를 직접 확인하지 못함.
- **T-W0-04 (dogfooding + 유저 인터뷰)**: **수행 권장 + 조사 질문 보정 필요**. "6축이 유용한가"보다 "개선(컴파운딩) 축을 자동화하는 플러그인이 실제 통증을 해결하는가"로 질문 축을 좁혀서 실행할 것.
- **T-W0-05 게이트 판정**: 본 T-W0-01 + T-W0-02 결과만으로는 **전면 통과도 전면 재스코프도 아님**. §7.1 게이트 옵션 중 **"유사 frameworks 발견 → primary differentiator를 개인화 컴파운딩으로 좁혀 재스코프 후 W1"** 경로가 가장 적합. T-W0-03·04 완료 후 v3 final-spec TL;DR 문구 재작성 권장.

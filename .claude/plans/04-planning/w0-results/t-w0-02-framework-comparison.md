# T-W0-02 — 4개 AI Agent Framework "6축 유사 레이어" 존재/부재 매트릭스

> **조사 일시**: 2026-04-19
> **담당**: Claude Opus 4.7 (1M context)
> **입력**: final-spec v2 §7.1 W0 게이트
> **목적**: DSPy / Inspect-AI / LangGraph / AutoGen 4개 대표 프레임워크가 "6축 유사 메타 레이어"를 표면화하는지 조사하여 프리미스 재검증

---

## 1. 버전 스냅샷 (2026-04-19 기준)

| 프레임워크 | 버전 | 릴리스일 | 상태 |
|-----------|------|---------|------|
| **DSPy** | v3.1.3 | 2026-02-05 | Active (Stanford NLP) |
| **Inspect-AI** | v0.3.199 | 2026-03-17 | Active (UK AISI) |
| **LangGraph** | v1.1.6 | 2026-04-10 | Active (LangChain, 1.0 GA 이후 1.1.x) |
| **AutoGen** | v0.4 (Jan 2025) | 2025-01 | **Maintenance mode** — 후속은 Microsoft Agent Framework 1.0 (2026-04-03 GA) |

**비고**: AutoGen은 2026-04 현재 유지보수 모드. Microsoft는 새 프로젝트에 **Microsoft Agent Framework** (AutoGen + Semantic Kernel 통합)를 권장. 본 조사는 AutoGen v0.4 + Agent Framework 1.0 양쪽을 함께 본다.

---

## 2. 6축 매트릭스 (● = 명시 제공, △ = 부분/간접, 빈칸 = 미제공)

| 프레임워크 | 구조 | 맥락 | 계획 | 실행 | 검증 | 개선 | **메타 레이어 명시?** |
|-----------|:----:|:----:|:----:|:----:|:----:|:----:|:---------------------:|
| DSPy | ● | △ | △ | ● | ● | ● | **No** (Optimizer 중심) |
| Inspect-AI | ● | △ | △ | ● | ● | △ | **No** (Evaluation 중심) |
| LangGraph | ● | ● | △ | ● | △ | | **No** (Orchestration 중심) |
| AutoGen (+ MS Agent FW) | ● | △ | ● | ● | △ | | **No** (Multi-Agent 중심) |

### 범례
- **구조**: 명시적 컴포넌트 타입/레이어 분리 유무
- **맥락**: 메모리·컴팩션·progressive disclosure 레이어 유무
- **계획**: planning/task decomposition을 **축으로 분리**했는지 (단순 라우팅 말고)
- **실행**: agent loop / tool call 오케스트레이션
- **검증**: evaluator / scorer / grader 레이어 분리
- **개선**: 세션 간 학습 자동 축적·컴파운딩 메카닉 (단순 optimizer는 △)
- **메타 레이어 명시**: "6축 유사 프레임워크 분류"를 **자체 문서에서 하나의 체계로 표면화**하는지

---

## 3. 프레임워크별 상세

### 3.1 DSPy (v3.1.3)

- **공식 위치**:
  - https://dspy.ai
  - https://github.com/stanfordnlp/dspy
  - 논문: *"DSPy: Compiling Declarative Language Model Calls into Self-Improving Pipelines"* (Stanford HAI)
- **정의**: "a declarative framework for building modular AI software"
- **주요 추상**:
  - **Signatures** — 타입 있는 입/출력 인터페이스
  - **Modules** — 프롬프트를 감싼 전략 (`Predict`, `ChainOfThought`, `ReAct`, `Refine` 등)
  - **Optimizers** — MIPROv2 / GEPA / SIMBA 등 compile/optimize 엔진
  - **Adapters** — ChatAdapter / JSONAdapter / XMLAdapter
- **6축 커버**:
  - 구조 ●: Signatures + Modules로 명시 구조화
  - 맥락 △: per-module history / thread-safe settings, 하지만 메모리·컴팩션 축 부재
  - 계획 △: `ReAct` 모듈이 계획 일부 포함, 독립 축 아님
  - 실행 ●: Modules 실행 + Module.batch + async
  - 검증 ●: `dspy.Evaluate` + metrics 레이어 명시
  - 개선 ● (단, 정의가 다름): Optimizer가 prompt/weight를 **compile-time에 개선**. 우리가 말하는 세션 간 컴파운딩(3회 반복→스킬화, "틀렸다"→Rule)과는 **개념 차이**. "자가 개선"이라기보다 "자가 최적화".
- **메타 레이어 표면화**: **No**
  - "Programming → Evaluation → Optimization" 3단 섹션으로 문서가 구조화되지만, 이것은 **개발 라이프사이클**이지 "실행 중 메타 프레임워크 레이어"가 아님.
  - "harness", "scaffold", "meta-framework" 단어는 등장하지 않음.
- **우리 프리미스와의 관계**: **중립 ~ 부분 훼손**
  - DSPy의 Optimizer + Evaluator 페어링은 우리 검증·개선 루프와 개념적으로 유사 → primary differentiator로서의 "검증·개선 축 표면화" 주장은 약화
  - 그러나 DSPy는 **Python 런타임 필수 + compile-time 중심** → 우리 MVP의 **bash/jq 런타임 + 세션 간 compounding** 포지셔닝은 여전히 차별화 가능
- **근거 URL**:
  - https://dspy.ai/
  - https://github.com/stanfordnlp/dspy/releases/tag/3.0.0
  - https://deepwiki.com/stanfordnlp/dspy/1.1-introduction-and-core-concepts

### 3.2 Inspect-AI (v0.3.199)

- **공식 위치**:
  - https://inspect.aisi.org.uk/
  - https://github.com/UKGovernmentBEIS/inspect_ai
  - PyPI: `inspect-ai`
- **정의**: UK AI Security Institute 공식 "framework for large language model evaluations"
- **주요 추상**:
  - **Tasks** / **Datasets** — 평가 입력 + 타깃
  - **Solvers** — 체인 컴포넌트 (elementary = `generate()`)
  - **Scorers** — text 비교·model grading·custom
  - **Agents** — ReAct / Multi-Agent / Custom / Bridge / Human
  - **Tools** — Standard / MCP / Custom / Sandboxing / Approval
  - **Analysis** — Log files, Dataframes
  - **Advanced** — Eval Sets, Error Handling, Limits, Tracing, Parallelism
- **6축 커버**:
  - 구조 ●: Tasks / Solvers / Scorers / Agents / Tools 컴포넌트 분리 명시
  - 맥락 △: Tracing / Log Viewer, 메모리 축 없음
  - 계획 △: Multi-Agent + ReAct이 계획 일부 포함, 축 분리 아님
  - 실행 ●: Solvers 체인 + Tools + Sandboxing
  - 검증 ●: Scorers (핵심 레이어) — 가장 강한 축
  - 개선 △: Eval Sets로 반복 평가 가능하지만, **세션 간 컴파운딩 메카닉 없음**. 사람이 결과를 보고 수동 개선하는 구조.
- **메타 레이어 표면화**: **No**
  - 문서 전체에 "scaffold"는 1회 등장 (agent 역량 설명 맥락).
  - "harness", "meta-framework" 등장 안 함.
  - 구조는 Eval 라이프사이클(Dataset → Solver → Scorer) 파이프라인이며, **6축 메타 레이어가 아님**.
- **우리 프리미스와의 관계**: **중립**
  - Inspect-AI는 "검증 축 특화 프레임워크" — 우리 `/verify` 스킬의 개념 대응이 강하지만, 그 외 5축(구조/맥락/계획/실행/개선)을 체계적으로 다루지 않음
  - 오히려 우리 스펙의 "qa-judge 임계값 KU-0" 설계 시 Inspect-AI의 Scorer 패턴을 참고 자산으로 **포팅 고려** 가능
- **근거 URL**:
  - https://inspect.aisi.org.uk/
  - https://pypi.org/project/inspect-ai/
  - https://github.com/UKGovernmentBEIS/inspect_ai

### 3.3 LangGraph (v1.1.6)

- **공식 위치**:
  - https://docs.langchain.com/oss/python/langgraph/overview (구 URL에서 이전)
  - https://github.com/langchain-ai/langgraph
  - LangGraph 1.0 GA 발표: changelog.langchain.com
- **정의**: "low-level orchestration framework and runtime for building, managing, and deploying long-running, stateful agents"
- **주요 추상**:
  - **Nodes** — 함수 단위
  - **Edges** — 노드 간 연결 (conditional edges 포함)
  - **Graphs** — StateGraph container
  - **States** — MessagesState 등 구조적 상태
  - **Memory** — short-term working + long-term cross-session
  - **Checkpointing** — durable execution
  - **LangSmith** 통합 (평가 / observability)
- **6축 커버**:
  - 구조 ●: StateGraph + Nodes + Edges 명시
  - 맥락 ●: **단·장기 메모리가 공식 레이어** — 4 프레임워크 중 가장 강한 맥락 축
  - 계획 △: conditional edges로 플로우 분기 가능, 독립 계획 축 아님
  - 실행 ●: durable execution + human-in-the-loop
  - 검증 △: LangSmith 외부 통합 필요, 내장 레이어 아님
  - 개선 : 학습·컴파운딩 레이어 없음
- **메타 레이어 표면화**: **No**
  - "orchestration framework"로 자기 정의. "harness", "meta-framework", "scaffold"는 등장하지 않음.
  - 레이어 분리(계획/실행/검증/개선)가 **플로우 그래프의 노드**로 환원됨 — 메타가 아닌 구현 수준.
- **우리 프리미스와의 관계**: **강화 (우리 프리미스를 뒷받침)**
  - LangGraph는 맥락·실행에 압도적으로 강하지만 계획·검증·**개선** 축은 사용자 몫
  - 6축을 하나의 메타 레이어로 묶어 강제하는 장치 부재
- **근거 URL**:
  - https://docs.langchain.com/oss/python/langgraph/overview
  - https://github.com/langchain-ai/langgraph/releases
  - https://changelog.langchain.com/announcements/langgraph-1-0-is-now-generally-available

### 3.4 AutoGen (v0.4) + Microsoft Agent Framework 1.0

- **공식 위치**:
  - https://microsoft.github.io/autogen/stable/
  - https://github.com/microsoft/autogen
  - Agent Framework 1.0 발표: 2026-04-03 (Visual Studio Magazine)
- **정의**: "framework for building AI agents and applications" (AutoGen) / "production-ready SDK and runtime for AI agents and multi-agent workflows" (Agent Framework 1.0)
- **주요 추상** (AutoGen v0.4):
  - **Studio** — 비코드 프로토타이핑
  - **AgentChat** — 단일/멀티 에이전트 Python 프레임워크
  - **Core** — event-driven 확장성 레이어
  - **Extensions** — MCP / Docker / gRPC
- **Microsoft Agent Framework 1.0 (후속)**:
  - Multi-agent orchestration + multi-provider + A2A + MCP 호환
  - AutoGen + Semantic Kernel 통합
- **6축 커버**:
  - 구조 ●: AgentChat / Core / Extensions 레이어 분리
  - 맥락 △: 대화 히스토리 관리, 메모리 축 독립 레이어 아님
  - 계획 ●: Multi-agent conversation에서 **Planner agent** 패턴이 중심 use case
  - 실행 ●: 에이전트 간 conversation loop
  - 검증 △: 자체 Evaluator 레이어 아닌, 에이전트 중 하나를 Evaluator로 배치하는 "관습"
  - 개선 : 세션 간 컴파운딩 레이어 없음
- **메타 레이어 표면화**: **No**
  - Studio / AgentChat / Core / Extensions 는 **추상화 레벨**이지 "6축 분류"가 아님
  - "harness", "meta-framework", "scaffold" 공식 문서에 없음
- **우리 프리미스와의 관계**: **강화**
  - AutoGen은 "multi-agent conversation" 하나에 집중 — 다른 5축은 사용자가 조립
  - Microsoft Agent Framework 1.0도 enterprise orchestration에 집중, 6축 메타 X
- **근거 URL**:
  - https://microsoft.github.io/autogen/stable/
  - https://visualstudiomagazine.com/articles/2026/04/06/microsoft-ships-production-ready-agent-framework-1-0-for-net-and-python.aspx
  - https://github.com/microsoft/autogen/releases

---

## 4. 종합 해석

### 4.1 축별 압도적 챔피언
- **구조**: 4개 모두 강함 (컴포넌트 분리가 각 프레임워크의 전부)
- **맥락**: **LangGraph** (단·장기 메모리 공식 레이어)
- **계획**: **AutoGen/Agent FW** (Planner agent 패턴)
- **실행**: 4개 모두 강함 (본질적으로 실행 엔진)
- **검증**: **Inspect-AI** (Scorer 레이어 압도적) + DSPy (Evaluate)
- **개선**: **DSPy만** 부분적 (Optimizer의 compile-time 최적화). **세션 간 컴파운딩**은 4개 모두 **부재**.

### 4.2 메타 레이어 표면화
**4/4 프레임워크 전부 No.**
- 각 프레임워크는 **자기 강점 1-2축**을 깊게 파고, 나머지는 "조립 가능"으로 남김
- "6축을 통합된 하나의 메타 프레임워크"로 문서화·강제하는 레퍼런스는 **본 조사 범위에서 0건**

### 4.3 프리미스 훼손 프레임워크 수
**0/4**
- 4개 모두 6축을 메타 레이어로 표면화하지 않음
- 단, **개별 축 커버리지**는 각 프레임워크가 우리보다 깊을 수 있음 (DSPy의 Optimizer, LangGraph의 Memory, Inspect-AI의 Scorer 등)

### 4.4 프리미스 판정
**🟢 강화 (4/4 비훼손) + 🟡 축 깊이 리스크**

- **강화**: 4 프레임워크 모두 6축 메타 레이어를 표면화하지 않음 → final-spec v2 §1 TL;DR의 "6축 메타 프레임워크 레퍼런스 없음" 주장은 본 조사 범위에서 **성립**.
- **축 깊이 리스크**: 각 축 개별 구현은 4 프레임워크가 이미 깊게 커버 — 우리가 **개별 축을 새로 만들면 안 되고**, 기존 프레임워크 중 최선 패턴을 참조하여 **6축을 묶는 레이어**만 새로 만들어야 함. (예: 검증 축은 Inspect-AI Scorer / DSPy Evaluate 패턴 차용, 맥락 축은 LangGraph memory 패턴 차용)
- **개선 축이 여전히 공백**: 4/4 프레임워크 모두 "세션 간 자동 컴파운딩" 레이어 없음. 우리 고유 차별화 지점.

---

## 5. 통합 판정 제안 (T-W0-02 단일 뷰)

**본 태스크 단독 결론**:
- 4개 대표 프레임워크는 "6축 메타 레이어"를 표면화하지 않음 → 프리미스 유지
- 그러나 축별 **깊이**는 기존 프레임워크가 더 깊음 → 우리는 "메타 레이어(통합)"에 가치 주장을 집중하고, 개별 축 구현은 참조·경량화 전략
- **개선(Compounding) 축**은 4/4 부재 → 최강 차별화 지점

**T-W0-03·04 수행 여부 권고**:
- **T-W0-03 (강의 원저자 공개 구현체 검색)**: **수행 권장**. 본 조사는 "잘 알려진 4개 프레임워크"에 한정됐으며, 이호연 강사 본인 또는 AI Native Camp 커뮤니티에서 이미 "6축"을 자체 구현 공개했을 가능성을 배제할 수 없음. T-W0-03에서 그 공개 여부를 직접 확인해야 프리미스 확정 가능.
- **T-W0-04 (dogfooding + 유저 인터뷰)**: **수행 권장 + 질문 축 재설정**. "6축이 유용한가"가 아니라 **"기존 프레임워크에서 개선(컴파운딩) 축을 어떻게 다루고 있고 어떤 통증이 있는가"**를 축으로 묻는 것이 효율적. 본 조사로 개선 축이 공백임이 확인된 이상, 유저 인터뷰는 그 공백에 대한 실수요 확인에 집중.
- **T-W0-05 게이트 판정**: T-W0-01(부분 훼손) + T-W0-02(강화)를 종합하면 final-spec §7.1 게이트 중 **"유사 frameworks 발견 → primary differentiator를 개인화 컴파운딩으로 좁혀 재스코프 후 W1"** 경로가 가장 적합. T-W0-03·04 완료 후 TL;DR 재작성 + primary differentiator 재정의 후 W1 진입 권장.

---

## 6. 참고 URL

### DSPy
- https://dspy.ai/
- https://github.com/stanfordnlp/dspy
- https://github.com/stanfordnlp/dspy/releases
- https://hai.stanford.edu/research/dspy-compiling-declarative-language-model-calls-into-state-of-the-art-pipelines

### Inspect-AI
- https://inspect.aisi.org.uk/
- https://github.com/UKGovernmentBEIS/inspect_ai
- https://pypi.org/project/inspect-ai/

### LangGraph
- https://docs.langchain.com/oss/python/langgraph/overview
- https://github.com/langchain-ai/langgraph
- https://changelog.langchain.com/announcements/langgraph-1-0-is-now-generally-available
- https://www.langchain.com/langgraph

### AutoGen / Microsoft Agent Framework
- https://microsoft.github.io/autogen/stable/
- https://github.com/microsoft/autogen
- https://visualstudiomagazine.com/articles/2026/04/06/microsoft-ships-production-ready-agent-framework-1-0-for-net-and-python.aspx
- https://devblogs.microsoft.com/autogen/autogen-reimagined-launching-autogen-0-4/

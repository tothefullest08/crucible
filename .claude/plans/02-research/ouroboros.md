# Phase 2 리서치 — `references/ouroboros` (검증 루프 패턴)

> - **작성일**: 2026-04-19
> - **분석 대상**: `/Users/ethan/Desktop/personal/harness/references/ouroboros/` (단독)
> - **분석 목적**: 하네스 클로드 플러그인의 **검증 루프 / 자기 강화 / Ralph Loop** 패턴 포팅 자산 발굴
> - **원본 저장소**: https://github.com/Q00/ouroboros (v0.28.8, MIT, Python 3.14+)
> - **제약**: 읽기 전용, 다른 레퍼런스 디렉토리 접근 금지

---

## TL;DR — 3줄 요약

1. **Ouroboros 자체가 "Interview → Seed → Execute → Evaluate → Evolve" 폐루프**다. 각 단계를 이벤트 소싱(SQLite EventStore)으로 기록해 머신을 재시작해도 루프가 이어진다. 이 구조 전체가 하네스의 **검증(Verify)+개선(Compound)** 축을 가장 깊이 체화한 레퍼런스다.
2. 검증은 3단 게이트로 분리돼 있다 — **Stage 1 Mechanical($0 lint/build/test) → Stage 2 Semantic(LLM AC 평가) → Stage 3 Consensus(멀티모델 투표)**. Generator(Seed Architect/Executor)와 Evaluator(Evaluator/QA-Judge/Contrarian)가 **에이전트 단위로 분리**되어 있어 하네스 day2에서 강조한 "Generator ≠ Evaluator" 원칙의 정석 구현이다.
3. **Ralph Loop = "The boulder never stops"**. QA verdict(pass/revise/fail)가 `revise`면 동일 lineage 위에서 재실행, `pass`까지 반복한다. `ouroboros_evolve_step`은 1세대만 처리하고 상태를 EventStore에서 재구축하는 **stateless-per-iteration** 설계 — 우리 플러그인의 `/verify` → 자동 재시도 루프에 그대로 이식 가능하다.

---

## 1. 디렉토리 구조

### 1.1 루트 레벨 (주요 파일만)

```
ouroboros/
├── .claude-plugin/
│   ├── plugin.json           # name: ouroboros, skills/mcpServers 선언
│   ├── marketplace.json      # Claude Code 마켓플레이스 메타
│   └── .mcp.json
├── .claude/settings.json     # UserPromptSubmit + PostToolUse 훅 (개발 모드)
├── .mcp.json                 # 실제 배포용 MCP 엔트리포인트 (uvx)
├── .ouroboros/
│   ├── mechanical.toml       # build/test 커맨드 (Stage 1 게이트 설정)
│   └── seeds/                # 실제 프로덕션 seed 샘플 (*.yaml)
├── CLAUDE.md                 # 개발 모드 `ooo` 서브커맨드 라우팅 테이블
├── README.md / README.ko.md  # 한/영 이중 README (~500 줄씩)
├── llms.txt / llms-full.txt  # LLM 전용 요약(21K / 569K 줄)
├── HANDOFF.md, CHANGELOG.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md
├── pyproject.toml, uv.lock   # Python 3.14+, uv 기반
├── commands/                 # 14개 *.md (슬래시 커맨드 엔트리)
├── skills/                   # 21개 SKILL.md (실제 동작 정의)
├── hooks/hooks.json          # SessionStart + UserPromptSubmit + PostToolUse
├── scripts/                  # drift-monitor.py, keyword-detector.py, ralph.py 등 11개
├── src/ouroboros/            # Python 코어 (agents/, bigbang/, routing/, execution/, evaluation/, evolution/, resilience/, observability/, persistence/, orchestrator/, mcp/, tui/, cli/)
├── crates/ouroboros-tui/     # Rust 기반 Textual TUI 크레이트
├── docs/                     # architecture.md, key-patterns.md, config-reference.md 등
├── examples/, tests/, tools/
└── .github/                  # ISSUE_TEMPLATE 3종, 4개 workflow
```

### 1.2 `.claude-plugin/plugin.json` 구성

```json
{
  "name": "ouroboros",
  "version": "0.28.8",
  "skills": "./skills/",
  "mcpServers": "./.mcp.json"
}
```
(file: `.claude-plugin/plugin.json:1-24`)

포인트: `skills/`와 `mcpServers`가 **상대 경로로 주입**됨 → 플러그인 설치 시 자동 탐색. 우리 플러그인도 동일 패턴.

### 1.3 `skills/` 디렉토리 (21개)

각 폴더에 `SKILL.md` 하나씩. 그룹화하면:

| 그룹 | 스킬 | 하네스 6축 매핑 |
|------|------|-----------------|
| Scaffold | `setup`, `welcome`, `tutorial`, `help`, `update` | 구조 |
| Context | `brownfield` | 맥락 |
| Planning | `interview`, `seed`, `pm` | 계획 |
| Execution | `run`, `ralph`, `cancel` | 실행 |
| Verify | `evaluate`, `qa`, `status` | **검증** |
| Compound | `evolve`, `unstuck`, `openclaw` | **개선** |
| Export | `publish` | 구조 |

### 1.4 `agents/` — 아홉 개의 사고 + 보조 5종

위치: `src/ouroboros/agents/` (플러그인 내장 agents/ 폴더가 아닌 **파이썬 패키지 안에 프롬프트 md**를 두는 변칙 구조). `loader.py`가 파일을 읽어 MCP 프롬프트로 주입.

| 카테고리 | 파일 | 역할 |
|---------|------|------|
| **Core (9)** | `socratic-interviewer.md` | 질문만 하는 인터뷰어 (도구 없음) |
|  | `ontologist.md` | "이게 정확히 뭐지?" 근본 정의 |
|  | `seed-architect.md` | 인터뷰 → Seed YAML 추출 |
|  | `evaluator.md` | 3단 평가 파이프라인 |
|  | `qa-judge.md` | **단일 JSON 응답 QA 판정관** (score/verdict/dimensions) |
|  | `contrarian.md` | 가정 뒤집기 |
|  | `hacker.md` / `simplifier.md` / `researcher.md` / `architect.md` | 5 막힘 돌파 페르소나 |
| **Support** | `advocate.md`, `breadth-keeper.md`, `codebase-explorer.md`, `consensus-reviewer.md`, `judge.md`, `ontology-analyst.md`, `seed-closer.md`, `semantic-evaluator.md`, `analysis-agent.md`, `code-executor.md`, `research-agent.md` | 파이프라인 내부 호출 |

### 1.5 `hooks/hooks.json` — 3종 훅

```json
{
  "SessionStart":     "python3 scripts/session-start.py",    // 버전 체크
  "UserPromptSubmit": "python3 scripts/keyword-detector.py", // 키워드 → 스킬 매핑
  "PostToolUse (Write|Edit)": "python3 scripts/drift-monitor.py" // 드리프트 경고
}
```
(file: `hooks/hooks.json:1-40`)

### 1.6 `commands/` — 14개 스킬 엔트리

각 파일은 **얇은 래퍼**:
```markdown
---
description: "..."
aliases: [eval]
---
Read the file at `${CLAUDE_PLUGIN_ROOT}/skills/evaluate/SKILL.md` using the Read tool and follow its instructions exactly.
```
(예: `commands/evaluate.md:1-6`)

이 패턴 덕분에 `commands/*.md`와 `skills/*/SKILL.md`가 **1:N 관계**가 될 수 있고, `aliases`로 자연어 트리거를 확장한다.

---

## 2. SKILL.md 프론트매터 패턴

### 2.1 3가지 프론트매터 템플릿

**A. 최소형** (`evaluate`, `qa`, `status`, `ralph`, `unstuck`):
```yaml
---
name: evaluate
description: "Evaluate execution with three-stage verification pipeline"
---
```

**B. MCP 바인딩형** (`interview`, `seed`, `run`):
```yaml
---
name: interview
description: "Socratic interview to crystallize vague requirements"
mcp_tool: ouroboros_interview
mcp_args:
  initial_context: "$1"
  cwd: "$CWD"
---
```
(file: `skills/interview/SKILL.md:1-8`)

→ 프론트매터가 **MCP 도구 자동 바인딩 선언**을 겸함. 위치 인자 `$1`과 환경변수 `$CWD` 치환.

**C. 자연어 트리거 강화형** (`pm`):
```yaml
---
name: pm
description: "Generate a PM through guided PM-focused interview with automatic question classification. Use when the user says 'ooo pm', 'prd', 'product requirements', or wants to create a PRD/PM document."
---
```
description 자체에 **"Use when the user says …"** 문장을 삽입 → Claude Code 자동 스킬 매칭률 상승.

### 2.2 description 최적화 — 트리거 키워드 패턴

키워드 매칭을 훅 스크립트 `scripts/keyword-detector.py`가 처리한다. 매핑 구조 (file: `scripts/keyword-detector.py:30-133`):

```python
KEYWORD_MAP = [
    {"patterns": ["ooo interview", "ooo socratic"], "skill": "/ouroboros:interview"},
    {"patterns": ["interview me", "clarify requirements", ...], "skill": "/ouroboros:interview"},
    {"patterns": ["ralph", "don't stop", "must complete", "until it works", "keep going"],
     "skill": "/ouroboros:ralph"},
    ...
]
```

트리거가 3계층:
1. **접두어 shortcut** (`ooo <cmd>`) — 최우선
2. **자연어 영어 키워드** (`"i'm stuck"`, `"am i drifting"`)
3. **bare `ooo`** → welcome 스킬

그리고 **setup 게이트**: MCP 미구성이면 `setup`/`help`/`qa`를 제외한 모든 명령을 `ooo setup`으로 리다이렉트 (file: `scripts/keyword-detector.py:22-27, 213-232`). → 우리 플러그인도 MCP 필수 스킬 게이트 만들 때 참조.

### 2.3 다국어(한국어) 지원 여부

- **README**: `README.md`(영어) + `README.ko.md`(한국어) **이중 파일** (각 ~500 줄, 거의 1:1 번역).
- **SKILL.md / agents/*.md**: **영어 전용**. 한국어 프롬프트 없음.
- **description / 키워드 트리거**: 영어만 등록.
- **오픈소스 배포**: PyPI (`ouroboros-ai`), Claude Code 마켓플레이스, OpenClaw 브릿지 모두 영어 1급.

→ **시사점**: 한국어 최적화는 README 레벨만, 실행 레이어는 영어 유지. "오픈소스 확산 vs 한국어 UX" 균형(우리의 `clarified-spec.md` UU 항목)의 구체적 선례다. 우리 플러그인은 **README 이중 + SKILL 영어 + description에 한국어 트리거 보강** 조합이 유력.

---

## 3. 핵심 워크플로우 (검증 루프 중점)

### 3.1 대순환 — Ouroboros 자체가 폐루프

```
Interview → Seed → Execute → Evaluate
    ↑                           ↓
    └──── Evolutionary Loop ────┘
```
(file: `CLAUDE.md:57-61`, `README.ko.md:166-175`)

이게 **우로보로스(자기 꼬리를 삼키는 뱀)의 아키텍처적 구현**이다. Evaluate 결과가 다음 세대 Seed 스펙 입력이 된다. 모든 iteration 데이터가 SQLite EventStore에 append-only.

### 3.2 Seed — 계획 산출물 (불변)

Seed YAML 구조 (실제 샘플, file: `.ouroboros/seeds/seed_73827177a2a3.yaml`):

```yaml
goal: <단일 문장>
task_type: code
brownfield_context:
  project_type: brownfield
  context_references: [...]
  existing_patterns: [...]
  existing_dependencies: [...]
constraints: [Python >= 3.14, ...]
acceptance_criteria: [...]   # 측정 가능한 기준, 트리 구조
ontology_schema:
  name: ACRecursiveExecution
  fields: [{name, type, description, required}, ...]
evaluation_principles:
  - {name, description, weight}   # 총합 1.0
exit_conditions:
  - {name, description, criteria}
metadata:
  seed_id: seed_73827177a2a3
  ambiguity_score: 0.1225          # ≤ 0.2 게이트 통과값
  interview_id: interview_20260404_165002
  parent_seed_id: null             # 계보(lineage) 포인터
```

핵심 포인트:
- **`evaluation_principles`에 weight** — 3단 평가가 이 가중치대로 점수화.
- **`exit_conditions`** — Ralph/Evolve가 멈추는 조건을 Seed가 스스로 명시.
- **`parent_seed_id`** — 진화 계보 추적. 세대가 거듭될수록 이 포인터가 이어진다.

### 3.3 Ambiguity Score Gate (암묵지 → 명시지 전환 게이트)

```
Ambiguity = 1 − Σ(clarityᵢ × weightᵢ)
```
(file: `README.ko.md:202-232`)

| 차원 | Greenfield | Brownfield |
|------|:---:|:---:|
| 목표 명확도 | 40% | 35% |
| 제약 명확도 | 30% | 25% |
| 성공 기준 | 30% | 25% |
| 컨텍스트 명확도 | — | 15% |

**임계값 0.2** 미만이 되어야 Seed 생성 가능. 그렇지 않으면 `interview`를 더 돌린다.

→ 우리 플러그인의 **"암묵지 해소" 요구사항**에 대응하는 **정량적 게이트 모델**. `clarify:vague`의 정성적 질문과 결합하면 강력하다.

### 3.4 3단 검증 파이프라인 (Evaluate)

(file: `src/ouroboros/agents/evaluator.md:1-76`, `docs/contributing/key-patterns.md:147-170`)

```
Artifact
  └─▶ Stage 1: Mechanical ($0)    — lint, build, test, static, coverage
        ✗ Fail → STOP
        ✓ Pass
  └─▶ Stage 2: Semantic ($$)      — LLM이 AC 준수도 + 드리프트 평가
        ✗ AC < 100% → STOP
        ✓ Pass (score ≥ 0.8)
  └─▶ Stage 3: Consensus ($$$$)   — 멀티모델 투표 (트리거 시)
        ≥66% 승인 → APPROVED
        < 66%     → REJECTED
```

**Stage 3 트리거 6조건** (file: `docs/contributing/key-patterns.md:164-170`):
1. Seed modification
2. Ontology evolution
3. Goal reinterpretation
4. Seed drift > 0.3
5. Stage 2 uncertainty > 0.3
6. Lateral thinking adoption

→ **모델 계층(Frugal 1x → Standard 10x → Frontier 30x)을 회의실처럼 에스컬레이션**하는 방식. 하네스 day2에서 언급한 "모델도 나누고, 역할도 나눈다"(Codex 코드리뷰 / Gemini 문서리뷰 / Opus 아키텍처)의 일반화된 구현.

### 3.5 QA-Judge — 단일 판정 (Ralph 내부 호출용)

`qa-judge.md`는 **엄격한 JSON 스키마 하나만** 반환 (file: `src/ouroboros/agents/qa-judge.md:1-36`):

```json
{
  "score": 0.72,
  "verdict": "revise",                    // pass | revise | fail
  "dimensions": {
    "correctness": 0.85,
    "completeness": 0.60,
    "quality": 0.75,
    "intent_alignment": 0.80,
    "domain_specific": 0.60
  },
  "differences": ["Missing error handling ..."],
  "suggestions": ["Add try/except in fetch_data() ..."],
  "reasoning": "..."
}
```

| Score | Verdict | Loop Action |
|-------|---------|-------------|
| ≥ 0.80 | pass    | done        |
| 0.40–0.79 | revise  | continue    |
| < 0.40 | fail    | escalate    |

**"Each difference MUST have a corresponding suggestion"** (제약 규칙) — 평가 결과가 **자동 다음 액션으로 번역 가능**한 형식이다.

→ 우리 플러그인의 `/verify` 루프에 그대로 이식 가능한 **가장 간결한 Evaluator 스키마**.

### 3.6 Ralph Loop — "The boulder never stops"

`skills/ralph/SKILL.md` (file: `skills/ralph/SKILL.md:1-193`) 핵심 의사코드:

```python
while iteration < max_iterations:
    job = await start_evolve_step(lineage_id, seed_content, execute=True)
    job_id, cursor = job.meta["job_id"], job.meta["cursor"]

    prev_completed = 0
    while not terminal:
        wait_result = await job_wait(job_id, cursor, timeout_seconds=120)
        cursor = wait_result.meta["cursor"]
        status  = wait_result.meta["status"]
        current_completed = <parse AC completed>
        if current_completed > prev_completed:
            print(f"[Level complete] AC: {current_completed}/{total}")
            prev_completed = current_completed
        terminal = status in ("completed", "failed", "cancelled")

    result = await job_result(job_id)
    qa_verdict = <parse from response>
    verification_history.append({"iteration": iteration, "verdict": qa_verdict, ...})

    if qa_verdict == "pass":
        break
    iteration += 1
```

주목할 설계:
1. **Non-blocking background execution** — `start_evolve_step`이 즉시 job_id 반환, 별도 long-poll(`job_wait`, 120초).
2. **Level-based polling** — AC 완료 개수가 증가할 때만 보고 (context 절약).
3. **상태는 EventStore에서 재구축** — 세션이 끊겨도 `query_events(aggregate_id=lineage_id)`로 이어감.
4. **종료 조건**: verdict=pass **또는** max_iterations.
5. **종료 시 다음 스텝 제안** — `📍 Next:` 형식으로 `ooo evaluate` 또는 `ooo interview`, `ooo unstuck` 안내.

추가로 `scripts/ralph.py`, `scripts/ralph.sh`, `scripts/ralph-rewind.py` — 외부에서 루프를 돌리는 쉘 진입점도 제공 (MCP 없이도 동작).

### 3.7 Evolve — 세대별 온톨로지 수렴

(file: `skills/evolve/SKILL.md:1-121`, `README.ko.md:234-265`)

```
Gen 1: Interview → Seed(O₁) → Execute → Evaluate
Gen 2: Wonder → Reflect → Seed(O₂) → Execute → Evaluate
...
→ Similarity ≥ 0.95 or Gen 30 도달 → CONVERGED
```

**유사도 계산**:
```
Similarity = 0.5 × name_overlap + 0.3 × type_match + 0.2 × exact_match
```

**병리 패턴 감지**:
| 신호 | 조건 | 의미 |
|------|------|------|
| Stagnation | 3세대 연속 similarity ≥ 0.95 | 안정 |
| Oscillation | Gen N ≈ Gen N-2 (주기 2) | 두 설계 사이 왕복 |
| Repeated feedback | 3세대 질문 중복률 ≥ 70% | Wonder 같은 질문만 반복 |
| Hard cap | 30세대 | 안전장치 |

**action 응답값 4종** (MCP 응답 meta):
- `continue` → 한 번 더 `evolve_step`
- `converged` → 완료
- `stagnated` → `ouroboros_lateral_think` 제안
- `exhausted` → 최고 결과로 `evaluate`
- `failed` → `status` 점검

→ **"루프 반복을 통한 학습"(compounding)의 수치화된 구현**. 우리 플러그인의 `/compound`에서 "패턴 3회 반복 감지"의 기법적 참고.

### 3.8 Drift Detection — 실행 중 맥락 이탈 감지

(file: `skills/status/SKILL.md:79-85`, `scripts/drift-monitor.py`)

```
Combined Drift = 0.5×Goal_Drift + 0.3×Constraint_Drift + 0.2×Ontology_Drift
```

| 구간 | 상태 | 조치 |
|------|------|------|
| 0.0 – 0.15 | Excellent | 계속 |
| 0.15 – 0.30 | Acceptable | 주시 |
| 0.30+ | Exceeded | 재정렬 (`ooo interview` 또는 `ooo evolve`) |

`scripts/drift-monitor.py` (file: `scripts/drift-monitor.py:1-65`)는 **PostToolUse(Write|Edit) 훅**으로 동작, 파일 수정 시마다 최근 세션(1시간 내)이 살아있는지 체크하고 advisory 메시지 출력. 실제 드리프트 계산은 MCP 호출이 담당.

→ 우리 플러그인의 **"틀렸다" 발언 기록 / 3회 반복 감지** 컴파운딩 트리거를 훅으로 구현할 때 참조할 패턴.

### 3.9 Unstuck — 막힘 돌파 5 페르소나

| Persona | 격언 | 용도 |
|---------|------|------|
| hacker | "Make it work first" | 과잉사고 해소 |
| researcher | "What info are we missing?" | 문제 불명확 |
| simplifier | "Cut scope, MVP" | 복잡성 폭주 |
| architect | "Restructure entirely" | 설계 오류 |
| contrarian | "Wrong problem?" | 가정 의심 |

(file: `skills/unstuck/SKILL.md:19-27`)

Evolve의 `stagnated` action 시 자동 제안. **lateral thinking을 이벤트 소스에 기록**해 Stage 3 Consensus 트리거 조건 중 하나로 활용.

### 3.10 사용 디자인 패턴 정리

| 패턴 | 적용 위치 | 증거 |
|------|-----------|------|
| **Generator/Evaluator 분리** | Seed Architect + Executor(Generator) vs Evaluator/QA-Judge(Evaluator) | `agents/*.md` 역할 정의 |
| **Ralph Loop** | `skills/ralph/`, `scripts/ralph.py` | `skills/ralph/SKILL.md` |
| **Event Sourcing** | SQLite EventStore, append-only, replay | `docs/contributing/key-patterns.md:76-104` |
| **Agent Council (mini)** | Stage 3 Consensus — Proposer / Devil's Advocate / Synthesizer | `agents/evaluator.md:31-46` |
| **Result<T,E> 타입** | 예상 실패는 Result, 버그는 예외 | `docs/contributing/key-patterns.md:11-37` |
| **Frozen Dataclass / Pydantic frozen=True** | Seed 불변성, 스레드 안전 | 동 46-67 |
| **Protocol 기반 전략** | ExecutionStrategy, 런타임 추상화(Claude Code / Codex CLI) | 동 107-139 |
| **PAL Router (1x→10x→30x)** | 실패 시 에스컬레이션, 성공 시 다운그레이드 | `README.ko.md:340-345` |
| **Progressive Disclosure** | SKILL.md에서 `ToolSearch`로 MCP 도구 지연 로드 | 모든 주요 SKILL.md 공통 |
| **Cost-Tiered Gating** | Mechanical($0) → Semantic($$) → Consensus($$$$) | `key-patterns.md:147-155` |

---

## 4. 재사용 / 포팅 가능한 자산 (UK 관점)

> UK = 내가 가진 것 중 덜 쓰이는 자산. Phase 1 `clarified-spec.md`에서 ouroboros는 "검증 루프 패턴" UK로 분류됨.

### 4.1 그대로 포팅할 구조·템플릿

| # | 자산 | 원본 경로 | 우리 플러그인에서의 용도 |
|---|------|-----------|--------------------------|
| A1 | `.claude-plugin/plugin.json` 최소 구성 (skills + mcpServers 2줄) | `.claude-plugin/plugin.json:1-24` | 플러그인 매니페스트 뼈대 |
| A2 | `commands/*.md` 얇은 래퍼 + `skills/*/SKILL.md` 본문 분리 패턴 | `commands/evaluate.md` ↔ `skills/evaluate/SKILL.md` | 슬래시 커맨드 → 본문 라우팅 |
| A3 | CLAUDE.md의 **서브커맨드 라우팅 테이블** | `CLAUDE.md:12-36` | `/harness <sub>` 진입점 매핑 |
| A4 | SKILL.md 프론트매터 3템플릿 (최소형 / MCP 바인딩형 / 자연어 트리거형) | §2.1 참조 | 스킬 6종 전부 이 3형식 내 |
| A5 | `scripts/keyword-detector.py` + **setup 게이트** 로직 | `scripts/keyword-detector.py:22-232` | 설치 안 된 상태에서 안내 훅 |
| A6 | `scripts/drift-monitor.py` **PostToolUse 훅** | `scripts/drift-monitor.py:1-65` | "세션 격리 + 승격 게이트" advisory |
| A7 | `hooks/hooks.json` 3종 훅 구성(SessionStart/UserPromptSubmit/PostToolUse) | `hooks/hooks.json:1-40` | 우리 3축(세션 시작·프롬프트·파일 저장) 훅 |
| A8 | Seed YAML 스키마 (goal/constraints/AC/ontology/principles+weight/exit_conditions/metadata) | `.ouroboros/seeds/seed_73827177a2a3.yaml` | `/plan` 산출물 형식 |
| A9 | `.ouroboros/mechanical.toml` — 3줄 build/test 선언 | `.ouroboros/mechanical.toml:1-4` | 프로젝트별 Stage 1 게이트 설정 |
| A10 | `qa-judge.md` JSON 스키마 + 임계값 | `src/ouroboros/agents/qa-judge.md:1-36` | `/verify` 1패스 판정 |
| A11 | `evaluator.md` 3단 파이프라인 **마크다운 포맷** | `src/ouroboros/agents/evaluator.md` | `/verify --deep` 포맷 |
| A12 | Ralph Loop **의사코드 블록** | `skills/ralph/SKILL.md:50-99` | `/verify` 자동 재시도 본문 |
| A13 | Ambiguity 점수 가중 공식 (Greenfield/Brownfield 이중 테이블) | `README.ko.md:210-230` | `/clarify` 종료 조건 |
| A14 | Drift 임계값 테이블 (0.15 / 0.30) | `skills/status/SKILL.md:79-85` | `/compound`의 암묵지 승격 게이트 수치 |
| A15 | Ontology Similarity 수식 (0.5 name + 0.3 type + 0.2 exact) | `README.ko.md:236-247` | "3회 반복 감지" 유사도 판정 |
| A16 | 병리 패턴 감지 4종 (stagnation/oscillation/repeated-feedback/hard-cap) | `README.ko.md:249-257` | 컴파운딩 오염 방지 규칙 |
| A17 | Unstuck 5 페르소나 프롬프트 | `src/ouroboros/agents/{contrarian,hacker,simplifier,researcher,architect}.md` | 루프 정체 시 측면 돌파 |
| A18 | 3템플릿 이슈 템플릿 (bug/feature/question) | `.github/ISSUE_TEMPLATE/*.yml` | 오픈소스 배포 시 그대로 |
| A19 | README.md + README.ko.md **이중 구조** | 루트 | 한·영 이중 진입 |
| A20 | `llms.txt` / `llms-full.txt` — LLM 전용 요약본 | 루트 | 플러그인 사용자 AI가 읽는 단일 문서 |

### 4.2 "verify → 개선" 자동 루프에 포팅할 구체 제안

**우리 플러그인 `/verify` 구현안** (ouroboros 포팅 기반):

```
사용자: "/verify"
  │
  ├─ Stage 0: ToolSearch로 MCP 지연 로드 (ouroboros A12 패턴)
  │
  ├─ Stage 1: Mechanical ($0) — .harness/mechanical.toml에서 build/test 명령 읽어 실행
  │    ✗ → STOP, 에러 메시지 반환
  │
  ├─ Stage 2: Semantic — Evaluator 서브에이전트(Generator와 분리) 호출
  │    │   (clarified-spec.md의 "다른 관점 서브에이전트, 회의적 튜닝" 원칙)
  │    │   qa-judge.md JSON 스키마 재사용 → {score, verdict, dimensions, differences, suggestions}
  │    ✗ verdict=revise, score 0.40~0.79 → 자동 재시도 (Ralph Loop, 최대 N회)
  │    ✗ verdict=fail (<0.40) → /unstuck 제안
  │    ✓ verdict=pass (≥0.80) → Stage 3 트리거 조건 체크
  │
  ├─ Stage 3: Consensus (트리거 시만) — Evaluator 2개 + Contrarian
  │    ≥66% 승인 시 APPROVED
  │
  └─ 결과 이벤트를 .harness/memory/verify-history/ 에 append-only 기록
       → /compound가 이 이력에서 "패턴 3회 반복" 감지 후 학습 승격 제안
```

**컴파운딩 루프와의 접속점**:
- ouroboros는 학습을 **seed 진화** 형태로만 축적(각 generation은 별도 Seed).
- 우리는 여기에 **`/compound`에서 corrections/ + tacit/ + preferences/ 디렉토리 분리 적립** (clarified-spec.md §암묵지 저장 포맷)을 결합.
- **3가지 트리거** (clarified-spec.md §컴파운딩 트리거):
  1. 패턴 3회 반복 감지 — ouroboros의 ontology similarity 수식 재사용 (A15)
  2. "틀렸다" 발언 감지 — drift-monitor.py(A6) 훅 변형, UserPromptSubmit에서 감지
  3. `/session-wrap` — ouroboros는 없지만 evolve의 `converged` action이 동일 역할

**승격 게이트** (clarified-spec.md §오염 방지):
- ouroboros는 세대 간 evolve_step에 **evaluate 통과 필수** → 우리 corrections/ 저장 전 `/verify` 통과 의무화 포팅 가능.
- 병리 패턴 감지(A16) → 같은 corrections가 3번 토글되면 oscillation, 저장 차단.

### 4.3 포팅 **금지** 또는 주의 자산

| 주의 | 이유 |
|------|------|
| Python 3.14+ 의존, uv 빌드 | 우리는 플러그인 단일 레이어 — 파이썬 런타임 필수화 피하고 **스킬/훅/MCP만** 쓴다 |
| SQLite EventStore (`persistence/`) | 이벤트 소싱 풀 구현은 과설계. **append-only JSON 파일**로 시작, 필요 시 승격 |
| Textual TUI (`crates/ouroboros-tui`) | 대시보드는 out of scope |
| LiteLLM 멀티 프로바이더 | Claude Code 범위에선 Claude 전용. Consensus도 claude-opus/claude-sonnet/claude-haiku 내부 분리로 충분 |
| MCP 서버 자체 개발 | ouroboros는 파이썬 MCP 서버를 따로 띄움. 우리는 **Claude Code 스킬+훅 순수 구성** 먼저. MCP는 Phase 2 옵션 |
| 버전 자동 체크 스크립트 (`scripts/version-check.py` + SessionStart) | 오픈소스 확산 전까지 과설계 |

---

## 5. 6축 매핑 매트릭스

ouroboros가 **하네스 6축 각각에 어떻게 대응하는지** — ✓ 강함 / ○ 약함 / – 없음 기준.

| 6축 | ouroboros 대응 | 증거 | 강도 |
|-----|----------------|------|------|
| **구조 (Scaffolding)** | `.claude-plugin/plugin.json` 최소 구성, `commands/` ↔ `skills/` 1:N 분리, `.ouroboros/seeds/` 산출물 폴더, `docs/contributing/` 체계, 이슈템플릿 3종 | `plugin.json`, `commands/*.md`, `.ouroboros/seeds/`, `.github/ISSUE_TEMPLATE/` | ✓ |
| **맥락 (Context)** | Brownfield scan 스킬, SKILL.md 프론트매터 설명 최적화, `llms.txt`/`llms-full.txt` LLM 전용 요약, 세션 격리(EventStore lineage_id) | `skills/brownfield/`, `llms.txt`, 스킬 내 `[from-code]`/`[from-user]`/`[from-research]` 라벨 | ✓ |
| **계획 (Planning)** | Socratic Interview → Seed 고정(Ambiguity ≤ 0.2 게이트), AskUserQuestion 4-PATH 라우팅, Dialectic Rhythm Guard(연속 3회 비인간 답변 차단) | `skills/interview/SKILL.md:97-250`, `.ouroboros/seeds/*.yaml` | ✓ |
| **실행 (Execution)** | PAL Router 3-tier 자동 스케일, AC Tree 재귀 분해, anyio 병렬, Double Diamond 4단계, Non-blocking background job | `src/ouroboros/execution/`, `skills/run/SKILL.md`, `README.ko.md:340-345` | ✓ |
| **검증 (Verify)** | **3단 파이프라인 (Mechanical/Semantic/Consensus)**, QA-Judge JSON 스키마, Drift 3-요소 가중 측정, Stage 3 6트리거 조건 | `src/ouroboros/agents/evaluator.md`, `src/ouroboros/agents/qa-judge.md`, `docs/contributing/key-patterns.md:147-170` | ✓✓ **최강** |
| **개선 (Compound)** | **Evolve loop (ontology similarity ≥ 0.95)**, Wonder/Reflect, 병리 패턴 4종, Ralph persistent loop, EventStore 계보 누적, Unstuck 5 페르소나 | `skills/evolve/SKILL.md`, `skills/ralph/SKILL.md`, `skills/unstuck/SKILL.md` | ✓✓ **최강** |

### 5.1 "검증"/"개선"축 특화 상세

ouroboros가 다른 레퍼런스와 **결정적으로 다른 지점**:

1. **Seed가 불변 + `evaluation_principles`에 weight** → 검증 기준을 **Seed 생성 시점에 미리 고정**. 하네스 day2의 "기준이 있어야 검증 가능"(Sprint Contract)을 **Seed가 강제**.
2. **3단 평가의 비용 게이트** → $0 mechanical 우선, 실패 시 LLM 호출 절약. 하네스 day2의 "너비(browser agent) vs 깊이(gate)" 중 **깊이 축을 극단적으로 심화**.
3. **Evolve의 `parent_seed_id` 계보** → 각 세대가 이전 세대를 참조 → 진화 이력 자체가 학습 누적. 하네스 day2의 "3번 반복 → Skill"의 **Seed 버전으로 구현**.
4. **Stagnation/Oscillation/Repeated-Feedback/Hard-cap** → 학습이 **오히려 나빠지는 경우**(oscillation) 자동 감지. `clarified-spec.md` UU §"개인화 컴파운딩 과적합" 리스크의 기술적 해답.
5. **Dialectic Rhythm Guard** → 자동화가 3연속이면 강제로 사용자에게 질문. 하네스 day2의 "'해줘' 대신 '물어봐'" 원칙의 프로그램화.

---

## 6. 차별점 4관점 평가

`clarified-spec.md`가 정의한 4가지 차별점 축에서 ouroboros 자체를 평가:

| 관점 | 평가 | 근거 |
|------|------|------|
| **1. 기존 도구 오케스트레이션** | ○ 일부 (독립형에 가까움) | 자체 폐루프 완결. Claude Code / Codex CLI / OpenClaw만 어댑트. Superpower/CE/hoyeon 같은 타 플러그인과 **조합 설계는 없음** |
| **2. 하네스 6축 강제** | ✓ 강함 (검증/개선 특히) | Seed 불변성 + Ambiguity 게이트 + 3단 평가 + Evolve 수렴 = 6축 중 **검증/개선 2축을 아키텍처로 강제**. 계획 축도 Interview로 강함. 다만 "구조/맥락" 축은 일반 플러그인 수준 |
| **3. 개인화 컴파운딩** | ○ 중간 (프로젝트 레벨만) | EventStore로 프로젝트 lineage는 누적되나, **유저 cross-project 학습은 없음**. `~/.ouroboros/prefs.json`은 star_asked / welcome 여부만. `corrections/`·`tacit/` 같은 카테고리 분리 암묵지 저장소 개념 **없음** |
| **4. 한국어 대화 최적화** | ○ README만 (실행은 영어) | README.ko.md만 한국어. SKILL.md / agents / 키워드 매핑 모두 영어. 한국어 트리거 키워드 등록 없음 |

### 6.1 우리 플러그인이 **채워야 할 공백** (ouroboros에 없는 것)

1. **크로스 프로젝트 유저 학습** — `~/.harness/memory/` 유저 레벨 암묵지 축적. ouroboros는 프로젝트별 Seed 진화만.
2. **타 도구 오케스트레이션** — superpower brainstorming + CE plan + ouroboros verify의 **상위 레이어**. ouroboros 자체는 이런 메타 조율을 하지 않음.
3. **한국어 트리거 + 대화 UX** — `scripts/keyword-detector.py`에 한국어 키워드 삽입, SKILL description에 한국어 트리거 문장 보강.
4. **"틀렸다" 발언 전용 corrections 저장소** — ouroboros의 drift-monitor 확장형. 유저 feedback 카테고리가 별도 계층으로 존재해야.
5. **세션 종료 시 `/session-wrap`** — evolve의 `converged`는 자동이지만, 우리는 **유저 명시 승인 필요** (clarified-spec.md §승격 게이트).

### 6.2 우리 플러그인이 **포팅해야 할 것** (ouroboros가 이미 잘한 것)

위 §4 표 A1–A20 중 핵심 7개를 Phase 3 브레인스토밍 우선 순위로:

1. **A12 Ralph Loop 의사코드** → `/verify` 자동 재시도 본문 (최우선)
2. **A10 qa-judge JSON 스키마** → Evaluator 응답 포맷
3. **A11 3단 평가 파이프라인** → `/verify --deep` 확장 옵션
4. **A2 commands ↔ skills 분리 패턴** → 우리 스킬 전부 이 구조
5. **A5 keyword-detector + setup 게이트** → 한국어 트리거 추가해 그대로
6. **A8 Seed YAML 스키마** → `/plan` 산출물 형식 (`evaluation_principles`의 weight 개념 포함)
7. **A6 drift-monitor PostToolUse 훅** → 우리 "틀렸다" 감지 훅 원형

---

## 7. 결정 요약 (Phase 3 브레인스토밍 인풋용)

### 7.1 ouroboros에서 확인한 검증 루프 설계 원칙 (우리 플러그인이 따를 것)

1. **기준은 계획 단계에서 고정한다** — `evaluation_principles`를 Seed에 못 박는다. 실행 후 기준 변경 금지.
2. **검증은 계단식 비용** — 무료 기계 검사 → LLM 평가 → 멀티모델 합의. 실패 시 즉시 중단.
3. **Generator ≠ Evaluator** — 별도 에이전트·별도 프롬프트·별도 JSON 스키마.
4. **루프는 stateless-per-iteration** — EventStore로 상태 복원. 세션이 끊겨도 이어짐.
5. **종료 조건도 Seed에** — `exit_conditions` 명시. max_iterations은 안전장치.
6. **수렴 vs 정체 구분** — similarity ≥ 0.95(수렴) vs oscillation(정체). 같은 걸 반복하지 않는다.
7. **막히면 측면으로** — Unstuck 5 페르소나로 관점 전환, 선형 루프 고집 금지.

### 7.2 ouroboros에서 **거른** 것 (과설계로 판정)

- 파이썬 코어 라이브러리 전체 (우리는 스킬+훅만)
- SQLite EventStore (JSON append로 시작)
- PAL Router 3-tier 모델 자동 스케일 (Claude Code 기본에 맡김)
- Textual TUI 대시보드
- LiteLLM 멀티 프로바이더
- MCP 자체 서버 구현 (Phase 2 옵션)

### 7.3 Phase 3 브레인스토밍으로 넘길 의문점

1. **한국어 트리거를 어디까지 영어와 섞을 것인가** — keyword-detector에 한국어만 추가 vs SKILL.md 자체 이중화
2. **Seed YAML을 우리도 쓸 것인가** — 채택 시 `/plan` 결과가 `harness-seed.yaml`. 거부 시 CE의 `plan.md`
3. **EventStore 없이 어떻게 루프 복원** — JSON append-only + session_id 인덱스로 충분한지
4. **3단 검증 중 Stage 3 Consensus 넣을 것인가** — 토큰 비용 vs 하네스 day2 "모델도 나누고" 원칙
5. **Evolve의 오실레이션 감지를 corrections에도 적용할 것인가** — 같은 "틀렸다" 3회 토글 시 사용자 확인 강제

---

## 8. 핵심 발견 3가지 (요약)

1. **ouroboros는 "검증/개선" 2축을 아키텍처로 강제한 유일한 레퍼런스** — Seed 불변 + `evaluation_principles` weight + 3단 파이프라인 + Evolve 수렴까지, Phase 1 clarified-spec.md의 "Generator vs Evaluator 분리 + 승격 게이트" 원칙을 전부 기술적으로 구현한 선례다.
2. **Ralph Loop 의사코드와 qa-judge JSON 스키마는 즉시 포팅 가능한 최소 단위 자산** — `skills/ralph/SKILL.md:50-99`의 non-blocking + level-based polling 패턴과 `src/ouroboros/agents/qa-judge.md`의 pass/revise/fail 판정 스키마를 조합하면, 우리 `/verify` → 자동 재시도 루프의 본문이 그대로 만들어진다.
3. **드리프트·정체·진동 감지가 컴파운딩 과적합(UU 리스크)의 기술적 해답** — `README.ko.md:249-257`의 stagnation/oscillation/repeated-feedback/hard-cap 4종 패턴 감지는, 우리 플러그인이 우려한 "개인화 컴파운딩 과적합"·"같은 corrections 3번 토글" 같은 오염을 차단하는 **검증된 수치 모델**이다. 단, 유저 크로스 프로젝트 학습·타 도구 오케스트레이션·한국어 UX는 **ouroboros가 채우지 않은 공백**이며 이 셋이 우리 플러그인의 진짜 차별점이 되어야 한다.

---

*작성: Phase 2 레퍼런스 리서치 — ouroboros 단독 분석 산출물*
*후속 연결: Phase 3 `/ce-brainstorm` 또는 `/ce-ideate` — 이 문서의 §4, §7을 인풋으로 6축 강제 방식 구체화*

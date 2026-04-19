# Phase 2 레퍼런스 리서치 — `compound-engineering-plugin`

> **분석 대상**: `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin`
> **중점**: 멀티 페르소나 · 오케스트레이션 · 검증 루프 · 컴파운딩 · 자동 메모리 통합
> **작성일**: 2026-04-19
> **분석자 관점**: 하네스(Harness) 6축 플러그인 설계를 위한 레퍼런스 포팅 검토

---

## 1. 디렉토리 구조

### 1.1 최상위 — 마켓플레이스 저장소 구조

```
compound-engineering-plugin/
├── .claude-plugin/
│   └── marketplace.json          # 마켓플레이스 카탈로그 (두 플러그인 호스팅)
├── .cursor-plugin/               # Cursor 호환 캐탈로그 (동일 구조)
├── .claude/
│   └── commands/triage-prs.md    # 자체 repo용 단일 커맨드
├── .github/                      # CI + release-please 자동화
│   ├── release-please-config.json
│   └── workflows/{ci,deploy-docs,release-pr,release-preview}.yml
├── AGENTS.md                     # 정식 repo 지시서 (379줄 규모)
├── CLAUDE.md                     # @AGENTS.md (호환성 shim 1줄)
├── README.md                     # 설치·사용 가이드
├── CHANGELOG.md                  # 35KB 릴리즈 히스토리
├── package.json / bun.lock       # Bun + TypeScript CLI
├── tsconfig.json
├── src/                          # Claude → OpenCode/Codex/Gemini 등 변환 CLI
├── tests/                        # 54개 converter/writer/CLI 테스트
├── docs/
│   ├── brainstorms/*.md          # 23개 요구사항 문서 (YYYY-MM-DD 규칙)
│   ├── plans/*.md                # 50+ 구현 계획 (YYYY-MM-DD-NNN 시퀀스)
│   ├── solutions/                # 카테고리별 학습 아카이브
│   └── specs/                    # 타겟 플랫폼 규격
└── plugins/
    ├── compound-engineering/     # 주력 플러그인 (이하 상세)
    └── coding-tutor/             # 보조 플러그인
```

**핵심 관찰**: 레포 자체가 compound engineering 방법론으로 자기 자신을 빌드한다. `docs/brainstorms/` → `docs/plans/` → `docs/solutions/` 흐름이 `/ce-brainstorm` → `/ce-plan` → `/ce-compound` 스킬 체인과 1:1 대응한다. 메타 일관성 강력.

### 1.2 `plugins/compound-engineering/` 구조

```
plugins/compound-engineering/
├── .claude-plugin/
│   └── plugin.json               # name="compound-engineering", version=2.68.1
├── .cursor-plugin/               # Cursor 동기화용 미러
├── AGENTS.md                     # 플러그인 개발자 지시서 (18KB, 상세 규칙)
├── CLAUDE.md                     # @AGENTS.md (1줄 shim)
├── README.md                     # 컴포넌트 카탈로그 (10KB)
├── CHANGELOG.md
├── LICENSE
├── skills/                       # 42개 스킬 디렉토리
│   ├── ce-brainstorm/
│   │   ├── SKILL.md              # YAML frontmatter + 실행 워크플로우
│   │   └── references/           # 디스크로 오프로드된 세부 문서
│   ├── ce-plan/
│   ├── ce-code-review/
│   │   └── references/{persona-catalog.md, subagent-template.md,
│   │                   diff-scope.md, findings-schema.json,
│   │                   review-output-template.md, ...}
│   ├── ce-work/
│   ├── ce-compound/
│   ├── ce-compound-refresh/
│   ├── ce-ideate/
│   ├── ce-optimize/
│   ├── ce-debug/
│   ├── ce-doc-review/
│   ├── ce-setup/                 # disable-model-invocation
│   ├── ce-polish-beta/
│   ├── lfg/                      # 완전 자율 파이프라인
│   └── ... (42개 총)
└── agents/                       # 50+ 서브에이전트 (카테고리 분리)
    ├── review/                   # 27개 코드/도메인 리뷰어
    ├── document-review/          # 7개 문서 리뷰 페르소나
    ├── research/                 # 9개 리서치 에이전트
    ├── design/                   # 3개 디자인 에이전트
    ├── workflow/                 # 2개 워크플로우 에이전트
    └── docs/                     # 1개 문서 에이전트
```

**핵심 관찰 (AGENTS.md에서 명시 인용)**:
- **훅(`hooks/`) 디렉토리 없음**: compound engineering은 훅으로 자동화하지 않고, 스킬 오케스트레이션으로 해결한다. 이는 `hoyeon`/`ouroboros`와 차별되는 명시적 선택.
- **커맨드 → 스킬 마이그레이션 (v2.39.0)**: 모든 구 `/command`는 `skills/<name>/SKILL.md`로 통합. "커맨드는 스킬의 한 표현형"이라는 철학.
- **서브디렉토리 격리 원칙**: "각 스킬 디렉토리는 self-contained 단위. SKILL.md는 자신의 디렉토리 트리 내 파일만 참조 가능." 크로스-스킬 참조 금지, 공유 파일은 복제.
- **카테고리 네임스페이스**: 에이전트 호출은 `<category>:ce-<agent-name>` 포맷(예: `review:ce-adversarial-reviewer`) 강제. 짧은 이름만 쓰면 런타임 해석 실패.

---

## 2. SKILL.md 프론트매터 패턴

### 2.1 표준 프론트매터 필드

두 가지 형태가 혼재:

```yaml
---
name: ce-brainstorm                          # 디렉토리명과 정확히 일치 (소문자·하이픈)
description: "Explore requirements ..."      # "무엇 + 언제" 2파트 설명
argument-hint: "[feature idea or problem]"   # 슬래시 명령 힌트
---
```

**설정 가능 옵션 (실제 사용 사례)**:

| 필드 | 값 사례 | 용도 |
|---|---|---|
| `name` | `ce-brainstorm`, `ce-plan` | 디렉토리명 일치 강제 |
| `description` | 긴 설명 + 트리거 구문 (인라인 `'let''s brainstorm'` 같은 이스케이프) | 자동 트리거 감지용 |
| `argument-hint` | `"[Plan doc path or description of work. Blank to auto use latest plan doc]"` | UI 노출용 |
| `disable-model-invocation` | `true` (ce-setup, ce-polish-beta) | 자동 트리거 방지 (사용자 직접 슬래시만) |

### 2.2 description 최적화 (트리거 키워드 패턴)

가장 정교한 예 — `ce-brainstorm`:

```yaml
description: 'Explore requirements and approaches through collaborative dialogue
before writing a right-sized requirements document and planning implementation.
Use for feature ideas, problem framing, when the user says ''let''s brainstorm'',
or when they want to think through options before deciding what to build.
Also use when a user describes a vague or ambitious feature request, asks ''what
should we build'', ''help me think through X'', presents a problem with multiple
valid solutions, or seems unsure about scope or direction — even if they don''t
explicitly ask to brainstorm.'
```

**패턴**:
1. **"What + When" 2파트**: 앞 문장은 기능, 뒤는 트리거 조건.
2. **구체 트리거 구문 나열**: `'let's brainstorm'`, `'what should we build'`, `'help me think through X'` 같은 실제 유저 발화 포함.
3. **음성 다양성**: 명시 발화 + 암묵 상황(`seems unsure about scope`) 둘 다 커버.
4. **YAML 안전성**: 어포스트로피는 `'''`로 이중 이스케이프 (AGENTS.md에서 명시: "콜론 포함 시 반드시 quote — js-yaml strict parser 크래시 방지. `bun test tests/frontmatter.test.ts` 검증").

### 2.3 다국어(한국어) 지원 여부

**결론: 한국어 지원 전무**.

- 모든 SKILL.md 프론트매터와 본문은 영어.
- description 내 한국어 트리거 구문 없음.
- 아키텍처는 "플랫폼의 blocking question tool (AskUserQuestion in Claude Code, request_user_input in Codex, ask_user in Gemini)"으로 플랫폼 추상화에만 투자. 언어 추상화는 없음.
- AGENTS.md 인용: "**Identifiers** (file names, agent names, command names): ASCII only -- converters and regex patterns depend on it. **Prose and skill content:** Unicode is fine." → 프론트매터는 ASCII 고정, 본문은 Unicode 허용이지만 실제 활용 없음.

**우리 플러그인 시사점**: `description` 필드에 한국어 + 영어 트리거 구문을 동시에 넣는 방식이 가능. 예:

```yaml
description: "계획 수립 · Create structured plans... 트리거: '계획 세워줘', 'plan this', '플랜 작성'..."
```

단, 한국어 트리거는 의미 분산을 최소화하도록 집중도 있게 설계 필요 (뒤 9.4절).

---

## 3. 핵심 워크플로우

### 3.1 최상위 파이프라인

README에서 명시:

```
Brainstorm -> Plan -> Work -> Review -> Compound -> Repeat
    ^
  Ideate (optional -- when you need ideas)
```

| 단계 | 스킬 | 역할 | 매칭 하네스 축 |
|---|---|---|---|
| 아이디어 발굴 | `/ce-ideate` | 발산 + 적대적 필터링 → 랭크된 ideation 아티팩트 | 계획 (상위) |
| 브레인스토밍 | `/ce-brainstorm` | WHAT 정의, 요구사항 문서 | 계획 + 맥락 |
| 계획 | `/ce-plan` | HOW 정의, 구현 단위 + 테스트 시나리오 | 계획 |
| 실행 | `/ce-work` | 서브에이전트 + worktree + 인크리멘털 커밋 | 실행 |
| 리뷰 | `/ce-code-review` | 17 페르소나 병렬 + 머지/dedup | 검증 |
| 컴파운딩 | `/ce-compound` | `docs/solutions/`로 학습 저장 | 개선 |
| 검증 루프 | `/ce-optimize` | metric-driven 반복 실험 + LLM-as-judge | 검증 + 개선 |
| 문서 리뷰 | `/ce-doc-review` | 7 페르소나 병렬, requirements/plan 검토 | 검증 |
| 디버그 | `/ce-debug` | root-cause → 예측 → 테스트 | 실행 + 검증 |

### 3.2 멀티 페르소나 오케스트레이션 설계 패턴

#### (A) Always-on + Conditional 이중 구조 (ce-code-review)

`skills/ce-code-review/SKILL.md`의 "Reviewers" 섹션:

- **Always-on (매 리뷰 6개)**: correctness, testing, maintainability, project-standards, agent-native-reviewer, learnings-researcher.
- **Cross-cutting conditional (diff 감지로 조건부)**: security, performance, api-contract, data-migrations, reliability, adversarial, cli-readiness, previous-comments.
- **Stack-specific conditional**: dhh-rails, kieran-rails, kieran-python, kieran-typescript, julik-frontend-races.

선택 로직 인용:
> "The model naturally right-sizes: a small config change triggers 0 conditionals = 6 reviewers. A Rails auth feature might trigger security + reliability + kieran-rails + dhh-rails = 10 reviewers."

**포인트**: 키워드 매칭이 아닌 **agent judgment**. SKILL.md는 "diff가 auth/routes/user-input을 건드리면 security-reviewer를 트리거"라고 서술적 가이드만 주고, LLM이 판단.

#### (B) 4단계 머지/dedup 파이프라인 (Stage 5)

```
1. Validate       # schema 검증, malformed 드롭
2. Confidence gate # < 0.60 억제 (단 P0은 0.50+ 생존)
3. Deduplicate    # fingerprint = normalize(file) + line_bucket(±3) + normalize(title)
4. Cross-reviewer agreement # 2+ 리뷰어 합치 시 confidence +0.10
5. Normalize routing # 보수적 경로 우선 (safe_auto → gated_auto → manual)
```

**인사이트**: 여러 AI 관점을 수집하는 것만으로는 부족. 머지·dedup·신뢰도 보정 파이프라인이 reliability를 만든다. 대부분의 레퍼런스(team-attention agent-council 포함)는 합성에 약한데, ce-code-review는 명시적으로 해결.

#### (C) 동적 페르소나 선택 (ce-doc-review)

`skills/ce-doc-review/SKILL.md` Phase 1:

- **Always-on**: coherence-reviewer, feasibility-reviewer.
- **Conditional (문서 내용 기반 판단)**: product-lens, design-lens, security-lens, scope-guardian, adversarial.

각 조건부 페르소나는 활성화 기준을 SKILL.md에 명시된 signal table로 판정. 예: security-lens는 "auth/authorization mentions, login flows, session management, API endpoints exposed to external clients, data handling, PII, payments..."가 있을 때.

#### (D) 오케스트레이터 vs 서브에이전트 Model Tiering (ce-code-review Stage 4)

> "Persona sub-agents do focused, scoped work and should use a fast mid-tier model... The orchestrator itself stays on the default (most capable) model."
> "In Claude Code, pass `model: \"sonnet\"` in the Agent tool call."

**포인트**: **비용/속도/품질 관점 분리** — 오케스트레이터는 최상급 (추론 집약), 서브에이전트는 mid-tier (초점형 작업). 이는 하네스의 "Generator vs Evaluator 관점 분리" 원칙의 구체적 구현.

### 3.3 검증 루프 — ce-optimize의 "Persistence Discipline"

`ce-optimize`는 metric-driven 자율 최적화 루프의 본격 구현. 핵심 설계 (SKILL.md 인용):

#### (A) 디스크가 단일 진실 (Single Source of Truth)

> "CRITICAL: The experiment log on disk is the single source of truth. The conversation context is NOT durable storage. Results that exist only in the conversation WILL be lost."

6개 Mandatory Checkpoints (CP-0 ~ CP-5) 강제:

| CP | 파일 | Phase |
|---|---|---|
| CP-0 | `spec.yaml` | Phase 0 |
| CP-1 | `experiment-log.yaml` (초기 + baseline) | Phase 1 |
| CP-2 | `hypothesis_backlog` 섹션 | Phase 2 |
| CP-3 | `experiment-log.yaml` append (실험마다 즉시) | Phase 3.3 |
| CP-4 | `outcomes` + `best` + `strategy-digest.md` | Phase 3.5 |
| CP-5 | 최종 상태 | Phase 4 |

#### (B) 3-tier 검증 접근

1. **Degenerate gates** (hard, cheap): "solo_pct <= 0.95" 같은 명백히 깨진 결과 탐지, 판정 저렴.
2. **LLM-as-judge** (본 목표): stratified sampling (top_by_size, mid_range, small_clusters, singleton_sample) + 1-5 rubric 스코어링.
3. **Diagnostics** (logged, not gated): 분포 통계, WHY 분석용.

#### (C) Ralph Loop 패턴 + worktree 격리

- `optimize/<spec-name>` 브랜치에서 실험마다 `optimize-exp/<spec-name>/exp-<NNN>` worktree 생성.
- 유지(keep) → 브랜치 머지 + 승자 diff를 실제 커밋으로.
- 실패(revert) → worktree 정리.
- stopping 기준: target_reached, max_iterations, max_hours, judge budget exhausted, plateau, empty backlog, user interrupt.

**하네스 매칭**: 강의의 "완료 기준 합의 → AI 작업 → 기준 충족? → (NO) 재작업" Ralph Loop의 본격 구현체.

### 3.4 컴파운딩 — ce-compound의 지식 누적

#### (A) 병렬 리서치 + 순차 조립 구조

```
Phase 0.5: Auto Memory Scan       # Claude의 auto-memory 블록 읽기 (Claude Code only)
Phase 1 (parallel):
  - Context Analyzer              # conversation → YAML frontmatter skeleton
  - Solution Extractor            # conversation → 트랙별 섹션(bug vs knowledge)
  - Related Docs Finder           # docs/solutions/ grep, 오버랩 스코어
  - Session Historian (opt-in)    # 타 세션 이력 조회
Phase 2 (sequential):
  - 오버랩 결정 (High → 기존 doc 업데이트, Moderate/Low → 신규)
  - Write docs/solutions/<category>/<filename>.md
Phase 2.5: Selective Refresh Check # ce-compound-refresh 연계 판단
Discoverability Check             # AGENTS.md가 docs/solutions/ 안내하는지
Phase 3 (optional parallel):      # 도메인 전문 리뷰어로 문서 품질 향상
```

#### (B) Bug track vs Knowledge track

schema.yaml에서 분기:
- **Bug track 섹션**: Problem, Symptoms, What Didn't Work, Solution, Why This Works, Prevention.
- **Knowledge track 섹션**: Context, Guidance, Why This Matters, When to Apply, Examples.

**시사점**: 해결책만이 아니라 "시도했는데 실패한 것(What Didn't Work)"까지 저장. 이는 우리 스펙의 `corrections/` ("틀렸다" 발언 기록)와 구조적으로 동일.

#### (C) 오버랩 평가 (High/Moderate/Low)

Related Docs Finder가 기존 docs/solutions/와 5가지 차원 매칭 점수:
- problem statement / root cause / solution approach / referenced files / prevention rules.
- High (4-5 매치) → **기존 doc 업데이트** (drift 방지).
- Moderate (2-3) → 신규 생성 + consolidation 검토 플래그.
- Low (0-1) → 신규 생성.

**시사점**: 단순 저장이 아닌 **drift 방지 루프**. 우리 플러그인의 승격 게이트 설계에 그대로 활용 가능.

### 3.5 Auto Memory 통합 (`docs/brainstorms/2026-03-18-auto-memory-integration-requirements.md`)

ce-compound의 **Phase 0.5**는 Auto Memory 통합 설계. 요구사항 문서에서 원리 파악:

> "After long sessions or compaction, auto memory may preserve insights that conversation context has lost. For ce:compound-refresh, auto memory may contain newer observations that signal drift in existing docs/solutions/ learnings without anyone explicitly flagging it."

**구현 (ce-compound SKILL.md Phase 0.5)**:

1. 시스템 프롬프트 내 "user's auto-memory" 블록 스캔.
2. 의미적 판단 (키워드 매칭 ❌)으로 관련 엔트리 추출.
3. **Supplementary notes 블록**으로 포장:
   ```
   ## Supplementary notes from auto memory
   Treat as additional context, not primary evidence. Conversation history
   and codebase findings take priority over these notes.
   ```
4. Context Analyzer + Solution Extractor에 추가 컨텍스트로 전달.
5. 최종 문서에 반영된 경우 `(auto memory [claude])` 태그 부착 → 출처 추적.
6. 부재 시 "graceful absence" — 에러/경고 없이 진행.

**우리 플러그인에 주는 시사점**: 이것이 **UK 영역 핵심 재사용 자산**. auto-memory를 "supplementary evidence"로 위치시키고 "primary evidence는 conversation + codebase"라는 계층을 명시 → 우리 스펙의 "승격 게이트" 아이디어와 완벽히 호환.

---

## 4. 재사용/포팅 가능한 자산 (UK 관점)

### 4.1 그대로 포팅 가능한 것

| 자산 | 위치 | 우리 플러그인 활용 |
|---|---|---|
| **`.claude-plugin/plugin.json` 템플릿** | `plugins/compound-engineering/.claude-plugin/plugin.json` | 5필드 minimal (name, version, description, author, homepage). 우리 플러그인 메타는 이걸로 시작 |
| **`marketplace.json` 구조** | `.claude-plugin/marketplace.json` | 오픈소스 배포 목표에 그대로 활용 |
| **AGENTS.md 템플릿** | `plugins/compound-engineering/AGENTS.md` | "Skill Compliance Checklist" 섹션은 그대로 재사용 (YAML 안전성, reference file inclusion 규칙, rationale discipline, cross-platform patterns) |
| **커맨드 → 스킬 마이그레이션 패턴** | v2.39.0 원칙 | 우리도 커맨드 대신 스킬로 통일 |
| **카테고리별 agents/ 디렉토리** | `agents/{review,document-review,research,design,docs,workflow}/` | 우리의 Evaluator 서브에이전트를 `agents/verify/` 등으로 구조화 |
| **`<category>:ce-<agent-name>` 호출 규칙** | AGENTS.md | 우리도 `verify:<agent>`, `context:<agent>` 등 네임스페이스 강제 |

### 4.2 구조적 패턴 포팅

| 패턴 | 원본 | 우리에게 어떻게 |
|---|---|---|
| **Always-on + Conditional 페르소나** | ce-code-review Stage 3 | `/verify` 스킬에서 6축별 always-on + 도메인별 conditional (auth → security-lens 등) |
| **4단계 머지/dedup 파이프라인** | ce-code-review Stage 5 | Evaluator 관점이 여러 개일 때 합성 알고리즘 그대로 차용 (fingerprint, cross-reviewer agreement boost) |
| **Orchestrator / Subagent Model Tiering** | ce-code-review Stage 4 | 비용 절감 — Evaluator 서브에이전트는 mid-tier, 메인 대화는 최상급 |
| **Mandatory Disk Checkpoints (CP-0~CP-5)** | ce-optimize Persistence Discipline | `/orchestrate` 장기 실행 시 동일 패턴 적용. 세션 crash/compaction 내구성 필수 |
| **3-tier 검증 (degenerate gate → judge → diagnostic)** | ce-optimize | 우리 "결과 스코어링 → 실패 시 자체 루프"의 템플릿 |
| **Bug track vs Knowledge track** | ce-compound schema.yaml | 우리 `corrections/`(실패), `tacit/`(암묵지), `preferences/`(선호)와 매핑 |
| **5-dimension overlap scoring** | ce-compound Related Docs Finder | 승격 게이트 — 기존 메모리와 신규 후보 drift 판정 |
| **Discoverability Check** | ce-compound | AGENTS.md/CLAUDE.md가 `.claude/memory/`를 안내하는지 자동 점검 |
| **Auto Memory supplementary block** | ce-compound Phase 0.5 | "primary evidence vs supplementary" 계층 그대로 차용 |
| **Ralph Loop + worktree 격리** | ce-optimize Phase 3 | `/verify` 재시도 루프의 격리 구현 |

### 4.3 복사 포팅이 아닌 개념 차용

| 개념 | 원본 | 우리 적용 |
|---|---|---|
| **"Right-size the artifact"** | ce-brainstorm Core Principle 5 | Lightweight/Standard/Deep 3단계 — 6축 강제도 작업 크기에 맞게 |
| **Platform Question Tool Design Rules** | AGENTS.md Interactive Question Tool Design | 한국어 optionlabel도 동일 원칙 (self-contained, 4개 이하, 3인칭, distinguishing word front-loaded) |
| **Rationale Discipline** | AGENTS.md | "매 줄이 invocation마다 load — 런타임 행동 바꾸지 않으면 삭제" 원칙 |
| **Conditional/Late-Sequence Extraction** | AGENTS.md | 큰 skill은 `references/` 디렉토리로 오프로드, 백틱 path로만 참조 |

### 4.4 구체 활용 제안

**우리 플러그인 스킬 매핑** (clarified-spec의 `/brainstorm`, `/plan`, `/verify`, `/compound`, `/orchestrate` 기준):

1. **`/brainstorm`** = ce-brainstorm의 워크플로우 3-Phase 구조 포팅 + 한국어 대화 스타일 추가.
2. **`/plan`** = ce-plan 전체 포팅 (requirements trace, implementation units, test scenarios). 6축 체크를 `Phase 5.3 Confidence Check`에 끼워넣기.
3. **`/verify`** = **3가지 레퍼런스 조합** — ce-code-review(17 페르소나) + ce-doc-review(7 페르소나) + ce-optimize(metric loop). 적응형으로 6축별 persona 선택.
4. **`/compound`** = ce-compound 거의 그대로 + 우리의 `MEMORY.md`/`tacit/corrections/preferences` 포맷으로 출력 경로 재매핑. Auto-memory Phase 0.5도 포팅.
5. **`/orchestrate`** = `/lfg` 스킬 (자율 파이프라인)의 오케스트레이션 패턴 참조. Checkpoint 기반 disk-first 설계 차용.

---

## 5. 6축 매핑 매트릭스

| 6축 | ce-* 기능 | 직접 대응 여부 | 주 증거 |
|---|---|---|---|
| **구조 (Scaffolding)** | `ce-setup`, AGENTS.md 지시 구조, 42 skill + 50 agent 카테고리화 | 부분 — 구조는 개별 축이 아닌 "어떻게 배치할지"의 교훈으로 녹아있음 | plugin AGENTS.md "Directory Structure" + Skill Compliance Checklist |
| **맥락 (Context)** | `ce-sessions` (프리어 세션 탐색), `ce-slack-research`, ce-compound Phase 0.5 Auto Memory, docs/solutions/ 지식 아카이브 | 강함 — 계층화된 맥락 (auto-memory → conversation → codebase → external) | ce-compound Phase 0.5, learnings-researcher 의 grep-first 전략 |
| **계획 (Planning)** | `/ce-ideate`, `/ce-brainstorm`, `/ce-plan` 3단 체인 | 매우 강함 — WHAT/WHY/HOW 명시 분리 | README "Brainstorm -> Plan -> Work" |
| **실행 (Execution)** | `/ce-work` (serial/parallel subagent + worktree + incremental commit), `/lfg` 자율 파이프라인 | 강함 — 3가지 실행 전략 (inline/serial/parallel) 명시적 선택 | ce-work Phase 1 Step 4 "Choose Execution Strategy" |
| **검증 (Verification)** | `/ce-code-review` (17 페르소나 + merge/dedup), `/ce-doc-review` (7 페르소나), `/ce-optimize` (degenerate gate + judge + diagnostic), `/ce-debug` (causal chain gate) | 매우 강함 — 계층화된 gate 철학 | ce-code-review Stage 5, ce-optimize 3-tier |
| **개선 (Compound)** | `/ce-compound`, `/ce-compound-refresh`, discoverability check, overlap scoring | 매우 강함 — knowledge accumulation + drift detection 2단 | ce-compound Phase 2.5, Related Docs Finder 5-dim scoring |

**총평**: CE 플러그인은 6축 중 **계획·실행·검증·개선 4축이 매우 강함**. 구조·맥락은 명시적 "축"으로 인식되기보다 AGENTS.md 규율 + 스킬 compliance checklist로 분산. 우리가 하네스 6축을 **primary differentiator**로 강제하는 것은 CE 대비 진짜 차별점이 된다.

---

## 6. 차별점 매핑 (4가지 관점 평가)

### 6.1 기존 도구 오케스트레이션

**CE 플러그인**: **독립형**.
- 자체적으로 완결된 42 스킬 + 50 에이전트 생태계.
- Slack/Proof/Codex 같은 외부는 스킬에 편입 (`ce-slack-research`, `ce-proof`).
- 다른 플러그인과의 오케스트레이션 메커니즘은 없음 — 오히려 "cross-skill 참조 금지" 정책.
- 한 가지 예외: `coding-tutor`가 같은 repo에 있지만 완전 분리된 plugin.

**우리 플러그인 시사점**:
- CE의 독립형을 따라가면 우리도 "자체 완결" 형태가 됨.
- 그러나 우리 스펙은 **superpower + CE + hoyeon + ouroboros + team-attention 조합 상위 레이어**를 지향.
- → 차별점 확보: CE가 못 하는 "플러그인 간 오케스트레이션" 공간이 있음. `/orchestrate`가 여러 플러그인 스킬을 연쇄 호출하는 조정자 역할을 해야 함.

### 6.2 하네스 6축 강제

**CE 플러그인**: **형식적 준수는 없음**.
- README "Brainstorm → Plan → Work → Review → Compound" 흐름이 6축과 **결과적으로 비슷하지만**, 의도된 매핑 아님.
- 6축이라는 메타 프레임워크 자체가 CE에는 없다.
- 스킬마다 6축 체크리스트 같은 강제 구조 없음.

**우리 플러그인 시사점**:
- 이것이 **Primary Differentiator**. CE는 절대 이 자리를 차지하지 않는다.
- 다만 CE의 "Confidence Check" (ce-plan Phase 5.3) 패턴처럼, 우리도 "6축 실효성 self-check"를 각 스킬 말미에 배치 가능.
- `/plan`이 생성한 결과물이 6축 각각에 대응되는지 `/verify` 서브에이전트가 채점.

### 6.3 개인화 컴파운딩

**CE 플러그인**: **팀 단위 컴파운딩은 강함, 개인화는 약함**.

강한 지점:
- `docs/solutions/` 구조화된 아카이브 (team-shared, structured).
- 5-dim overlap scoring → drift detection.
- ce-compound-refresh로 노후 학습 업데이트.
- **Auto Memory 통합 (ce-compound Phase 0.5)** — Claude Code의 `~/.claude/projects/<project>/memory/`를 supplementary evidence로 편입. 이것이 개인화에 가장 근접.

약한 지점:
- 유저별 "틀렸다" 피드백 별도 기록 메커니즘 없음.
- 선호도/작업 습관 추적 없음.
- auto-memory 자체는 Claude Code 기능에 의존 — CE는 소비자일 뿐 생산자가 아님.

**`ce-compound` 상세 평가**:
> "**Why \"compound\"?** Each documented solution compounds your team's knowledge. The first time you solve a problem takes research. Document it, and the next occurrence takes minutes. Knowledge compounds."

이는 **팀 지식** 컴파운딩 선언. 개인 레벨 학습은 Auto Memory에 위임 + CE가 그것을 supplementary로 편입.

**우리 플러그인 시사점**:
- 개인화 컴파운딩을 **primary**로 설계해야 차별.
- 구체: `.claude/memory/{MEMORY.md, tacit/, corrections/, preferences/}` 포맷이 개인 단위 (user-curated).
- Auto-memory의 "supplementary block" 패턴은 그대로 차용 — `corrections/`를 conversation과 codebase findings보다 낮은 우선순위로 배치.
- 승격 게이트 임계값을 개인별로 adaptive하게 — 같은 유저가 계속 "틀렸다"하는 패턴은 더 강하게 승격, 새 유저는 보수적 임계값.

### 6.4 한국어 대화 최적화

**CE 플러그인**: **전무**.
- 모든 description, 메시지, 프롬프트가 영어.
- 한국어 트리거 구문 없음.
- `AskUserQuestion` 옵션 라벨 설계 규칙(AGENTS.md Interactive Question Tool Design)은 영어 전제로 "front-loaded distinguishing word" 같은 영문 UX 원칙 기반.

**우리 플러그인 시사점**:
- CE가 정의한 question tool design 원칙은 언어 중립적 (self-contained, ≤4 options, 3rd person, distinguishing word front-loaded) → 한국어에도 그대로 적용 가능.
- description 필드에 한국어 트리거를 영어와 함께 배치.
- 예시 프롬프트 스타일: 한국어 존중어·경어체를 기본으로 하되, 코드/디렉토리/기술용어는 영어 유지 (AGENTS.md의 ASCII identifier 규칙과 호환).
- 오픈소스 배포를 생각하면 **이중 모드 (EN default + KO preset)** 설계가 안전.

---

## 7. 핵심 증거 인용 요약

### 7.1 파일 레벨 증거 (절대 경로)

| 클레임 | 증거 파일 |
|---|---|
| plugin.json minimal template | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/.claude-plugin/plugin.json` |
| 플러그인 개발자 지시서 + 스킬 compliance checklist | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/AGENTS.md` |
| 마켓플레이스 카탈로그 구조 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/.claude-plugin/marketplace.json` |
| 전체 워크플로우 다이어그램 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/README.md` (lines 26-48) |
| ce-brainstorm 3-Phase 워크플로우 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/skills/ce-brainstorm/SKILL.md` |
| ce-plan 5-Phase + Confidence Check | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/skills/ce-plan/SKILL.md` |
| ce-code-review 17 페르소나 + merge pipeline | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/skills/ce-code-review/SKILL.md` |
| ce-work 실행 전략 3가지 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/skills/ce-work/SKILL.md` |
| ce-compound 병렬 리서치 + Auto Memory Phase 0.5 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/skills/ce-compound/SKILL.md` |
| ce-optimize Persistence Discipline + 3-tier 검증 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/skills/ce-optimize/SKILL.md` |
| ce-doc-review 7 페르소나 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/skills/ce-doc-review/SKILL.md` |
| ce-ideate 6 frames 발산 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/skills/ce-ideate/SKILL.md` |
| Auto Memory 통합 요구사항 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/docs/brainstorms/2026-03-18-auto-memory-integration-requirements.md` |
| learnings-researcher grep-first 전략 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/agents/research/ce-learnings-researcher.agent.md` |
| coherence-reviewer 페르소나 구조 예 | `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/plugins/compound-engineering/agents/document-review/ce-coherence-reviewer.agent.md` |

### 7.2 원문 인용 (핵심 구문)

1. **"Each unit of engineering work should make subsequent units easier—not harder."** (README, ce-compound) — 플러그인 전체의 중심 철학.
2. **"The experiment log on disk is the single source of truth. The conversation context is NOT durable storage."** (ce-optimize) — 내구성 우선 설계.
3. **"Use `type: judge` when the quality of the output requires semantic understanding to evaluate... The optimization could produce degenerate solutions that look good on paper."** (ce-optimize) — 검증의 깊이 원칙.
4. **"Never use the bare agent name alone... Use the category-qualified namespace: `<category>:ce-<agent-name>`."** (AGENTS.md) — 네임스페이스 강제.
5. **"Every line in SKILL.md loads on every invocation. Include rationale only when it changes what the agent does at runtime."** (AGENTS.md Rationale Discipline) — 토큰 경제.
6. **"Memory notes take priority lower than conversation history and codebase findings."** (ce-compound Phase 0.5 supplementary block format) — 증거 계층.

---

## 8. 결론 & 우리 플러그인에 주는 액션 아이템

### 8.1 즉시 포팅 가능 (UK, 이번 주)

1. `.claude-plugin/plugin.json` minimal 5-field 포맷 그대로 복사.
2. AGENTS.md의 Skill Compliance Checklist 섹션 포팅 (YAML 안전성, reference file rule, rationale discipline).
3. `skills/<name>/SKILL.md + references/` 디렉토리 구조 컨벤션 채택.
4. 카테고리별 `agents/` 디렉토리 네임스페이스 (`verify:`, `context:`, `compound:` 등).

### 8.2 구조 차용 (KU, 2주차)

1. **Always-on + Conditional 페르소나 구조**: `/verify` 스킬에서 6축 always-on + 도메인 conditional.
2. **4단계 머지/dedup 파이프라인**: Evaluator 여러 관점 합성.
3. **Model tiering**: 오케스트레이터 = 최상급, 서브에이전트 = mid-tier.
4. **Bug vs Knowledge track**: `corrections/` vs `tacit/` 분기.

### 8.3 심화 활용 (KK 주력, 3-6주차)

1. **ce-optimize Persistence Discipline** 전체 포팅 → `/orchestrate` 장기 실행 내구성.
2. **ce-compound Phase 0.5 Auto Memory supplementary block 패턴** → 우리 `MEMORY.md` 읽기 로직 베이스.
3. **5-dimension overlap scoring** → 승격 게이트 스코어링 알고리즘.
4. **Discoverability Check** → 우리도 AGENTS.md/CLAUDE.md가 `.claude/memory/` 안내하는지 자동 점검.

### 8.4 의식적 차별화 (CE가 못 하는 것)

1. **6축 강제**: 각 스킬 말미에 "이 결과물이 6축 어디에 기여하는가" self-check 메타스킬.
2. **한국어 대화**: description 다국어, 옵션 라벨 한글 + Question Tool Design 원칙 준수.
3. **개인화 컴파운딩**: user-curated `.claude/memory/` + 승격 게이트 + `corrections/` 전용.
4. **플러그인 간 오케스트레이션**: CE가 다른 플러그인을 오케스트레이트하지 않으므로, `/orchestrate`가 그 공간을 차지.

---

*Phase 2 리서치 — compound-engineering-plugin 분석 완료. 다음 단계는 다른 레퍼런스(superpower, hoyeon, ouroboros, team-attention, oh-my-claudecode)와 교차 검증 후 Phase 3 브레인스토밍 (/ce-brainstorm) 진입.*

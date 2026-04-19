# Phase 2 리서치 — `references/plugins-for-claude-natives`

> Team Attention의 "Plugins for Claude Natives" 마켓플레이스 전체 구조 분석
> 핵심 초점: **clarify** (암묵지 해소) + **session-wrap** (컴파운딩) 심층 분석

- **작성일**: 2026-04-19
- **분석 대상**: `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives`
- **리포지토리**: https://github.com/team-attention/plugins-for-claude-natives
- **버전**: plugin root `0.1.0` / clarify `2.0.0` / session-wrap `1.0.0`
- **라이선스**: MIT

---

## 📦 개요 (TL;DR)

`plugins-for-claude-natives`는 **단일 리포 × 다중 서브플러그인 마켓플레이스** 구조다. 루트의 `.claude-plugin/marketplace.json`이 13개의 독립 플러그인을 등록하고, 각 플러그인은 자체 `.claude-plugin/plugin.json`을 가진다. 이 구조는 우리 하네스 플러그인에도 직접 적용 가능하다 — 6축(구조·맥락·계획·실행·검증·개선)을 6개 서브플러그인으로 쪼개고 루트 marketplace가 묶는 식.

하네스 요구사항(암묵지 해소 / 검증 루프 / 컴파운딩) 관점에서 이 리포가 가진 가장 중요한 자산은 **두 개**:

1. **`clarify`** (3개 스킬: `vague` + `unknown` + `metamedium`) — 이미 Phase 1 Clarify 단계에서 사용한 바로 그 스킬이며, **"hypothesis-as-options"** 원칙으로 AskUserQuestion을 강제하는 암묵지 해소 템플릿.
2. **`session-wrap`** (1개 command + 3개 skill + 5개 agent) — **2-Phase 멀티에이전트 파이프라인** (4개 병렬 분석 + 1개 duplicate validator). 하네스의 **"개선(Compound)"** 축이 요구하는 "세션 데이터 → rules/skills/docs 축적"의 구현체.

그 외 11개 플러그인(agent-council, dev, doubt, interactive-review, team-assemble 등)은 맥락 비교용.

---

## 1. 디렉토리 구조

### 1.1 루트 레벨

```
plugins-for-claude-natives/
├── .claude-plugin/
│   ├── plugin.json              # 루트 플러그인 메타 (0.1.0)
│   └── marketplace.json         # 13개 서브플러그인 등록
├── plugins/                     # 서브플러그인 13개
│   ├── agent-council/
│   ├── clarify/                 # ★ 심층 분석 대상
│   ├── dev/
│   ├── doubt/
│   ├── gmail/
│   ├── google-calendar/
│   ├── interactive-review/
│   ├── kakaotalk/
│   ├── podcast/
│   ├── say-summary/
│   ├── session-wrap/            # ★ 심층 분석 대상
│   ├── team-assemble/
│   └── youtube-digest/
├── assets/                      # gif/png 데모
├── LICENSE                      # MIT
├── README.md                    # 19,746 bytes (영문)
├── README.ko.md                 # 16,753 bytes (한국어 1차 번역)
└── .gitignore
```

**핵심 포인트**:
- `CLAUDE.md`, `AGENTS.md`, `.claude/rules/` **없음** — 이 리포 자체는 하네스 6축의 "구조/맥락"을 갖추지 않은 단순 플러그인 배포 리포.
- `README.ko.md`가 존재한다는 점이 한국어 UX 지원의 1차 증거 (단 13개 중 10개만 한국어 번역됨).
- 루트 `plugin.json`의 description도 한국어로 작성됨 ("Claude Code 네이티브 사용자를 위한 유틸리티 플러그인 모음").

### 1.2 `clarify` 플러그인 구조

```
plugins/clarify/
├── .claude-plugin/
│   └── plugin.json              # v2.0.0, 3-lens 구조
└── skills/
    ├── vague/
    │   └── SKILL.md             # 요구사항 명확화
    ├── unknown/
    │   ├── SKILL.md             # 4분면 블라인드 스팟 분석
    │   └── references/
    │       ├── question-design.md
    │       └── playbook-template.md
    └── metamedium/
        ├── SKILL.md             # 내용 vs 형식 레버리지
        └── references/
            └── alan-kay-quotes.md
```

- **agents/, hooks/, commands/ 없음** — 순수 skill 기반.
- 각 스킬은 서로 다른 "렌즈"를 제공하고, 서로를 교차 참조 (`For strategy blind spots use unknown`).
- `references/` 하위의 분리된 가이드 파일 = **Progressive Disclosure** 패턴 (SKILL.md에 "상세는 `references/xxx.md` 참조" 식으로 위임).

### 1.3 `session-wrap` 플러그인 구조

```
plugins/session-wrap/
├── .claude-plugin/
│   └── plugin.json              # v1.0.0
├── commands/
│   └── wrap.md                  # /wrap 슬래시 명령 진입점
├── agents/                      # 5개 에이전트
│   ├── doc-updater.md           # sonnet, blue — CLAUDE.md/context.md 갱신
│   ├── automation-scout.md      # sonnet, green — skill/command/agent 자동화 기회
│   ├── learning-extractor.md    # sonnet, magenta — TIL 추출
│   ├── followup-suggester.md    # sonnet, cyan — 후속 태스크 우선순위
│   └── duplicate-checker.md     # haiku, yellow — Phase 2 validator
├── skills/
│   ├── session-wrap/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── multi-agent-patterns.md
│   ├── history-insight/
│   │   ├── SKILL.md             # JSONL 세션 로그 분석
│   │   ├── scripts/
│   │   │   └── extract-session.sh
│   │   └── references/
│   │       └── session-file-format.md
│   └── session-analyzer/
│       ├── SKILL.md             # 사후 세션 검증 (SKILL.md 명세 대비)
│       ├── scripts/
│       │   ├── find-session-files.sh
│       │   ├── extract-subagent-calls.sh
│       │   └── extract-hook-events.sh
│       └── references/
│           ├── analysis-patterns.md
│           └── common-issues.md
└── README.md
```

**패턴 관찰**:
- **command(진입점) → skill(로직) → agent(실행자)** 의 3층 분리. `commands/wrap.md`는 얇은 래퍼이고 모든 로직은 `skills/session-wrap/SKILL.md`에 위임.
- **bash script + reference pair** = 데이터 처리(jq 파싱 등)는 shell에, 판단 규칙은 reference md에 분리.
- 5개 에이전트 모두 `tools: ["Read", "Glob", "Grep"]`으로 **읽기 전용** — 실제 파일 수정은 메인 세션이 수행 (안전 가드).

---

## 2. SKILL.md 프론트매터 패턴

### 2.1 공통 규칙 (5개 SKILL.md 전수조사)

| 스킬 | name | version | user-invocable | model/color |
|------|------|---------|---------------|-------------|
| vague | `vague` | 없음 | 없음 | 없음 |
| unknown | `unknown` | 없음 | 없음 | 없음 |
| metamedium | `metamedium` | 없음 | 없음 | 없음 |
| session-wrap | `session-wrap` | `2.0.0` | 없음 | 없음 |
| history-insight | `history-insight` | `1.1.0` | `true` | 없음 |
| session-analyzer | `session-analyzer` | `1.0.0` | `true` | 없음 |

→ 일관성이 완벽하진 않음 (version 기입 여부가 스킬별로 다름). **`user-invocable: true`**는 `history-insight`와 `session-analyzer`에만 있고 — 이건 "슬래시로 사용자가 직접 호출할 수 있는 스킬"이라는 의미로 읽힘. 반면 `vague`/`unknown`/`metamedium`은 description 내부에 `"/clarify"` 트리거가 박혀 있으니 사실상 사용자 호출 가능.

### 2.2 description 최적화 — "Trigger on ..." 패턴

모든 SKILL.md가 동일한 구조를 따른다:

```
This skill should be used when <조건>. Trigger on "<구문1>", "<구문2>", ...
```

**트리거 키워드 개수 (전수 카운트)**:
- `vague`: 영문 6개 + 한국어 5개 + `/clarify` = 12
- `unknown`: 영문 9개 + 한국어 5개 = 14
- `metamedium`: 영문 6개 + 한국어 5개 = 11
- `session-wrap`: 영문 7개 (한국어 거의 없음)
- `history-insight`: 영문 6개 (한국어 암시)
- `session-analyzer`: 영문 5개 + 한국어 2개 = 7

→ clarify 3-lens는 **다국어 트리거가 나란히** 배치되고, 맨 끝에 **"다른 스킬과의 구분"** 문장이 반드시 온다:
> "For strategy blind spots use **unknown**; for content-vs-form reframing use **metamedium**."

이 "교차 참조 문장"은 LLM이 스킬을 오인 트리거하는 걸 막는 프롬프트 엔지니어링 장치. 하네스의 6개 스킬(`/brainstorm`, `/plan`, `/verify`, `/compound`, `/orchestrate`, 추가)에도 동일 패턴이 필요.

### 2.3 다국어(한국어) 지원 — 증거 기반 점수

| 영역 | 증거 | 점수 |
|------|------|------|
| Description 내 한국어 트리거 | clarify 3-lens 모두 `"요구사항 명확히"`, `"뭘 원하는 건지"`, `"4분면 분석"`, `"내용 vs 형식"` 등 명시 | **강함** |
| SKILL.md 본문 한국어 | `history-insight/SKILL.md` 본문 일부 한국어 ("스코프 결정", "날짜 필터링") | **중간** |
| README.ko.md 존재 | 루트에 별도 한국어 README | **있음** |
| 누락 범위 | session-wrap 3개 스킬 및 5개 에이전트 본문은 전부 영문 | **편차 큼** |

**결론**: 한국어는 "description 트리거 + 일부 본문"에만 임베드. 본격적 이중모드는 아님. 하네스 플러그인은 이보다 더 철저히 "영문 디폴트 + 한국어 UX" 분리가 필요.

---

## 3. 핵심 워크플로우 분석

### 3.1 `clarify` — 3-lens 아키텍처

clarify 플러그인의 핵심 발견: **동일한 "hypothesis-as-options" 원칙을 3개 다른 축으로 적용**한 것.

| 스킬 | 레벨 | 축 | 출력 |
|------|------|-----|------|
| `vague` | 요구사항 (feature/bug) | 구체성 (vague → spec) | Before/After 표 + 선택적 파일 저장 |
| `unknown` | 전략/계획 | 인식론 (what I know vs don't) | 4분면 플레이북 `.md` |
| `metamedium` | 작업 방식 | 내용 vs 형식 | Content/Form 분석 부록 |

**공통 프로토콜**:
1. `AskUserQuestion` **강제** — 평문 질문 금지 (모든 SKILL.md가 대문자 "ALWAYS" 표기)
2. 옵션 = 테스트 가능한 가설 (`"Option = Hypothesis"` 원칙)
3. 3-4 옵션, 5-10 질문 상한 (`choice fatigue` 방지)
4. multiSelect 규칙: 원인/블로커는 복수, 우선순위/선택은 단일

**unknown 스킬의 3-Round depth pattern** (가장 정교):

| Round | 목적 | 질문 수 | 핵심 |
|-------|------|---------|------|
| R1 | 초안 4분면 검증 | 3-4 | **한 번의 AskUserQuestion에 batch** (max 4) |
| R2 | 약한 지점 드릴다운 | 2-3 | **R1 답변에서 동적으로 생성** (사전 준비 금지) |
| R3 | 실행 디테일 | 2-3 (optional) | R2가 충분하면 스킵 |

이 "Round N은 Round N-1의 답변에서 도출" 원칙이 **암묵지 해소**의 핵심 기법. 단순 체크리스트가 아닌 **분기형 심화 질문**이다.

**vague 스킬의 Ambiguity Categories** (암묵지 분류):

| Category | Hypotheses 예시 |
|----------|-----------------|
| Scope | All users / Admins only / Specific roles |
| Behavior | Fail silently / Show error / Auto-retry |
| Interface | REST API / GraphQL / CLI |
| Data | JSON / CSV / Both |
| Constraints | <100ms / <1s / No requirement |
| Priority | Must-have / Nice-to-have / Future |

→ 우리 하네스 플러그인의 **"corrections/" 메모리 포맷**에 그대로 대응 가능한 카테고리 체계.

### 3.2 `session-wrap` — 2-Phase 멀티에이전트

**실행 흐름** (`skills/session-wrap/SKILL.md` 기준):

```
Step 1: git status --short + git diff --stat HEAD~3

Step 2: Phase 1 (병렬) — 단일 메시지에 4개 Task() 호출
        ├─ doc-updater          → CLAUDE.md/context.md 갱신안
        ├─ automation-scout     → skill/command/agent 승격 후보
        ├─ learning-extractor   → TIL 포맷 (성공/실패/오해/절차 개선)
        └─ followup-suggester   → P0-P3 우선순위 태스크

Step 3: Phase 2 (순차) — duplicate-checker (haiku, Phase 1 결과 입력)
        ├─ Complete duplicate → Skip
        ├─ Partial duplicate  → Merge 제안
        └─ No duplicate       → Approve

Step 4: AskUserQuestion (multiSelect)
        ├─ Create commit (Recommended)
        ├─ Update CLAUDE.md
        ├─ Create automation
        └─ Skip

Step 5: 선택된 액션만 메인 세션이 실행
```

**핵심 설계 원칙** (`multi-agent-patterns.md`에 명시):

> "Agent architecture should reflect the dependency graph of the task" — Anthropic Multi-Agent Research

- **Phase 1은 독립 분석 (shared state 없음)** → 병렬 가능
- **Phase 2는 Phase 1 결과를 입력** → 반드시 순차
- **Validator는 haiku로 경량화** (Generator=sonnet, Evaluator=haiku)
- 5개 에이전트 모두 `Read`/`Glob`/`Grep`만 (쓰기 없음 = 안전 게이트)

이것이 요구사항의 **"승격 게이트"** 구현체. 자동 저장 없이:
- Phase 1 analyzers가 **제안만** 생성
- Phase 2 duplicate-checker가 **검증**
- Step 4에서 **사용자 명시 승인**
- Step 5에서만 **영구화**

→ 하네스 요구사항 "승격 게이트 + 세션 격리 + 유저 명시 승인" 3가지가 모두 이 파이프라인에 녹아 있다.

### 3.3 `history-insight` — 세션 로그 파싱

`~/.claude/projects/<encoded-cwd>/*.jsonl` 포맷을 직접 읽는 스킬. 중요 발견:

- **경로 인코딩 규칙**: `/Users/foo/project` → `-Users-foo-project` (슬래시 → 하이픈)
- **파일 수 기반 분기**: 1-3개는 직접 Read, 4+ 개는 `jq` 배치 파이프라인 (`/tmp/cc-cache/<analysis-name>/`)
- **초대용량 대응**: `split -l 2000`으로 쪼개고 병렬 `Task(opus, run_in_background=true)`
- **OS별 stat 분기**: macOS `stat -f`, Linux `stat -c`

→ 하네스 "자동 메모리 축적"에서 세션 로그를 원재료로 쓴다면 이 스크립트가 **직접 포팅 대상**. `scripts/extract-session.sh`는 thinking/tool_use 노이즈 제거용.

### 3.4 `session-analyzer` — Generator vs Evaluator의 구현

"사후 세션 검증" 스킬은 Anthropic 권장 Generator/Evaluator 분리를 구현한다:

- **Input**: `sessionId` + `targetSkill` (검증 기준 SKILL.md)
- **Phase 1**: 세션 파일 로케이션 (`~/.claude/projects/`, `~/.claude/debug/`)
- **Phase 2**: 타겟 SKILL.md에서 **예상 동작 체크리스트** 추출 (SubAgent/Hook/Artifact)
- **Phase 3-4**: 디버그 로그에서 **실제 실행 이벤트** 추출
- **Phase 5**: Expected vs Actual **비교 테이블** 생성 + 편차 플래그
- **Phase 6**: PASS/FAIL 리포트

**증거 기반 검증의 예** (Phase 5 테이블):
```
| Component   | Expected          | Actual                    | Status |
|-------------|-------------------|---------------------------|--------|
| Explore agent| 2 parallel calls | 2 calls at 09:39:26       | ✅     |
| reviewer    | Called after plan | 2 calls (REJECT→OKAY)     | ✅     |
| Stop hook   | Validates approval| Returned ok:true          | ✅     |
```

→ 이것이 하네스 요구사항 **"결과 스코어링 → 실패 시 자체 루프"** 의 골격이 된다. SKILL.md가 곧 검증 명세서가 되는 **"명세 = 검증 기준"** 패턴.

---

## 4. 재사용/포팅 가능한 자산 (UK 관점)

> Phase 1 스펙 문서의 UK(Unknown Known) = 10% 자산 활용 영역. 이 레퍼런스에서 건질 게 가장 많은 부분.

### 4.1 구조적으로 포팅 가능한 자산

| 자산 | 출처 | 하네스 적용 |
|------|------|-------------|
| **멀티 플러그인 마켓플레이스 구조** | 루트 `.claude-plugin/marketplace.json` | 6축별 서브플러그인으로 분리 후 루트 marketplace에 등록 |
| **command→skill→agent 3층 래핑** | `session-wrap/commands/wrap.md` | `/orchestrate` 슬래시는 얇은 래퍼, 로직은 SKILL.md, 분석은 에이전트 |
| **2-Phase 파이프라인** | `session-wrap/skills/session-wrap/SKILL.md` | `/compound` 스킬의 기본 구조 |
| **Read-only 에이전트 + 메인이 쓰기** | `session-wrap/agents/*.md` 모두 `tools: ["Read","Glob","Grep"]` | 승격 게이트의 안전 계층 |
| **bash script + reference md 페어** | `history-insight/scripts/*.sh` + `references/session-file-format.md` | 로그 파싱·메모리 축적 스크립트와 그 설명 분리 |
| **`user-invocable: true` 마커** | `history-insight`, `session-analyzer` | 사용자 직접 호출 스킬을 명시적으로 표기 |
| **hypothesis-as-options 원칙** | clarify 3-lens 공통 | `/brainstorm`과 `/plan` 스킬의 질문 규칙 |
| **Progressive Disclosure via references/** | clarify `unknown/references/{question-design,playbook-template}.md` | 긴 템플릿/가이드를 SKILL.md 본문 밖으로 빼기 |

### 4.2 프롬프트 패턴 포팅

**패턴 A — "Trigger on" description** (모든 SKILL.md에서 재사용):
```yaml
description: This skill should be used when <조건>.
  Trigger on "<구문1>", "<구문2>", "<한국어 구문1>", "<한국어 구문2>", "/<slash>".
  <한 줄 요약>. For <상황1> use <other-skill1>; for <상황2> use <other-skill2>.
```

**패턴 B — "ALWAYS use AskUserQuestion" 강제**:
> "**ALWAYS use the AskUserQuestion tool** — never ask clarifying questions in plain text."

→ 하네스 `/brainstorm`, `/plan`, `/verify` 모두에 복사 가능한 1줄.

**패턴 C — 3-4 options 규칙**:
> "3-4 options per question (never 5+). description explains implications, not just restates label. multiSelect for cause/blocker questions, single for priority/choice questions."

→ 암묵지 해소 UX의 마이크로 규칙.

### 4.3 코드·스크립트 직접 포팅 후보

1. `session-wrap/skills/history-insight/scripts/extract-session.sh` — JSONL 압축 (thinking/tool_use 제거) → 하네스 auto-memory의 **원재료 전처리**
2. `session-wrap/skills/session-analyzer/scripts/find-session-files.sh`, `extract-subagent-calls.sh`, `extract-hook-events.sh` — 세션 로그 파싱 → 하네스 **verify** 스킬의 증거 수집
3. `session-wrap/skills/session-wrap/references/multi-agent-patterns.md` — Anthropic 6 패턴(Prompt Chaining / Routing / Parallelization / Orchestrator-Worker / Evaluator-Optimizer / Autonomous Agent) 요약 → 하네스 `/orchestrate`의 패턴 선택 매트릭스

### 4.4 우리 하네스 플러그인에서 어떻게 재사용할지 — 구체 제안

#### (a) `clarify` 포팅 → `skills/brainstorm/`, `skills/plan/` 내부 서브 루틴

clarify 3-lens 자체를 **독립 진입점으로 다시 노출하지 말고**, 하네스 `/brainstorm`과 `/plan` 내부에서 서브 루틴처럼 호출:

```
/brainstorm
  → Phase A: vague 스타일 요구사항 해소 (hypothesis-as-options)
  → Phase B: unknown 스타일 4분면 (KK/KU/UK/UU 리소스 %)
  → Phase C: metamedium 스타일 content/form 포크
  → Output: 브레인스토밍 파일
```

이렇게 하면 하네스 6축의 **"맥락(Context)"** 축이 채워진다. clarify가 "암묵지 해소의 실질 도구"라는 점을 requirement.md의 "유저와의 대화를 통해 암묵지 해소" 요구와 직결.

#### (b) `session-wrap` 포팅 → `skills/compound/` 전체 뼈대

`session-wrap` 아키텍처를 **그대로 복사**하되 다음 3가지만 변경:

| 항목 | session-wrap 원형 | 하네스 적용 |
|------|------------------|-------------|
| 커밋 중심 | `/wrap [commit message]` 빠른 커밋 | 커밋은 부차, **메모리 축적**이 primary |
| 에이전트 구성 (4+1) | doc-updater / automation-scout / learning-extractor / followup-suggester / duplicate-checker | **tacit-extractor** / **correction-extractor** (유저 "틀렸다" 감지) / **pattern-detector** (3회 반복) / **preference-extractor** / duplicate-checker |
| 저장 경로 | CLAUDE.md / context.md / skills 직접 갱신 | `.claude/memory/` 하위 4개 타입 (`tacit/`, `corrections/`, `preferences/` + `MEMORY.md` 인덱스) |

**컴파운딩 트리거 3종** (Phase 1 명확화 스펙)이 이 구조에 자연스럽게 매핑:
- "3회 반복 감지" → `pattern-detector` 에이전트
- "틀렸다 발언 감지" → `correction-extractor` 에이전트  
- "/session-wrap" → `/compound` 슬래시 커맨드

#### (c) `session-analyzer` 포팅 → `skills/verify/` 백본

session-analyzer의 "Expected vs Actual" 비교 테이블 생성 로직을 **검증 루프(Ralph Loop)** 의 판정 엔진으로 재사용:
- **Generator**: 하네스 `/execute`가 산출한 결과물
- **Evaluator**: session-analyzer 방식으로 "명세(SKILL.md) 대비 실행 증거" 검증
- **Score**: PASS/FAIL + 편차 플래그 → 실패 시 재시도

이는 requirement.md "결과 검증 루프 — 결과에 대한 스코어링 → 실패 시 자체 루프"와 직결.

#### (d) 마켓플레이스 구조 포팅 → 6축 서브플러그인

plugins-for-claude-natives처럼 하네스를 **모노플러그인이 아닌 멀티플러그인 마켓플레이스**로 출시:

```
harness/
├── .claude-plugin/
│   ├── plugin.json              # harness root
│   └── marketplace.json         # 6축 + 통합 오케스트레이터 등록
└── plugins/
    ├── harness-scaffold/        # 구조
    ├── harness-context/         # 맥락 (clarify 포팅 내장)
    ├── harness-plan/            # 계획
    ├── harness-execute/         # 실행
    ├── harness-verify/          # 검증 (session-analyzer 포팅 내장)
    ├── harness-compound/        # 개선 (session-wrap 포팅 내장)
    └── harness-orchestrate/     # 통합 파이프라인
```

장점: 유저가 6축 중 일부만 골라 설치 가능 → 오픈소스 배포 시 진입 장벽 낮춤.
단점: 서브플러그인 간 의존성 관리 필요 (marketplace.json이 이를 기술하지 않음 — 이건 하네스 자체 해결 영역).

---

## 5. 6축 매핑 매트릭스

| 하네스 6축 | 이 레퍼런스의 대응 자산 | 매핑 강도 | 증거 |
|------------|--------------------------|-----------|------|
| **구조 (Scaffolding)** | 멀티플러그인 마켓플레이스, command/skill/agent 3층 분리, `user-invocable` 플래그 | **중** | 루트 `.claude-plugin/marketplace.json` (13개 서브 등록), session-wrap의 `commands/wrap.md` → `skills/session-wrap/SKILL.md` → `agents/*.md` 래핑 |
| **맥락 (Context)** | clarify 3-lens (vague/unknown/metamedium), `AskUserQuestion` 강제, hypothesis-as-options | **강** | `clarify/skills/vague/SKILL.md` "Hypotheses as Options" 섹션, `unknown`의 3-Round depth pattern, `metamedium`의 content/form 포크 |
| **계획 (Planning)** | clarify `unknown` 4분면 플레이북 (KK 60% / KU 25% / UK 10% / UU 5%), execution roadmap 템플릿 | **중-강** | `clarify/skills/unknown/references/playbook-template.md` (Week 1-2, Week 3-4, Month 2 주차별 로드맵) |
| **실행 (Execution)** | 2-Phase 멀티에이전트 파이프라인, 병렬 Task 호출, `multi-agent-patterns.md` | **중** | `session-wrap/skills/session-wrap/SKILL.md` Step 2 "Parallel Execution", Anthropic 6 composable patterns |
| **검증 (Verification)** | `session-analyzer` (Expected vs Actual 비교 테이블), `duplicate-checker` (Phase 2 validator, haiku로 경량화) | **강** | `session-analyzer/SKILL.md` Phase 5 비교 테이블, `duplicate-checker.md`의 Approved/Merge/Skip 분류 |
| **개선 (Compounding)** | `session-wrap` 전체, `learning-extractor` TIL 포맷, `automation-scout` (3회 반복 감지 ≒ "repetition frequency ≥ 2"), `history-insight` (세션 로그 → 패턴) | **매우 강** | `session-wrap/README.md` "Session wrap-up workflow with multi-agent analysis", `automation-scout.md` "Repetition (frequency ≥ 2)" 섹션 |

**총평**:
- **맥락 + 개선** 축에 이 레퍼런스의 자산이 압도적으로 집중돼 있다. Phase 1 명확화 스펙에서 "UK 자산 활용 10%"라고 본 이유가 증거로 확인됨.
- **구조 / 계획 / 실행** 축은 중간 — 일부 패턴만 차용 가능.
- **검증** 축은 `session-analyzer` 하나가 제대로 만들어져 있어서 강함. 다만 자체 피드백 루프(실패 → 재시도)는 없음. 이건 ouroboros 등 다른 레퍼런스에서 보강해야 함.

---

## 📊 차별점 매핑 (4가지 관점)

Phase 1 명확화 스펙의 4가지 차별점 축에 대한 이 레퍼런스의 기여도:

### 1. 기존 도구 오케스트레이션

- **평가**: **독립형** 중심. 다른 도구를 조합하는 상위 레이어가 아님. 각 플러그인은 자기 목적만 수행.
- **예외**: `dev` 플러그인의 `/tech-decision`은 내부에 `codebase-explorer + docs-researcher + dev-scan + agent-council` 4개 에이전트 병렬을 쓰므로 준-오케스트레이션. 이 패턴이 하네스 `/orchestrate`에 직접 모델.
- **한계**: 이 리포는 "다른 마켓플레이스/플러그인을 오케스트레이트하는" 레벨은 아님. 단일 리포 내부 에이전트 오케스트레이션만 있음.
- **하네스 적용**: `/orchestrate` 스킬이 외부 superpower·CE·ouroboros·hoyeon 플러그인을 호출하는 부분은 이 레퍼런스에 없는 설계 영역.

### 2. 하네스 6축 강제

- **평가**: **전혀 없음**. 이 리포는 6축을 의식하지 않고 만들어짐. CLAUDE.md도, rules/도, 아키텍처 가이드도 없음.
- **간접 기여**: clarify가 "맥락" 축의 90% 채워주고, session-wrap이 "개선" 축의 80% 채워줌. 나머지 4축(구조·계획·실행·검증)은 이 레퍼런스에서 **파편만** 구할 수 있음.
- **하네스 적용**: 6축을 plugin.json / SKILL.md / hooks 차원에서 강제하는 메커니즘은 **우리가 직접 만들어야 함**. 체크리스트식 확인이 아니라 "6축별 effect metric" (Phase 1 KU 영역)이 숙제.

### 3. 개인화 컴파운딩

- **평가**: **session-wrap이 구현체의 절반**. 나머지 절반은 우리가 채워야 함.
- **갖춰진 것**:
  - 세션 종료 시점 트리거 (`/wrap` command)
  - 5개 에이전트 병렬 분석 (doc / automation / learning / followup / duplicate)
  - 승격 게이트 (Phase 2 validator + Step 4 사용자 승인)
  - `history-insight`의 세션 로그 파싱 (`~/.claude/projects/`)
  - TIL 포맷 (learning-extractor의 Technical Discoveries / Successful Approaches / Failed Attempts / Debugging Insights)
- **빠진 것**:
  - **유저별** 축적 (플러그인 전체가 "세션별"이지 "유저별"이 아님)
  - **"틀렸다" 감지** (learning-extractor가 "Mistakes & Lessons" 섹션을 갖긴 하나, 유저 발언 기반 감지 로직은 없음)
  - **3회 반복 자동 감지** (automation-scout의 "frequency ≥ 2" 원칙이 있으나, 구체적 카운팅 로직은 에이전트 프롬프트 레벨)
  - **메모리 인덱스** (`MEMORY.md` 같은 포인터 파일 없음 — 각 세션이 독립적으로 CLAUDE.md 갱신만 제안)
- **하네스 적용**: session-wrap을 **뼈대로 쓰되**, 위 4개 빠진 조각을 추가 구현. 특히 `.claude/memory/{tacit,corrections,preferences}/` 구조는 우리 신규 설계.

### 4. 한국어 대화 최적화

- **평가**: **중간**. 트리거 레벨에서는 강하지만 본문/출력 레벨은 부족.
- **강점**:
  - clarify 3-lens description에 한국어 트리거 5-6개씩 (`"요구사항 명확히"`, `"4분면 분석"`, `"내용 vs 형식"` 등)
  - `history-insight` SKILL.md 본문 부분 한국어 (예: "스코프 결정", "날짜 필터링")
  - `README.ko.md` 존재
  - kakaotalk, podcast 플러그인은 한국어 네이티브 UX
- **약점**:
  - session-wrap 3개 skill + 5개 agent 본문 **전부 영문**
  - vague/unknown/metamedium SKILL.md 본문도 **전부 영문**
  - 출력 템플릿(playbook-template.md)이 영문 전제
  - 한국어/영어 전환 메커니즘 없음 (유저가 한국어로 질문해도 내부는 영문 프롬프트)
- **하네스 적용**: 영문 디폴트 + 한국어 프리셋 모드를 **독립된 토글**로 설계 필요. Phase 1 KU 실험 "한국어 vs 오픈소스 균형" 항목이 바로 이 부분.

---

## 🔑 핵심 발견 3가지 (요약)

1. **`session-wrap` = 우리 "개선(Compound)" 축의 직접 복제 템플릿**.
   - 2-Phase 멀티에이전트(4 분석자 병렬 + 1 validator 순차) 구조가 요구사항의 "승격 게이트 + 컴파운딩"을 그대로 구현. 에이전트 5개를 **tacit-extractor / correction-extractor / pattern-detector / preference-extractor / duplicate-checker** 로 이름만 바꿔도 80% 완성.

2. **`clarify` 3-lens = 요구사항의 "암묵지 해소" 전용 엔진**.
   - `AskUserQuestion` 강제 + hypothesis-as-options + 3-Round depth pattern + 6개 Ambiguity Category (Scope/Behavior/Interface/Data/Constraints/Priority) 체계는 그대로 `/brainstorm`과 `/plan`에 내장 가능. 이건 Phase 1에서 **이미 사용한 스킬이므로 검증 완료**.

3. **6축 강제 메커니즘은 이 레퍼런스에 없다 — 우리가 만들어야 한다**.
   - plugins-for-claude-natives는 훌륭한 **개별 도구 카탈로그**지만, 하네스 아키텍처(CLAUDE.md / rules/ / hooks / memory / compound loop)를 가이드하진 않음. 구조·계획·실행·검증 4축의 6축-강제 로직(체크리스트 이상, 실효성 판정)은 KU 실험 영역으로 남겨야 함. "체크리스트화"가 아닌 "6축별 effect metric" 설계는 하네스 플러그인의 **primary 차별점**이 될 수 있다.

---

## 📎 참고 파일 (절대 경로)

**핵심 심층 분석**:
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/.claude-plugin/marketplace.json`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/clarify/skills/vague/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/clarify/skills/unknown/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/clarify/skills/unknown/references/question-design.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/clarify/skills/unknown/references/playbook-template.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/clarify/skills/metamedium/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/skills/session-wrap/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/skills/session-wrap/references/multi-agent-patterns.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/skills/history-insight/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/skills/session-analyzer/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/commands/wrap.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/agents/doc-updater.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/agents/automation-scout.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/agents/learning-extractor.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/agents/followup-suggester.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/agents/duplicate-checker.md`

**맥락 참조**:
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/README.md`
- `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/README.ko.md`

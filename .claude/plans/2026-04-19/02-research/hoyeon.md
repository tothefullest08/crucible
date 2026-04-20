# Phase 2 레퍼런스 리서치 — `references/hoyeon`

> 하네스(Harness) Claude 플러그인 Phase 2 병렬 리서치 결과.
> 담당 레퍼런스: **`references/hoyeon`** (verify 에이전트 구조 참조)

- **작성일**: 2026-04-19
- **분석 대상 루트**: `/Users/ethan/Desktop/personal/harness/references/hoyeon`
- **상위 저장소**: [team-attention/hoyeon](https://github.com/team-attention/hoyeon) — `@team-attention/hoyeon-cli` 기반 Claude Code 플러그인
- **버전**: 1.6.0 (`.claude-plugin/plugin.json`)
- **한 줄 요약**: "의도 → 요구사항 → 설계도 → 실행" 4레이어 도출 체인을 강제하고, 각 레이어를 **독립 verify 에이전트**가 기계·에이전트·사람 3축으로 검증하는 대규모 하네스 플러그인.

---

## 1. 디렉토리 구조

### 1.1 최상위 구조 (증거: `ls -la references/hoyeon/`)

```
references/hoyeon/
├── .claude-plugin/
│   ├── plugin.json          # name: hoyeon, version: 1.6.0
│   └── marketplace.json     # team-attention-dev 마켓플레이스 등록
├── .claude/
│   ├── settings.json        # 프로젝트 레벨 훅 등록
│   └── skill-rules.json     # 스킬별 트리거 키워드 (다국어)
├── .github/workflows/       # ci.yml, publish.yml
├── agents/                  # 28개 .md 에이전트 정의
│   └── _shared/charter-preflight.md
├── cli/                     # @team-attention/hoyeon-cli npm 패키지
│   ├── src/commands/        # issue, learning, plan, req, session
│   ├── schemas/plan.schema.json
│   └── package.json
├── docs/architecture.md     # 파이프라인·훅·패턴 문서
├── hooks/hooks.json         # 플러그인 레벨 훅 등록
├── scripts/                 # 20+ 훅 스크립트 (shell)
├── skills/                  # 26개 스킬 디렉토리 (SKILL.md + templates/)
├── CLAUDE.md                # 프로젝트 가이드라인 (200 lines)
├── PLUGIN-README.md         # 스킬·에이전트·훅 요약
├── README.md / README.ko.md / README.zh.md / README.ja.md  # 4개 언어
├── VERIFICATION.md          # 4-Tier Testing Model (361 lines)
└── CONTRIBUTING.md
```

### 1.2 `.claude-plugin/plugin.json`

```json
{
  "name": "hoyeon",
  "version": "1.6.0",
  "description": "Development workflow automation plugin: specify → open → execute pipeline with parallel research agents, hook-based guards, and PR state management",
  "author": { "name": "team-attention" }
}
```

- **마켓플레이스 등록**: `.claude-plugin/marketplace.json`에 `team-attention-dev` 마켓플레이스로 등록 (source: `./`, category: `productivity`).
- 플러그인·CLI·README가 모두 **한 모노레포**에 있고 버전이 3파일 동기화 (`plugin.json` + `marketplace.json` + `cli/package.json`) — 릴리스 절차 CLAUDE.md 100~116행.

### 1.3 `skills/` 디렉토리 (총 26개, 증거: `ls skills/`)

```
analyze-oss/  blueprint/   browser-work/  bugfix/       check/
compound/     council/     deep-research/ dev-scan/     discuss/
execute/      google-search/ issue/       mirror/        qa/
ralph/        reference-seek/ rulph/      scaffold/     skill-session-analyzer/
specify/      stepback/    tech-decision/ tribunal/    ultrawork/
```

대부분 단일 `SKILL.md`이며, `compound/`·`execute/`·`qa/`·`specify/`·`skill-session-analyzer/` 등 일부는 `references/`·`templates/` 보조 폴더를 포함.

### 1.4 `agents/` 디렉토리 (총 28개)

verify·gap·extract·review 계열로 명확히 분류됨:

| 계열 | 에이전트 |
|------|----------|
| **verify 계열 (핵심)** | `verifier`, `verification-planner`, `verify-planner`, `qa-verifier`, `ralph-verifier`, `spec-coverage` |
| **gap/audit** | `gap-analyzer`, `gap-auditor` |
| **extract** | `business-extractor`, `interaction-extractor`, `tech-extractor`, `contract-deriver` |
| **review** | `code-reviewer`, `ux-reviewer`, `codex-risk-analyst`, `codex-strategist`, `tradeoff-analyzer`, `feasibility-checker`, `value-assessor` |
| **worker/orchestration** | `worker`, `taskgraph-planner`, `debugger`, `git-master`, `interviewer` |
| **탐색** | `browser-explorer`, `code-explorer`, `docs-researcher`, `external-researcher` |
| **공유** | `_shared/charter-preflight.md`, `_karpathy.md` |

### 1.5 `hooks/hooks.json` — 6개 훅 이벤트 × 20+ 스크립트

증거 `hooks/hooks.json`:

```
SessionStart    → cli-version-sync.sh, session-compact-hook.sh
UserPromptSubmit → ultrawork-init, skill-session-init, rv-detector
PreToolUse[Skill]       → skill-session-init, rulph-init
PreToolUse[Edit|Write]  → skill-session-guard, ralph-dod-guard
PostToolUse[Task|Skill] → validate-output
PostToolUse[Grep|Glob|WebFetch|Bash] → tool-output-truncator
PostToolUseFailure[Edit|Write] → edit-error-recovery
PostToolUseFailure[Read]       → large-file-recovery
PostToolUseFailure[*]          → tool-failure-tracker
Stop            → ultrawork-stop, skill-session-stop, rv-validator, rulph-stop, ralph-stop
SessionEnd      → skill-session-cleanup
```

- **이중 등록 규칙** (CLAUDE.md 88~92행): 훅 추가 시 `hooks/hooks.json`(플러그인) + `.claude/settings.json`(프로젝트) + `CLAUDE.md`(문서) **세 군데 모두 업데이트** 필수.
- 훅은 전부 `scripts/` 하위 shell 스크립트이며 `scripts/`는 `.claude/scripts/`로 심링크.

### 1.6 루트 레벨 주요 파일

| 파일 | 역할 |
|------|------|
| `CLAUDE.md` | `validate_prompt` 프론트매터 사용법, 훅 시스템 카탈로그, 릴리스 플로우, CLI 레퍼런스 |
| `VERIFICATION.md` | **4-Tier Testing Model** (Unit/Integration/E2E/Agent Sandbox), 2-axis 검증 분류 모델 |
| `docs/architecture.md` | specify→blueprint→execute 파이프라인 다이어그램, 훅 라이프사이클, 6가지 패턴 정리 |
| `PLUGIN-README.md` | 컴포넌트 요약 (Skills 26 · Agents 28 · Hooks) |
| `README.{md,ko,zh,ja}.md` | **4개 언어 README** (영어·한국어·중국어·일본어) |
| `.claude/skill-rules.json` | 스킬별 트리거 키워드 사전 (다국어 키워드 포함) |

---

## 2. SKILL.md 프론트매터 패턴

### 2.1 공통 필드

모든 `SKILL.md`는 YAML 프론트매터를 가지며 **최소 2개 필수 필드** + 선택 필드로 구성.

**필수**:
- `name`: 스킬 ID (디렉토리 이름과 동일)
- `description`: 파이프 `|` 멀티라인. **트리거 키워드를 인용부호로 잔뜩 나열**하는 패턴

**자주 보이는 선택 필드**:
- `allowed-tools`: 허용 도구 화이트리스트 (예: `Read`, `Grep`, `Agent`, `TeamCreate`, `SendMessage`, `TaskCreate`, …)
- `disallowed-tools`: 명시적 금지 (예: `interviewer`는 `Write/Edit/Bash/NotebookEdit` 금지 → "Socratic 질문만" 강제)
- `validate_prompt`: **자기 검증 규칙**. `PostToolUse[Task|Skill]` 훅이 이 텍스트를 Claude에게 다시 주입 → 스킬/에이전트 산출물이 규칙 충족하는지 즉시 재점검 (CLAUDE.md 34~44행).
- `color`, `model`(opus/sonnet/haiku), `permissionMode: bypassPermissions` 등.

### 2.2 description = 트리거 키워드 펌프

한국어·영어·중국어 키워드를 **description에 직접 박아 넣어** 활성화 가능성을 최대화. 예 (`skills/ralph/SKILL.md` 1~10행):

```yaml
description: |
  Iterative task completion loop with Definition of Done verification.
  ...
  "/ralph", "ralph loop", "ralph 루프", "반복 작업", "DoD 루프",
  "완료 검증 루프", "task loop", "keep going until done"
```

`skills/rulph/SKILL.md`:

```yaml
"/rulph", "rubric evaluate", "rubric score", "multi-model evaluate",
"score and improve", "evaluate and iterate", "grade this",
"루브릭 루프", "채점 루프", "자율 개선", "개선 루프", "루브릭 평가"
```

`skills/discuss/SKILL.md`:

```yaml
"/discuss", ... "요구사항 정리", "인터뷰", "딥 인터뷰",
"뭘 만들어야 할지 모르겠어",
Korean triggers: "같이 생각해보자", "이거 어떻게 생각해?", "문제 정의",
"이게 좋은 아이디어야?", "이거 맞아?", "요구사항이 불명확"
```

### 2.3 `validate_prompt` — 후행 검증 훅과 결합

증거 `CLAUDE.md` 27~44행 + `agents/verification-planner.md` 프론트매터:

```yaml
validate_prompt: |
  Must contain all 6 sections:
  1. Test Infrastructure (4-Tier) ...
  2. Machine-verifiable sub-requirements ...
  ...
```

- `PostToolUse[Task|Skill]` 훅 `validate-output.sh`가 이 프론트매터를 파싱해 **완료 직후 Claude에게 "검증 요청"을 자동 주입**.
- 에이전트/스킬 **자체가 명시한 산출물 계약**을 훅이 자동 강제. 자기모니터링 루프를 프론트매터 한 줄로 묶어버리는 강력한 패턴.

### 2.4 다국어 지원 — skill-rules.json

`.claude/skill-rules.json`은 스킬별 `keywords[]`를 별도로 유지하지만, 실제로는 `skill-rules.json`의 대부분 키워드는 영어. **한국어 트리거는 주로 `SKILL.md` description 본문에 직접 기재** — 두 소스가 부분적으로 중복. (예: `ralph` skill-rules.json에는 영어만, SKILL.md description에는 한국어 포함.)

### 2.5 한국어 지원 수준 평가

- **README**: `README.ko.md` 519행 분량으로 완역 수준 (영어 README와 동등).
- **스킬 트리거**: 상당수 스킬에 한국어 트리거 키워드 내장 (discuss/ralph/rulph/stepback/council/tribunal/compound 등 다수).
- **에이전트 프롬프트 본문**: 모두 **영어**로 작성 — CLAUDE.md "Pre-Release Checklist"가 명시 (104행: *"All content must be written in English (SKILL.md, agent .md, CLAUDE.md, README.md, commit messages, comments)"*).
- **결론**: **사용자 인터페이스·트리거는 한·영 병용 / 내부 에이전트 프롬프트는 영어 전용** 이중 구조. 오픈소스 배포 + 한국어 UX 공존 전략을 이미 실제로 구현한 레퍼런스.

---

## 3. 핵심 워크플로우

### 3.1 메인 파이프라인 — specify → blueprint → execute

증거 `docs/architecture.md` 파이프라인 다이어그램:

```
User Request
    │
    ▼
/specify ──requirements.md──▶ /blueprint ──plan.json + contracts.md──▶ /execute
(interview,                   (contract-first,                         (3-axis dispatch,
 GWT 도출)                     task graph, verify plan)                 verify gate)
                                                                             │
                                                          ┌──────────────────┼──────────────────┐
                                                          ▼                  ▼                  ▼
                                                       worker             worker             worker
                                                          │                  │                  │
                                                          └──── git-master ──┴──── Verify ──────┘
                                                                               (light/standard/thorough)
                                                                                     │
                                                                                     ▼
                                                                              Final Report
```

- **`/ultrawork`** = 위 파이프라인을 `Stop` 훅으로 단계 간 자동 이어붙이기.
- **4레이어 도출 체인** (`README.ko.md` 49~53행): `Goal → Decisions → Requirements → Sub-requirements → Tasks` — 태스크는 요구사항의 파생물이며, 요구사항이 바뀌면 태스크가 재도출됨.

### 3.2 verify 에이전트 구조 — 중점 분석

이 레퍼런스의 핵심 가치. **"Generator vs Evaluator 분리"**가 여러 레이어로 구현됨.

#### (1) `verify-planner` — 4-Gate 할당자 (`agents/verify-planner.md`)

- 입력: `requirements.md` + `journeys[]`
- 출력: 각 sub-req/journey에 **4-Gate 조합** 할당 (JSON)

| Gate | 이름 | 정의 | 예시 |
|------|------|------|------|
| **1** | `machine` | 모델 개입 없는 결정적 체크 (unit test, tsc, exit code, DOM 존재) | `npm test` pass, `localStorage["k"] === "v"` |
| **2** | `agent_semantic` | LLM이 코드/로그를 읽고 "의도 일치" 판단 | 구현된 함수가 명세 행동을 커버하는가 |
| **3** | `agent_e2e` | 샌드박스 런타임 관찰 (브라우저, computer-use, 실제 API) | Playwright 클릭 → 스크린샷 → LLM 시각 판단 |
| **4** | `human` | 사람만 가능한 판정 (UX 감성, retry rate, 미적 취향) | "재미있는가?", "NPS 조사" |

- **항상 Gate 1 + 2 포함** (비타협). Journey는 기본적으로 3도 포함.
- "키워드 매칭이 아닌 **의미 독해**"를 명시적으로 요구 (`Example 1~4` 참조).
- `ambiguities[]` 필드로 "사용자가 직접 결정해야 하는 것만" 에스컬레이트 (`user_impact: time|confidence|none` 중 `time`만 올림). Planner 내부 결정은 조용히 처리.

#### (2) `verification-planner` — 2-Axis × 4-Tier 전략 (`agents/verification-planner.md`)

Phase 2와 다른 별도 에이전트. `VERIFICATION.md` 4-Tier 모델에 따라:

- **2-Axis**: `verified_by: Auto|Agent|Manual` × `execution_env: host|sandbox`
- **4-Tier**: Unit / Integration / E2E / Agent Sandbox (BDD + persona agents)
- 재분류를 **공격적으로** 수행: 모든 Manual 항목에 "에이전트가 코드를 읽거나 명령을 실행하거나 브라우저를 쓰면 검증 가능한가?"를 묻고, 가능하면 Agent/Machine으로 내림. Manual은 최소화.
- 샌드박스 드리프트 감지: DB migration/envvar/docker-compose 변경 시 `seed.sql`, `.env.sandbox`, mock 응답 업데이트 필요성 자동 경고.

#### (3) `verifier` — 기계적 실행자 (`agents/verifier.md`)

> "You are an **independent Verifier**. You did NOT write the code you are verifying."

- 입력: `verify_plan[]` JSON (`sub_requirement`, `method: command|assertion|instruction`, `given/when/then`).
- `method: command` → Bash 실행 후 `exit_code` · `stdout_contains` · `stderr_empty` 체크.
- `method: assertion` → 소스 파일을 **독립 읽기** (Worker 주장 불신) + GWT 우선 검증.
- `method: instruction` → 사람 리뷰 필요 → `pending`.
- "판단·우회 없이 top-to-bottom 기계적으로" — 강한 규칙.
- 도구: 읽기 전용 (`Read/Grep/Glob/Bash/WebSearch/WebFetch`). CLI 기록만 예외.

#### (4) `ralph-verifier` — DoD 전용 분리 컨텍스트 검증 (`agents/ralph-verifier.md`)

> "You are an **independent verification agent** ... runs in a separate context to eliminate self-verification bias."

- `/ralph` 루프 전용. **새 컨텍스트**에서 실행 → 작업자 편향 제거.
- DoD `- [ ]` 항목 각각에 대해 실제 파일·명령·테스트를 **돌려보고** PASS/FAIL 판정.
- 출력 스키마: `{"results":[{"item":"...","verdict":"PASS|FAIL","evidence":"..."}]}`.
- `/ralph` SKILL의 지침: "**반드시 foreground에서 spawn**. `run_in_background=true`로 띄우면 메인이 멈춰 Stop hook이 터지며 루프가 끊김." (`skills/ralph/SKILL.md` 153~159행)

#### (5) `spec-coverage` — Gate-2 GWT 증거 인용 리뷰어 (`agents/spec-coverage.md`)

- gate=2에서 `code-reviewer`와 **병렬 실행**. 둘 다 PASS여야 sub_req 통과.
- `code-reviewer`는 "코드가 옳은가", `spec-coverage`는 "코드가 스펙을 충족하는가" — **질문이 다름**.
- PASS 조건: `given/when/then` **각각**에 대해 `file_path:line` 인용 + **verbatim GWT 텍스트** 첨부. 패러프레이즈 금지, 키워드 매칭 불허.
- 하나의 sub_req_id만 보도록 스코프 강제.

#### (6) `qa-verifier` — 실행 기반 QA (`agents/qa-verifier.md`)

- GWT 기반으로 browser(chromux/CDP) / cli(tmux) / desktop(MCP computer-use) / shell(Bash) 중 자동 분류 후 실행.
- 증거 디렉토리 `.qa-reports/verify-evidence/{sub_req_id}.{png|txt}`에 스크린샷·캡처 저장.
- **Spec drift 검사**: 스펙에 없는 구현(SPEC_DRIFT)과 스펙에 있는데 구현이 없는 항목(MISSING) 모두 탐지.
- 수정은 절대 하지 않음 — 보고 전용.

#### (7) `rulph` — 루브릭 다중 모델 자율 개선 (`skills/rulph/SKILL.md`)

루브릭 기반 자기개선 루프:

1. **Phase 1** — 사용자와 3단계 대화로 루브릭 구축 (criteria → 체크리스트 sub-items → threshold + **per-criterion floor**).
2. **Phase 2** — **Codex + Gemini + Claude 3개 모델 병렬 평가** (foreground Agent `run_in_background=true` 3개를 **한 메시지**로 발사). AVAILABLE/SKIPPED/DEGRADED 상태 관리.
3. **Phase 3** — 자율 개선 루프: 가장 낮은 기준(floor 위반 우선) → `worker` agent에게 "그 기준만 집중 개선" 지시 → 재평가. max_rounds=5 circuit breaker.
4. **Phase 4** — PASS (threshold ∧ 모든 기준 ≥ floor) 또는 회로차단 시 리포트.

"점수 격리" 규칙 — 재평가 시 **이전 점수/개선 이력은 평가자에게 전달 금지**, 현재 아티팩트만. 점수 편향 방지 장치.

### 3.3 핵심 디자인 패턴 (architecture.md "Patterns" 섹션 발췌)

| 패턴 | 설명 |
|------|------|
| **Requirements-Driven Development** | 모든 구현은 `requirements.md`(GWT 포맷)를 거침. plan.json = 기계 상태, contracts.md = 인터페이스 계약. |
| **3-Axis Configuration (Execute)** | `dispatch: direct/agent/team` × `work: worktree/branch/no-commit` × `verify: light/standard/thorough` — 9조합 설정 가능. |
| **Hook-Guarded Writes** | `skill-session-guard.sh`가 Edit/Write를 가로챔. /specify에서는 코드 쓰기 금지(계획만), /execute에서는 orchestrator 직접 쓰기 금지(worker에게 위임 강제). **계획자·오케스트레이터·구현자 관심사 분리를 훅으로 강제**. |
| **Contract-First Planning** | blueprint가 코드 작성 전 `contracts.md` 생성. worker는 contract 경로·ID만 받고 inlined 내용 받지 않음 → 관심사 분리. |
| **DAG-Based Parallel Execution** | `plan.json.tasks[].depends_on`으로 DAG 구성. 독립 task 병렬 + agent 모드에선 모듈별 그룹 라운드 커밋. |
| **Stop Hook Re-injection (Ralph Pattern)** | Stop 훅이 DoD 미충족 시 원 프롬프트를 **다시 주입**하며 종료 차단. Circuit breaker max_iter로 무한 루프 방지. |
| **Validate-on-Complete** | `PostToolUse[Task|Skill]` 훅이 `validate_prompt` 프론트매터를 리마인더로 출력 → Orchestrator가 즉시 자체 검증. |
| **Charter Preflight** | 모든 에이전트 첫 출력에 `CHARTER_CHECK` 5줄 블록 (Clarity/Domain/Must NOT do/Success criteria/Assumptions). 스코프 드리프트 사전 차단. |

### 3.4 council — Agent Team 동료 간 토론 (`skills/council/SKILL.md`)

하네스 6축 중 "검증"과 "계획"에 걸쳐 있는 하이브리드 스킬:

- **TeamCreate**로 2~4명의 **동적 패널리스트**(역할 고정 아님) + **step-back judge** 팀메이트 + Codex/dev-scan 배경 agent를 **한 메시지에서 병렬 소환**.
- `SendMessage`로 패널리스트 간 **P2P 토론** — 하네스 Day2가 말한 "Team Mode"의 실제 구현 사례.
- Step-back judge가 매 라운드 후 CONVERGED/PARTIAL/FULL 판정 → 부족하면 재토론 라운드 (max 3).
- "Tribunal(고정 3역할)"의 확장판: "Dynamic 3 roles + External LLM + Community sentiment + Multi-round debate + In-loop judge".

### 3.5 compounding — 학습 누적 (`skills/compound/SKILL.md` + README.ko.md 92~120행)

- `/compound`: PR 본문 + `context/learnings.json` + `context/decisions.md` + `context/issues.json` + PR 코멘트/리뷰를 **병렬 수집** → 분류 → `docs/learnings/{YYYY-MM-DD}-{title}.md`로 구조화 저장.
- CLI 명령: `hoyeon-cli learning --task T1 --stdin <spec_dir> << 'EOF' {"problem":"…","cause":"…","rule":"…","tags":[…]} EOF`
- **크로스-스펙 컴파운딩** (README.ko.md): `/specify` 시작 시 **BM25 검색**으로 과거 `learnings.json`을 조회 → 유사 이슈를 **미리 요구사항에 반영**. 예: "발견: todo-app 스펙에서 localStorage 용량 이슈. → R5: 용량 가드 요구사항 자동 추가".
- "매 세션을 백지에서 시작하지 않는다. 10번째 프로젝트는 첫 번째보다 의미 있게 낫다."

### 3.6 인터뷰·Gap 체계

- `interviewer`: **Socratic 전담**. Write/Edit/Bash 금지, 모든 응답은 질문으로 끝나야 함. 6개 Probe type(Clarifying/Challenging/Consequential/Perspective/Meta/Ontological)로 분류.
- `gap-analyzer`: 플랜 생성 **전** 실행. Missing Requirements / AI Pitfalls / Changeability / Must NOT Do / Recommended Questions 5섹션. "Metis from oh-my-opencode에서 영감" 명시.
- `gap-auditor`: 인터뷰 Q&A 로그를 taxonomy (BUSINESS/INTERACTION/TECH 각 6노드)에 대해 COVERED/AMBIGUOUS/MISSING 분류. Coverage < 80% 또는 AMBIGUOUS 있으면 CONTINUE 판정.
- **Depth calibration**: `deep/standard/light/skip` 레벨별로 질문 엄격도 차등. "토이 프로젝트에 SHA-256 강요하지 않되 프로덕션은 엄격히" — 스코프 적응형.
- **Risk modifier override**: `sensitive-data` → SECURITY·DATA 자동 `deep` 승격. 콘텍스트가 조정을 뒤집을 수 있음.

---

## 4. 재사용/포팅 가능한 자산 (UK 관점)

> UK = Unknown-Known. "이미 있는데 덜 활용 중인" 자산 → 우리 하네스 플러그인에 직접 포팅 가능한 부분.

### 4.1 그대로 포팅 가능 (구조·템플릿)

| 자산 | 소스 | 우리 플러그인 활용 |
|------|------|-------------------|
| **`.claude-plugin/plugin.json` + `marketplace.json` 짝** | `.claude-plugin/` | `/Users/ethan/Desktop/personal/harness/.claude-plugin/`에 동일 구조 채택 |
| **훅 3중 등록 규약** (`hooks/hooks.json` + `.claude/settings.json` + CLAUDE.md 카탈로그) | CLAUDE.md 86~92행 | 우리 훅 추가 시 동일한 3파일 동기화 체크리스트를 CLAUDE.md에 명시 |
| **SKILL.md `validate_prompt` 프론트매터 + `PostToolUse` 훅** | CLAUDE.md 27~44행 + `scripts/validate-output.sh` | 우리 `/brainstorm` `/plan` `/verify` `/compound` 스킬마다 validate_prompt 필수화 — 스킬 자체가 검증 계약을 선언 |
| **Charter Preflight 5줄 블록** | `agents/_shared/charter-preflight.md` | 우리 서브에이전트(Evaluator 등) 첫 출력 규약으로 채택 → 스코프 드리프트 방지 |
| **3-Axis Configuration 개념** | `execute` 스킬 | 우리 `/orchestrate`에 `dispatch × work × verify` 조합 그대로 이식 |

### 4.2 패턴·흐름 차용 (로직·프롬프트)

| 자산 | 차용 방식 |
|------|-----------|
| **verify 4-Gate 할당 (`verify-planner`)** | 우리 `/verify` 스킬 내부 로직의 **기본 뼈대**. 6축 요구사항을 sub-req 수준까지 쪼개고 각각에 G1+G2 기본 + 필요시 G3/G4 부여. |
| **2-Axis × 4-Tier 분류 (`verification-planner`)** | 각 검증 항목을 `verified_by(Auto/Agent/Manual) × execution_env(host/sandbox)`로 라벨링 → 우리 "Evaluator 서브에이전트"가 반환할 리포트 스키마에 반영. |
| **독립 Verifier 컨텍스트 격리 (`ralph-verifier`)** | "작성한 에이전트가 자기 작업을 검증하지 않는다" 규칙을 우리 검증 루프의 **불변 규칙**으로 명시. Foreground spawn 규칙까지 포함. |
| **verbatim GWT 인용 (`spec-coverage`)** | 우리 "틀렸다" 기록 포맷: 유저 지적 원문을 그대로 `corrections/` 에 저장 (paraphrase 금지). 나중 검증 시 verbatim 매칭 강제. |
| **다중 모델 병렬 평가 (`rulph` Phase 2)** | Evaluator 편향(UU 리스크) 대응책. Codex + Gemini + Claude를 한 메시지 3-Agent `run_in_background=true`로 발사. 우리 암묵지 승격 게이트에 그대로 적용. |
| **Per-criterion floor + threshold (`rulph`)** | 승격 게이트 기준 설계에 직접 활용: "전체 점수 ≥ threshold **∧** 각 차원 ≥ floor". 한 차원 약점이 전체 점수로 가려지지 않게. |
| **BM25 크로스-스펙 검색 (`README.ko.md` 112~118)** | 우리 `MEMORY.md` 인덱스에서 `.claude/memory/tacit/` `corrections/` 조회 시 BM25 구현 포팅 가능 (cli/src/commands/learning.js 참고). |
| **Stop 훅 프롬프트 재주입 (Ralph Pattern)** | 우리 "결과 검증 루프" 요구사항의 **직접 레퍼런스**. Scoring 실패 시 원 프롬프트 + 실패 항목을 Stop 훅 JSON 페이로드로 재주입하고 circuit breaker로 무한루프 방지. |
| **Hook-Guarded Writes (skill-session-guard)** | 우리 `/brainstorm` 단계에서 "구현 코드 쓰기 금지" 강제를 훅으로 구현. 계획·오케스트레이션·구현 격리 원칙. |

### 4.3 한국어·오픈소스 공존 전략 (UU 리스크 대응)

- **영어 내부 + 한국어 트리거 이중 구조** 그대로 차용: 에이전트/스킬 프롬프트 본문은 영어 유지 (오픈소스 확산성), description·skill-rules에는 한국어 트리거 병기 (한국 UX).
- 다국어 README 4본 구조 (`README.{md,ko,zh,ja}.md`) — 릴리스 체크리스트에 동기화 규약(CLAUDE.md 105행) 포함. 우리도 최소 2본(ko/en) 동기화 체크리스트 포함.

### 4.4 CLI 설계 패턴 — `hoyeon-cli`

- 메모리·상태 CRUD를 **shell JSON 파일**로 저장하고 CLI가 래퍼 (`session set/get --sid`). 우리 `MEMORY.md` 인덱스 + 타입별 파일도 동일 패턴 가능.
- JSON heredoc + `--stdin` 컨벤션: zsh glob 확장 회피. shell 기반 CLI 설계 시 필수 규약.
- schema 검증 (`cli/schemas/plan.schema.json`) + 단조 done-lock(완료 태스크 재오픈 금지) — 자동화 안전장치.

---

## 5. 하네스 6축 매핑

| 6축 | hoyeon 기능 / 파일 | 강도 | 비고 |
|-----|---------------------|------|------|
| **① 구조 (Scaffolding)** | `/scaffold` 스킬 · `skills/ · agents/ · hooks/ · scripts/` 분리 · CLAUDE.md 역할 분리 (프로젝트 가이드라인 vs. rules) · `.hoyeon/specs/{name}/{requirements.md,plan.json,context/}` 디렉토리 컨벤션 | ★★★★☆ | 역할별 폴더링이 강한 편, 스캐폴드 스킬까지 존재. "Agent output 구조화" 지침에 잘 부합. |
| **② 맥락 (Context)** | 4-레벨 CLAUDE.md 계층 (프로젝트 가이드라인) · `.claude/skill-rules.json` 키워드 사전 · Progressive Disclosure (`discuss`의 `--scored`/`--deep` 플래그) · `session-compact-hook.sh`로 compact 복구 · charter-preflight로 에이전트 스코프 격리 | ★★★★☆ | 서브에이전트 독립 컨텍스트 격리(verifier/ralph-verifier) 잘 구현. Auto-memory는 `learnings.json` 방식으로 구현. |
| **③ 계획 (Planning)** | `/specify` (인터뷰 + L0~L4 도출) · `/blueprint` (contract-first + task DAG + verify plan) · `interviewer` agent Socratic 강제 · `gap-analyzer` · `gap-auditor`의 coverage ≥ 80% 게이트 · AskUserQuestion 패턴 표준화 | ★★★★★ | **최강점**. "해줘" 대신 "물어봐" 원칙이 훅·게이트로 강제됨. depth-calibration + risk modifier로 스코프 적응형. |
| **④ 실행 (Execution)** | `/execute` 3-axis (direct/agent/team × worktree/branch/no-commit × light/standard/thorough) · `worker` agent + `taskgraph-planner` · `/council`의 TeamCreate + SendMessage P2P · `hook-guarded writes` (skill-session-guard) · DAG 기반 병렬 · `/ultrawork` 장기 위임 | ★★★★★ | 하네스 Day2가 말한 Single/Subagent/Team Mode + 체크포인트 + 위임을 제일 충실히 구현. |
| **⑤ 검증 (Verification)** | **verify 6-에이전트 스택** (verifier · verification-planner · verify-planner · qa-verifier · ralph-verifier · spec-coverage) · 4-Gate 모델 · 2-Axis × 4-Tier 모델 · `rulph` 다중 모델 평가 · Stop 훅 re-injection · VERIFICATION.md 361행 문서 · Generator/Evaluator 분리 강제 | ★★★★★ | **하네스 전체 생태계 중 최강의 검증 구조**. 우리 verify 축 설계의 1순위 레퍼런스. |
| **⑥ 개선 (Compounding)** | `/compound` PR 학습 추출 → `docs/learnings/` 저장 · `learnings.json` 구조화 · BM25 크로스-스펙 검색 · `hoyeon-cli learning` · Pre-Release 체크리스트 (CLAUDE.md) · `skill-session-analyzer` 후분석 | ★★★★☆ | "10번째 프로젝트가 첫 번째보다 낫다" 비전을 BM25 + 구조화 학습으로 구현. `/session-wrap` 유사 기능은 `skill-session-analyzer`가 담당. |

**요약**: hoyeon은 **6축 모두를 실제 구현한 드문 레퍼런스**이며, 특히 **③ 계획 · ④ 실행 · ⑤ 검증** 축에 대해 가장 성숙한 참조 구현을 제공.

---

## 📊 4대 차별점 관점 평가

우리 플러그인의 4대 차별점 각각에 대한 hoyeon의 포지션 — 우리가 **계승할지/차별화할지** 판단 기준.

### (1) 기존 도구 오케스트레이션 — **독립형 (조합형 아님)**

- hoyeon은 **자체 완결형 파이프라인**. 타 플러그인(CE, superpower, ouroboros)을 래핑하거나 재호출하지 않음.
- 외부 LLM 호출은 있음 (`codex`, `gemini` CLI) — 하지만 플러그인이 아닌 **CLI 레벨** 통합.
- ⇒ **우리 플러그인 (오케스트레이션 레이어)과는 상보적**. hoyeon의 스킬들을 우리가 상위에서 조합할 수도 있고, 구조·패턴만 포팅하고 독립 구현할 수도 있음.

### (2) 하네스 6축 강제 — **암묵적 강제 (명시적 6축 선언은 없음)**

- "하네스"라는 단어는 README.ko.md 문맥에서 간접적으로만 언급 (team-attention이 발표한 "Harness #2" 개념의 실제 구현체).
- 6축 각각을 **명시적 축으로 이름 붙이지는 않음**. 대신 `specify/blueprint/execute/verify/compound` 5개 스킬 + `scaffold` 스킬로 사실상 6축을 실물화.
- ⇒ **우리 플러그인의 차별화 포인트**: hoyeon은 6축 **실물 구현** 제공, 우리는 여기에 "**6축이라는 메타 이름과 체크리스트**를 표면화"하여 사용자가 의식적으로 따라가도록 강제.

### (3) 개인화 컴파운딩 — **프로젝트 단위 + 크로스-스펙 구현됨**

- `docs/learnings/` + `learnings.json` + BM25 크로스-프로젝트 검색 = **프로젝트 간** 컴파운딩 구현.
- "**유저별** 암묵지" 개념은 명시 없음 — 팀/레포 단위 학습에 가까움.
- "틀렸다" 저장 포맷(우리 `corrections/`에 해당)은 별도 없음. `issues.json` (`type: failed_approach|out_of_scope|blocker`)이 가장 근접.
- ⇒ **우리 차별화**: 유저별 `.claude/memory/{tacit,corrections,preferences}/` 구조는 hoyeon에 **없는 축**. 추가 가치 있음.

### (4) 한국어 대화 최적화 — **부분 최적화 (UX 트리거 한국어 / 내부 영어)**

- 트리거 키워드 다국어 (한·영·중·일 README + 스킬 description 한국어 병기).
- 하지만 **에이전트 프롬프트 본문은 영어 고정** (CLAUDE.md Pre-Release Checklist가 명시).
- ⇒ **우리 플러그인 방향성 검증**: 한국어 UX + 영어 내부 구현 = **오픈소스 확산성 + 한국 UX** 공존 전략이 이미 검증된 패턴. 그대로 따라가도 안전.
- 차별화 가능: 에이전트가 **한국어로 응답**하도록 명시적 옵션 플래그(`--lang ko`) 추가 가능 (hoyeon에는 없음).

---

## 🎯 핵심 테이크어웨이 3가지

### 1. **verify 에이전트 스택은 그대로 포팅할 가치가 있다**
`verifier` / `verification-planner` / `verify-planner` / `qa-verifier` / `ralph-verifier` / `spec-coverage` 6개 에이전트가 각각 다른 "검증 질문"을 담당. 우리 `/verify` 스킬 내부에 **동일한 역할 분리** + **독립 컨텍스트 격리 규칙** + **4-Gate 할당 로직**을 이식하는 것이 가장 빠른 길. 특히 `ralph-verifier`의 "작성자 ≠ 검증자" 불변 규칙과 `spec-coverage`의 verbatim GWT 인용 강제는 그대로 채택.

### 2. **프론트매터 `validate_prompt` + PostToolUse 훅은 자기검증 자동화의 마법**
SKILL.md/agent.md 프론트매터에 선언된 `validate_prompt` 텍스트를 `validate-output.sh` 훅이 완료 직후 Claude에게 자동 재주입 → 스킬이 **자기 산출물 계약을 스스로 점검**. 우리 6축 스킬마다 validate_prompt 필수화하면 "체크리스트식 6축 준수"(Stop Doing 리스트에 있던 것)를 피하면서도 실질적 검증 달성. **구현 비용 대비 가치 최고**.

### 3. **한국어 UX + 영어 내부 이중 구조는 이미 검증된 패턴**
README 4언어 완역 + skill description 한국어 트리거 + 에이전트 본문 영어 고정의 이중 구조가 오픈소스 배포와 한국 사용자 UX를 동시에 만족시키는 실제 구현 증거. "한국어 특화가 오픈소스 확산 방해"(UU 리스크 #3)에 대한 **실증적 답**. 우리도 동일 구조 채택 + 추가로 `--lang ko` 플래그로 에이전트 응답 언어 옵션화하면 차별화까지 확보.

---

## 📎 증거 파일 경로 (전부 절대 경로)

- `/Users/ethan/Desktop/personal/harness/references/hoyeon/.claude-plugin/plugin.json`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/.claude-plugin/marketplace.json`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/CLAUDE.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/VERIFICATION.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/PLUGIN-README.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/README.ko.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/docs/architecture.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/hooks/hooks.json`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/.claude/skill-rules.json`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/_shared/charter-preflight.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/verifier.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/verification-planner.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/verify-planner.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/qa-verifier.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/ralph-verifier.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/spec-coverage.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/gap-analyzer.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/gap-auditor.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/interviewer.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/worker.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/skills/council/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/skills/ralph/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/skills/rulph/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/skills/compound/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/skills/discuss/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/skills/blueprint/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/hoyeon/scripts/ralph-dod-guard.sh`

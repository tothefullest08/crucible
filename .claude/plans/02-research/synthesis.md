# Phase 2 레퍼런스 리서치 — 종합 (Synthesis)

> 6개 레퍼런스(superpowers · compound-engineering-plugin · hoyeon · ouroboros · agent-council · plugins-for-claude-natives) 병렬 분석을 하나로 묶은 메인 세션 산출물.
>
> 입력: `.claude/plans/02-research/{name}.md` 6개
> 목적: (1) 매트릭스 통합, (2) 차별점별 순위, (3) 포팅 Top-N, (4) KU 실험 설계 업데이트
> 작성: 2026-04-19

---

## 0. 요약 — 한 줄 결론

| 레퍼런스 | 한 문장 | 우리 플러그인에 대한 포지션 |
|----------|---------|----------------------------|
| **superpowers** | HARD-GATE + 3단 Evaluator 서브에이전트 + SessionStart 훅 주입의 규율 라이브러리 | **통합 대상** — 1·3·4·5축 70% 포팅 |
| **compound-engineering-plugin** | 42 스킬 + 50 에이전트의 독립 생태계, 계획·실행·검증·개선 4축 프로덕션급 | **구조·파이프라인 모델** — 알고리즘 복사 |
| **hoyeon** | 6축을 이름 없이 실물 구현한 유일 레퍼런스, 특히 verify 6-에이전트 스택 최강 | **6축 구현 청사진** — verify 스택 이식 |
| **ouroboros** | 검증/개선 2축을 아키텍처로 강제한 폐루프 시스템, Ralph Loop + 3단 게이트 정석 | **검증 엔진 코어** — 의사코드·스키마 복사 |
| **agent-council** | 1 스킬로 멀티 CLI 병렬 수집 + 종합, Host UI 원격 조작 + Wait 커서 엔지니어링 | **오케스트레이션 서브루틴** — `/orchestrate` 내부 호출 |
| **plugins-for-claude-natives** | clarify 3-lens(맥락) + session-wrap 2-Phase(개선)의 피스들 모음 | **맥락·개선 축 직결** — clarify/session-wrap 80% 뼈대 차용 |

---

## 1. 6개 레퍼런스 종합 매트릭스

### 1.1 구조 · SKILL 패턴 · 워크플로우 · 재사용성 · 6축 매핑

| 차원 | superpowers | CE plugin | hoyeon | ouroboros | agent-council | p4cn |
|------|:-----------:|:---------:|:------:|:---------:|:-------------:|:----:|
| **plugin.json** | ✓ v5.0.7 | ✓ v2.68.1 | ✓ v1.6.0 | ✓ v0.28.8 | ✗ (marketplace만) | ✓ + 하위 13개 |
| **marketplace.json** | ✓ | ✓ | ✓ | ✓ | ✓ (primary) | ✓ (primary) |
| **skill 수** | 14 | 42 | 26 | 21 | 1 | 13 플러그인 내 30+ |
| **agent 수** | 1 (code-reviewer) | 50+ (6 카테고리) | 28 (verify/gap/extract/review) | 9 core + 5 보조 | 0 (CLI spawn) | 5 (session-wrap) |
| **훅 시스템** | SessionStart 1종 | **없음** (스킬 오케스트레이션만) | **6 이벤트 × 20+ 스크립트** | SessionStart/UserPromptSubmit/PostToolUse 3종 | 없음 | 없음 |
| **프론트매터 필수** | `name`, `description` 2필드 | `name`, `description`, `argument-hint` | `name`, `description`, `allowed-tools`, **`validate_prompt`** | `name`, `description`, (선택) `mcp_tool/mcp_args` | `name`, `description` | `name`, `description`, (일부) `version`, `user-invocable` |
| **description 원칙** | "Use when ..." CSO 트리거 | "What + When" 2파트 + 구체 트리거 구문 | 트리거 키워드 **다국어 펌프** (한·영·중) | 3템플릿 (최소형/MCP 바인딩/자연어) | "Use when users say ..." 영어 3-4 발화 | "Trigger on ...; for X use other-skill" 교차 참조 |
| **한국어 지원** | ✗ 전무 | ✗ 전무 | **✓ 4언어 README + 트리거 병기** | ○ README 이중 + 프롬프트 영어 | ○ README 이중 + 문서만 | ○ 트리거 일부 + README 부분 |
| **핵심 워크플로우** | 7단 강제 파이프라인 (brainstorm → ... → finish) | Brainstorm→Plan→Work→Review→Compound | specify→blueprint→execute (4-레이어 L0~L4) | Interview→Seed→Execute→Evaluate→Evolve 폐루프 | Stage 1~3 (dispatch→collect→synthesize) | 2-Phase 멀티에이전트 (병렬 분석 + 순차 validator) |
| **디자인 패턴 핵심** | HARD-GATE, Iron Law, Red Flags, 3단 서브에이전트 | Always-on + Conditional, 4단계 merge/dedup, Model Tiering, Mandatory Checkpoints, Auto Memory supplementary | 4-Gate 검증, 2-Axis × 4-Tier, Charter Preflight, Stop 훅 재주입, validate_prompt | Ralph Loop, Cost-Tiered Gating, Ambiguity Gate, Event Sourcing, 병리 감지 | Generator/Evaluator 자동 분리, Wait cursor bucket, Host UI payload | clarify 3-lens, hypothesis-as-options, Read-only 에이전트 + 메인 쓰기 |
| **1 구조** | ●●● | ●●● | ●●●● | ●●● | ●● | ●●● |
| **2 맥락** | ●● | ●●● | ●●●● | ●●● | ● | ●●●● |
| **3 계획** | ●●●● | ●●●●● | ●●●●● | ●●●● | ●● | ●●● |
| **4 실행** | ●●●●● | ●●●● | ●●●●● | ●●●● | ●●●●● | ●●● |
| **5 검증** | ●●●●● | ●●●●● | ●●●●● | ●●●●●●(최강) | ●●●●● | ●●● |
| **6 개선** | ● | ●●●●● | ●●●● | ●●●●●●(최강) | · | ●●●●● |

> 범례: ● 스케일은 상대 평가 (●=터치, ●●●●●●=해당 축의 모범 구현). "CSO"=Claude Search Optimization.

### 1.2 축별 "강한 레퍼런스" 한눈에

| 6축 | 1순위 | 2순위 | 비고 |
|-----|-------|-------|------|
| **구조** | hoyeon | superpowers ≈ CE ≈ p4cn | hoyeon은 `skills/ + agents/ + hooks/ + scripts/ + cli/` 모두 분리 |
| **맥락** | hoyeon, p4cn | CE | p4cn의 clarify 3-lens가 암묵지 해소 엔진 |
| **계획** | hoyeon, CE | superpowers, ouroboros | hoyeon `gap-analyzer + gap-auditor` + ouroboros `Ambiguity Gate` |
| **실행** | superpowers, hoyeon, agent-council | CE, ouroboros | superpowers의 3단 Evaluator + hoyeon 3-axis dispatch + agent-council CLI spawn |
| **검증** | ouroboros, hoyeon | superpowers, CE, agent-council | ouroboros 3단 파이프라인 + hoyeon verify 6-에이전트 스택 |
| **개선** | ouroboros, p4cn | CE, hoyeon | ouroboros evolve + p4cn session-wrap + CE ce-compound (Auto Memory 통합) |

---

## 2. 차별점별 레퍼런스 순위

Phase 1 `clarified-spec.md`가 정의한 4가지 차별점 축에 각 레퍼런스를 투영.

### 2.1 기존 도구 오케스트레이션

| 순위 | 레퍼런스 | 근거 |
|------|----------|------|
| 🥇 | **agent-council** | CLI들을 spawn해 병렬 수집 + 종합하는 **유일한 본격 오케스트레이터**. Wait cursor + Host UI payload까지. |
| 🥈 | **hoyeon** | `/council` + TeamCreate로 Agent Team 오케스트레이션 구현. Codex/Gemini CLI 레벨 통합. |
| 🥉 | **CE plugin** | 독립형이지만 42 스킬 내부 오케스트레이션 (Research track, Sub-agent 위임)가 성숙. |
| 4 | superpowers | 독립형 — 타 플러그인 호출 없음. Task 도구로 ad-hoc 서브에이전트만. |
| 5 | ouroboros | 독립형 폐루프. 외부 어댑터는 Claude Code/Codex CLI만. |
| 6 | p4cn | 카탈로그에 가까움 — 플러그인 간 조합 메커니즘 없음. |

**핵심 교훈**: 진짜 "플러그인 간 오케스트레이터"는 없음. 우리 `/orchestrate`는 agent-council의 CLI spawn 엔진 + hoyeon의 3-axis dispatch 조합이 유력.

### 2.2 하네스 6축 강제

| 순위 | 레퍼런스 | 근거 |
|------|----------|------|
| 🥇 | **hoyeon** | 6축을 **이름 없이 실물 구현**. specify/blueprint/execute/verify/compound + scaffold가 사실상 6축. `validate_prompt` 프론트매터가 자기검증 자동화. |
| 🥈 | **ouroboros** | 검증/개선 2축을 **아키텍처로 강제**. Seed 불변 + Ambiguity Gate + 3단 파이프라인 + Evolve 수렴. |
| 🥉 | **CE plugin** | 4축 프로덕션급 (계획·실행·검증·개선). 6축 메타 프레임워크는 없음. |
| 4 | superpowers | 3·4·5축 production-ready. 6축 메타 레이어 없음. |
| 5 | agent-council | 4·5축 특화. 나머지 4축 미커버. |
| 6 | p4cn | 2·6축(clarify·session-wrap)만 강함. 나머지 4축은 파편. |

**핵심 교훈**: "6축**이라는 이름과 메타-체크리스트**를 표면화"하는 것이 우리 순수 차별점. hoyeon의 `validate_prompt` + ouroboros의 `evaluation_principles`을 조합하면 "체크리스트化 방지 + 실효 검증" 동시 달성.

### 2.3 개인화 컴파운딩

| 순위 | 레퍼런스 | 근거 |
|------|----------|------|
| 🥇 | **p4cn (session-wrap)** | 2-Phase 멀티에이전트 (4 분석자 병렬 + 1 validator 순차) + AskUserQuestion 승인 = **승격 게이트 + 세션 격리 + 유저 명시 승인** 3박자 구현체. |
| 🥈 | **CE plugin (ce-compound)** | 5-dim overlap scoring + Bug/Knowledge track 분기 + **Auto Memory supplementary block**. 팀 단위 최강. |
| 🥉 | **ouroboros (evolve)** | Seed lineage + 병리 패턴 4종 감지 (stagnation/oscillation/repeated-feedback/hard-cap). 과적합 방지 수치 모델. |
| 4 | hoyeon (/compound + BM25) | `docs/learnings/` + learnings.json + BM25 크로스-스펙 검색. 프로젝트 레벨. |
| 5 | superpowers | 없음. `writing-skills`의 Skill TDD 만 간접. |
| 6 | agent-council | 전무 — `clean`이 오히려 증거 삭제. |

**핵심 교훈**: 3개 레퍼런스(p4cn/CE/ouroboros) 조각을 합쳐야 우리 요구사항 완전 커버. **p4cn 뼈대 + CE overlap 알고리즘 + ouroboros 병리 감지 + "유저 cross-project" 레이어(우리 신규)** = 우리 `/compound`.

### 2.4 한국어 대화 최적화

| 순위 | 레퍼런스 | 근거 |
|------|----------|------|
| 🥇 | **hoyeon** | 4언어 README 완역 + `skill-rules.json`·description 다국어 트리거 + 프롬프트 영어 고정의 **검증된 이중 구조**. UU 리스크 "한국어 특화 = 오픈소스 확산 방해"의 실증적 반례. |
| 🥈 | **p4cn** | clarify description 한국어 트리거 5-6개씩 + 일부 본문 한국어 + `README.ko.md`. 다만 편차 큼. |
| 🥉 | **ouroboros** | README.ko.md 완역만. SKILL/agents 영어 고정. |
| 4 | agent-council | README.ko.md 완전 번역 + 문서 레벨 한국어 발화 예시. 코드/프론트매터는 영어. |
| 5 | superpowers | 전무 — 멀티 하네스 분기(.claude-plugin/.cursor-plugin/...)는 있으나 **언어 분기 없음**. |
| 6 | CE plugin | 전무 — AGENTS.md에 "identifiers ASCII only" 명시. |

**핵심 교훈**: hoyeon 이중 구조가 베스트 프랙티스로 검증. 우리는 여기에 **`--lang ko` 응답 언어 플래그** 추가 시 차별화까지 확보.

---

## 3. 포팅 UK 자산 Top-N (우선순위 포함)

Phase 1 KU/UK 프레임에서 **UK(이미 있는 덜 쓰인 자산)** 영역으로 분류된 포팅 후보. 우선순위는 `/verify`·`/compound`·`/brainstorm`·`/orchestrate` 스킬 MVP 도달 기준.

### 3.1 P0 — 즉시 포팅 (MVP 필수)

| # | 자산 | 원본 | 우리 쪽 위치 | 기여 축 |
|---|------|------|-------------|---------|
| 1 | **verify 6-에이전트 스택** (verifier / verification-planner / verify-planner / qa-verifier / ralph-verifier / spec-coverage) | hoyeon `agents/*.md` | `/verify` 백본 | 5축 |
| 2 | **Ralph Loop 의사코드** (non-blocking + level-based polling) | ouroboros `skills/ralph/SKILL.md:50-99` | `/verify` 자동 재시도 본문 | 5축 |
| 3 | **qa-judge JSON 스키마** (score/verdict/dimensions/differences/suggestions) + 임계값 (0.80/0.40) | ouroboros `agents/qa-judge.md` | Evaluator 응답 포맷 | 5축 |
| 4 | **session-wrap 2-Phase 파이프라인** (4 분석자 병렬 + 1 validator 순차 + AskUserQuestion) | p4cn `session-wrap/` 전체 | `/compound` 전체 뼈대 | 6축 |
| 5 | **`validate_prompt` 프론트매터 + `PostToolUse[Task\|Skill]` 훅** | hoyeon CLAUDE.md:27-44 + `validate-output.sh` | 우리 모든 스킬 자기검증 계약 | 1·5축 |
| 6 | **SessionStart 훅 + `using-harness.md` 주입** | superpowers `hooks/session-start` | 우리 `hooks/` | 2축 |
| 7 | **HARD-GATE 태그 패턴** | superpowers `brainstorming/SKILL.md:12-14` | 우리 6축 전환 지점 각각에 배치 | 3·4·5축 |

### 3.2 P1 — 구조 차용 (2주차)

| # | 자산 | 원본 | 우리 쪽 위치 | 기여 축 |
|---|------|------|-------------|---------|
| 8 | **3단 Evaluator 서브에이전트** (implementer / spec-reviewer "Do Not Trust" / code-quality-reviewer) | superpowers `subagent-driven-development/*-prompt.md` | 우리 "6축 적합성 평가자 + 승격 게이트" 2·3단 | 5축 |
| 9 | **Always-on + Conditional 페르소나** | CE `ce-code-review` (17 페르소나) | `/verify` 6축 always-on + 도메인 conditional | 5축 |
| 10 | **4단계 머지/dedup 파이프라인** (fingerprint + confidence gate + cross-reviewer agreement +0.10) | CE `ce-code-review` Stage 5 | Evaluator 여러 관점 합성 | 5축 |
| 11 | **3단 검증 파이프라인** (Mechanical $0 → Semantic $$ → Consensus $$$$) + Stage 3 6트리거 | ouroboros `agents/evaluator.md` | `/verify --deep` 확장 옵션 | 5축 |
| 12 | **Host UI payload + Wait cursor bucket** | agent-council `council-job.js:179-258, 515-650` | `/orchestrate` 6축 진행 시각화 | 1·4축 |
| 13 | **Charter Preflight 5줄 블록** | hoyeon `agents/_shared/charter-preflight.md` | 우리 서브에이전트 첫 출력 규약 | 1·2축 |
| 14 | **clarify 3-lens 서브루틴** (vague / unknown / metamedium + 3-Round depth pattern) | p4cn `clarify/skills/*` | `/brainstorm` 내장 Phase A·B·C | 2·3축 |
| 15 | **Model Tiering** (Orchestrator 최상급 / Subagent mid-tier / Validator cheap) | CE ce-code-review Stage 4, superpowers `subagent-driven-development` line 87-100 | 우리 전체 서브에이전트 호출 정책 | 4축 |
| 16 | **hoyeon 3-Axis 실행 조합** (dispatch × work × verify = 9 조합) | hoyeon `/execute` | `/orchestrate` 실행 전략 선택 | 4축 |

### 3.3 P2 — 알고리즘·수치 차용 (3~4주차)

| # | 자산 | 원본 | 우리 쪽 위치 | 기여 축 |
|---|------|------|-------------|---------|
| 17 | **Mandatory Disk Checkpoints CP-0~CP-5** (experiment-log.yaml) | CE `ce-optimize` Persistence Discipline | `/orchestrate` 장기 실행 내구성 | 1·4축 |
| 18 | **5-dimension overlap scoring** (problem/cause/solution/files/prevention) + High/Moderate/Low | CE `ce-compound` Related Docs Finder | 승격 게이트 drift 판정 | 6축 |
| 19 | **Auto Memory supplementary block** ("Treat as additional context, not primary evidence") | CE `ce-compound` Phase 0.5 | MEMORY.md 계층 규약 | 2·6축 |
| 20 | **Ambiguity Score Gate** (0.2 임계) + **Drift 임계값** (0.15/0.30) | ouroboros `README.ko.md:210-230, skills/status:79-85` | `/clarify` 종료 + 승격 게이트 수치 | 2·5·6축 |
| 21 | **Seed YAML 스키마** (goal/constraints/AC/`evaluation_principles`+weight/`exit_conditions`/parent_seed_id) | ouroboros `.ouroboros/seeds/*.yaml` | `/plan` 산출물 형식 | 3축 |
| 22 | **병리 패턴 감지 4종** (stagnation/oscillation/repeated-feedback/hard-cap) | ouroboros `README.ko.md:249-257` | 컴파운딩 과적합 방지 | 6축 |
| 23 | **Rulph 다중 모델 병렬 평가** (Codex + Gemini + Claude, per-criterion floor + threshold) | hoyeon `skills/rulph/SKILL.md` | Evaluator 편향(UU) 대응 승격 게이트 | 5·6축 |
| 24 | **Bug track vs Knowledge track** schema 분기 (`What Didn't Work` 포함) | CE `ce-compound` schema.yaml | `corrections/` vs `tacit/` 매핑 | 6축 |
| 25 | **history-insight 세션 로그 파서** (경로 인코딩, jq 배치, split+병렬) | p4cn `history-insight/scripts/*.sh` | 메모리 원재료 전처리 | 6축 |
| 26 | **session-analyzer Expected vs Actual 비교 테이블** | p4cn `session-analyzer/SKILL.md` Phase 5 | `/verify` 스코어링 엔진 골격 | 5축 |

### 3.4 P3 — 선택·실험 영역 (5주차+)

| # | 자산 | 원본 | 우리 쪽 위치 | 비고 |
|---|------|------|-------------|------|
| 27 | **4언어 README + `--lang ko` 플래그** | hoyeon `README.{md,ko,zh,ja}.md` + CLAUDE.md Pre-Release Checklist | 오픈소스 + 한국어 공존 | 차별점 4 |
| 28 | **마켓플레이스 최소 구조** (plugin.json 없이 marketplace.json만) | agent-council `.claude-plugin/marketplace.json` | 배포 minimal 옵션 | 1축 |
| 29 | **llms.txt / llms-full.txt LLM 전용 요약본** | ouroboros 루트 | 플러그인 소비자 AI 문서 | 2축 |
| 30 | **writing-skills Skill TDD** (RED-GREEN-REFACTOR for docs) | superpowers `writing-skills/SKILL.md:31-45, 376-392` | `/compound` 승격 품질 검증 | 6축 |
| 31 | **Cross-spec BM25 검색** (과거 `learnings.json` 조회) | hoyeon `cli/src/commands/learning.js` + README.ko.md:112-118 | MEMORY.md 인덱스 검색 | 6축 |
| 32 | **dhh-rails / kieran-* persona-as-code 문체** | CE `agents/review/*` | 우리 6축 evaluator 페르소나 스타일 | 5축 |

### 3.5 포팅하지 말 것 (명시적 제외)

| 자산 | 이유 |
|------|------|
| ouroboros Python 3.14+ 런타임 + SQLite EventStore | 스킬+훅+MCP만 원칙. JSON append로 시작 |
| ouroboros Textual TUI + LiteLLM 멀티 프로바이더 | out of scope |
| superpowers Visual Companion 브라우저 서버 | 복잡도 과다, 1차 릴리스 제외 |
| superpowers `AGENTS.md → CLAUDE.md` symlink | 미지원 플랫폼에서 깨짐, 1차는 중복 파일로 |
| CE "cross-skill 참조 금지" 정책 | 우리는 6축 간 조합이 primary → 반대 정책 |
| hoyeon `cli/` npm 패키지 + 복잡한 schema | MVP는 순수 스킬/훅/훅 스크립트 |
| agent-council `clean` 서브커맨드 (증거 삭제) | **반대로 흘려보내는** 후크로 변형 |

---

## 4. KU(실험 설계) 업데이트 — 레퍼런스 기반 구체화

Phase 1 `clarified-spec.md`의 KU(알고 있지만 검증 필요) 항목을 레퍼런스 결과로 구체화.

### 4.1 KU-1. "6축 강제" 실효성 판정

**Phase 1 가정**: "체크리스트식 확인이 아니라 effect metric이 필요"

**레퍼런스 증거**:
- hoyeon `validate_prompt` 프론트매터 + `PostToolUse[Task|Skill]` 훅 → 스킬 자체가 계약을 선언하고 훅이 자동 재주입.
- ouroboros `evaluation_principles` weight → 합 1.0 가중치 기반 점수화.
- CE `ce-plan` Phase 5.3 Confidence Check → 스킬 말미 자체 채점.

**실험 설계 (구체화)**:
- 실험 A: 각 6축 스킬(`/brainstorm`·`/plan`·`/verify`·`/compound`·`/orchestrate`)의 SKILL.md에 `validate_prompt` 필수화. 10개 샘플 태스크에서 훅이 자동 재주입한 검증 질문을 Claude가 **실제로 답하지 않고 넘어간 횟수** 측정. 목표: 신뢰도 ≥ 90%.
- 실험 B: 6축 각각에 `evaluation_principles` weight 할당 → 스킬 종료 시 자체 점수 산출. 주관 체감 vs 자체 점수 상관 ≥ 0.7 되는지 점검.
- 실험 C: `/verify --axis 5` 처럼 축 한정 실행 시 다른 축 영향 누수율 < 10%.

### 4.2 KU-2. 한국어 트리거 vs 오픈소스 확산 균형

**Phase 1 가정**: "한국어 특화가 오픈소스 확산을 저해할 위험"

**레퍼런스 증거 (반례 확보)**:
- hoyeon README 4언어 완역 + description 한국어 트리거 + 프롬프트 본문 영어 **이중 구조 실증**.
- CLAUDE.md Pre-Release Checklist 104행: *"All content must be written in English (SKILL.md, agent .md, CLAUDE.md, README.md, commit messages, comments)"*.
- p4cn clarify: description 한·영 병기 + 본문 영어.

**실험 설계 (구체화)**:
- 실험 D: description에 **한·영 병기 트리거**를 넣은 버전 vs 영어만 버전을 각각 20개 유저 발화로 테스트. 트리거 정확도 차이 측정. (한국어 병기가 해치지 않아야 성공)
- 실험 E: `--lang ko` 플래그 도입 → 에이전트 응답 언어만 분기. 영어 응답 사용자 불편도 0 유지.
- 실험 F: 영어권 PR 검토에서 description 한국어 포함이 거절 사유가 되는지 A/B.

### 4.3 KU-3. 승격 게이트 오검지율·철회율

**Phase 1 가정**: "오검지율 < 20%, 철회율 < 10%"

**레퍼런스 증거**:
- CE 5-dim overlap scoring (problem/cause/solution/files/prevention)의 High(4-5) / Moderate(2-3) / Low(0-1) 분류.
- ouroboros Ambiguity Gate 0.2 임계 + Drift 0.15/0.30 3구간.
- p4cn duplicate-checker (haiku, Phase 2 validator)의 Complete/Partial/No 분류.

**실험 설계 (구체화)**:
- 실험 G: 10개 실 세션에서 `/compound`를 돌린 뒤, **자동 승격 제안** vs **유저 실제 승인** 일치율. 목표: false positive < 20%.
- 실험 H: 한 번 승격된 corrections/tacit 중 2주 내 재편집/철회율 < 10%.
- 실험 I: ouroboros oscillation 감지(Gen N ≈ Gen N-2)를 corrections에도 적용 — 같은 "틀렸다" 3회 토글 시 자동 차단.

### 4.4 KU-4. Evaluator 편향(같은 모델군 맹점)

**Phase 1 가정**: "회의적 튜닝된 별도 Evaluator 필요"

**레퍼런스 증거**:
- superpowers `spec-reviewer-prompt.md:20-36` "**Do Not Trust the Report ... Verify by reading code**".
- hoyeon `ralph-verifier` "**새 컨텍스트에서 실행해 자기검증 편향 제거**" + foreground spawn 강제.
- hoyeon `rulph` Phase 2 **Codex + Gemini + Claude 3모델 병렬 평가** + per-criterion floor + threshold.
- agent-council `exclude_chairman_from_members: true` **기본값** (YAML 한 줄).

**실험 설계 (구체화)**:
- 실험 J: 동일 Evaluator를 self-mode vs fresh-context-mode로 평가. 편향 차 ≥ 15% 나타나는지.
- 실험 K: Claude Opus Generator에 대해 Evaluator를 Claude Sonnet / Codex / Gemini 3종으로 쪼개 per-criterion floor 시나리오. 합의(≥ 66%) 임계 적절성.
- 실험 L: agent-council `exclude_chairman_from_members` 원칙 위반 시 품질 저하 정도 측정.

### 4.5 KU-5. 개인화 컴파운딩 과적합 방지

**Phase 1 가정**: "같은 패턴 3회 토글 = 차단"

**레퍼런스 증거**:
- ouroboros 4 병리 패턴 (stagnation/oscillation/repeated-feedback/hard-cap).
- ontology similarity 공식: `0.5 × name_overlap + 0.3 × type_match + 0.2 × exact_match`.
- CE 5-dim overlap scoring → Moderate(2-3) 시 consolidation 플래그.

**실험 설계 (구체화)**:
- 실험 M: 10 세션에서 oscillation 감지가 **실제 과적합**을 막은 케이스 vs **유용한 학습**을 억제한 케이스 비율 측정.
- 실험 N: similarity 임계 0.95를 한국어 텍스트에도 적용 가능한지 — 한국어 tokenization 영향 체크.
- 실험 O: hard-cap 30세대(ouroboros 기본)을 우리 컴파운딩에선 몇 회로 잡을지 — 15/30/60 비교.

---

## 5. 아키텍처 초안 (레퍼런스 조합)

Top-N 자산을 실제 플러그인으로 조립한 초안. Phase 3 `/ce-brainstorm`의 입력.

```
harness (우리 플러그인)
├── .claude-plugin/
│   ├── plugin.json            ← CE plugin.json 5필드 minimal
│   └── marketplace.json       ← agent-council marketplace 구조
├── hooks/
│   ├── hooks.json             ← hoyeon 패턴 (SessionStart + UserPromptSubmit + PostToolUse + Stop)
│   ├── session-start          ← superpowers bash 구조 + using-harness.md 주입
│   ├── validate-output.sh     ← hoyeon validate_prompt 재주입
│   ├── drift-monitor.sh       ← ouroboros PostToolUse 드리프트 advisory
│   └── correction-detector.sh ← 신규 — "틀렸다" 발언 감지 → corrections/ 흐름
├── skills/
│   ├── using-harness/         ← SessionStart 페이로드 (superpowers 패턴)
│   ├── brainstorm/            ← superpowers 9단 체크리스트 + p4cn clarify 3-lens 내장
│   ├── plan/                  ← ouroboros Seed YAML + CE ce-plan 5-Phase + hoyeon gap-analyzer
│   ├── verify/                ← hoyeon verify 6-에이전트 스택 + ouroboros 3단 파이프라인 + Ralph Loop
│   ├── compound/              ← p4cn session-wrap 2-Phase + CE 5-dim overlap + ouroboros 병리 감지
│   └── orchestrate/           ← agent-council Wait cursor + hoyeon 3-axis dispatch + CE Mandatory Checkpoints
├── agents/
│   ├── _shared/
│   │   └── charter-preflight.md   ← hoyeon 5줄 블록 규약
│   ├── verify/                    ← hoyeon 6종 + ouroboros qa-judge 파생
│   ├── compound/                  ← p4cn 5종 이름 리네이밍 (tacit/correction/pattern/preference/duplicate-checker)
│   └── evaluator/                 ← superpowers 3단 (implementer/spec-reviewer/code-quality)
├── scripts/
│   ├── keyword-detector.py        ← ouroboros setup gate + 한국어 트리거 추가
│   └── extract-session.sh         ← p4cn history-insight 포팅
├── CLAUDE.md                      ← hoyeon 2중 구조 (프로젝트 가이드라인)
├── AGENTS.md                      ← CE Skill Compliance Checklist 섹션
├── README.md + README.ko.md       ← ouroboros 이중 + hoyeon 4언어 확장 여지
└── .harness/
    ├── memory/
    │   ├── MEMORY.md          ← 우리 신규 — 인덱스
    │   ├── tacit/             ← 승격된 암묵지
    │   ├── corrections/       ← "틀렸다" 기록
    │   └── preferences/       ← 유저 선호
    └── mechanical.toml        ← ouroboros Stage 1 게이트 설정
```

---

## 6. Phase 3 입력으로 넘길 핵심 의문점 (브레인스토밍 시드)

레퍼런스 분석으로도 답이 나오지 않은, **설계 결정이 필요한 지점** 5가지:

1. **Seed YAML vs Markdown plan** — ouroboros `harness-seed.yaml`(불변 + weight) vs CE `plan.md`(유연) 중 `/plan` 산출물 포맷 결정.
2. **Stage 3 Consensus 비용 감수 여부** — 토큰 비용과 Evaluator 편향 대응(KU-4) 사이 균형. 기본 off + `/verify --deep`으로 on이 유력.
3. **세션 간 상태 저장 방법** — ouroboros SQLite EventStore(과설계) vs JSON append-only(간결) 중 후자가 유력하지만, 복원성 검증 필요.
4. **한국어 description 병기 수준** — agent-council처럼 문서로만 vs p4cn처럼 description에 섞기 vs hoyeon처럼 skill-rules.json 별도 관리 중 어느 레이어로.
5. **`/orchestrate`의 외부 플러그인 호출 범위** — agent-council CLI spawn 레이어를 쓸 것인가(superpowers/CE/ouroboros 설치되어 있다고 가정), 아니면 우리 플러그인 단일 완결형으로 먼저.

---

## 7. 완료 체크리스트 (Phase 2 종료)

- [x] 6개 레퍼런스 분석 문서 생성 (`02-research/{superpowers,compound-engineering-plugin,hoyeon,ouroboros,agent-council,plugins-for-claude-natives}.md`)
- [x] 각 문서가 5개 섹션 + 4개 차별점 평가 + 6축 매핑 포함
- [x] 종합 문서 (본 파일) 생성 — 매트릭스 · 차별점 순위 · 포팅 Top-N (32개 자산, 4-tier 우선순위) · KU 업데이트 (5 항목)

## 8. 다음 단계 추천

**권장**: `/ce-brainstorm` — 위 §6 의문점 5가지를 시드로 설계 결정 대화.

**대안**:
- 바로 `/ce-plan` — 포팅 Top-N P0·P1 항목을 기반으로 곧장 구현 태스크 분해.
- `/clarify:unknown` — §6 의문점을 4분면에 배치해 전략 블라인드스팟 추가 점검.

---

*Phase 2 리서치 종합 산출물 끝. 6개 병렬 분석 + 메인 세션 통합. Phase 3 진입 준비 완료.*

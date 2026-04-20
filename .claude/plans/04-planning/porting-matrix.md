# 하네스 플러그인 — 포팅 자산 매트릭스 (Phase 4 `/ce-plan` 산출물)

> **입력**: `.claude/plans/02-research/synthesis.md` §3 Top-32 자산 + v2 스펙 §4.1 bash+jq 제약
> **자매 산출물**: `04-planning/implementation-plan.md`, `04-planning/section11-promotion-tracker.md`
> **작성일**: 2026-04-19
> **목적**: Top-32 자산을 주차별 배정 + 원본/위치/상류 해시/재작성 필요 여부/라이선스 초안을 단일 매트릭스로.

---

## 0. 요약

- **P0 (7개)**: W1~W4 내 진입 필수
- **P1 (9개)**: 구조 차용 — W3~W7
- **P2 (10개)**: 알고리즘·수치 차용 — W3~W7.5
- **P3 (6개)**: 선택·실험 — W8 / 2차 릴리스
- **2차 릴리스 명시 분류 (7개)**: `/orchestrate` 고급 기능·`skill-rules.json`·Rulph 3모델 등
- **bash+jq 재작성 필수 (P0-1 위반 시 전면 재작업)**: 2개 — ouroboros `drift-monitor.py`, `keyword-detector.py`
- **라이선스 실측 결과 (2026-04-19 · user-decisions-5 §4 근거)**: **6개 상류 전부 MIT 확인 → 시나리오 A 확정**. 본 플러그인 최종 라이선스 **MIT** (SPDX identifier `MIT`, final-spec v3 §4.5). 호환 플래그 전부 ✅
- **상류 커밋 해시 스냅샷 (2026-04-20 · T-W8-PRE-02 확정)**: hoyeon `4a4e0f3` · ouroboros `23426b5` · p4cn `7895a58` · superpowers `b557648` · CE plugin `b575e49` · agent-council `79a13ee`. 각 §2 상세 매트릭스에 반영

---

## 1. 주차별 배정 총람

### 1.1 W0 (프리미스 재검증) — 포팅 없음

### 1.2 W1 — 스캐폴드 + SessionStart + JSONL smoke

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 6 | SessionStart + `using-harness.md` 주입 | `hooks/session-start` + `skills/using-harness/` | T-W1-04, T-W1-05 | ✗ (bash 원본) |
| 25 | history-insight 세션 로그 파서 | `scripts/extract-session.sh` | T-W1-06 | ○ 통일 (jq 패턴 일관화) |
| 28 | 마켓플레이스 최소 구조 (marketplace.json만) | `.claude-plugin/marketplace.json` | T-W1-02 | ✗ |

### 1.3 W2 — `/brainstorm` MVP

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 5 | `validate_prompt` frontmatter + `PostToolUse` 훅 | `skills/*/SKILL.md` frontmatter + `hooks/validate-output.sh` | T-W2-05, T-W2-06 | ✗ (bash+jq 원본) |
| 7 | HARD-GATE 태그 패턴 | `skills/brainstorm/SKILL.md` 본문 | T-W2-10 | ✗ |
| 14 | clarify 3-lens (vague / unknown / metamedium) | `skills/brainstorm/` 본문 내장 | T-W2-02 | ✗ |

### 1.4 W3 — `/plan` 하이브리드 포맷

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 15 | Model Tiering (Orchestrator/Subagent/Validator) | `/plan` 본문 + 전체 서브에이전트 호출 정책 | T-W3-02 | ✗ (정책 차용) |
| 20 | Ambiguity Score Gate (0.2 임계) | `/plan` 시작 게이트 | T-W3-05 | ✗ (수치 차용) |
| 21 | Seed YAML 스키마 (goal/AC/evaluation_principles+weight/exit_conditions/parent_seed_id) | `/plan` YAML frontmatter | T-W3-03 | ✗ (스키마 차용) |

### 1.5 W4 — `/verify` scaffolding + qa-judge + Ralph Loop

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 1 | verify 6-에이전트 스택 | `agents/verify/` | T-W4-02 (일부 W7.5 이월) | ✗ (이식) |
| 2 | Ralph Loop 의사코드 | `skills/verify/` 본문 | T-W4-04 | ✗ (의사코드 차용) |
| 3 | qa-judge JSON 스키마 (0.80/0.40) | `agents/evaluator/qa-judge.md` | T-W4-03 | ✗ (임계값은 KU-0 재조정) |
| 8 | 3단 Evaluator (implementer/spec-reviewer/code-quality) | `agents/evaluator/` 2·3단 | T-W4-02 (부분) | ✗ |
| 9 | Always-on + Conditional 페르소나 | `/verify` 6축 always-on + 도메인 conditional | T-W4-01 | ✗ (정책 차용) |
| 13 | Charter Preflight 5줄 블록 | `agents/_shared/charter-preflight.md` | T-W4-02 (부속) | ✗ |
| — | 🚨 **drift-monitor.py → drift-monitor.sh** | `hooks/drift-monitor.sh` | T-W4-07 | **○ bash+jq 재작성 필수 (P0-1)** |

### 1.6 W5 — 메모리 + 승격 게이트 UX

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 18 | 5-dimension overlap scoring (problem/cause/solution/files/prevention) | `/compound` 승격 게이트 | T-W5-05 | ✗ (알고리즘 차용) |
| 19 | Auto Memory supplementary block 원칙 | MEMORY.md 계층 규약 | T-W5-02 | ✗ (규약 차용) |
| 24 | Bug track vs Knowledge track 스키마 분기 | `corrections/` vs `tacit/` 매핑 | T-W5-04 | ✗ (스키마 차용) |

### 1.7 W6 — `/compound` 트리거 3종

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 4 | session-wrap 2-Phase 파이프라인 (4 분석자 병렬 + validator 순차) | `skills/compound/` 전체 | T-W6-02 | ✗ (이식) |
| 22 | 병리 패턴 감지 4종 (stagnation/oscillation/repeated-feedback/hard-cap) | `/compound` 과적합 방지 | T-W6-09 → T-W7.5-06 이월 | ✗ (패턴 차용) |
| 26 | session-analyzer Expected vs Actual 비교 테이블 | `/verify` 스코어링 엔진 골격 | T-W6-02 (부속) | ✗ |
| — | 🚨 **keyword-detector.py → keyword-detector.sh** | `scripts/keyword-detector.sh` | T-W6-04 | **○ bash+jq 재작성 필수 (P0-1)** |
| — | p4cn 5종 에이전트 리네이밍 (tacit-extractor / correction-recorder / pattern-detector / preference-tracker / duplicate-checker) | `agents/compound/` | T-W6-03 | ✗ (리네이밍만) |

### 1.8 W7 `[Stretch]` — `/orchestrate` B

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 12 | Host UI payload + Wait cursor bucket | `/orchestrate` 6축 진행 시각화 | T-W7-03 `[Stretch]` | ✗ |
| 16 | hoyeon 3-Axis 실행 조합 (dispatch × work × verify = 9) | `/orchestrate` 실행 전략 선택 | T-W7-04 `[Stretch]` | ✗ |
| 17 | Mandatory Disk Checkpoints CP-0~CP-5 (experiment-log.yaml) | `/orchestrate` 장기 실행 내구성 | T-W7-05 `[Stretch]` | ✗ |

### 1.9 W7.5 — KU 실행 + 하드닝

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 10 | 4단계 머지/dedup (fingerprint + confidence gate + cross-reviewer +0.10) | Evaluator 여러 관점 합성 (KU-3 측정에서 검증) | T-W7.5-04 (측정 경로) | ✗ (알고리즘 차용) |
| 30 | writing-skills Skill TDD (RED-GREEN-REFACTOR for docs) | `/compound` 승격 품질 검증 (KU-3 보조) | T-W7.5-04 | ✗ (패턴 차용) |

### 1.10 W8 — 문서화 + 배포

| # | 자산 | 우리 위치 | 태스크 ID | 재작성 필요 |
|---|------|----------|-----------|------------|
| 27 | README 다언어 (MVP는 영·한 2언어) | `README.md`, `README.ko.md` | T-W8-01, T-W8-02 | ✗ (4언어는 2차) |
| 29 | llms.txt / llms-full.txt LLM 전용 요약 | 플러그인 소비자 AI 문서 | T-W8-07 (부속) | ✗ |

### 1.11 2차 릴리스 (명시 연기)

| # | 자산 | 연기 이유 | 연계 Hard AC |
|---|------|----------|-------------|
| 11 | 3단 검증 파이프라인 (Mechanical $0 → Semantic $$ → Consensus $$$$) + Stage 3 6트리거 | `/verify --deep` 플래그가 v2 §10.3 2차 릴리스 | — |
| 23 | Rulph 다중 모델 병렬 평가 (Codex+Gemini+Claude, per-criterion floor) | KU-4 (Evaluator 편향) 2차 → 의존 기능 연기 | — |
| 27 (부분) | hoyeon 4언어 README (zh/ja 추가) + `--lang ko` 응답 언어 플래그 | MVP 이중 언어 충족 후 확장 | — |
| 31 | Cross-spec BM25 검색 (learnings.json 조회) | 인덱스 규모 확보 후 재검토 | — |
| 32 | dhh-rails / kieran-* persona-as-code 문체 | 평가자 페르소나 스타일링은 MVP 불필요 | — |
| — | qa-judge 회색지대 **자동** Consensus | v2 §10.3 명시 2차 | — |
| — | `/orchestrate` C (외부 플러그인 감지·위임) | v2 §10.3 명시 2차 | — |
| — | `skill-rules.json` 이전 | v2 §10.3 명시 2차 | — |
| — | 글로벌 `~/.claude/memory/` 완전 교차 오염 방지 | v2 §9.2 명시 2차 | — |

---

## 2. 자산별 상세 매트릭스 (Top-32 전수)

### P0 — 즉시 포팅 (#1~7)

| # | 자산 | 원본 경로 | 우리 위치 | 상류 커밋 해시 | sync 주기 | 재작성 필요 | 주차 | 태스크 ID | 라이선스 | MIT 호환 |
|---|------|-----------|----------|--------------|----------|-------------|------|-----------|---------|---------|
| 1 | verify 6-에이전트 스택 | hoyeon `agents/{verifier,verification-planner,verify-planner,qa-verifier,ralph-verifier,spec-coverage}.md` | `agents/verify/` | `4a4e0f3` | 분기 | ✗ | W4 | T-W4-02 | **MIT** (hoyeon, © 2026 team-attention) | ✅ |
| 2 | Ralph Loop 의사코드 (non-blocking + level-based polling) | ouroboros `skills/ralph/SKILL.md:50-99` | `skills/verify/` 본문 | `23426b5` | 분기 | ✗ | W4 | T-W4-04 | **MIT** (ouroboros, © 2025 Q00) | ✅ |
| 3 | qa-judge JSON 스키마 (0.80/0.40 임계값) | ouroboros `agents/qa-judge.md` | `agents/evaluator/qa-judge.md` | `23426b5` | 분기 | ✗ | W4 | T-W4-03 | **MIT** (ouroboros) | ✅ |
| 4 | session-wrap 2-Phase 파이프라인 (4 병렬 + 1 순차 + AskUserQuestion) | p4cn `session-wrap/` 전체 | `skills/compound/` 전체 뼈대 | `7895a58` | 반기 | ✗ | W6 | T-W6-02 | **MIT** (p4cn, © 2025 Team Attention) | ✅ |
| 5 | `validate_prompt` frontmatter + `PostToolUse[Task\|Skill]` 훅 | hoyeon `CLAUDE.md:27-44` + `validate-output.sh` | `skills/*/SKILL.md` frontmatter + `hooks/validate-output.sh` | `4a4e0f3` | 분기 | ✗ | W2 | T-W2-05, T-W2-06 | **MIT** (hoyeon) | ✅ |
| 6 | SessionStart 훅 + `using-harness.md` 주입 | superpowers `hooks/session-start` | `hooks/session-start` + `skills/using-harness/` | `b557648` | 반기 | ✗ | W1 | T-W1-04, T-W1-05 | **MIT** (superpowers, © 2025 Jesse Vincent) | ✅ |
| 7 | HARD-GATE 태그 패턴 | superpowers `brainstorming/SKILL.md:12-14` | 각 스킬 본문 (전환점) | `b557648` | 반기 | ✗ | W2 | T-W2-10 | **MIT** (superpowers) | ✅ |

### P1 — 구조 차용 (#8~16)

| # | 자산 | 원본 경로 | 우리 위치 | 상류 커밋 해시 | sync 주기 | 재작성 필요 | 주차 | 태스크 ID | 라이선스 | MIT 호환 |
|---|------|-----------|----------|--------------|----------|-------------|------|-----------|---------|---------|
| 8 | 3단 Evaluator (implementer/spec-reviewer/code-quality) | superpowers `subagent-driven-development/*-prompt.md` | `agents/evaluator/` 2·3단 | `b557648` | 반기 | ✗ | W4 | T-W4-02 (부분) | **MIT** (superpowers) | ✅ |
| 9 | Always-on + Conditional 페르소나 | CE `ce-code-review` (17 페르소나) | `/verify` 6축 always-on + 도메인 conditional | `b575e49` | 연 | ✗ | W4 | T-W4-01 | **MIT** (CE, © 2025 Every) | ✅ |
| 10 | 4단계 머지/dedup 파이프라인 (fingerprint + confidence gate + cross-reviewer +0.10) | CE `ce-code-review` Stage 5 | Evaluator 여러 관점 합성 | `b575e49` | 연 | ✗ | W7.5 (측정) | T-W7.5-04 | **MIT** (CE) | ✅ |
| 11 | 3단 검증 파이프라인 (Mechanical $0 → Semantic $$ → Consensus $$$$) + Stage 3 6트리거 | ouroboros `agents/evaluator.md` | `/verify --deep` 확장 | `23426b5` | 분기 | ✗ | **2차** | — | **MIT** (ouroboros) | ✅ |
| 12 | Host UI payload + Wait cursor bucket | agent-council `council-job.js:179-258, 515-650` | `/orchestrate` 6축 진행 시각화 | `79a13ee` | 연 | ✗ | W7 `[Stretch]` | T-W7-03 | **MIT** (agent-council, © 2024 Team Attention) | ✅ |
| 13 | Charter Preflight 5줄 블록 | hoyeon `agents/_shared/charter-preflight.md` | `agents/_shared/charter-preflight.md` | `4a4e0f3` | 분기 | ✗ | W4 | T-W4-02 (부속) | **MIT** (hoyeon) | ✅ |
| 14 | clarify 3-lens (vague/unknown/metamedium + 3-Round depth) | p4cn `clarify/skills/*` | `skills/brainstorm/` 본문 내장 | `7895a58` | 반기 | ✗ | W2 | T-W2-02 | **MIT** (p4cn) | ✅ |
| 15 | Model Tiering (Orchestrator / Subagent / Validator) | CE ce-code-review Stage 4 + superpowers `subagent-driven-development:87-100` | 전체 서브에이전트 호출 정책 | `b575e49`+`b557648` | 연+반기 | ✗ | W3 | T-W3-02 | **MIT** (CE + superpowers) | ✅ |
| 16 | hoyeon 3-Axis 실행 조합 (dispatch × work × verify = 9) | hoyeon `/execute` | `/orchestrate` 실행 전략 선택 | `4a4e0f3` | 분기 | ✗ | W7 `[Stretch]` | T-W7-04 | **MIT** (hoyeon) | ✅ |

### P2 — 알고리즘·수치 차용 (#17~26)

| # | 자산 | 원본 경로 | 우리 위치 | 상류 커밋 해시 | sync 주기 | 재작성 필요 | 주차 | 태스크 ID | 라이선스 | MIT 호환 |
|---|------|-----------|----------|--------------|----------|-------------|------|-----------|---------|---------|
| 17 | Mandatory Disk Checkpoints CP-0~CP-5 (experiment-log.yaml) | CE `ce-optimize` Persistence Discipline | `/orchestrate` 장기 실행 내구성 | `b575e49` | 연 | ✗ | W7 `[Stretch]` | T-W7-05 | **MIT** (CE) | ✅ |
| 18 | 5-dimension overlap scoring (problem/cause/solution/files/prevention) + High/Moderate/Low | CE `ce-compound` Related Docs Finder | `/compound` 승격 게이트 drift 판정 | `b575e49` | 연 | ✗ | W5 | T-W5-05 | **MIT** (CE) | ✅ |
| 19 | Auto Memory supplementary block ("additional context, not primary evidence") | CE `ce-compound` Phase 0.5 | MEMORY.md 계층 규약 | `b575e49` | 연 | ✗ | W5 | T-W5-02 | **MIT** (CE) | ✅ |
| 20 | Ambiguity Score Gate (0.2) + Drift 임계값 (0.15/0.30) | ouroboros `README.ko.md:210-230, skills/status:79-85` | `/plan` 시작 + 승격 게이트 수치 | `23426b5` | 분기 | ✗ | W3 | T-W3-05 | **MIT** (ouroboros) | ✅ |
| 21 | Seed YAML 스키마 (goal / AC / evaluation_principles+weight / exit_conditions / parent_seed_id) | ouroboros `.ouroboros/seeds/*.yaml` | `/plan` 산출물 frontmatter | `23426b5` | 분기 | ✗ | W3 | T-W3-03 | **MIT** (ouroboros) | ✅ |
| 22 | 병리 패턴 감지 4종 (stagnation/oscillation/repeated-feedback/hard-cap) | ouroboros `README.ko.md:249-257` | `/compound` 과적합 방지 | `23426b5` | 분기 | ✗ | W6 → W7.5 이월 | T-W6-09 / T-W7.5-06 | **MIT** (ouroboros) | ✅ |
| 23 | Rulph 다중 모델 병렬 평가 (Codex+Gemini+Claude, per-criterion floor + threshold) | hoyeon `skills/rulph/SKILL.md` | Evaluator 편향 승격 게이트 | `4a4e0f3` | 분기 | ✗ | **2차** (KU-4 의존) | — | **MIT** (hoyeon) | ✅ |
| 24 | Bug track vs Knowledge track 스키마 분기 (`What Didn't Work` 포함) | CE `ce-compound` schema.yaml | `corrections/` vs `tacit/` 매핑 | `b575e49` | 연 | ✗ | W5 | T-W5-04 | **MIT** (CE) | ✅ |
| 25 | history-insight 세션 로그 파서 (경로 인코딩 · jq 배치 · split+병렬) | p4cn `history-insight/scripts/*.sh` | `scripts/extract-session.sh` | `7895a58` | 반기 | ○ jq 패턴 통일 | W1 | T-W1-06 | **MIT** (p4cn) | ✅ |
| 26 | session-analyzer Expected vs Actual 비교 테이블 | p4cn `session-analyzer/SKILL.md` Phase 5 | `/verify` 스코어링 엔진 골격 | `7895a58` | 반기 | ✗ | W6 | T-W6-02 (부속) | **MIT** (p4cn) | ✅ |

### P3 — 선택·실험 (#27~32)

| # | 자산 | 원본 경로 | 우리 위치 | 상류 커밋 해시 | sync 주기 | 재작성 필요 | 주차 | 태스크 ID | 라이선스 | MIT 호환 |
|---|------|-----------|----------|--------------|----------|-------------|------|-----------|---------|---------|
| 27 | 4언어 README + `--lang ko` 플래그 | hoyeon `README.{md,ko,zh,ja}.md` + `CLAUDE.md` Pre-Release Checklist | `README.md` + `README.ko.md` (MVP 2언어) / `--lang` 2차 | `4a4e0f3` | 분기 | ✗ | W8 (2언어) / **2차** (4언어+플래그) | T-W8-01, T-W8-02 | **MIT** (hoyeon) | ✅ |
| 28 | 마켓플레이스 최소 구조 (plugin.json 없이 marketplace.json만) | agent-council `.claude-plugin/marketplace.json` | `.claude-plugin/marketplace.json` | `79a13ee` | 연 | ✗ | W1 | T-W1-02 | **MIT** (agent-council) | ✅ |
| 29 | llms.txt / llms-full.txt LLM 전용 요약 | ouroboros 루트 | 플러그인 소비자 AI 문서 | `23426b5` | 분기 | ✗ | W8 | T-W8-07 (부속) | **MIT** (ouroboros) | ✅ |
| 30 | writing-skills Skill TDD (RED-GREEN-REFACTOR for docs) | superpowers `writing-skills/SKILL.md:31-45, 376-392` | `/compound` 승격 품질 검증 | `b557648` | 반기 | ✗ | W7.5 (보조) | T-W7.5-04 | **MIT** (superpowers) | ✅ |
| 31 | Cross-spec BM25 검색 (learnings.json 조회) | hoyeon `cli/src/commands/learning.js` + `README.ko.md:112-118` | MEMORY.md 인덱스 검색 | `4a4e0f3` | 분기 | ✗ | **2차** | — | **MIT** (hoyeon) | ✅ |
| 32 | dhh-rails / kieran-* persona-as-code 문체 | CE `agents/review/*` | 6축 evaluator 페르소나 스타일 | `b575e49` | 연 | ✗ | **2차** | — | **MIT** (CE) | ✅ |

### 특수 — 재작성 필수 원본 (P0-1 제약)

| 원본 | 언어 | 우리 재작성 | 태스크 ID | 검증 |
|------|------|-----------|-----------|------|
| ouroboros `drift-monitor.py` | Python | `hooks/drift-monitor.sh` (bash+jq) | T-W4-07 | 원본 파리티 테스트 + Python 런타임 0 assertion |
| ouroboros `keyword-detector.py` | Python | `scripts/keyword-detector.sh` (bash+jq) | T-W6-04 | 원본 파리티 테스트 + Python 런타임 0 assertion |

### 포팅 제외 (v2 §9.1 영구 제외)

| 자산 | 제외 이유 |
|------|----------|
| ouroboros Python 3.14+ 런타임 + SQLite EventStore | 스킬+훅+MCP만 원칙. JSON append로 시작 (P0-1) |
| ouroboros Textual TUI + LiteLLM 멀티 프로바이더 | out of scope |
| superpowers Visual Companion 브라우저 서버 | 복잡도 과다, 1차 제외 |
| superpowers `AGENTS.md → CLAUDE.md` symlink | 미지원 플랫폼 호환성. 1차는 중복 파일 |
| CE "cross-skill 참조 금지" 정책 | 우리는 6축 간 조합이 primary → 반대 정책 |
| hoyeon `cli/` npm 패키지 + 복잡 schema | MVP는 순수 스킬/훅/스크립트 |
| agent-council `clean` 서브커맨드 (증거 삭제) | 반대로 흘려보내는 후크로 변형 |

---

## 3. bash+jq 재작성 리스크 요약 (P0-1)

| 항목 | 리스크 | 완화 |
|------|-------|------|
| drift-monitor.py → drift-monitor.sh | Python 의존 문자열 처리 로직(정규식 · dict 조작)을 jq로 재현 시 정확도 저하 | T-W4-07 파리티 테스트에 원본 Python 기준 input/output pair 최소 10건 포함 |
| keyword-detector.py → keyword-detector.sh | 한국어 키워드 매칭 인코딩 이슈 (UTF-8 NFC/NFD) | jq의 `ascii_downcase` 미지원 → `tr`/`awk` 조합으로 대체하고 NFC 정규화 입력 단계 명시 |
| history-insight 포팅 | 상류가 이미 bash+jq이므로 기술적 재작성 아님 · jq 패턴 방언만 통일 | T-W1-06에서 jq 공통 헬퍼 스크립트 분리 |

---

## 4. 라이선스 호환성 매트릭스 (실측 반영 — user-decisions-5 §4)

### 4.1 6개 상류 라이선스 실측 결과 (2026-04-19 스캔 · **시나리오 A 확정**)

| 상류 | SPDX | Copyright 주체 | 확인 위치 | 호환성 (MIT 배포) | 플래그 |
|------|------|--------------|----------|-------------------|--------|
| hoyeon | **MIT** | © 2026 team-attention | `references/hoyeon/LICENSE` | ✅ 호환 | Green |
| ouroboros | **MIT** | © 2025 Q00 | `references/ouroboros/LICENSE` | ✅ 호환 | Green |
| p4cn (plugins-for-claude-natives) | **MIT** | © 2025 Team Attention | `references/plugins-for-claude-natives/LICENSE` | ✅ 호환 | Green |
| superpowers (obra/superpowers) | **MIT** | © 2025 Jesse Vincent | `references/superpowers/LICENSE` | ✅ 호환 | Green |
| CE (compound-engineering plugin) | **MIT** | © 2025 Every | `references/compound-engineering-plugin/LICENSE` | ✅ 호환 | Green |
| agent-council | **MIT** | © 2024 Team Attention | `references/agent-council/LICENSE` | ✅ 호환 | Green |

**결론**: 6상류 전부 MIT → **시나리오 A** → 본 플러그인 **MIT 확정** (final-spec v3 §4.5.1). GPL 전염 없음. 포팅 대체 경로 불요. 비호환 자산 0건.

### 4.2 3가지 시나리오별 대응 (시나리오 A 발동 / B·C는 미래 포팅 확장 대비 참조)

**시나리오 A: 전부 MIT/Apache-2.0** — **본 프로젝트 적용** ✅
- 본 플러그인 라이선스: **MIT** 확정 (Apache-2.0 NOTICE 조항 회피 + Claude Code 생태계 일관)
- 각 상류 저작권 고지: `NOTICES.md` 단일 파일에 6건 일괄 수록 (T-W8-PRE-02)

**시나리오 B: 일부 GPL 전염** — **현 시점 미발동**. 미래 상류 추가 시 발동 조건
- GPL 상류 자산은 **포팅 제외** 또는 본 플러그인 전체 GPL 라이선스 선택
- 해당 자산 final-spec §6 테이블·§9.1 Non-Goals로 이동 + 대안 (알고리즘만 참조)

**시나리오 C: 라이선스 부재 (All Rights Reserved)** — **현 시점 미발동**
- 해당 상류는 **포팅 불가**. 원저자 연락 또는 알고리즘만 참조 (문헌 인용)
- W0 게이트 판정에서 differentiator 재평가 요인

### 4.3 잔여 확인 체크리스트 (T-W8-PRE-02 실행 항목)

- [x] 6개 상류 각각 `LICENSE` 파일 확인 (2026-04-19 완료 · 전부 MIT)
- [x] 각 상류 `LICENSE` 파일의 git commit hash 스냅샷 기록 (2026-04-20 · T-W8-PRE-02 완료): hoyeon `4a4e0f3` · ouroboros `23426b5` · p4cn `7895a58` · superpowers `b557648` · CE `b575e49` · agent-council `79a13ee`
- [x] SPDX identifier 확정: **전부 `MIT`** (본 플러그인 포함)
- [x] 본 플러그인 `LICENSE` 파일 작성 (MIT 원문) + `NOTICES.md` 6 저작권 고지 기재 (T-W8-07)
- [x] 라이선스 호환 불가 자산 유무 점검 → **0건** (시나리오 A)

---

## 5. 상류 sync 주기 제안 (T-W8-PRE-02 확정 대상)

| 상류 | 의존 강도 | 제안 sync 주기 | 근거 |
|------|----------|-------------|------|
| ouroboros | 높음 (qa-judge · Ralph Loop · Seed YAML) | **분기 1회** | 핵심 평가 엔진 변화 추적 |
| hoyeon | 높음 (validate_prompt · verify 6-에이전트) | **분기 1회** | 훅 패턴 변화 추적 |
| p4cn | 중간 (session-wrap · clarify · history-insight) | **반기 1회** | 알고리즘 안정적 |
| superpowers | 중간 (SessionStart · HARD-GATE · 3단 Evaluator) | **반기 1회** | 패턴 안정적 |
| CE plugin | 낮음 (5-dim overlap · Auto Memory 규약) | **연 1회** | 알고리즘만 참조 |
| agent-council | 낮음 (marketplace 구조 · Wait cursor) | **연 1회** | 구조 안정적 |

---

## 6. 포팅 진행 상태 추적 체크리스트 (각 주차 완료 시 갱신)

| # | 자산 | 주차 | 상태 |
|---|------|------|------|
| 1 | verify 6-에이전트 스택 | W4 | ☐ 미착수 |
| 2 | Ralph Loop 의사코드 | W4 | ☐ 미착수 |
| 3 | qa-judge 스키마 | W4 | ☐ 미착수 |
| 4 | session-wrap 2-Phase | W6 | ☐ 미착수 |
| 5 | validate_prompt + PostToolUse | W2 | ☐ 미착수 |
| 6 | SessionStart + using-harness | W1 | ☐ 미착수 |
| 7 | HARD-GATE 태그 | W2 | ☐ 미착수 |
| 8 | 3단 Evaluator | W4 | ☐ 미착수 |
| 9 | Always-on + Conditional | W4 | ☐ 미착수 |
| 10 | 4단계 머지/dedup | W7.5 (측정) | ☐ 미착수 |
| 11 | 3단 검증 파이프라인 | 2차 | ⏸ 2차 연기 |
| 12 | Host UI payload + Wait cursor | W7 `[Stretch]` | ☐ 미착수 |
| 13 | Charter Preflight | W4 | ☐ 미착수 |
| 14 | clarify 3-lens | W2 | ☐ 미착수 |
| 15 | Model Tiering | W3 | ☐ 미착수 |
| 16 | hoyeon 3-Axis | W7 `[Stretch]` | ☐ 미착수 |
| 17 | Mandatory Disk Checkpoints | W7 `[Stretch]` | ☐ 미착수 |
| 18 | 5-dim overlap scoring | W5 | ☐ 미착수 |
| 19 | Auto Memory supplementary | W5 | ☐ 미착수 |
| 20 | Ambiguity Gate + Drift 임계 | W3 | ☐ 미착수 |
| 21 | Seed YAML 스키마 | W3 | ☐ 미착수 |
| 22 | 병리 패턴 감지 4종 | W6 → W7.5 이월 | ☐ 미착수 |
| 23 | Rulph 3모델 병렬 평가 | 2차 | ⏸ 2차 연기 |
| 24 | Bug vs Knowledge track | W5 | ☐ 미착수 |
| 25 | history-insight 파서 | W1 | ☐ 미착수 |
| 26 | session-analyzer 비교 테이블 | W6 | ☐ 미착수 |
| 27 | 4언어 README + --lang ko | W8 (2언어) / 2차 (4언어+플래그) | ☐ 미착수 |
| 28 | marketplace 최소 구조 | W1 | ☐ 미착수 |
| 29 | llms.txt | W8 | ☐ 미착수 |
| 30 | writing-skills Skill TDD | W7.5 (보조) | ☐ 미착수 |
| 31 | Cross-spec BM25 검색 | 2차 | ⏸ 2차 연기 |
| 32 | dhh-rails/kieran persona-as-code | 2차 | ⏸ 2차 연기 |

**MVP 경로 포팅 건수: 25개** · **2차 연기: 7개** · **MVP 내 `[Stretch]`: 3개**

---

*Top-32 전수 배정 + bash+jq 재작성 리스크 + 라이선스 실측 매트릭스 (2026-04-19 시나리오 A 확정 · 전부 MIT · 본 플러그인 MIT 채택). 잔여 작업(상류 커밋 해시·LICENSE/NOTICES 파일 작성)은 T-W8-PRE-02.*

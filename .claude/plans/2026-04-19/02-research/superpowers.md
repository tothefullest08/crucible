# Phase 2 레퍼런스 리서치 — `references/superpowers`

> Jesse Vincent(obra) 의 Superpowers v5.0.7 — Claude Code·Codex·Cursor·Gemini·Copilot·OpenCode 멀티 하네스용 핵심 스킬 라이브러리.
> **하네스 플러그인 설계 관점(UK, "이미 가진 자산")에서 본 분석 — 한국어 전량 기술.**

- **작성일**: 2026-04-19
- **분석 대상 경로**: `/Users/ethan/Desktop/personal/harness/references/superpowers`
- **버전**: `5.0.7` (plugin.json)
- **라이선스**: MIT
- **포지셔닝**: "A complete software development methodology for your coding agents" — 범용 범프로젝트 합일 플러그인(오픈소스 배포형)

---

## 0. TL;DR — 한 눈에 보기

1. **브레인스토밍 → 쓰기 계획 → 실행 → 리뷰 → 마무리의 "강제 파이프라인"** 이 프론트매터 `description` 필드와 `<HARD-GATE>` 태그로 하드코딩되어 있다. 사람 승인 없이는 다음 스킬로 못 넘어간다.
2. **Generator vs Evaluator 분리**가 `subagent-driven-development` 안에 명시적으로 구현됨 — Implementer 서브에이전트 / Spec Reviewer 서브에이전트 / Code Quality Reviewer 서브에이전트 **3단 분리**.
3. **SessionStart 훅**으로 `using-superpowers` SKILL 내용을 매 세션 자동 주입해서 "스킬을 꼭 써라" 라는 규율을 세션 첫 턴부터 강제한다.
4. 한국어 지원은 **없음**(설명/템플릿 전부 영문). 대신 멀티 하네스(Cursor / Codex / Gemini / Copilot / OpenCode) 이식 레이어가 탄탄해서 **포팅 시 한국어 레이어를 덧붙이면 됨**.
5. 우리 하네스 플러그인 관점 최고 가치: **HARD-GATE 패턴 + 3단 리뷰 템플릿 + SessionStart 훅 주입 + writing-skills의 SKILL description 룰** — 이 4개는 거의 그대로 포팅 가능.

---

## 1. 디렉토리 구조

### 1.1 루트 레벨
```
references/superpowers/
├── .claude-plugin/
│   ├── plugin.json           (name=superpowers, v5.0.7, MIT)
│   └── marketplace.json      (marketplace name: superpowers-dev)
├── .cursor-plugin/           (Cursor 대응 심볼릭 변환)
├── .codex/                   (Codex 대응)
├── .opencode/                (OpenCode 대응)
├── .github/
│   ├── FUNDING.yml
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── AGENTS.md  →  CLAUDE.md (symlink)     ← 멀티 하네스 호환용 심볼릭
├── GEMINI.md                              ← Gemini 전용 컨텍스트
├── CLAUDE.md                              ← 메인 기여 가이드(94% PR 거절률 경고)
├── README.md
├── RELEASE-NOTES.md                       (58KB — 매우 상세)
├── CODE_OF_CONDUCT.md
├── package.json                           (버전 관리용, 의존성 0)
├── gemini-extension.json                  (Gemini 확장 매니페스트)
├── agents/
│   └── code-reviewer.md                   (단 하나의 에이전트)
├── commands/
│   ├── brainstorm.md                      (deprecated — skill로 대체)
│   ├── write-plan.md                      (deprecated)
│   └── execute-plan.md                    (deprecated)
├── hooks/
│   ├── hooks.json                         (SessionStart 훅 등록)
│   ├── hooks-cursor.json
│   ├── run-hook.cmd                       (크로스플랫폼 셸 런처)
│   └── session-start                      (bash — using-superpowers 자동 주입)
├── skills/                                (14개 스킬, 각 디렉토리 단위)
│   ├── brainstorming/
│   ├── dispatching-parallel-agents/
│   ├── executing-plans/
│   ├── finishing-a-development-branch/
│   ├── receiving-code-review/
│   ├── requesting-code-review/
│   ├── subagent-driven-development/
│   ├── systematic-debugging/
│   ├── test-driven-development/
│   ├── using-git-worktrees/
│   ├── using-superpowers/                 (세션 시작 주입용)
│   ├── verification-before-completion/
│   ├── writing-plans/
│   └── writing-skills/                    (메타 스킬 — "스킬 만드는 스킬")
├── docs/                                  (플랫폼별 설치 가이드 + testing.md)
├── scripts/                               (유틸)
└── tests/                                 (스킬 테스트 셋)
```

### 1.2 `.claude-plugin/plugin.json`
```json
{
  "name": "superpowers",
  "description": "Core skills library for Claude Code: TDD, debugging, collaboration patterns, and proven techniques",
  "version": "5.0.7",
  "author": {"name": "Jesse Vincent", "email": "jesse@fsck.com"},
  "keywords": ["skills","tdd","debugging","collaboration","best-practices","workflows"]
}
```

### 1.3 스킬 디렉토리 규약 (4가지 형태)
`skills/writing-skills/SKILL.md:348-373` 에 명시된 규약:

| 형태 | 구성 | 사례 |
|------|------|------|
| **Self-Contained** | `SKILL.md` 만 | `verification-before-completion/`, `dispatching-parallel-agents/` |
| **SKILL + 재사용 툴** | `SKILL.md` + 예제 스크립트/템플릿 | `brainstorming/` (scripts + visual-companion.md + spec-document-reviewer-prompt.md) |
| **SKILL + 레퍼런스** | `SKILL.md` + 대용량 레퍼런스 md | `writing-skills/` (anthropic-best-practices.md 45KB + persuasion-principles.md 등) |
| **Heavy SKILL** | SKILL.md + 여러 reviewer 프롬프트 템플릿 | `subagent-driven-development/` (3개 프롬프트 템플릿 분리) |

### 1.4 핵심 관찰
- 루트 `commands/` 은 **deprecated 전용** — 모든 트리거를 **skill 자동 감지**로 일원화
- 에이전트는 단 1개(`code-reviewer.md`) — 나머지는 **Task 도구로 ad-hoc 서브에이전트 디스패치**
- 훅은 1개(`SessionStart`) — 세션 시작 시 `using-superpowers` SKILL을 **무조건** 컨텍스트 주입
- "멀티 하네스" 전략: 같은 SKILL 내용을 Claude Code / Cursor / Codex / Gemini / Copilot / OpenCode 6개 플랫폼에서 작동하게 디렉토리만 분기 (`.claude-plugin`, `.cursor-plugin`, `.codex`, `.opencode`, `gemini-extension.json`)

---

## 2. SKILL.md 프론트매터 패턴

### 2.1 필수 필드 (`skills/writing-skills/SKILL.md:95-103`)
```yaml
---
name: Skill-Name-With-Hyphens
description: Use when [specific triggering conditions and symptoms]
---
```

- **필수 2필드**: `name`, `description`
- **최대 크기**: 1024자 (전체 frontmatter)
- `name`: 영문+숫자+하이픈 전용 (괄호/특수문자 금지)
- `description`: 500자 이내 권장

### 2.2 description 최적화 — **"트리거 전용, 워크플로 요약 금지"**

`writing-skills/SKILL.md:140-197` 은 description 설계를 깊이 있게 다룬다. 핵심 발견:

> **"description이 workflow를 요약하면 Claude가 full content를 안 읽고 description만 따라 한다."**

실험 결과(인용):
- ❌ `"Use when executing plans - dispatches subagent per task with code review between tasks"` → Claude가 **1회 리뷰만** 수행 (skill에 명시된 2단계 리뷰 무시)
- ✅ `"Use when executing implementation plans with independent tasks in the current session"` → Claude가 **본문 플로우차트까지 읽고 2단계 리뷰 수행**

**결론:** description = **When to Use**, NOT What the Skill Does.

### 2.3 description 스타일 3원칙 (반복 등장)
1. **"Use when ..." 로 시작** — 13개 스킬 중 12개가 이 패턴을 따름
2. **3인칭, 일반 현재형** — "I can help ..." 같은 1인칭 금지
3. **증상/상황/맥락 키워드 포함** — Claude가 내부 검색으로 찾아야 하므로 에러 메시지·symptom·synonym 을 풍부하게 (CSO = Claude Search Optimization)

### 2.4 실제 description 예시 (전수 조사)

| 스킬 | description |
|------|-----|
| brainstorming | "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation." |
| writing-plans | "Use when you have a spec or requirements for a multi-step task, before touching code" |
| subagent-driven-development | "Use when executing implementation plans with independent tasks in the current session" |
| executing-plans | "Use when you have a written implementation plan to execute in a separate session with review checkpoints" |
| test-driven-development | "Use when implementing any feature or bugfix, before writing implementation code" |
| verification-before-completion | "Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always" |
| systematic-debugging | "Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes" |
| requesting-code-review | "Use when completing tasks, implementing major features, or before merging to verify work meets requirements" |
| receiving-code-review | "Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable - requires technical rigor and verification, not performative agreement or blind implementation" |
| dispatching-parallel-agents | "Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies" |
| using-git-worktrees | "Use when starting feature work that needs isolation from current workspace or before executing implementation plans - creates isolated git worktrees with smart directory selection and safety verification" |
| finishing-a-development-branch | "Use when implementation is complete, all tests pass, and you need to decide how to integrate the work ..." |
| using-superpowers | "Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions" |
| writing-skills | "Use when creating new skills, editing existing skills, or verifying skills work before deployment" |

패턴 정리:
- 13/14 이 `"Use when ..."` 로 시작
- 1개(`brainstorming`) 만 `"You MUST use this before ..."` — 제일 중요한 게이트 스킬이라 더 강제적 문구
- 5개는 " - " 뒤에 **"왜 중요한지/무엇을 요구하는지"** 짧은 rationale 추가 (`verification-before-completion`, `receiving-code-review`, `using-git-worktrees`, `finishing-a-development-branch`, `using-superpowers`)

### 2.5 본문 구조 표준 (`writing-skills/SKILL.md:104-137`)
```
# Skill Name
## Overview          ← 1-2문장 core principle
## When to Use       ← (optional) 작은 flowchart + 리스트
## The Iron Law      ← (discipline skill만) 깨지지 않는 단 하나의 규칙
## Core Pattern      ← before/after 코드 비교
## Quick Reference   ← 테이블/리스트
## Implementation    ← 인라인 코드 또는 파일 링크
## Common Mistakes / Red Flags
## Real-World Impact (선택)
```

### 2.6 다국어(한국어) 지원 — **없음**
- README·SKILL·hooks·모든 프롬프트가 **영문 전용**
- description도 영문 트리거 키워드만 — 한국어 트리거("브레인스토밍", "계획 세우기") 없음
- `GEMINI.md`·`AGENTS.md` 같은 **플랫폼별 분기는 있지만 언어별 분기는 없음**
- 즉 **한국어 최적화는 우리 플러그인의 순수 차별점이 될 수 있음** (UU 위험 제외하면)

---

## 3. 핵심 워크플로우

### 3.1 "The Basic Workflow" — 7단 강제 파이프라인 (`README.md:119-136`)

```
1. brainstorming          (brainstorming/SKILL.md)
   ↓
2. using-git-worktrees
   ↓
3. writing-plans
   ↓
4. subagent-driven-development  or  executing-plans
   ↓
5. test-driven-development      (4번 서브에이전트가 자동 호출)
   ↓
6. requesting-code-review
   ↓
7. finishing-a-development-branch
```

각 스킬의 description 맨 앞 "Use when ..." 자체가 **다음 단계 진입 조건**을 강제한다. 이게 하드코드된 파이프라인.

### 3.2 **HARD-GATE 패턴** — `brainstorming/SKILL.md:12-14`
```xml
<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project,
or take any implementation action until you have presented a design and the user
has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>
```

효과:
- 간단한 요청이라도 "design → user approval → writing-plans" 루트를 우회할 수 없다
- "This Is Too Simple" 합리화를 명시적으로 **Anti-Pattern** 으로 규정 (line 16-18)
- 모든 프로젝트가 **동일한 게이트**를 거침 → 작은 프로젝트가 맥락 누락으로 어긋나는 걸 방지

### 3.3 브레인스토밍 워크플로우 상세 (`brainstorming/SKILL.md:21-64`)

9단계 체크리스트(각 단계는 TodoWrite 항목으로 추가):

1. **Explore project context** — 파일·docs·최근 커밋 조회
2. **Offer visual companion** (필요 시) — 별도 메시지로만, 다른 질문 섞지 말 것
3. **Ask clarifying questions** — **한 번에 한 개** 질문, 다중선택 선호
4. **Propose 2-3 approaches** — 추천안과 이유 같이
5. **Present design** — 섹션별로 승인받으며 진행 (각 섹션 복잡도에 맞춰 크기 조절)
6. **Write design doc** — `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` + 커밋
7. **Spec self-review** — placeholder/모순/ambiguity/scope 인라인 체크
8. **User reviews written spec** — 명시적 사용자 리뷰 게이트
9. **Transition to implementation** — `writing-plans` 만 호출 (다른 skill 호출 금지)

설계 원칙:
- **One question at a time** (line 140) — 쏟아붓지 말 것
- **Multiple choice preferred** (line 141) — 답하기 쉬움
- **YAGNI ruthlessly** (line 142) — 불필요 기능 제거
- **Explore alternatives** (line 143) — 항상 2-3 옵션 먼저
- **Incremental validation** (line 144) — 섹션별 승인
- **Be flexible** (line 145) — 막히면 되돌아가기

"해줘"가 아니라 "**물어봐**" — 하네스 day2 lecture의 3축(Planning) "AskUserQuestion 패턴"과 완벽 대응.

### 3.4 Subagent-Driven Development — **Generator/Evaluator 분리의 구현체**

`subagent-driven-development/SKILL.md:41-85` 의 flowchart 가 핵심:

**태스크 단위 3단 구조:**
```
Dispatch implementer subagent (implementer-prompt.md)
   ↓ [implementer가 질문 있으면 answer → re-dispatch]
implementer 실행 → 테스트 → 커밋 → 자가 리뷰
   ↓
Dispatch spec-reviewer subagent (spec-reviewer-prompt.md)
   ↓ [이슈 발견 시 implementer 재호출 → spec-review 재실행]
Spec 적합성 OK?
   ↓
Dispatch code-quality-reviewer subagent (code-quality-reviewer-prompt.md)
   ↓ [이슈 발견 시 implementer 재호출 → quality-review 재실행]
코드 품질 OK?
   ↓
TodoWrite 완료 마킹 → 다음 태스크
```

3 개의 서브에이전트 프롬프트 템플릿 (각각 별도 파일):

| 템플릿 파일 | 역할 | 핵심 문구 |
|------|-----|-----|
| `implementer-prompt.md` | 구현 | "When You're in Over Your Head — It is always OK to stop and say 'this is too hard for me.'" (line 57-73) |
| `spec-reviewer-prompt.md` | 스펙 적합성 | **"CRITICAL: Do Not Trust the Report ... Verify by reading code, not by trusting report."** (line 20-36) |
| `code-quality-reviewer-prompt.md` | 코드 품질 | `requesting-code-review/code-reviewer.md` 재사용 + 파일 책임/경계 체크 |

**Spec Reviewer의 "Do Not Trust" 패턴** 이 하네스 lecture 5축(검증)의 "Evaluator를 회의적으로 튜닝" 원칙의 정확한 구현:
```
The implementer finished suspiciously quickly. Their report may be incomplete,
inaccurate, or optimistic. You MUST verify everything independently.
```

Implementer subagent의 4가지 상태 보고:
- `DONE` — 진행 가능
- `DONE_WITH_CONCERNS` — 완료했지만 의심 있음 (읽고 판단)
- `NEEDS_CONTEXT` — 맥락 부족 (컨트롤러가 제공 후 재디스패치)
- `BLOCKED` — 불가 (moreCapable 모델로 재시도 OR 태스크 분해 OR 사람에게 에스컬레이션)

**Model Selection 룰** (line 87-100):
- 기계적 구현 (1-2 파일, 명세 확실) → **cheap model** (Haiku 유형)
- 통합/판단 요하는 다중 파일 → **standard model** (Sonnet 유형)
- 아키텍처/디자인/리뷰 → **최고 성능 모델** (Opus 유형)

→ 하네스 lecture 5축 "모델도 나누고 역할도 나눈다" 의 정확한 구현.

### 3.5 Verification-Before-Completion — "완료 주장 금지 룰"

`verification-before-completion/SKILL.md:17-21`:
```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

- "Should work now" 같은 말 전면 금지 (Red Flags line 54-62)
- Claim → Requires → Not Sufficient 매트릭스 (line 42-51) 로 "무엇이 증거가 되는가"를 못박음
- Rationalization Prevention 테이블 (line 64-74) — "I'm tired" 도 핑계 못 됨
- 에이전트 위임 결과도 **VCS diff 로 독립 검증** 하라고 명시 (line 102-104)

이건 lecture의 "Evidence over claims" 원칙을 **룰 수준으로 명문화** 한 것.

### 3.6 Writing-Skills — **스킬 TDD**

`writing-skills/SKILL.md:31-45` 의 테이블이 독창적:

| TDD Concept | Skill Creation |
|-------------|----------------|
| Test case | Pressure scenario with subagent |
| Production code | SKILL.md |
| Test fails (RED) | Agent violates rule without skill |
| Test passes (GREEN) | Agent complies with skill |
| Refactor | Close loopholes while maintaining compliance |

**Iron Law**: `NO SKILL WITHOUT A FAILING TEST FIRST` (line 376)

즉 "스킬을 쓰기 전 반드시 서브에이전트로 baseline behavior를 관찰해야 한다" — 스킬 자체가 **경험적 근거 기반**으로 만들어짐. 우리의 UU 우려(체크리스트化)를 방지하는 방법론이 이미 있음.

### 3.7 SessionStart 훅 — "세션 첫 턴에 무조건 주입"

`hooks/session-start` (bash 스크립트):
```bash
using_superpowers_content=$(cat "${PLUGIN_ROOT}/skills/using-superpowers/SKILL.md")
session_context="<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n
**Below is the full content of your 'superpowers:using-superpowers' skill ...**\n\n${using_superpowers_escaped}\n\n
</EXTREMELY_IMPORTANT>"
```

`hooks.json` 에서 `"matcher": "startup|clear|compact"` 로 걸어 **세션 시작 / /clear / /compact 직후** 매번 주입.

효과:
- 세션 첫 턴부터 "스킬 먼저 호출해야 한다" 규율이 시스템 프롬프트 수준에서 적용
- 플랫폼별로 JSON key 가 다름(Claude: `hookSpecificOutput.additionalContext`, Cursor: `additional_context`, Copilot: `additionalContext`) — 한 bash 파일에서 env var 로 분기 처리

`using-superpowers/SKILL.md:10-16` 의 문구가 이 주입의 페이로드:
```
<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing,
you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
</EXTREMELY-IMPORTANT>
```

### 3.8 사용된 디자인 패턴 요약

| 패턴 | 위치 | 하네스 대응축 |
|------|------|---------------|
| **HARD-GATE** (진입/전환 강제 차단) | `brainstorming/SKILL.md:12-14` | 3축(계획), 4축(실행) |
| **Generator/Evaluator 분리** (3단 서브에이전트) | `subagent-driven-development/` 전체 | 5축(검증) |
| **Iron Law** (깨지지 않는 룰 한 개) | TDD, debugging, verification, writing-skills | 전 축 공통 |
| **Red Flags + Rationalization Prevention 테이블** | 거의 모든 discipline 스킬 | 6축(개선 — 실수 패턴 문서화) |
| **SessionStart Context Injection** | `hooks/session-start` | 2축(맥락) — 경계 설정 |
| **멀티 하네스 분기** | `.claude-plugin/.cursor-plugin/.codex/.opencode/gemini-extension.json` | 1축(구조 — Placement) |
| **서브에이전트 프롬프트 템플릿 외부화** | `*-prompt.md` 3개 파일 | 1축(구조), 4축(실행) |
| **Skill TDD (RED-GREEN-REFACTOR for docs)** | `writing-skills/SKILL.md:31-45` | 6축(개선) |
| **Self-Review + User Review 이중 게이트** | `brainstorming/SKILL.md:7-9` 단계 | 3축(계획), 5축(검증) |
| **Status Codes (DONE / CONCERNS / BLOCKED / NEEDS_CONTEXT)** | `implementer-prompt.md:103-113` | 4축(실행), 2축(맥락) |

### 3.9 지원되지 않는 개념들 (없다 = 우리 차별점 여지)

- **Compounding / 개인화 학습** — 없음. Session-wrap / MEMORY.md / 암묵지 저장 개념 자체가 없다.
- **"유저가 틀렸다고 말한 것" 기록** — 없음.
- **스코어링 루프** — TDD의 RED-GREEN 만 있음. Ralph Loop 같은 임계값 반복 없음.
- **한국어 / 다국어** — 없음.
- **6축 강제 메타 스킬** — 없음 (superpowers 자체가 하네스의 일부일 뿐).

---

## 4. 재사용·포팅 가능한 자산 (UK 관점)

### 4.1 그대로 포팅 가능한 자산 (복사 레벨)

| 자산 | 원본 위치 | 우리 쪽 배치 | 수정 범위 |
|------|-----------|------------|-----------|
| **HARD-GATE 태그 패턴** | `brainstorming/SKILL.md:12-14` | 우리 `skills/brainstorm.md`, `skills/plan.md`, `skills/verify.md` 진입부 | 문구만 6축 기준으로 교체 |
| **SessionStart 훅 (using-superpowers 주입)** | `hooks/session-start` + `hooks/hooks.json` | 우리 플러그인 `hooks/` 하위 | 주입 페이로드를 `using-harness.md` (6축 요약)로 교체 |
| **3개 서브에이전트 프롬프트 템플릿** | `subagent-driven-development/*-prompt.md` | 우리 `skills/verify/` 하위 `generator-prompt.md` / `evaluator-prompt.md` | Spec Reviewer 의 "Do Not Trust" 블록 거의 그대로 |
| **Implementer Status Codes** | `implementer-prompt.md:103-113` | 우리 서브에이전트 상태 보고 규약 | 그대로 |
| **SKILL.md 프론트매터 규약 + description 원칙** | `writing-skills/SKILL.md:95-197` | 우리 skill 작성 가이드 | 한국어 트리거 키워드 추가 |
| **checklist + TodoWrite 매핑** | `brainstorming/SKILL.md:21-33` | 우리 6축 스킬 각 체크리스트 | 6축별 체크 항목으로 재작성 |
| **Verification Iron Law + Claim→Evidence 테이블** | `verification-before-completion/SKILL.md` | 우리 `verify/` 스킬 본문 | 스코어링 임계값 개념 추가 |
| **Rationalization Prevention 테이블** | `verification-before-completion:64-74`, `using-superpowers:80-96` | 우리 core 문서 | 한국어 버전 병기 |
| **Red Flags 테이블 형식** | 다수 스킬에 반복 | 우리 각 스킬 | 이름 차용, 내용은 우리 케이스로 |
| **Flowchart dot 형식** | 거의 모든 스킬이 동일한 dot 스타일 | 우리 스킬 | 구조 복붙, 노드 텍스트만 |

### 4.2 구조만 차용 (로직 재설계)

| 자산 | 차용 이유 | 우리 쪽 재설계 포인트 |
|------|----------|-----------------------|
| **9단 brainstorming 체크리스트** | "인터뷰 → propose → present → 문서화 → self-review → user-review → 다음 skill" 구조가 이미 검증됨 | 6축 중 2축(맥락)·3축(계획) 강제 단계 삽입 — 예: "6축 적합성 평가" 를 step 6.5 로 |
| **subagent-driven 3단 리뷰 루프** | Generator/Evaluator 분리의 정석 구현 | 우리 "스코어링 → 실패 시 자체 루프" 에 Evaluator 프롬프트를 적용 (회의적 튜닝 그대로) |
| **멀티 하네스 분기 구조** (`.claude-plugin/.cursor-plugin/.codex/.opencode/`) | 오픈소스 배포 타겟과 정합 | 우선은 `.claude-plugin/` 만, 필요 시 .codex 등 추가 가능 구조로 설계 |
| **`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` 명명 규약** | 날짜-주제 파일명으로 정렬/검색 용이 | 우리 `.claude/memory/tacit/YYYY-MM-DD-<topic>.md` 로 치환 |
| **stat-review dispatcher 프롬프트 구조** | Task tool 호출 템플릿이 깔끔 | 우리 session-wrap/승격 게이트 서브에이전트 디스패치 템플릿 |

### 4.3 우리 플러그인에서의 구체적 재사용 제안

**제안 1 — HARD-GATE를 6축별로 설치**
```xml
<!-- skills/brainstorm.md -->
<HARD-GATE axis="3-planning">
암묵지 해소 인터뷰(ask 단계) 없이 /plan 또는 /verify 로 전환 금지.
유저 승인 메시지 수신 전까지 다음 스킬 invoke 불허.
</HARD-GATE>
```
이유: 원본의 HARD-GATE는 "design → implementation" 한 지점만 막음. 우리는 6축 각각의 **전환 지점**에 동일 패턴을 배치해 "체크리스트化 방지" + "형식만 적용" 을 차단.

**제안 2 — SessionStart 주입 페이로드 교체**
- 원본은 `using-superpowers/SKILL.md` 주입
- 우리는 `using-harness.md` (6축 한 줄 요약 + "1% 라도 해당되면 반드시 axis-skill 호출" 규약) 를 주입
- 한국어 사용자 감지 시 `using-harness.ko.md` 분기 (LANG env 또는 CLAUDE.md 내 선언)

**제안 3 — Evaluator 3단을 "검증 루프 + 승격 게이트" 에 이식**
- Implementer → Spec Reviewer → Code Quality Reviewer 3단을
- Generator → **6축 적합성 평가자** → **승격 게이트(암묵지/룰/스킬 저장 판정)** 3단으로 재사용
- 2번째 evaluator 의 "Do Not Trust" 문구는 **그대로** 재사용 (하네스 5축 "Evaluator 회의적 튜닝" 직접 대응)

**제안 4 — writing-skills 의 Skill TDD를 우리 `skills/compound.md` 에 적용**
- 승격된 룰/스킬을 **반드시 RED-GREEN 테스트**로 검증
- "승격 후 철회율 < 10%" KU 실험 기준과 직결 (Phase 1 clarified-spec 참조)

**제안 5 — Writing-Skills description 룰 준수**
- 우리 스킬 description 에 워크플로를 요약하지 말 것
- 한국어 트리거("브레인스토밍", "계획", "검증", "컴파운딩", "6축") 를 포함하되 **한국어만 고수하지 말 것** — description 내부는 영어+한국어 혼용이 검색 최적화 측면에서 유리 (원본은 영문만 지원하므로 이건 우리가 추가로 실험해야 함)

### 4.4 포팅하지 말 것 (위험 / 불일치)

- **Visual Companion** 브라우저 서버 (`brainstorming/scripts/`) — 고정 localhost 서버 + HTML 프레임, 오픈소스 배포 시 복잡도 과다. 1차 릴리즈는 제외.
- **"zero-dependency" 원칙** 을 우리도 그대로 답습할 필요는 없음. 우리는 `.claude/memory/` 쓰기가 필수. 다만 **외부 서비스 의존성은 배제**라는 기조만 차용.
- **94% PR 거절률 톤** — superpowers는 기여 차단을 위한 강경 가이드라인. 우리는 오픈소스 커뮤니티 확장이 목표라면 환영형 가이드라인으로 (다만 "fabricated content 금지", "one problem per PR" 원칙은 차용).
- **`AGENTS.md → CLAUDE.md` symlink** — 멀티 하네스 미지원 플랫폼에서 깨질 수 있음. 1차는 중복 파일로, 2차에서 symlink 고려.

---

## 5. 6축 매핑

### 5.1 Superpowers 기능 ↔ 하네스 6축 매트릭스

| Superpowers 기능 | 1 구조 | 2 맥락 | 3 계획 | 4 실행 | 5 검증 | 6 개선 |
|------|:---:|:---:|:---:|:---:|:---:|:---:|
| `.claude-plugin/plugin.json` + 멀티 하네스 분기 | ●●● | · | · | · | · | · |
| 14 스킬 디렉토리 규약 (self-contained / + tool / + ref) | ●●● | ● | · | · | · | · |
| `SessionStart` 훅으로 `using-superpowers` 주입 | · | ●●● | · | · | · | · |
| SKILL frontmatter description = "Use when ..." (CSO) | · | ●●● | ● | · | · | · |
| `brainstorming/` 9단 체크리스트 | · | ●● | ●●● | · | ● | · |
| `<HARD-GATE>` 태그 (design → plan 전환 차단) | · | · | ●●● | ● | · | · |
| `writing-plans/` bite-sized task + 파일 구조 설계 | · | · | ●●● | ● | · | · |
| `subagent-driven-development/` 3단 서브에이전트 | · | ●● | · | ●●● | ●●● | · |
| `implementer-prompt.md` DONE/CONCERNS/BLOCKED 상태 | · | ● | · | ●●● | ● | · |
| `spec-reviewer-prompt.md` "Do Not Trust" | · | · | · | · | ●●● | · |
| `code-quality-reviewer-prompt.md` | · | · | · | · | ●●● | · |
| `verification-before-completion/` Iron Law | · | · | · | ● | ●●● | · |
| `test-driven-development/` RED-GREEN-REFACTOR | · | · | · | ●●● | ●●● | · |
| `systematic-debugging/` 4-phase root cause | · | ● | · | ●● | ●●● | · |
| `dispatching-parallel-agents/` | · | ●● | · | ●●● | · | · |
| `using-git-worktrees/` 격리 | ●● | · | · | ●●● | ● | · |
| `finishing-a-development-branch/` 4-option gate | · | · | · | ●● | ●●● | · |
| `requesting-code-review/` + `receiving-code-review/` | · | · | · | ● | ●●● | · |
| `writing-skills/` Skill TDD + 평가 프레임 | ●●● | · | · | · | ●● | ●●● |
| Red Flags / Rationalization Prevention 테이블 | · | ● | · | ● | ●● | ●●● |
| Model Selection 룰 (cheap/standard/most-capable) | · | · | · | ●●● | ● | · |

범례: ●●● 강하게 대응 / ●● 부분 대응 / ● 간접 기여 / · 해당 없음

### 5.2 축별 축약 평가

- **1 구조** : 디렉토리 규약·멀티 하네스 분기·스킬 파일 구조 표준 — **강함**. 그대로 차용.
- **2 맥락** : SessionStart 훅 주입·SKILL description CSO — **중간+**. 승격 게이트 / 맥락 격리 개념은 우리가 추가해야.
- **3 계획** : brainstorming·writing-plans 의 HARD-GATE + 9단 체크리스트 — **강함**. 우리 브레인스토밍/계획 스킬의 뼈대로.
- **4 실행** : subagent-driven-development 의 3단 + Model Selection + worktree 격리 — **매우 강함**. 거의 완성도 있는 레퍼런스.
- **5 검증** : spec/quality reviewer 분리, Verification Iron Law, TDD — **매우 강함**. **Generator/Evaluator 분리의 모범 구현**.
- **6 개선** : writing-skills 의 Skill TDD + Red Flags 문서화 — **부분적**. **Compounding(학습 저장·재활용) 개념은 없음**. 이건 우리의 고유 영역.

### 5.3 6축 관점 강점 vs 결손

**강점 (우리가 가져올 것):**
- 3·4·5축은 superpowers가 이미 **production-ready** 수준. 포팅 안 하면 오히려 손해.
- 디자인 패턴(HARD-GATE, Iron Law, Red Flags) 이 6축 전반에 재사용 가능.

**결손 (우리가 메울 곳):**
- **6축(개선)** 에 "Compounding = 세션 → 학습 → 저장 → 재활용" 개념이 통째로 비어 있음. 이 부분은 hoyeon / ouroboros / team-attention 레퍼런스가 채울 영역 (본 분석 범위 아님).
- **2축(맥락)** 에서 `MEMORY.md` 인덱스 / 승격 게이트 / 암묵지 포맷이 없음. auto-memory 시스템 참조 필요.
- **1축(구조)** 에서 "사람 문서 vs AI 문서 분리(.dev/ 구조)" 개념이 없음 — Jesse 는 `docs/superpowers/` 한 디렉토리로 단일화 (우리는 하네스 day2 철학에 맞춰 분리 유지).

---

## 6. 차별점 매핑 (4가지 관점 평가)

### 6.1 기존 도구 오케스트레이션
- **위치**: **독립형** — 다른 플러그인에 의존하지 않고 자체 완결적인 14 스킬 체인.
- **외부 의존**: zero (CLAUDE.md에 "zero-dependency plugin by design" 명문화, PR 거절 기준 1번).
- **다른 도구 통합**: Task tool / Skill tool / TodoWrite / Bash 등 **Claude Code 내장 툴만** 사용. MCP 외부 서버·외부 API 없음.
- **우리 플러그인 관점**: superpowers 는 **오케스트레이션 대상이 아니라 통합 대상** — 우리가 만들 `/orchestrate` 가 superpowers 의 `brainstorming → writing-plans → subagent-driven-development` 를 **6축 강제 레이어 밑에서 호출** 하는 구조가 자연스럽다.

### 6.2 하네스 6축 강제
- **명시적 6축 강제**: **없음**. Superpowers는 하네스 day2 lecture 이전에 만들어진 범용 플러그인.
- **암묵적 대응**: 위 5.1 매트릭스가 보여주듯 4/5/6축 일부는 실질적으로 커버. 그러나 **"6축 중 어느 축을 지금 다루고 있는가" 를 메타인지하는 메커니즘은 없음**.
- **결론**: 6축 강제는 **순수 우리 차별점**. Superpowers는 Generator/Evaluator/TDD/Git Worktree 같은 단편적 best practice 를 묶었지만, **"6축 프레임워크로 모든 스킬을 정합화" 하는 메타 레이어가 없음**.

### 6.3 개인화 컴파운딩
- **지원**: **없음**. 세션 내 TodoWrite만 있고, 세션 간 학습·축적 메커니즘 없음.
- **유일한 관련**: `writing-skills/SKILL.md` 가 "스킬을 새로 만드는 방법" 을 가르쳐줌 — 즉 **수동 compounding**. 자동 패턴 감지·승격·유저 교정 저장 없음.
- **결론**: 컴파운딩은 **순수 우리 차별점**. 다만 `writing-skills` 의 **Skill TDD 방법론은 승격된 스킬의 품질 검증에 재사용 가능**.

### 6.4 한국어 대화 최적화
- **지원 수준**: **전무**. 전 파일 영문.
- **다국어 분기 구조**: 플랫폼별 분기(.claude-plugin / .cursor-plugin / .codex / .opencode / GEMINI.md) 는 있지만 **언어별 분기 없음**.
- **결론**: 한국어 최적화는 **순수 우리 차별점**. 포팅할 description·SKILL 본문에 한국어 트리거/사례를 병기하는 전략이 필요.

### 6.5 종합 결론 (차별점별 정량 평가)

| 차별점 | superpowers 커버리지 | 우리 독자 기여 필요도 | UK 활용도 |
|--------|:---:|:---:|:---:|
| 기존 도구 오케스트레이션 | 0% (통합 대상) | - | ●●● (스킬 체인 차용) |
| 하네스 6축 강제 | 40% (간접 커버) | 매우 높음 (메타 레이어 전담) | ●●● (패턴 그대로 재활용) |
| 개인화 컴파운딩 | 0% | 매우 높음 | ●● (Skill TDD 방법론만) |
| 한국어 최적화 | 0% | 매우 높음 | · (새로 써야 함) |

**전략 권고:**
- 1축·4축·5축 는 **superpowers 포팅으로 70% 완성** 가능 — 차별점 낭비가 아니라 품질 보장
- 2축·3축·6축 는 **우리 고유 설계 필요** — auto-memory / session-wrap / 승격 게이트 / 한국어 레이어는 다른 레퍼런스와 우리 창작으로

---

## 7. 핵심 인용 및 증거 파일 경로

### 7.1 절대 경로 인용

- `/Users/ethan/Desktop/personal/harness/references/superpowers/.claude-plugin/plugin.json` — 플러그인 메타
- `/Users/ethan/Desktop/personal/harness/references/superpowers/CLAUDE.md` — 기여 가이드 / 하드룰
- `/Users/ethan/Desktop/personal/harness/references/superpowers/README.md` — 7단 워크플로
- `/Users/ethan/Desktop/personal/harness/references/superpowers/hooks/session-start` — SessionStart bash 훅
- `/Users/ethan/Desktop/personal/harness/references/superpowers/hooks/hooks.json` — 훅 등록
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/brainstorming/SKILL.md` — HARD-GATE + 9단 체크리스트
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/brainstorming/spec-document-reviewer-prompt.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/brainstorming/visual-companion.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/writing-plans/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/writing-plans/plan-document-reviewer-prompt.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/subagent-driven-development/SKILL.md` — 3단 리뷰 루프
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/subagent-driven-development/implementer-prompt.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/subagent-driven-development/spec-reviewer-prompt.md` — "Do Not Trust"
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/subagent-driven-development/code-quality-reviewer-prompt.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/verification-before-completion/SKILL.md` — Iron Law
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/test-driven-development/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/systematic-debugging/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/dispatching-parallel-agents/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/using-git-worktrees/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/finishing-a-development-branch/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/requesting-code-review/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/receiving-code-review/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/writing-skills/SKILL.md` — SKILL description 룰, Skill TDD
- `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/using-superpowers/SKILL.md` — 세션 주입 페이로드
- `/Users/ethan/Desktop/personal/harness/references/superpowers/agents/code-reviewer.md`

### 7.2 핵심 문구 (원문 그대로)

- `brainstorming/SKILL.md:12-14` — HARD-GATE
- `brainstorming/SKILL.md:16-18` — "Simple projects" Anti-Pattern
- `writing-skills/SKILL.md:150-158` — "description이 workflow를 요약하면 Claude가 본문을 안 읽는다" 실증
- `subagent-driven-development/SKILL.md:41-85` — 3단 리뷰 flowchart
- `spec-reviewer-prompt.md:20-36` — "Do Not Trust the Report ... Verify by reading code"
- `verification-before-completion/SKILL.md:17-21` — Iron Law
- `using-superpowers/SKILL.md:10-16` — "1% 라도 해당되면 반드시 스킬 호출"
- `writing-skills/SKILL.md:376-392` — Skill TDD Iron Law

---

## 8. 추가 관찰 (하네스 플러그인 설계자를 위한 힌트)

### 8.1 Superpowers 의 "강제성" 스타일
- **대문자·`<EXTREMELY-IMPORTANT>`·`<HARD-GATE>`·"NO ... WITHOUT ..."** 같은 극단적 톤
- 이유: Claude 가 합리화(rationalization)로 규율을 우회하는 패턴을 역공학적으로 막음
- 우리 채택 여부: **부분 채택** — 6축 전환 지점에서만 강제 톤 사용, 나머지는 친절한 안내로. 한국어 사용자에게는 강경 톤이 불편할 수 있음.

### 8.2 "your human partner" 라는 2인칭
- CLAUDE.md line 78: "your human partner is deliberate, not interchangeable with 'the user'"
- 인간과 AI의 파트너십을 의식적으로 호명 → AI의 자세를 동료적으로 유지
- 우리 채택: **채택 권장** — 한국어로 "함께 일하는 사람" / "파트너" 등으로 번역. `tothefullest08@gmail.com` 유저 개인화 맥락과도 정합.

### 8.3 Release Notes 가 58KB
- `RELEASE-NOTES.md` 가 버전별로 매우 상세. 각 skill 변경 이유·실패 사례·A/B 테스트 결과까지 기록
- 우리 시사점: **6축별 변경 이력**을 RELEASE-NOTES 수준으로 남기면 컴파운딩 재료가 됨

### 8.4 테스트 디렉토리
- `tests/` 가 존재 — 스킬 동작 회귀 테스트 가능
- 우리 시사점: 승격 게이트 임계값(오검지율 20% / 철회율 10%) 검증용 테스트셋을 같은 구조로

### 8.5 `"model: inherit"` 패턴 (agents/code-reviewer.md:5)
- 서브에이전트가 상위 컨트롤러의 모델을 상속
- 반면 subagent-driven-development 본문(line 87-100)은 Task 복잡도에 따라 모델 분기 권장
- 우리 시사점: **Evaluator 는 Generator 보다 작은 모델도 충분** (실험적으로 Haiku Evaluator + Sonnet Generator 조합 가능). 하네스 lecture의 "모델도 나누고 역할도 나눈다" 와 조화.

---

## 9. 마무리 — Phase 3 입력으로 넘길 것 3가지

Phase 3 (`/ce-brainstorm` 또는 `/ce-ideate`) 에서 가장 먼저 논의되어야 할 3가지:

1. **HARD-GATE + 3단 Evaluator 서브에이전트 패턴을 우리 `/verify` 스킬의 스펙으로 확정할지** — superpowers 가 이미 검증한 레퍼런스 구현이므로, 우리는 여기에 "스코어링 + 실패 시 자체 루프" 를 덧붙이는 포지셔닝이 되는지.
2. **`using-superpowers` 처럼 `using-harness.md` 를 SessionStart 훅으로 주입할지** — 주입 페이로드(6축 요약 + 한국어/영어 분기) 설계가 2축(맥락)의 첫 진입점.
3. **description 룰("Use when ... + workflow 요약 금지")을 한국어 트리거와 어떻게 조화시킬지** — 실험 영역(KU). superpowers 는 순영문이라 교훈은 있지만 답은 없음.

---

*본 분석은 Phase 2 병렬 리서치의 `references/superpowers` 단독 분석이며, 다른 레퍼런스(compound-engineering / hoyeon / ouroboros / team-attention / oh-my-claudecode) 는 병렬 수행된 별개 분석 문서에서 다룬다.*

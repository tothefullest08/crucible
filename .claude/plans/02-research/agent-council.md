# Phase 2 레퍼런스 리서치 — `references/agent-council`

> 멀티 에이전트 합의(Consensus) 패턴 참조 분석
> Team Attention의 `agent-council` 플러그인이 여러 AI CLI(Claude/Codex/Gemini)의 의견을 병렬 수집·종합하는 구조와, 우리 하네스 플러그인에 어떻게 포팅할지 정리

- **작성일**: 2026-04-19
- **분석 대상**: `/Users/ethan/Desktop/personal/harness/references/agent-council`
- **원본 리포지토리**: https://github.com/team-attention/agent-council
- **영감 출처**: [Karpathy의 LLM Council](https://github.com/karpathy/llm-council)
- **분석 범위**: 이 레퍼런스 단독 (다른 레퍼런스 접근 금지, 병렬 독립성 보장)

---

## 🔎 한눈에 보기

`agent-council`은 **"호스트 CLI(Claude Code 또는 Codex CLI)가 Chairman이 되고, 다른 AI CLI들을 Members로 소집해 병렬 질의 → 의견 수집 → 종합"**을 수행하는 매우 얇은 셸+Node 스킬이다. 특징:

1. **API 비용 제로** — 각 LLM의 API가 아니라 이미 로그인된 **CLI**를 `spawn`하여 재사용 (Karpathy LLM Council과의 결정적 차이점)
2. **Stage 3 파이프라인** — 초기 의견 수집 → 응답 집합 → Chairman 종합
3. **Job 기반 비동기 모델** — `start` / `status` / `wait` / `results` / `clean` 서브커맨드로 tool cell 스팸 없이 진행 가능
4. **Host UI 연동** — 반환하는 JSON 안에 `ui.codex.update_plan.plan` / `ui.claude.todo_write.todos` 페이로드가 들어 있어 호스트의 네이티브 Plan/Todo UI를 직접 갱신
5. **한국어 1급 지원** — `README.ko.md`로 완전 번역, 트리거 문구도 한국어 예시("council 소집해줘", "다른 AI들 의견도 들어보자") 제공

---

## 1. 디렉토리 구조

### 루트 레이아웃

`references/agent-council/` 직접 글롭 결과 — 다른 레퍼런스 접근 없이 이 트리만 확인함:

```
agent-council/
├── .claude-plugin/
│   └── marketplace.json             # Claude Code 마켓플레이스 등록 스펙
├── bin/
│   └── install.js                   # npx 설치 스크립트 (Claude/Codex 자동 감지)
├── skills/
│   └── agent-council/
│       ├── SKILL.md                 # 스킬 엔트리포인트 (매우 짧음)
│       ├── references/              # progressive disclosure용 보조 문서
│       │   ├── overview.md
│       │   ├── examples.md
│       │   ├── config.md
│       │   ├── requirements.md
│       │   ├── host-ui.md
│       │   └── safety.md
│       └── scripts/
│           ├── council.sh               # 사용자 진입 셸
│           ├── council-job.sh           # node 실행 래퍼
│           ├── council-job.js           # 오케스트레이터 (start/status/wait/results/stop/clean)
│           └── council-job-worker.js    # Member 1명당 1개 워커 (CLI spawn)
├── council.config.yaml              # Chairman + Members + settings 선언
├── package.json                     # npm 패키지 메타 (bin: agent-council → install.js)
├── README.md / README.ko.md         # 영/한 이중 언어 문서
├── AGENTS.md                        # Codex 호스트용 플랜/할일 UI 가이드
├── CLAUDE.md                        # Claude 호스트용 TodoWrite UI 가이드
├── LICENSE                          # MIT
└── .gitignore
```

### `.claude-plugin/plugin.json` 유무

**없음.** 대신 `.claude-plugin/marketplace.json`만 존재:

```json
{
  "name": "team-attention-plugins",
  "owner": { "name": "Team Attention" },
  "plugins": [
    {
      "name": "agent-council",
      "source": "./",
      "strict": false,
      "skills": ["./skills/agent-council"]
    }
  ]
}
```
(`references/agent-council/.claude-plugin/marketplace.json:1-16`)

→ **"마켓플레이스를 통째로 제공하는 모델"**이다. `plugin.json` 없이도 `marketplace.json`의 `plugins[].skills` 경로만으로 Claude Code 플러그인이 구성된다. `strict: false`로 자유도 높음.

### `skills/` 디렉토리

- **스킬 수: 1개** (`skills/agent-council/`)
- 엔트리: `SKILL.md` — 단 36줄, 거의 "진입점 + 참고 문서 인덱스" 역할만 함 (`references/agent-council/skills/agent-council/SKILL.md:1-36`)
- `references/*.md` 6종 — Anthropic 권고안인 **Progressive Disclosure** 패턴을 그대로 따름
- `scripts/` 4종 — 실제 오케스트레이션 로직

### `agents/`, `hooks/`, `commands/` 디렉토리

**전부 없음.** 이 플러그인은 **스킬 단 1개로 다중 에이전트 기능 전체를 구현**한다. 별도 agents/ 디렉토리 없이 `council.config.yaml`에서 Members를 YAML로 선언하고, `council-job-worker.js`가 각 CLI를 자식 프로세스로 `spawn`한다. 즉 **"에이전트 = 외부 CLI 호출"**로 추상화되어 있다.

### 루트 레벨 주요 파일

| 파일 | 역할 |
|------|------|
| `CLAUDE.md` | Claude Code 전용 프로젝트 인스트럭션 — **스킬 시작 시 `TodoWrite` 먼저 호출하고, `wait → TodoWrite` 반복 요구** (`references/agent-council/CLAUDE.md:1-9`) |
| `AGENTS.md` | Codex 전용 — `update_plan` 동일 패턴 (`references/agent-council/AGENTS.md:1-8`) |
| `council.config.yaml` | 유일한 런타임 설정: Members 리스트 + Chairman 롤 + timeout |
| `package.json` | `bin.agent-council = bin/install.js` → `npx github:team-attention/agent-council`로 설치 가능 |
| `bin/install.js` | **Claude Code / Codex CLI 자동 감지**, `.claude/` 또는 `.codex/` 아래에 스킬 복사 + `yaml` 런타임 의존성까지 번들 (`references/agent-council/bin/install.js:81-203`) |

---

## 2. SKILL.md 프론트매터 패턴

### 실제 프론트매터

```yaml
---
name: agent-council
description: Collect and synthesize opinions from multiple AI agents. Use when users say "summon the council", "ask other AIs", or want multiple AI perspectives on a question.
---
```
(`references/agent-council/skills/agent-council/SKILL.md:1-4`)

### 메타데이터 규칙

- **필드 2개만** 사용: `name`, `description`. 버전·작성자·태그 등 일체 없음 → **극단적 미니멀리즘**
- **트리거 키워드 패턴**: "Use when users say..."로 **명시적 발화 예시**를 description에 박아 Claude의 스킬 매칭을 튜닝
  - `"summon the council"`, `"ask other AIs"` 같은 **짧은 영어 관용구** 3~4개 나열
- **파일 본문**: 스킬 사용법(`Usage`)과 참고 문서 인덱스(`References`) 2블록만. 구현·설명은 전부 `references/*.md`로 분리 → **Progressive Disclosure**

### description 최적화 분석

한 문장에 **세 가지 정보**가 압축되어 있다:
1. **무엇을 하는가**: "Collect and synthesize opinions from multiple AI agents"
2. **언제 써야 하는가**: "Use when users say..."
3. **구체적 트리거 발화**: 큰따옴표 인용 3개

→ Claude가 "어떤 상황에서 이 스킬을 불러야 할지"를 결정하는 데 필요한 정보가 한 description에 다 들어 있다. **우리 하네스 플러그인의 `/brainstorm`·`/plan`·`/verify`·`/compound` description 작성 시 그대로 모방할 수 있는 템플릿**.

### 다국어(한국어) 지원 여부

- **SKILL.md 프론트매터 자체는 영어만.** description은 단일 영어 문장.
- 다만 `README.ko.md`의 Usage 섹션에 한국어 트리거 발화가 "council 소집해줘", "다른 AI들 의견도 들어보자" 등 **별도로 문서화**되어 있음 (`references/agent-council/README.ko.md:130-138`).
- 즉 **description에는 한국어 키워드를 넣지 않는다** — 대신 문서에서 유저에게 "이렇게 말하면 된다"고 안내하는 방식. 호스트 AI가 영어 description을 읽어도, 유저 발화가 한국어로 들어오면 의미 매칭으로 트리거되는 것에 의존.
- ⚠️ **주의 포인트**: 우리 플러그인이 한국어 최적화를 primary 차별점으로 삼는다면, **description에 한국어 트리거 예시를 "영어 발화 + 한국어 발화" 병기**로 넣는 변형을 시도해볼 만하다.

---

## 3. 핵심 워크플로우 — 3단계 합의 프로토콜

### 전체 플로우 (Stage 1 → 2 → 3)

`references/agent-council/skills/agent-council/references/overview.md:8-13`:

```
1. Send the same prompt to each member.
2. Collect and surface member responses.
3. Synthesize the final answer as chairman;
   optionally run the chairman inside council.sh via chairman.command.
```

즉 **Generator(Members) vs Evaluator(Chairman) 분리**가 아키텍처 레벨에서 강제된다. 하네스 6축의 "검증" 원칙(Generator ≠ Evaluator)을 그대로 실현한 구현체.

### Stage 1 — 병렬 의견 수집

`council-job.js:cmdStart` (`references/agent-council/skills/agent-council/scripts/council-job.js:370-471`):

1. `council.config.yaml` 파싱
2. Chairman 롤 결정 (`role: auto`면 `/.claude/skills/` 경로면 `claude`, `/.codex/skills/` 경로면 `codex`로 자동 추론 — `detectHostRole()`, line 26-31)
3. `exclude_chairman_from_members: true`(기본값)이면 **Chairman으로 뽑힌 AI는 Members에서 자동 제외** → 자기 자신을 평가하지 않게 함
4. Members 각각에 대해 `council-job-worker.js`를 `spawn(detached: true, stdio: 'ignore')`로 **완전 분리된 자식 프로세스**로 띄움 (line 458-464)
5. 각 워커는 `members/<safeName>/status.json`을 **atomic write**로 업데이트 (tmp 파일 → rename)

### Stage 2 — 응답 수집

`council-job-worker.js` (`references/agent-council/skills/agent-council/scripts/council-job-worker.js:88-217`):

- 각 워커는 `prompt.txt`를 읽고, `command` 토큰을 파싱한 뒤 `<tokens[0]> ...<tokens[1:]> <prompt>` 형태로 자식 CLI를 spawn
- stdout → `output.txt`, stderr → `error.txt`로 스트리밍
- **타임아웃 핸들러**: `timeoutSec` 경과 시 `SIGTERM`, exit 처리에서 `timed_out` / `canceled` / `done` / `error` / `missing_cli` 5가지 상태로 분류
- 종료 시 `status.json`을 최종 payload로 덮어씀

**핵심 관찰**: Members 간 통신은 **없다**. 각자 동일한 `prompt.txt`만 받고 독립적으로 응답 → **"독립 의견 수집"**이 디자인 결정. 이는 합의 연구에서 말하는 **independence condition**(판단의 상호 영향 배제)을 만족시키는 구조.

### Stage 3 — Chairman 종합

두 가지 모드:

**모드 A · 기본: 호스트 에이전트가 Chairman**
- `council.sh` 반환값(`results` 서브커맨드 출력)을 호스트 AI(Claude Code/Codex)가 직접 읽고 종합
- `chairman.role: "auto"` + `chairman.command` 미지정 시 이 경로

**모드 B · 선택: `council.sh` 내부에서 CLI로 Chairman 실행**
- `chairman.command: "codex exec"` 같이 지정하면 `council.sh`가 내부에서 한 번 더 spawn하여 종합까지 완료 (`references/agent-council/council.config.yaml:32-44`)

→ 하네스 관점에서 두 모드가 주는 교훈: **"종합 단계의 모델을 다르게 쓸 수 있게 설계 분리"**. 우리 플러그인의 Evaluator도 같은 토글을 가질 수 있다 (기본: 호스트 Claude / 선택: Codex exec 서브프로세스).

### 멀티 에이전트 합의 메커니즘 — 투표/병합 전략 분석

**중요 발견**: `agent-council`은 **정량적 투표도, 점수 병합도 하지 않는다.**

- Members의 상태는 `done / error / missing_cli / timed_out / canceled` 5종 라벨뿐 (`council-job.js:277-280`)
- `results` 서브커맨드가 반환하는 것: **"멤버 이름 + state + 원본 output 텍스트"의 단순 연결**
- 최종 합성은 **LLM 판단에 위임** (Chairman이 자유 텍스트로 synthesize)

즉 **"정형화된 투표 알고리즘 ❌, LLM-as-synthesizer 패턴 ✅"**. 이것은 의도된 설계로, 다음 이유 때문이다:
1. Members의 응답이 비구조 텍스트라서 정량 비교가 곤란
2. Chairman의 자연어 추론력이 "다수결"보다 맥락 적응성 높음
3. 구현 단순성 — YAML 한 줄 추가로 Member 확장 가능

이 지점은 우리 하네스 플러그인의 `/verify` 설계에서 **"의견 수집 형태를 자유 텍스트로 둘지, 스코어링 루브릭을 강제할지"**를 고민하게 만든다. **agent-council이 일부러 루브릭을 넣지 않은 반면, 우리는 요구사항상 "스코어링 루프"가 필요**하므로, 우리는 **agent-council의 수집 인프라 + 별도 Evaluator 루브릭 레이어**의 2층 구조가 적절하다.

### 페르소나 설계 방식

`council.config.yaml`의 Member 선언은 **의도적으로 페르소나 정보가 없다**:

```yaml
- name: claude
  command: "claude -p"
  emoji: "🧠"
  color: "CYAN"
```
(`references/agent-council/council.config.yaml:14-28`)

**name / command / emoji / color 4개 필드뿐.** `role`, `perspective`, `system_prompt` 등 페르소나 필드 일체 없음. 즉 **"페르소나 = 모델 자체의 기본 성향 + 이름"**에 의존하고, 페르소나 주입은 전적으로 **프롬프트 레벨**(유저 질문)에서 하게 둠.

→ **시사점**: 우리 하네스 플러그인에서 **6축별 Evaluator 서브에이전트**를 만든다면, agent-council의 Member 스키마를 확장해 `system_prompt` 또는 `focus_axis`(6축 중 하나) 필드를 추가하는 쪽이 자연스럽다. 이건 agent-council의 미니멀리즘을 **페르소나 방향으로 확장**하는 오리지널 기여가 된다.

### Job 모드 — tool cell 스팸 방지

`council-job.js` 서브커맨드 체계:

| 커맨드 | 역할 | 핵심 설계 |
|--------|------|-----------|
| `start` | Job 디렉토리 생성 + 워커 spawn | 즉시 반환 (non-blocking), 반환값은 `JOB_DIR` |
| `status` | 현재 진행 집계 | `--json` / `--text` / `--checklist` 세 포맷 |
| `wait` | **의미 있는 진행이 생길 때까지 블록** | 커서(`v2:bucketSize:dispatchBucket:doneBucket:isDone`)로 중복 업데이트 억제 |
| `results` | 모든 멤버의 output.txt 출력 | `--json`이면 구조화 |
| `stop` | 실행 중 멤버에 SIGTERM | pid 기반 |
| `clean` | Job 디렉토리 삭제 | |

**가장 독특한 설계 — `wait` 커서 메커니즘** (`references/agent-council/skills/agent-council/scripts/council-job.js:515-650`):

- Auto-bucket: 기본 5번만 업데이트 (`Math.max(1, Math.ceil(totalNum / 5))`, line 580)
- `--bucket 1`: 매 멤버 완료마다 반환
- 커서가 이전과 동일하면 `Atomics.wait`으로 250ms 슬립 후 재확인
- **결과**: 호스트 AI tool cell이 매초 새로고침되지 않고, "진짜 진행"만 보고받음 → 토큰 절감 + UI 노이즈 제거

### Host UI 직접 업데이트 — 가장 독창적인 패턴

`buildCouncilUiPayload` (`references/agent-council/skills/agent-council/scripts/council-job.js:179-258`)가 **Codex의 `update_plan` 스키마**와 **Claude의 `TodoWrite` 스키마**를 **동시에** 포함한 JSON을 생성:

```json
{
  "progress": { "done": 2, "total": 3, "overallState": "running" },
  "codex": { "update_plan": { "plan": [...] } },
  "claude": { "todo_write": { "todos": [...] } }
}
```

각 스텝은:
- `[Council] Prompt dispatch` — 초기 dispatch
- `[Council] Ask <member>` — 멤버별 스텝
- `[Council] Synthesize` — 마지막 종합 스텝

그리고 `CLAUDE.md`에서 유저에게 **"wait → TodoWrite 반복 실행"**을 의무화 (`references/agent-council/CLAUDE.md:5-7`). 즉 **"스킬이 호스트 AI의 네이티브 플랜 UI를 원격 조작"**하는 패턴이다. `host-ui.md:13-17`에 "exactly one in_progress item while work remains"라는 규칙이 명시되어 있다.

→ 하네스 관점에서 이건 **구조축의 UX 혁신**이다. 우리 플러그인도 `/orchestrate` 실행 시 Claude Todo UI를 동일 패턴으로 업데이트하면 "지금 어느 축을 돌리는 중인지" 시각화 가능.

---

## 4. 재사용/포팅 가능한 자산 (UK 관점)

Phase 1 4분면의 **UK(이미 가진 덜 쓰인 자산)** 영역에서 `agent-council`이 주는 포팅 가능 자산:

### 4.1 그대로 포팅 가능한 구조·템플릿·패턴

| 자산 | 위치 | 재사용 방식 |
|------|------|-------------|
| **Marketplace + Skill-only 구조** | `.claude-plugin/marketplace.json` + `skills/<name>/` | `plugin.json` 없이 marketplace로 바로 배포 가능한 최소 구조. 우리 플러그인이 오픈소스 배포 목표이므로 그대로 차용 |
| **SKILL.md 미니멀 프론트매터** | `name` + `description` 2필드, 트리거 발화 큰따옴표 인용 | `/brainstorm`, `/plan`, `/verify`, `/compound`, `/orchestrate` 5개 스킬의 description 포맷을 이것 그대로 |
| **Progressive Disclosure 문서 구조** | `skills/<name>/references/*.md` 6종 (overview/examples/config/requirements/host-ui/safety) | 6축별 스킬의 보조 문서를 같은 구조로. 특히 `safety.md`·`requirements.md`는 플러그인 표준 섹션화 |
| **`council.config.yaml` 선언형 Members** | YAML로 `name + command + emoji + color` | 6축별 Evaluator 서브에이전트를 `evaluator.config.yaml`로 선언형 관리 |
| **Job 디렉토리 + atomic status 패턴** | `members/<safeName>/status.json` + `.tmp + rename` | `.claude/memory/` 승격 게이트에서 **원자적 쓰기** 필수 — 동일 패턴 복사 |
| **Wait 커서(`v2:bucketSize:dispatchBucket:doneBucket:isDone`)** | `council-job.js:515-650` | 장시간 구동되는 `/compound` 루프에서 tool cell 스팸 방지용으로 그대로 포팅 가능 |
| **`buildCouncilUiPayload` 호스트 UI 페이로드** | `council-job.js:179-258` | `/orchestrate`의 6축 진행을 Claude TodoWrite로 시각화할 때 거의 그대로 |
| **자동 호스트 감지 (`detectHostRole`)** | `council-job.js:26-31` — 경로 `.claude/skills/` vs `.codex/skills/` | 우리 플러그인이 Claude Code 외 다른 호스트(Codex)로 확장될 때 유용 |
| **`install.js` npx 설치 스크립트** | `bin/install.js` — CLI 감지 + 런타임 의존성(yaml) 번들 | 우리 플러그인도 npx 설치 옵션 제공 시 템플릿으로 |
| **AGENTS.md / CLAUDE.md 호스트 의무화 지시** | "스킬 시작 시 TodoWrite 먼저" | 우리 플러그인도 `CLAUDE.md`에 "스킬 호출 전 6축 체크리스트 Todo 생성 필수" 같은 의무화 인스트럭션 추가 가능 |

### 4.2 멀티 페르소나 프롬프트 조합 패턴 (핵심 질문)

**관찰**: `agent-council`은 **페르소나 조합을 프롬프트 레벨로 외부화**했다. Member에게는 동일 프롬프트가 가고, 페르소나 다양성은 **모델 자체의 다양성**에 의존한다.

**우리 플러그인의 개선 방향**:

```yaml
# 예: 우리 플러그인의 evaluator.config.yaml (agent-council 스키마 확장)
evaluators:
  - name: structure-evaluator
    command: "claude -p"
    axis: "scaffold"       # 신규 필드: 6축 중 어느 축 담당
    system_prompt: |        # 신규 필드: 페르소나 주입
      You are reviewing from the perspective of project structure...
    emoji: "🏗️"
    color: "CYAN"
  - name: context-evaluator
    command: "codex exec"
    axis: "context"
    system_prompt: "You check for context pollution and CLAUDE.md hygiene..."
    ...
```

이 접근의 이점:
1. **6축 강제**: 각 Evaluator가 하나의 축을 전담 → 체크리스트화 방지, 실효성 검증
2. **모델 다양성 + 페르소나 다양성 결합**: `command`로 모델 고름 + `system_prompt`로 관점 고정
3. **Evaluator 편향 대응** (Phase 1 UU 경고): 같은 모델군 맹점 방지 → Claude + Codex 교차 요구 가능

### 4.3 검증 루프(`/verify`) 구현 제안

`agent-council`의 Stage 1~3이 **단 1회** 실행되는 반면, 우리 요구사항 "실패 시 자체 루프"는 **반복 구조**가 필요. 따라서:

```
[Generator 1회 실행]
    ↓ 결과물
[agent-council Stage 1~2 (Members = 6축 Evaluator)]
    ↓ 멤버별 output.txt
[Chairman = 스코어링 루브릭으로 점수화]
    ↓ 점수 < 임계값?
   ├─ YES → Generator 재실행 (피드백 + Members 의견 주입)
   └─ NO  → 종료 + /compound 학습
```

→ `agent-council`의 job 모드(`start/status/wait/results/clean`)가 **루프 한 사이클의 기본 unit**이 된다. 우리는 이것을 **여러 번 호출**하는 상위 오케스트레이터를 만든다.

### 4.4 추가 포팅 후보

- **`--target auto` CLI 감지 로직** (`bin/install.js:81-107`) — 우리 플러그인 설치 스크립트에 그대로 활용
- **탈출구 설계**: `stop` 서브커맨드로 SIGTERM 전송 — 장시간 `/orchestrate` 중단 버튼 구현 시 패턴
- **`exclude_chairman_from_members: true` 기본값** (`council.config.yaml:42`) — "자기 자신을 평가하지 않음"의 **하드 가드레일**. 우리 Evaluator 설계의 기본 원칙으로 채택

---

## 5. 하네스 6축 매핑 매트릭스

| 하네스 축 | agent-council이 직접 구현하는가? | 해당 구성요소 | 우리 플러그인 확장 방향 |
|-----------|----------------------------------|--------------|-------------------------|
| **1. 구조 (Scaffolding)** | 부분 | `.claude-plugin/marketplace.json`, `skills/`, `scripts/`, `references/` 명확 분리 · `CLAUDE.md`/`AGENTS.md` 호스트별 분리 | 6축별 디렉토리 분리 (`scaffold/`/`context/`/...) 추가 |
| **2. 맥락 (Context)** | 약함 | SKILL.md Progressive Disclosure만 활용. Members 간 맥락 공유 없음 (의도된 독립성) | `.claude/memory/` + `MEMORY.md` 인덱스 신설 (agent-council에 없음) |
| **3. 계획 (Planning)** | 보통 | `buildCouncilUiPayload`가 Plan UI를 동적 생성 → "dispatch → ask × N → synthesize" 3단계 플랜 자동 노출 | 동일 패턴으로 6축 각 단계를 자동 Plan으로 |
| **4. 실행 (Execution)** | **강함** | **Subagent 패턴 정면 구현**: 멤버마다 detached 워커, 병렬 spawn, timeout, stop. 하네스 강의의 "Subagent 오케스트레이션"을 문자 그대로 코드화 | 우리 플러그인의 실행 백본으로 사실상 이것을 그대로 사용 가능 |
| **5. 검증 (Verify)** | **강함** | **Generator(Members) vs Evaluator(Chairman) 분리**가 아키텍처 레벨에서 강제 · `exclude_chairman_from_members` 기본값으로 자가 평가 방지 | 스코어링 루브릭 레이어 추가 (agent-council은 자유 텍스트 종합, 우리는 "점수 < 임계값" 판정 추가) |
| **6. 개선 (Compound)** | **없음** | 세션·학습 저장/재사용 구조가 없음. `clean`이 오히려 **증거 삭제** | 우리 플러그인이 **원본 기여**해야 하는 영역. job 결과를 삭제하지 않고 `.claude/memory/tacit/`·`corrections/`로 흘려보내는 후크 필요 |

### 멀티 에이전트 합의가 "계획" / "검증" 축과 닿는 지점

- **"계획"축**: Chairman이 Members 의견을 읽고 최종 추천을 내놓는 것은 본질적으로 **"계획 결정의 합의"**. 우리 `/plan`·`/brainstorm` 스킬에서 어느 방향으로 갈지 불확실할 때 agent-council을 **Decision-Support 호출**로 삽입 가능.
- **"검증"축**: 가장 직접적. Generator/Evaluator 분리가 이미 되어 있으므로 `/verify` 스킬의 **런타임 엔진**으로 agent-council을 재사용.

### 6축 관점 종합

`agent-council`은 **실행·검증 축에 특화**된 레퍼런스. 구조·맥락·계획 축에는 최소한만 터치하고, 개선 축은 **결여**되어 있다. 우리 하네스 플러그인에서 이것을 "검증 엔진"으로 포팅하되, **나머지 4축(특히 맥락·개선)을 우리가 추가해야 한다**는 것이 핵심 교훈이다.

---

## 📊 차별점 매핑 — 4가지 관점 평가

Phase 1에서 확정된 우리 플러그인의 4대 차별점에 agent-council을 투영:

### 1. 기존 도구 오케스트레이션

- **agent-council 본질**: 이것 자체가 오케스트레이션 레이어다. Claude/Codex/Gemini CLI들을 감싸서 "병렬 + 종합" 단일 인터페이스로 올림.
- **독립형 vs 조합**: **완전 독립형 스킬** — 다른 플러그인 의존성 제로. yaml 런타임 1개 빼면 Node 표준 라이브러리만 사용.
- **우리 플러그인 적용**: agent-council을 **"오케스트레이션 피스 중 하나"**로 흡수. 우리의 `/orchestrate`가 상위, agent-council이 그 안의 **검증 호출 서브루틴**으로 배치되는 구조. Phase 1 추천 파이프라인의 Phase 5(리뷰) / Phase 7(검증 루프)에 정확히 맞물린다.
- **평가**: ⭐⭐⭐⭐⭐ — 가장 깊게 포팅할 수 있는 레퍼런스 중 하나

### 2. 하네스 6축 강제

- **agent-council이 다루는 축**: 실행(⭐⭐⭐⭐⭐), 검증(⭐⭐⭐⭐⭐), 구조(⭐⭐⭐), 계획(⭐⭐), 맥락(⭐), 개선(⭐)
- **6축 강제 메커니즘**: 없음. 순수 도구 레벨. 6축 관점은 우리가 상위에서 주입해야 함.
- **우리 플러그인 적용**: agent-council의 **Member 스키마에 `axis` 필드 추가** → 각 Evaluator를 6축 중 하나에 고정 → YAML 선언만으로 "6축 강제"가 자동 달성됨. 이게 Phase 1 KU 중 "6축 실효성 판정" 실험의 **구체적 실현 방법**.
- **평가**: ⭐⭐⭐ — agent-council 자체는 6축 불감이지만, 확장 여지가 크다

### 3. 개인화 컴파운딩

- **agent-council이 제공하는 학습 메커니즘**: **전무.** `clean` 서브커맨드가 오히려 job 디렉토리를 날려 세션 증거를 지움.
- **우리 플러그인이 추가해야 할 것**:
  - `clean` 전 훅: `members/*/output.txt` + `job.json`을 `.claude/memory/tacit/` 후보로 이동
  - 패턴 감지: Members 응답에서 "동일 제안이 3회 이상" → 승격 후보
  - "틀렸다" 발언 시 해당 session의 Chairman 종합을 `corrections/`에 기록
- **평가**: ⭐ (현재 상태) / ⭐⭐⭐⭐⭐ (확장 후) — 우리가 채워 넣어야 할 영역

### 4. 한국어 대화 최적화

- **현재 지원 수준**:
  - README.ko.md 완전 번역 (`references/agent-council/README.ko.md:1-224`) ⭐⭐⭐⭐
  - SKILL.md description은 영어 단일 ⭐⭐
  - AGENTS.md/CLAUDE.md는 영어 ⭐⭐
  - 트리거 발화 한국어 예시는 문서에만 존재 (`"council 소집해줘"` 등) ⭐⭐⭐
- **우리 플러그인 적용**: SKILL.md description에 **영어 + 한국어 트리거 병기**를 시도 → agent-council보다 한 단계 위의 한국어 UX 제공. 단 Phase 1 UU 경고대로 "오픈소스 확산 방해" 리스크 있으므로 **language preset 토글**(영어 기본 / 한국어 프리셋) 형태로 분리 권장.
- **평가**: ⭐⭐⭐ — 문서 레벨은 좋지만 코드/프론트매터는 영어 단일. 우리가 개선 여지 있음

---

## 🔑 핵심 발견 3가지 (요약)

### 발견 1: Generator/Evaluator 분리가 아키텍처 레벨에서 강제되어 있다
`exclude_chairman_from_members: true`가 기본값 (`council.config.yaml:42`) — Chairman이 자기 자신을 평가하지 않도록 **자동으로 Members 리스트에서 제외**. 이는 하네스 강의 5번째 축("Generator vs Evaluator 분리, 자기 평가는 mediocre도 잘했다고 평가하므로 회의적으로 튜닝된 별도 Evaluator 필요") 원칙을 **YAML 한 줄의 기본값**으로 실현한 것. 우리 `/verify` 설계의 하드 가드레일로 그대로 채택할 것.

### 발견 2: Members는 "설정 선언"만으로 추가 — 페르소나는 외부화되어 있다
`council.config.yaml`의 Member 스키마는 `name + command + emoji + color` 4필드만 요구한다. `role`, `perspective`, `system_prompt` 같은 페르소나 필드는 **없다** (`references/agent-council/council.config.yaml:14-28`). 이는 "페르소나 = 모델 자체의 성향 + 프롬프트"에 의존하는 의도적 결정으로, **단순성과 확장성의 균형**을 잡는다. 우리 플러그인은 여기에 **`axis` (6축) + `system_prompt`** 2필드만 추가해 "6축 강제"를 선언적으로 실현할 수 있다 — agent-council 스키마의 자연스러운 확장.

### 발견 3: 호스트 네이티브 UI를 원격 조작하는 Wait 커서 패턴은 우리 `/orchestrate`에 그대로 포팅 가능
`buildCouncilUiPayload` (`council-job.js:179-258`)가 JSON 응답에 `codex.update_plan.plan` + `claude.todo_write.todos`를 **동시 포함**하여, `CLAUDE.md`에서 의무화된 `wait → TodoWrite` 루프로 호스트 AI의 네이티브 Todo UI를 **스킬이 원격 조작**한다. 또 커서(`v2:bucketSize:dispatchBucket:doneBucket:isDone`)가 auto-bucket 5회 업데이트로 **tool cell 스팸을 억제**. 이 두 패턴(UI 페이로드 + 커서 bucket)은 우리 `/orchestrate`가 6축 파이프라인을 돌릴 때 "지금 어느 축을 검증 중"인지를 Claude Todo UI로 **자동 시각화**하는 데 거의 그대로 사용할 수 있는 엔지니어링 자산이다.

---

## 📂 관련 경로 레퍼런스

**루트**
- `/Users/ethan/Desktop/personal/harness/references/agent-council/README.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/README.ko.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/CLAUDE.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/AGENTS.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/council.config.yaml`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/package.json`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/.claude-plugin/marketplace.json`

**스킬 문서**
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/SKILL.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/references/overview.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/references/examples.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/references/config.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/references/requirements.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/references/host-ui.md`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/references/safety.md`

**스크립트 구현**
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/scripts/council.sh`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/scripts/council-job.sh`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/scripts/council-job.js`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/agent-council/scripts/council-job-worker.js`
- `/Users/ethan/Desktop/personal/harness/references/agent-council/bin/install.js`

---

*이 문서는 Phase 2 병렬 레퍼런스 리서치 산출물 중 `agent-council` 단독 분석입니다. 다른 레퍼런스(superpower/CE/hoyeon/ouroboros/clarify/oh-my-claudecode)의 분석은 별도 동료 분석가가 병렬로 생성하는 문서를 참조하세요.*

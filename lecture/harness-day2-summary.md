# 📘 Harness Engineering #2 — AI가 잘 일하는 환경을 설계하는 기술

**발표자**: Team Attention 이호연 / AI Native Camp
**분량**: 57페이지

---

## 🎯 큰 그림: Harness의 6개 축 — 순환 구조

```
구조(Scaffolding) → 맥락(Context) → 계획(Planning)
       ↑                                ↓
   개선(Compound) ← 검증(Verify) ← 실행(Execution)
```

**하네스 정의**: "프로젝트 안에서 **세 층이 엮여 돌아가는 엔진**"
- **Layer 1 · 기반** (구조+맥락): 폴더 구조, CLAUDE.md, .claude/rules/, spec, auto-memory
- **Layer 2 · 도구/연결**: MCP 서버, 외부 API, 파일·데이터 소스, CLI/쉘 도구(rtk·gh·git)
- **Layer 3 · 워크플로우**: 범용 플러그인(oh-my-claudecode, gstack, superpowers) + 프로젝트 전용(skill·agent·hook)

**과제**: 내가 겪는 문제를 "내 하네스"로 푸는 경험이 목표. 결과물은 3가지 형태 중 선택 — **A) 스킬 셋**, **B) 공용 플러그인**, **C) 프로젝트 통째**.

---

## 1️⃣ 구조 (Scaffolding)

### 프로젝트 구조 3원칙
1. **Monorepo로 묶기** — 소스·문서·테스트·설정을 한 프로젝트에서 관리, AI가 전체 맥락을 한눈에 파악
2. **역할별 폴더링** — 목적이 명확한 폴더 구조
3. **아키텍처가 퀄리티를 결정** — clean arch → consistent output

### Agent output 폴더도 구조화
- `.dev/data/` — 수집 데이터 원본
- `.dev/reports/` — 분석 결과물 (사람이 읽을 수 있는 형태)
- `.dev/handoff/` — 세션 간 핸드오프 메모(spec·TODO·lesson-learned)

> **AI가 어디에 쌓을지 모르면 아무 데나 쌓는다** — 자리를 먼저 만들어라

### 구조 설계 3가지 질문
| Q | 핵심 |
|---|------|
| **Foldering** | 사람 문서(`docs/`) vs AI 문서(`.dev/`) — 역할별 격리 |
| **Placement** | 도구를 어디에 둘까 (User/Project/Plugin) |
| **Boundary** | AI가 뭘 알고 어디까지 하게 할까 (CLAUDE.md + permission + hook) |

### User · Project · Plugin 배치 전략
| 도구 | User (~/.claude/) | Project (.claude/) | Plugin (plugin.json) |
|-----|------|---------|---------|
| Skills | 개인 루틴 `/commit` | 프로젝트 컨벤션 `/deploy-staging` | 팀 배포 `/my-plugin:review` |
| Hooks | 보편 알림·차단 | 팀 전체 금지사항 | 번들 자동화 |
| Agents | 개인 전문가 풀 | 도메인 전문가 | 재사용 에이전트 |
| MCP | 개인 계정 | 팀 공용 `.mcp.json` | plugin 내부 제공 |

**승격 전략**: `.claude/` → Plugin으로 올리기 (중복 정리 필수, blackbox 방지)

### 경계(Boundary) 설정
- **뭘 알려줄까**: `CLAUDE.md` + `rules/`
- **어디까지 허용**: `settings.json` Permission Mode (plan/auto/bypass)
- **뭘 막을까**: `.claude/hooks/` 로 위험 명령 차단
- ⚠️ **Hook 블랙박스 주의** — 많을수록 충돌 원인 모를 버그. `/hooks` 로 주기 점검

### 핵심: AI 품질 = Harness 설정 × 코드 아키텍처
둘 중 하나가 0이면 곱도 0. 규칙보다 구조가 우선 — **아키텍처부터 잡고 시작**.

### 🟢 TRY IT
- `/scaffold` — 프로젝트 초기 구성 자동 생성
- `/check-harness` — Harness 상태 체크리스트 진단
- `/skill-creator` — Anthropic 공식 스킬 생성 도구

---

## 2️⃣ 맥락 (Context)

### 설정 파일 계층 (하위가 상위를 오버라이드)
```
~/.claude/CLAUDE.md           [User — 모든 프로젝트]
  └─ my-app/CLAUDE.md         [Project — 팀 공유·Git]
       └─ .claude/rules/      [주제별 분리·glob]
            ├─ code-style.md  [*.ts, *.tsx]
            ├─ testing.md     [*.test.*, **/__tests__/**]
            └─ security.md    [**/auth/**, *.sql]
       └─ src/auth/CLAUDE.md  [Folder — 작업 시에만 로드]
```

### CLAUDE.md 실전
- User: 내 작업 습관, 코딩 스타일
- Project: 기술 스택, 컨벤션, 제약
- Folder: 특정 모듈의 특수 규칙
- **팁**: "최대 200줄, 너무 길면 AI 성능 급격 저하"

### 맥락 관리 핵심 원칙
1. **Progressive Disclosure** — 필요한 것만 필요할 때 보여주기
   - SKILL.md/CLAUDE.md에 `"이 상황에서는 이 문서를 읽어"` 가이드 → AI가 동적으로 필요 문서만 로드
2. **.claude/rules/** — 주제별 분리, glob 조건부 로드
3. **Scope 계층** — User/Project/Folder 각 레벨에 맞는 정보 배치

### 세션 맥락 관리 — 쌓이면 비워라
| 사용량 | 조치 |
|--------|------|
| ~20% | 쾌적 |
| ~50% | `/compact` (같은 주제 이어갈 때) |
| ~80% | `/clear` 또는 새 세션 |

- `/clear`: 컨텍스트 완전 초기화
- `/compact`: 요약·압축
- `handoff`: 맥락을 파일로 저장 → 새 세션에서 이어받기

### 주기 점검
- `/context` 로 카테고리별 토큰 사용량 확인
- CLAUDE.md·rules 비대해지면 **AI에게 직접 점검 요청**

### 컨텍스트 효율 = 분리 + 독립
- **PRINCIPLE 01**: 특성별 분리 (규칙·이력·문서·툴 결과를 한 바구니에 담지 말 것)
- **PRINCIPLE 02**: 작업자(subagent)는 독립 컨텍스트 — 메인에 전부 싣지 말고 역할별로 띄워 오염 격리

### Memory System
| Human-Curated | Auto-Accumulated |
|---|---|
| **CLAUDE.md** — 변하지 않아야 할 규칙, 리뷰 가능한 문서 | **Auto-memory** — 세션 거치며 AI가 스스로 쌓는 경험 기반 지식 |

대안: `claude-mem` (외부 저장소 + 압축 요약)
> 규칙은 CLAUDE.md에, 경험은 Auto-memory에. **섞이면 둘 다 오염**.

### Context 계층화
- **Git 커밋 히스토리** — 왜 바꿨는가의 timeline
- **Agent Task 히스토리** — spec·troubleshooting·lesson-learned
- **Human Documents** — docs/monitoring.md, deployment.md (AI가 못 건드리게)
- **Session Insights** — `/session-wrap` 으로 통과한 인사이트만 rules/skills/docs로 흘려보냄

### 토큰 절감 — `rtk` (github.com/rtk-ai/rtk)
자주 쓰는 dev 명령 출력을 필터링해 **60~90% 절감**. Rust 단일 바이너리.
- `rtk init -g` 한 번이면 Claude Code bash 명령에 자동 적용
- 지원: git·files·test·build·ops·meta

---

## 3️⃣ 계획 (Planning)

### 핵심 흐름: 계획 → 실행 → 검증 (반복 수렴)
"한 번에 완벽하게"가 아니라 **반복해서 수렴**.

### "해줘"의 함정 vs 같이 계획부터
- ❌ "이거 만들어줘" → AI가 알아서 → 검수 → "아닌데..." → 반복 → 시간만 날림
- ✅ "같이 계획 세워보자" → AI 계획 작성 → 사람 검토/수정/승인 → 실행 → **높은 성공률**

### AskUserQuestion 패턴
스킬 프롬프트에 **"이해한 것을 미러링하고, 모호한 점을 질문해서 명확하게 해줘"** 를 넣으면, AI가 AskUserQuestion으로 빠진 맥락을 스스로 물어본다.
> "해줘"가 아니라 "물어봐"

### 커스텀 Plan 스킬 진화
기본 Plan Mode 한계를 느끼면 전용 `/specify` 스킬 제작:
1. 목표 확인 (의도 미러링)
2. 인터뷰 (모호한 지점 질문)
3. 요구사항 + 태스크 도출
4. 플랜 파일로 떨구기 → `/execute` 실행
> implicit(머릿속) → explicit(플랜 파일)

### 🟢 TRY IT
- `/specify` — 인터뷰 → 요구사항 → 플랜 파일 자동화
- `/deep-interview` — unknown-unknown 엣지 케이스까지 끌어냄
- `/clarify` — 모호한 지시를 구체 스펙으로 변환

---

## 4️⃣ 실행 (Execution)

### 실행 패턴 3가지
| 패턴 | 용도 | 비용 |
|------|------|------|
| **Single** (혼자) | 단순 작업, 대부분의 일상 | 기본 |
| **Subagent** (부하 파견) | 병렬·전문화 위임→종합 | 중간 |
| **Team Mode** (팀 협업) | 다관점·복잡, 에이전트 간 소통 | **~7x** |

**90%는 단일/서브에이전트로 충분**.

### 상황별 오케스트레이션
- **순차 파이프라인**: "조사→초안→퇴고→발행 순서대로" → TaskCreate 체크박스
- **병렬 Subagent**: "A/B/C사 랜딩 페이지 동시 분석" → Agent 3개 spawn, 병렬 후 종합
- **Team Mode**: "설계자·구현자·리뷰어 3명 팀으로" → TeamCreate, 에이전트 간 직접 소통
- 참고: **revfactory/harness** — 실행 구조 설계 도구

### Ralph Loop — 될 때까지 반복
"**완료 기준 합의 → AI 작업 → 기준 충족? → (NO) 재작업**"
- 예: 모바일 반응형 + Lighthouse 90+ + 카피 3번 이상 퇴고
- **사람이 할 일: 기준 정하기 1번. 나머진 AI**

### Auto Research (karpathy/autoresearch)
자율 실험 루프: **수정 → 실행 → 평가 → 판단 → 반복**
- `program.md`에 연구 방향 작성 (스킬 역할)
- 시간당 ~12개 실험 자율 수행, 밤새 무인 운영
- 개선되면 유지, 아니면 폐기

### 장기 위임의 3요소 (새 역량)
1. **길게 맡기는 것 자체가 실력** — 몇 시간~밤새 돌아가는 위임 설계
2. **체크포인트** — 판단할 지점을 미리 찍어두고 나머지 위임 ("알아서 끝까지 해"는 ❌)
3. **맡기기 전에 철저히 확인** — 스펙·맥락·성공 기준·경계를 직전 단계에 집중

> 길게 시키는 것 ≠ 방치. **사전 확인 + 체크포인트 + 위임**이 한 세트.

### 🟢 TRY IT
- `/agent-orchestrate` — 패턴 자동 적용 (단일/병렬/파이프라인)
- `ralph` — 자동 검증 공식 플러그인
- `autoresearch` — Karpathy 자율 실험
- `revfactory/harness` — 실행 구조 설계 하네스

---

## 5️⃣ 검증 (Verification)

### 원칙 01 · 기준이 있어야 검증 가능
- **Sprint Contract**: 작업 전 "뭘 만들고 어떻게 검증할지" 합의
- 완료 조건을 **측정 가능하게** ("잘 되게" ❌ / "테스트 통과+빌드 성공" ✅)
- 미달하면 Ralph Loop 자동 반복

### 원칙 02 · 컨텍스트·관점 분리 (Anthropic)
**Generator(만드는 AI) vs Evaluator(평가하는 AI) 분리가 가장 강력한 레버**
- 자기 작업 평가하면 mediocre여도 자신있게 칭찬
- Evaluator를 **회의적으로 튜닝**하는 게 Generator를 자기비판적으로 만드는 것보다 쉬움

### 검증 전략 — 너비와 깊이
**너비 · 눈을 최대한 붙여주기**
- Browser Agent (Chrome-CDP, agent-browser) — 웹앱 UX 직접 확인
- Computer Use (built-in MCP) — 스크린샷+키보드로 네이티브 앱 제어
- 시각 검증 루프 — 스크린샷 → 판단 → 수정 (사람 눈 대신 AI)

**깊이 · Gate 세우기**
- AI 결과물 → **GATE(실제 돌려보고 판정)** → 통과→merge / 실패→재시도
- 테스트 코드만 보지 않고 **실제 사용자 시나리오** 끝까지 실행
- 병렬 에이전트의 커밋도 gate가 막음

### 원칙 03 · 모델도 나누고, 역할도 나눈다
| 모델 | 역할 |
|------|------|
| **Codex** | 코드 리뷰 — 로직 오류·보안·테스트 누락 |
| **Gemini** | 문서 리뷰 — 일관성·정확성·구조 |
| **Opus / Sonnet** | Opus: 복잡 판단·아키텍처 / Sonnet: 빠른 확인·반복 검증 |

> "Out of the box, Claude is a poor QA agent" — 검증 에이전트도 튜닝 필요 (기준을 구체적으로, 회의적으로)

### 안전장치
- **되돌릴 수 있는 환경**: `git worktree add` — 브랜치/워크트리 격리
- **위험한 건 사람 확인**: Runtime Gate — 삭제/배포/외부 발송은 승인 후
- **Dry-run 먼저**: `--dry-run` 미리보기 후 실행

### 🟢 TRY IT
- `/qa` — Browser Agent + Computer Use 기반 QA 자동화
- `verify` 레퍼런스 (team-attention/hoyeon)

---

## 6️⃣ 개선 (Compounding)

### 관측하고 개선하기
**관측**
- 세션 분석: 프롬프트 패턴 + Skill/Agent 호출 빈도
- AI Slop 감지: 불필요한 코드·중복 설정·안 쓰는 규칙

**개선**
- **3번 반복 → Skill로** 자동화
- **3번 틀리면 → Rule 또는 CLAUDE.md**에 명시
- Skill 개선 루프: 만들기 → 사용 → 세션 분석 → 병목 → 개선

### 단순화하기
- 안 쓰는 건 치운다 — Skill·MCP·Rule 삭제 (쌓이면 AI slop)
- 모델 좋아지면 Harness 재평가 — 예전 가드레일이 불필요할 수 있음
- 과설계 신호 인식 — 복잡하면 뭔가 잘못된 것

> **Anthropic** — "Harness의 공간은 모델이 좋아져도 줄어들지 않는다. 이동할 뿐이다."

### 자가 진단
**✅ 잘 가는 신호**
- 같은 말을 두 번 하지 않는다 (맥락 전달 양호)
- 실수가 규칙이 된다 (개선 루프 작동)
- 차단 장치가 뭔가 막고 있다 (사고 예방)
- 불필요한 것이 줄어든다 (단순화 진행)

**❌ 실패 징후**
- 검수 시간이 길어진다 → 검증 자동화 필요
- 원하는 결과가 안 나온다 → 맥락/계획 부족
- 스킬·에이전트 많은데 잘 안 쓴다 → context pollution
- 가이드 파일이 길어지고 관리 안 된다 → 분리/정리 부재

> **좋은 Harness는 점점 단순해진다**

### 세션 데이터 활용 (Compound)
- AI와의 대화·에이전트 결과 = **가장 진한 사용자 데이터**
- 반복되는 병목·실수가 그대로 기록 → 문제 정의 근거
- **`/session-wrap`**: 세션 끝에 AI가 대화를 다시 읽고 → 버그/인사이트/반복 작업 정리 → rules·skills·docs에 축적

### 주기적 자동화 (PR이 올라오게)
```
Trigger(/loop·/schedule) → 세션 분석 → 개선점 감지 → PR 생성
```
- `/schedule` — 매일 밤/매주/매 배포 뒤 주기 설정
- `/loop` — "분석 → 개선 → 재검증" N회 자율 반복
- 결과물은 반드시 **PR** (auto-merge 금지, 사람 리뷰 거쳐 반영)

> 세션은 일회용 로그가 아니라 **원재료**. 하네스가 밤사이 스스로 좋아진다.

### 🟢 TRY IT
- `session-wrap` (plugins-for-claude-natives) — 패턴 발견·실수 추출·문서 업데이트

---

## 🎬 마무리

### 사람은 앞으로 뭘 해야 하는가?
| 구조(Scaffold) | 맥락(Context) | 개선(Compound) |
|---|---|---|
| 환경 설계·유지 | AI가 아는 것 최신으로 | AI Slop 나오지 않도록 점검 |
| 요구사항 변경 시 구조 발전 / AI가 따를 수 있는 아키텍처 | CLAUDE.md·docs 갱신 / 새 컨벤션 → rules/ 추가 | 품질 모니터링 / 반복 실수 → 규칙, 반복 작업 → 스킬 / 안 쓰는 건 치우기 |

> **AI가 코드를 쓰는 시대, 사람의 역할은 "잘 짜기"에서 "잘 일하는 환경을 만들기"로 바뀐다**

### 최종 과제
본인의 문제를 푸는 **워크플로우 하나 만들기** (Skill Set / Plugin / Project 형태 중 선택). 6가지 축(구조·맥락·계획·실행·검증·개선)을 의식적으로 적용하고, 최대한 공유 가능한 형태로.

---

## 🔑 핵심 테이크어웨이 (한 줄 요약)

1. **구조**: 자리를 먼저 만들어라 — 사람 문서 vs AI 문서 분리
2. **맥락**: 쌓이면 비워라 — Progressive Disclosure + User/Project/Folder 계층
3. **계획**: "해줘" 대신 "물어봐" — 계획/실행 분리가 성공률을 올린다
4. **실행**: 길게 맡기는 것이 실력 — 사전 확인+체크포인트+위임 한 세트
5. **검증**: Generator vs Evaluator 분리 — 만드는 AI와 평가하는 AI는 달라야 한다
6. **개선**: Harness는 점점 단순해져야 한다 — 3번 반복→Skill, 3번 틀림→Rule

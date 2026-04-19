# 하네스 플러그인 — 최종 요구사항 스펙 v3 (user-decisions-5 반영)

> Phase 1 명확화 + Phase 2 레퍼런스 리서치 + Phase 3 브레인스토밍 + Phase 3.5 document-review + user-decisions-5 5건 반영 최종 문서.
> `/ce-plan` 입력으로 바로 쓰기 위한 단일 진실 소스(single source of truth).

- **작성일**: 2026-04-19 (v1), 2026-04-19 (v2: review applied), 2026-04-19 (v3: user-decisions-5 반영)
- **변경 이력 v2 → v3 (2026-04-19)**: `user-decisions-5.md` 5건 승격 — 보안 범위(§4.3 확장) · KU 샘플·정책(§8 확장) · 6축 강제 범위(§3.5 신설) · 라이선스 정책(§4.5 신설) · 포지셔닝 1문장(§1 TL;DR 상단). §11-2·4·5·6·7 포지셔닝 항목은 "이관 완료 → §N.Y 참조"로 축소. 상세 before/after는 `v3-change-log.md` 참조.
- **변경 이력 v1 → v2 (2026-04-19)**: P0-1(언어 제약 명시) + P0-3(W0 프리미스 재검증) + P0-4(AC 3단 재구성) + P0-9(§11 설계 미결 vs §12 Phase 4 이관 분리) 네 건 반영. 잔여 P0/P1은 §11에 명시.
- **선행 문서**:
  - `requirement.md` — 원본
  - `lecture/harness-day2-summary.md` — 하네스 6축
  - `.claude/plans/00-recommendations/tool-recommendations.md` — 도구 추천
  - `.claude/plans/01-requirements/clarified-spec.md` — Phase 1 (10개 결정)
  - `.claude/plans/02-research/*.md` (6개) + `02-research/synthesis.md` — Phase 2
  - `.claude/plans/03-design/final-spec-review.md` — 7-페르소나 document-review (30 findings)
  - `.claude/plans/03-design/user-decisions-5.md` — 유저 판단 5건 결정 (v3 승격 소스)

---

## 1. 요약 (TL;DR)

> **"harness는 Claude Code로 반복 작업하는 개발자가 세션마다 같은 실수를 반복하고 암묵지가 휘발하는 문제를 해결하고 싶을 때, 승격 게이트와 6축 검증 루프로 개인화된 컴파운딩 메모리를 누적하는 플러그인이다. 기존 CE·hoyeon과는 '유저 승인 게이트를 통과한 학습만 영속 저장한다'는 점에서 구별된다."**
>
> *(결정 근거: user-decisions-5 §5 포지셔닝 1문장. 단축안은 README.md·marketplace.json description 후보로 재활용.)*

**무엇을**: 하네스 6축(구조·맥락·계획·실행·검증·개선)을 **구조적으로 강제**하는 `.claude-plugin/` 공용 플러그인.
**왜**: 기존 플러그인들(superpower/CE/hoyeon/ouroboros/agent-council/p4cn)이 각 축은 다루지만 **"6축 메타-프레임워크"** 를 표면화한 레퍼런스가 없음. (※ 이 가정의 유효성은 **W0 프리미스 재검증** 후 확정 — §7 참조)
**누구**: 오픈소스 배포(MIT) + 한국어 UX 이중 지원 (hoyeon 실증 패턴).
**핵심 기능 3**: 암묵지 해소 (대화 기반 + "틀렸다" 분리 기록) · 결과 검증 루프 (스코어링 + 회색지대 자동 재검증) · 컴파운딩 (3회 반복/틀렸다/session-wrap 하이브리드 트리거).
**1차 릴리스 원칙**: **단일 완결형 MVP** → 실증 후 외부 플러그인 연동 진화.

---

## 2. 확정 스펙 (결정 매트릭스)

### 2.1 Phase 1 결정 (유지)

| # | 항목 | 결정 |
|---|------|------|
| 1 | 결과물 형태 | `.claude-plugin/` 공용 플러그인 |
| 2 | 중심축(primary) | **하네스 6축 강제** |
| 3 | 차별점 (복수) | 오케스트레이션(2차) · 6축 강제(1차) · 개인화 컴파운딩(1차) · 한국어 최적화(2차) |
| 4 | 타겟 | 오픈소스 배포 |
| 5 | Evaluator | 다른 관점 서브에이전트 (회의적 튜닝 + fresh context) |
| 6 | 오염 방지 | 승격 게이트 + 세션 격리 (+유저 명시 승인) |
| 7 | 메모리 포맷 | `MEMORY.md` 인덱스 + `tacit/` · `corrections/` · `preferences/` |
| 8 | 컴파운딩 트리거 (복수) | 3회 반복 감지 · "틀렸다" 발언 · `/session-wrap` |
| 9 | 진입점 | `/brainstorm` · `/plan` · `/verify` · `/compound` + `/orchestrate` |

### 2.2 Phase 3 신규 결정 (6가지)

| # | 질문 | 결정 | 근거 |
|---|------|------|------|
| 10 | `/plan` 산출물 포맷 | **C. 하이브리드** (Markdown 본문 + YAML frontmatter) | 기계 검증(Evaluator) + 사람 친화성 동시 |
| 11 | Stage 3 Consensus 발동 | **C. 회색지대 자동 + 승격 게이트** | qa-judge 점수 0.40~0.80 회색지대 + `/compound` 승격 시만 3모델 consensus (**2차 릴리스 항목**) |
| 12 | 세션 간 상태 저장 | **D. Claude Code JSONL 재사용** | `~/.claude/projects/*.jsonl`을 p4cn `history-insight` 방식으로 파싱 |
| 12.2 | 메모리 저장 위치 | 프로젝트 로컬 `.claude/memory/` **기본** + 플러그인 설정으로 `~/.claude/memory/` 글로벌 옵션 | 유저 주석 반영 |
| 13 | 한국어 description 병기 | **D. MVP는 B → 실증 후 C** | MVP 한·영 병기, KU-2 실증 후 `skill-rules.json` 이전 검토 |
| 14 | `/orchestrate` 외부 플러그인 호출 | **D. MVP=B → 2차=C** | MVP 단일 완결형, 2차에 외부 감지 위임 |

### 2.3 Phase 3.5 User Decisions 반영 (5가지, 2026-04-19)

`user-decisions-5.md` 5건을 v3 정식 § 로 승격한 결과. 결정 원본은 `user-decisions-5.md` 보존.

| # | 질문 | 결정 | v3 반영 위치 | 근거 |
|---|------|------|------------|------|
| 15 | **보안 범위** (§11-2) | 범용 7종 + 로컬 확장 훅 · 외부 도구 불허 · 글로벌 메모리 기본 OFF | §4.3 확장 (§4.3.1~§4.3.4) | user-decisions-5 §1 · Recommended 채택 |
| 16 | **KU 샘플·정책** (§11-4) | 각 KU 20 샘플 · 재시도 1회 후 차단 · 자동 LLM judge 서브에이전트 | §8 KU 테이블 3컬럼 확장 + §8.1 실행 스펙 소절 | user-decisions-5 §2 · Recommended 채택 |
| 17 | **6축 강제 범위** (§11-5) | `/plan`·`/verify`·`/orchestrate` ON · `--skip-axis N` 허용 · 검증 축(5) 스킵 시 강경 경고 · 실효성 KU 2차 연기 | §3.5 신설 + §9.1 #7 각주 + §10.3 |
| 18 | **라이선스** (§11-6) | MIT 최종 채택 · DCO sign-off · 상류 sync 분기/반기/연 차등 | §4.5 신설 + `porting-matrix.md` §2 라이선스 컬럼 실측 업데이트 | user-decisions-5 §4 · 시나리오 A (6상류 전부 MIT 실측 확인 2026-04-19) |
| 19 | **포지셔닝 1문장** (§11-7) | 2문장 최종안(사용자·통증·메카닉·결과·차별화 5요소) | §1 TL;DR 최상단 + README.md 첫 문장 | user-decisions-5 §5 · review P1-1 |

### 2.4 상충 재검토 (v2 §2.3 계승)

| 항목 | 상충 여부 | 해결 |
|------|----------|------|
| 오픈소스 배포(#4) ↔ 한국어 병기(#13) | **잠재 충돌** | 단계별 진화(D), 1차 병기 → 저항 시 `skill-rules.json` 이전 |
| 중심축 6축 강제(#2) ↔ `/orchestrate` 완결형(#14) | **정합** | 차별점 1(오케스트레이션)은 secondary, 완결형이 6축 강제 강화 |
| Evaluator 분리(#5) ↔ Consensus 회색지대만(#11) | **정합** | 기본 Evaluator = 회의적 + fresh context, Consensus는 회색지대·승격에만 (**2차**) |
| 컴파운딩 트리거 3종(#8) ↔ JSONL 재사용(#12) | **정합** | p4cn `history-insight` 파싱 방식이 3트리거 모두 커버 |
| 6축 강제(#2, #17) ↔ `/brainstorm`·`/compound` 자유발화 | **정합** (§3.5 범위 한정) | 강제는 3개 스킬(/plan·/verify·/orchestrate)만 ON, 나머지는 힌트만 |
| MIT(#18) ↔ 상류 라이선스 | **정합** (시나리오 A 확정) | 6상류 실측 전부 MIT — 저작권 고지 통합만 필요 |

---

## 3. 기능 요구사항 (사용자 관점)

### 3.1 유저 스토리

1. **브레인스토밍**: `/brainstorm [주제]` → clarify 3-lens(vague/unknown/metamedium)로 모호점 해소 → 요구사항 문서 생성
2. **계획**: `/plan [요구사항.md]` → 하이브리드 산출물(Markdown + YAML frontmatter)
3. **검증**: `/verify [산출물]` → 회의적 Evaluator 채점 → 승격 게이트 판정 → (2차: 회색지대 자동 Consensus) → Ralph Loop 재시도
4. **컴파운딩**: `/compound` (수동) 또는 자동 트리거 감지 → 승격 게이트(검증 → 유저 승인 → 저장)
5. **오케스트레이션** (Stretch): `/orchestrate [주제]` → 내부 4개 스킬 순차 실행

### 3.2 입력·출력 계약

| 스킬 | 입력 | 출력 |
|------|------|------|
| `/brainstorm` | 주제 (자유 발화) | `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` |
| `/plan` | 요구사항 문서 | `.claude/plans/YYYY-MM-DD-{slug}-plan.md` (Markdown + YAML frontmatter) |
| `/verify` | 산출물 경로 + 선택적 `--axis N`  (`--deep` 플래그는 **2차 릴리스**) | `qa-judge` JSON 리포트 + 승격/재시도 결정 |
| `/compound` | 트리거 조건 또는 수동 호출 | `.claude/memory/{tacit\|corrections\|preferences}/*.md` 업데이트 + `MEMORY.md` 인덱스 |
| `/orchestrate` | 주제 (자유 발화) | 파이프라인 전체 산출물 + 최종 리포트 (**Stretch**, W8 목표) |

### 3.3 한국어 UX (MVP = B)

- description: "한국어 트리거 / English trigger" 병기
- README: 영어 + `README.ko.md` 이중
- 본문·프롬프트·SKILL.md 내부: **영어 고정** (오픈소스 호환)
- `--lang ko` 플래그: 에이전트 응답 언어 분기 (future)

### 3.4 (예약) 승격 게이트 UX 전체 사양

**상태**: 미결 (§11-3 유지 · W5 이전 승격 예정 · T-W5-PRE-01).

본 소절은 `/compound` 승격 게이트의 6단계 UX 명세를 담기 위해 예약됨. 현 v3 시점 골격은 §11-3 참조.

### 3.5 6축 강제 적용 범위 (신설, 2026-04-19)

*결정 근거: user-decisions-5 §3 · §2.3 #17. 상세는 tracker §5.*

**6축 활성 매트릭스**:

| 진입점 | 구조(1) | 맥락(2) | 계획(3) | 실행(4) | 검증(5) | 개선(6) |
|--------|--------|--------|--------|--------|--------|--------|
| `/plan` | **ON** | **ON** | **ON** | 힌트 | **ON** | 힌트 |
| `/verify` | **ON** | **ON** | 힌트 | **ON** | **ON** | **ON** |
| `/orchestrate` | **ON** | **ON** | **ON** | **ON** | **ON** | **ON** |
| `/brainstorm` | 힌트 | 힌트 | 힌트 | — | — | — |
| `/compound` | — | 힌트 | — | — | 힌트 | **ON** |
| 일반 Q&A | — | — | — | — | — | — |

- **ON**: 축 통과 없이 산출물 배출 차단 (HARD-GATE 태그 + `validate_prompt` 자기검증 활성)
- **힌트**: 자연 대화에 축 체크리스트 제안만, 강제 없음
- **—**: 적용 안 함

**이스케이프 해치 `--skip-axis N`**:

- 문법: `/plan [요구사항] --skip-axis 2,3` (쉼표 분리, N=1~6)
- 기본 스킵은 stderr 1회 경고 + 응답 상단 `⚠️ axis N skipped` 배너
- **검증 축(5) 스킵은 추가 플래그 요구**: `--skip-axis 5 --acknowledge-risk` 조합이 없으면 skip 거부
- 스킵 사유는 거부 이력과 함께 `.claude/memory/corrections/skip-log.md`에 추기 (W5 `/compound` 메모리 경로 재사용)

**"실효성 지표" KU**: 6축 통과가 산출물 품질 향상과 상관되는지 측정하는 KU는 **2차 릴리스로 연기**. MVP 기간 dogfooding 로그를 2차 KU 설계 입력으로 수집. §10.3 참조.

### 3.6 (예약) OSS composability

**상태**: 미결 (§11-7 유지 · W8 이전 승격 · T-W8-PRE-03).

각 스킬이 독립 설치 가능한지 + 필수 의존 스킬 매트릭스를 담을 예정.

---

## 4. 비기능 요구사항

### 4.1 런타임·의존성 (P0-1 반영)

| 분류 | 결정 |
|------|------|
| **허용 런타임** | bash ≥ 4, **jq ≥ 1.6**, awk (macOS/Linux 표준). Python/Node 불허 |
| **JSONL 파싱** | `jq`만 사용. bash 변수 보간은 `"$var"` 쌍따옴표 + `printf '%s'` 패턴으로 제한 |
| **포팅 예외 원본** | ouroboros `drift-monitor.py` / `keyword-detector.py`는 **bash + jq로 재작성 후 포팅**. 원본 Python 그대로 포팅 금지 |
| **패키지 매니저** | 없음. `.claude-plugin/plugin.json` 설치만으로 동작 |
| **외부 secrets 도구** | **불허** (§4.3.2 근거: user-decisions-5 §1). `detect-secrets` · `trufflehog` 등 Python/Node 외부 도구 금지 — bash+jq 정규식만 |

### 4.2 외부 스키마 안정성 (P0-2 대응 — **§11에서 추후 구체화**)

- `~/.claude/projects/*.jsonl`은 **Anthropic 비공식 포맷**. 본 플러그인은 이 포맷의 안정성을 **전제하지 않는다**.
- 필수 방어 레이어 (§11-1에서 상세 설계):
  1. 스키마 어댑터 (schema_version 감지)
  2. 알 수 없는 `type`은 스킵 (defensive parser)
  3. UserPromptSubmit 훅 기반 라이브 캡처를 2차 fallback으로 구현
  4. Claude Code 릴리스 72시간 이내 smoke test (W1 CI 포함)
- 포맷 붕괴 시 degradation: 컴파운딩 **비활성화** (전체 실패 없음)

### 4.3 보안 제약 (확장 — user-decisions-5 §1 반영)

기존 v2 원칙(bash 훅 변수 보간 보호 · `eval` 금지 · 화이트리스트 slug)은 유지. 아래 §4.3.1~§4.3.4 4건은 **§11-2 결정 부분**을 승격. 잔여(훅 페이로드 SHA256 · correction-detector 부정 문맥 · PostToolUse 훅 실행 순서)는 §11-2에 잔류.

#### 4.3.1 Secrets redaction 정규식 리스트 (범용 7종)

*결정 근거: user-decisions-5 §1 · Recommended 채택.*

| # | 패턴 종류 | 대상 |
|---|---------|------|
| 1 | AWS access key / secret access key | `AKIA[0-9A-Z]{16}` · `(?i)aws.{0,20}(secret\|key).{0,20}[A-Za-z0-9/+=]{40}` |
| 2 | GCP service account key | `"private_key": "-----BEGIN PRIVATE KEY-----` |
| 3 | GitHub token (fine-grained + classic) | `ghp_[A-Za-z0-9]{36}` · `github_pat_[A-Za-z0-9_]{82}` |
| 4 | Slack token (bot/user/webhook) | `xox[baprs]-[A-Za-z0-9-]{10,}` · `hooks\.slack\.com/services/` |
| 5 | JWT | `eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` |
| 6 | DB URL (postgres·mysql·mongodb·redis) | `(postgres\|postgresql\|mysql\|mongodb\|redis)://[^\s]+:[^\s]+@` |
| 7 | Bearer token | `(?i)bearer\s+[A-Za-z0-9_\-\.=]{20,}` |

**매칭 시 동작**: 해당 턴 **전체 드롭** · 드롭 카운트만 `{redacted: N}` 형태로 기록. 일부 라인만 지우지 않음 (문맥 복원 방지).

#### 4.3.2 외부 secrets 탐지 도구 불허

*결정 근거: user-decisions-5 §1 · §4.1 P0-1 런타임 제약 정합.*

- `detect-secrets`, `trufflehog`, `gitleaks` 등 Python/Node 외부 도구 **금지**
- 이유: 설치 부담 + 의존 전파 + P0-1 위반
- 정밀도 보완: §4.3.1 범용 7종을 매 릴리스마다 통계 재검토 · §4.3.3 로컬 확장 훅 활용

#### 4.3.3 사내 확장 훅 (`secrets-patterns.local.json`)

*결정 근거: user-decisions-5 §1 · 범용 7종 한계 완화 fallback.*

- 플러그인 사용자가 `.claude/secrets-patterns.local.json` 파일을 두면 추가 정규식 패턴을 런타임에 로드
- 스키마(예비, §11-2 잔여 구체화 시 확정):
  ```json
  { "patterns": [ { "name": "company-ticket-id", "regex": "COMPANY-\\d{4,}", "action": "redact" } ] }
  ```
- 기본 내장 7종 해시는 `plugin.json`에 `secrets_patterns_builtin` 필드로 고정(§4.3 SHA256 무결성은 §11-2에서 설계)

#### 4.3.4 글로벌 `~/.claude/memory/` 기본 모드

*결정 근거: user-decisions-5 §1 · v2 §9.2 #11 일관.*

- 기본값: **OFF (opt-in)**
- 프로젝트 로컬 `.claude/memory/`만 기본 활성
- 글로벌 활성 조건: 플러그인 설정에서 명시 ON + 모든 메모리 파일에 **프로젝트 ID 태그** 자동 부여 (secrets 교차 오염 완전 차단은 2차 · v2 §9.2 #11 유지)
- `plugin.json` 필드(예비): `global_memory_enabled: false`

### 4.4 기타

| 분류 | 내용 |
|------|------|
| **설치** | `.claude-plugin/plugin.json` + `marketplace.json` 2파일. 외부 플러그인 의존 0 |
| **성능** | `/verify` 기본 단일 Evaluator = 1× 비용. 회색지대/승격 시 3× (**2차**) |
| **안전성** | 모든 메모리 쓰기는 **승격 게이트 통과** 시에만 (게이트 UX는 §11-3) |
| **복원성** | 세션 로그는 Claude Code JSONL 재사용. 플러그인 오류로 데이터 소실 없음. 단, 외부 스키마 안정성 가정은 §4.2 |

### 4.5 라이선스 정책 (신설 — user-decisions-5 §4 반영)

*결정 근거: user-decisions-5 §4 · 시나리오 A (2026-04-19 6상류 실측 전부 MIT 확인). 상세 호환성·sync 매트릭스는 `porting-matrix.md` §2·§4·§5 참조.*

#### 4.5.1 본 플러그인 라이선스

- **최종 채택**: **MIT**
- 근거: (a) Apache-2.0 NOTICE 추가 조항 회피로 permissive 극대화 · (b) Claude Code 생태계 대다수가 MIT · (c) 6상류 실측 전부 MIT — 호환성 문제 없음 · (d) 오픈소스 확산 목표(Phase 1 #4)와 일관
- 산출물: `LICENSE` 파일 (SPDX `MIT`) · `NOTICES.md` (6상류 저작권 고지 일괄 수록)

#### 4.5.2 기여 수용 정책

- **DCO (Developer Certificate of Origin) sign-off** 채택
- 절차: 기여자가 `git commit -s` 필수. 별도 CLA 서명·작성 불요
- 근거: Linux Kernel·Git 등 대형 OSS 표준 · 법적 최소 보호 + 기여 장벽 최소화
- 산출물: `CONTRIBUTING.md`에 `git commit -s` 예시 + DCO 전문 링크

#### 4.5.3 상류 sync 주기 (차등)

| 상류 | 의존 강도 | sync 주기 | 근거 |
|------|----------|----------|------|
| ouroboros | 높음 (qa-judge · Ralph Loop · Seed YAML) | **분기 1회** | 핵심 평가 엔진 변화 추적 |
| hoyeon | 높음 (validate_prompt · verify 6-에이전트) | **분기 1회** | 훅 패턴 변화 추적 |
| p4cn | 중간 (session-wrap · clarify · history-insight) | **반기 1회** | 알고리즘 안정적 |
| superpowers | 중간 (SessionStart · HARD-GATE · 3단 Evaluator) | **반기 1회** | 패턴 안정적 |
| CE plugin | 낮음 (5-dim overlap · Auto Memory 규약) | **연 1회** | 알고리즘만 참조 |
| agent-council | 낮음 (marketplace · Wait cursor) | **연 1회** | 구조 안정적 |

- 모든 sync는 **수동** (릴리스 주기 정규 이벤트). 자동 CI cron 전환은 **2차 릴리스**로 연기
- 각 sync 시 `porting-matrix.md` §2 `상류 커밋 해시` 컬럼 갱신

#### 4.5.4 조건부 대안 (시나리오 B·C 발생 시 재활성)

현 시점 6상류 전부 MIT로 시나리오 A 확정 — B·C는 미발동이나 미래 포팅 확장 시 참조:

- **시나리오 B (일부 GPL 발견)**: GPL 상류 자산 **포팅 제외** + MIT 유지 (v2 §9 Non-Goals에 해당 자산 이동). 대안은 알고리즘만 참조 · 코드 미포팅
- **시나리오 C (라이선스 부재, All Rights Reserved 기본값)**: 해당 상류 포팅 불가 → 원저자 연락 시도 → 실패 시 차별화 재평가 (W0 게이트로 되돌아감)

---

## 5. 아키텍처 (synthesis §5 기반)

```
harness (우리 플러그인, 공용)
├── .claude-plugin/
│   ├── plugin.json              # CE 5필드 minimal
│   └── marketplace.json         # agent-council 구조
├── hooks/
│   ├── hooks.json               # SessionStart + UserPromptSubmit + PostToolUse + Stop
│   ├── session-start            # superpowers + using-harness.md 주입
│   ├── validate-output.sh       # hoyeon validate_prompt 재주입
│   ├── drift-monitor.sh         # ouroboros PostToolUse 드리프트 (jq 재작성)
│   └── correction-detector.sh   # "틀렸다" 감지 (정확한 동작은 §11-2)
├── skills/
│   ├── using-harness/           # SessionStart 페이로드
│   ├── brainstorm/              # superpowers 9단 + p4cn clarify 3-lens
│   ├── plan/                    # CE ce-plan 5-Phase + ouroboros Seed YAML frontmatter
│   ├── verify/                  # hoyeon verify 6-에이전트 + ouroboros 3단 + Ralph Loop
│   ├── compound/                # p4cn session-wrap 2-Phase + CE 5-dim overlap
│   └── orchestrate/             # (Stretch) 내부 4축 순차
├── agents/
│   ├── _shared/charter-preflight.md
│   ├── verify/                  # hoyeon 6종 + ouroboros qa-judge
│   ├── compound/                # p4cn 5종 리네이밍
│   └── evaluator/               # superpowers 3단 (소문자 통일 — P2-2)
├── scripts/
│   ├── keyword-detector.sh      # ouroboros Python → bash+jq 재작성
│   └── extract-session.sh       # p4cn history-insight 포팅 (jq 기반)
├── CLAUDE.md
├── AGENTS.md
├── README.md + README.ko.md
├── LICENSE                      # MIT (§4.5.1)
├── NOTICES.md                   # 6상류 저작권 고지 (§4.5.1)
├── CONTRIBUTING.md              # DCO sign-off 절차 (§4.5.2)
└── (플러그인 사용자 프로젝트 측)
    .claude/memory/              # 프로젝트 로컬 기본
    ├── MEMORY.md                # 1줄 포인터 인덱스
    ├── tacit/
    ├── corrections/
    └── preferences/
```

글로벌 옵션: 플러그인 설정으로 `~/.claude/memory/` 활성화 시 **프로젝트 ID 태그 필수** (§4.3.4).

---

## 6. 포팅 자산 Top-N 발췌 (P0 MVP 필수)

synthesis §3에서 선별. 상세(6개 상류 라이선스 실측 MIT 확인 + sync 주기)는 `porting-matrix.md` §2·§4·§5 참조.

| # | 자산 | 원본 | 우리 위치 | 라이선스 |
|---|------|------|----------|---------|
| 1 | verify 6-에이전트 스택 | hoyeon | `agents/verify/` | MIT (호환) |
| 2 | Ralph Loop 의사코드 | ouroboros `skills/ralph/SKILL.md:50-99` | `skills/verify/` 본문 | MIT (호환) |
| 3 | qa-judge JSON 스키마 (0.80/0.40) | ouroboros `agents/qa-judge.md` | Evaluator 응답 포맷 (임계값은 KU-0으로 재조정 — §8) | MIT (호환) |
| 4 | session-wrap 2-Phase | p4cn `session-wrap/` | `skills/compound/` 전체 | MIT (호환) |
| 5 | `validate_prompt` + `PostToolUse` 훅 | hoyeon CLAUDE.md:27-44 | 모든 스킬 자기검증 | MIT (호환) |
| 6 | SessionStart + `using-harness.md` | superpowers `hooks/session-start` | `hooks/` | MIT (호환) |
| 7 | HARD-GATE 태그 패턴 | superpowers `brainstorming/SKILL.md:12-14` | 6축 전환 지점 | MIT (호환) |

P1/P2/P3는 synthesis §3 / `porting-matrix.md` §2 참조. **상류 6곳(hoyeon·ouroboros·p4cn·superpowers·CE·agent-council) 전부 MIT** (2026-04-19 실측 확인). 상류 커밋 해시·sync 주기는 §4.5.3 · T-W8-PRE-02.

---

## 7. 실행 로드맵 (P0-3 · P1-9 부분 반영)

### 7.1 W0 — 프리미스 재검증 (P0-3, 1일)

W1 착수 전 필수. **결과가 전제를 훼손하지 않을 때만** W1 진입.

1. Anthropic Cookbook `harness` 패턴 검색
2. DSPy / Inspect-AI / LangGraph / AutoGen 공식문서에서 "meta-framework" 섹션 확인
3. 강의 원저자(harness-day2-summary.md)의 공개 구현체 검색
4. 본인 dogfooding 로그 또는 3-5명 실사용자 인터뷰에서 "6축 축별 실제 통증" 증거 수집

**게이트 기준**:
- 전제 훼손 없음 → W1 착수 (현재 TL;DR 유지)
- 유사 frameworks 발견 → primary differentiator를 **개인화 컴파운딩**(유일하게 구체적 메카닉)으로 좁혀 재스코프 후 W1
- differentiator 없음 → §11로 돌려 재설계

### 7.2 W1~W8 (+ W7.5 KU) — MVP 구현

| 주차 | 단계 | 산출물 | 주요 자산 |
|------|------|--------|----------|
| W1 | 스캐폴드 + SessionStart + JSONL 72h smoke test 셋업 | `.claude-plugin/plugin.json` + `using-harness.md` + CI 기본 | P0 #6, §4.2 |
| W2 | `/brainstorm` MVP | `skills/brainstorm/` + clarify 3-lens 내장 | P1 #14 |
| W3 | `/plan` 하이브리드 포맷 | Markdown + YAML frontmatter | Dec 10 |
| W4 | `/verify` scaffolding + qa-judge + Ralph Loop + §4.3 보안 승격 | hoyeon 6-에이전트 (stub 응답 포함) | P0 #1·#2·#3 |
| W5 | 메모리 + 승격 게이트 UX (§11-3 구체안 적용) | `.claude/memory/` + 승격 UX | Phase 1 #6·#7 |
| W6 | `/compound` 트리거 3종 | 패턴 감지 + "틀렸다" 훅 + `/session-wrap` | P0 #4 |
| W7 | `/orchestrate` B (Stretch) | 내부 4축 순차 파이프라인 | Dec 14 |
| W7.5 | **KU 실행 + 하드닝 (P1-9 권고 반영)** | KU-0~KU-3 실험 결과 (각 20샘플, 재시도 1회 후 차단) + 하드 AC 판정 | §8 |
| W8 | 문서화 + 오픈소스 배포 (MIT LICENSE + NOTICES.md + CONTRIBUTING.md) | README 이중 + description 병기 | Dec 13 · §4.5 |

**2차 릴리스(~W12)**:
- qa-judge 회색지대 자동 Consensus (Dec 11 2차)
- `/orchestrate` C (외부 플러그인 감지 위임) (Dec 14 2차)
- `skill-rules.json` 이전 검토 (Dec 13 2차)
- 6축 **실효성 지표 KU** (§3.5 · §10.3)
- 상류 sync 자동 CI cron (§4.5.3)
- 글로벌 `~/.claude/memory/` 완전 교차 오염 방지

---

## 8. KU 실험 설계 (user-decisions-5 §2 반영)

*결정 근거: user-decisions-5 §2 · Recommended 채택. 실행 주차는 W7.5. 오너십/데이터 소스 상세는 §11-4 잔여(judge 프롬프트 등) + T-W7.5-PRE-01.*

| KU | 실험 | 성공 기준 | 샘플 수 | 실패 시 결정 | judge 방식 | 분류 |
|----|------|----------|--------|------------|----------|------|
| **KU-0** | qa-judge 점수 분포 (신규, P1-8) | histogram 기반 임계값 재조정 (0.40/0.80 → 분위수 기반) | **20** | 재시도 1회 후 차단 | 자동 스크립트 (histogram 측정) | **MVP 하드** |
| KU-1 | 6축 `validate_prompt` 자동 재주입 신뢰도 | 훅 발동률 ≥ 99% + 응답률 ≥ 90% | **20** | 재시도 1회 후 차단 | 자동 훅 계측 (발동률) + **자동 LLM judge 서브에이전트** (응답률 KU-1b) | MVP 하드 |
| KU-2 | description 한·영 병기 트리거 정확도 (A/B) | 영어만과 동등 (양방향 기준 — P1-3) | **20 × 2 = 40** (한·영 각각) | 재시도 1회 후 차단 | 자동 LLM judge 서브에이전트 | MVP 하드 |
| KU-3 | 승격 게이트 오검지율 | false positive < 20% | **20** | 재시도 1회 후 차단 | 자동 LLM judge 서브에이전트 | MVP 하드 |
| KU-4 | Consensus Evaluator 편향 차이 | self vs fresh-context ≥ 15% | TBD | TBD | TBD | **2차** (의존 기능이 2차) |
| KU-5 | oscillation 감지 과적합 방지율 | 유용 학습 억제 < 10% | TBD | TBD | TBD | **2차** |
| KU-6 | **6축 실효성** (신규, §3.5 유예) | 축 통과가 산출물 품질 향상과 상관 r ≥ 0.3 | TBD | TBD | TBD | **2차** (dogfooding 데이터 수집 후 설계) |

### 8.1 KU 실행 스펙 (§11-4 승격분)

- **각 KU 공통 샘플 수**: 20건 (KU-2는 언어별 20건씩 실효 40건)
  - 선택 근거: 이진 판정 95% CI 폭 n=10 → ±30%p, n=20 → ±22%p, n=30 → ±17%p → **20이 MVP 실행 가능성·통계 유의성의 타협점** (user-decisions-5 §2)
- **실패 시 정책**: **재시도 1회 후 차단**
  - 1차 미달 → 스키마/프롬프트 튜닝 → 재측정 → 2차 미달 시 **W8 릴리스 차단**
  - 베타 태그 부분 릴리스는 **선택하지 않음** (품질 명확성 우선)
- **judge 에이전트 (KU-1b 포함) 구현 방식**: **자동 LLM judge 서브에이전트**
  - 프롬프트 기반 판정 · 기대 출력 스키마 명세 · CI 재실행 가능 (reproducibility)
  - 모델 편향 교차 검증은 KU-4(2차)로 위임
- **잔여 (§11-4 유지)**: judge 에이전트 시스템 프롬프트 · 기대 출력 스키마 · 데이터 소스 매핑. W7.5 이전 `T-W7.5-PRE-01`에서 승격.

---

## 9. Non-Goals / Stop Doing (P0-4 반영)

MVP에서 **명시적 제외**:

### 9.1 영구 제외
1. Python/Node 런타임 의존 (**jq/awk는 허용** — P0-1)
2. SQLite EventStore / Textual TUI / LiteLLM (ouroboros 고급 기능)
3. Visual Companion 브라우저 서버 (superpowers)
4. CE "cross-skill 참조 금지" 정책 (우리는 6축 간 조합이 primary → 반대 정책)
5. 즉시 학습 저장 (승격 게이트 없이)
6. 단일 모델 자가 Consensus (KU-4 위반)
7. 체크리스트식 6축 준수 (실효성 지표 없는 형식 포함) — 6축 강제 적용 범위는 **§3.5**에서 명세. *각주: 실효성 지표 KU는 MVP 연기(2차 KU-6), dogfooding 로그로 2차 설계 (§10.3).*
8. **외부 secrets 탐지 도구 의존** (detect-secrets · trufflehog 등 — §4.3.2)
9. **GPL 전염 자산 포팅** (현 시점 시나리오 A라 미해당, §4.5.4 시나리오 B 발동 시 재활성)

### 9.2 2차 릴리스(~W12)로 명시 연기 — **신규 (P0-4)**
10. `qa-judge` 회색지대 **자동** Consensus (MVP는 수동 승격으로 fallback)
11. `/orchestrate` C (외부 플러그인 감지·위임)
12. `skill-rules.json` 이전 (MVP는 description 한·영 병기)
13. 글로벌 `~/.claude/memory/` 교차 오염 방지 완전 구현 (MVP는 기본 off, 프로젝트 ID 태그 필수 옵션만 — §4.3.4)
14. **6축 실효성 지표 KU** (KU-6 — §3.5 결정)
15. **상류 sync 자동 CI cron** (§4.5.3 — MVP는 수동 차등)

---

## 10. 성공 기준 (P0-4 재구성)

### 10.1 Hard AC — W8 릴리스 차단 기준 (미달 시 미배포)

- [ ] `.claude-plugin/plugin.json` + `marketplace.json` 설치 성공 (외부 의존 0)
- [ ] `/brainstorm`·`/plan`·`/verify`·`/compound` **4개 스킬** 호출 가능
- [ ] 각 스킬 `validate_prompt` 자기검증 훅 발동률 ≥ 99% **AND** 실제 응답률 ≥ 90% (KU-1, 20샘플, 재시도 1회 후 차단)
- [ ] description 한·영 병기 트리거 정확도 (KU-2, 언어별 20샘플, 양방향 기준, 재시도 1회 후 차단)
- [ ] 승격 게이트 오검지 < 20% (KU-3, 20샘플, 재시도 1회 후 차단)
- [ ] 세션 JSONL 파서가 3가지 컴파운딩 트리거 모두 **감지** (감지 정확도는 KU-3에 포함)
- [ ] qa-judge 점수 분포 KU-0 완료 (20샘플) 및 임계값 확정
- [ ] README + README.ko.md 이중 + 한·영 description 실증
- [ ] `LICENSE` (MIT) + `NOTICES.md` + `CONTRIBUTING.md` (DCO) 준비 (§4.5)

### 10.2 Stretch — W8 목표, 미달 시 2차 연기

- [ ] `/orchestrate` 단일 완결형 B 동작 (내부 4축 순차)
- [ ] `.claude/memory/` 글로벌 전환 옵션 (기본 off + 프로젝트 ID 태그 필수 — §4.3.4)

### 10.3 2차 릴리스(~W12)

- qa-judge 회색지대 **자동** Consensus
- `/orchestrate` C (외부 플러그인 감지 위임)
- `skill-rules.json` 이전 검토
- **6축 실효성 지표 KU (KU-6)** — §3.5 "실효성 지표" 연기분. MVP dogfooding 로그를 입력으로 설계
- **상류 sync 자동 CI cron** (§4.5.3)
- 글로벌 메모리 완전 교차 오염 방지

---

## 11. 설계 미결 (본 문서 업데이트 필요 — `/ce-plan` 입력 전 혹은 해당 주차 이전)

P0-2·P0-5·P0-6·P0-7·P0-8 과 P1 주요 이슈 중 본 v3에 아직 구체 사양이 없는 항목. 각 항목은 해당 주차 시작 전 본 문서 내 섹션으로 승격되어야 함.

**v3 승격 완료 (user-decisions-5)**: §11-2 일부 · §11-4 일부 · §11-5 전체 · §11-6 전체 · §11-7 포지셔닝. 상세는 `v3-change-log.md`. 잔여는 아래.

### 11-1. JSONL 외부 스키마 안정성 구체안 (P0-2, W1 이전 완료)
- 스키마 어댑터 레이어 정확한 타입 시그니처
- UserPromptSubmit 훅 기반 라이브 캡처 fallback 구현 세부
- CC 릴리스 72시간 smoke test 체크리스트 (CI 어떤 이벤트를 검증?)
- 포맷 붕괴 시 degradation UX (사용자 알림 방식)

### 11-2. 보안 완전 사양 (P0-5·P0-8 잔여, W4 이전 완료)
**→ 결정분(§4.3.1~§4.3.4)은 v3에서 승격 완료. 이하는 잔여분.**

- **훅 페이로드 무결성 SHA256 상세**: `using-harness.md` SHA256을 `plugin.json`에 고정, 세션 시작 시 해시 불일치 감지 → 주입 거부 + 경고. `secrets_patterns_builtin` 해시 고정 세부(§4.3.3 스키마 확정 포함)
- **correction-detector 부정 문맥 확인 (P1-7)**: 문자열 매칭 + 직전 assistant 턴 부정 문맥 판별 규칙
- **훅 실행 순서 명세**: `hooks.json`의 `PostToolUse`에 `validate-output` + `drift-monitor` + `correction-detector` 공존 시 실행 순서 + 실패 전파 정책

### 11-3. 승격 게이트 UX 전체 사양 (P0-6, W5 이전 완료)
- §3.4 승격 게이트 신규 섹션 6단계 명세
- 단계: 후보 생성 → Evaluator 점수 → 자동 판정(≥0.80 자동 승격 / ≤0.40 자동 기각 / 회색지대 수동 승격) → 사용자 확인 UX(y/N/e/s) → 저장 → 거부 이력
- **Consent fatigue 완화**: 세션 종료(Stop hook) 시 일괄 제시 + 동일 패턴 3회 연속 거부 시 detector 임시 비활성화 제안

### 11-4. KU 실험 실행 상세 (P0-7, W7.5 이전 완료)
**→ 샘플 수·실패 정책·judge 방식은 v3에서 §8 테이블에 승격 완료. 이하는 잔여분.**

- judge 에이전트(KU-1b) **시스템 프롬프트 전문** 및 기대 출력 스키마
- KU-0 histogram 측정 자동화 스크립트 (qa-judge 점수 N건 수집 → histogram → 분위수 기반 임계값 계산 → v2 §4/§10 diff)
- 각 KU별 **데이터 소스 매핑** (어느 세션 · 어느 훅 로그 · 어느 Evaluator 출력)

### 11-5. 6축 강제 적용 범위 (P1-5)
**→ v3에서 §3.5로 승격 완료. 본 항목 미결 해제. 실효성 KU(KU-6)는 §10.3 2차 릴리스에 등재.**

### 11-6. 라이선스 · 상류 sync (P1-10)
**→ v3에서 §4.5로 승격 완료 (시나리오 A · MIT · DCO · 분기/반기/연 차등). 본 항목 미결 해제. 상류 커밋 해시 확보 + `NOTICES.md` 초안은 W8 이전 T-W8-PRE-02에서 실행.**

### 11-7. 기타 설계 미결
- **프론트매터 필드** (스킬 5개 각각의 name/description/when_to_use/input/output 확정) — W2~W7 각 스킬 구현 시작 시
- ~~**포지셔닝 1문장** (P1-1)~~ **→ v3에서 §1 TL;DR 상단으로 승격 완료.**
- **OSS composability** (P1-2) — 각 스킬 독립 사용 가능 여부 명세 (예: `/verify` 단독 설치)
- **`/orchestrate` 실질 가치 vs 수동 호출 비교표** (P1-4) — W7 시작 전

---

## 12. Phase 4 이관 — 태스크 분해 대상 (P0-9 분리)

§11이 닫힌 뒤에야 `/ce-plan`이 다룰 항목. **설계가 아니라 구현 분해**:

- W0 프리미스 재검증 각 스텝의 구체 실행 태스크
- W1~W8 (+W7.5) 주차별 구현 태스크 (각 스킬 파일 작성, 훅 스크립트 구현, 테스트 추가)
- `marketplace.json` 카테고리·태그 세부 입력
- 훅 스크립트 bash + jq 실제 구현 코드 (§4.3 secrets 7종 + 로컬 확장 훅 구현)
- `LICENSE` · `NOTICES.md` · `CONTRIBUTING.md` 파일 내용 실제 작성 (§4.5)
- CI 설정 (JSONL smoke test, 훅 해시 검증 테스트)
- README 템플릿 채우기 (§1 포지셔닝 문장 첫 문장 배치)

---

## 13. 다음 단계

**권장**: 본 v3 문서로 `/compound-engineering:ce-plan` 실행 (§11 잔여 항목은 해당 주차 전까지 승격 과제로 두고, 태스크 분해에 포함).

**대안**:
- §11 잔여 전체 해소 후 `/ce-plan` — 더 안전하지만 2-3일 추가 투자
- 바로 W0 프리미스 재검증 실행 → 결과에 따라 v4 생성 또는 재스코프

---

*Phase 1+2+3 + Review + user-decisions-5 반영 최종 스펙 v3. 잔여 P0(2/5/6/7/8 일부) + P1 주요는 §11에 명시적 등재되어 해당 주차 이전 승격 대상.*

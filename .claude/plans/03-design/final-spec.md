# 하네스 플러그인 — 최종 요구사항 스펙 v3.3 (§11-3 승격 완료)

> Phase 1 명확화 + Phase 2 레퍼런스 리서치 + Phase 3 브레인스토밍 + Phase 3.5 document-review + user-decisions-5 5건 + T-W1-PRE-01 §11-1 승격 반영 최종 문서.
> `/ce-plan` 입력으로 바로 쓰기 위한 단일 진실 소스(single source of truth).

- **작성일**: 2026-04-19 (v1), 2026-04-19 (v2: review applied), 2026-04-19 (v3: user-decisions-5 반영), 2026-04-19 (v3.1: §11-1 승격)
- **변경 이력 v3.2 → v3.3 (2026-04-19)**: **§11-3 승격 (T-W5-PRE-01 완료)** — 승격 게이트 UX 6-Step 파이프라인 · 후보 객체 스키마 · y/N/e/s 응답 · Consent fatigue 완화 · ASCII wireframe을 §3.4 정식 소절로 승격. draft `04-planning/s11-3-ux-draft.md` 전문은 상세 본문으로 보존. §11-3 미결 해제.
- **변경 이력 v3.1 → v3.2 (2026-04-19)**: **§11-2 승격 (T-W4-PRE-01 완료)** — 보안 완전 사양 잔여 3항목(훅 페이로드 SHA256 무결성 · PostToolUse 훅 실행 순서 · correction-detector 부정 문맥 규칙)을 §4.3.5·§4.3.6·§4.3.7 정식 소절로 재작성. §11-2 미결 해제.
- **변경 이력 v3 → v3.1 (2026-04-19)**: **§11-1 승격 (T-W1-PRE-01 완료)** — JSONL 외부 스키마 안정성 4항목(스키마 어댑터 타입 시그니처 · UserPromptSubmit fallback 순서도 · 72h smoke test 체크리스트 · degradation UX)을 §4.2 정식 섹션으로 재작성. §11-1은 "→ §4.2 참조" 한 줄로 축소(추적성 보존). 상세 diff는 `v3-change-log.md` §9 참조.
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

### 3.4 승격 게이트 UX 전체 사양 (T-W5-PRE-01 승격, 2026-04-19)

> **결정 근거**: P0-6 (final-spec-review) · `04-planning/s11-3-ux-draft.md` 6 섹션 정식화.
> **배경**: 승격 게이트는 메모리 오염(§2.1 #6)의 **유일한 차단 메카닉**. 자동 저장 폭주·Consent fatigue·구현자 임의 해석 3 리스크를 봉쇄.

#### 3.4.1 6-Step 파이프라인

| Step | 역할 | 구현 시점 |
|------|------|----------|
| 1. 후보 생성 | 3 트리거(`pattern_repeat` / `user_correction` / `session_wrap`) → 큐 적재 | T-W6 · `.claude/state/promotion_queue/` |
| 2. Evaluator 점수 | 다른 관점 fresh-context 서브에이전트(Sonnet) · qa-judge JSON 재사용 | W4 qa-judge ✅ |
| 3. 자동 판정 | `≥0.80` promote queue · `≤0.40` auto reject · `0.40~0.80` gray (2차 Consensus, MVP 수동 fallback) | W4 임계값 ✅ + §2.2 Dec 11 |
| 4. 사용자 확인 UX | Stop hook 일괄 제시 · `[y / N / e / s]` 선택 (기본 `N`) · AskUserQuestion | T-W5-06 |
| 5. 저장 | 승인 시 `.claude/memory/{tacit\|corrections\|preferences}/` + MEMORY.md 인덱스 + frontmatter(`candidate_id`·`promoted_at`·`evaluator_score`·`source_turn`) | T-W5-01·03·05 |
| 6. 거부 이력 | `corrections/_rejected/{candidate_id}.md` 보존 + 과적합 감지 입력 | T-W5-08 |

#### 3.4.2 후보 객체 스키마

```yaml
candidate_id: <uuid-v4>
trigger_source: pattern_repeat | user_correction | session_wrap
content: <free text>
context:
  session_id: sess_<YYYYMMDD>_<HHMMSS>
  turn_range: <start>-<end>
  related_files: [path, ...]
detected_at: <ISO-8601 UTC>
```

#### 3.4.3 Step 4 사용자 응답 키

| 키 | 의미 | 다음 동작 |
|----|------|----------|
| `y` | 승인 | Step 5 저장 |
| `N` | 거부 (기본값) | Step 6 이력 |
| `e` | 수정 후 승인 | 별도 프롬프트로 본문 수정 기회 → 저장 |
| `s` | 건너뛰기 | 다음 session_wrap 재제시 |

#### 3.4.4 Consent Fatigue 완화

- **Mid-session 중단 금지**: Stop hook에서만 일괄 제시. 최대 10 후보 / 세션, 초과 시 다음 세션.
- **우선순위**: score 높은 순 (중요 결정 먼저, 피로 최소 상태에서 판정).
- **동일 패턴 3회 연속 거부 시 detector 임시 비활성화**: 7일 자동 비활성 + 유저 `/compound --reactivate <detector_id>` 수동 재활성화.

#### 3.4.5 ASCII Wireframe

```
════════════════════════════════════════════════════════════════
  Harness Compound — 세션 종료 승격 후보 (3건)
════════════════════════════════════════════════════════════════
[1/3] 🟢 score=0.87 · trigger=pattern_repeat
  저장 경로: tacit/<slug>.md
  요약: "..."
  source: sess_YYYYMMDD_HHMMSS · turn N-M
  dimensions: correctness=0.9 clarity=0.85
  [y]승인  [N]거부  [e]수정 후 승인  [s]건너뛰기 >
[2/3] ...
```

상세 6-Step 구현 매핑 · 열린 질문(자동 비활성화 기간 · `e` UX · Stop hook 실현성)은 `04-planning/s11-3-ux-draft.md` 참조.

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

### 4.2 JSONL 외부 스키마 안정성 (정식 — T-W1-PRE-01 승격, 2026-04-19)

*결정 근거: P0-2 대응 · §11-1 4항목 승격 완료 (T-W1-PRE-01). 상세 diff는 `v3-change-log.md` §9 참조.*

#### 4.2.0 원칙

- `~/.claude/projects/*.jsonl`은 **Anthropic 비공식 포맷** (Claude Code 내부 사양 · 공식 스키마 문서 부재).
- 본 플러그인은 이 포맷의 안정성을 **전제하지 않는다**. 모든 JSONL 파싱은 defensive parser 원칙(unknown → skip + log) + 라이브 캡처 fallback + 포맷 붕괴 감지 루프를 **필수 설계**로 포함한다.
- 포맷 붕괴 시 사용자에게 **즉시 가시화** + 컴파운딩 **자동 비활성화** (전체 세션 실패 없음).

#### 4.2.1 스키마 어댑터 (`scripts/schema-adapter.sh`) 동작 명세

**입력·출력 계약**:

```
입력 (stdin): JSONL 라인 1개
처리:
  1. .type 필드 추출          ── jq -r '.type // "unknown"'
  2. .schema_version 필드 추출 ── jq -r '.schema_version // "v0"'
  3. (type, schema_version) 쌍을 adapter 함수로 dispatch
  4. 매핑 없는 경우 → skip + stderr 로그 (처리 중단 아님)
출력 (stdout): 정규화된 JSON (single-line)
종료 코드:
  0 → 정규화 성공 (또는 skip 성공)
  1 → JSON 파싱 불가 (jq 에러) → 상위 파이프에서 count만 집계
  2 → 치명적 런타임 에러 (jq 없음 등) → 호출자에게 전파
```

**최소 초기 dispatch 매핑 (3종 · p4cn `session-file-format.md` 기반)**:

| (type, schema_version) | 어댑터 함수 | 출력 정규화 |
|------------------------|------------|-----------|
| `("file-history-snapshot", "v0")` | `parse_fhs_v0` | `{kind: "fhs", path, sha, ts}` |
| `("user-prompt", "v0")` | `parse_user_prompt_v0` | `{kind: "prompt", text, ts, session_id}` |
| `("assistant-turn", "v0")` | `parse_assistant_turn_v0` | `{kind: "turn", text, tool_calls, ts}` |
| 기타 | `skip_with_log` | (stdout 빈 줄) + stderr `skipped: <type>@<schema_version>` |

- **확장 규약**: 새 `type` 발견 시 스크립트 상단 `ADAPTERS` 연관 배열에 한 줄 추가. 함수명 네이밍은 `parse_<slug>_<schema_version>`.
- **알 수 없는 `type` 처리**: 무조건 `skip_with_log` → 전체 파이프라인 **계속 진행**. 스킵 카운터는 `stderr`에 `skipped_count:N` 라인으로 주기적 emit (100줄마다).
- **정규화 스키마 계약**: 모든 어댑터 출력은 `{kind: string, ts: ISO8601}` 공통 필드를 포함해야 한다. 나머지 필드는 어댑터별 자유.
- **bash+jq 재작성 제약**: Python·Node 불허 (§4.1 P0-1 정합). 변수 보간은 `"$var"` + `printf '%s'` 패턴만 허용 (§4.3 P0-8 정합).

#### 4.2.2 Fallback 순서도 — 3단 degradation

```
┌─────────────────────────────────────────────┐
│ [Primary] JSONL 파서 (scripts/extract-session.sh) │
│   → schema-adapter.sh 통해 정규화           │
└─────────────┬───────────────────────────────┘
              │ 실패 조건 도달
              ▼
┌─────────────────────────────────────────────┐
│ [Secondary] UserPromptSubmit 훅 live 캡처   │
│   → hooks/capture-live.sh 가 turn을          │
│     .claude/memory/_live/<session>.jsonl로    │
│     실시간 기록 (플러그인 자체 포맷 · v0)    │
└─────────────┬───────────────────────────────┘
              │ 실패 조건 도달
              ▼
┌─────────────────────────────────────────────┐
│ [Tertiary] 컴파운딩 자동 비활성화            │
│   → SessionStart 경고 배너 + /compound 호출 │
│     시 명시적 에러 + MEMORY.md degraded 플래그│
└─────────────────────────────────────────────┘
```

**Primary → Secondary 전환 조건 (수치화)**:

- 최근 10 세션 기준 **schema error 발생률 > 30%** → Secondary로 자동 전환
  - "schema error" = `schema-adapter.sh` 종료 코드 1 + unknown `type` 스킵 누적 비율 합산
  - 측정 창은 세션 종료(Stop hook) 시점에 슬라이딩 윈도우로 갱신
  - 전환 플래그: `.claude/memory/_live/fallback.json` → `{tier: "secondary", since: "<ISO8601>", reason: "schema_error_rate_0.34"}`
- 전환은 **자동**이나, 사용자에게 SessionStart 배너로 1회 알림 (§4.2.4 참조)

**Secondary → Tertiary 전환 조건**:

- Live 캡처 훅이 최근 3 세션 연속으로 **페이로드 미수신** 또는 `hooks/capture-live.sh` 종료 코드 ≠ 0
- 전환 시 `.claude/memory/_live/fallback.json` → `{tier: "tertiary", since: "<ISO8601>", reason: "live_capture_failed_3x"}`

**복구 (Tertiary → Secondary → Primary)**:

- 자동 복구는 **하지 않는다** (무한 전환 루프 방지). 사용자가 `/compound --reactivate` 호출 시 fallback.json 삭제 → 다음 세션에서 Primary 재시도.

#### 4.2.3 72h smoke test 체크리스트 (GitHub Actions cron)

- **실행 주기**: cron `0 */72 * * *` 아님 — cron은 **3일마다 고정 시각 1회** (`0 9 */3 * *`, UTC 09:00).
- **워크플로 위치**: `.github/workflows/jsonl-smoke-test.yml` (W1 T-W1-08)
- **검증 체크 항목 (5종 모두 통과 필요)**:

  - [ ] **C-1 JSONL 파싱 에러율 < 5%** — 최근 7일치 `~/.claude/projects/*.jsonl` 샘플에서 `schema-adapter.sh` 종료 코드 1 비율
  - [ ] **C-2 unknown `type` 출현 여부** — `skip_with_log` 누적 라인에서 새 `type`/`schema_version` 조합 발견 시 알림 이벤트 발화 (GitHub Issues auto-create)
  - [ ] **C-3 schema_version 분포** — 특정 버전 점유율이 **90% 이상 변화**(Δ) 시 경고. 기준선은 `.github/baseline/schema_version_distribution.json`에 고정, 매 릴리스마다 갱신
  - [ ] **C-4 adapter dispatch 누락 카운트 = 0** — 알려진 `type`이 매핑표에서 빠진 경우 (회귀 테스트)
  - [ ] **C-5 Claude Code 최근 릴리스 72h 내 여부 + 릴리스 노트 키워드 grep** — `gh release list` 결과에서 72h 내 릴리스 존재 시 노트 본문에 `jsonl` · `session` · `schema` 키워드 grep. 매칭 시 수동 재검토 플래그 (fail 처리는 아님 · Issue 자동 생성)

- **실패 시 동작**:
  - C-1·C-4 실패: **CI red** (머지 차단)
  - C-2·C-3·C-5 실패: **CI yellow** (경고만 + GitHub Issue 자동 생성 · 머지 차단 아님)
- **베이스라인 관리**: `baseline/schema_version_distribution.json`은 릴리스 PR마다 `T-W8-06` 체크리스트에서 검증 (W8).

#### 4.2.4 Degradation UX — 포맷 붕괴 시 사용자 알림

**3채널 병행 알림** (사용자가 어느 경로로 접근해도 degraded 상태를 확인 가능):

1. **SessionStart 페이로드 배너 (1줄)**:
   ```
   ⚠️ harness: JSONL compounding degraded (tier=<secondary|tertiary>, since=<date>). See /compound --status.
   ```
   - `hooks/session-start`가 `.claude/memory/_live/fallback.json` 존재 시 `using-harness.md` 페이로드 상단에 자동 삽입
   - 매 세션 1회 (중복 suppression은 안 함 — 명시적 가시화 우선)

2. **`/compound` 호출 시 명시적 에러 메시지**:
   - **Secondary 단계**: "⚠️ Primary JSONL parser disabled. Using live capture fallback. Compounding continues but may miss older turns. Reason: <reason>. Recover with `/compound --reactivate`."
   - **Tertiary 단계**: "❌ Compounding disabled (tier=tertiary). Reason: <reason>. Rollback JSONL format or run `/compound --reactivate` after verifying."
   - `--status` 하위 명령: 현재 tier · since · reason · 최근 10 세션 에러율을 표로 출력

3. **`MEMORY.md` 헤더 YAML 플래그**:
   ```yaml
   ---
   degraded: true
   tier: secondary   # or tertiary
   since: 2026-04-23T14:12:00Z
   reason: schema_error_rate_0.34
   ---
   ```
   - Tertiary 단계에서만 `MEMORY.md` 최상단 frontmatter 자동 삽입 (Secondary는 `fallback.json`에만 기록 · `MEMORY.md`는 건드리지 않음)
   - 플래그가 살아있는 동안 `/compound` 자동 트리거는 비활성. 수동 `/compound --force` 만 허용 (경고 배너와 함께)

**Consent fatigue 완화**: SessionStart 배너는 같은 tier·reason이 **14일 이상 지속**되면 주 1회로 빈도 축소(hooks/session-start가 fallback.json의 `since` 필드로 계산).

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

---

### 4.3.5 훅 페이로드 SHA256 무결성 (T-W4-PRE-01 승격, 2026-04-19)

하네스가 SessionStart 등으로 주입·실행하는 훅·스킬 페이로드의 변조를 감지하기 위해 SHA256 해시 고정.

- 대상 파일: `skills/using-harness/SKILL.md`, `hooks/session-start.sh`, `hooks/validate-output.sh`, `hooks/drift-monitor.sh` (+ 향후 추가 훅)
- 고정 위치: `.claude-plugin/plugin.json` 내 `harness.payload_sha256` 객체
  ```json
  "harness": {
    "payload_sha256": {
      "skills/using-harness/SKILL.md": "abc123...",
      "hooks/session-start.sh": "def456...",
      ...
    }
  }
  ```
- 검증 시점: `hooks/session-start.sh` 실행 시 각 대상 파일의 현재 해시를 `sha256sum`으로 계산 후 `plugin.json` 값과 비교
- 불일치 처리: stderr 경고 (`WARN: payload hash mismatch for <file>`) + 해당 페이로드 **주입 거부** + `exit 0` (세션 진입은 차단 금지)
- 해시 갱신 도구: `scripts/update-payload-hashes.sh` (T-W4 범위) — 개발자가 훅 파일 수정 후 실행하면 `plugin.json` 해시 자동 갱신

### 4.3.6 PostToolUse 훅 실행 순서

`hooks.json`의 PostToolUse 배열은 다음 **고정 순서**로 실행한다 (순서 변경 금지, 각 훅은 독립 실행 · stdout 체이닝 없음).

1. **`validate-output.sh`** (W2 완료) — `validate_prompt` 재주입 advisory
2. **`drift-monitor.sh`** (T-W4-07 범위) — 드리프트 advisory
3. **`correction-detector.sh`** (W6 예정) — "틀렸다" 감지 → `/compound` 승격 후보 생성

제약:
- 총 실행 시간 상한: **3초** (advisory 목적, blocking 금지)
- 각 훅 stderr는 Claude Code로 전달 (advisory 표시용), stdout은 무시
- 훅 내부에서 **세션 state 변경 금지** (read-only + advisory만)

### 4.3.7 correction-detector 부정 문맥 규칙 (P1-7 반영)

`correction-detector.sh`의 false positive 폭증 방지 휴리스틱. W6 구현 기준.

- **키워드**: `틀렸`, `wrong`, `incorrect`, `잘못` (case-insensitive)
- **부정 문맥 확인** (단독 키워드 매칭 금지):
  1. 직전 assistant 턴 length ≥ 20자 (완전한 주장이었음을 확인)
  2. 매칭 문장이 직전 assistant 턴의 핵심 명사를 포함 (coreference 근사)
  3. 3인칭 서술 (`X가 틀렸다`) · 코드 리뷰 (`이 assertion은 틀렸다`) · 반어법 여부는 MVP에서 처리 안 함 → **false positive는 허용**하고 승격 게이트 UX(§3.4, §11-3)에서 유저가 최종 거부 가능
- **MVP 정확도 목표**: precision ≥ 0.7 (KU에 추가 반영 — §8)
- **트리거 후 동작**: `/compound --candidate correction` 프리셋으로 AskUserQuestion 제시 (승격 게이트 Step 1 candidate 생성)

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
- **judge 에이전트 시스템 프롬프트** (KU-1·2·3·4 공유, KU-0은 규칙 기반):
  - 경로: `agents/evaluator/ku-judge.md` (name: `ku-judge`, model: sonnet, tools: Read/Grep)
  - 입력: `{ku_id, sample_id, sample, expected_criteria, pass_threshold(기본 0.80)}`
  - 출력: **정확히 1개 JSON 객체**, 전후 공백·마크다운 금지
- **기대 출력 스키마**:
  ```json
  {"ku_id":"KU-1","sample_id":"ku1-03","pass":true,"score":0.92,"reasoning":"≤240 chars"}
  ```
- **데이터 소스 매핑**:
  - 실 세션 우선: `.claude/logs/sessions/*.jsonl` (dogfooding 로그 존재 시)
  - 합성 fixture fallback: `__tests__/fixtures/ku-{0,1,2,3}-*/` (MVP 기본값)
  - 결과 JSON에 `data_source: real_session | synthetic` 필드 기록 필수
- **KU-0 histogram 자동화**: `scripts/ku-histogram.sh` (stdin score list → JSON 분위수 p10/25/50/75/90) + `scripts/ku-0-run.sh` drive
- **공통 래퍼**: `scripts/ku-harness.sh` — `ku_run <ku_id> <fixture_dir> <pass_fn> <retry_fn> <results_out>` + `ku_decide` / `ku_decide_lt` (재시도 1회 후 차단 내장)
- **§11-4 status**: **승격 완료** (T-W7.5-PRE-01, 2026-04-19). 본 항목 미결 해제.

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

**v3.1 승격 완료 (T-W1-PRE-01)**: §11-1 전체 → §4.2 정식화. 상세는 `v3-change-log.md` §9.

### 11-1. JSONL 외부 스키마 안정성 구체안 (P0-2)
**→ §4.2 참조. 승격 완료 2026-04-19 (T-W1-PRE-01). 4항목(어댑터 타입 시그니처 · fallback 3단 · 72h smoke 체크리스트 · degradation UX) 전부 §4.2.1~§4.2.4에 정식화. 본 항목 미결 해제.**

### 11-2. 보안 완전 사양 (P0-5·P0-8 잔여, W4 이전 완료)
**→ 결정분(§4.3.1~§4.3.4)은 v3에서 승격 완료.**
**→ 잔여분(SHA256 무결성 · correction-detector 부정 문맥 · PostToolUse 훅 실행 순서)은 v3.2에서 §4.3.5·§4.3.6·§4.3.7로 승격 완료 (T-W4-PRE-01, 2026-04-19). 본 항목 미결 해제.**

### 11-3. 승격 게이트 UX 전체 사양
**→ v3.3에서 §3.4로 승격 완료 (T-W5-PRE-01, 2026-04-19). 6-Step · 후보 스키마 · y/N/e/s · Consent fatigue 완화 · ASCII wireframe 정식 본문. 상세 draft는 `04-planning/s11-3-ux-draft.md`. 본 항목 미결 해제.**

### 11-4. KU 실험 실행 상세 (P0-7, W7.5 이전 완료)
**→ 샘플 수·실패 정책·judge 방식은 v3에서 §8 테이블에 승격 완료.**
**→ 잔여분(judge 에이전트 시스템 프롬프트 · 기대 출력 스키마 · KU-0 histogram 자동화 · 데이터 소스 매핑)은 v3.3에서 §8.1로 승격 완료 (T-W7.5-PRE-01, 2026-04-19). 본 항목 미결 해제.**

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

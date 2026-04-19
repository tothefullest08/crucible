# 하네스 플러그인 — 구현 태스크 분해 (Phase 4 `/ce-plan` 산출물)

> **입력**: `.claude/plans/03-design/final-spec.md` v2 (단일 진실 소스)
> **자매 산출물**: `04-planning/porting-matrix.md`, `04-planning/section11-promotion-tracker.md`
> **작성일**: 2026-04-19
> **목적**: 구현 태스크 분해 전용. 실제 코드·파일 생성은 이 Phase의 범위 밖.

---

## 0. 요약

- **주차 구성**: W0(프리미스 재검증 1일) + W1~W8 + W7.5 (KU 실행 + 하드닝)
- **태스크 ID 체계**: `T-W{주차}-{순번}` (예: `T-W4-03`). 승격 선행 태스크는 `T-W{주차}-PRE-{순번}`
- **공수 합계**:
  - **Hard AC 경로** (Stretch 제외): 346h ≈ **8.65주** → 9주 한도 내
  - **Stretch 포함**: 386h ≈ 9.65주 → W7 (/orchestrate) 전량 Stretch로 9주 초과분 흡수
- **Hard AC 8개 모두** 특정 태스크로 추적 가능 (§5 매핑 테이블)
- **§11 승격 과제 7개 모두** 해당 주차 PRE 태스크로 스케줄링

## 1. 위험 플래그 · Stretch 표기 규약

| 표기 | 의미 |
|------|------|
| 🚨 P0-1 | bash+jq 재작성 제약 위반 시 전면 재작업 위험 |
| 🚨 P0-2 | `~/.claude/projects/*.jsonl` 외부 스키마 리스크 |
| 🚨 P0-5 | Secrets redaction 미구현 → 컴파운딩 오염 위험 |
| 🚨 P0-8 | 훅 보안 (변수 보간 · `eval` · 해시 검증) 위반 위험 |
| `[Stretch]` | v2 §10.2 Stretch AC 또는 2차 릴리스 연기 허용 태스크 |
| ⛳ §11-N 승격 | 해당 주차 착수 전 v2 §11-N을 정식 섹션으로 승격해야 함 |

## 2. 의존성 그래프 (ASCII)

```
W0 (프리미스 재검증)
 │
 └ gate 통과 ──> W1 (스캐폴드 + JSONL smoke)
                  │  ⛳ §11-1 승격 선행
                  v
                 W2 (/brainstorm MVP)
                  │
                  v
                 W3 (/plan 하이브리드)
                  │
                  v
                 W4 (/verify + qa-judge)
                  │  ⛳ §11-2 승격 선행
                  v
                 W5 (메모리 + 승격 게이트 UX)
                  │  ⛳ §11-3 승격 선행
                  v
                 W6 (/compound 트리거 3종)
                  │
                  ├──> W7 [Stretch] (/orchestrate B)
                  │
                  v
                 W7.5 (KU 실행 + 하드닝)
                  │  ⛳ §11-4 승격 선행
                  v
                 W8 (문서화 + 배포)
                    ⛳ §11-5 · §11-6 · §11-7 승격 선행
```

```mermaid
flowchart TD
    W0[W0 프리미스 재검증] -->|gate| W1[W1 스캐폴드<br/>§11-1]
    W1 --> W2[W2 /brainstorm]
    W2 --> W3[W3 /plan]
    W3 --> W4[W4 /verify<br/>§11-2]
    W4 --> W5[W5 메모리+게이트<br/>§11-3]
    W5 --> W6[W6 /compound]
    W6 --> W7[W7 /orchestrate<br/>[Stretch]]
    W6 --> W75[W7.5 KU 실행<br/>§11-4]
    W7 --> W75
    W75 --> W8[W8 문서화+배포<br/>§11-5/6/7]
```

---

## 3. 주차별 태스크

### W0 — 프리미스 재검증 (1일 / 8h)

> v2 §7.1 기준. 게이트 기준: 전제 훼손 없음 → W1 진입 / 유사 framework 발견 → 재스코프 / differentiator 없음 → §11 재설계.

- [x] **T-W0-01** Anthropic Cookbook `harness` 패턴 검색
  - 의존성: 없음
  - 공수: 2h
  - 검증: cookbook/*.ipynb grep 결과 요약 1쪽 산출 (발견 건수 · 유사도)
  - 관련 자산: —
  - §11: —

- [x] **T-W0-02** DSPy / Inspect-AI / LangGraph / AutoGen "meta-framework" 섹션 탐색
  - 의존성: 없음
  - 공수: 2h
  - 검증: 4개 프레임워크 공식문서 2026-04 스냅샷에서 "6축 유사 레이어" 존재/부재 표 작성
  - 관련 자산: —

- [ ] **T-W0-03** 강의 원저자 공개 구현체 검색 (harness-day2-summary 저자)
  - 의존성: 없음
  - 공수: 1h
  - 검증: GitHub/gist 검색 결과 리스트 0~N건 + 중첩도 점수

- [ ] **T-W0-04** 본인 dogfooding 로그 · 3~5명 유저 인터뷰
  - 의존성: 없음
  - 공수: 2h
  - 검증: 6축별 "실제 통증" 증거표 (축 × 사례 매트릭스) 1쪽

- [x] **T-W0-05** W0 게이트 판정 → W1 착수 / 재스코프 / §11 재설계
  - 의존성: T-W0-01 ~ T-W0-04
  - 공수: 1h
  - 검증: `.claude/plans/04-planning/w0-gate-decision.md` 작성 (TL;DR 유지 여부 판정)

**W0 합계: 8h**

---

### W1 — 스캐폴드 + SessionStart + JSONL 72h smoke test (6일 / 48h)

- [x] **T-W1-PRE-01** ⛳ §11-1 승격 — JSONL 외부 스키마 안정성 정식화 🚨 P0-2
  - 의존성: T-W0-05 통과
  - 공수: 8h
  - 검증: v2 §4.2가 §11-1 초안 흡수 후 정식 섹션으로 승격된 diff. 어댑터 타입 시그니처 / UserPromptSubmit fallback 순서도 / 72h smoke 체크리스트 / degradation UX 4개 모두 확정.
  - §11: **§11-1 승격 완료**

- [x] **T-W1-01** `.claude-plugin/plugin.json` 5필드 minimal → **AC-1**
  - 의존성: T-W1-PRE-01
  - 공수: 2h
  - 검증: `plugin.json` validator 통과 + 외부 의존 0 확인
  - 관련 자산: **#28** (marketplace 구조 경유)

- [x] **T-W1-02** `.claude-plugin/marketplace.json` agent-council 구조 → **AC-1**
  - 의존성: T-W1-01
  - 공수: 2h
  - 검증: marketplace manifest JSON schema 통과
  - 관련 자산: **#28**

- [x] **T-W1-03** `hooks/hooks.json` — SessionStart + UserPromptSubmit + PostToolUse + Stop 4이벤트 등록
  - 의존성: T-W1-02
  - 공수: 2h
  - 검증: Claude Code 실 세션 로그에 4이벤트 훅 모두 발화
  - 관련 자산: hoyeon 훅 패턴

- [x] **T-W1-04** `hooks/session-start` 스크립트 — using-harness.md 주입 + 해시 검증 placeholder 🚨 P0-8
  - 의존성: T-W1-03
  - 공수: 4h
  - 검증: `"$var"` 쌍따옴표 + 화이트리스트 slug + `eval` 금지 정적 lint 통과
  - 관련 자산: **#6**

- [x] **T-W1-05** `skills/using-harness/SKILL.md` — SessionStart 페이로드
  - 의존성: T-W1-04
  - 공수: 4h
  - 검증: superpowers 패턴 체크리스트 7항 전부 충족
  - 관련 자산: **#6**

- [x] **T-W1-06** `scripts/extract-session.sh` — p4cn history-insight 포팅 (bash+jq 재작성) 🚨 P0-1 🚨 P0-2
  - 의존성: T-W1-PRE-01
  - 공수: 6h
  - 검증: unit test 3종 (정상 JSONL · unknown `type` 스킵 · 손상 JSONL 전체 실패 없음)
  - 관련 자산: **#25**

- [x] **T-W1-07** `scripts/schema-adapter.sh` — JSONL `schema_version` 감지 레이어 🚨 P0-2
  - 의존성: T-W1-06, T-W1-PRE-01
  - 공수: 4h
  - 검증: 3개 버전 JSONL 샘플에서 모두 적절한 adapter 함수 dispatch

- [x] **T-W1-08** CI — JSONL 72h smoke test 셋업 (GitHub Actions cron) 🚨 P0-2
  - 의존성: T-W1-07
  - 공수: 4h
  - 검증: cron 3회 연속 성공 + 스키마 변화 감지 시 알림 이벤트 발화

- [x] **T-W1-09** unit test: hooks bash 보안 (쌍따옴표 + slug 화이트리스트 + `eval` 금지) 🚨 P0-8
  - 의존성: T-W1-04
  - 공수: 2h
  - 검증: shellcheck + 커스텀 보안 linter 2종 전부 통과

- [x] **T-W1-10** integration test — 플러그인 설치 → SessionStart 주입 확인 → **AC-1**
  - 의존성: T-W1-09
  - 공수: 2h
  - 검증: Claude Code 실 세션 로그에 `using-harness.md` 페이로드 포함

**W1 합계: 48h** (§11-1 승격 8h 포함)

---

### W2 — `/brainstorm` MVP (5일 / 40h)

- [x] **T-W2-01** `skills/brainstorm/SKILL.md` 구조 + frontmatter (name/description/when_to_use/input/output)
  - 의존성: T-W1-10
  - 공수: 4h
  - 검증: CE `/ce-review` skill-frontmatter lint 통과

- [x] **T-W2-02** clarify 3-lens (vague / unknown / metamedium) 본문 내장
  - 의존성: T-W2-01
  - 공수: 8h
  - 검증: 3-lens 각각 트리거 키워드 리스트 + 3-Round depth pattern 재현
  - 관련 자산: **#14**

- [x] **T-W2-03** description 한·영 병기 작성 (KU-2 준비)
  - 의존성: T-W2-01
  - 공수: 2h
  - 검증: 한국어 트리거 5~6개 + 영어 "Use when ..." 문장 병기

- [x] **T-W2-04** output: `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` 템플릿 + slug 화이트리스트 🚨 P0-8
  - 의존성: T-W2-01
  - 공수: 2h
  - 검증: `[a-zA-Z0-9_-]` 외 문자 주입 시 reject

- [x] **T-W2-05** `validate_prompt` frontmatter 필드 채우기 (6축 해당 축 자기검증 질문)
  - 의존성: T-W2-01
  - 공수: 4h
  - 검증: hoyeon 원본 포맷 재현 + 답을 스킵했을 때 재주입 여부 판정 가능
  - 관련 자산: **#5**

- [x] **T-W2-06** `hooks/validate-output.sh` PostToolUse 훅 (bash+jq) 🚨 P0-1 🚨 P0-8
  - 의존성: T-W2-05
  - 공수: 8h
  - 검증: 10샘플 중 9개 이상에서 validate_prompt 재주입 실측 (KU-1 사전 리허설)
  - 관련 자산: **#5**

- [x] **T-W2-07** unit test: 10 샘플 발화로 /brainstorm 트리거 동작 확인 → **AC-2**
  - 의존성: T-W2-06
  - 공수: 4h
  - 검증: 10개 중 9개 이상 정확 트리거

- [x] **T-W2-08** smoke test: slug 생성 화이트리스트 보안 🚨 P0-8
  - 의존성: T-W2-04
  - 공수: 2h
  - 검증: injection payload 5종 모두 reject

- [x] **T-W2-09** docs: /brainstorm 사용 예제 README 초안 (영어 + 한국어)
  - 의존성: T-W2-07
  - 공수: 4h
  - 검증: README 각 언어에 최소 2개 예제

- [x] **T-W2-10** HARD-GATE 태그 배치 (구조→맥락→계획 전환점)
  - 의존성: T-W2-01
  - 공수: 2h
  - 검증: 6축 전환 지점 각각에 HARD-GATE 블록 삽입
  - 관련 자산: **#7**

**W2 합계: 40h**

---

### W3 — `/plan` 하이브리드 포맷 (5일 / 40h)

- [x] **T-W3-01** `skills/plan/SKILL.md` 구조 + frontmatter
  - 의존성: T-W2-10
  - 공수: 4h
  - 검증: frontmatter lint 통과

- [x] **T-W3-02** Markdown 본문 템플릿 (CE ce-plan 5-Phase 차용)
  - 의존성: T-W3-01
  - 공수: 6h
  - 검증: 5-Phase 각 섹션 키워드 매칭
  - 관련 자산: **#15 (Model Tiering)**

- [x] **T-W3-03** YAML frontmatter 스키마 (goal / constraints / AC / evaluation_principles+weight / exit_conditions / parent_seed_id)
  - 의존성: T-W3-01
  - 공수: 6h
  - 검증: JSON schema validator + weight 합 1.0 assertion
  - 관련 자산: **#21**

- [x] **T-W3-04** gap-analyzer 호출 레이어 (스텁 단계)
  - 의존성: T-W3-02
  - 공수: 8h
  - 검증: 3개 요구사항 문서에서 gap 항목 ≥ 1개 추출
  - 관련 자산: hoyeon gap-analyzer

- [x] **T-W3-05** Ambiguity Score Gate (0.2 임계) — /plan 시작 시 게이트
  - 의존성: T-W3-04
  - 공수: 4h
  - 검증: 점수 0.15/0.25 샘플에서 각각 reject/pass
  - 관련 자산: **#20**

- [x] **T-W3-06** output 저장 훅 (description 기반 slug 파일명) 🚨 P0-8
  - 의존성: T-W3-01
  - 공수: 2h
  - 검증: T-W2-04와 동일 slug linter 재사용

- [x] **T-W3-07** `validate_prompt` 필드 (계획 축 자기검증)
  - 의존성: T-W3-01
  - 공수: 2h
  - 검증: W2-05와 동일 패턴 재현

- [x] **T-W3-08** unit test: 3개 요구사항 문서로 /plan 실행 + 산출물 스키마 검증 → **AC-2**
  - 의존성: T-W3-05, T-W3-06, T-W3-07
  - 공수: 4h
  - 검증: Markdown+YAML 하이브리드 포맷 linter 통과 3/3

- [x] **T-W3-09** docs: /plan 사용 예제 한·영
  - 의존성: T-W3-08
  - 공수: 4h
  - 검증: README에 예제 포함

**W3 합계: 40h**

---

### W4 — `/verify` scaffolding + qa-judge + Ralph Loop (6일 / 48h)

- [x] **T-W4-PRE-01** ⛳ §11-2 승격 — 보안 완전 사양 정식화 🚨 P0-5 🚨 P0-8
  - 의존성: T-W3-09
  - 공수: 8h
  - 검증: v2 §4.3 확장 완료 — Secrets regex 7종 리스트 · 훅 페이로드 SHA256 고정 · correction-detector 부정 문맥 규칙 · PostToolUse 훅 실행 순서 4개 모두 확정
  - §11: **§11-2 승격 완료**

- [x] **T-W4-01** `skills/verify/SKILL.md` 구조 + frontmatter
  - 의존성: T-W4-PRE-01
  - 공수: 4h

- [ ] **T-W4-02** `agents/verify/` 6-에이전트 스텁 (verifier / verification-planner / verify-planner / qa-verifier / ralph-verifier / spec-coverage) — **일부 W7.5로 이월**
  - 의존성: T-W4-01
  - 공수: 8h (잔여 4h는 T-W7.5-05로 이월)
  - 검증: 각 에이전트 최소 stub 응답 동작
  - 관련 자산: **#1**

- [ ] **T-W4-03** `agents/evaluator/qa-judge.md` 스키마 (score / verdict / dimensions / differences / suggestions)
  - 의존성: T-W4-01
  - 공수: 4h
  - 검증: JSON schema validator + 임계값 0.80/0.40 분기 로직 unit test
  - 관련 자산: **#3**

- [ ] **T-W4-04** Ralph Loop 의사코드 verify 본문 내장 (non-blocking + level-based polling)
  - 의존성: T-W4-01
  - 공수: 4h
  - 검증: 의사코드 라인 커버리지 vs ouroboros 원본 ≥ 80%
  - 관련 자산: **#2**

- [ ] **T-W4-05** `validate_prompt` + hooks 페이로드 SHA256 해시 검증 구현 → **AC-3 구현** 🚨 P0-8
  - 의존성: T-W4-PRE-01
  - 공수: 4h
  - 검증: 세션 시작 시 해시 불일치 주입 거부 실측 3/3
  - 관련 자산: **#5** + §11-2

- [ ] **T-W4-06** Secrets redaction 정규식 리스트 구현 (AWS · GCP · GitHub · Slack · JWT · DB URL · Bearer) 🚨 P0-5
  - 의존성: T-W4-PRE-01
  - 공수: 6h
  - 검증: 7 정규식 각 positive 3건 + negative 1건 = 28 케이스 unit test 통과. 드롭 시 `{redacted: N}` 기록

- [ ] **T-W4-07** `hooks/drift-monitor.sh` PostToolUse 드리프트 advisory (bash+jq 재작성) 🚨 P0-1
  - 의존성: T-W4-01
  - 공수: 4h
  - 검증: 원본 `drift-monitor.py` 로직 파리티 테스트 + Python 런타임 0 assertion
  - 관련 자산: ouroboros `drift-monitor.py` (재작성 필수)

- [ ] **T-W4-08** unit test: qa-judge 임계값 분기 3종 (승격 ≥0.80 / 재시도 0.40~0.80 / 기각 ≤0.40) → **AC-2**
  - 의존성: T-W4-03, T-W4-04
  - 공수: 2h
  - 검증: 각 분기 최소 1건 정확 판정

**W4 합계: 48h** (§11-2 승격 8h 포함 · T-W4-02 잔여 4h는 W7.5로 이월)

---

### W5 — 메모리 + 승격 게이트 UX (5일 / 40h)

- [ ] **T-W5-PRE-01** ⛳ §11-3 승격 — 승격 게이트 UX 전체 사양 정식화
  - 의존성: T-W4-08
  - 공수: 6h
  - 검증: v2 §3.4 신규 섹션 작성 — 단계 (후보 → 점수 → 자동 판정 → y/N/e/s UX → 저장 → 이력) 전부 명세 + Consent fatigue 완화 (Stop hook 일괄 · 3회 거부 detector 임시 비활성화) 포함
  - §11: **§11-3 승격 완료**

- [ ] **T-W5-01** `.claude/memory/` 초기 구조 (MEMORY.md + tacit/ + corrections/ + preferences/)
  - 의존성: T-W5-PRE-01
  - 공수: 2h
  - 검증: 디렉토리 트리 생성 + MEMORY.md 빈 인덱스 포함

- [ ] **T-W5-02** MEMORY.md 1줄 포인터 인덱스 포맷 규약
  - 의존성: T-W5-01
  - 공수: 2h
  - 검증: `- [Title](file.md) — hook` 포맷 regex 매칭

- [ ] **T-W5-03** 메모리 파일 frontmatter 스키마 (name / description / type)
  - 의존성: T-W5-02
  - 공수: 2h
  - 검증: 3 type (user/feedback/project/reference) 각각 샘플 파일 lint 통과

- [ ] **T-W5-04** Bug track vs Knowledge track 분기
  - 의존성: T-W5-03
  - 공수: 4h
  - 검증: `corrections/` → Bug track, `tacit/` → Knowledge track 자동 분류 3/3
  - 관련 자산: **#24**

- [ ] **T-W5-05** 5-dimension overlap scoring (problem / cause / solution / files / prevention)
  - 의존성: T-W5-03
  - 공수: 8h
  - 검증: High(4-5) / Moderate(2-3) / Low(0-1) 분류 10샘플 정확도 ≥ 80%
  - 관련 자산: **#18**

- [ ] **T-W5-06** 승격 게이트 UX: AskUserQuestion y/N/e/s UI
  - 의존성: T-W5-PRE-01, T-W5-05
  - 공수: 6h
  - 검증: 4 분기 각각 유저 응답별 저장/거부/편집/스킵 동작 실측
  - 관련 자산: §11-3

- [ ] **T-W5-07** Stop hook 일괄 제시 + 3회 연속 거부 detector 임시 비활성화
  - 의존성: T-W5-06
  - 공수: 4h
  - 검증: 3회 reject 시 다음 세션까지 detector off
  - 관련 자산: §11-3

- [ ] **T-W5-08** 거부 이력 저장 로직 (`corrections/_rejections.log`)
  - 의존성: T-W5-07
  - 공수: 4h
  - 검증: 거부 3건 후 로그 파일에 timestamp+pattern 기록

- [ ] **T-W5-09** correction-detector 문자열 매칭 + 직전 assistant 턴 부정 문맥 확인
  - 의존성: T-W4-PRE-01
  - 공수: 2h
  - 검증: P1-7 부정 문맥 5샘플 정확도 ≥ 4/5
  - 관련 자산: §11-2 (P1-7)

- [ ] **T-W5-10** `[Stretch]` 글로벌 `~/.claude/memory/` 프로젝트 ID 태그 옵션 → **AC-Stretch-2**
  - 의존성: T-W5-01
  - 공수: 4h (Stretch)
  - 검증: 글로벌 모드 활성화 시 파일명에 `project_id=` 태그 필수
  - `[Stretch]`

**W5 합계: 40h (Stretch T-W5-10 포함 시 44h, Stretch 제외 40h)**

---

### W6 — `/compound` 트리거 3종 (5일 / 40h)

- [ ] **T-W6-01** `skills/compound/SKILL.md` 구조 + frontmatter
  - 의존성: T-W5-08
  - 공수: 4h

- [ ] **T-W6-02** session-wrap 2-Phase 파이프라인 포팅 (4 분석자 병렬 + 1 validator 순차)
  - 의존성: T-W6-01
  - 공수: 8h
  - 검증: 4 분석자 병렬 실행 + validator 최종 검증 동작 파리티
  - 관련 자산: **#4**

- [ ] **T-W6-03** `agents/compound/` 5종 리네이밍 (tacit-extractor / correction-recorder / pattern-detector / preference-tracker / duplicate-checker)
  - 의존성: T-W6-02
  - 공수: 8h
  - 검증: 5 에이전트 각각 최소 동작 + 이름 P1 네임스페이스 규약 준수

- [ ] **T-W6-04** `scripts/keyword-detector.sh` — ouroboros Python → bash+jq 재작성 🚨 P0-1
  - 의존성: T-W6-01
  - 공수: 6h
  - 검증: 원본 keyword-detector.py 파리티 테스트 + Python 런타임 0 assertion
  - 관련 자산: ouroboros `keyword-detector.py` (재작성 필수)

- [ ] **T-W6-05** `hooks/correction-detector.sh` UserPromptSubmit 훅 (bash+jq) 🚨 P0-8
  - 의존성: T-W5-09, T-W6-04
  - 공수: 4h
  - 검증: "틀렸다" 발언 10샘플 감지율 ≥ 90%
  - 관련 자산: §11-2 (P1-7)

- [ ] **T-W6-06** 3회 반복 패턴 감지 (JSONL 파서 활용)
  - 의존성: T-W1-06
  - 공수: 4h
  - 검증: 동일 토픽 3회 반복 세션 샘플 정확 감지 3/3
  - 관련 자산: **#25**

- [ ] **T-W6-07** `/session-wrap` 수동 호출 트리거
  - 의존성: T-W6-01
  - 공수: 2h
  - 검증: 수동 호출 시 컴파운딩 후보 목록 제시

- [ ] **T-W6-08** unit test: 3트리거 감지 (반복 / 틀렸다 / session-wrap) → **AC-6**
  - 의존성: T-W6-05, T-W6-06, T-W6-07
  - 공수: 4h
  - 검증: 3 트리거 각각 최소 1건 실측 (감지 정확도는 KU-3 → W7.5에서 엄밀 측정)

- [ ] **T-W6-09** oscillation 과적합 방지 (Gen N ≈ Gen N-2) — **일부 W7.5로 이월**
  - 의존성: T-W6-05
  - 공수: 0h (전량 T-W7.5-06으로 이월)
  - 관련 자산: **#22**

**W6 합계: 40h** (oscillation 4h는 W7.5로 이월)

---

### W7 — `/orchestrate` B `[Stretch]` (5일 / 40h 전량 Stretch)

> v2 §10.2 Stretch AC. MVP 릴리스 차단 기준 아님.

- [ ] **T-W7-01** `[Stretch]` `skills/orchestrate/SKILL.md` 구조 + frontmatter → **AC-Stretch-1**
  - 의존성: T-W6-08
  - 공수: 4h (Stretch)
  - 검증: frontmatter lint 통과

- [ ] **T-W7-02** `[Stretch]` 내부 4축 순차 파이프라인 (/brainstorm → /plan → /verify → /compound)
  - 의존성: T-W7-01
  - 공수: 12h (Stretch)
  - 검증: 단일 주제로 4축 end-to-end 성공 1회

- [ ] **T-W7-03** `[Stretch]` agent-council Wait cursor bucket UI 차용
  - 의존성: T-W7-02
  - 공수: 6h (Stretch)
  - 검증: 6축 진행 시각화 + cursor 상태 전이
  - 관련 자산: **#12**

- [ ] **T-W7-04** `[Stretch]` hoyeon 3-Axis 실행 조합 (dispatch × work × verify = 9 조합)
  - 의존성: T-W7-02
  - 공수: 8h (Stretch)
  - 검증: 9 조합 중 최소 3 조합 동작
  - 관련 자산: **#16**

- [ ] **T-W7-05** `[Stretch]` Mandatory Disk Checkpoints CP-0~CP-5
  - 의존성: T-W7-02
  - 공수: 6h (Stretch)
  - 검증: `experiment-log.yaml` 체크포인트 6단계 전부 기록
  - 관련 자산: **#17**

- [ ] **T-W7-06** `[Stretch]` unit test: 4축 순차 전체 파이프라인
  - 의존성: T-W7-05
  - 공수: 4h (Stretch)
  - 검증: 단일 주제 end-to-end 녹화 1회 성공

**W7 합계: 40h (전량 Stretch)**

---

### W7.5 — KU 실행 + 하드닝 (3일 / 24h)

> v2 §8 기준. MVP 하드 KU 4종 (KU-0 / KU-1 / KU-2 / KU-3) 실행 주차.

- [ ] **T-W7.5-PRE-01** ⛳ §11-4 승격 — KU 실행 상세 정식화
  - 의존성: T-W6-08 (W7 Stretch는 독립)
  - 공수: 4h
  - 검증: v2 §8 확장 — 각 KU별 데이터 소스 · 샘플 수 · 자동/수동 · 실패 시 결정 (차단/경고) 확정 + judge 에이전트(KU-1b) 프롬프트 설계 + KU-0 histogram 측정 자동화 스크립트
  - §11: **§11-4 승격 완료**

- [ ] **T-W7.5-01** KU-0 qa-judge 점수 histogram 수집 + 분위수 기반 임계값 재조정 → **AC-7**
  - 의존성: T-W7.5-PRE-01
  - 공수: 4h
  - 검증: histogram 플롯 + 임계값 0.80/0.40 → 분위수 기반 값으로 갱신 diff

- [ ] **T-W7.5-02** KU-1 validate_prompt 훅 발동률 ≥ 99% + 응답률 ≥ 90% 측정 → **AC-3**
  - 의존성: T-W7.5-PRE-01
  - 공수: 4h
  - 검증: 10 샘플 태스크 실측 + judge 에이전트 평가. 미달 시 T-W4-05 재작업 게이트

- [ ] **T-W7.5-03** KU-2 description 한·영 병기 A/B 20 발화 정확도 → **AC-4**
  - 의존성: T-W7.5-PRE-01
  - 공수: 4h
  - 검증: 영어만 vs 한·영 병기 정확도 차 ≤ 5%p (양방향 기준 — P1-3)

- [ ] **T-W7.5-04** KU-3 승격 게이트 false positive < 20% 측정 → **AC-5**
  - 의존성: T-W7.5-PRE-01
  - 공수: 4h
  - 검증: 10 실 세션 기반 오검지율 20% 미만

- [ ] **T-W7.5-05** 하드닝: W4-02 verify 에이전트 잔여 구현 이월
  - 의존성: T-W4-02
  - 공수: 4h
  - 검증: 6 에이전트 실구현 완결 + 스텁 제거

- [ ] **T-W7.5-06** 하드닝: W6 oscillation 과적합 방지 구현 이월
  - 의존성: T-W6-05
  - 공수: 4h (본래 W6에서 계획되었으나 이월)
  - 검증: oscillation 5 샘플 중 과적합 차단 정확도 ≥ 4/5

**W7.5 합계: 28h** (§11-4 승격 4h + KU 4종 16h + 하드닝 이월 8h)

---

### W8 — 문서화 + 오픈소스 배포 (6.5일 / 52h)

- [ ] **T-W8-PRE-01** ⛳ §11-5 승격 — 6축 강제 적용 범위 확정
  - 의존성: T-W7.5-04
  - 공수: 4h
  - 검증: v2 §3 확장 — 축별 활성 규칙 (`/plan`·`/verify`·`/orchestrate` 기본 ON, `/brainstorm`·`/compound` 자연 대화, 일반 Q&A OFF) + `--skip-axis N` 이스케이프 해치 스펙 + 실효성 지표 메트릭 KU 추가 검토
  - §11: **§11-5 승격 완료**

- [ ] **T-W8-PRE-02** ⛳ §11-6 승격 — 라이선스 · 상류 sync 매트릭스
  - 의존성: T-W7.5-04
  - 공수: 4h
  - 검증: v2 §6 테이블에 `상류 커밋 해시` · `sync 주기` 컬럼 추가 + 4 상류(hoyeon/ouroboros/p4cn/superpowers) 라이선스 호환성 매트릭스 + 본 플러그인 최종 라이선스 선택 (→ porting-matrix.md §4와 연동)
  - §11: **§11-6 승격 완료**

- [ ] **T-W8-PRE-03** ⛳ §11-7 승격 — 기타 설계 미결 정리
  - 의존성: T-W7.5-04
  - 공수: 4h
  - 검증: 프론트매터 필드 5 스킬 전부 확정 · 포지셔닝 1문장 README 확정 · OSS composability (스킬 독립 사용 가능 여부) 명세 · `/orchestrate` 실질 가치 vs 수동 호출 비교표
  - §11: **§11-7 승격 완료**

- [ ] **T-W8-01** README.md 영어 → **AC-8**
  - 의존성: T-W8-PRE-03
  - 공수: 6h
  - 검증: 포지셔닝 1문장 · 설치법 · 5 스킬 사용 예제 · License 섹션 포함

- [ ] **T-W8-02** README.ko.md → **AC-8**
  - 의존성: T-W8-01
  - 공수: 4h
  - 검증: 영어 README와 섹션 구성 동형 + ko 고유 예제 최소 1개

- [ ] **T-W8-03** CLAUDE.md 작성 (프로젝트 가이드라인)
  - 의존성: T-W8-PRE-03
  - 공수: 4h
  - 검증: hoyeon 2중 구조 차용 확인

- [ ] **T-W8-04** AGENTS.md 작성 (Skill Compliance Checklist 섹션)
  - 의존성: T-W8-03
  - 공수: 2h

- [ ] **T-W8-05** 각 스킬 description 한·영 병기 최종 점검
  - 의존성: T-W7.5-03
  - 공수: 2h
  - 검증: 5 스킬 전부 병기 포맷 일관성 확인

- [ ] **T-W8-06** 릴리스 체크리스트 + Hard AC 8개 모두 만족 판정
  - 의존성: T-W8-01 ~ T-W8-05
  - 공수: 4h
  - 검증: §5 AC 매핑 전체 green + W0~W8 게이트 회고

- [ ] **T-W8-07** 오픈소스 라이선스 파일 + CONTRIBUTING 초안
  - 의존성: T-W8-PRE-02
  - 공수: 2h
  - 검증: SPDX identifier 포함

- [ ] **T-W8-08** 배포 검증: 클린 머신에서 플러그인 설치 → `/brainstorm` 호출 → **AC-1**
  - 의존성: T-W8-07
  - 공수: 4h
  - 검증: 외부 의존 0 · `/brainstorm` 단일 호출 성공

**W8 합계: 52h** (§11-5/6/7 승격 12h 포함)

---

## 4. 주차별 공수 합계

| 주차 | 구현 공수 | §11 승격 선행 | Stretch | 합계 |
|------|---------:|-------------:|--------:|-----:|
| W0 | 8h | — | — | 8h |
| W1 | 40h | 8h (§11-1) | — | 48h |
| W2 | 40h | — | — | 40h |
| W3 | 40h | — | — | 40h |
| W4 | 40h | 8h (§11-2) | — | 48h |
| W5 | 36h | 6h (§11-3) | 4h (T-W5-10) | 46h |
| W6 | 40h | — | — | 40h |
| W7 | — | — | 40h (전량) | 40h |
| W7.5 | 24h | 4h (§11-4) | — | 28h |
| W8 | 40h | 12h (§11-5/6/7) | — | 52h |
| **Hard AC 경로** | **308h** | **38h** | — | **346h** |
| **Stretch 포함** | — | — | **40h** | **386h** |

- **Hard AC 경로 (Stretch 제외)**: 346h ≈ **8.65주** → **9주 한도 충족** ✓
- **Stretch 포함**: 386h ≈ 9.65주 → W7 (/orchestrate)를 2차 릴리스로 연기 시 9주 이내 수렴

---

## 5. Hard AC 추적 매트릭스

v2 §10.1 기준. Hard AC 8개가 각각 어느 태스크로 충족되는지 추적.

| # | Hard AC | 충족 태스크 | 측정 태스크 |
|---|---------|-------------|-------------|
| AC-1 | plugin.json + marketplace.json 설치 성공 (외부 의존 0) | T-W1-01, T-W1-02 | T-W1-10, T-W8-08 |
| AC-2 | 4개 스킬 호출 가능 | T-W2-01~10, T-W3-01~09, T-W4-01~08, T-W6-01~09 | T-W2-07, T-W3-08, T-W4-08, T-W6-08 |
| AC-3 | validate_prompt 발동률 ≥99% · 응답률 ≥90% (KU-1) | T-W4-05 | T-W7.5-02 |
| AC-4 | description 한·영 병기 트리거 정확도 (KU-2) | T-W2-03, T-W8-05 | T-W7.5-03 |
| AC-5 | 승격 게이트 오검지 <20% (KU-3) | T-W5-06, T-W5-07, T-W5-08 | T-W7.5-04 |
| AC-6 | 세션 JSONL 파서가 3 컴파운딩 트리거 감지 | T-W1-06, T-W6-05, T-W6-06, T-W6-07 | T-W6-08 |
| AC-7 | qa-judge 점수 분포 KU-0 + 임계값 확정 | T-W4-03 | T-W7.5-01 |
| AC-8 | README + README.ko.md 이중 + 한·영 description 실증 | T-W8-01, T-W8-02 | T-W8-06 |

**Stretch AC (v2 §10.2)**:

| # | Stretch AC | 충족 태스크 |
|---|-----------|-------------|
| AC-S1 | `/orchestrate` 단일 완결형 B (내부 4축 순차) | T-W7-01~06 (전량 Stretch) |
| AC-S2 | `.claude/memory/` 글로벌 전환 옵션 | T-W5-10 (Stretch) |

**2차 릴리스 (v2 §10.3) — 본 주차 분해 밖**: qa-judge 회색지대 자동 Consensus / `/orchestrate` C / `skill-rules.json` 이전

---

## 6. §11 승격 과제 타임라인 (상세는 `section11-promotion-tracker.md` 참조)

| §11 항목 | 승격 deadline | 승격 태스크 ID | 흡수 대상 v2 섹션 |
|----------|--------------|---------------|-------------------|
| §11-1 JSONL 안정성 | W1 이전 | T-W1-PRE-01 | v2 §4.2 |
| §11-2 보안 완전 사양 | W4 이전 | T-W4-PRE-01 | v2 §4.3 확장 |
| §11-3 승격 게이트 UX | W5 이전 | T-W5-PRE-01 | v2 §3.4 신규 |
| §11-4 KU 실행 상세 | W7.5 이전 | T-W7.5-PRE-01 | v2 §8 확장 |
| §11-5 6축 강제 범위 | W8 이전 | T-W8-PRE-01 | v2 §3 확장 |
| §11-6 라이선스 · 상류 sync | W8 이전 | T-W8-PRE-02 | v2 §6 확장 |
| §11-7 기타 설계 미결 | W8 이전 | T-W8-PRE-03 | v2 §3/9/10 확장 |

---

## 7. 결정 필요 항목 (유저 확인 대기)

`/ce-plan` 스킬 내부에서 기본값으로 채웠으나 릴리스 전 유저 판단이 필요한 분기:

1. **W0 게이트 판정 주체** — T-W0-05 책임자. 현재 "본인"으로 가정했으나 유저 확정 필요.
2. **§11-5 6축 강제 적용 범위** — T-W8-PRE-01. 일반 Q&A OFF 기본값은 보수적. 유저가 원하면 축소 필요.
3. **§11-6 본 플러그인 최종 라이선스** — T-W8-PRE-02. MIT vs Apache-2.0 vs BSL 선택 (GPL 자산 포팅 없으므로 MIT 권장).
4. **W7 `[Stretch]` 포함 여부** — 9주 한도를 엄수하려면 W7 전량 2차로 연기. 포함 시 9.65주 초과.
5. **W5-10 글로벌 메모리 옵션 포함 여부** — 4h Stretch. MVP 범위에 남길지 2차 이관할지.

---

## 8. Non-Goals (v2 §9 재확인 — 본 분해 밖)

- ❌ Python/Node 런타임 의존 (jq/awk만 허용 — P0-1)
- ❌ SQLite EventStore · Textual TUI · LiteLLM (ouroboros 고급)
- ❌ Visual Companion 브라우저 서버 (superpowers)
- ❌ CE "cross-skill 참조 금지" 정책
- ❌ 체크리스트식 6축 준수 (실효성 지표 없는 형식 포함)
- ❌ qa-judge 회색지대 **자동** Consensus (2차 릴리스)
- ❌ `/orchestrate` C (외부 플러그인 감지·위임) (2차 릴리스)
- ❌ `skill-rules.json` 이전 (2차 릴리스)
- ❌ 글로벌 `~/.claude/memory/` 완전 교차 오염 방지 구현 (MVP는 기본 off + 태그 옵션만)

---

## 9. 완료 기준 (Phase 4 자체 검수)

- [x] W0~W8 + W7.5 전 주차 태스크 `T-W{주차}-{순번}` 체계로 일관되게 ID 부여
- [x] Top-32 포팅 자산 모두 주차 배정 또는 2차 릴리스 분류 (→ `porting-matrix.md` 참조)
- [x] §11 승격 과제 7개 모두 deadline 및 PRE 태스크 지정
- [x] Hard AC 8개 모두 충족/측정 태스크로 추적 가능 (§5 매트릭스)
- [x] Stretch 태스크 `[Stretch]` 태그로 분리
- [x] 🚨 P0 위험 플래그 (P0-1 · P0-2 · P0-5 · P0-8) 관련 태스크 마킹
- [x] 주차별 공수 합계 산정 + Hard AC 경로 9주 한도 검증
- [x] 의존성 그래프 (ASCII + Mermaid) 포함

---

*Phase 4 `/ce-plan` 태스크 분해 산출물. 실제 구현은 W0 게이트 통과 후 착수.*

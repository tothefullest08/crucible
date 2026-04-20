# §11-3 승격 게이트 UX 사전 설계 draft

> **상태**: 사전 draft (W5 진입 시 final-spec.md §3.4로 정식 승격 예정)
> **작성일**: 2026-04-19
> **작성 컨텍스트**:
> - `03-design/final-spec.md` v3.1 §3 (승격 게이트 개념) · §2.1 #6 (오염 방지) · §3.5 (6축 강제 범위)
> - `03-design/user-decisions-5.md` §3 (승격 게이트 관련 결정)
> - `04-planning/section11-promotion-tracker.md` §11-3 기준 (W5 이전 승격 deadline)
> - `03-design/final-spec-review.md` P0-6 (승격 게이트 UX 미정의 지적)
> - 레퍼런스: `references/plugins-for-claude-natives/plugins/session-wrap/` (2-Phase + AskUserQuestion 패턴) · `references/compound-engineering-plugin/` (ce-compound 5-dim overlap + Auto Memory)

---

## 1. 개요 및 승격 목표

### 1.1 승격 대상
- final-spec.md **§3 또는 §4 내에 신규 `§3.4 승격 게이트 상세 사양` 섹션 추가** 예정
- 기존 §3.1 유저 스토리의 "승격 게이트(검증 → 유저 승인 → 저장)" 문장에 §3.4 링크 삽입
- §3.4는 본 draft 6 섹션을 정식 본문으로 흡수

### 1.2 목적
final-spec v3 §2.1 #6 "오염 방지"는 본 플러그인 핵심 차별화 메카닉이다. 그 유일한 차단 게이트가 **승격 게이트**이며, 본 게이트의 UX가 모호하면 다음과 같은 실 운영 리스크가 발생한다.

- **F-1. 자동 저장 폭주**: 유저 승인 없이 자동 저장 → 컴파운딩 메모리가 거짓 패턴으로 오염 → 다음 세션부터 잘못된 컨텍스트가 주입되는 음의 누적
- **F-2. Consent fatigue**: 매 턴마다 승인 프롬프트 → 유저가 무의식적으로 모두 승인 → F-1과 동일 결과
- **F-3. 구현자 임의 해석**: §11-3이 미명세 상태로 W5에 진입하면 T-W5-06/07/08 구현자(본인)가 "적당히" 결정 → final-spec과 실제 구현 분기

본 draft는 W5 진입 전에 위 3 리스크를 봉쇄하기 위한 **6단계 파이프라인 + Consent fatigue 완화 정책 + 텍스트 wireframe**의 단일 사양을 제공한다.

### 1.3 범위 외 (본 draft 비대상)
- 패턴 3회 반복 감지 알고리즘 자체 → §11-7 detector 별도 설계 (ce-compound 5-dim overlap 재사용 검토 중)
- correction-detector.sh 부정 문맥 판별 정규식 → §11-2 (T-W4-PRE-01) 잔여
- judge 에이전트 시스템 프롬프트 → §11-4 (T-W7.5-PRE-01) 잔여

---

## 2. 승격 게이트 파이프라인 단계 (6-Step)

### Step 1: 후보 생성

#### 트리거 소스 3종 (final-spec v3 §2.1 #8)
| # | trigger_source | 발생 위치 | 구현 주차 |
|---|---------------|----------|----------|
| 1 | `pattern_repeat` | 패턴 3회 반복 감지 detector (실시간/주기) | T-W7 (§11-7 별도) |
| 2 | `user_correction` | `correction-detector.sh` PostToolUse 훅 | T-W6-03 |
| 3 | `session_wrap` | `/session-wrap` 명령 (Stop hook 직전) | T-W6-06 |

#### 후보 객체 스키마
모든 트리거 소스는 동일 후보 객체를 생성하여 큐에 적재한다.

```yaml
# .claude/state/promotion_queue/{candidate_id}.yaml
candidate_id: <uuid-v4>
trigger_source: pattern_repeat | user_correction | session_wrap
content: |
  <free text — 패턴 요지 또는 정정 발언 또는 세션 학습 요지>
context:
  session_id: sess_<YYYYMMDD>_<HHMMSS>
  turn_range: <start_turn>-<end_turn>
  related_files:
    - <path1>
    - <path2>
detected_at: <ISO-8601 UTC>
```

#### 큐 위치
- `.claude/state/promotion_queue/` (gitignore 대상 — 운영 상태)
- 세션 내 누적 → Step 4 일괄 제시 시점에 일괄 처리 → 처리 완료된 후보는 Step 5/6으로 이동

---

### Step 2: Evaluator 점수

#### 호출 방식 (final-spec v3 §2.1 #5 준수)
- **다른 관점 서브에이전트** + **fresh context** (현재 세션의 편향 차단)
- 서브에이전트 모델: Sonnet 4.6 기본 (5-dim 평가 정확도 우선)
- qa-judge JSON 스키마 재사용 (final-spec v3 §4.2 참조)

#### 입력
- 후보 객체 전체 (Step 1 출력)
- 평가 컨텍스트: "이 학습이 향후 세션에 누적될 가치가 있는가? 오염 위험은?"

#### 출력 (qa-judge 스키마)
```json
{
  "candidate_id": "<uuid>",
  "score": 0.82,
  "dimensions": {
    "correctness": 0.90,
    "clarity": 0.85,
    "generality": 0.78,
    "non_redundancy": 0.80,
    "actionability": 0.77
  },
  "reasoning": "<1-2 문장 요지>",
  "suggested_path": "tacit/kotlin-coroutine-scope.md"
}
```

#### 실패 모드
- 서브에이전트 호출 실패(타임아웃·rate limit) → 후보를 큐에 보존하고 다음 session-wrap으로 연기 (자동 폐기 금지)
- 3회 연속 실패 → MEMORY.md에 1줄 경고 (`evaluator unavailable since {date}`)

---

### Step 3: 자동 판정

| 조건 | 분기 | 비고 |
|------|------|------|
| `score ≥ 0.80` | **자동 승격 큐**로 이동 (단 Step 4 유저 확인 필수) | "자동"은 Step 4 사전 분류만 의미 — 저장은 항상 유저 승인 후 |
| `score ≤ 0.40` | **자동 기각** → Step 6으로 직행 | `corrections/_rejected/` 보존 (재학습용) |
| `0.40 < score < 0.80` | **회색지대** — final-spec v3 §2.2 Dec 11에 따라 처리 | 아래 3.5 참조 |

#### 회색지대 (0.40 < score < 0.80) 처리
- **MVP**: 수동 승격 fallback (Step 4 유저 확인 시 회색 표시 배지로 노출)
- **2차 릴리스**: 자동 Consensus (Evaluator 2회 호출 후 평균 0.60 미만/이상으로 자동 분류)
- 회색지대 후보는 Step 4 표시 시 score 옆에 🟡 배지

---

### Step 4: 사용자 확인 UX (P0-6 핵심)

#### 4.1 mid-session 중단 금지 원칙
- **세션 진행 중에는 절대 프롬프트 중단 발생 금지** (사용자 사고 흐름 보호)
- 모든 후보는 **세션 종료(Stop hook) 시점**에 일괄 제시
- `/session-wrap` 수동 호출 시에도 동일 일괄 UX 트리거

#### 4.2 표시 내용 (후보별 필드)
| 필드 | 표시 형식 | 비고 |
|------|----------|------|
| 순번 | `[1/N]` | 총 N건 중 현재 |
| score 배지 | 🟢 (≥0.80) / 🟡 (회색지대) / 🔴 (≤0.40 단 자동 기각이라 표시 안 함) | |
| score 수치 | `score=0.87` | |
| trigger | `trigger=pattern_repeat` | |
| 추천 저장 경로 | `tacit/kotlin-coroutine-scope.md` | Evaluator의 `suggested_path` |
| 본문 요약 | content 첫 80자 + ... | 전체 보기는 `[v]` 키 |
| 소스 링크 | `sess_20260419_142301 · turn 45-48` | JSONL turn timestamp |
| 주요 dimensions | 상위 2개 (correctness=0.9 clarity=0.85) | |

#### 4.3 응답 키 매핑
| 키 | 동작 | 기본값 여부 |
|----|------|------------|
| `y` | **승인** → Step 5 저장 | |
| `N` | **거부** → Step 6 기각 이력 | ✅ 기본값 (Enter만 누르면 거부) |
| `e` | **수정 후 승인** → 별도 프롬프트로 본문 편집 → Step 5 저장 | MVP는 별도 프롬프트, 2차에서 inline edit 검토 |
| `s` | **건너뛰기** → 다음 session-wrap에서 재제시 (큐에 보존) | |
| `v` | **전체 본문 보기** → 같은 후보 다시 표시 | |
| `q` | **나머지 전체 건너뛰기** → 모든 잔여 후보 `s` 처리 | 피로도 탈출 비상구 |

#### 4.4 기본값을 거부(N)로 설정한 이유
- 오염 방지가 핵심 (final-spec v3 §2.1 #6) — **거짓 양성**(잘못된 학습 저장) 비용 > **거짓 음성**(좋은 학습 놓침) 비용
- Enter 연타 습관에도 안전 (False Positive 차단)

#### 4.5 한·영 병기 프롬프트 문안
final-spec v3 §11-3 승격 게이트 기준 #3 (AskUserQuestion 정확한 프롬프트 문안) 충족.

```
[y]es approve  [N]o reject  [e]dit then approve  [s]kip until next  [v]iew full  [q]uit batch
[y]승인  [N]거부  [e]수정 후 승인  [s]다음 session-wrap에서 재제시  [v]전체 보기  [q]일괄 종료
```

---

### Step 5: 저장 (승인 시에만)

#### 5.1 저장 경로
승인된 후보는 Evaluator의 `suggested_path` 또는 유저가 `e`로 수정한 경로로 저장.

| 디렉토리 | 용도 | 출처 매핑 |
|---------|------|----------|
| `.claude/memory/tacit/` | 암묵지 (코드 패턴, 도메인 지식) | trigger=pattern_repeat 다수 |
| `.claude/memory/corrections/` | 정정 사실 (틀린 가정 → 수정) | trigger=user_correction 다수 |
| `.claude/memory/preferences/` | 사용자 선호 (스타일, 컨벤션) | trigger=session_wrap 다수 |

#### 5.2 frontmatter 스키마
```yaml
---
candidate_id: <uuid>
promoted_at: <ISO-8601 UTC>
evaluator_score: 0.82
dimensions:
  correctness: 0.90
  clarity: 0.85
  generality: 0.78
  non_redundancy: 0.80
  actionability: 0.77
trigger_source: pattern_repeat | user_correction | session_wrap
source_turn: <session_id>:<start_turn>-<end_turn>
edited_by_user: false  # `e` 경로 사용 시 true
---

<본문 (Markdown)>
```

#### 5.3 MEMORY.md 인덱스 1줄 추가
```markdown
- [<짧은 제목>](<상대경로>) — <Evaluator reasoning 첫 50자>
```

#### 5.4 중복 검출
저장 직전 ce-compound 5-dim overlap (또는 단순 유사도 ≥ 0.85) 검사 → 기존 메모리와 high overlap 시 유저에게 "병합 vs 신규 저장" 추가 프롬프트 (회색지대만, 그린은 자동 신규 저장).

---

### Step 6: 거부 이력

#### 6.1 자동 기각(score ≤ 0.40) + 유저 거부(`N`) 모두 보존
- 위치: `.claude/memory/corrections/_rejected/{candidate_id}.md`
- 보존 사유: 과적합 감지(KU-5) 입력 데이터 + 동일 패턴 재발 시 자동 비활성화 트리거

#### 6.2 frontmatter 스키마
```yaml
---
candidate_id: <uuid>
rejected_at: <ISO-8601 UTC>
rejection_source: auto_low_score | user_reject
evaluator_score: 0.32
trigger_source: pattern_repeat | user_correction | session_wrap
source_turn: <session_id>:<start_turn>-<end_turn>
---

<본문>
```

#### 6.3 자동 detector 비활성화 트리거
**동일 패턴 3회 연속 거부** 시:
1. detector_id 추출 (예: `pattern_repeat:coroutine-scope`)
2. `.claude/state/disabled_detectors.yaml`에 `disabled_until: <now+7d>` 기록
3. 다음 session-wrap에서 "이 detector 7일간 OFF — `/compound --reactivate <detector_id>`로 즉시 복구" 안내

---

## 3. Consent Fatigue 완화 정책

### 3.1 핵심 원칙
- **F-2 (Consent fatigue)** 차단이 본 §3 절의 단일 목적
- 매 턴 프롬프트 → 무의식 승인 → F-1과 동일 결과 → 핵심 차별화 무력화

### 3.2 정책 1: Stop hook 일괄 제시
- mid-session 중단 절대 금지 (Step 4 §4.1과 중복 강조)
- 모든 후보는 세션 종료 시점 일괄 처리
- 단 한 번의 컨텍스트 전환만 발생

### 3.3 정책 2: 동일 패턴 3회 연속 거부 시 detector 자동 비활성화
| 항목 | 값 | 근거 |
|------|----|------|
| 비활성화 기간 | **7일** | MVP 임시값 — KU-5(과적합 감지) 실측 후 조정 (열린 질문 §6.1) |
| 재검토 prompt | 7일 경과 시 다음 session-wrap에서 1회 재활성화 prompt | |
| 수동 재활성화 | `/compound --reactivate <detector_id>` 즉시 ON | |
| "동일 패턴" 정의 | ce-compound 5-dim overlap score ≥ High (≥0.75) | section11-promotion-tracker §3 주의 항목 |

### 3.4 정책 3: 배치 제시 시 우선순위 정렬
| 순서 | 기준 | 이유 |
|------|------|------|
| 1순위 | score 내림차순 (높은 score 먼저) | 피로도 적은 상태에서 중요한 결정부터 |
| 2순위 | trigger_source 우선순위: user_correction > pattern_repeat > session_wrap | 유저가 명시적으로 정정한 것 우선 |
| 3순위 | detected_at 오름차순 (오래된 것 먼저) | FIFO |

### 3.5 정책 4: 최대 표시 개수 제한
- **세션당 최대 10개**
- 11개 이상 누적 시: 상위 10개만 표시 + "11+ 후보가 다음 session-wrap에서 계속됩니다" 안내
- 잔여 후보는 `s`로 처리된 것과 동일하게 큐 보존

### 3.6 정책 5: `q` 비상구
- 사용자가 압도되었을 때 즉시 탈출 가능
- 잔여 모두 `s`(skip)로 일괄 처리 → 다음 session-wrap에서 재제시
- 데이터 손실 없음

---

## 4. 텍스트 Wireframe (ASCII)

`/session-wrap` 호출 시 또는 Stop hook 발화 시 표시되는 실제 UX 예시 (3건 누적 가정).

```
════════════════════════════════════════════════════════════════
  Harness Compound — 세션 종료 승격 후보 (3건)
  세션: sess_20260419_142301 · 누적 turn 1-127
════════════════════════════════════════════════════════════════

[1/3] 🟢 score=0.87 · trigger=pattern_repeat
  제안 저장 경로: tacit/kotlin-coroutine-scope.md
  요약: "CoroutineScope는 suspend 함수 밖에서 명시적으로 생성되..."
  source: sess_20260419_142301 · turn 45-48
  dimensions: correctness=0.90 · clarity=0.85
  reasoning: "3회 반복된 코루틴 스코프 패턴, 일반화 가치 높음"

  [y]승인  [N]거부  [e]수정 후 승인  [s]건너뛰기  [v]전체  [q]일괄 종료
  > _

────────────────────────────────────────────────────────────────

[2/3] 🟡 score=0.62 · trigger=user_correction
  제안 저장 경로: corrections/path-handling-windows.md
  요약: "Windows 경로 separator는 forward slash로도 동작하므로..."
  source: sess_20260419_142301 · turn 89-91
  dimensions: correctness=0.75 · generality=0.55
  reasoning: "회색지대 — 유저 정정이지만 일반화 폭이 좁음"

  [y]승인  [N]거부  [e]수정 후 승인  [s]건너뛰기  [v]전체  [q]일괄 종료
  > _

────────────────────────────────────────────────────────────────

[3/3] 🟢 score=0.83 · trigger=session_wrap
  제안 저장 경로: preferences/commit-message-style.md
  요약: "이 프로젝트는 conventional commits + 한국어 본문 규칙..."
  source: sess_20260419_142301 · turn 120-127
  dimensions: clarity=0.90 · actionability=0.85
  reasoning: "세션 학습 요지, 명확한 유저 선호"

  [y]승인  [N]거부  [e]수정 후 승인  [s]건너뛰기  [v]전체  [q]일괄 종료
  > _

════════════════════════════════════════════════════════════════
  완료: 승인 N건 · 거부 N건 · 건너뛰기 N건
  저장: .claude/memory/{tacit|corrections|preferences}/
  거부 이력: .claude/memory/corrections/_rejected/
════════════════════════════════════════════════════════════════
```

### 4.1 자동 비활성화 안내 예시 (3회 연속 거부 후)
```
════════════════════════════════════════════════════════════════
  ℹ  detector 자동 비활성화 안내
════════════════════════════════════════════════════════════════
  detector: pattern_repeat:coroutine-scope
  사유: 동일 패턴 3회 연속 거부
  비활성화 기간: 7일 (2026-04-26 까지)

  즉시 복구: /compound --reactivate pattern_repeat:coroutine-scope
════════════════════════════════════════════════════════════════
```

### 4.2 11+ 후보 누적 시 안내 예시
```
════════════════════════════════════════════════════════════════
  Harness Compound — 세션 종료 승격 후보 (15건 중 상위 10건)
════════════════════════════════════════════════════════════════
  ⚠ 잔여 5건은 다음 session-wrap에서 계속됩니다.
   (큐 위치: .claude/state/promotion_queue/)

  ... (이하 [1/10] ~ [10/10])
```

---

## 5. 구현 주차 매핑

| 주차 | 태스크 ID | 본 draft 매핑 |
|------|----------|--------------|
| W5 진입 전 | T-W5-PRE-01 | 본 draft를 final-spec.md §3.4로 정식 승격 (6 섹션 모두 흡수 + 열린 질문 해결) |
| W5 | T-W5-01 | candidate detector 큐 인프라 (Step 1) |
| W5 | T-W5-02 | Evaluator 서브에이전트 호출 wrapper (Step 2) |
| W5 | T-W5-03 | 자동 판정 분기 로직 (Step 3) |
| W5 | T-W5-04 | 저장 + frontmatter 작성 (Step 5) |
| W5 | T-W5-05 | 거부 이력 + 자동 비활성화 (Step 6 + §3 정책 2) |
| W5 | T-W5-06 | y/N/e/s/v/q UI (Step 4 §4.3) |
| W5 | T-W5-07 | Stop hook 일괄 제시 + 3회 거부 비활성화 (Step 4 §4.1 + §3 정책 2) |
| W5 | T-W5-08 | 거부 이력 인덱싱 (Step 6) |
| W5 | T-W5-09 | correction-detector 부정 문맥 (§11-2 잔여, 별도 트랙) |
| W6 | T-W6-03 | correction-detector.sh가 trigger_source=user_correction 케이스 생성 (Step 1 트리거 #2) |
| W6 | T-W6-05 | correction-detector PostToolUse 훅 등록 |
| W6 | T-W6-06 | `/session-wrap` 명령이 Step 4 배치 UX 트리거 |
| W7 | §11-7 detector | pattern_repeat 알고리즘 (Step 1 트리거 #1) |

---

## 6. 열린 질문 (W5 진입 전 결정 필요)

승격 시점(T-W5-PRE-01)에 본 3개 질문이 결정되어야 §3.4 정식화 가능.

### 6.1 자동 비활성화 기간 7일은 적절한가?
- **현재 임시값**: 7일
- **검증 방법**: KU-5 (과적합 감지) 실측 후 조정
- **결정 후보**:
  - (a) 7일 유지 (디폴트 — 1주 단위 사이클 가정)
  - (b) 3일 (빠른 재시도 — 유저 피로 적음)
  - (c) 14일 (보수적 — detector 재학습 시간 충분 확보)
- **결정 책임**: 본인 (KU-5 실측 데이터 기반) — 단 MVP 시점 데이터 부재 시 (a) 7일 채택 후 2차에서 조정

### 6.2 `e` (수정 후 승인) UX 상세
- **MVP 권장안**: 별도 프롬프트 (현재 후보 표시 → `e` 입력 → 신규 프롬프트로 본문 + 저장 경로 편집)
- **2차 검토안**: inline edit (현재 후보 표시 위치에서 직접 편집)
- **결정 후보**:
  - (a) 별도 프롬프트 (MVP) — 구현 단순, 멀티라인 편집 안정적
  - (b) inline edit (2차) — UX 매끄럽지만 터미널 환경 호환성 검증 필요
- **결정 책임**: 본인 (Claude Code 환경의 멀티라인 입력 호환성 확인 후)

### 6.3 Stop hook 일괄 제시가 Claude Code에서 실제 구현 가능한가?
- **위험**: Claude Code의 Stop hook이 stdout/stderr 외에 사용자 입력을 받을 수 있는지 미검증
- **영향**: 불가하다면 정책 1 (mid-session 중단 금지) 자체가 무너짐 → 대안 필요
- **검증 방법**: T-W1-10 (integration test) 결과 반영 — Stop hook 내에서 AskUserQuestion 또는 read 사용 가능 여부
- **대안 후보** (Stop hook 제약 시):
  - (a) `/session-wrap` 수동 호출만 지원 (Stop hook 자동 트리거 포기) — 유저 의지 의존
  - (b) Stop hook은 후보 큐에만 적재, 다음 SessionStart 시 일괄 제시 — 1세션 지연 발생
  - (c) PreCompact hook 활용 (compaction 직전 트리거) — 호출 빈도 적음
- **결정 책임**: 본인 (T-W1-10 결과 후) — 임시 (a) 채택 후 (b)/(c)로 fallback

---

## 7. 승격 게이트 기준 충족 매트릭스 (section11-promotion-tracker §3 대조)

| 게이트 기준 | 본 draft 충족 위치 | 상태 |
|------------|-------------------|------|
| 1. §3.4 신규 섹션의 6단계 전체 명세 (입출력 계약 포함) | §2 Step 1~6 전체 | ✅ 충족 |
| 2. Consent fatigue 완화 UX (Stop hook 일괄 + 3회 거부 비활성화) | §3 정책 1~5 | ✅ 충족 (열린 질문 §6.1 단서 포함) |
| 3. AskUserQuestion 정확한 프롬프트 문안 (한·영 병기) | §2 Step 4 §4.5 | ✅ 충족 |
| 추가 (section11-promotion-tracker §3 주의) | "동일 패턴" 정의 명시 | ✅ §3 정책 2 — ce-compound 5-dim overlap ≥ High |

→ **승격 게이트 3 기준 모두 충족 (열린 질문 3건 해결 시 즉시 §3.4 승격 가능)**

---

*본 draft는 W5 진입 전(T-W5-PRE-01) §3.4로 정식 승격 예정. 승격 시 final-spec.md §3.1 유저 스토리의 "승격 게이트(검증 → 유저 승인 → 저장)" 문장에 §3.4 링크 삽입 + 본 draft 6 섹션 흡수. 열린 질문 §6.1~§6.3 결정 후 최종화.*

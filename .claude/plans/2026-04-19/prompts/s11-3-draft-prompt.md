# §11-3 승격 게이트 UX 사전 설계 draft 지시서 (패널 4)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v3.1 (§3 승격 게이트 개념 · §2.1 #6 오염 방지 · §3.5 6축 강제 범위)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/user-decisions-5.md` — §3 승격 게이트 관련 유저 결정
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/section11-promotion-tracker.md` **§11-3 기준** (W5 이전 승격 deadline)
5. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec-review.md` — P0-6 승격 게이트 UX 미정의 지적
6. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/` 2-Phase + AskUserQuestion 패턴
   - `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/` ce-compound 5-dim overlap + Auto Memory

## 🎯 태스크

W5 이전 §11-3이 final-spec으로 승격되어야 함. 지금 **사전 설계 draft**를 작성 → W5 진입 시 바로 final-spec §3.4로 승격.

### 산출물: `04-planning/s11-3-ux-draft.md`

**필수 섹션**:

#### 1. 개요 및 승격 목표
- 승격 대상: final-spec §3 또는 §4 내에 신규 `§3.4 승격 게이트 상세 사양` 섹션 추가 예정
- 목적: "오염 방지"의 유일한 차단 메카닉을 구현자가 임의 해석하지 않도록 UX 전체 명세

#### 2. 승격 게이트 파이프라인 단계 (6-Step)

**Step 1: 후보 생성**
- 트리거 소스 3종 (v3 §2.1 #8):
  - 패턴 3회 반복 감지 (detector 알고리즘 §11-7에서 별도 설계)
  - "틀렸다" 발언 (correction-detector.sh, T-W6 범위)
  - 세션 종료 `/session-wrap`
- 후보 객체 스키마 YAML:
  ```yaml
  candidate_id: <uuid>
  trigger_source: pattern_repeat | user_correction | session_wrap
  content: <free text>
  context: {session_id, turn_range, related_files}
  detected_at: <ISO-8601>
  ```

**Step 2: Evaluator 점수**
- v3 §2.1 #5 "다른 관점 서브에이전트 + fresh context"로 Evaluator 호출
- qa-judge JSON 스키마 재사용 (v3 §4.2 참조, score ∈ [0.0, 1.0] + dimensions)

**Step 3: 자동 판정**
- `score ≥ 0.80`: **자동 승격 큐** (여전히 유저 최종 확인 단계 남음)
- `score ≤ 0.40`: **자동 기각** (corrections/_rejected/ 참고용 보존)
- `0.40 < score < 0.80` (회색지대): v3 §2.2 Dec 11에 따라 **2차 릴리스** 자동 Consensus, MVP는 수동 승격 fallback

**Step 4: 사용자 확인 UX** (P0-6 핵심)
- **mid-session 중단 금지** — 세션 종료(Stop hook) 시 일괄 제시
- 표시 내용 (후보별):
  - 전체 원문 (content 필드)
  - 저장 경로 예시 (`tacit/`, `corrections/`, `preferences/` 중 추천)
  - 소스 JSONL 턴 timestamp 링크
  - Evaluator 점수 + 주요 dimensions 1줄
- 응답 키:
  - `y` = 승인
  - `N` = 거부 (기본값)
  - `e` = 수정 후 승인
  - `s` = 건너뛰기 (다음 session-wrap 때 재제시)
- **텍스트 기반 wireframe** 포함 (예: ASCII box layout)

**Step 5: 저장**
- 승인 시에만 `.claude/memory/{tacit|corrections|preferences}/*.md` 기록
- `MEMORY.md` 인덱스 1줄 포인터 추가
- frontmatter 스키마:
  ```yaml
  ---
  candidate_id: <uuid>
  promoted_at: <ISO-8601>
  evaluator_score: 0.82
  source_turn: <session_id:turn_range>
  ---
  <본문>
  ```

**Step 6: 거부 이력**
- 거부된 후보는 `corrections/_rejected/{candidate_id}.md`에 보존
- 과적합 감지(KU-5) 입력으로 활용: 동일 패턴 3회 연속 거부 시 해당 detector 임시 비활성화

#### 3. Consent Fatigue 완화 정책
- **Stop hook 일괄 제시** 원칙 (mid-session 중단 없음)
- **동일 패턴 3회 연속 거부 시 detector 자동 비활성화 제안**
  - 자동 비활성화 기간: 7일 (재검토 prompt 포함)
  - 유저가 `/compound --reactivate detector_id`로 수동 재활성화 가능
- **배치 제시 시 우선순위**:
  - 높은 score 상위부터 (피로도 적은 상태에서 중요한 것 먼저 결정)
  - 최대 표시 개수: 10개 (초과 시 "다음 session-wrap에서 계속")

#### 4. 텍스트 Wireframe (ASCII)

`/session-wrap` 호출 시 표시되는 실제 UX 예시:

```
════════════════════════════════════════════════════════════════
  Harness Compound — 세션 종료 승격 후보 (3건)
════════════════════════════════════════════════════════════════

[1/3] 🟢 score=0.87 · trigger=pattern_repeat
  제안 저장 경로: tacit/kotlin-coroutine-scope.md
  요약: "CoroutineScope는 suspend 함수 밖에서..."
  source: sess_20260419_142301 · turn 45-48
  dimensions: correctness=0.9 clarity=0.85

  [y]승인  [N]거부  [e]수정 후 승인  [s]건너뛰기 >

[2/3] ...
```

#### 5. 구현 주차 매핑
- T-W5-PRE-01 (§11-3 승격): 본 draft를 final-spec §3.4로 정식화
- T-W5-01~05: 게이트 파이프라인 구현 (candidate detector · evaluator 호출 · store · reject log · 재활성화 명령)
- T-W6-03: correction-detector.sh가 Step 1의 trigger_source=user_correction 케이스 생성
- T-W6-06: `/session-wrap` 명령이 Step 4 배치 UX 트리거

#### 6. 열린 질문 (W5 진입 전 결정 필요)
- **자동 비활성화 기간 7일은 적절한가?** — KU-5로 실측 후 조정
- **e(수정 후 승인) UX 상세** — inline edit vs 별도 프롬프트? MVP는 별도 프롬프트 권장
- **Stop hook 일괄 제시가 Claude Code에서 실제 구현 가능한가?** — T-W1-10 integration test 결과 반영 필요

---

## 📁 산출물

- `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/s11-3-ux-draft.md`

### 부가 업데이트 (선택)
- `section11-promotion-tracker.md` §11-3 섹션에 "사전 draft 작성 완료 (s11-3-ux-draft.md) — W5 진입 시 승격 예정" 한 줄 추가

## ⚙️ 실행 제약

- **한국어** (draft 문서)
- **코드 블록 영어** OK
- **final-spec.md 수정 금지** — 사전 draft만. W5 진입 시 정식 승격은 별도 이터레이션
- **다른 패널과 파일 충돌 없음**:
  - 패널 1: hooks/session-start, skills/using-harness/
  - 패널 2: scripts/, __tests__/
  - 패널 3: README, LICENSE, CONTRIBUTING, .github/
  - 패널 4 (본인): 04-planning/s11-3-ux-draft.md + (선택) section11-promotion-tracker.md
- **user-decisions-5.md · implementation-plan.md 수정 금지**

## ✅ 완료 기준

1. `s11-3-ux-draft.md` 생성 (6섹션 + ASCII wireframe + 열린 질문)
2. (선택) section11-promotion-tracker.md §11-3 1줄 업데이트
3. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시 워크플로우 (필수)

```bash
cd /Users/ethan/Desktop/personal/harness

# 1. pull rebase
git pull --rebase origin main

# 2. stage
git add .claude/plans/2026-04-19/04-planning/s11-3-ux-draft.md .claude/plans/2026-04-19/04-planning/section11-promotion-tracker.md

# 3. commit (DCO sign-off)
git commit -s -m "$(cat <<'EOF'
docs(plan): §11-3 승격 게이트 UX 사전 설계 draft (W5 승격 준비)

- 04-planning/s11-3-ux-draft.md 신규 (6섹션 + ASCII wireframe)
- 6-Step 파이프라인 + Consent fatigue 완화 정책 + 주차 매핑 + 열린 질문
- W5 진입 시 final-spec §3.4로 승격 예정
EOF
)"

# 4. push (재시도 3회)
git push origin main || (git pull --rebase origin main && git push origin main) || (git pull --rebase origin main && git push origin main)
```

## 🛑 금지

- `final-spec.md` 수정 (승격은 W5 이전 별도 이터레이션)
- `implementation-plan.md` 수정 (W5 태스크는 이미 분해되어 있음)
- `.claude-plugin/`, `hooks/`, `skills/`, `scripts/`, 루트 docs 수정 (다른 패널 범위)
- references/ 수정

시작하세요.

---
name: compound
description: |
  개인화 컴파운딩 / Personal knowledge compounding — 3 트리거 (pattern_repeat · user_correction · session_wrap) → 승격 게이트 → 메모리 저장.
  Use when repeated patterns, user corrections, or session-end summaries should be promoted to persistent memory.
  트리거: "compound", "컴파운딩", "/session-wrap", "학습 저장", "승격", "promotion gate", "session wrap"
when_to_use: "세션에서 배운 것 · 유저의 정정 · 반복 패턴을 영구 메모리로 승격할 때"
input: "(자동) 3 트리거 이벤트 발생 | (수동) 호출 시 현재 세션 승격 후보 큐 일괄 제시"
output: ".claude/memory/{tacit|corrections|preferences}/*.md 승격 + MEMORY.md 인덱스 업데이트 | corrections/_rejected/ 거부 이력"
validate_prompt: |
  /compound 자기검증 (개선 축 · 6 compound):
  1. 3 트리거(pattern_repeat / user_correction / session_wrap)가 모두 인식되는가?
  2. 승격 게이트 6-Step (v3.3 §3.4) 순서 엄수: 후보 → 점수 → 판정 → UX → 저장 → 이력
  3. y/N/e/s 응답 키가 기본 N으로 설정되고 mid-session 중단 없이 Stop hook에서만 제시되는가?
  4. 메모리 파일 frontmatter가 `.claude/memory/README.md` 스키마(name/description/type/candidate_id/promoted_at/evaluator_score/source_turn)를 준수하는가?
  5. 동일 패턴 3회 연속 거부 시 해당 detector `disabled_until` 7일 자동 기록되는가?
  6. Bug track(corrections)과 Knowledge track(tacit) 분류가 자동 이루어지는가?
---

# Compound

> 하네스 플러그인의 **개인화 컴파운딩 메모리**. 3 트리거 → 승격 게이트(v3.3 §3.4) → `.claude/memory/` 저장. 오염 방지를 위해 **모든 쓰기는 승격 게이트 통과 시에만** (v3.3 §2.1 #6).

## When to Use

- **자동**: 세션 중 3 트리거 감지
  - `pattern_repeat`: 동일 토픽/패턴 3회 반복 → T-W6-06 감지기
  - `user_correction`: 유저가 "틀렸다"·"wrong"·"incorrect"·"잘못" 발언 → T-W6-05 correction-detector
  - `session_wrap`: 세션 종료 `/session-wrap` → T-W6-07 · Stop hook 일괄 제시 (v3.3 §3.4.4)
- **수동**: `/compound` 호출 시 현재 큐 일괄 제시
- **관리**: `/compound --reactivate <detector_id>` 로 비활성화된 detector 재활성화

## Protocol

각 Phase는 **목표 / 입력 / 동작 / 출력 / 실패 시 fallback** 5섹션 고정.

### Phase 1: Trigger Intake
(T-W6-02 session-wrap 2-Phase + T-W6-05·06·07 트리거 감지에서 확장)

### Phase 2: Evaluator Score
(W4 qa-judge 재사용 + 5-dim overlap scoring — T-W5-05에서 확장)

### Phase 3: Auto Verdict
(v3.3 §3.4.1 Step 3 — 0.80/0.40 임계값 + 회색지대 수동 fallback)

### Phase 4: Gate UX (y/N/e/s)
(T-W5-06에서 확장 — Stop hook 일괄 제시 + Consent fatigue 완화)

### Phase 5: Store + Reject Log
(T-W5-08에서 확장 — `.claude/memory/{tacit|corrections|preferences}/` 저장 + `_rejected/` 이력)

## Integration Points

- **입력**:
  - 자동 3 트리거 (hooks/UserPromptSubmit·PostToolUse·Stop)
  - 수동 `/compound` 호출
- **출력**:
  - `.claude/memory/{tacit|corrections|preferences}/<slug>.md` (frontmatter + 본문)
  - `.claude/memory/MEMORY.md` 인덱스 1줄 추가
  - `.claude/memory/corrections/_rejected/<candidate_id>.md` (거부 이력)
- **보안 · 오염 방지**: v3.3 §3.4 승격 게이트 · §4.3.7 부정 문맥 규칙 · §4.3.4 글로벌 메모리 기본 OFF
- **상호 참조**:
  - `/verify` qa-judge 점수 재사용 (v3.3 §2.1 #5 Evaluator)
  - `skills/compound/templates/gate-dialog.md` (T-W5-06 ASCII wireframe)
  - `scripts/track-router.sh` (T-W5-04 Bug/Knowledge 분류)
  - `scripts/overlap-score.sh` (T-W5-05 5-dim)
  - `scripts/promotion-gate.sh` (T-W5-06 y/N/e/s)
  - `hooks/stop.sh` (T-W5-07 일괄 제시 + 비활성화)

## TODO (W6 후속 태스크)

| 태스크 | 범위 | 공수 |
|-------|------|------|
| T-W6-02 | Phase 1~5 본문 확장 + session-wrap 2-Phase 파이프라인 | 8h |
| T-W6-03 | `agents/compound/` 5종 (tacit-extractor · correction-recorder · pattern-detector · preference-tracker · duplicate-checker) | 8h |
| T-W6-04 | `scripts/keyword-detector.sh` bash+jq 재작성 (Python 제거) | 6h |
| T-W6-05 | `hooks/correction-detector.sh` UserPromptSubmit 훅 확장 | 4h |
| T-W6-06 | 3회 반복 패턴 감지 (JSONL 파서 활용) | 4h |
| T-W6-07 | `/session-wrap` 수동 호출 트리거 | 2h |
| T-W6-08 | 3 트리거 감지 AC-6 unit test | 4h |

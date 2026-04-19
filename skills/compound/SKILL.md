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
Phase 1~3은 `scripts/session-wrap-pipeline.sh` 의 2-Phase 파이프라인(A: 병렬 4 분석자 · B: 순차 validator)에 대응하며, Phase 4~5는 T-W5 승격 게이트 본체를 재사용한다.

---

### Phase 1 — Trigger Intake (session-wrap Phase A 진입)

- **목표**: 3 트리거(`pattern_repeat` / `user_correction` / `session_wrap`) 중 하나가 활성화되면 세션 JSONL을 정규화하고 4 분석자가 공유할 입력 스냅샷을 만든다. (v3.3 §3.4.1 Step 1)
- **입력**:
  - hooks 신호 — `UserPromptSubmit` (user_correction) · `PostToolUse` (pattern_repeat) · `Stop` (session_wrap) · 수동 `/session-wrap` 호출
  - 세션 JSONL — `~/.claude/projects/<encoded-cwd>/*.jsonl` (W1 `scripts/extract-session.sh` 재사용)
- **동작**:
  1. 트리거 종류 식별 → `trigger_source` 태그 부여
  2. `scripts/extract-session.sh` 호출로 JSONL → 정규화 turn 배열
  3. 최근 N turn(기본 50) 윈도우를 snapshot 파일(`.claude/state/sessions/<session_id>.turns.json`)로 고정
  4. session_id + turn_range 메타 생성 → `scripts/session-wrap-pipeline.sh` 에 전달
- **출력**:
  - Phase A 입력 스냅샷 파일 경로 (stdout JSON `{session_id, turns_path, trigger_source}`)
- **실패 시 fallback**:
  - JSONL 미존재 → stderr 경고 + 빈 큐 반환 (트리거 무시)
  - 손상 라인 → `extract-session.sh` 정책에 따라 skip + stderr 집계. 전체 처리는 계속.
  - `hooks/stop.sh` 는 Phase 1 실패 시 `[compound] intake skipped` 로그만 남기고 즉시 종료.

---

### Phase 2 — Analyzer Fanout (session-wrap Phase A, 4 분석자 병렬)

- **목표**: 동일 snapshot을 독립 fresh-context로 읽는 4 분석자가 승격 후보를 추출. p4cn session-wrap 2-Phase 파이프라인의 **Phase A** 이식 (포팅 자산 #4).
- **입력**:
  - Phase 1 스냅샷 (`turns_path`, `session_id`, `trigger_source`)
  - 4 분석자 spec (`agents/compound/{tacit-extractor,correction-recorder,pattern-detector,preference-tracker}.md`)
- **동작**:
  1. Claude는 **Task 도구 4회 동시 호출**로 4 분석자를 병렬 실행 (각각 fresh context)
     - `tacit-extractor` → Knowledge track 후보 (암묵지 / 경험)
     - `correction-recorder` → Bug track 후보 (original_claim · user_correction · prevention)
     - `pattern-detector` → 3회 이상 등장 토픽 후보
     - `preference-tracker` → 선호 후보 (scope: session/project/user)
  2. 각 분석자의 stdout = 후보 JSON 리스트: `[{content, trigger_source, track_hint, rationale, turn_range}, ...]`
  3. `scripts/session-wrap-pipeline.sh` 가 wall-clock 기준 모든 분석자 종료 대기 → 4개 결과를 `.claude/state/sessions/<session_id>.candidates.raw.json` 으로 병합
- **출력**:
  - 후보 raw 큐 경로 (4 분석자 합산, dedup 전)
- **실패 시 fallback**:
  - 분석자 1개 실패 → 나머지 3개 결과만 병합 (부분 성공 허용, stderr 경고)
  - 분석자 ≥2개 실패 → Phase 2 abort, Phase B 건너뛰고 빈 큐로 Phase 4 진입
  - Task 도구 불가(MVP 스텁 경로) → `scripts/session-wrap-pipeline.sh` 가 fixed fixture 반환

---

### Phase 3 — Validator + Evaluator Score (session-wrap Phase B, 1 validator 순차)

- **목표**: Phase A 출력을 단일 validator로 dedup/병합한 뒤 `/verify` qa-judge 점수와 5-dim overlap band를 부착. 2-Phase의 **Phase B** 이식.
- **입력**:
  - Phase 2 raw 큐 (`candidates.raw.json`)
  - 기존 메모리 — `.claude/memory/{tacit,corrections,preferences}/*.md`
  - W4 qa-judge 에이전트 · `scripts/overlap-score.sh` (T-W5-05 5-dim)
- **동작**:
  1. `agents/compound/duplicate-checker` 1회 순차 호출 → raw 큐의 4 분석자 출력 병합 + 기존 memory 대비 dedup
  2. 각 후보를 `scripts/overlap-score.sh <candidate.yaml> <target.md>` 로 5-dim 비교 → `overlap_band` (High / Moderate / Low) 할당
  3. `/verify` qa-judge 재사용 — correctness / clarity / citations / safety / completeness 5 dim 평균 → `evaluator_score` (0.0~1.0)
  4. 후보 YAML 생성: `.claude/state/sessions/<session_id>.candidates/<candidate_id>.yaml` (frontmatter `candidate_id`·`trigger_source`·`evaluator_score`·`overlap_band` + 본문 content)
- **출력**:
  - 후보 YAML 파일 리스트 (Phase 4 큐 입력)
- **실패 시 fallback**:
  - duplicate-checker 실패 → raw 큐를 그대로 Phase 4로 전달 (dedup 건너뜀, stderr 경고)
  - qa-judge 미응답 → `evaluator_score=0.0` 부여 → Phase 3 Auto Verdict 가 회색지대로 분류 → Phase 4 수동 결정
  - overlap-score 계산 불가 → `overlap_band=unknown` 로 마크 (Phase 4에서 수동 검토)

---

### Phase 4 — Gate UX (y / N / e / s, Stop hook 일괄 제시)

- **목표**: Phase 3까지 누적된 후보 큐를 **Stop hook 시점에만** 유저에게 일괄 제시 (v3.3 §3.4.3 · §2.1 #6 오염 방지). T-W5-06 `gate-dialog.md` + `scripts/promotion-gate.sh` 재사용.
- **입력**:
  - 후보 YAML 큐
  - `skills/compound/templates/gate-dialog.md` 템플릿
- **동작**:
  1. `hooks/stop.sh` → `scripts/promotion-gate.sh <candidate.yaml>` 를 후보 개수만큼 순차 호출
  2. `evaluator_score` 기반 Auto Verdict (v3.3 §3.4.1 Step 3):
     - `≥0.80` → 🟢 기본 `y` 하이라이트
     - `≤0.40` → 🔴 기본 `N` 하이라이트
     - 회색지대 → 🟡 명시적 유저 입력 필요
  3. y / N / e / s 응답 수집 — Enter 단독 입력은 **N (거부)** 고정, mid-session 차단 금지
  4. `e` 선택 시 편집 프롬프트 → 수정된 본문 파일 경로를 Phase 5로 전달
- **출력**:
  - 응답 결과 JSON — `{"action":"approved|rejected|edited_approved|skipped", ...}` per candidate
- **실패 시 fallback**:
  - Stop hook 외 시점 호출 → 즉시 abort (mid-session 중단 금지)
  - stdin 유실 (비대화형) → 전부 `N` 처리 + stderr `[compound] non-interactive → all rejected`
  - 동일 detector 3회 연속 거부 감지 → `hooks/stop.sh` 가 `disabled_until` = now + 7일 기록 (v3.3 §3.4.4)

---

### Phase 5 — Store + Reject Log (승격 확정 및 이력)

- **목표**: 승인 후보는 `.claude/memory/` 로 영구 저장, 거부 후보는 `_rejected/` 이력으로 축적. T-W5-08 `scripts/track-router.sh` 확장.
- **입력**:
  - Phase 4 응답 결과
  - 후보 YAML (frontmatter 포함)
- **동작**:
  1. `action=approved|edited_approved` → `scripts/track-router.sh` 로 Bug/Knowledge 자동 분류
     - `trigger_source=user_correction` → `.claude/memory/corrections/<slug>.md`
     - 그 외 → `.claude/memory/tacit/<slug>.md`
     - scope 필드 있는 preference 후보 → `.claude/memory/preferences/<slug>.md`
  2. frontmatter (`name`·`description`·`type`·`candidate_id`·`promoted_at`·`evaluator_score`·`source_turn` + type별 추가 필드)를 `.claude/memory/README.md` 스키마대로 기록
  3. `MEMORY.md` 인덱스에 1줄 포인터 추가 (정규식 `^- \[([^\]]+)\]\(([^)]+)\) — (.{1,150})$`)
  4. `action=rejected` → `.claude/memory/corrections/_rejected/<candidate_id>.md` + `_rejections.log` 누적
  5. `action=skipped` → 큐에 남기고 다음 session_wrap 에서 재제시
  6. 글로벌 모드 opt-in(`plugin.json.global_memory_enabled=true`) 이면 `project_id` 태그 강제 주입 (v3.3 §4.3.4 교차 오염 방지)
- **출력**:
  - 저장된 메모리 파일 경로 · 갱신된 `MEMORY.md` · `_rejected/` 이력
- **실패 시 fallback**:
  - 파일 쓰기 실패(권한/디스크) → candidate 를 `.claude/state/sessions/<session_id>.pending.yaml` 로 큐잉 + stderr 경고. 다음 session_wrap 에서 재시도.
  - slug 충돌 → `<slug>-<candidate_id_prefix>` 로 자동 접미사. 기존 파일 덮어쓰기 금지.
  - `MEMORY.md` 200줄 초과 위험 → 오래된 항목 정리 제안을 stderr 로 출력 (자동 삭제 금지)

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

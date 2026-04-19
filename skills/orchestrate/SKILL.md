---
name: orchestrate
description: |
  4축 통합 오케스트레이션 / 4-axis integrated orchestration — /brainstorm → /plan → /verify → /compound 순차 파이프라인.
  Use when a single topic requires end-to-end harness run across all four axes without manual dispatch.
  트리거: "orchestrate", "오케스트레이션", "/orchestrate", "4축 파이프라인", "end-to-end"
when_to_use: "단일 주제를 4축(Brainstorm → Plan → Verify → Compound)으로 일괄 처리할 때"
input: "주제 프롬프트 (자연어 1줄) + 선택적 --skip-axis <n> 이스케이프 해치"
output: "4축 파이프라인 experiment-log.yaml CP-0~CP-5 + 각 축 산출물 링크"
validate_prompt: |
  /orchestrate 자기검증 (4축 순차 무결성):
  1. 4축 순서(Brainstorm → Plan → Verify → Compound) 위반 없는가?
  2. 각 축 Mandatory Disk Checkpoint(CP-0~CP-5)가 experiment-log.yaml에 기록되는가?
  3. cursor bucket UI로 현재 축·진행률이 시각화되는가?
  4. 3-Axis dispatch×work×verify 조합 중 허용된 3 조합으로 수렴하는가?
  5. 축 간 아티팩트 전달 시 SHA256 payload 무결성 검증 수행하는가?
  6. 실패 시 해당 축에서 중단 + 이미 진행된 체크포인트는 보존하는가?
---

# Orchestrate

> 4축 통합 파이프라인. **[Stretch]** — v3.3 §10.2 AC-Stretch-1 목표. MVP 릴리스 블록 아님.
> 각 축 실제 LLM 호출은 W7.5 (KU-3) 에서 실측. 현재는 **stub 반환 허용**.

## When to Use

- 단일 주제를 브레인스토밍부터 승격까지 **연속** 진행할 때
- 수동 `/brainstorm` → `/plan` → `/verify` → `/compound` 호출이 번거로울 때
- 4축 일관성이 중요한 프로젝트 초기 설계 단계
- 3-Axis 실행 조합(`sequential×fresh-context×strict` 등)을 명시적으로 선택하고 싶을 때

## Input

- 주제 프롬프트: 자연어 1줄 (예: `"add dark mode toggle"`)
- 선택 플래그:
  - `--skip-axis <n>` : 특정 축(n=1..4) 스킵
  - `--resume <run_id>` : 중단된 실행 재개 (마지막 `done` CP 다음부터)
  - `--axis dispatch=...,work=...,verify=...` : 3-Axis 조합 선택 (T-W7-04)

## Output

- `.claude/state/orchestrate/<run_id>/experiment-log.yaml` (CP-0~CP-5)
- 축별 산출물:
  - `01-brainstorm/requirements.md`
  - `02-plan/impl-plan.md`
  - `03-verify/qa-score.json`
  - `04-compound/promotion-queue.yaml`

## Protocol

각 Phase는 **목표 / 입력 / 동작 / 출력 / 실패 시 fallback** 5섹션 고정.
전체 드라이버는 `scripts/orchestrate-pipeline.sh`, 체크포인트 기록은
`scripts/orchestrate-checkpoint.sh`, 진행 시각화는 `scripts/cursor-bucket-ui.sh`,
3-Axis 조합 선택은 `scripts/orchestrate-three-axis.sh` 에서 수행한다.

---

### Phase 1 — Brainstorm (CP-0 → CP-1)

- **목표**: 주제를 요구사항 문서(`requirements.md`)로 정제. 1축(skills/brainstorm) 재사용.
- **입력**: 사용자 주제 프롬프트 (자연어 1줄) + `--skip-axis 1` 미지정.
- **동작**:
  1. CP-0 기록: `{run_id, topic, skip_axes, dispatch_mode, started_at}`
  2. `skills/brainstorm/SKILL.md` 프로토콜 호출 (MVP stub: fixture requirements 복사)
  3. 산출물을 `01-brainstorm/requirements.md` 로 저장
  4. CP-1 기록: `{requirements_path, turn_count, started_at, completed_at}`
- **출력**: `01-brainstorm/requirements.md` + CP-1 체크포인트
- **실패 시 fallback**:
  - stub 실패 → 빈 requirements.md + CP-1 `status: failed` 기록, 파이프라인 중단
  - `--skip-axis 1` 지정 시 CP-1 `status: skipped` 로만 기록 후 Phase 2 진행

---

### Phase 2 — Plan (CP-1 → CP-2)

- **목표**: Phase 1 요구사항을 implementation-plan 으로 전개. 2축(skills/plan) 재사용.
- **입력**: `01-brainstorm/requirements.md` (또는 skip 시 topic 직접 투입).
- **동작**:
  1. `skills/plan/SKILL.md` 프로토콜 호출 (MVP stub: task_count=0 placeholder)
  2. 산출물을 `02-plan/impl-plan.md` 로 저장
  3. CP-2 기록: `{plan_path, task_count, completed_at}`
- **출력**: `02-plan/impl-plan.md` + CP-2 체크포인트
- **실패 시 fallback**:
  - stub 실패 → CP-2 `status: failed`, 파이프라인 중단 (체크포인트 보존)
  - `--skip-axis 2` → CP-2 `status: skipped`

---

### Phase 3 — Verify (CP-2 → CP-3)

- **목표**: Plan 품질 검증. 3축(skills/verify) 재사용. qa-judge 점수 + Ralph Loop.
- **입력**: `02-plan/impl-plan.md`.
- **동작**:
  1. `skills/verify/SKILL.md` qa-judge 호출 (MVP stub: 고정 점수 0.75 · verdict `pass`)
  2. Ralph Loop 반복 횟수 기록 (stub: 0)
  3. 산출물을 `03-verify/qa-score.json` 로 저장
  4. CP-3 기록: `{qa_score, verdict, ralph_loop_iterations, completed_at}`
  5. `qa_score < 0.40` → Phase 4 진입 거부, 파이프라인 중단 (체크포인트 유지)
- **출력**: `03-verify/qa-score.json` + CP-3 체크포인트
- **실패 시 fallback**:
  - stub 실패 → CP-3 `status: failed`, 파이프라인 중단
  - `--skip-axis 3` → CP-3 `status: skipped` + `qa_score: null`

---

### Phase 4 — Compound (CP-3 → CP-4)

- **목표**: 검증 통과 후 승격 게이트 경유해 메모리 후보 큐 생성. 4축(skills/compound) 재사용.
- **입력**: `03-verify/qa-score.json` (verdict == pass 필수).
- **동작**:
  1. `skills/compound/SKILL.md` 승격 게이트 호출 (MVP stub: promoted=0, rejected=0)
  2. 산출물을 `04-compound/promotion-queue.yaml` 로 저장
  3. CP-4 기록: `{promoted_count, rejected_count, completed_at}`
- **출력**: `04-compound/promotion-queue.yaml` + CP-4 체크포인트
- **실패 시 fallback**:
  - stub 실패 → CP-4 `status: failed`, CP-5 는 기록하되 총평은 `failed` 로 마감
  - `--skip-axis 4` → CP-4 `status: skipped` + 빈 promotion-queue

---

### Phase 5 — Finalize (CP-4 → CP-5)

- **목표**: 전체 실행 요약 + 총소요시간 기록. 항상 실행 (앞 단계 실패 여부와 무관).
- **입력**: 앞선 CP-0~CP-4 메타.
- **동작**:
  1. `total_duration_sec` = CP-5.timestamp - CP-0.started_at
  2. `artifacts_paths` 배열 수집
  3. CP-5 기록: `{total_duration_sec, artifacts_paths, completed_at}`
  4. `cursor-bucket-ui.sh` 에 최종 상태 전달 (done | failed | partial)
- **출력**: CP-5 체크포인트 + stdout JSON 한 줄 요약.
- **실패 시 fallback**:
  - CP-5 기록 자체가 실패 → stderr 경고 + exit 4. 앞 CP 는 보존됨.

---

## Checkpoints

**CP-0** (Intake) · **CP-1** (Brainstorm) · **CP-2** (Plan) · **CP-3** (Verify) · **CP-4** (Compound) · **CP-5** (Finalize).
모든 체크포인트는 `.claude/state/orchestrate/<run_id>/experiment-log.yaml` 에 `flock`(또는 mkdir fallback) 보호하에 append.
CP 순서 위반(예: CP-3 없이 CP-4 기록 시도)은 `orchestrate-checkpoint.sh` 가 거부한다.

## 3-Axis Execution Modes

`scripts/orchestrate-three-axis.sh` 가 `dispatch × work × verify` 9 조합 중
**허용 3 조합**만 통과시킨다:

1. `sequential × fresh-context × strict` — **기본**. 단일 패널, 가장 보수적.
2. `parallel × shared-context × lenient` — 고속 모드. 축 간 병렬 실행 시도.
3. `lazy × hybrid × skip` — 디버그/드라이런 모드. 대부분 stub.

미허용 조합 선택 시 stderr 에러 + exit 1.

## Cursor Bucket UI

`scripts/cursor-bucket-ui.sh` 는 현재 `experiment-log.yaml` 을 읽어 6 bucket
상태(`pending · active · done · skipped · failed · paused`) 를 ANSI 색상으로
렌더링. cursor 전이: `pending → active → done`(또는 `failed`).

## Escape Hatches

- `--skip-axis <n>` : 해당 축을 skipped 로 기록하고 통과
- `--resume <run_id>` : 마지막 done CP 다음 Phase 부터 재개
- `ORCH_STUB=1` : 모든 축을 stub 으로 강제 (테스트용 기본값)

## References

- 포팅 #12: `references/agent-council/` wait cursor bucket UI
- 포팅 #16: `references/hoyeon/` 3-Axis dispatch × work × verify
- 포팅 #17: `references/ouroboros/` Mandatory Disk Checkpoints

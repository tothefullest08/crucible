# W7 Sprint 1 (단일 패널) — T-W7-01~06 `/orchestrate` [Stretch] 전량

> **⚠️ 본 주차는 전량 [Stretch]**: v3.3 §10.2 기준 MVP 릴리스 차단 아님. AC-Stretch-1 만 목표. 속도 우선·완결성 차선.

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v3.3 (§3 스킬 모델, §10.2 Stretch AC-Stretch-1)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W7 (T-W7-01~06)
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/prompts/_git-workflow-template.md`
5. `/Users/ethan/Desktop/personal/harness/skills/brainstorm/SKILL.md` — 1축 참조 (T-W2 산출)
6. `/Users/ethan/Desktop/personal/harness/skills/plan/SKILL.md` — 2축 참조 (T-W3 산출)
7. `/Users/ethan/Desktop/personal/harness/skills/verify/SKILL.md` — 3축 참조 (T-W4 산출)
8. `/Users/ethan/Desktop/personal/harness/skills/compound/SKILL.md` — 4축 참조 (T-W6 산출)
9. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/agent-council/skills/` — Wait cursor bucket UI 원본 (포팅 #12)
   - `/Users/ethan/Desktop/personal/harness/references/hoyeon/skills/` — 3-Axis dispatch×work×verify (포팅 #16)
   - `/Users/ethan/Desktop/personal/harness/references/ouroboros/` — Mandatory Disk Checkpoints 원본 (포팅 #17)

## 🎯 태스크 (순차, 중간 커밋 허용)

### T-W7-01 — `skills/orchestrate/SKILL.md` 구조 + frontmatter (4h) → **AC-Stretch-1**

**경로**: `skills/orchestrate/SKILL.md` (신규)

**frontmatter**:
```yaml
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

> 4축 통합 파이프라인. [Stretch] AC-Stretch-1 목표. MVP 블록 아님.

## When to Use
- 단일 주제를 브레인스토밍부터 승격까지 연속 진행할 때
- 수동 /brainstorm → /plan → /verify → /compound 호출이 번거로울 때
- 4축 일관성이 중요한 프로젝트 초기 설계 단계

## Protocol
(본 태스크는 구조만 작성. 본문 Phase 1~4는 T-W7-02에서 확장)

- **Phase 1 — Brainstorm**: `/brainstorm` 호출 → requirements.md 산출
- **Phase 2 — Plan**: `/plan` 호출 → implementation-plan.md 산출
- **Phase 3 — Verify**: `/verify` 호출 → qa-judge 점수 + Ralph Loop
- **Phase 4 — Compound**: `/compound` 호출 → 승격 게이트 + 메모리 저장

## Checkpoints
CP-0 (입력 확정) · CP-1 (Brainstorm 완료) · CP-2 (Plan 완료) · CP-3 (Verify 완료) · CP-4 (Compound 완료) · CP-5 (최종 정리)
모든 체크포인트는 `.claude/state/orchestrate/<run_id>/experiment-log.yaml`에 기록.

## Escape Hatches
- `--skip-axis <n>`: 특정 축 스킵 (n=1..4)
- `--resume <run_id>`: 중단된 실행 재개 (CP-N 에서)
```

**검증**: `yq eval '.name, .description' skills/orchestrate/SKILL.md` 파싱 통과 + frontmatter 필드 6개 모두 존재

---

### T-W7-02 — 내부 4축 순차 파이프라인 (12h)

**경로**:
- `skills/orchestrate/SKILL.md` 본문 Phase 1~4 확장
- `scripts/orchestrate-pipeline.sh` (신규, 실행 가능)

**목표**: `/brainstorm → /plan → /verify → /compound` 4축을 하나의 실행으로 연결. 각 축 산출물이 다음 축 입력으로 전달.

**SKILL.md Phase 확장 포인트**:
- Phase 1 (Brainstorm): 목표/입력/동작/출력/fallback 5섹션
  - 동작: `skills/brainstorm/SKILL.md` 트리거 + requirements 산출
  - 출력: `.claude/state/orchestrate/<run_id>/01-brainstorm/requirements.md`
- Phase 2 (Plan): Phase 1 산출 입력
  - 동작: `skills/plan/SKILL.md` 트리거 + implementation-plan 산출
  - 출력: `.claude/state/orchestrate/<run_id>/02-plan/impl-plan.md`
- Phase 3 (Verify): Phase 2 산출 입력
  - 동작: `skills/verify/SKILL.md` qa-judge + Ralph Loop 호출
  - 출력: `.claude/state/orchestrate/<run_id>/03-verify/qa-score.json`
  - 점수 < 0.40 → 실패, 체크포인트 유지
- Phase 4 (Compound): Phase 3 산출 입력
  - 동작: `skills/compound/SKILL.md` 승격 게이트 호출
  - 출력: `.claude/state/orchestrate/<run_id>/04-compound/promotion-queue.yaml`

**pipeline 스크립트** (`scripts/orchestrate-pipeline.sh`):
- 입력: 주제 문자열 + optional `--skip-axis <n>` + `--resume <run_id>`
- 동작:
  1. `run_id=$(uuidgen)` 생성
  2. `.claude/state/orchestrate/<run_id>/` 디렉토리 생성
  3. CP-0 기록 (experiment-log.yaml)
  4. Phase 1~4 순차 실행 (`--skip-axis` 검사)
  5. 각 Phase 완료 시 CP-N 기록
  6. 최종 CP-5 정리
- shellcheck 통과

**검증**:
- 단일 주제(예: "add dark mode toggle")로 4축 end-to-end 성공 1회 (MVP는 stub 반환 허용)
- experiment-log.yaml 에 CP-0~CP-5 기록 확인

---

### T-W7-03 — agent-council Wait cursor bucket UI 차용 (6h) — 포팅 #12

**경로**: `scripts/cursor-bucket-ui.sh` (신규)

**목표**: 6축 진행 시각화 + cursor 상태 전이. agent-council 원본에서 착안.

**로직**:
1. `experiment-log.yaml` 읽기 → 현재 CP-N 감지
2. 6 bucket 상태:
   - `pending` · `active` · `done` · `skipped` · `failed` · `paused`
3. stdout ANSI 렌더링:
   ```
   [✓] CP-0 Intake        (done)
   [⠋] CP-1 Brainstorm    (active · 3s elapsed)
   [ ] CP-2 Plan          (pending)
   [ ] CP-3 Verify        (pending)
   [ ] CP-4 Compound      (pending)
   [ ] CP-5 Finalize      (pending)
   ```
4. cursor 전이 규칙: pending → active → done (또는 failed)
5. shellcheck 통과

**레퍼런스 확인**: `ls /Users/ethan/Desktop/personal/harness/references/agent-council/skills/` 에서 cursor 관련 파일 스캔. 실제 구현 참고(포팅 #12).

**검증**:
- 6 bucket 상태 전이 수동 시뮬레이션 1회 성공
- ANSI 색상 코드 포함 출력

---

### T-W7-04 — hoyeon 3-Axis 실행 조합 (6h) — 포팅 #16

**경로**: `scripts/orchestrate-three-axis.sh` (신규)

**목표**: hoyeon 3-Axis 방식 차용. dispatch × work × verify = 9 조합 중 최소 3 조합 동작.

**3-Axis 정의**:
- **dispatch**: sequential · parallel · lazy
- **work**: fresh-context · shared-context · hybrid
- **verify**: strict · lenient · skip

**허용 3 조합** (MVP):
1. `sequential × fresh-context × strict` (기본)
2. `parallel × shared-context × lenient` (고속 모드)
3. `lazy × hybrid × skip` (디버그 모드)

**로직**:
1. `--axis dispatch=sequential,work=fresh-context,verify=strict` 플래그 파싱
2. 조합 검증 (9 조합 중 허용 3 조합인지)
3. 해당 조합 선택 시 orchestrate-pipeline.sh 에 파라미터 전달
4. 미허용 조합 → stderr 에러 + exit 1

**검증**:
- 3 허용 조합 각각 1회 실행 성공 (stub 반환 허용)
- 미허용 조합 시 적절한 에러 출력

---

### T-W7-05 — Mandatory Disk Checkpoints CP-0~CP-5 (6h) — 포팅 #17

**경로**: `scripts/orchestrate-checkpoint.sh` (신규, lib) + `orchestrate-pipeline.sh` 통합

**목표**: ouroboros Mandatory Disk Checkpoints 방식 도입. 모든 단계 종료 시 디스크 기록 강제.

**체크포인트 스펙**:
- CP-0 (Intake): `{run_id, topic, skip_axes, dispatch_mode, started_at}`
- CP-1 (Brainstorm): `{requirements_path, turn_count, started_at, completed_at}`
- CP-2 (Plan): `{plan_path, task_count, completed_at}`
- CP-3 (Verify): `{qa_score, verdict, ralph_loop_iterations, completed_at}`
- CP-4 (Compound): `{promoted_count, rejected_count, completed_at}`
- CP-5 (Finalize): `{total_duration_sec, artifacts_paths, completed_at}`

**저장 포맷** (`experiment-log.yaml`):
```yaml
run_id: <uuid>
topic: "<input>"
checkpoints:
  CP-0:
    timestamp: 2026-04-19T...
    status: done
    data: {...}
  CP-1:
    ...
```

**로직**:
1. `write_checkpoint <run_id> <cp_name> <status> <data_json>` 함수
2. yq로 experiment-log.yaml 업데이트 (append/merge)
3. 파일 잠금(`flock`) — 동시 쓰기 방지
4. shellcheck 통과

**검증**:
- 4축 전체 실행 시 CP-0~CP-5 6개 전부 experiment-log.yaml 기록
- CP 순서 위반 거부 (예: CP-3 전에 CP-4 기록 시도 시 에러)

---

### T-W7-06 — 4축 순차 전체 파이프라인 unit test (4h)

**경로**: `__tests__/integration/test-orchestrate-pipeline.sh` (신규)

**목표**: 단일 주제 end-to-end 녹화 1회 성공.

**테스트 시나리오**:
1. 주제: "add error boundary component" (단순 샘플)
2. `./scripts/orchestrate-pipeline.sh "add error boundary component"` 실행
3. 기대 산출:
   - `.claude/state/orchestrate/<run_id>/experiment-log.yaml` CP-0~CP-5 존재
   - `01-brainstorm/`, `02-plan/`, `03-verify/`, `04-compound/` 4 디렉토리 존재
   - cursor-bucket-ui.sh 출력에 `[✓] CP-5 Finalize (done)` 포함
4. 검증 assertion:
   - `yq '.checkpoints.CP-5.status' experiment-log.yaml == "done"`
   - 각 축 산출물 파일 최소 1개 존재
5. **MVP는 각 축 실제 LLM 호출 대신 stub 허용** (T-W7-02 Phase 스텁 재사용)

**검증**: 1회 실행 → PASS 출력. 실패 시 어느 CP에서 실패했는지 명시.

---

## 📁 산출물

- `skills/orchestrate/SKILL.md` (T-W7-01 + T-W7-02 본문 확장)
- `scripts/orchestrate-pipeline.sh` (T-W7-02)
- `scripts/cursor-bucket-ui.sh` (T-W7-03)
- `scripts/orchestrate-three-axis.sh` (T-W7-04)
- `scripts/orchestrate-checkpoint.sh` (T-W7-05)
- `__tests__/integration/test-orchestrate-pipeline.sh` (T-W7-06)

## ⚙️ 실행 제약

- bash + jq + yq + uuidgen + flock만 (v3.3 §4.1). **Python 금지**.
- `"$var"` 쌍따옴표 · `eval` 금지 · shellcheck 통과
- skills/brainstorm, skills/plan, skills/verify, skills/compound **수정 금지** (read-only 참조만)
- `_git-workflow-template.md` 순서 엄수
- 권한 dialog 나오면 "2" always allow
- **Stretch 특성**: 완결성보다 구조 완성 우선. 각 축 실제 LLM 호출 대신 stub 반환 허용 (KU-3 W7.5에서 실측).

## ✅ 완료 기준

1. T-W7-01 frontmatter 6 필드 yq 파싱 통과
2. T-W7-02 orchestrate-pipeline.sh shellcheck + 4축 stub end-to-end 1회 성공
3. T-W7-03 cursor-bucket-ui.sh 6 bucket 전이 시뮬레이션 성공
4. T-W7-04 3 허용 조합 각 1회 성공 + 미허용 조합 에러 처리
5. T-W7-05 experiment-log.yaml CP-0~CP-5 6개 기록
6. T-W7-06 test-orchestrate-pipeline.sh 1회 PASS
7. 체크박스 T-W7-01·02·03·04·05·06 업데이트
8. 자체 커밋+푸시 (중간 커밋 허용, 최종 1회 push)

---

## 🔄 자동 커밋+푸시 (태스크 종료 시점)

```bash
cd /Users/ethan/Desktop/personal/harness

git pull --rebase origin main || { echo "pull failed"; exit 1; }

sed -i '' \
  -e 's|^- \[ \] \*\*T-W7-01\*\*|- [x] **T-W7-01**|' \
  -e 's|^- \[ \] \*\*T-W7-02\*\*|- [x] **T-W7-02**|' \
  -e 's|^- \[ \] \*\*T-W7-03\*\*|- [x] **T-W7-03**|' \
  -e 's|^- \[ \] \*\*T-W7-04\*\*|- [x] **T-W7-04**|' \
  -e 's|^- \[ \] \*\*T-W7-05\*\*|- [x] **T-W7-05**|' \
  -e 's|^- \[ \] \*\*T-W7-06\*\*|- [x] **T-W7-06**|' \
  .claude/plans/04-planning/implementation-plan.md

git add skills/orchestrate/ scripts/orchestrate-pipeline.sh scripts/cursor-bucket-ui.sh scripts/orchestrate-three-axis.sh scripts/orchestrate-checkpoint.sh __tests__/integration/test-orchestrate-pipeline.sh .claude/plans/04-planning/implementation-plan.md

git commit -s -m "$(cat <<'EOF'
feat(W7): T-W7-01~06 /orchestrate [Stretch] 4축 통합 파이프라인

- skills/orchestrate/SKILL.md: 4축 순차 파이프라인 + frontmatter 6필드 (AC-Stretch-1)
- scripts/orchestrate-pipeline.sh: /brainstorm→/plan→/verify→/compound 파이프라인
- scripts/cursor-bucket-ui.sh: 6 bucket 진행 시각화 (포팅 #12)
- scripts/orchestrate-three-axis.sh: dispatch×work×verify 3 조합 (포팅 #16)
- scripts/orchestrate-checkpoint.sh: CP-0~CP-5 experiment-log.yaml (포팅 #17)
- __tests__/integration/test-orchestrate-pipeline.sh: 4축 end-to-end unit test
- Stretch 특성: stub 반환 허용, 실측은 KU-3(W7.5) 이월
EOF
)"

for attempt in 1 2 3; do
  if git push origin main; then break; fi
  if [ "$attempt" -eq 3 ]; then echo "push failed 3x, abort"; exit 1; fi
  git fetch origin main
  git rebase origin/main || { echo "rebase conflict, abort"; exit 1; }
done
```

## 🛑 금지

- `skills/brainstorm/`, `skills/plan/`, `skills/verify/`, `skills/compound/` 본문 수정 (read-only 참조만 — 인터페이스 변경 없음)
- final-spec · implementation-plan(체크박스 외) 수정
- `.claude/memory/` 직접 쓰기 (승격 게이트 경유 원칙 유지)
- Python/Node 사용
- W7.5 선수행 (KU-3는 W7.5에서)
- push 3회 실패 시 중단

시작하세요.

#!/usr/bin/env bash
# scripts/orchestrate-pipeline.sh — T-W7-02 · /orchestrate 본체 드라이버
#
# 4축 통합 파이프라인 (Brainstorm → Plan → Verify → Compound) + Finalize.
# MVP 는 각 축 실제 LLM 호출 대신 **stub 반환 허용** (v3.3 §10.2 Stretch).
# 체크포인트 기록은 scripts/orchestrate-checkpoint.sh 를 source 해 사용한다.
#
# 사용법:
#   orchestrate-pipeline.sh [options] <topic>
#
# 옵션:
#   --skip-axis <n>      n=1..4 스킵 (반복 지정 가능)
#   --resume <run_id>    기존 run 디렉토리에서 재개 (마지막 done CP 다음부터)
#   --state-root <dir>   기본 .claude/state/orchestrate
#   --stub               모든 축 stub 으로 강제 (ORCH_STUB=1 동등)
#   -h | --help          도움말
#
# 환경 변수:
#   ORCH_DISPATCH, ORCH_WORK, ORCH_VERIFY — 3-Axis 조합 (three-axis.sh 에서 주입)
#   ORCH_STUB=1 — 모든 축 stub 으로 강제 (기본: 1, 실 호출은 W7.5)
#
# 출력 (stdout):
#   실행 종료 시 단일 JSON 요약 1줄:
#     {"run_id":"...","status":"done|partial|failed","artifacts":[...]}
#
# 종료 코드:
#   0 — 정상 종료 (skipped/failed 축이 있어도 CP-5 까지 기록되면 0)
#   1 — 입력 오류
#   2 — 런타임 의존성 부재
#   3 — 중대한 파이프라인 실패 (CP-5 도 기록 못함)
#   4 — CP-5 자체 기록 실패

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- 의존성 ------------------------------------------------------------------

for bin in jq yq uuidgen; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Error: $bin is required (brew install $bin)" >&2
    exit 2
  fi
done

# shellcheck source=scripts/orchestrate-checkpoint.sh
. "${SCRIPT_DIR}/orchestrate-checkpoint.sh"

# --- 기본값 & 인자 파싱 --------------------------------------------------------

STATE_ROOT="${REPO_ROOT}/.claude/state/orchestrate"
SKIP_AXES=()
RESUME_ID=""
TOPIC=""
STUB_MODE="${ORCH_STUB:-1}"  # 기본 stub (Stretch 특성)

DISPATCH="${ORCH_DISPATCH:-sequential}"
WORK="${ORCH_WORK:-fresh-context}"
VERIFY_MODE="${ORCH_VERIFY:-strict}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-axis)  SKIP_AXES+=("${2:-}"); shift 2 ;;
    --resume)     RESUME_ID="${2:-}"; shift 2 ;;
    --state-root) STATE_ROOT="${2:-}"; shift 2 ;;
    --stub)       STUB_MODE=1; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" >&2
      exit 0
      ;;
    -*)
      echo "Error: unknown flag: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$TOPIC" ]]; then
        TOPIC="$1"
      else
        TOPIC="$TOPIC $1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$TOPIC" && -z "$RESUME_ID" ]]; then
  echo "Error: topic required (or --resume <run_id>)" >&2
  exit 1
fi

# skip-axis 숫자 검증
for n in "${SKIP_AXES[@]:-}"; do
  [[ -z "$n" ]] && continue
  case "$n" in
    1|2|3|4) ;;
    *) echo "Error: --skip-axis must be 1..4, got: $n" >&2; exit 1 ;;
  esac
done

# STATE_ROOT slug 검증 불필요 (내부 고정 경로) — run_id 만 검증
mkdir -p "$STATE_ROOT"

# --- run_id 결정 & 디렉토리 준비 -----------------------------------------------

if [[ -n "$RESUME_ID" ]]; then
  if [[ ! "$RESUME_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: invalid run_id: $RESUME_ID" >&2
    exit 1
  fi
  RUN_ID="$RESUME_ID"
  RUN_DIR="${STATE_ROOT}/${RUN_ID}"
  if [[ ! -s "${RUN_DIR}/experiment-log.yaml" ]]; then
    echo "Error: cannot resume — no experiment-log.yaml at $RUN_DIR" >&2
    exit 1
  fi
  # topic 복원
  if [[ -z "$TOPIC" ]]; then
    TOPIC="$(yq eval '.topic' "${RUN_DIR}/experiment-log.yaml")"
  fi
else
  RUN_ID="run-$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-12)"
  RUN_DIR="${STATE_ROOT}/${RUN_ID}"
  mkdir -p "$RUN_DIR"
fi

mkdir -p "${RUN_DIR}/01-brainstorm" \
         "${RUN_DIR}/02-plan" \
         "${RUN_DIR}/03-verify" \
         "${RUN_DIR}/04-compound"

# --- 축 skip 조회 헬퍼 --------------------------------------------------------

is_skipped() {
  local n="$1"
  for s in "${SKIP_AXES[@]:-}"; do
    [[ "$s" == "$n" ]] && return 0
  done
  return 1
}

# CP 가 이미 done/skipped 로 기록돼 있으면 true (resume)
already_done() {
  local cp="$1"
  local s
  s="$(cp_get "$RUN_DIR" "$cp" .status 2>/dev/null || true)"
  [[ "$s" == "done" || "$s" == "skipped" ]]
}

log_info() {
  printf '%s[orchestrate]%s %s\n' $'\033[34m' $'\033[0m' "$*" >&2
}

# --- CP-0 Intake ---------------------------------------------------------------

SKIP_CSV="$(IFS=,; echo "${SKIP_AXES[*]:-}")"
DISPATCH_MODE="${DISPATCH}×${WORK}×${VERIFY_MODE}"

if ! already_done CP-0; then
  cp_init "$RUN_DIR" "$TOPIC" "$SKIP_CSV" "$DISPATCH_MODE"
  log_info "CP-0 recorded (run_id=$RUN_ID, topic=$TOPIC)"
fi

# --- Phase 1: Brainstorm (CP-1) -----------------------------------------------

run_brainstorm_stub() {
  local out="${RUN_DIR}/01-brainstorm/requirements.md"
  cat >"$out" <<EOF
# Requirements (stub)

Topic: ${TOPIC}

- [stub] MVP placeholder: 실제 /brainstorm 호출은 W7.5 (KU-3) 에서 실측.
- 생성 경로: ${out}
- 3-Axis: ${DISPATCH_MODE}
EOF
  printf '%s' "$out"
}

phase1_brainstorm() {
  if already_done CP-1; then
    log_info "CP-1 already done (resume)"
    return 0
  fi
  if is_skipped 1; then
    cp_write "$RUN_DIR" CP-1 skipped '{"reason":"--skip-axis 1"}'
    log_info "CP-1 skipped"
    return 0
  fi

  local started completed path
  started="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if [[ "$STUB_MODE" -eq 1 ]]; then
    path="$(run_brainstorm_stub)"
  else
    # 실제 skill 호출 hook (W7.5) — 현재는 stub 과 동일
    path="$(run_brainstorm_stub)"
  fi
  completed="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local data
  data="$(jq -n \
    --arg p "$path" \
    --arg s "$started" \
    --arg c "$completed" \
    '{requirements_path: $p, turn_count: 0, started_at: $s, completed_at: $c}')"
  cp_write "$RUN_DIR" CP-1 "done" "$data"
  log_info "CP-1 done ($path)"
}

# --- Phase 2: Plan (CP-2) -----------------------------------------------------

run_plan_stub() {
  local out="${RUN_DIR}/02-plan/impl-plan.md"
  cat >"$out" <<EOF
# Implementation Plan (stub)

Topic: ${TOPIC}

- [stub] task_count=0 placeholder.
- Source: 01-brainstorm/requirements.md
EOF
  printf '%s' "$out"
}

phase2_plan() {
  if already_done CP-2; then
    log_info "CP-2 already done (resume)"
    return 0
  fi
  if is_skipped 2; then
    cp_write "$RUN_DIR" CP-2 skipped '{"reason":"--skip-axis 2"}'
    log_info "CP-2 skipped"
    return 0
  fi

  local path completed
  path="$(run_plan_stub)"
  completed="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local data
  data="$(jq -n --arg p "$path" --arg c "$completed" \
    '{plan_path: $p, task_count: 0, completed_at: $c}')"
  cp_write "$RUN_DIR" CP-2 "done" "$data"
  log_info "CP-2 done ($path)"
}

# --- Phase 3: Verify (CP-3) ---------------------------------------------------

run_verify_stub() {
  local out="${RUN_DIR}/03-verify/qa-score.json"
  local score=0.75
  local verdict="pass"
  if [[ "$VERIFY_MODE" == "skip" ]]; then
    score=null
    verdict="skipped"
  elif [[ "$VERIFY_MODE" == "lenient" ]]; then
    score=0.55
    verdict="pass"
  fi
  jq -n \
    --argjson score "$score" \
    --arg verdict "$verdict" \
    '{score: $score, verdict: $verdict, ralph_loop_iterations: 0, stub: true}' \
    >"$out"
  printf '%s' "$out"
}

phase3_verify() {
  if already_done CP-3; then
    log_info "CP-3 already done (resume)"
    return 0
  fi
  if is_skipped 3; then
    cp_write "$RUN_DIR" CP-3 skipped '{"reason":"--skip-axis 3","qa_score":null}'
    log_info "CP-3 skipped"
    return 0
  fi

  local path completed
  path="$(run_verify_stub)"
  completed="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local score verdict iters
  score="$(jq -r '.score // 0' "$path")"
  verdict="$(jq -r '.verdict' "$path")"
  iters="$(jq -r '.ralph_loop_iterations' "$path")"

  local data
  data="$(jq -n \
    --arg path "$path" \
    --argjson score "${score:-0}" \
    --arg verdict "$verdict" \
    --argjson iters "${iters:-0}" \
    --arg c "$completed" \
    '{qa_score: $score, verdict: $verdict, ralph_loop_iterations: $iters,
      qa_path: $path, completed_at: $c}')"
  cp_write "$RUN_DIR" CP-3 "done" "$data"
  log_info "CP-3 done (score=$score, verdict=$verdict)"

  # 점수 < 0.40 → Phase 4 거부 플래그
  if [[ "$verdict" != "skipped" ]]; then
    local low
    low="$(jq -n --argjson s "${score:-0}" '$s < 0.40')"
    if [[ "$low" == "true" ]]; then
      log_info "CP-3 qa_score below threshold (< 0.40) — halting before CP-4"
      return 10
    fi
  fi
}

# --- Phase 4: Compound (CP-4) -------------------------------------------------

run_compound_stub() {
  local out="${RUN_DIR}/04-compound/promotion-queue.yaml"
  cat >"$out" <<EOF
run_id: ${RUN_ID}
topic: "${TOPIC}"
promoted: []
rejected: []
stub: true
EOF
  printf '%s' "$out"
}

phase4_compound() {
  if already_done CP-4; then
    log_info "CP-4 already done (resume)"
    return 0
  fi
  if is_skipped 4; then
    cp_write "$RUN_DIR" CP-4 skipped '{"reason":"--skip-axis 4","promoted_count":0,"rejected_count":0}'
    log_info "CP-4 skipped"
    return 0
  fi

  local path completed
  path="$(run_compound_stub)"
  completed="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local data
  data="$(jq -n --arg p "$path" --arg c "$completed" \
    '{promoted_count: 0, rejected_count: 0, queue_path: $p, completed_at: $c}')"
  cp_write "$RUN_DIR" CP-4 "done" "$data"
  log_info "CP-4 done ($path)"
}

# --- Phase 5: Finalize (CP-5) -------------------------------------------------

phase5_finalize() {
  local overall_status="$1"
  local completed
  completed="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # started_at 에서 경과 초 계산
  local started
  started="$(yq eval '.started_at' "${RUN_DIR}/experiment-log.yaml")"
  local total=0
  if [[ -n "$started" && "$started" != "null" ]]; then
    # GNU date 와 BSD date 양쪽에서 동작하도록 안전 파싱
    local start_epoch end_epoch
    start_epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" +%s 2>/dev/null \
                || date -u -d "$started" +%s 2>/dev/null || echo 0)"
    end_epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$completed" +%s 2>/dev/null \
                || date -u -d "$completed" +%s 2>/dev/null || echo 0)"
    if [[ "$start_epoch" -gt 0 && "$end_epoch" -gt 0 ]]; then
      total=$((end_epoch - start_epoch))
    fi
  fi

  # 산출물 경로 수집
  local artifacts_json
  artifacts_json="$(jq -n \
    --arg b "${RUN_DIR}/01-brainstorm/requirements.md" \
    --arg p "${RUN_DIR}/02-plan/impl-plan.md" \
    --arg v "${RUN_DIR}/03-verify/qa-score.json" \
    --arg c "${RUN_DIR}/04-compound/promotion-queue.yaml" \
    '[$b,$p,$v,$c] | map(select(. != ""))')"

  local data
  data="$(jq -n \
    --argjson total "$total" \
    --argjson arts "$artifacts_json" \
    --arg c "$completed" \
    --arg overall "$overall_status" \
    '{total_duration_sec: $total, artifacts_paths: $arts,
      overall_status: $overall, completed_at: $c}')"
  cp_write "$RUN_DIR" CP-5 "done" "$data"
  log_info "CP-5 done (duration=${total}s, status=$overall_status)"
}

# --- 파이프라인 오케스트레이션 (sequential dispatch) --------------------------

overall="done"
halted=0

for phase in phase1_brainstorm phase2_plan phase3_verify phase4_compound; do
  set +e
  "$phase"
  rc=$?
  set -e
  if [[ "$rc" -eq 10 ]]; then
    # qa_score < 0.40 → halt 전 CP-4 는 건너뛰고 CP-5 마무리
    overall="halted"
    halted=1
    break
  elif [[ "$rc" -ne 0 ]]; then
    overall="failed"
    halted=1
    log_info "phase failed: $phase (rc=$rc)"
    break
  fi
done

# CP-5 는 언제나 기록 (halted/failed 도 total summary 남김)
set +e
phase5_finalize "$overall"
cp5_rc=$?
set -e
if [[ "$cp5_rc" -ne 0 ]]; then
  echo "Error: CP-5 write failed (rc=$cp5_rc)" >&2
  exit 4
fi

# --- stdout JSON 요약 ---------------------------------------------------------

summary_artifacts="$(jq -n \
  --arg b "${RUN_DIR}/01-brainstorm/requirements.md" \
  --arg p "${RUN_DIR}/02-plan/impl-plan.md" \
  --arg v "${RUN_DIR}/03-verify/qa-score.json" \
  --arg c "${RUN_DIR}/04-compound/promotion-queue.yaml" \
  '[$b,$p,$v,$c]')"

jq -cn \
  --arg run_id "$RUN_ID" \
  --arg status "$overall" \
  --arg topic "$TOPIC" \
  --arg dir "$RUN_DIR" \
  --argjson arts "$summary_artifacts" \
  '{run_id:$run_id, status:$status, topic:$topic, run_dir:$dir, artifacts:$arts}'

if [[ "$halted" -eq 1 && "$overall" == "failed" ]]; then
  exit 3
fi
exit 0

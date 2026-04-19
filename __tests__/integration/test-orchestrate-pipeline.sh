#!/usr/bin/env bash
# __tests__/integration/test-orchestrate-pipeline.sh — T-W7-06
#
# /orchestrate 4축 end-to-end 통합 테스트 (Stretch, stub 허용).
#
# 검증 항목:
#   1. orchestrate-pipeline.sh 가 단일 주제로 end-to-end 1회 성공 (stub)
#   2. experiment-log.yaml 에 CP-0 ~ CP-5 가 모두 기록
#   3. 01-brainstorm / 02-plan / 03-verify / 04-compound 디렉토리 각각
#      최소 1개 산출물 존재
#   4. cursor-bucket-ui.sh 가 "[✓] CP-5 Finalize" 를 포함해 렌더
#   5. 3-Axis 허용 조합 1개(lazy × hybrid × skip) 실행 성공
#   6. CP 순서 위반(CP-4 before CP-3) 거부
#
# 사용법:
#   __tests__/integration/test-orchestrate-pipeline.sh
#
# 종료 코드:
#   0 — 모든 assertion PASS
#   1 — 하나 이상 FAIL (실패 CP 또는 항목 명시)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PIPELINE="scripts/orchestrate-pipeline.sh"
UI="scripts/cursor-bucket-ui.sh"
THREE_AXIS="scripts/orchestrate-three-axis.sh"
CHECKPOINT="scripts/orchestrate-checkpoint.sh"

for f in "$PIPELINE" "$UI" "$THREE_AXIS" "$CHECKPOINT"; do
  if [[ ! -x "$f" ]]; then
    echo "FAIL: prerequisite missing or not executable: $f" >&2
    exit 1
  fi
done

TMPDIR="$(mktemp -d -t orch-e2e.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

fail=0
fail_details=""

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  PASS: %s\n' "$label"
  else
    fail=1
    fail_details="${fail_details}  FAIL: ${label} (expected='${expected}' actual='${actual}')"$'\n'
    printf '  FAIL: %s (expected=%s actual=%s)\n' "$label" "$expected" "$actual"
  fi
}

assert_file_nonempty() {
  local label="$1" path="$2"
  if [[ -s "$path" ]]; then
    printf '  PASS: %s (%s)\n' "$label" "$path"
  else
    fail=1
    fail_details="${fail_details}  FAIL: ${label} missing or empty: ${path}"$'\n'
    printf '  FAIL: %s missing or empty: %s\n' "$label" "$path"
  fi
}

assert_dir_has_files() {
  local label="$1" dir="$2"
  local count
  count="$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$count" -ge 1 ]]; then
    printf '  PASS: %s (%d files in %s)\n' "$label" "$count" "$dir"
  else
    fail=1
    fail_details="${fail_details}  FAIL: ${label} ${dir} has 0 files"$'\n'
    printf '  FAIL: %s has 0 files: %s\n' "$label" "$dir"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf '  PASS: %s\n' "$label"
  else
    fail=1
    fail_details="${fail_details}  FAIL: ${label} — missing substring '${needle}'"$'\n'
    printf '  FAIL: %s — missing substring: %s\n' "$label" "$needle"
  fi
}

# =========================================================================
# Case A — 기본 sequential × fresh-context × strict 조합으로 end-to-end
# =========================================================================
echo "== Case A: default 3-Axis end-to-end =="

STATE_A="$TMPDIR/state-a"
mkdir -p "$STATE_A"

set +e
SUMMARY_A="$("$PIPELINE" --state-root "$STATE_A" "add error boundary component" 2>"$TMPDIR/a.stderr")"
rc_a=$?
set -e

assert_eq "A.exit" "0" "$rc_a"
assert_contains "A.summary.status=done" '"status":"done"' "$SUMMARY_A"

RUN_A="$(ls -d "$STATE_A"/run-* 2>/dev/null | head -1)"
if [[ -z "$RUN_A" ]]; then
  fail=1
  fail_details="${fail_details}  FAIL: A.run_dir not created"$'\n'
  echo "  FAIL: A.run_dir not created"
fi

LOG_A="$RUN_A/experiment-log.yaml"
assert_file_nonempty "A.experiment-log" "$LOG_A"

# 6개 체크포인트 모두 status=done
for cp in CP-0 CP-1 CP-2 CP-3 CP-4 CP-5; do
  status="$(yq eval ".checkpoints.\"$cp\".status // \"\"" "$LOG_A")"
  assert_eq "A.$cp.status" "done" "$status"
done

# 4 디렉토리에 산출물 ≥ 1
assert_dir_has_files "A.01-brainstorm" "$RUN_A/01-brainstorm"
assert_dir_has_files "A.02-plan"       "$RUN_A/02-plan"
assert_dir_has_files "A.03-verify"     "$RUN_A/03-verify"
assert_dir_has_files "A.04-compound"   "$RUN_A/04-compound"

# cursor UI 렌더에 CP-5 done 표기
UI_OUT="$("$UI" --no-color "$RUN_A")"
assert_contains "A.ui.cp5-done" "CP-5 Finalize" "$UI_OUT"
assert_contains "A.ui.cp5-done-status" "(done)" "$UI_OUT"

# =========================================================================
# Case B — 3-Axis 허용 조합(lazy × hybrid × skip) 통과
# =========================================================================
echo ""
echo "== Case B: 3-Axis (lazy × hybrid × skip) =="

STATE_B="$TMPDIR/state-b"
mkdir -p "$STATE_B"

set +e
SUMMARY_B="$("$THREE_AXIS" \
  --axis dispatch=lazy,work=hybrid,verify=skip \
  -- --state-root "$STATE_B" "debug-mode topic" 2>"$TMPDIR/b.stderr")"
rc_b=$?
set -e

assert_eq "B.exit" "0" "$rc_b"
assert_contains "B.summary.status=done" '"status":"done"' "$SUMMARY_B"

RUN_B="$(ls -d "$STATE_B"/run-* 2>/dev/null | head -1)"
assert_file_nonempty "B.experiment-log" "$RUN_B/experiment-log.yaml"

# dispatch_mode 필드에 선택한 조합이 기록
DISP_B="$(yq eval '.dispatch_mode' "$RUN_B/experiment-log.yaml")"
assert_eq "B.dispatch_mode" "lazy×hybrid×skip" "$DISP_B"

# =========================================================================
# Case C — 미허용 조합 거부
# =========================================================================
echo ""
echo "== Case C: disallowed 3-Axis combination =="

set +e
"$THREE_AXIS" --validate-only \
  --axis dispatch=sequential,work=hybrid,verify=strict >/dev/null 2>"$TMPDIR/c.stderr"
rc_c=$?
set -e
assert_eq "C.exit-nonzero" "1" "$rc_c"
ERR_C="$(cat "$TMPDIR/c.stderr")"
assert_contains "C.err.disallowed" "disallowed 3-Axis combination" "$ERR_C"

# =========================================================================
# Case D — CP 순서 위반 거부 (CP-4 before CP-3)
# =========================================================================
echo ""
echo "== Case D: CP order violation rejected =="

STATE_D="$TMPDIR/state-d"
mkdir -p "$STATE_D/run-order-test"
"$CHECKPOINT" init "$STATE_D/run-order-test" "order test" >/dev/null
"$CHECKPOINT" write "$STATE_D/run-order-test" CP-1 "done" '{}' >/dev/null
"$CHECKPOINT" write "$STATE_D/run-order-test" CP-2 "done" '{}' >/dev/null

set +e
"$CHECKPOINT" write "$STATE_D/run-order-test" CP-4 "done" '{}' 2>"$TMPDIR/d.stderr"
rc_d=$?
set -e
assert_eq "D.exit-nonzero" "3" "$rc_d"
ERR_D="$(cat "$TMPDIR/d.stderr")"
assert_contains "D.err.out-of-order" "out-of-order" "$ERR_D"

# =========================================================================
# Summary
# =========================================================================
echo ""
echo "==============================================="
if [[ "$fail" -eq 0 ]]; then
  echo "ALL PASS — /orchestrate 4축 파이프라인 end-to-end 검증 성공"
  exit 0
else
  echo "FAIL — 아래 항목 확인:"
  printf '%s' "$fail_details"
  exit 1
fi

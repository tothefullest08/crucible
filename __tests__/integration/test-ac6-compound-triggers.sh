#!/usr/bin/env bash
# __tests__/integration/test-ac6-compound-triggers.sh — T-W6-08 → AC-6
#
# 3 compound 트리거(user_correction · pattern_repeat · session_wrap) 각 ≥ 1건
# 실측 smoke 테스트. MVP 스코프는 "검출 발생 여부" 만 확인하며, 정확도
# 엄밀 측정은 KU-3 (W7.5) 에서 진행한다 (final-spec v3.3 §11 · KU-3).
#
# 사용법:
#   __tests__/integration/test-ac6-compound-triggers.sh
#   (exit 0 = AC-6 PASS,  exit 1 = FAIL)
#
# 안전:
#   set -euo pipefail, tmpdir 격리, 레포 내 파일 수정 없음 (HARNESS_STATE_ROOT
#   을 tmpdir 로 오버라이드).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FIX_CORR="__tests__/fixtures/correction-detector-w6/01-kr-valid.json"
FIX_PAT="__tests__/fixtures/pattern-repeat/01-three-repeats.jsonl"

for f in "$FIX_CORR" "$FIX_PAT" \
         hooks/correction-detector.sh scripts/pattern-repeat-detector.sh hooks/stop.sh; do
    if [[ ! -e "$f" ]]; then
        echo "FAIL: missing prerequisite: $f" >&2
        exit 1
    fi
done

TMPDIR="$(mktemp -d -t ac6.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/memory"

STATE_ROOT="$TMPDIR"
QUEUE_DIR="$TMPDIR/promotion_queue"

fail=0
detail=""

# ----------------------------------------------------------------------------
# Trigger 1 — user_correction (UserPromptSubmit + PostToolUse fallback)
# ----------------------------------------------------------------------------

HARNESS_STATE_ROOT="$STATE_ROOT" \
    hooks/correction-detector.sh < "$FIX_CORR" > /dev/null

correction_yamls=0
if [[ -d "$QUEUE_DIR" ]]; then
    for y in "$QUEUE_DIR"/*.yaml; do
        [[ -e "$y" ]] || continue
        ts="$(yq -r '.trigger_source' "$y")"
        [[ "$ts" == "user_correction" ]] && correction_yamls=$((correction_yamls + 1))
    done
fi

if [[ "$correction_yamls" -lt 1 ]]; then
    fail=1
    detail+="  - user_correction: expected >=1 candidate, got $correction_yamls\n"
fi

# ----------------------------------------------------------------------------
# Trigger 2 — pattern_repeat
# ----------------------------------------------------------------------------

HARNESS_STATE_ROOT="$STATE_ROOT" \
    scripts/pattern-repeat-detector.sh "$FIX_PAT" > /dev/null 2>&1

pattern_yamls=0
for y in "$QUEUE_DIR"/*.yaml; do
    [[ -e "$y" ]] || continue
    ts="$(yq -r '.trigger_source' "$y")"
    [[ "$ts" == "pattern_repeat" ]] && pattern_yamls=$((pattern_yamls + 1))
done

if [[ "$pattern_yamls" -lt 1 ]]; then
    fail=1
    detail+="  - pattern_repeat: expected >=1 candidate, got $pattern_yamls\n"
fi

# ----------------------------------------------------------------------------
# Trigger 3 — session_wrap (manual /session-wrap invocation → stop.sh pipeline)
# ----------------------------------------------------------------------------

session_wrap_output="$(hooks/stop.sh \
    --memory-root "$TMPDIR/memory" \
    --state-root  "$STATE_ROOT" \
    --response    N \
    2>/dev/null)"

summary_line="$(printf '%s\n' "$session_wrap_output" | tail -1)"
processed="$(printf '%s' "$summary_line" | jq -r '.summary.processed // 0')"

if [[ "$processed" -lt 2 ]]; then
    fail=1
    detail+="  - session_wrap: expected processed>=2, got $processed (summary=$summary_line)\n"
fi

# ----------------------------------------------------------------------------
# Verdict
# ----------------------------------------------------------------------------

if [[ "$fail" -eq 0 ]]; then
    printf 'AC-6 PASS  user_correction=%d pattern_repeat=%d session_wrap_processed=%d\n' \
        "$correction_yamls" "$pattern_yamls" "$processed"
    exit 0
else
    printf 'AC-6 FAIL\n' >&2
    printf '%b' "$detail" >&2
    exit 1
fi

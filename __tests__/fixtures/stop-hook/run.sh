#!/usr/bin/env bash
# __tests__/fixtures/stop-hook/run.sh — T-W5-07 검증 러너
#
# 3건의 같은 detector_id 를 가진 후보를 promotion_queue 에 배치하고
# hooks/stop.sh 를 --response N (일괄 거부) 로 실행 후
# detector-status.json 에 disabled_until 이 7일 후로 설정되는지 검증.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STOP="${REPO_ROOT}/hooks/stop.sh"
FX="${REPO_ROOT}/__tests__/fixtures/stop-hook"

WORK="$(mktemp -d -t stop-hook-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

MEMORY="${WORK}/memory"
STATE="${WORK}/state"
QUEUE="${STATE}/promotion_queue"
mkdir -p "$MEMORY" "$QUEUE"

cp "${FX}/01-same-pattern.yaml" "${QUEUE}/"
cp "${FX}/02-same-pattern.yaml" "${QUEUE}/"
cp "${FX}/03-same-pattern.yaml" "${QUEUE}/"

echo "=== Pre: queue files ==="
find "$QUEUE" -maxdepth 1 -name '*.yaml' | LC_ALL=C sort

echo ""
echo "=== Run stop.sh --response N ==="
"$STOP" --memory-root "$MEMORY" --state-root "$STATE" --response N

STATUS_FILE="${STATE}/detector-status.json"

pass=0
fail=0

assert_eq() {
  if [[ "$2" == "$3" ]]; then
    printf '  ✓ %s = %s\n' "$1" "$3"
    pass=$((pass + 1))
  else
    printf '  ✗ %s expected=%s actual=%s\n' "$1" "$3" "$2"
    fail=$((fail + 1))
  fi
}

echo ""
echo "=== Verify detector-status.json ==="
cat "$STATUS_FILE"
echo ""

detector_id="pattern_repeat:coroutine-scope"
rejects="$(jq -r --arg d "$detector_id" '.detectors[$d].consecutive_rejects' "$STATUS_FILE")"
disabled_until="$(jq -r --arg d "$detector_id" '.detectors[$d].disabled_until' "$STATUS_FILE")"

assert_eq "consecutive_rejects" "$rejects" "3"

if [[ -z "$disabled_until" || "$disabled_until" == "null" ]]; then
  echo "  ✗ disabled_until is null/empty"
  fail=$((fail + 1))
else
  echo "  ✓ disabled_until set: $disabled_until"
  pass=$((pass + 1))

  # ISO8601 → epoch (macOS / linux 호환)
  if date -j -f '%Y-%m-%dT%H:%M:%SZ' "$disabled_until" +%s >/dev/null 2>&1; then
    du_epoch="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$disabled_until" +%s)"
  else
    du_epoch="$(date -u -d "$disabled_until" +%s)"
  fi
  now_epoch="$(date -u +%s)"
  diff_days=$(( (du_epoch - now_epoch) / 86400 ))
  # 7일 ± 허용 (실행 시점 시차 흡수)
  if [[ "$diff_days" -ge 6 && "$diff_days" -le 8 ]]; then
    echo "  ✓ disabled_until ≈ now + 7d (diff_days=$diff_days)"
    pass=$((pass + 1))
  else
    echo "  ✗ disabled_until delta out of range: $diff_days days"
    fail=$((fail + 1))
  fi
fi

# 3 후보 파일 전부 큐에서 제거되었는지 확인 (거부 완료)
remaining="$(find "$QUEUE" -maxdepth 1 -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "queue remaining" "$remaining" "0"

# _rejections.log 에 3 라인 있는지 확인
LOG="${MEMORY}/corrections/_rejections.log"
if [[ -f "$LOG" ]]; then
  lines="$(wc -l < "$LOG" | tr -d ' ')"
  assert_eq "_rejections.log line count" "$lines" "3"
else
  echo "  ✗ _rejections.log missing"
  fail=$((fail + 1))
fi

echo ""
printf 'Summary: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

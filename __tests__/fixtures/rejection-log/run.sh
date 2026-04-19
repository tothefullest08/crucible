#!/usr/bin/env bash
# __tests__/fixtures/rejection-log/run.sh — T-W5-08 검증 러너
#
# 3 후보를 거부하여 다음을 검증:
#   1. `_rejected/<candidate_id>.md` 3 파일 생성
#   2. `_rejections.log` 3 라인 (ISO ts + detector_id + pattern_hash)
#   3. 각 라인이 형식에 맞는지 regex 매칭
#
# promotion-gate.sh 를 직접 호출 (stop.sh 는 T-W5-07 에서 검증).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="${REPO_ROOT}/scripts/promotion-gate.sh"
FX="${REPO_ROOT}/__tests__/fixtures/rejection-log"

WORK="$(mktemp -d -t rejlog-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

MEMORY="${WORK}/memory"
STATE="${WORK}/state"
mkdir -p "$MEMORY" "$STATE"

pass=0
fail=0

echo "=== Reject 3 candidates via promotion-gate --response N ==="
for f in "${FX}/01-reject-a.yaml" "${FX}/02-reject-b.yaml" "${FX}/03-reject-c.yaml"; do
  "$GATE" "$f" --memory-root "$MEMORY" --state-root "$STATE" \
    --response N --evaluator-score 0.20 2>/dev/null
done

REJ_DIR="${MEMORY}/corrections/_rejected"
LOG="${MEMORY}/corrections/_rejections.log"

echo ""
echo "=== Verify _rejected/ files ==="
rej_count="$(find "$REJ_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$rej_count" == "3" ]]; then
  printf '  ✓ 3 rejected files in %s\n' "$REJ_DIR"
  pass=$((pass + 1))
else
  printf '  ✗ expected 3 rejected files, got %s\n' "$rej_count"
  fail=$((fail + 1))
fi

# 각 파일의 frontmatter 확인
for cid in 20000001-0000-4000-8000-0000000000a1 20000002-0000-4000-8000-0000000000b2 20000003-0000-4000-8000-0000000000c3; do
  file="${REJ_DIR}/${cid}.md"
  if [[ -f "$file" ]] && grep -q 'rejection_source: user_reject' "$file"; then
    printf '  ✓ %s frontmatter OK\n' "$cid"
    pass=$((pass + 1))
  else
    printf '  ✗ %s frontmatter missing or file absent\n' "$cid"
    fail=$((fail + 1))
  fi
done

echo ""
echo "=== Verify _rejections.log ==="
if [[ ! -f "$LOG" ]]; then
  echo "  ✗ log file missing"
  fail=$((fail + 1))
else
  echo "  log contents:"
  sed 's/^/    /' "$LOG"
  log_lines="$(wc -l < "$LOG" | tr -d ' ')"
  if [[ "$log_lines" == "3" ]]; then
    printf '  ✓ log has 3 lines\n'
    pass=$((pass + 1))
  else
    printf '  ✗ expected 3 log lines, got %s\n' "$log_lines"
    fail=$((fail + 1))
  fi

  # 각 라인 포맷: ISO8601 + space + detector_id + space + pattern_hash
  regex='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z [a-z_]+:[a-z0-9_-]+ [a-f0-9-]{12}$'
  while IFS= read -r line; do
    if [[ "$line" =~ $regex ]]; then
      printf '  ✓ line format OK: %s\n' "$line"
      pass=$((pass + 1))
    else
      printf '  ✗ line format BAD: %s\n' "$line"
      fail=$((fail + 1))
    fi
  done < "$LOG"

  # 각 detector 가 로그에 등장하는지
  for d in user_correction:eslint-override pattern_repeat:webpack-alias session_wrap:tsconfig-strict; do
    if grep -qF "$d" "$LOG"; then
      printf '  ✓ detector present: %s\n' "$d"
      pass=$((pass + 1))
    else
      printf '  ✗ detector missing in log: %s\n' "$d"
      fail=$((fail + 1))
    fi
  done
fi

echo ""
printf 'Summary: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

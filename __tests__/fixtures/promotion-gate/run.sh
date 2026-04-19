#!/usr/bin/env bash
# __tests__/fixtures/promotion-gate/run.sh — T-W5-06 검증 러너
#
# 4 응답 시나리오 (y/N/e/s) 로 promotion-gate.sh 를 실행하여
# 저장/거부/편집/스킵 동작을 실측.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="${REPO_ROOT}/scripts/promotion-gate.sh"
FX="${REPO_ROOT}/__tests__/fixtures/promotion-gate"

# 임시 워크스페이스 (실제 memory 는 건드리지 않음)
WORK="$(mktemp -d -t gate-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

MEMORY="${WORK}/memory"
STATE="${WORK}/state"
mkdir -p "$MEMORY" "$STATE"

pass=0
fail=0

assert_file() {
  local label="$1" file="$2"
  if [[ -f "$file" ]]; then
    printf '  ✓ %s present: %s\n' "$label" "$file"
    pass=$((pass + 1))
  else
    printf '  ✗ %s MISSING: %s\n' "$label" "$file"
    fail=$((fail + 1))
  fi
}

assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    printf '  ✓ %s = %s\n' "$label" "$expected"
    pass=$((pass + 1))
  else
    printf '  ✗ %s expected=%s actual=%s\n' "$label" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

echo "=== [1] y (approve) ==="
out="$("$GATE" "${FX}/approve.yaml" --memory-root "$MEMORY" --state-root "$STATE" \
       --response y --evaluator-score 0.85 2>/dev/null)"
echo "  action JSON: $out"
action="$(printf '%s' "$out" | jq -r '.action')"
saved_to="$(printf '%s' "$out" | jq -r '.saved_to')"
assert_eq "action" "$action" "approved"
assert_file "saved_to" "$saved_to"
if [[ -f "$saved_to" ]]; then
  if grep -q 'edited_by_user: false' "$saved_to"; then
    echo "  ✓ edited_by_user=false"; pass=$((pass + 1))
  else
    echo "  ✗ edited_by_user frontmatter missing"; fail=$((fail + 1))
  fi
fi

echo ""
echo "=== [2] N (reject) ==="
out="$("$GATE" "${FX}/reject.yaml" --memory-root "$MEMORY" --state-root "$STATE" \
       --response N --evaluator-score 0.25 2>/dev/null)"
echo "  action JSON: $out"
action="$(printf '%s' "$out" | jq -r '.action')"
rejected_to="$(printf '%s' "$out" | jq -r '.rejected_to')"
assert_eq "action" "$action" "rejected"
assert_file "rejected_to" "$rejected_to"
assert_file "_rejections.log" "${MEMORY}/corrections/_rejections.log"
log_lines="$(wc -l < "${MEMORY}/corrections/_rejections.log" | tr -d ' ')"
assert_eq "log line count" "$log_lines" "1"

echo ""
echo "=== [3] e (edit then approve) ==="
out="$("$GATE" "${FX}/edit.yaml" --memory-root "$MEMORY" --state-root "$STATE" \
       --response e --edited-content "${FX}/edit-content.md" --evaluator-score 0.75 2>/dev/null)"
echo "  action JSON: $out"
action="$(printf '%s' "$out" | jq -r '.action')"
saved_to="$(printf '%s' "$out" | jq -r '.saved_to')"
assert_eq "action" "$action" "edited_approved"
assert_file "saved_to" "$saved_to"
if [[ -f "$saved_to" ]]; then
  if grep -q 'Edited body with refinements' "$saved_to"; then
    echo "  ✓ edited body present"; pass=$((pass + 1))
  else
    echo "  ✗ edited body missing"; fail=$((fail + 1))
  fi
  if grep -q 'edited_by_user: true' "$saved_to"; then
    echo "  ✓ edited_by_user=true"; pass=$((pass + 1))
  else
    echo "  ✗ edited_by_user frontmatter incorrect"; fail=$((fail + 1))
  fi
fi

echo ""
echo "=== [4] s (skip) ==="
out="$("$GATE" "${FX}/skip.yaml" --memory-root "$MEMORY" --state-root "$STATE" \
       --response s --evaluator-score 0.55 2>/dev/null)"
echo "  action JSON: $out"
action="$(printf '%s' "$out" | jq -r '.action')"
kept_at="$(printf '%s' "$out" | jq -r '.kept_at')"
assert_eq "action" "$action" "skipped"
assert_file "kept_at" "$kept_at"

echo ""
printf 'Summary: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

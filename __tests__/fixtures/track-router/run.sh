#!/usr/bin/env bash
# __tests__/fixtures/track-router/run.sh — T-W5-04 검증 러너
#
# 3개 fixture 를 track-router.sh 로 분류하고 expected vs actual 비교.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ROUTER="${REPO_ROOT}/scripts/track-router.sh"
FIXTURES_DIR="${REPO_ROOT}/__tests__/fixtures/track-router"

declare -a CASES=(
  "01-user-correction.yaml|.claude/memory/corrections/react-useeffect-deps.md"
  "02-pattern-repeat.yaml|.claude/memory/tacit/kotlin-coroutine-scope.md"
  "03-session-wrap.yaml|.claude/memory/tacit/commit-message-style.md"
)

pass=0
fail=0
for entry in "${CASES[@]}"; do
  fixture="${entry%%|*}"
  expected="${entry##*|}"
  actual="$("$ROUTER" "${FIXTURES_DIR}/${fixture}" .claude/memory)"
  if [[ "$actual" == "$expected" ]]; then
    printf '[PASS] %s -> %s\n' "$fixture" "$actual"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s\n  expected: %s\n  actual:   %s\n' "$fixture" "$expected" "$actual"
    fail=$((fail + 1))
  fi
done

printf '\nSummary: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

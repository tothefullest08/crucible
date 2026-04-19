#!/usr/bin/env bash
# __tests__/fixtures/overlap-score/run.sh — T-W5-05 검증 러너
#
# 10 샘플 (High/Moderate/Low) 로 overlap-score.sh 실행 후
# expected_band vs actual_band 비교. 정확도 ≥ 80% 통과 기준.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCORE="${REPO_ROOT}/scripts/overlap-score.sh"
DIR="${REPO_ROOT}/__tests__/fixtures/overlap-score"

declare -a CASES=(
  "01-high-react-useeffect.yaml|01-high-react-useeffect.md|High"
  "02-high-kotlin-coroutine.yaml|02-high-kotlin-coroutine.md|High"
  "03-high-db-pool.yaml|03-high-db-pool.md|High"
  "04-moderate-react-state.yaml|04-moderate-react-state.md|Moderate"
  "05-moderate-kotlin-null.yaml|05-moderate-kotlin-null.md|Moderate"
  "06-moderate-async-promise.yaml|06-moderate-async-promise.md|Moderate"
  "07-moderate-python-dict.yaml|07-moderate-python-dict.md|Moderate"
  "08-low-react-vs-python.yaml|08-low-react-vs-python.md|Low"
  "09-low-db-vs-css.yaml|09-low-db-vs-css.md|Low"
  "10-low-kotlin-vs-shell.yaml|10-low-kotlin-vs-shell.md|Low"
)

pass=0
fail=0
total="${#CASES[@]}"
for entry in "${CASES[@]}"; do
  cand="${entry%%|*}"
  rest="${entry#*|}"
  tgt="${rest%%|*}"
  expected="${rest##*|}"
  json="$("$SCORE" "${DIR}/candidates/${cand}" "${DIR}/targets/${tgt}")"
  actual="$(printf '%s' "$json" | jq -r '.total_band')"
  if [[ "$actual" == "$expected" ]]; then
    printf '[PASS] %-40s expected=%-8s actual=%-8s\n' "$cand" "$expected" "$actual"
    pass=$((pass + 1))
  else
    printf '[FAIL] %-40s expected=%-8s actual=%-8s  (%s)\n' "$cand" "$expected" "$actual" "$json"
    fail=$((fail + 1))
  fi
done

accuracy=$(awk -v p="$pass" -v t="$total" 'BEGIN { printf("%.2f", p / t) }')
printf '\nSummary: %d/%d passed (accuracy=%s)\n' "$pass" "$total" "$accuracy"

# 기준: ≥ 0.80
passing="$(awk -v a="$accuracy" 'BEGIN { print (a + 0 >= 0.80) ? 1 : 0 }')"
if [[ "$passing" == "1" ]]; then
  echo "ACCURACY GATE PASS (≥ 80%)"
  exit 0
else
  echo "ACCURACY GATE FAIL (< 80%)"
  exit 1
fi

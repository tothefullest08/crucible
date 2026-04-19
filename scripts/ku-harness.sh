#!/usr/bin/env bash
# scripts/ku-harness.sh — T-W7.5-PRE-01 · v3.3 §8.1 KU 공통 래퍼
#
# 제공 함수 (source 후 호출):
#   ku_run <ku_id> <fixture_dir> <pass_fn> <retry_fn> <results_out>
#     - fixture_dir: 샘플 JSON 묶음 디렉토리 (샘플당 1 파일)
#     - pass_fn: `pass_fn <sample_json_path>` → exit 0 이면 통과, 그 외는 실패
#     - retry_fn: `retry_fn <sample_json_path>` → 1회 재시도 로직 (없으면 `:`)
#     - results_out: 결과 JSON 누적 경로 (디렉토리 내 per-sample .result.json)
#
#   ku_collect_pass_rate <results_dir>  → float (0.00~1.00)
#   ku_decide <metric> <threshold>      → "GREEN" | "blocked_w8"
#
# 제약: bash + jq (§4.1). Python 금지. set -eu. eval 금지.
# shellcheck shell=bash

set -euo pipefail

ku_log() {
  printf '[ku-harness] %s\n' "$*" >&2
}

# ---------------------------------------------------------------
# ku_run — 샘플 루프 + 재시도 1회 후 차단
# ---------------------------------------------------------------
ku_run() {
  local ku_id="$1"
  local fixture_dir="$2"
  local pass_fn="$3"
  local retry_fn="${4::}"
  local results_out="$5"

  if [[ ! -d "$fixture_dir" ]]; then
    ku_log "fixture_dir not found: $fixture_dir"
    return 1
  fi
  mkdir -p "$results_out"

  local total=0
  local passed=0
  local retried=0

  # sample files: *.json (not *.result.json)
  local sample
  while IFS= read -r -d '' sample; do
    total=$((total + 1))
    local sample_id
    sample_id="$(jq -r '.sample_id // "unknown"' "$sample")"

    local result_path="$results_out/${sample_id}.result.json"
    local pass=0

    if "$pass_fn" "$sample"; then
      pass=1
    else
      # Retry once
      retried=$((retried + 1))
      if [[ "$retry_fn" != ":" ]] && "$retry_fn" "$sample"; then
        if "$pass_fn" "$sample"; then
          pass=1
        fi
      fi
    fi

    if [[ "$pass" -eq 1 ]]; then
      passed=$((passed + 1))
    fi

    jq -n \
      --arg ku "$ku_id" \
      --arg sid "$sample_id" \
      --argjson p "$pass" \
      '{ku_id:$ku, sample_id:$sid, pass: ($p==1)}' \
      > "$result_path"
  done < <(find "$fixture_dir" -maxdepth 1 -type f -name '*.json' ! -name '*.result.json' -print0)

  jq -n \
    --arg ku "$ku_id" \
    --argjson total "$total" \
    --argjson passed "$passed" \
    --argjson retried "$retried" \
    '{ku_id:$ku, total:$total, passed:$passed, retried:$retried, pass_rate: (if $total>0 then ($passed/$total) else 0 end)}'
}

# ---------------------------------------------------------------
# ku_decide — 단일 메트릭 판정
# ---------------------------------------------------------------
ku_decide() {
  local metric="$1"
  local threshold="$2"

  awk -v m="$metric" -v t="$threshold" 'BEGIN { if (m+0 >= t+0) print "GREEN"; else print "blocked_w8" }'
}

# ---------------------------------------------------------------
# ku_decide_lt — "낮을수록 좋은" 메트릭 (예: KU-3 false positive rate)
# ---------------------------------------------------------------
ku_decide_lt() {
  local metric="$1"
  local threshold="$2"

  awk -v m="$metric" -v t="$threshold" 'BEGIN { if (m+0 < t+0) print "GREEN"; else print "blocked_w8" }'
}

# Allow sourcing — if run as a script with no args, print usage.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cat >&2 <<'USAGE'
scripts/ku-harness.sh is a library. Source it:

  source scripts/ku-harness.sh
  ku_run "KU-1" "__tests__/fixtures/ku-1-validate-prompt" my_pass_fn my_retry_fn ".claude/state/ku-results/ku-1"
  summary_json="$(ku_run ...)"
  echo "$summary_json" | jq
USAGE
  exit 0
fi

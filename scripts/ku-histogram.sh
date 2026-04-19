#!/usr/bin/env bash
# scripts/ku-histogram.sh — T-W7.5-PRE-01 · v3.3 §8.1 KU-0 자동화
#
# KU-0 qa-judge 점수 분포 측정. 점수 리스트를 stdin 으로 받아
# 분위수(p10/p25/p50/p75/p90) + 기본 통계를 JSON 으로 stdout 출력.
#
# 입력 포맷: 한 줄당 하나의 float (0.0 ~ 1.0). 주석/빈 줄은 무시.
# 출력 포맷: 단일 JSON 객체
#   {
#     "count": 20,
#     "min": 0.10, "max": 0.95,
#     "mean": 0.62,
#     "p10": 0.15, "p25": 0.40, "p50": 0.62, "p75": 0.80, "p90": 0.92
#   }
#
# 제약: bash + awk + jq (§4.1). Python 금지. `eval` 금지. "$var" 쌍따옴표.

set -euo pipefail

# --- helpers ---

_usage() {
  cat >&2 <<'USAGE'
Usage:
  ku-histogram.sh < scores.txt
  echo "0.80
0.40
..." | ku-histogram.sh

Prints a JSON histogram (quantiles + mean/min/max) to stdout.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  _usage
  exit 0
fi

# --- read + validate scores ---

scores_raw="$(cat)"

if [[ -z "${scores_raw// /}" ]]; then
  echo "error: empty input" >&2
  exit 1
fi

# Filter: numeric lines only, clamp [0,1], drop comments/blanks.
scores="$(printf '%s\n' "$scores_raw" \
  | awk 'NF > 0 && $1 !~ /^#/ && $1 ~ /^[0-9]+(\.[0-9]+)?$/ { print $1 }')"

if [[ -z "$scores" ]]; then
  echo "error: no numeric scores after filtering" >&2
  exit 1
fi

# --- compute quantiles via awk (sorted) ---

histogram_json="$(printf '%s\n' "$scores" | sort -n | awk '
  {
    v = $1 + 0
    if (v < 0) v = 0
    if (v > 1) v = 1
    a[NR] = v
    sum += v
  }
  END {
    n = NR
    if (n == 0) { print "{}"; exit 1 }

    # linear-interpolated quantiles (inlined — macOS awk lacks user functions)
    split("0.10 0.25 0.50 0.75 0.90", probs, " ")
    for (i = 1; i <= 5; i++) {
      p = probs[i] + 0
      pos = p * (n - 1) + 1
      lo = int(pos)
      hi = (lo < n) ? lo + 1 : n
      frac = pos - lo
      qv[i] = a[lo] + frac * (a[hi] - a[lo])
    }

    mean = sum / n
    printf "{\"count\":%d,\"min\":%.2f,\"max\":%.2f,\"mean\":%.2f,\"p10\":%.2f,\"p25\":%.2f,\"p50\":%.2f,\"p75\":%.2f,\"p90\":%.2f}\n", \
      n, a[1], a[n], mean, qv[1], qv[2], qv[3], qv[4], qv[5]
  }
')"

# Pretty-print via jq for downstream consumers (validates JSON as a bonus).
printf '%s\n' "$histogram_json" | jq -c .

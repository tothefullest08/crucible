#!/usr/bin/env bash
# scripts/ku-0-run.sh — T-W7.5-01 · v3.3 §8.1 · AC-7
#
# KU-0: qa-judge 점수 분포 histogram 측정 + 분위수 기반 임계값 재조정.
#
# 입력: __tests__/fixtures/ku-0-qa-judge/samples.jsonl (20 샘플 qa-judge 응답)
# 출력: .claude/state/ku-results/ku-0.json
#   {
#     "ku_id": "KU-0", "ac": "AC-7", "status": "GREEN"|"blocked_w8",
#     "data_source": "synthetic" | "real_session",
#     "samples": 20, "histogram": {...}, "old_thresholds": {...}, "new_thresholds": {...}, "diff": {...}
#   }
#
# 제약: bash + jq + awk. Python 금지. eval 금지. "$var".

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly FIXTURE="$ROOT/__tests__/fixtures/ku-0-qa-judge/samples.jsonl"
readonly OUT="$ROOT/.claude/state/ku-results/ku-0.json"
readonly HISTO="$ROOT/scripts/ku-histogram.sh"

# Old thresholds (v3.3 §8 footnote 3: 0.80 / 0.40 from qa-judge MVP).
OLD_ACCEPT=0.80
OLD_RETRY=0.40

# Data source: real session override if env set, else synthetic fixture.
DATA_SOURCE="${KU_DATA_SOURCE:-synthetic}"

if [[ ! -f "$FIXTURE" ]]; then
  echo "error: fixture not found: $FIXTURE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

# Extract scores (stream JSONL → one float per line)
scores="$(jq -r '.score' "$FIXTURE")"

sample_count="$(printf '%s\n' "$scores" | awk 'NF>0' | wc -l | tr -d ' ')"

histogram_json="$(printf '%s\n' "$scores" | "$HISTO")"

# p75 → new accept, p25 → new retry
new_accept="$(printf '%s' "$histogram_json" | jq -r '.p75')"
new_retry="$(printf '%s' "$histogram_json" | jq -r '.p25')"

# Decision rule (AC-7): histogram 20 samples completed AND new thresholds differ from old.
status="GREEN"
reason="histogram 20 samples measured + thresholds rebased on quantiles"
if [[ "$sample_count" -lt 20 ]]; then
  status="blocked_w8"
  reason="samples < 20 (got $sample_count)"
fi
# Check thresholds actually shifted
thresholds_changed="$(awk -v oa="$OLD_ACCEPT" -v na="$new_accept" -v or="$OLD_RETRY" -v nr="$new_retry" \
  'BEGIN { print ((oa+0)!=(na+0) || (or+0)!=(nr+0)) ? "true" : "false" }')"
if [[ "$thresholds_changed" == "false" ]]; then
  status="blocked_w8"
  reason="thresholds unchanged (p75=$new_accept equals old accept=$OLD_ACCEPT)"
fi

jq -n \
  --arg ku "KU-0" \
  --arg ac "AC-7" \
  --arg ds "$DATA_SOURCE" \
  --arg status "$status" \
  --arg reason "$reason" \
  --argjson samples "$sample_count" \
  --argjson histogram "$histogram_json" \
  --argjson old_accept "$OLD_ACCEPT" \
  --argjson old_retry "$OLD_RETRY" \
  --argjson new_accept "$new_accept" \
  --argjson new_retry "$new_retry" \
  '{
    ku_id: $ku, ac: $ac, status: $status, reason: $reason,
    data_source: $ds,
    samples: $samples,
    histogram: $histogram,
    old_thresholds: { accept: $old_accept, retry: $old_retry },
    new_thresholds: { accept: $new_accept, retry: $new_retry },
    diff: {
      accept_delta: ($new_accept - $old_accept),
      retry_delta:  ($new_retry  - $old_retry)
    }
  }' > "$OUT"

echo "wrote: $OUT" >&2
cat "$OUT"

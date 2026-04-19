#!/usr/bin/env bash
# scripts/ku-3-run.sh — T-W7.5-04 · v3.3 §8.1 · AC-5
#
# KU-3: 승격 게이트 false positive rate < 20%.
# 20 후보 (10 valid + 10 noise) 대상으로 규칙 기반 promote/reject 시뮬레이션.
#
# 입력: __tests__/fixtures/ku-3-promotion/*.json
# 출력: .claude/state/ku-results/ku-3.json
#
# Promotion heuristic (MVP 규칙 기반 — LLM judge 대체):
#   1. content 길이 < 40 chars  → reject (short/empty)
#   2. title 공백/NULL           → reject
#   3. evidence 필드 공백        → reject (근거 부재)
#   4. content 단어 수 < 6       → reject (generic filler)
#   5. 반복 토큰 비율 > 0.5      → reject (aaa bbb aaa bbb)
#   otherwise                    → promote
#
# false_positive = (noise 후보 중 promoted) / 10
#
# 제약: bash + jq + awk. Python 금지. eval 금지.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly FIXTURE_DIR="$ROOT/__tests__/fixtures/ku-3-promotion"
readonly OUT="$ROOT/.claude/state/ku-results/ku-3.json"

DATA_SOURCE="${KU_DATA_SOURCE:-synthetic}"
readonly FP_THRESHOLD=0.20

mkdir -p "$(dirname "$OUT")"

# Decide promote/reject given content/evidence/title
decide() {
  local title="$1" content="$2" evidence="$3"

  # Rule 2: empty title
  if [[ -z "${title// /}" ]]; then
    echo "reject"; return
  fi
  # Rule 3: empty evidence
  if [[ -z "${evidence// /}" ]]; then
    echo "reject"; return
  fi
  # Rule 1: short content (< 40 chars)
  local clen=${#content}
  if (( clen < 40 )); then
    echo "reject"; return
  fi
  # Rule 4: word count < 6
  local wc_val
  wc_val="$(printf '%s' "$content" | awk '{print NF}')"
  if (( wc_val < 6 )); then
    echo "reject"; return
  fi
  # Rule 5: repetition ratio (unique tokens / total tokens < 0.5)
  local uniq_ratio
  uniq_ratio="$(printf '%s' "$content" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9가-힣' ' ' | tr -s ' ' '\n' \
    | awk 'NF' | awk '
      { total++; seen[$1]++ }
      END { if (total==0) print "0"; else { u=0; for (k in seen) u++; printf "%.4f", u/total } }
    ')"
  if awk -v r="$uniq_ratio" 'BEGIN { exit !(r+0 < 0.5) }'; then
    echo "reject"; return
  fi
  echo "promote"
}

tp=0; fp=0; tn=0; fn=0
total=0
per_sample_json="[]"

shopt -s nullglob
for f in "$FIXTURE_DIR"/*.json; do
  total=$((total + 1))
  sid="$(jq -r '.sample_id' "$f")"
  gt="$(jq -r '.ground_truth' "$f")"
  title="$(jq -r '.title' "$f")"
  content="$(jq -r '.content' "$f")"
  evidence="$(jq -r '.evidence' "$f")"

  decision="$(decide "$title" "$content" "$evidence")"

  # Classify
  if [[ "$gt" == "valid" && "$decision" == "promote" ]]; then
    tp=$((tp + 1))
  elif [[ "$gt" == "noise" && "$decision" == "promote" ]]; then
    fp=$((fp + 1))
  elif [[ "$gt" == "noise" && "$decision" == "reject" ]]; then
    tn=$((tn + 1))
  else
    fn=$((fn + 1))
  fi

  per_sample_json="$(
    jq --arg sid "$sid" --arg gt "$gt" --arg d "$decision" \
       '. + [{sample_id:$sid, ground_truth:$gt, decision:$d, correct:(( $gt=="valid" and $d=="promote") or ($gt=="noise" and $d=="reject"))}]' \
       <<<"$per_sample_json"
  )"
done

fp_rate="$(awk -v fp="$fp" 'BEGIN { printf "%.4f", fp/10 }')"
status="$(awk -v r="$fp_rate" -v t="$FP_THRESHOLD" 'BEGIN { if (r+0 < t+0) print "GREEN"; else print "blocked_w8" }')"

jq -n \
  --arg ku "KU-3" --arg ac "AC-5" \
  --arg status "$status" --arg ds "$DATA_SOURCE" \
  --argjson total "$total" \
  --argjson tp "$tp" --argjson fp "$fp" --argjson tn "$tn" --argjson fn "$fn" \
  --argjson fp_rate "$fp_rate" --argjson fp_threshold "$FP_THRESHOLD" \
  --argjson per "$per_sample_json" \
  '{
    ku_id:$ku, ac:$ac, status:$status, data_source:$ds,
    samples:$total,
    confusion: { true_positive:$tp, false_positive:$fp, true_negative:$tn, false_negative:$fn },
    false_positive_rate:$fp_rate,
    threshold:$fp_threshold,
    per_sample:$per
  }' > "$OUT"

echo "wrote: $OUT" >&2
jq '{status, samples, confusion, false_positive_rate}' "$OUT"

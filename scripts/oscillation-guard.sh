#!/usr/bin/env bash
# scripts/oscillation-guard.sh — T-W7.5-06 · v3.3 oscillation 과적합 방지
#
# 새 승격 후보 (gen N) 가 2 generations 이내 거부 이력과 content overlap ≥ 0.8 이면
# 재승격 차단. suggested_action: `defer_to_w7.5_review` 로 플래그.
#
# 사용법:
#   scripts/oscillation-guard.sh <candidate.json> <rejected_dir> [--current-gen N]
#
# 입력:
#   <candidate.json> — {sample_id, gen, content, ...}
#   <rejected_dir>   — .claude/memory/corrections/_rejected/ (또는 fixture 경로). YAML 파일들.
#
# 출력 (stdout, single-line JSON):
#   {"sample_id":"...","blocked":true|false,"reason":"...","matched_reject_id":"..."|null,"overlap":0.00,"gen_delta":N}
#
# 로직:
#   1. rejected 파일 로드 (yq 로 content, gen, id 추출)
#   2. gen_delta = current_gen - rejected.gen  (0, 1, 2 만 "recent")
#   3. content Jaccard (normalize → token set) ≥ 0.8 AND gen_delta ≤ 2 → BLOCK
#   4. 그 외 → allow
#
# 제약: bash + jq + yq + awk. Python 금지. eval 금지. set -euo pipefail.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
# shellcheck source=scripts/lib/overlap-dims.sh
source "$ROOT/scripts/lib/overlap-dims.sh"

readonly OVERLAP_THRESHOLD=0.80
readonly GEN_WINDOW=2

_usage() {
  cat >&2 <<'USAGE'
Usage:
  oscillation-guard.sh <candidate.json> <rejected_dir> [--current-gen N]
USAGE
}

if [[ $# -lt 2 ]]; then
  _usage; exit 1
fi

candidate_path="$1"
rejected_dir="$2"
current_gen=""
shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --current-gen) current_gen="$2"; shift 2 ;;
    *) _usage; exit 1 ;;
  esac
done

[[ ! -f "$candidate_path" ]] && { echo "error: candidate not found: $candidate_path" >&2; exit 1; }
[[ ! -d "$rejected_dir"  ]] && { echo "error: rejected_dir not found: $rejected_dir" >&2; exit 1; }

sample_id="$(jq -r '.sample_id' "$candidate_path")"
cand_content="$(jq -r '.content' "$candidate_path")"
cand_gen="${current_gen:-$(jq -r '.gen' "$candidate_path")}"

blocked=false
reason="no-match"
matched_id="null"
max_overlap="0.00"
gen_delta_out=0

shopt -s nullglob
for rej in "$rejected_dir"/*.yaml; do
  rej_id="$(yq eval '.id' "$rej")"
  rej_gen="$(yq eval '.gen' "$rej")"
  rej_content="$(yq eval '.content' "$rej")"

  gen_delta=$((cand_gen - rej_gen))
  # Only consider recent rejections (within GEN_WINDOW)
  if (( gen_delta < 0 || gen_delta > GEN_WINDOW )); then
    continue
  fi

  overlap="$(jaccard_score "$(printf '%s' "$cand_content" | normalize_text)" \
                           "$(printf '%s' "$rej_content"  | normalize_text)")"

  # Track max overlap
  if awk -v a="$overlap" -v b="$max_overlap" 'BEGIN { exit !(a+0 > b+0) }'; then
    max_overlap="$overlap"
  fi

  if awk -v o="$overlap" -v t="$OVERLAP_THRESHOLD" 'BEGIN { exit !(o+0 >= t+0) }'; then
    blocked=true
    reason="overlap ${overlap} >= ${OVERLAP_THRESHOLD} with ${rej_id} (gen_delta=${gen_delta})"
    matched_id="\"$rej_id\""
    gen_delta_out="$gen_delta"
    break
  fi
done

if [[ "$blocked" == "false" ]]; then
  reason="max overlap ${max_overlap} < ${OVERLAP_THRESHOLD} within gen window ±${GEN_WINDOW}"
fi

jq -n \
  --arg sid "$sample_id" \
  --argjson blocked "$blocked" \
  --arg reason "$reason" \
  --argjson matched "$matched_id" \
  --argjson overlap "$max_overlap" \
  --argjson gen_delta "$gen_delta_out" \
  '{
    sample_id:$sid,
    blocked:$blocked,
    reason:$reason,
    matched_reject_id:$matched,
    overlap:$overlap,
    gen_delta:$gen_delta,
    suggested_action: (if $blocked then "defer_to_w7.5_review" else "allow" end)
  }'

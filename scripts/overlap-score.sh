#!/usr/bin/env bash
# scripts/overlap-score.sh — T-W5-05 · 포팅 자산 #18 · v3.3 §3.4 Step 5
#
# 후보 객체(.yaml) 와 기존 메모리 파일(.md) 간 5-dim overlap scoring.
# ce-compound SKILL.md §Related Docs Finder 이식 (bash+jq 재작성).
#
# 5 dimensions (ce-compound):
#   1. problem    (문제 정의)
#   2. cause      (root cause / 원인)
#   3. solution   (solution approach / 해결 방식)
#   4. files      (referenced files)
#   5. prevention (prevention rules)
#
# 각 dim 은 Jaccard 유사도 0.00~1.00, threshold ≥ 0.50 이면 "matched".
# 매치된 dim 수 → Band (High/Moderate/Low, v3.3 §3.4 Step 5).
#
# 사용법:
#   scripts/overlap-score.sh <candidate.yaml> <target.md>
#
# 출력 (stdout, single-line JSON):
#   {"problem":0.87,"cause":0.60,"solution":0.75,"files":1.00,"prevention":0.40,"total_band":"High"}
#
# 에러 처리:
#   • 입력 파일 없음   → exit 1
#   • yq/jq 부재       → exit 2
#
# 보안 (§4.3 P0-8):
#   • set -euo pipefail
#   • 모든 변수 "$var"
#   • eval 금지
#   • jq/yq 에 사용자 입력 직접 보간 금지 (--arg / stdin 사용)

set -euo pipefail

# --- 런타임 선행 검증 ---------------------------------------------------------

if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq is required. 설치: brew install yq" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. 설치: brew install jq" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/overlap-dims.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/overlap-dims.sh"

# --- 인자 파싱 ----------------------------------------------------------------

if [[ $# -lt 2 ]]; then
  echo "Usage: overlap-score.sh <candidate.yaml> <target.md>" >&2
  exit 1
fi

CANDIDATE="$1"
TARGET="$2"

if [[ ! -f "$CANDIDATE" ]]; then
  echo "Error: candidate file not found: $CANDIDATE" >&2
  exit 1
fi
if [[ ! -f "$TARGET" ]]; then
  echo "Error: target file not found: $TARGET" >&2
  exit 1
fi

# --- 후보 5-dim 텍스트 추출 ----------------------------------------------------
#
# 후보 YAML 스키마 (선택 필드 5개):
#   .problem · .cause · .solution · .prevention : 텍스트 (없으면 .content 로 fallback)
#   .context.related_files : CSV (배열 → 쉼표 join)
# content 만 있을 경우 4개 텍스트 dim 을 모두 동일 값으로 초기화.

cand_problem="$(yq -r '.problem // ""' "$CANDIDATE")"
cand_cause="$(yq -r '.cause // ""' "$CANDIDATE")"
cand_solution="$(yq -r '.solution // ""' "$CANDIDATE")"
cand_prevention="$(yq -r '.prevention // ""' "$CANDIDATE")"
cand_content="$(yq -r '.content // ""' "$CANDIDATE")"

[[ -z "$cand_problem" ]]    && cand_problem="$cand_content"
[[ -z "$cand_cause" ]]      && cand_cause="$cand_content"
[[ -z "$cand_solution" ]]   && cand_solution="$cand_content"
[[ -z "$cand_prevention" ]] && cand_prevention="$cand_content"

cand_files_csv="$(yq -r '.context.related_files // [] | join(",")' "$CANDIDATE")"

# --- 타깃 5-dim 텍스트 추출 ----------------------------------------------------
#
# 타깃 .md 는 YAML frontmatter + body 구조.
# frontmatter 필드 우선: .problem, .cause, .solution, .prevention
# 없으면 body 전체를 fallback.
#
# frontmatter 분리: 파일 최상단 `---` ... `---` 블록.

extract_frontmatter() {
  local file="$1"
  awk '
    BEGIN { in_fm = 0; started = 0 }
    /^---[[:space:]]*$/ {
      if (!started) { started = 1; in_fm = 1; next }
      else if (in_fm) { exit }
    }
    { if (in_fm) print }
  ' "$file"
}

extract_body() {
  local file="$1"
  awk '
    BEGIN { in_fm = 0; started = 0; done = 0 }
    /^---[[:space:]]*$/ {
      if (!started) { started = 1; in_fm = 1; next }
      else if (in_fm) { in_fm = 0; done = 1; next }
    }
    { if (done || !started) print }
  ' "$file"
}

target_fm="$(extract_frontmatter "$TARGET")"
target_body="$(extract_body "$TARGET")"

get_fm_field() {
  local field="$1"
  if [[ -z "$target_fm" ]]; then
    printf ''
    return 0
  fi
  printf '%s\n' "$target_fm" | yq -r ".${field} // \"\"" 2>/dev/null || printf ''
}

tgt_problem="$(get_fm_field problem)"
tgt_cause="$(get_fm_field cause)"
tgt_solution="$(get_fm_field solution)"
tgt_prevention="$(get_fm_field prevention)"
tgt_files_csv="$(printf '%s\n' "$target_fm" | yq -r '.related_files // [] | join(",")' 2>/dev/null || printf '')"

[[ -z "$tgt_problem" ]]    && tgt_problem="$target_body"
[[ -z "$tgt_cause" ]]      && tgt_cause="$target_body"
[[ -z "$tgt_solution" ]]   && tgt_solution="$target_body"
[[ -z "$tgt_prevention" ]] && tgt_prevention="$target_body"

# --- 5-dim 점수 계산 ----------------------------------------------------------

score_problem="$(jaccard_score "$cand_problem" "$tgt_problem")"
score_cause="$(jaccard_score "$cand_cause" "$tgt_cause")"
score_solution="$(jaccard_score "$cand_solution" "$tgt_solution")"
score_prevention="$(jaccard_score "$cand_prevention" "$tgt_prevention")"
score_files="$(files_overlap "$cand_files_csv" "$tgt_files_csv")"

# --- matched dim 수 계산 (threshold = 0.50) ------------------------------------

matched=0
for s in "$score_problem" "$score_cause" "$score_solution" "$score_files" "$score_prevention"; do
  # 문자열 비교 없이 awk 로 수치 비교 (bash 는 float 비교 미지원)
  is_match="$(awk -v v="$s" 'BEGIN { print (v + 0 >= 0.5) ? 1 : 0 }')"
  if [[ "$is_match" == "1" ]]; then
    matched=$((matched + 1))
  fi
done

band="$(band_from_matches "$matched")"

# --- JSON 조립 ----------------------------------------------------------------

jq -nc \
  --argjson problem    "$score_problem" \
  --argjson cause      "$score_cause" \
  --argjson solution   "$score_solution" \
  --argjson files      "$score_files" \
  --argjson prevention "$score_prevention" \
  --arg band           "$band" \
  '{
    problem:    $problem,
    cause:      $cause,
    solution:   $solution,
    files:      $files,
    prevention: $prevention,
    total_band: $band
  }'

#!/usr/bin/env bash
# scripts/track-router.sh — T-W5-04 · 포팅 자산 #24 · v3.3 §3.4 Step 5
#
# 후보 객체(.yaml)를 읽어 trigger_source 기반으로 Bug track vs Knowledge track
# 자동 분류. 최종 저장 경로를 stdout 에 출력.
#
# 분기 규칙 (v3.3 §3.4.1 Step 5 + memory/README.md §Bug track vs Knowledge track):
#   • trigger_source = user_correction → corrections/  (Bug track)
#   • 그 외 (pattern_repeat, session_wrap) → tacit/    (Knowledge track)
#
# 사용법:
#   scripts/track-router.sh <candidate.yaml> [<memory_root>]
#
# 인자:
#   $1 : 후보 객체 YAML 경로 (필수)
#   $2 : 메모리 루트 경로 (선택, 기본 .claude/memory)
#
# 출력 (stdout):
#   최종 저장 경로 (예: .claude/memory/corrections/<slug>.md)
#
# 에러 처리:
#   • YAML 파싱 실패    → exit 1
#   • trigger_source 누락 → exit 1
#   • slug 검증 실패     → exit 1
#
# 보안 (§4.3 P0-8):
#   • set -euo pipefail
#   • 모든 변수 "$var"
#   • eval 금지
#   • slug 화이트리스트 [a-zA-Z0-9_-]
#   • yq 표현식에 사용자 입력 보간 금지 (eval-expression 금지)

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

# --- 인자 파싱 ----------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "Usage: track-router.sh <candidate.yaml> [<memory_root>]" >&2
  exit 1
fi

CANDIDATE="$1"
MEMORY_ROOT="${2:-.claude/memory}"

if [[ ! -f "$CANDIDATE" ]]; then
  echo "Error: candidate file not found: $CANDIDATE" >&2
  exit 1
fi

# --- 후보 YAML 파싱 -----------------------------------------------------------

trigger_source="$(yq -r '.trigger_source // ""' "$CANDIDATE")"
candidate_id="$(yq -r '.candidate_id // ""' "$CANDIDATE")"
content="$(yq -r '.content // ""' "$CANDIDATE")"

if [[ -z "$trigger_source" ]]; then
  echo "Error: trigger_source missing in $CANDIDATE" >&2
  exit 1
fi

if [[ -z "$candidate_id" ]]; then
  echo "Error: candidate_id missing in $CANDIDATE" >&2
  exit 1
fi

# --- 트랙 분기 ----------------------------------------------------------------

case "$trigger_source" in
  user_correction)
    track_dir="corrections"
    ;;
  pattern_repeat|session_wrap)
    track_dir="tacit"
    ;;
  *)
    echo "Error: unknown trigger_source: $trigger_source" >&2
    exit 1
    ;;
esac

# --- slug 생성 ----------------------------------------------------------------
#
# slug 우선순위:
#   1) YAML .suggested_slug 필드
#   2) content 첫 줄에서 영숫자만 추출 + lowercase + 공백 → dash
#   3) candidate_id (uuid) 앞 8자

suggested_slug="$(yq -r '.suggested_slug // ""' "$CANDIDATE")"

make_slug_from_content() {
  local raw="$1"
  # 첫 줄만 + lowercase + 영숫자/공백만 남김 + 공백 → '-' + 최대 50자
  printf '%s' "$raw" \
    | head -n 1 \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9 \n' ' ' \
    | tr -s ' ' '-' \
    | sed 's/^-//;s/-$//' \
    | cut -c1-50
}

if [[ -n "$suggested_slug" ]]; then
  slug="$suggested_slug"
elif [[ -n "$content" ]]; then
  slug="$(make_slug_from_content "$content")"
  if [[ -z "$slug" ]]; then
    slug="${candidate_id:0:8}"
  fi
else
  slug="${candidate_id:0:8}"
fi

# slug 화이트리스트 (§4.3 P0-8)
if [[ ! "$slug" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: slug contains invalid characters (allowed: [a-zA-Z0-9_-]): $slug" >&2
  exit 1
fi

# --- 최종 경로 ----------------------------------------------------------------

final_path="${MEMORY_ROOT}/${track_dir}/${slug}.md"
printf '%s\n' "$final_path"

#!/usr/bin/env bash
# scripts/promotion-gate.sh — T-W5-06 · v3.3 §3.4 Step 4+5+6
#
# 승격 후보 1건에 대해 y/N/e/s UX 를 제공. Stop hook 또는 /session-wrap 수동 호출
# 에서 각 후보별로 반복 호출된다.
#
# 사용법:
#   scripts/promotion-gate.sh <candidate.yaml> \
#       [--memory-root <dir>]        # 기본 .claude/memory
#       [--state-root <dir>]         # 기본 .claude/state
#       [--response <y|N|e|s>]       # stdin 대신 직접 응답 (fixture 시뮬레이션)
#       [--edited-content <file>]    # --response e 전용 (편집된 본문 파일)
#       [--evaluator-score <float>]  # 표시용 score (optional)
#       [--index N] [--count M]      # 표시용 순번 (optional)
#
# 출력 (stdout, single-line JSON):
#   {"action":"approved","saved_to":"<path>"}
#   {"action":"rejected","rejected_to":"<path>","detector_id":"<id>"}
#   {"action":"edited_approved","saved_to":"<path>"}
#   {"action":"skipped","kept_at":"<path>"}
#
# 보안 (§4.3 P0-8):
#   • set -euo pipefail · "$var" · eval 금지
#   • slug 화이트리스트
#   • yq 에 사용자 입력 보간 금지

set -euo pipefail

# --- 선행 검증 -----------------------------------------------------------------

if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq is required." >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTER="${SCRIPT_DIR}/track-router.sh"

if [[ ! -x "$ROUTER" ]]; then
  echo "Error: track-router.sh not found or not executable: $ROUTER" >&2
  exit 2
fi

# --- 인자 파싱 -----------------------------------------------------------------

CANDIDATE=""
MEMORY_ROOT=".claude/memory"
STATE_ROOT=".claude/state"
RESPONSE=""
EDITED_CONTENT=""
EVALUATOR_SCORE=""
INDEX="1"
COUNT="1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --memory-root)      MEMORY_ROOT="$2"; shift 2 ;;
    --state-root)       STATE_ROOT="$2"; shift 2 ;;
    --response)         RESPONSE="$2"; shift 2 ;;
    --edited-content)   EDITED_CONTENT="$2"; shift 2 ;;
    --evaluator-score)  EVALUATOR_SCORE="$2"; shift 2 ;;
    --index)            INDEX="$2"; shift 2 ;;
    --count)            COUNT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0" >&2
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$CANDIDATE" ]]; then
        CANDIDATE="$1"
      else
        echo "Unexpected arg: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$CANDIDATE" ]]; then
  echo "Usage: promotion-gate.sh <candidate.yaml> [options...]" >&2
  exit 1
fi
if [[ ! -f "$CANDIDATE" ]]; then
  echo "Error: candidate not found: $CANDIDATE" >&2
  exit 1
fi

# --- 후보 필드 추출 -----------------------------------------------------------

candidate_id="$(yq -r '.candidate_id // ""' "$CANDIDATE")"
trigger_source="$(yq -r '.trigger_source // ""' "$CANDIDATE")"
content="$(yq -r '.content // ""' "$CANDIDATE")"
session_id="$(yq -r '.context.session_id // ""' "$CANDIDATE")"
turn_range="$(yq -r '.context.turn_range // ""' "$CANDIDATE")"
detector_id_field="$(yq -r '.detector_id // ""' "$CANDIDATE")"

if [[ -z "$candidate_id" || -z "$trigger_source" ]]; then
  echo "Error: candidate missing candidate_id or trigger_source" >&2
  exit 1
fi

# detector_id: 명시 필드 > trigger_source:candidate_id[:8] fallback (§3.4.4 "동일 패턴" 식별자)
if [[ -n "$detector_id_field" ]]; then
  detector_id="$detector_id_field"
else
  detector_id="${trigger_source}:${candidate_id:0:8}"
fi

# --- gate-dialog 출력 (stderr) -------------------------------------------------

badge="🟡"
if [[ -n "$EVALUATOR_SCORE" ]]; then
  badge="$(awk -v s="$EVALUATOR_SCORE" 'BEGIN {
    v = s + 0
    if (v >= 0.80) print "🟢"
    else if (v >= 0.40) print "🟡"
    else print "🔴"
  }')"
fi

summary="$(printf '%s' "$content" | head -n 1 | cut -c1-80)"
if [[ "${#summary}" -ge 80 ]]; then
  summary="${summary}…"
fi

suggested_path="$("$ROUTER" "$CANDIDATE" "$MEMORY_ROOT")"

{
  printf '════════════════════════════════════════════════════════════════\n'
  printf '  Harness Compound — 승격 후보 [%s/%s]\n' "$INDEX" "$COUNT"
  printf '════════════════════════════════════════════════════════════════\n'
  printf '  %s score=%s · trigger=%s\n' "$badge" "${EVALUATOR_SCORE:-?}" "$trigger_source"
  printf '  저장 경로: %s\n' "$suggested_path"
  printf '  요약: "%s"\n' "$summary"
  printf '  source: %s · turn %s\n' "$session_id" "$turn_range"
  printf '\n'
  printf '  [y]승인  [N]거부  [e]수정 후 승인  [s]건너뛰기 > '
} >&2

# --- 응답 수집 -----------------------------------------------------------------

if [[ -z "$RESPONSE" ]]; then
  IFS= read -r RESPONSE || RESPONSE=""
fi
# 기본값 N (오염 방지, v3.3 §3.4.3)
if [[ -z "$RESPONSE" ]]; then
  RESPONSE="N"
fi

# --- 보조 함수 ----------------------------------------------------------------

write_approved() {
  # $1: target path
  # $2: content (overrides candidate.content when edited)
  local target="$1"
  local body="$2"
  mkdir -p "$(dirname "$target")"
  local promoted_at
  promoted_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  {
    printf -- '---\n'
    printf 'candidate_id: %s\n' "$candidate_id"
    printf 'promoted_at: %s\n' "$promoted_at"
    if [[ -n "$EVALUATOR_SCORE" ]]; then
      printf 'evaluator_score: %s\n' "$EVALUATOR_SCORE"
    fi
    printf 'trigger_source: %s\n' "$trigger_source"
    printf 'source_turn: %s:%s\n' "$session_id" "$turn_range"
    printf 'edited_by_user: %s\n' "$3"
    printf -- '---\n'
    printf '\n%s\n' "$body"
  } > "$target"
}

append_rejection_log() {
  # $1: detector_id
  local detector_id="$1"
  local log_file="${MEMORY_ROOT}/corrections/_rejections.log"
  mkdir -p "$(dirname "$log_file")"
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  # pattern hash: candidate_id 의 앞 12자를 pattern_hash 로 사용 (안정 식별자)
  local pattern_hash="${candidate_id:0:12}"
  printf '%s %s %s\n' "$ts" "$detector_id" "$pattern_hash" >> "$log_file"
}

write_rejected() {
  local rejected_dir="${MEMORY_ROOT}/corrections/_rejected"
  mkdir -p "$rejected_dir"
  local target="${rejected_dir}/${candidate_id}.md"
  local rejected_at
  rejected_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  {
    printf -- '---\n'
    printf 'candidate_id: %s\n' "$candidate_id"
    printf 'rejected_at: %s\n' "$rejected_at"
    printf 'rejection_source: user_reject\n'
    if [[ -n "$EVALUATOR_SCORE" ]]; then
      printf 'evaluator_score: %s\n' "$EVALUATOR_SCORE"
    fi
    printf 'trigger_source: %s\n' "$trigger_source"
    printf 'source_turn: %s:%s\n' "$session_id" "$turn_range"
    printf -- '---\n'
    printf '\n%s\n' "$content"
  } > "$target"
  printf '%s' "$target"
}

# --- 분기 실행 ----------------------------------------------------------------

case "$RESPONSE" in
  y|Y)
    write_approved "$suggested_path" "$content" "false"
    jq -nc --arg p "$suggested_path" '{action:"approved",saved_to:$p}'
    ;;
  e|E)
    if [[ -z "$EDITED_CONTENT" ]]; then
      echo "Error: --response e requires --edited-content <file>" >&2
      exit 1
    fi
    if [[ ! -f "$EDITED_CONTENT" ]]; then
      echo "Error: edited content file not found: $EDITED_CONTENT" >&2
      exit 1
    fi
    edited_body="$(cat "$EDITED_CONTENT")"
    write_approved "$suggested_path" "$edited_body" "true"
    jq -nc --arg p "$suggested_path" '{action:"edited_approved",saved_to:$p}'
    ;;
  s|S)
    queue_path="${STATE_ROOT}/promotion_queue/${candidate_id}.yaml"
    mkdir -p "$(dirname "$queue_path")"
    # 원본 후보 파일이 이미 큐 위치에 있으면 별도 복사 없이 경로만 보고.
    if [[ "$(cd "$(dirname "$CANDIDATE")" && pwd)/$(basename "$CANDIDATE")" != \
          "$(cd "$(dirname "$queue_path")" && pwd)/$(basename "$queue_path")" ]]; then
      cp -f "$CANDIDATE" "$queue_path"
    fi
    jq -nc --arg p "$queue_path" '{action:"skipped",kept_at:$p}'
    ;;
  N|n|"")
    rejected_path="$(write_rejected)"
    append_rejection_log "$detector_id"
    jq -nc \
      --arg p "$rejected_path" \
      --arg d "$detector_id" \
      '{action:"rejected",rejected_to:$p,detector_id:$d}'
    ;;
  *)
    echo "Error: invalid response: $RESPONSE (expected y|N|e|s)" >&2
    exit 1
    ;;
esac

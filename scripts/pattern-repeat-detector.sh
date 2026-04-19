#!/usr/bin/env bash
# scripts/pattern-repeat-detector.sh — T-W6-06 · v3.3 §3.4 Step 1 (pattern_repeat)
#
# 동일 토픽 3회 반복 감지기. p4cn history-insight 아이디어를 bash+jq 로 재구성.
# 세션 JSONL 을 W1 scripts/extract-session.sh 로 파싱하여 유저 발화(prompt-v0)
# 턴들에서 핵심 토큰을 추출, 3회 이상 등장한 토큰마다 pattern_repeat 후보를
# `${HARNESS_STATE_ROOT:-.claude/state}/promotion_queue/<candidate_id>.yaml` 에 적재.
#
# 사용법:
#   scripts/pattern-repeat-detector.sh <session.jsonl>
#
# 출력 (stdout):
#   NDJSON — 감지된 후보마다 1줄:
#     {"candidate_id":"...","token":"...","count":N,"turns":[..],"queue_path":"..."}
#
# 환경 변수:
#   HARNESS_STATE_ROOT      큐 루트 (기본 .claude/state)
#   PATTERN_REPEAT_MIN      반복 임계값 (기본 3)
#   PATTERN_REPEAT_MIN_LEN  토큰 최소 바이트 수 (기본 5 — 짧은 기능어 배제)
#
# 보안 (v3.3 §4.3):
#   set -euo pipefail · 모든 변수 "$var" · eval 금지
#   jq filter 문자열 보간 금지 (--arg / --argjson 만)
#   SC linter clean

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq required" >&2
    exit 2
fi
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
    echo "Error: bash >= 4.0 required" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACTOR="${SCRIPT_DIR}/extract-session.sh"
if [[ ! -x "$EXTRACTOR" ]]; then
    echo "Error: extract-session.sh missing: $EXTRACTOR" >&2
    exit 2
fi

MIN_REPEAT="${PATTERN_REPEAT_MIN:-3}"
MIN_LEN="${PATTERN_REPEAT_MIN_LEN:-5}"

# Minimal English stopword set — only words that otherwise routinely pass the
# length filter yet carry no topical signal. Kept tight so surprising FPs
# remain observable in fixtures (MVP tolerates them; promotion gate rejects).
STOPWORDS=(
    "about" "above" "after" "again" "against" "because" "before" "being" "between"
    "could" "should" "would" "their" "there" "these" "those" "through" "which" "while"
    "where" "with" "your" "this" "that" "from" "have" "here" "much" "just" "very"
    "really" "thing" "something" "nothing" "doing" "going" "still" "even" "also" "only"
    "then" "than" "them" "they" "when" "what" "into" "over" "been" "each" "such" "some"
)

is_stopword() {
    local w="$1" s
    for s in "${STOPWORDS[@]}"; do
        [[ "$w" == "$s" ]] && return 0
    done
    return 1
}

if [[ $# -lt 1 ]]; then
    echo "Usage: pattern-repeat-detector.sh <session.jsonl>" >&2
    exit 1
fi

SESSION_PATH="$1"
if [[ ! -f "$SESSION_PATH" ]]; then
    echo "Error: session JSONL not found: $SESSION_PATH" >&2
    exit 1
fi

# --- Extract turns + filter user prompts -------------------------------------

TURNS_JSON="$("$EXTRACTOR" "$SESSION_PATH" 2>/dev/null)"
if [[ -z "$TURNS_JSON" || "$TURNS_JSON" == "[]" ]]; then
    echo "pattern-repeat: no turns extracted" >&2
    exit 0
fi

# Build a TAB-separated table: turn_index<TAB>text  for prompt-kind turns.
TURN_TABLE="$(mktemp -t prd-turns.XXXXXX)"
trap 'rm -f "$TURN_TABLE" "$TOKEN_FILE" 2>/dev/null || true' EXIT

jq -r '
    .[]
    | select(.content.kind == "prompt")
    | [(.turn_index | tostring), (.content.text // "")]
    | @tsv
' <<<"$TURNS_JSON" > "$TURN_TABLE"

# Resolve session_id from first prompt turn (fallback: basename).
SESSION_ID="$(jq -r '
    [.[] | select(.content.kind == "prompt" and .content.session_id != null) | .content.session_id]
    | if length > 0 then .[0] else "" end
' <<<"$TURNS_JSON")"
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID="$(basename "$SESSION_PATH" .jsonl)"
fi

# --- Tokenize user turns ------------------------------------------------------

TOKEN_FILE="$(mktemp -t prd-tokens.XXXXXX)"

while IFS=$'\t' read -r turn_idx text; do
    [[ -z "$turn_idx" ]] && continue
    # Lowercase + split on non-word (keep multibyte bytes intact).
    printf '%s' "$text" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -c 'a-z0-9_\200-\377' '\n' \
        | awk -v t="$turn_idx" -v min="$MIN_LEN" 'length($0) >= min { printf "%s\t%s\n", $0, t }'
done < "$TURN_TABLE" > "$TOKEN_FILE"

# --- Count and emit candidates ------------------------------------------------

# Sort + uniq to deduplicate a token within the same turn (don't count twice).
DEDUP="$(mktemp -t prd-dedup.XXXXXX)"
# shellcheck disable=SC2064
trap "rm -f '$TURN_TABLE' '$TOKEN_FILE' '$DEDUP' 2>/dev/null || true" EXIT
sort -u "$TOKEN_FILE" > "$DEDUP"

# Aggregate per token: count occurrences (turns), collect turn list.
# Output format: <count>\t<token>\t<turn1,turn2,...>
AGG="$(awk -F'\t' '
{
    tok = $1
    turn = $2
    count[tok]++
    if (turns[tok] == "") turns[tok] = turn
    else turns[tok] = turns[tok] "," turn
}
END {
    for (t in count) printf "%d\t%s\t%s\n", count[t], t, turns[t]
}' "$DEDUP")"

QUEUE_DIR="${HARNESS_STATE_ROOT:-.claude/state}/promotion_queue"
mkdir -p "$QUEUE_DIR"

iso_now() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
new_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        local hex
        hex="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
        printf '%s-%s-4%s-8%s-%s\n' \
            "${hex:0:8}" "${hex:8:4}" "${hex:13:3}" "${hex:17:3}" "${hex:20:12}"
    fi
}

emitted=0
while IFS=$'\t' read -r count token turns; do
    [[ -z "$token" ]] && continue
    (( count >= MIN_REPEAT )) || continue
    is_stopword "$token" && continue

    cid="$(new_uuid)"
    now_iso="$(iso_now)"

    # turn_range = min-max
    range_min="$(printf '%s' "$turns" | tr ',' '\n' | sort -n | head -1)"
    range_max="$(printf '%s' "$turns" | tr ',' '\n' | sort -n | tail -1)"

    target="${QUEUE_DIR}/${cid}.yaml"
    tmp="${target}.tmp.$$"

    {
        printf 'candidate_id: %s\n' "$cid"
        printf 'trigger_source: pattern_repeat\n'
        printf 'detector_id: pattern:%s\n' "${token}"
        printf 'content: |\n'
        printf '  Repeated topic: %s. Occurrences: turn %s\n' "$token" "$turns"
        printf 'context:\n'
        printf '  session_id: "%s"\n' "$SESSION_ID"
        printf '  turn_range: "%s-%s"\n' "$range_min" "$range_max"
        printf '  related_files: []\n'
        printf 'detected_at: %s\n' "$now_iso"
        printf 'detection_reason: "token=%s count=%d"\n' "$token" "$count"
    } > "$tmp"
    mv -f "$tmp" "$target"

    # stdout report
    turns_json="$(printf '%s' "$turns" | tr ',' '\n' | jq -R 'tonumber? // empty' | jq -sc '.')"
    jq -cn \
        --arg cid "$cid" \
        --arg tok "$token" \
        --argjson c "$count" \
        --argjson t "$turns_json" \
        --arg path "$target" \
        '{candidate_id:$cid, token:$tok, count:$c, turns:$t, queue_path:$path}'

    emitted=$((emitted + 1))
done <<< "$AGG"

echo "pattern-repeat: emitted=$emitted min_repeat=$MIN_REPEAT session=$SESSION_ID" >&2

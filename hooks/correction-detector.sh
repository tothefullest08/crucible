#!/usr/bin/env bash
# hooks/correction-detector.sh — T-W5-09 + T-W6-05 · v3.3 §4.3.6·§4.3.7·§3.4.1
#
# Reads a PostToolUse or UserPromptSubmit payload (JSON) from stdin, extracts
# the user utterance and (when present) the prior assistant turn, runs the
# keyword + negative-context check, emits a JSON verdict on stdout, and — on
# positive detection — enqueues a promotion candidate to
# `${HARNESS_STATE_ROOT:-.claude/state}/promotion_queue/<candidate_id>.yaml`.
#
# Keyword set (§4.3.7): 틀렸, wrong, incorrect, 잘못 (case-insensitive).
#
# Negative-context (false-positive suppression) — §4.3.7 P1-7 (T-W5-09 scope):
#   1. Prior assistant turn length ≥ 20 chars (complete claim present).
#   2. User utterance shares ≥ 1 meaningful token with the prior assistant
#      turn (simple coreference approximation).
#
# Payload field dispatch:
#   - user_utterance:  .tool_response.user_utterance // .tool_response.prompt // .prompt
#   - prior_turn:      .tool_response.prior_assistant_turn // .prior_assistant_turn
#   - session_id:      .session_id
#
# Queue enqueue (T-W6-05):
#   - Triggered on detected=true, unless env CORRECTION_DETECT_ONLY=1 is set
#     (used by T-W5-09 smoke fixtures that only check the verdict).
#   - Candidate YAML schema follows v3.3 §3.4.2 (candidate_id / trigger_source
#     / content / context.{session_id, turn_range, related_files} / detected_at).
#
# Output contract (stdout, single line JSON):
#   detected == true   -> {"detected":true,"reason":"...","suggested_action":"promotion_gate_user_correction","candidate_id":"..."}
#   detected == false  -> {"detected":false,"reason":"..."}
#
# Safety (v3.3 §4.3):
#   - set -euo pipefail
#   - all expansions quoted
#   - no eval / no string-interpolated jq filters (uses --arg only)
#   - shellcheck clean
#
# Runtime: bash + jq (+ uuidgen) only (Python/Node forbidden — v3 §4.1).

set -euo pipefail

MIN_PRIOR_LEN=20
MIN_TOKEN_LEN=3          # bytes — skips KR josas / short function words
KEYWORDS=('틀렸' 'wrong' 'incorrect' '잘못')

emit() {
    # $1 = detected bool, $2 = reason, $3 (optional) = suggested_action,
    # $4 (optional) = candidate_id
    local detected="$1" reason="$2" action="${3:-}" cid="${4:-}"
    if [[ -n "$action" && -n "$cid" ]]; then
        jq -cn --argjson d "$detected" --arg r "$reason" --arg a "$action" --arg c "$cid" \
            '{detected:$d, reason:$r, suggested_action:$a, candidate_id:$c}'
    elif [[ -n "$action" ]]; then
        jq -cn --argjson d "$detected" --arg r "$reason" --arg a "$action" \
            '{detected:$d, reason:$r, suggested_action:$a}'
    else
        jq -cn --argjson d "$detected" --arg r "$reason" \
            '{detected:$d, reason:$r}'
    fi
}

# T-W6-05: produce a lowercased UUID. Prefer uuidgen; fall back to
# /proc/sys/kernel/random/uuid (Linux) or /dev/urandom composite (macOS sans
# uuidgen, rare). Never interpolate into jq / yaml without quoting.
new_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # 16 random bytes → rfc4122 v4-ish layout. Safe enough for queue IDs.
        local hex
        hex="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
        printf '%s-%s-4%s-8%s-%s\n' \
            "${hex:0:8}" "${hex:8:4}" "${hex:13:3}" "${hex:17:3}" "${hex:20:12}"
    fi
}

iso8601_utc_now() {
    date -u +'%Y-%m-%dT%H:%M:%SZ'
}

# Enqueue a user_correction candidate (v3.3 §3.4.2). Writes YAML atomically
# via a temp file + rename so a mid-write partial file can never be consumed
# by hooks/stop.sh.
enqueue_correction_candidate() {
    local utterance="$1" session_id="$2" reason="$3"
    local state_root="${HARNESS_STATE_ROOT:-.claude/state}"
    local queue_dir="${state_root}/promotion_queue"
    mkdir -p "$queue_dir"

    local candidate_id
    candidate_id="$(new_uuid)"
    local now_iso
    now_iso="$(iso8601_utc_now)"

    local target="${queue_dir}/${candidate_id}.yaml"
    local tmp="${target}.tmp.$$"

    # Indent literal block scalar: every line of the utterance gets 2 spaces.
    # Use awk to keep newlines intact without eval or interpolation.
    local content_block
    content_block="$(awk '{print "  " $0}' <<<"$utterance")"

    local reason_escaped
    reason_escaped="$(printf '%s' "$reason" | sed 's/"/\\"/g')"

    {
        printf 'candidate_id: %s\n' "$candidate_id"
        printf 'trigger_source: user_correction\n'
        printf 'detector_id: correction:%s\n' "${candidate_id:0:8}"
        printf 'content: |\n'
        printf '%s\n' "$content_block"
        printf 'context:\n'
        printf '  session_id: "%s"\n' "$session_id"
        printf '  turn_range: ""\n'
        printf '  related_files: []\n'
        printf 'detected_at: %s\n' "$now_iso"
        printf 'detection_reason: "%s"\n' "$reason_escaped"
    } > "$tmp"
    mv -f "$tmp" "$target"
    printf '%s' "$candidate_id"
}

# Lower-case and split on non-word characters. Emits one token per line.
# Korean characters are preserved (multibyte-safe because tr operates on
# byte ranges we do not strip). Tokens shorter than MIN_TOKEN_LEN bytes are
# filtered — this drops both ASCII particles and single-syllable noise while
# keeping two-syllable Korean words (≥ 6 bytes in UTF-8).
tokenize() {
    local text="$1"
    local lower
    lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"
    # Replace ASCII punctuation and whitespace with newlines; leave multibyte
    # bytes alone. Each line becomes one candidate token.
    printf '%s' "$lower" \
        | tr -c 'a-z0-9_\200-\377' '\n' \
        | awk -v min="$MIN_TOKEN_LEN" 'length($0) >= min { print }'
}

# Shared-token intersection. Keywords are removed from the user-side token
# list so the keyword itself cannot count as "coreference evidence".
shared_token() {
    local user_tokens="$1" prior_tokens="$2"
    local filtered="$user_tokens"
    local kw
    for kw in "${KEYWORDS[@]}"; do
        local kw_lower
        kw_lower="$(printf '%s' "$kw" | tr '[:upper:]' '[:lower:]')"
        # Drop tokens containing the keyword (substring filter covers KR
        # conjugations like "틀렸다", "틀렸습니다").
        filtered="$(printf '%s\n' "$filtered" | grep -Fv -- "$kw_lower" || true)"
    done
    [[ -n "$filtered" ]] || return 1
    # Substring match in either direction: user-token ⊂ prior-token OR
    # prior-token ⊂ user-token. Tolerates Korean josa attachment.
    while IFS= read -r tok; do
        [[ -n "$tok" ]] || continue
        if printf '%s\n' "$prior_tokens" | grep -Fq -- "$tok"; then
            printf '%s' "$tok"
            return 0
        fi
    done <<< "$filtered"
    return 1
}

# -----------------------------------------------------------------------------
# 1. Parse payload.
# -----------------------------------------------------------------------------
INPUT="$(cat)"

if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
    emit false "invalid payload"
    exit 0
fi

USER_UTTERANCE="$(printf '%s' "$INPUT" | jq -r '.tool_response.user_utterance // .tool_response.prompt // .prompt // empty')"
PRIOR_TURN="$(printf '%s' "$INPUT" | jq -r '.tool_response.prior_assistant_turn // .prior_assistant_turn // empty')"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // .tool_response.session_id // empty')"

if [[ -z "$USER_UTTERANCE" ]]; then
    emit false "no user utterance"
    exit 0
fi

# -----------------------------------------------------------------------------
# 2. Keyword match (case-insensitive).
# -----------------------------------------------------------------------------
USER_LOWER="$(printf '%s' "$USER_UTTERANCE" | tr '[:upper:]' '[:lower:]')"
matched_keyword=''
for kw in "${KEYWORDS[@]}"; do
    kw_lower="$(printf '%s' "$kw" | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$USER_LOWER" | grep -Fq -- "$kw_lower"; then
        matched_keyword="$kw"
        break
    fi
done

if [[ -z "$matched_keyword" ]]; then
    emit false "no keyword"
    exit 0
fi

# -----------------------------------------------------------------------------
# 3. Negative-context check #1 — prior assistant turn length.
# -----------------------------------------------------------------------------
if [[ "${#PRIOR_TURN}" -lt "$MIN_PRIOR_LEN" ]]; then
    emit false "no prior assistant claim"
    exit 0
fi

# -----------------------------------------------------------------------------
# 4. Negative-context check #2 — shared meaningful token.
# -----------------------------------------------------------------------------
USER_TOKENS="$(tokenize "$USER_UTTERANCE")"
PRIOR_TOKENS="$(tokenize "$PRIOR_TURN")"

if ! shared="$(shared_token "$USER_TOKENS" "$PRIOR_TOKENS")"; then
    emit false "no shared token with prior turn"
    exit 0
fi

# -----------------------------------------------------------------------------
# 5. Verdict + (T-W6-05) enqueue candidate.
# -----------------------------------------------------------------------------
reason="keyword='${matched_keyword}', shared='${shared}'"

candidate_id=""
if [[ "${CORRECTION_DETECT_ONLY:-0}" != "1" ]]; then
    candidate_id="$(enqueue_correction_candidate "$USER_UTTERANCE" "$SESSION_ID" "$reason" || true)"
fi

emit true "$reason" "promotion_gate_user_correction" "$candidate_id"
exit 0

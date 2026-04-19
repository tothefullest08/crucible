#!/usr/bin/env bash
# hooks/correction-detector.sh — T-W5-09 · v3.3 §4.3.6 PostToolUse chain #3 · §4.3.7
#
# Reads a PostToolUse payload (JSON) from stdin, extracts the user utterance
# and the prior assistant turn from `tool_response`, and emits a small JSON
# verdict on stdout describing whether a user correction was detected.
#
# Keyword set (§4.3.7): 틀렸, wrong, incorrect, 잘못 (case-insensitive).
#
# Negative-context (false-positive suppression) — §4.3.7 P1-7:
#   1. Prior assistant turn length ≥ 20 chars (complete claim present).
#   2. User utterance (the "matched sentence") shares ≥ 1 meaningful token
#      with the prior assistant turn (simple coreference approximation).
#
# MVP accepts remaining false positives; the promotion gate UX (§3.4, §11-3)
# gives the user a final reject.
#
# Output contract (stdout, single line JSON):
#   detected == true   -> {"detected":true,"reason":"...","suggested_action":"promotion_gate_user_correction"}
#   detected == false  -> {"detected":false,"reason":"..."}
#
# Safety (v3.3 §4.3):
#   - set -euo pipefail
#   - all expansions quoted
#   - no eval / no string-interpolated jq filters (uses --arg only)
#   - shellcheck clean
#
# Runtime: bash + jq only (Python/Node forbidden — v3 §4.1).

set -euo pipefail

MIN_PRIOR_LEN=20
MIN_TOKEN_LEN=3          # bytes — skips KR josas / short function words
KEYWORDS=('틀렸' 'wrong' 'incorrect' '잘못')

emit() {
    # $1 = detected bool, $2 = reason, $3 (optional) = suggested_action
    local detected="$1" reason="$2" action="${3:-}"
    if [[ -n "$action" ]]; then
        jq -cn --argjson d "$detected" --arg r "$reason" --arg a "$action" \
            '{detected:$d, reason:$r, suggested_action:$a}'
    else
        jq -cn --argjson d "$detected" --arg r "$reason" \
            '{detected:$d, reason:$r}'
    fi
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

USER_UTTERANCE="$(printf '%s' "$INPUT" | jq -r '.tool_response.user_utterance // .tool_response.prompt // empty')"
PRIOR_TURN="$(printf '%s' "$INPUT" | jq -r '.tool_response.prior_assistant_turn // empty')"

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
# 5. Verdict.
# -----------------------------------------------------------------------------
reason="keyword='${matched_keyword}', shared='${shared}'"
emit true "$reason" "promotion_gate_user_correction"
exit 0

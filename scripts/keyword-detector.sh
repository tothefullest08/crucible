#!/usr/bin/env bash
# scripts/keyword-detector.sh — T-W6-04 · v3.3 §4.1 (Python 금지, 🚨 P0-1)
#
# references/ouroboros/scripts/keyword-detector.py → bash+jq 재작성.
# 로직 파리티: 원본 KEYWORD_MAP 순서·엔트리 그대로 유지.
#
# 입력:
#   (mode-1) stdin 텍스트 1건 (파리티 모드, 기본)
#   (mode-2) --file <jsonl>  — W1 extract-session.sh 재사용으로 턴 단위 매칭
#
# 출력 (stdout):
#   (mode-1) 감지 결과 JSON 1줄:
#             {"detected":bool, "keyword":str|null, "suggested_skill":str|null}
#   (mode-2) 매칭된 턴별 JSON 1줄씩 (감지된 턴만):
#             {"turn":N, "line":N, "keyword":..., "suggested_skill":...}
#
# 실패 조건:
#   - jq/bash<4 미설치 → exit 2
#   - 잘못된 플래그     → exit 1
#
# Safety (v3.3 §4.3):
#   - set -euo pipefail · 모든 변수 "$var" · eval 금지
#   - jq filter 문자열 보간 금지 (--arg / --argjson 만 사용)
#   - shellcheck clean

set -euo pipefail

# --- Runtime checks ----------------------------------------------------------
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
    echo "Error: bash >= 4.0 required (brew install bash)" >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq required (brew install jq)" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Regex helpers -----------------------------------------------------------

# Escape POSIX ERE metacharacters so pattern literals can be used inside
# a `grep -E` expression. The bracket expression matches: ] [ ( ) { } . *
# + ? ^ $ \ |  and each gets a literal backslash prefixed.
escape_ere() {
    printf '%s' "$1" | sed -e 's/[][(){}.*+?^$\\|]/\\&/g'
}

emit_match_stdin() {
    jq -cn --arg k "$1" --arg s "$2" \
        '{detected:true, keyword:$k, suggested_skill:$s}'
    exit 0
}

emit_nomatch_stdin() {
    jq -cn '{detected:false, keyword:null, suggested_skill:null}'
    exit 0
}

# Returns "keyword|||skill" on match, or empty string on no match.
# KEYWORD_MAP_RAW row format: "pat1|||pat2|||patN::/skill". Patterns never
# contain `::`, so parameter expansion splits cleanly.
match_text() {
    local text_lower="$1"
    local line entry_patterns entry_skill pat escaped

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        entry_patterns="${line%%::*}"
        entry_skill="${line#*::}"
        [[ "$entry_patterns" == "$line" ]] && continue
        local -a pats=()
        local pat_line
        while IFS= read -r pat_line; do
            [[ -n "$pat_line" ]] && pats+=("$pat_line")
        done < <(awk -v s="$entry_patterns" 'BEGIN{n=split(s, a, /\|\|\|/); for(i=1;i<=n;i++) print a[i]}')
        for pat in "${pats[@]}"; do
            [[ -z "$pat" ]] && continue
            escaped="$(escape_ere "$pat")"
            if grep -qE "(^|[^[:alnum:]_])${escaped}([^[:alnum:]_]|$)" <<<"$text_lower"; then
                printf '%s|||%s\n' "$pat" "$entry_skill"
                return 0
            fi
        done
    done <<<"$KEYWORD_MAP_RAW"

    # Bare "ooo" / "ooo?" fallthrough (mirrors keyword-detector.py).
    if [[ "$text_lower" == "ooo" || "$text_lower" == "ooo?" ]]; then
        printf 'ooo|||/ouroboros:welcome\n'
        return 0
    fi
    return 1
}

# KEYWORD_MAP_RAW — one entry per line. Format:
#   pat1|||pat2|||patN::/skill
# Order matches keyword-detector.py KEYWORD_MAP (priority).
# Ends at a line without `::` to allow trailing blank.
KEYWORD_MAP_RAW="$(cat <<'EOF'
ooo interview|||ooo socratic::/ouroboros:interview
ooo seed|||ooo crystallize::/ouroboros:seed
ooo run|||ooo execute::/ouroboros:run
ooo eval|||ooo evaluate::/ouroboros:evaluate
ooo evolve::/ouroboros:evolve
ooo stuck|||ooo unstuck|||ooo lateral::/ouroboros:unstuck
ooo status|||ooo drift::/ouroboros:status
ooo ralph::/ouroboros:ralph
ooo tutorial::/ouroboros:tutorial
ooo welcome::/ouroboros:welcome
ooo setup::/ouroboros:setup
ooo help::/ouroboros:help
ooo pm|||ooo prd::/ouroboros:pm
ooo qa|||qa check|||quality check::/ouroboros:qa
ooo cancel|||ooo abort::/ouroboros:cancel
ooo update|||ooo upgrade::/ouroboros:update
ooo brownfield::/ouroboros:brownfield
write prd|||pm interview|||product requirements|||create prd::/ouroboros:pm
interview me|||clarify requirements|||clarify my requirements|||socratic interview|||socratic questioning::/ouroboros:interview
crystallize|||generate seed|||create seed|||freeze requirements::/ouroboros:seed
ouroboros run|||execute seed|||run seed|||run workflow::/ouroboros:run
evaluate this|||3-stage check|||three-stage|||verify execution::/ouroboros:evaluate
evolve|||evolutionary loop|||iterate until converged::/ouroboros:evolve
think sideways|||i'm stuck|||im stuck|||i am stuck|||break through|||lateral thinking::/ouroboros:unstuck
am i drifting|||drift check|||session status|||check drift|||goal deviation::/ouroboros:status
ralph|||don't stop|||must complete|||until it works|||keep going::/ouroboros:ralph
ouroboros setup|||setup ouroboros::/ouroboros:setup
ouroboros help::/ouroboros:help
update ouroboros|||upgrade ouroboros::/ouroboros:update
cancel execution|||stop job|||kill stuck|||abort execution::/ouroboros:cancel
brownfield defaults|||brownfield scan::/ouroboros:brownfield
EOF
)"

# --- Mode dispatch -----------------------------------------------------------

MODE='stdin'
JSONL_PATH=''

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            MODE='file'
            JSONL_PATH="${2:-}"
            shift 2
            ;;
        -h|--help)
            cat <<'USAGE'
keyword-detector.sh — bash+jq port of ouroboros keyword-detector.py

Usage:
  keyword-detector.sh           # stdin text → detection JSON
  keyword-detector.sh --file <jsonl>  # per-turn matches from session JSONL

Output (stdin mode):
  {"detected":bool, "keyword":str|null, "suggested_skill":str|null}

Output (file mode):
  {"turn":N, "line":N, "keyword":..., "suggested_skill":...}  # one per match
USAGE
            exit 0
            ;;
        *)
            echo "Error: unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

normalize_text() {
    local text="$1"
    local lower
    lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"
    # strip leading/trailing whitespace (POSIX compatible)
    lower="${lower#"${lower%%[![:space:]]*}"}"
    lower="${lower%"${lower##*[![:space:]]}"}"
    printf '%s' "$lower"
}

if [[ "$MODE" == "stdin" ]]; then
    INPUT_TEXT="$(cat)"
    text_lower="$(normalize_text "$INPUT_TEXT")"
    if result="$(match_text "$text_lower")"; then
        kw="${result%%|||*}"
        skill="${result##*|||}"
        emit_match_stdin "$kw" "$skill"
    fi
    emit_nomatch_stdin
fi

# --- File mode (session JSONL) -----------------------------------------------

if [[ "$MODE" == "file" ]]; then
    if [[ ! -f "$JSONL_PATH" ]]; then
        echo "Error: JSONL file not found: $JSONL_PATH" >&2
        exit 1
    fi

    EXTRACTOR="${SCRIPT_DIR}/extract-session.sh"
    if [[ ! -x "$EXTRACTOR" ]]; then
        echo "Error: extract-session.sh not found: $EXTRACTOR" >&2
        exit 2
    fi

    # Parse turns via W1 extractor; filter prompt-v0 user turns.
    TURNS_JSON="$("$EXTRACTOR" "$JSONL_PATH" 2>/dev/null)"
    line_idx=0
    while IFS= read -r turn; do
        [[ -z "$turn" ]] && continue
        line_idx=$((line_idx + 1))
        role="$(jq -r '.role // empty' <<<"$turn")"
        [[ "$role" != "user" && "$role" != "prompt-v0" ]] && continue
        content="$(jq -r '.content | if type=="string" then . else tojson end' <<<"$turn")"
        turn_idx="$(jq -r '.turn_index // 0' <<<"$turn")"
        text_lower="$(normalize_text "$content")"
        if result="$(match_text "$text_lower")"; then
            kw="${result%%|||*}"
            skill="${result##*|||}"
            jq -cn \
                --argjson t "$turn_idx" \
                --argjson l "$line_idx" \
                --arg k "$kw" \
                --arg s "$skill" \
                '{turn:$t, line:$l, keyword:$k, suggested_skill:$s}'
        fi
    done < <(jq -c '.[]' <<<"$TURNS_JSON" 2>/dev/null || true)
fi

#!/usr/bin/env bash
# PostToolUse hook: re-injects the active skill/agent's `validate_prompt` self-check.
#
# Invoked from hooks/hooks.json on Task|Skill completion. Reads the PostToolUse
# payload from stdin, locates the SKILL.md / agent.md that was invoked, extracts
# the `validate_prompt` YAML field, and — when at least one required question
# keyword is missing from the tool_response — emits an advisory via stdout using
# the PostToolUse `additionalContext` envelope so Claude re-answers.
#
# Safety (v3.1 §4.3):
#   - set -euo pipefail
#   - no eval, no unquoted expansion
#   - ${CLAUDE_PLUGIN_ROOT} / name inputs validated against slug whitelist
#   - jq filters built with --arg, never string-interpolated
#
# Tooling: bash + jq + yq (Python/Node forbidden — v3 §4.1).

set -euo pipefail

# -----------------------------------------------------------------------------
# 1. Read payload, bail out fast on non-Task/Skill events.
# -----------------------------------------------------------------------------
INPUT="$(cat)"

if ! TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"; then
    exit 0
fi

if [[ "$TOOL_NAME" != "Task" && "$TOOL_NAME" != "Skill" ]]; then
    exit 0
fi

# -----------------------------------------------------------------------------
# 2. Resolve the skill/agent name from tool_input.
# -----------------------------------------------------------------------------
if [[ "$TOOL_NAME" == "Task" ]]; then
    NAME="$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // empty')"
    KIND="agent"
else
    NAME="$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // .tool_input.skill_name // empty')"
    KIND="skill"
fi

[[ -n "$NAME" ]] || exit 0

# Slug whitelist (v3.1 §4.3): allow only [a-zA-Z0-9_-] plus optional "plugin:"
# prefix and "/" namespacing. Rejects shell metacharacters and path traversal.
if ! [[ "$NAME" =~ ^[a-zA-Z0-9_./:-]+$ ]]; then
    exit 0
fi
if [[ "$NAME" == *".."* || "$NAME" == /* ]]; then
    exit 0
fi

# Strip a "plugin:" prefix if present — the file lookup uses the bare slug.
BARE_NAME="${NAME#*:}"

CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty')"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

# Validate CWD / PLUGIN_ROOT if supplied (same whitelist + absolute-path rule).
validate_path() {
    local p="$1"
    [[ -z "$p" ]] && return 0
    [[ "$p" == /* ]] || return 1
    [[ "$p" == *".."* ]] && return 1
    [[ "$p" =~ ^[a-zA-Z0-9_/.:-]+$ ]] || return 1
    return 0
}

validate_path "$CWD" || CWD=""
validate_path "$PLUGIN_ROOT" || PLUGIN_ROOT=""

# -----------------------------------------------------------------------------
# 3. Locate the skill/agent definition file.
# -----------------------------------------------------------------------------
find_file() {
    local name="$1" kind="$2"
    local -a candidates=()

    if [[ "$kind" == "skill" ]]; then
        [[ -n "$CWD"         ]] && candidates+=("$CWD/.claude/skills/$name/SKILL.md")
        [[ -n "$PLUGIN_ROOT" ]] && candidates+=("$PLUGIN_ROOT/skills/$name/SKILL.md")
        candidates+=("$HOME/.claude/skills/$name/SKILL.md")
    else
        [[ -n "$CWD"         ]] && candidates+=("$CWD/.claude/agents/$name.md")
        [[ -n "$PLUGIN_ROOT" ]] && candidates+=("$PLUGIN_ROOT/agents/$name.md")
        candidates+=("$HOME/.claude/agents/$name.md")
    fi

    local path
    for path in "${candidates[@]}"; do
        [[ -r "$path" ]] && { printf '%s\n' "$path"; return 0; }
    done
    return 1
}

FILE="$(find_file "$BARE_NAME" "$KIND" 2>/dev/null)" || exit 0

# -----------------------------------------------------------------------------
# 4. Extract validate_prompt from YAML frontmatter via yq.
#     - Slice the frontmatter between the first pair of `---` lines with awk.
#     - Pipe to `yq eval '.validate_prompt'` to resolve multiline/scalar forms.
# -----------------------------------------------------------------------------
extract_validate_prompt() {
    local file="$1"
    awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$file" \
        | yq '.validate_prompt // ""' - 2>/dev/null
}

VALIDATE_PROMPT="$(extract_validate_prompt "$FILE")"
VALIDATE_PROMPT="${VALIDATE_PROMPT%$'\n'}"

if [[ -z "$VALIDATE_PROMPT" || "$VALIDATE_PROMPT" == "null" ]]; then
    exit 0
fi

# -----------------------------------------------------------------------------
# 5. Gap detection — derive required keywords from each numbered question line
#    and check presence in tool_response. A line counts as "answered" when at
#    least one of its quoted / parenthetical anchor keywords appears in the
#    response text.
# -----------------------------------------------------------------------------
TOOL_RESPONSE="$(printf '%s' "$INPUT" | jq -r '.tool_response // "" | if type=="string" then . else tostring end')"

missing_lines=()

# Iterate each numbered check line of validate_prompt.
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Only consider lines that start with a digit + "." — the actual check items.
    [[ "$line" =~ ^[[:space:]]*[0-9]+\. ]] || continue

    # Pull candidate anchor tokens: quoted phrases and parenthetical tags.
    # shellcheck disable=SC2016  # backticks here are literal regex, not command subs
    anchors="$(printf '%s\n' "$line" \
        | grep -oE '"[^"]+"|\([^)]+\)|`[^`]+`' \
        | sed -e 's/^"//' -e 's/"$//' -e 's/^(//' -e 's/)$//' -e 's/^`//' -e 's/`$//' \
        || true)"

    # Fallback anchor: the first 8 non-whitespace Korean/English word characters
    # after the leading number — keeps per-line matching meaningful even without
    # explicit quotes.
    if [[ -z "$anchors" ]]; then
        anchors="$(printf '%s\n' "$line" \
            | sed -E 's/^[[:space:]]*[0-9]+\.[[:space:]]*//' \
            | cut -c1-24)"
    fi

    hit="no"
    while IFS= read -r anchor; do
        [[ -z "$anchor" ]] && continue
        if printf '%s' "$TOOL_RESPONSE" | grep -Fq -- "$anchor"; then
            hit="yes"
            break
        fi
    done <<< "$anchors"

    if [[ "$hit" == "no" ]]; then
        missing_lines+=("$line")
    fi
done <<< "$VALIDATE_PROMPT"

# -----------------------------------------------------------------------------
# 6. If at least one check is missing, emit the advisory as additionalContext.
#    Otherwise exit 0 silently.
# -----------------------------------------------------------------------------
if [[ ${#missing_lines[@]} -eq 0 ]]; then
    exit 0
fi

missing_text=""
for l in "${missing_lines[@]}"; do
    missing_text+="${l}"$'\n'
done

# shellcheck disable=SC2016  # backticks here are literal Markdown code marks
CONTEXT=$(printf '⚠️ VALIDATION REQUIRED for %s: %s\n\nThe following self-check items from `validate_prompt` were not addressed in the response:\n\n%s\nPlease answer each unresolved item before proceeding to the next phase.' \
    "$KIND" "$BARE_NAME" "$missing_text")

CTX="$CONTEXT" jq -n '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: env.CTX
  }
}'

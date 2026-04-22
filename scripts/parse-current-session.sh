#!/usr/bin/env bash
# parse-current-session.sh — extract dogfood structured events from the
# current Claude Code session JSONL.
#
# The parser emits four event types, one JSONL line per event, to stdout:
#
#   skill_call      — user invocations of /crucible:* slash commands, and
#                     tool_use entries with name == "Skill".
#                     Recursion filter: /crucible:dogfood itself is dropped so
#                     repeated invocations don't pollute their own output.
#   promotion_gate  — AskUserQuestion tool_use whose question mentions
#                     "승격" / "promotion" / "저장할까요" (compound gate UX).
#   axis_skip       — tool_use input containing "--skip-axis" plus an
#                     optional "--acknowledge-risk" marker (axis 5 policy).
#   qa_judge        — tool_result bodies carrying a JSON blob with
#                     {"score": <float>, "verdict": <string>} (qa-judge /verify
#                     output).
#
# Usage:
#   scripts/parse-current-session.sh                      # auto-detect from $PWD
#   scripts/parse-current-session.sh <path/to/session.jsonl>
#
# Auto-detect rule: encode "$PWD" as ~/.claude/projects/ slug (/→-) and
# pick the file with the most recent mtime. Missing directory → exit 1,
# empty directory → exit 1, no events parsed → exit 0 with zero output.
#
# Runtime: bash + jq + awk + find. No Python/Node.
# Safety: set -euo pipefail, all vars quoted, no eval, shellcheck clean.

set -euo pipefail

# --- dependencies -----------------------------------------------------------

for tool in jq find awk sed; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'parse-current-session: %s is required on PATH\n' "$tool" >&2
        exit 2
    fi
done

# --- locate session file ----------------------------------------------------

session_file="${1:-}"

if [[ -z "$session_file" ]]; then
    encoded="$(printf '%s' "$PWD" | sed 's|/|-|g')"
    projects_dir="${HOME}/.claude/projects/${encoded}"
    if [[ ! -d "$projects_dir" ]]; then
        printf 'parse-current-session: no projects dir at %s\n' "$projects_dir" >&2
        exit 1
    fi
    # most recent *.jsonl by mtime
    session_file="$(find "$projects_dir" -maxdepth 1 -type f -name '*.jsonl' \
        -exec stat -f '%m %N' {} + 2>/dev/null \
        | LC_ALL=C sort -nr | awk 'NR==1 { $1=""; sub(/^ /,""); print }')"
    if [[ -z "$session_file" ]]; then
        printf 'parse-current-session: no *.jsonl files in %s\n' "$projects_dir" >&2
        exit 1
    fi
fi

if [[ ! -f "$session_file" ]]; then
    printf 'parse-current-session: file not found: %s\n' "$session_file" >&2
    exit 1
fi

# --- extract events via jq --------------------------------------------------
#
# The JSONL is streamed once; jq emits zero or more events per input line.
# Recursion filter lives inside the jq program so no separate pass is needed.
#
# schema notes (observed 2026-04-22):
#   user line       : { type: "user", message: { content: "string" | array }, timestamp }
#   assistant line  : { type: "assistant", message: { content: [ ... ] }, timestamp }
#     tool_use      :   { type: "tool_use", name, input, id }
#   tool_result line: { type: "user", message: { content: [ { tool_use_id, content, ... } ] } }

jq -rc '
    def ts_of: (.timestamp // .ts // "unknown");

    def text_of(x):
        if (x | type) == "string" then x
        elif (x | type) == "array" then
            [x[]? | if (type) == "string" then . elif .type == "text" then (.text // "") else "" end]
            | join(" ")
        elif (x | type) == "object" then (x.text // "")
        else ""
        end;

    def emit_skill_call(ts; skill; summary):
        if (skill | startswith("/crucible:dogfood")) or skill == "/dogfood" or skill == "dogfood" then empty
        else { ts: ts, type: "skill_call", skill: skill, args_summary: summary } end;

    # user-typed slash command invocations
    (
      select(.type == "user")
      | (text_of(.message.content)) as $txt
      | ts_of as $ts
      | if ($txt | test("(^|\\s)/crucible:[a-z_-]+"; "i")) then
            ($txt | capture("(?<cmd>/crucible:[a-z_-]+)(?<args>[^\\n]*)")) as $m
            | emit_skill_call($ts; $m.cmd; ($m.args | .[0:80]))
        else empty end
    ),
    # structured tool_use events from assistant turns
    (
      select(.type == "assistant")
      | ts_of as $ts
      | .message.content[]?
      | select(.type == "tool_use")
      | . as $tu
      | (
          # Skill tool invocations
          if $tu.name == "Skill" then
              (($tu.input.skill // "unknown") | tostring) as $sname
              | emit_skill_call($ts; ("/" + $sname); (($tu.input.args // "") | tostring | .[0:80]))
          # axis_skip via Bash arguments containing --skip-axis
          elif $tu.name == "Bash" and (($tu.input.command // "") | test("--skip-axis")) then
              ($tu.input.command // "") as $cmd
              | ($cmd | capture("--skip-axis[= ](?<n>[0-9]+)") | .n | tonumber? // null) as $axis
              | { ts: $ts, type: "axis_skip",
                  axis: $axis,
                  acknowledged: ($cmd | test("--acknowledge-risk")),
                  reason: ($cmd | .[0:120]) }
          # promotion_gate via AskUserQuestion wording
          elif $tu.name == "AskUserQuestion" then
              ($tu.input | tostring) as $payload
              | if ($payload | test("승격|promotion|저장할까요|promote candidate"; "i")) then
                    { ts: $ts, type: "promotion_gate",
                      candidate_id: null,
                      response: null,
                      detector: "prompt_match" }
                else empty end
          else empty end
        )
    ),
    # qa_judge via tool_result bodies containing {"score":..,"verdict":..}
    (
      select(.type == "user")
      | ts_of as $ts
      | .message.content[]?
      | select(.type? == "tool_result")
      | (text_of(.content)) as $body
      | if ($body | test("\"score\"\\s*:") and ($body | test("\"verdict\"\\s*:"))) then
            ($body | capture("\"score\"\\s*:\\s*(?<s>[0-9.]+)[\\s\\S]*?\"verdict\"\\s*:\\s*\"(?<v>[a-zA-Z_]+)\"")) as $m
            | { ts: $ts, type: "qa_judge",
                score: ($m.s | tonumber? // null),
                verdict: $m.v }
        else empty end
    )
' "$session_file" 2>/dev/null || true

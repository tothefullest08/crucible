#!/usr/bin/env bash
# pretool-block-danger.sh — block destructive Bash commands before execution.
# stdin: PreToolUse JSON payload.
# stdout: hookSpecificOutput with permissionDecision=allow|deny (Claude Code >= v2.1 schema).

set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

# Non-Bash invocation or empty command: let through.
if [ -z "$cmd" ]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow"}}'
  exit 0
fi

block_with() {
  jq -n --arg c "$cmd" --arg why "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("Blocked by pretool-block-danger (" + $why + "): " + $c)}}'
}

# rm -rf against root or absolute-root-adjacent paths.
# shellcheck disable=SC2016  # $HOME is regex text for grep, not a shell expansion.
if printf '%s' "$cmd" | grep -qE '(^|[^a-zA-Z0-9_])rm[[:space:]]+(-[rRfF]+[[:space:]]*)+(/|/\*|~|\$HOME|\$\{HOME\})([[:space:]]|$)'; then
  block_with "rm -rf against root/home"
  exit 0
fi

# git push --force on any branch — require explicit user confirmation instead.
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push[[:space:]].*(-f([[:space:]]|$)|--force([[:space:]]|$)|--force-with-lease([[:space:]]|$))'; then
  block_with "git push --force"
  exit 0
fi

# Classic fork bomb.
if printf '%s' "$cmd" | grep -qE ':[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:[[:space:]]*&[[:space:]]*\}[[:space:]]*;[[:space:]]*:'; then
  block_with "fork bomb"
  exit 0
fi

# dd to /dev/sd* or /dev/nvme* raw block devices.
if printf '%s' "$cmd" | grep -qE 'dd[[:space:]].*of=/dev/(sd[a-z]|nvme|disk)'; then
  block_with "dd to raw block device"
  exit 0
fi

jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow"}}'

#!/usr/bin/env bash
# pretool-block-secrets.sh — block writes to sensitive-file patterns before the tool runs.
# stdin: PreToolUse JSON payload.
# stdout: hookSpecificOutput with permissionDecision=allow|deny (Claude Code >= v2.1 schema).

set -euo pipefail

input="$(cat)"

path="$(jq -r '.tool_input.file_path // .tool_input.path // empty' <<<"$input")"

# Empty path = not a file-writing invocation; let it through.
if [ -z "$path" ]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow"}}'
  exit 0
fi

# Case-insensitive match on the basename.
# The full path doesn't need a separate check: any suspicious file lands in
# basename patterns (`id_rsa`, `.env`, `credentials`, `*.pem`, `*.key`).
base="$(basename "$path")"
lower_base="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"

blocked=0
case "$lower_base" in
  .env|.env.*|*.env|credentials|credentials.*|*.credentials.* )
    blocked=1 ;;
  *secrets*|*.pem|*.key|id_rsa|id_rsa.*|id_ed25519|id_ed25519.*|id_ecdsa|id_ecdsa.* )
    blocked=1 ;;
esac

if [ "$blocked" -eq 1 ]; then
  jq -n --arg p "$path" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("Blocked by pretool-block-secrets: " + $p + " matches a sensitive-file pattern (.env / credentials / keys / secrets). If this is intentional, move the file or rename it, then retry.")}}'
  exit 0
fi

jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow"}}'

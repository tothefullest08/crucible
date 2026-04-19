#!/usr/bin/env bash
# Fixture: should PASS every rule in custom-security-linter.sh.
# - every variable expansion is double-quoted
# - no eval
# - path construction uses a slug-whitelisted variable

set -euo pipefail

greeting="hello"
printf '%s\n' "${greeting}"

# Path construction with env-var + whitelist validation regex present
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    root="${CLAUDE_PLUGIN_ROOT}"
else
    root="$(pwd)"
fi

path_whitelist='^[a-zA-Z0-9_./~-]+$'
if [[ "${root}" =~ ${path_whitelist} ]]; then
    printf 'root=%s\n' "${root}"
fi

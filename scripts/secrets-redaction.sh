#!/usr/bin/env bash
# scripts/secrets-redaction.sh — T-W4-06 · 🚨 P0-5 · v3.2 §4.3.1
#
# Reads text from stdin, drops any line (= "turn" in the redaction context) that
# matches one of the 7 universal secret patterns, and writes the sanitized text
# to stdout. The count of dropped lines is emitted to stderr as
# `{redacted: N}` so downstream tooling (W5 MEMORY.md accumulation) can pick
# it up without parsing stdout.
#
# Runtime: bash + grep (BRE/ERE) only. Python/Node forbidden — v3 §4.1.
#
# Per v3.2 §4.3.1: on any match the ENTIRE line is dropped — partial-line
# redaction is deliberately avoided so that surrounding context cannot be used
# to reconstruct the secret.
#
# The 7 patterns (see prompts/w4-sprint1-p2-prompt.md §T-W4-06):
#   1. AWS Access Key        : AKIA[0-9A-Z]{16}
#   2. GCP API Key           : AIza[0-9A-Za-z_-]{35}
#   3. GitHub PAT            : gh[ops]_[0-9A-Za-z]{36}
#   4. Slack Token           : xox[baprs]-[0-9A-Za-z-]{10,}
#   5. JWT                   : eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+
#   6. DB URL w/ creds       : (postgres|postgresql|mysql|mongodb|redis)://[^[:space:]@]+@[^[:space:]/]+
#   7. Bearer Token          : Bearer[[:space:]]+[A-Za-z0-9._~/+-]{20,}=*

set -euo pipefail

PATTERNS=(
    'AKIA[0-9A-Z]{16}'
    'AIza[0-9A-Za-z_-]{35}'
    'gh[ops]_[0-9A-Za-z]{36}'
    'xox[baprs]-[0-9A-Za-z-]{10,}'
    'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
    '(postgres|postgresql|mysql|mongodb|redis)://[^[:space:]@]+@[^[:space:]/]+'
    'Bearer[[:space:]]+[A-Za-z0-9._~/+-]{20,}=*'
)

combined=''
for p in "${PATTERNS[@]}"; do
    if [[ -z "${combined}" ]]; then
        combined="${p}"
    else
        combined="${combined}|${p}"
    fi
done

redacted=0
while IFS= read -r line || [[ -n "${line}" ]]; do
    if printf '%s' "${line}" | grep -Eq -- "${combined}"; then
        redacted=$((redacted + 1))
        continue
    fi
    printf '%s\n' "${line}"
done

printf '{redacted: %d}\n' "${redacted}" >&2
exit 0

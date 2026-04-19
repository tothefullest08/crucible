#!/usr/bin/env bash
# __tests__/security/test-secrets-redaction.sh — T-W4-06 unit test.
#
# 7 patterns × (3 positive + 1 negative) = 28 cases total.
# Positive cases expect the line to be dropped (sanitized stdout is empty).
# Negative cases expect the line to be passed through unchanged.
#
# Also asserts the `{redacted: N}` sidecar on stderr matches the number of
# positive cases within each pattern batch (light accumulation check).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "${script_dir}/../.." && pwd)"
redact="${plugin_root}/scripts/secrets-redaction.sh"

total=0
pass=0
fail=0

# Run redaction on a single-line input; return stdout and stderr separately.
_run() {
    local input="$1"
    local stdout_file stderr_file
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"
    printf '%s\n' "${input}" | bash "${redact}" >"${stdout_file}" 2>"${stderr_file}" || true
    __stdout="$(cat "${stdout_file}")"
    __stderr="$(cat "${stderr_file}")"
    rm -f "${stdout_file}" "${stderr_file}"
}

assert_drop() {
    local label="$1" input="$2"
    total=$((total + 1))
    _run "${input}"
    if [[ -z "${__stdout}" ]]; then
        if printf '%s' "${__stderr}" | grep -Fq '{redacted: 1}'; then
            pass=$((pass + 1))
            printf 'PASS (drop): %s\n' "${label}"
        else
            printf 'FAIL (drop): %s — dropped but {redacted} sidecar wrong: %s\n' \
                "${label}" "${__stderr}" >&2
            fail=$((fail + 1))
        fi
    else
        printf 'FAIL (drop): %s — expected empty stdout, got: %q\n' "${label}" "${__stdout}" >&2
        fail=$((fail + 1))
    fi
}

assert_keep() {
    local label="$1" input="$2"
    total=$((total + 1))
    _run "${input}"
    if [[ "${__stdout}" == "${input}" ]]; then
        if printf '%s' "${__stderr}" | grep -Fq '{redacted: 0}'; then
            pass=$((pass + 1))
            printf 'PASS (keep): %s\n' "${label}"
        else
            printf 'FAIL (keep): %s — kept but {redacted} sidecar wrong: %s\n' \
                "${label}" "${__stderr}" >&2
            fail=$((fail + 1))
        fi
    else
        printf 'FAIL (keep): %s — expected %q, got %q\n' "${label}" "${input}" "${__stdout}" >&2
        fail=$((fail + 1))
    fi
}

# 1. AWS Access Key: AKIA[0-9A-Z]{16}
assert_drop 'AWS pos 1 (classic example)' 'AWS key AKIAIOSFODNN7EXAMPLE in log'
assert_drop 'AWS pos 2 (all uppercase pad)' 'use=AKIAZZZZZZZZZZZZ1234'
assert_drop 'AWS pos 3 (inline)' 'cfg AKIAABCDEFGHIJKLMNOP today'
assert_keep 'AWS neg  (too short)' 'AKIA123'

# 2. GCP API Key: AIza[0-9A-Za-z_-]{35}
assert_drop 'GCP pos 1 (SyDk style)' 'key AIzaSyDkVvFakeExampleKey_abcdefghijklmnop1234'
assert_drop 'GCP pos 2 (alnum tail)' 'tok AIza0123456789abcdefghijklmnopqrstuvwxyzXYZ'
assert_drop 'GCP pos 3 (dashes/underscores)' 'k=AIza____-----0123456789ABCDEFGHIJKLMNOPQRSTU'
assert_keep 'GCP neg  (too short)' 'AIza123'

# 3. GitHub PAT: gh[ops]_[0-9A-Za-z]{36}
assert_drop 'GH pos 1 (ghp_)' 'ghp_abcdefghijklmnopqrstuvwxyz0123456789ABC'
assert_drop 'GH pos 2 (gho_)' 'token gho_1234567890abcdefghijklmnopqrstuvwxyzABC'
assert_drop 'GH pos 3 (ghs_)' 'ghs_ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ'
assert_keep 'GH neg  (too short)' 'ghp_123'

# 4. Slack Token: xox[baprs]-[0-9A-Za-z-]{10,}
assert_drop 'Slack pos 1 (xoxb)' 'xoxb-1234567890'
assert_drop 'Slack pos 2 (xoxp)' 'Auth xoxp-ABCDEFGHIJ-abc'
assert_drop 'Slack pos 3 (xoxs multi-dash)' 'xoxs-0000-1111-2222-aaaa'
assert_keep 'Slack neg (too short)' 'xoxb-123'

# 5. JWT: eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+
assert_drop 'JWT pos 1 (full triple)' 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.AbCdEf'
assert_drop 'JWT pos 2 (inline)' 'Auth: eyJabc.eyJdef.sig123'
assert_drop 'JWT pos 3 (long segments)' 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiamFuZSJ9.x_y-z'
assert_keep 'JWT neg (single segment)' 'eyJnot-a-jwt'

# 6. DB URL with embedded creds:
#    (postgres|postgresql|mysql|mongodb|redis)://[^[:space:]@]+@[^[:space:]/]+
assert_drop 'DB pos 1 (postgres)' 'DATABASE_URL=postgres://user:pass@localhost:5432/db'
assert_drop 'DB pos 2 (mysql)' 'mysql://admin:secret@db.example.com'
assert_drop 'DB pos 3 (mongodb)' 'mongodb://root:top_secret@mongo.prod:27017'
assert_keep 'DB neg (http scheme)' 'http://no-match.example.com/path'

# 7. Bearer: Bearer[[:space:]]+[A-Za-z0-9._~/+-]{20,}=*
assert_drop 'Bearer pos 1 (classic)' 'Authorization: Bearer abcdefghijklmnopqrstuvwxyz123'
assert_drop 'Bearer pos 2 (alnum tail)' 'Bearer 0123456789ABCDEFGHIJKLMNOPqrst'
assert_drop 'Bearer pos 3 (padded)'    'Bearer  aaaaaaaaaaaaaaaaaaaaaaaaa='
assert_keep 'Bearer neg (too short)'   'Bearer abc'

printf '\n%d/%d passed\n' "${pass}" "${total}"
[[ "${fail}" -eq 0 ]] || exit 1

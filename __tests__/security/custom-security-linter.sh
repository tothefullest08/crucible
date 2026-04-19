#!/usr/bin/env bash
# Custom security linter for hooks/*.sh and related bash scripts.
# Implements final-spec v3.1 §4.3 security constraints:
#   R1) every $var-style expansion must be double-quoted
#   R2) zero `eval` usage
#   R3) path construction from env vars must be guarded by a slug whitelist regex
#
# Usage: custom-security-linter.sh <file> [<file>...]
# Exit: 0 = all rules pass, 1 = at least one violation.

set -uo pipefail

fail_count=0

strip_comments() {
    # Remove everything after a `#` on each line so in-source comments can
    # safely reference forbidden tokens (e.g. the word "eval") for documentation.
    local file="$1"
    sed 's/#.*$//' "${file}"
}

rule_quoted_vars() {
    local file="$1"
    local violations
    violations="$(
        strip_comments "${file}" \
            | grep -nE '\$[a-zA-Z_]' \
            | grep -vE '"\$[a-zA-Z_]' \
            || true
    )"
    if [[ -n "${violations}" ]]; then
        printf '  [R1] unquoted variable expansion in %s\n' "${file}"
        printf '%s\n' "${violations}" | sed 's/^/        /'
        return 1
    fi
    return 0
}

rule_no_eval() {
    local file="$1"
    local violations
    violations="$(
        strip_comments "${file}" \
            | grep -nwE 'eval' \
            || true
    )"
    if [[ -n "${violations}" ]]; then
        printf '  [R2] eval usage detected in %s\n' "${file}"
        printf '%s\n' "${violations}" | sed 's/^/        /'
        return 1
    fi
    return 0
}

rule_slug_whitelist() {
    local file="$1"
    local stripped
    stripped="$(strip_comments "${file}")"

    # Flag files that interpolate env-var paths (${CLAUDE_*}, ${HARNESS_*}, ${HOME})
    # without declaring a slug whitelist regex (pattern `[a-zA-Z0-9`) somewhere.
    local uses_env_path
    uses_env_path="$(
        printf '%s\n' "${stripped}" \
            | grep -cE '"\$\{(CLAUDE_[A-Z_]+|HARNESS_[A-Z_]+|HOME)(\}|:-)' \
            || true
    )"
    local has_whitelist
    has_whitelist="$(
        printf '%s\n' "${stripped}" \
            | grep -cE '\[a-zA-Z0-9' \
            || true
    )"

    if [[ "${uses_env_path}" -gt 0 && "${has_whitelist}" -eq 0 ]]; then
        printf '  [R3] env-var path interpolation without slug whitelist in %s\n' "${file}"
        return 1
    fi
    return 0
}

lint_file() {
    local file="$1"
    local file_fail=0
    rule_quoted_vars  "${file}" || file_fail=1
    rule_no_eval      "${file}" || file_fail=1
    rule_slug_whitelist "${file}" || file_fail=1
    if [[ "${file_fail}" -eq 0 ]]; then
        printf '  PASS %s\n' "${file}"
    fi
    return "${file_fail}"
}

main() {
    if [[ "$#" -eq 0 ]]; then
        printf 'usage: %s <file> [<file>...]\n' "$0" >&2
        exit 2
    fi

    for target in "$@"; do
        if [[ ! -r "${target}" ]]; then
            printf '  MISS %s (not readable)\n' "${target}" >&2
            fail_count=$((fail_count + 1))
            continue
        fi
        if ! lint_file "${target}"; then
            fail_count=$((fail_count + 1))
        fi
    done

    if [[ "${fail_count}" -gt 0 ]]; then
        printf 'custom-security-linter: %d file(s) failed\n' "${fail_count}" >&2
        exit 1
    fi
    exit 0
}

main "$@"

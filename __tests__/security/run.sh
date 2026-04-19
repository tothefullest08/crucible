#!/usr/bin/env bash
# Entry point for T-W1-09 security tests (CI calls this).
#
# Two phases:
#   A) Real hooks/*.sh must pass shellcheck + custom linter (all 3 rules).
#   B) Fixtures under __tests__/security/fixtures/ behave as their filename advertises:
#        - good.sh          -> PASS
#        - bad-unquoted.sh  -> FAIL rule R1 (quoted vars)
#        - bad-eval.sh      -> FAIL rule R2 (no eval)
#
# Exit: 0 on success, non-zero otherwise.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

shellcheck_runner="${script_dir}/shellcheck-runner.sh"
linter="${script_dir}/custom-security-linter.sh"
fixtures_dir="${script_dir}/fixtures"

pass_count=0
fail_count=0

record_pass() { pass_count=$((pass_count + 1)); printf '[PASS] %s\n' "$1"; }
record_fail() { fail_count=$((fail_count + 1)); printf '[FAIL] %s\n' "$1" >&2; }

# ---- Phase A: real hooks ------------------------------------------------------
printf '\n== Phase A: hooks/*.sh ==\n'

hooks_dir="${repo_root}/hooks"
if [[ -d "${hooks_dir}" ]]; then
    if bash "${shellcheck_runner}" "${hooks_dir}"; then
        record_pass 'shellcheck clean on hooks/*.sh'
    else
        record_fail 'shellcheck violations in hooks/*.sh'
    fi

    mapfile -t hook_scripts < <(find "${hooks_dir}" -type f -name '*.sh' 2>/dev/null)
    if [[ "${#hook_scripts[@]}" -gt 0 ]]; then
        if bash "${linter}" "${hook_scripts[@]}"; then
            record_pass 'custom-security-linter clean on hooks/*.sh'
        else
            record_fail 'custom-security-linter violations in hooks/*.sh'
        fi
    else
        printf '[SKIP] no *.sh under hooks/ yet\n'
    fi
else
    record_fail "hooks/ directory not found at ${hooks_dir}"
fi

# ---- Phase B: fixtures --------------------------------------------------------
printf '\n== Phase B: fixtures ==\n'

expect_pass() {
    local label="$1"; shift
    if bash "${linter}" "$@" >/dev/null 2>&1; then
        record_pass "${label}"
    else
        record_fail "${label} (expected PASS but linter returned non-zero)"
    fi
}

expect_fail() {
    local label="$1"; shift
    if bash "${linter}" "$@" >/dev/null 2>&1; then
        record_fail "${label} (expected FAIL but linter returned zero)"
    else
        record_pass "${label}"
    fi
}

expect_pass 'fixture good.sh         -> linter PASS' "${fixtures_dir}/good.sh"
expect_fail 'fixture bad-unquoted.sh -> linter FAIL' "${fixtures_dir}/bad-unquoted.sh"
expect_fail 'fixture bad-eval.sh     -> linter FAIL' "${fixtures_dir}/bad-eval.sh"

# ---- Summary ------------------------------------------------------------------
printf '\n== Summary ==\n'
printf '  passed: %d\n' "${pass_count}"
printf '  failed: %d\n' "${fail_count}"

if [[ "${fail_count}" -gt 0 ]]; then
    exit 1
fi
exit 0

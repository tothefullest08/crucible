#!/usr/bin/env bash
# AC-2 Hard Gate integration test.
#
# Exercises hooks/validate-output.sh against 10 brainstorm fixtures:
#   - 4 PASS cases (complete self-answers)  -> expect no advisory
#   - 6 FAIL cases (each missing one item)  -> expect advisory
#
# PASS criterion: correct classifications >= 9/10.
#
# The hook always exits 0 (Claude Code hook contract); the advisory is emitted
# on stdout as a `hookSpecificOutput.additionalContext` JSON envelope. We detect
# that envelope rather than rely on exit status.
#
# Exit: 0 = AC-2 PASS, 1 = AC-2 FAIL.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

fixtures_dir="${repo_root}/__tests__/fixtures/validate-prompt"
hook="${repo_root}/hooks/validate-output.sh"

if ! command -v jq >/dev/null 2>&1; then
    printf 'integration: jq is required on PATH\n' >&2
    exit 1
fi
if ! command -v yq >/dev/null 2>&1; then
    printf 'integration: yq is required on PATH\n' >&2
    exit 1
fi
if [[ ! -x "${hook}" ]]; then
    printf 'integration: hook missing or not executable: %s\n' "${hook}" >&2
    exit 1
fi
if [[ ! -d "${fixtures_dir}" ]]; then
    printf 'integration: fixtures dir missing: %s\n' "${fixtures_dir}" >&2
    exit 1
fi

# The hook needs CLAUDE_PLUGIN_ROOT to locate skills/brainstorm/SKILL.md.
export CLAUDE_PLUGIN_ROOT="${repo_root}"

pass=0
total=0
failures=()

for fixture in "${fixtures_dir}"/*.json; do
    [[ -r "${fixture}" ]] || continue
    total=$((total + 1))

    expected="$(jq -r '.expected' "${fixture}" 2>/dev/null)"
    if [[ "${expected}" != "advisory" && "${expected}" != "none" ]]; then
        printf '[SKIP] %s — missing .expected field\n' "$(basename "${fixture}")" >&2
        continue
    fi

    # Strip helper fields before feeding the payload to the hook.
    payload="$(jq 'del(.expected, ._note)' "${fixture}")"

    # Capture hook stdout; rely on it (not exit code) for the classification.
    output="$(printf '%s' "${payload}" | bash "${hook}" 2>/dev/null || true)"

    if [[ -n "${output}" ]] \
        && printf '%s' "${output}" \
            | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
        actual="advisory"
    else
        actual="none"
    fi

    if [[ "${actual}" == "${expected}" ]]; then
        pass=$((pass + 1))
        printf '[PASS] %-50s expected=%-8s actual=%s\n' \
            "$(basename "${fixture}")" "${expected}" "${actual}"
    else
        failures+=("$(basename "${fixture}") expected=${expected} actual=${actual}")
        printf '[FAIL] %-50s expected=%-8s actual=%s\n' \
            "$(basename "${fixture}")" "${expected}" "${actual}" >&2
    fi
done

printf '\n== Summary ==\n'
printf '  Accuracy: %d/%d\n' "${pass}" "${total}"

if [[ "${total}" -lt 10 ]]; then
    printf '\nAC-2 FAIL (fixture count < 10)\n' >&2
    exit 1
fi

if [[ "${pass}" -ge 9 ]]; then
    printf '\nAC-2 PASS\n'
    exit 0
fi

printf '\nAC-2 FAIL (< 9/10)\n' >&2
for f in "${failures[@]}"; do
    printf '  - %s\n' "${f}" >&2
done
exit 1

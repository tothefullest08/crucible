#!/usr/bin/env bash
# Static-analysis runner — wraps shellcheck to enforce zero warnings
# across every hooks/*.sh script in the repository.
#
# Usage: shellcheck-runner.sh [<dir>]
#   default <dir> = hooks
# Exit: 0 = clean, 1 = at least one warning, 2 = shellcheck missing.

set -uo pipefail

target_dir="${1:-hooks}"

if ! command -v shellcheck >/dev/null 2>&1; then
    printf 'shellcheck-runner: shellcheck binary not found on PATH\n' >&2
    exit 2
fi

fail_count=0
file_count=0

while IFS= read -r -d '' script; do
    file_count=$((file_count + 1))
    if shellcheck "${script}"; then
        printf '  PASS shellcheck %s\n' "${script}"
    else
        printf '  FAIL shellcheck %s\n' "${script}"
        fail_count=$((fail_count + 1))
    fi
done < <(find "${target_dir}" -type f -name '*.sh' -print0 2>/dev/null)

if [[ "${file_count}" -eq 0 ]]; then
    printf 'shellcheck-runner: no *.sh files under %s\n' "${target_dir}" >&2
    exit 0
fi

if [[ "${fail_count}" -gt 0 ]]; then
    printf 'shellcheck-runner: %d of %d file(s) failed\n' "${fail_count}" "${file_count}" >&2
    exit 1
fi

printf 'shellcheck-runner: %d file(s) clean\n' "${file_count}"
exit 0

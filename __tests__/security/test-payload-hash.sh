#!/usr/bin/env bash
# T-W4-05 verification (v3.2 §4.3.5):
# For each tracked payload file, tamper it in an isolated plugin_root copy and
# assert that hooks/session-start.sh emits a "payload hash mismatch for <path>"
# warning via stderr. 3/3 mismatches must be detected.
#
# Also asserts that SKILL.md tampering causes injection to be skipped (no
# payload on stdout), while non-SKILL mismatches still warn but still inject.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "${script_dir}/../.." && pwd)"
session_start="${plugin_root}/hooks/session-start.sh"
fixtures_dir="${script_dir}/fixtures/hash-mismatch"

TRACKED=(
    "skills/using-harness/SKILL.md"
    "hooks/session-start.sh"
    "hooks/validate-output.sh"
)

fixture_for() {
    case "$1" in
        "skills/using-harness/SKILL.md")   printf '%s' "${fixtures_dir}/SKILL.md.tampered" ;;
        "hooks/session-start.sh")          printf '%s' "${fixtures_dir}/session-start.sh.tampered" ;;
        "hooks/validate-output.sh")        printf '%s' "${fixtures_dir}/validate-output.sh.tampered" ;;
        *) return 1 ;;
    esac
}

compute_sha256() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "${file}" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${file}" | awk '{print $1}'
    else
        printf ''
    fi
}

total=0
pass=0
fail=0

# Build a reusable baseline plugin_root mirror with fresh hashes, so the test
# is robust to whether plugin.json happens to be in sync on disk.
baseline="$(mktemp -d)"
mkdir -p "${baseline}/.claude-plugin"
cp "${plugin_root}/.claude-plugin/plugin.json" "${baseline}/.claude-plugin/plugin.json"

tmp_manifest="$(mktemp)"
jq '.harness = (.harness // {}) | .harness.payload_sha256 = {}' \
    "${baseline}/.claude-plugin/plugin.json" > "${tmp_manifest}"

for rel in "${TRACKED[@]}"; do
    mkdir -p "${baseline}/$(dirname "${rel}")"
    cp "${plugin_root}/${rel}" "${baseline}/${rel}"
    h="$(compute_sha256 "${plugin_root}/${rel}")"
    next="$(mktemp)"
    jq --arg key "${rel}" --arg value "${h}" \
        '.harness.payload_sha256[$key] = $value' \
        "${tmp_manifest}" > "${next}"
    mv "${next}" "${tmp_manifest}"
done
mv "${tmp_manifest}" "${baseline}/.claude-plugin/plugin.json"

run_case() {
    local rel="$1"
    total=$((total + 1))

    local tmp_root
    tmp_root="$(mktemp -d)"

    # Mirror baseline (legitimate payloads + matching manifest)
    mkdir -p "${tmp_root}/.claude-plugin"
    cp "${baseline}/.claude-plugin/plugin.json" "${tmp_root}/.claude-plugin/plugin.json"
    for f in "${TRACKED[@]}"; do
        mkdir -p "${tmp_root}/$(dirname "${f}")"
        cp "${baseline}/${f}" "${tmp_root}/${f}"
    done

    # Overwrite the target file with tampered fixture
    local fixture
    fixture="$(fixture_for "${rel}")"
    if [[ ! -r "${fixture}" ]]; then
        printf 'FAIL (%s): missing fixture %s\n' "${rel}" "${fixture}" >&2
        fail=$((fail + 1))
        rm -rf "${tmp_root}"
        return
    fi
    cp "${fixture}" "${tmp_root}/${rel}"

    # Invoke the REAL session-start.sh pointing at the tampered root.
    # Capture stdout and stderr separately to check both behaviors.
    local stdout stderr rc
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"
    rc=0
    CLAUDE_PLUGIN_ROOT="${tmp_root}" "${session_start}" \
        >"${stdout_file}" 2>"${stderr_file}" || rc=$?
    stdout="$(cat "${stdout_file}")"
    stderr="$(cat "${stderr_file}")"
    rm -f "${stdout_file}" "${stderr_file}"

    local ok=1
    if [[ "${rc}" -ne 0 ]]; then
        printf 'FAIL (%s): exit code must be 0 (got %d)\n' "${rel}" "${rc}" >&2
        ok=0
    fi
    if ! printf '%s' "${stderr}" | grep -Fq "payload hash mismatch for ${rel}"; then
        printf 'FAIL (%s): expected mismatch warn in stderr\n' "${rel}" >&2
        printf 'stderr was:\n%s\n' "${stderr}" >&2
        ok=0
    fi

    if [[ "${rel}" == "skills/using-harness/SKILL.md" ]]; then
        if [[ -n "${stdout}" ]]; then
            printf 'FAIL (%s): expected injection to be skipped, got stdout len=%d\n' \
                "${rel}" "${#stdout}" >&2
            ok=0
        fi
    else
        if [[ -z "${stdout}" ]]; then
            printf 'FAIL (%s): expected SKILL.md to still inject on non-skill mismatch\n' "${rel}" >&2
            ok=0
        fi
    fi

    if [[ "${ok}" -eq 1 ]]; then
        pass=$((pass + 1))
        printf 'PASS: %s mismatch detected & handled correctly\n' "${rel}"
    else
        fail=$((fail + 1))
    fi

    rm -rf "${tmp_root}"
}

for rel in "${TRACKED[@]}"; do
    run_case "${rel}"
done

rm -rf "${baseline}"

printf '\n%d/%d passed\n' "${pass}" "${total}"
[[ "${fail}" -eq 0 ]] || exit 1

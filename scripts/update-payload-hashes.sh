#!/usr/bin/env bash
# Developer tool: refresh .claude-plugin/plugin.json `.harness.payload_sha256`
# with current SHA256 hashes of the tracked payload files.
# Run whenever a tracked hook/skill payload is edited.
#
# Tracked files (v3.2 §4.3.5 · T-W4-05):
#   - skills/using-harness/SKILL.md
#   - hooks/session-start.sh
#   - hooks/validate-output.sh
#
# Future additions should be appended to the TRACKED array below.
#
# Runtime: bash + jq + (shasum|sha256sum) only.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "${script_dir}/.." && pwd)"
manifest="${plugin_root}/.claude-plugin/plugin.json"

TRACKED=(
    "skills/using-harness/SKILL.md"
    "skills/dogfood-digest/SKILL.md"
    "hooks/session-start.sh"
    "hooks/validate-output.sh"
)

if [[ ! -r "${manifest}" ]]; then
    printf 'update-payload-hashes: manifest not readable: %s\n' "${manifest}" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    printf 'update-payload-hashes: jq required\n' >&2
    exit 1
fi

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

# Start from a copy; rebuild the .harness.payload_sha256 map from scratch so
# stale entries for removed files are purged.
tmp="$(mktemp)"
jq '.harness = (.harness // {}) | .harness.payload_sha256 = {}' "${manifest}" > "${tmp}"

for rel in "${TRACKED[@]}"; do
    target="${plugin_root}/${rel}"
    if [[ ! -r "${target}" ]]; then
        printf 'update-payload-hashes: missing %s — skipped\n' "${rel}" >&2
        continue
    fi
    hash="$(compute_sha256 "${target}")"
    if [[ -z "${hash}" ]]; then
        printf 'update-payload-hashes: sha256 tool not found\n' >&2
        rm -f "${tmp}"
        exit 1
    fi
    next="$(mktemp)"
    jq --arg key "${rel}" --arg value "${hash}" \
        '.harness.payload_sha256[$key] = $value' \
        "${tmp}" > "${next}"
    mv "${next}" "${tmp}"
    printf '  %s\n    %s\n' "${rel}" "${hash}"
done

mv "${tmp}" "${manifest}"
printf 'update-payload-hashes: wrote %s\n' "${manifest}"

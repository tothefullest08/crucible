#!/usr/bin/env bash
# SessionStart hook — injects the using-harness SKILL.md as session context
# and verifies payload SHA256 integrity declared in plugin.json.
# Referenced by hooks/hooks.json (${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh).
#
# Security constraints (final-spec v3.2 §4.3.5 · T-W4-05 · 🚨 P0-8):
#   - every variable expansion is double-quoted
#   - no eval, no dynamic command construction from external input
#   - plugin-root path validated against a strict slug whitelist
#   - failures are non-fatal (exit 0) so the session is never blocked
#   - payload hash mismatch → stderr WARN + skip that payload injection

set -euo pipefail

# ---- resolve plugin root ------------------------------------------------------
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    plugin_root="${CLAUDE_PLUGIN_ROOT}"
else
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    plugin_root="$(cd "${script_dir}/.." && pwd)"
fi

path_whitelist='^[a-zA-Z0-9_./~-]+$'
if ! [[ "${plugin_root}" =~ ${path_whitelist} ]]; then
    printf 'session-start: rejected plugin root (unsafe chars)\n' >&2
    exit 0
fi

skill_path="${plugin_root}/skills/using-harness/SKILL.md"
manifest_path="${plugin_root}/.claude-plugin/plugin.json"

if [[ ! -r "${skill_path}" ]]; then
    printf 'session-start: skill payload missing at %s\n' "${skill_path}" >&2
    exit 0
fi

# ---- sha256 helper ------------------------------------------------------------
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

# ---- SHA256 integrity check (v3.2 §4.3.5) -------------------------------------
# plugin.json.harness.payload_sha256 is an object mapping relative path →
# expected SHA256. Iterate the object via jq, compare each target's actual
# hash, warn on mismatch, and skip SKILL.md injection when its own hash fails.
skill_mismatch=0
rel_whitelist='^[a-zA-Z0-9_./-]+$'

if [[ -r "${manifest_path}" ]] && command -v jq >/dev/null 2>&1; then
    if jq -e 'has("harness") and (.harness | type == "object") and (.harness.payload_sha256 | type == "object")' \
           "${manifest_path}" >/dev/null 2>&1; then
        while IFS=$'\t' read -r rel_path expected_hash; do
            [[ -z "${rel_path}" ]] && continue
            [[ -z "${expected_hash}" ]] && continue

            if ! [[ "${rel_path}" =~ ${rel_whitelist} ]]; then
                printf 'WARN: payload path rejected (unsafe chars): %s\n' "${rel_path}" >&2
                continue
            fi
            if [[ "${rel_path}" == *".."* ]]; then
                printf 'WARN: payload path rejected (traversal): %s\n' "${rel_path}" >&2
                continue
            fi

            target="${plugin_root}/${rel_path}"
            if [[ ! -r "${target}" ]]; then
                printf 'WARN: payload missing for hash check: %s\n' "${rel_path}" >&2
                if [[ "${rel_path}" == "skills/using-harness/SKILL.md" ]]; then
                    skill_mismatch=1
                fi
                continue
            fi

            actual_hash="$(compute_sha256 "${target}")"
            if [[ -z "${actual_hash}" ]]; then
                printf 'WARN: sha256 tool unavailable, skipping %s\n' "${rel_path}" >&2
                continue
            fi

            if [[ "${expected_hash}" != "${actual_hash}" ]]; then
                printf 'WARN: payload hash mismatch for %s (expected=%s actual=%s)\n' \
                    "${rel_path}" "${expected_hash}" "${actual_hash}" >&2
                if [[ "${rel_path}" == "skills/using-harness/SKILL.md" ]]; then
                    skill_mismatch=1
                fi
            fi
        done < <(jq -r '.harness.payload_sha256 | to_entries[] | "\(.key)\t\(.value)"' "${manifest_path}")
    fi
fi

if [[ "${skill_mismatch}" -eq 1 ]]; then
    printf 'session-start: skipping SKILL.md injection due to hash mismatch\n' >&2
    exit 0
fi

# ---- emit payload -------------------------------------------------------------
cat "${skill_path}"

exit 0

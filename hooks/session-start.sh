#!/usr/bin/env bash
# SessionStart hook — injects the using-harness SKILL.md as session context.
# Referenced by hooks/hooks.json ($\{CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh).
#
# Security constraints (final-spec v3.1 §4.3, P0-8):
#   - every variable expansion is double-quoted
#   - no eval, no dynamic command construction from external input
#   - plugin-root path validated against a strict slug whitelist
#   - failures are non-fatal (exit 0) so the session is never blocked

set -euo pipefail

# ---- resolve plugin root ------------------------------------------------------
# Prefer the Claude Code supplied env var; fall back to the script's own location
# so manual invocation (`bash hooks/session-start.sh`) still works.
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    plugin_root="${CLAUDE_PLUGIN_ROOT}"
else
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    plugin_root="$(cd "${script_dir}/.." && pwd)"
fi

# ---- whitelist validation -----------------------------------------------------
# Accept only characters that are safe inside POSIX paths we control. This is a
# defense-in-depth step: reject unexpected shell metacharacters before the value
# is expanded into any later command argument.
path_whitelist='^[a-zA-Z0-9_./~-]+$'
if ! [[ "${plugin_root}" =~ ${path_whitelist} ]]; then
    printf 'session-start: rejected plugin root (unsafe chars)\n' >&2
    exit 0
fi

skill_path="${plugin_root}/skills/using-harness/SKILL.md"
manifest_path="${plugin_root}/.claude-plugin/plugin.json"

# ---- payload presence check ---------------------------------------------------
if [[ ! -r "${skill_path}" ]]; then
    printf 'session-start: skill payload missing at %s\n' "${skill_path}" >&2
    exit 0
fi

# ---- optional SHA256 integrity check (MVP placeholder) ------------------------
# If plugin.json declares .harness.payload_sha256, require a match before
# emitting the payload. Missing field => skip (not fatal in MVP).
if [[ -r "${manifest_path}" ]] && command -v jq >/dev/null 2>&1; then
    expected_hash="$(jq -r '.harness.payload_sha256 // empty' "${manifest_path}" 2>/dev/null || printf '')"
    if [[ -n "${expected_hash}" ]]; then
        if command -v shasum >/dev/null 2>&1; then
            actual_hash="$(shasum -a 256 "${skill_path}" | awk '{print $1}')"
        elif command -v sha256sum >/dev/null 2>&1; then
            actual_hash="$(sha256sum "${skill_path}" | awk '{print $1}')"
        else
            actual_hash=""
        fi

        if [[ -n "${actual_hash}" && "${expected_hash}" != "${actual_hash}" ]]; then
            printf 'session-start: payload hash mismatch (expected=%s actual=%s)\n' \
                "${expected_hash}" "${actual_hash}" >&2
            exit 0
        fi
    fi
fi

# ---- emit payload -------------------------------------------------------------
# Claude Code treats stdout of a SessionStart hook as additional session context.
# The manual-test contract (prompt §검증) is "SKILL.md 내용 그대로 출력",
# so we stream the file verbatim rather than wrap it in a JSON envelope.
cat "${skill_path}"

exit 0

#!/usr/bin/env bash
# shellcheck disable=SC2329
# (All check_* helpers are called indirectly via `check "<label>" <fn>`.)
# AC-1 Hard Gate integration test.
#
# Verifies that the plugin package is install-ready for Claude Code:
#   1) plugin.json has the 5 required fields
#   2) marketplace.json plugins[0].name matches plugin.json.name
#   3) hooks/hooks.json registers SessionStart + UserPromptSubmit + PostToolUse + Stop
#   4) hooks/session-start.sh exists, is executable, and shellcheck-clean
#   5) skills/using-harness/SKILL.md has parseable frontmatter (name + description)
#   6) Running hooks/session-start.sh emits the SKILL.md payload on stdout
#   7) Delegate to the T-W1-09 security linter for the full hook suite
#
# A real Claude Code install smoke test is out of scope here (T-W7.5 hardening);
# this script only asserts that the package satisfies the installer contract.
#
# Exit: 0 on AC-1 PASS, 1 otherwise.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

plugin_json="${repo_root}/.claude-plugin/plugin.json"
marketplace_json="${repo_root}/.claude-plugin/marketplace.json"
hooks_json="${repo_root}/hooks/hooks.json"
session_start="${repo_root}/hooks/session-start.sh"
skill_md="${repo_root}/skills/using-harness/SKILL.md"
security_run="${repo_root}/__tests__/security/run.sh"

pass_count=0
fail_count=0

check() {
    local label="$1"; shift
    if "$@"; then
        pass_count=$((pass_count + 1))
        printf '[PASS] %s\n' "${label}"
    else
        fail_count=$((fail_count + 1))
        printf '[FAIL] %s\n' "${label}" >&2
    fi
}

# ---- prerequisites -----------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
    printf 'integration: jq is required on PATH\n' >&2
    exit 1
fi

# ---- check 1: plugin.json required fields ------------------------------------
check_plugin_json_fields() {
    [[ -r "${plugin_json}" ]] || { printf '  plugin.json missing at %s\n' "${plugin_json}" >&2; return 1; }
    local missing=""
    local field
    for field in name version description author license; do
        if ! jq -e ".${field}" "${plugin_json}" >/dev/null 2>&1; then
            missing="${missing} ${field}"
        fi
    done
    if [[ -n "${missing}" ]]; then
        printf '  plugin.json missing fields:%s\n' "${missing}" >&2
        return 1
    fi
    return 0
}

# ---- check 2: marketplace name alignment -------------------------------------
check_marketplace_alignment() {
    [[ -r "${marketplace_json}" ]] || { printf '  marketplace.json missing\n' >&2; return 1; }
    local plugin_name mkt_name
    plugin_name="$(jq -r '.name' "${plugin_json}" 2>/dev/null)"
    mkt_name="$(jq -r '.plugins[0].name' "${marketplace_json}" 2>/dev/null)"
    if [[ -z "${plugin_name}" || "${plugin_name}" == "null" ]]; then
        printf '  plugin.json.name is empty/null\n' >&2
        return 1
    fi
    if [[ "${plugin_name}" != "${mkt_name}" ]]; then
        printf '  name mismatch: plugin=%s marketplace=%s\n' "${plugin_name}" "${mkt_name}" >&2
        return 1
    fi
    return 0
}

# ---- check 3: hooks.json registers 4 events ----------------------------------
check_hooks_json_events() {
    [[ -r "${hooks_json}" ]] || { printf '  hooks.json missing\n' >&2; return 1; }
    local missing=""
    local event
    for event in SessionStart UserPromptSubmit PostToolUse Stop; do
        if ! jq -e ".hooks.\"${event}\" | length > 0" "${hooks_json}" >/dev/null 2>&1; then
            missing="${missing} ${event}"
        fi
    done
    if [[ -n "${missing}" ]]; then
        printf '  hooks.json missing events:%s\n' "${missing}" >&2
        return 1
    fi
    return 0
}

# ---- check 4: session-start.sh exists + executable + shellcheck clean --------
check_session_start_script() {
    if [[ ! -f "${session_start}" ]]; then
        printf '  session-start.sh missing\n' >&2
        return 1
    fi
    if [[ ! -x "${session_start}" ]]; then
        printf '  session-start.sh not executable\n' >&2
        return 1
    fi
    if ! command -v shellcheck >/dev/null 2>&1; then
        printf '  shellcheck not installed (required for AC-1)\n' >&2
        return 1
    fi
    if ! shellcheck "${session_start}" >/dev/null 2>&1; then
        shellcheck "${session_start}" >&2
        return 1
    fi
    return 0
}

# ---- check 5: SKILL.md frontmatter parseable ---------------------------------
check_skill_frontmatter() {
    [[ -r "${skill_md}" ]] || { printf '  SKILL.md missing\n' >&2; return 1; }
    local first_line
    first_line="$(head -n 1 "${skill_md}")"
    if [[ "${first_line}" != "---" ]]; then
        printf '  SKILL.md does not start with frontmatter marker\n' >&2
        return 1
    fi
    # Extract frontmatter block between first two `---` lines.
    local fm
    fm="$(awk '/^---$/{c++; next} c==1{print}' "${skill_md}")"
    if ! printf '%s\n' "${fm}" | grep -qE '^name:[[:space:]]*[^[:space:]]'; then
        printf '  SKILL.md frontmatter missing name field\n' >&2
        return 1
    fi
    if ! printf '%s\n' "${fm}" | grep -qE '^description:[[:space:]]*[^[:space:]]'; then
        printf '  SKILL.md frontmatter missing description field\n' >&2
        return 1
    fi
    return 0
}

# ---- check 6: execution emits SKILL.md payload -------------------------------
check_runtime_payload_injection() {
    [[ -x "${session_start}" ]] || { printf '  session-start.sh not executable\n' >&2; return 1; }
    [[ -r "${skill_md}" ]] || { printf '  SKILL.md missing\n' >&2; return 1; }

    local actual expected
    if ! actual="$(CLAUDE_PLUGIN_ROOT="${repo_root}" bash "${session_start}" 2>/dev/null)"; then
        printf '  session-start.sh exited non-zero\n' >&2
        return 1
    fi
    expected="$(head -c 100 "${skill_md}")"
    if [[ -z "${expected}" ]]; then
        printf '  SKILL.md is empty\n' >&2
        return 1
    fi
    # The first 100 bytes of SKILL.md must appear in the hook stdout.
    if ! printf '%s' "${actual}" | grep -F -q -- "${expected}"; then
        printf '  hook stdout does not contain first 100 bytes of SKILL.md\n' >&2
        return 1
    fi
    return 0
}

# ---- check 7: delegate security linter ---------------------------------------
check_security_suite() {
    [[ -x "${security_run}" || -r "${security_run}" ]] || {
        printf '  security linter entry point missing at %s\n' "${security_run}" >&2
        return 1
    }
    bash "${security_run}" >/dev/null 2>&1
}

printf '== AC-1 install-readiness checks ==\n'
check 'plugin.json has name/version/description/author/license' check_plugin_json_fields
check 'marketplace.json plugins[0].name == plugin.json.name'    check_marketplace_alignment
check 'hooks.json registers SessionStart/UserPromptSubmit/PostToolUse/Stop' check_hooks_json_events
check 'session-start.sh exists + executable + shellcheck clean' check_session_start_script
check 'SKILL.md frontmatter parseable (name + description)'     check_skill_frontmatter
check 'session-start.sh emits first 100 bytes of SKILL.md'      check_runtime_payload_injection
check 'security linter run.sh (T-W1-09) all green'              check_security_suite

printf '\n== Summary ==\n'
printf '  passed: %d\n' "${pass_count}"
printf '  failed: %d\n' "${fail_count}"

if [[ "${fail_count}" -gt 0 ]]; then
    printf '\nAC-1 FAIL\n' >&2
    exit 1
fi

printf '\nAC-1 PASS\n'
exit 0

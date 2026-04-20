#!/usr/bin/env bash
# T-W8-08 / AC-1 — Clean-machine install verification.
#
# Copies the plugin into a fresh temporary directory, asserts external-dependency
# minimalism (bash + jq + yq + uuidgen + flock only — no Python / Node at runtime),
# and simulates a `/brainstorm` invocation by parsing the skill frontmatter with `yq`.
#
# Exit: 0 on AC-1 PASS, 1 otherwise. Cleans up tmpdir on every exit path.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

failures=0
check() {
    local label="$1" rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf '  ✅ %s\n' "$label"
    else
        printf '  ❌ %s (exit %d)\n' "$label" "$rc"
        failures=$((failures + 1))
    fi
}

tmpdir=""
cleanup() {
    if [ -n "${tmpdir}" ] && [ -d "${tmpdir}" ]; then
        rm -rf "${tmpdir}"
    fi
}
trap cleanup EXIT

# --- 1) Preflight: required host binaries exist ------------------------------
# bash / jq / yq / uuidgen are hard requirements.
# flock is optional — scripts/orchestrate-checkpoint.sh falls back to mkdir-lock
# when flock is missing (macOS without util-linux, BSD).
printf '== host binaries ==\n'
for bin in bash jq yq uuidgen; do
    if command -v "$bin" >/dev/null 2>&1; then
        check "command -v $bin" 0
    else
        check "command -v $bin" 1
    fi
done
if command -v flock >/dev/null 2>&1; then
    printf '  ✅ command -v flock (optional — available)\n'
else
    printf '  ⚠️  command -v flock (optional — missing, mkdir-lock fallback will be used)\n'
fi

# --- 2) Create clean tmpdir + copy plugin surface ----------------------------
printf '\n== stage clean copy ==\n'
tmpdir="$(mktemp -d -t harness-clean-install.XXXXXX)"
target="${tmpdir}/clean-harness"
mkdir -p "${target}"

# Copy plugin surface required for `/brainstorm` cold start.
# Sources mirror the plugin distribution contract (final-spec §4.1 · T-W8-08 task spec).
for path in .claude-plugin skills agents scripts hooks __tests__ LICENSE README.md; do
    src="${repo_root}/${path}"
    if [ -e "${src}" ]; then
        cp -R "${src}" "${target}/"
        check "copy ${path}" 0
    else
        check "copy ${path} (missing in source)" 1
    fi
done

# --- 3) External-dependency check inside the staged copy ---------------------
printf '\n== external-dependency scan ==\n'
cd "${target}" || { printf '  ❌ cd ${target} failed\n'; exit 1; }

# 3a) No python/node shebangs or runtime calls inside our code paths.
#     Shebangs elsewhere (e.g. inside references/) are out of scope — we do not copy them.
runtime_hits="$(
    grep -R -n -E 'python3?|node ' scripts/ hooks/ agents/ skills/ 2>/dev/null \
        | grep -v -E '(^|/|:)#|//|<!--' \
        | grep -v -E '\.md:' \
        || true
)"
if [ -z "${runtime_hits}" ]; then
    check "no python/node runtime refs in scripts/hooks/agents/skills" 0
else
    printf '%s\n' "${runtime_hits}" | head -5
    check "no python/node runtime refs in scripts/hooks/agents/skills" 1
fi

# 3b) Host command availability inside the copied surface (hard requirements only).
for bin in bash jq yq uuidgen; do
    if command -v "$bin" >/dev/null 2>&1; then
        check "staged host has $bin" 0
    else
        check "staged host has $bin" 1
    fi
done

# --- 4) `/brainstorm` cold-start simulation ----------------------------------
printf '\n== /brainstorm simulation ==\n'
brainstorm_skill="${target}/skills/brainstorm/SKILL.md"
if [ ! -f "${brainstorm_skill}" ]; then
    check "brainstorm SKILL.md present" 1
else
    check "brainstorm SKILL.md present" 0

    # Extract YAML frontmatter (between the two `---` fences) and parse `.name`.
    frontmatter="$(awk '/^---$/{c++; if(c==2) exit} c==1 && !/^---$/{print}' "${brainstorm_skill}")"
    name="$(printf '%s\n' "${frontmatter}" | yq eval '.name' - 2>/dev/null || true)"
    if [ "${name}" = "brainstorm" ]; then
        check "yq parses skills/brainstorm/SKILL.md .name = brainstorm" 0
    else
        printf '    got: %q\n' "${name}"
        check "yq parses skills/brainstorm/SKILL.md .name = brainstorm" 1
    fi
fi

# --- 5) Plugin footprint (informational) -------------------------------------
printf '\n== plugin footprint ==\n'
size="$(du -sh "${target}" 2>/dev/null | awk '{print $1}')"
printf '  plugin size: %s\n' "${size:-unknown}"
printf '  tmpdir     : %s\n' "${target}"

# --- 6) Summary --------------------------------------------------------------
printf '\n== summary ==\n'
if [ "${failures}" -eq 0 ]; then
    printf '  AC-1 PASS — clean install ready.\n'
    exit 0
fi
printf '  AC-1 FAIL — %d failure(s).\n' "${failures}"
exit 1

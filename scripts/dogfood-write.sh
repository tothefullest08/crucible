#!/usr/bin/env bash
# dogfood-write.sh — append stdin JSONL to {project}/.claude/dogfood/log.jsonl
# and, if CRUCIBLE_DOGFOOD_GLOBAL != "0", also mirror to
# ~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl.
#
# Responsibilities:
#   1. Validate every stdin line as JSON (skip blanks, reject non-JSON).
#   2. Acquire an flock on the local log file to serialize concurrent writers.
#   3. Append validated lines to local log (create dir if missing).
#   4. Mirror to global path when opt-in is active.
#   5. Ensure .gitignore in the project root contains ".claude/dogfood/"
#      exactly once (idempotent — skips if the pattern already present).
#   6. Print a human-readable summary to stdout:
#        ✓ Wrote N lines to local / global
#
# Usage:
#   echo '{"type":"note", ...}' | scripts/dogfood-write.sh
#   cat events.jsonl | scripts/dogfood-write.sh
#
# Exit codes: 0 on success, 2 on invalid input, 1 on I/O failure.
#
# Env:
#   CRUCIBLE_DOGFOOD_GLOBAL  "0" disables the global mirror (default: on)
#   CRUCIBLE_DOGFOOD_ROOT    override project root (default: $PWD)
#   CRUCIBLE_DOGFOOD_HOME    override global mirror home (default: $HOME)
#
# Runtime: bash + jq + flock + find. No Python/Node.
# Safety: set -euo pipefail, all vars quoted, shellcheck clean.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq >/dev/null 2>&1; then
    printf 'dogfood-write: jq is required on PATH\n' >&2
    exit 2
fi

project_root="${CRUCIBLE_DOGFOOD_ROOT:-$PWD}"
global_home="${CRUCIBLE_DOGFOOD_HOME:-$HOME}"

if [[ ! -d "$project_root" ]]; then
    printf 'dogfood-write: project root missing: %s\n' "$project_root" >&2
    exit 1
fi

local_dir="${project_root}/.claude/dogfood"
local_log="${local_dir}/log.jsonl"
gitignore_path="${project_root}/.gitignore"

# --- validate stdin ---------------------------------------------------------

tmp_input="$(mktemp -t dogfood-input.XXXXXX)"
trap 'rm -f "$tmp_input"' EXIT

line_count=0
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
        continue
    fi
    if ! printf '%s\n' "$line" | jq -e . >/dev/null 2>&1; then
        printf 'dogfood-write: invalid JSON line (skipping): %s\n' "${line:0:80}" >&2
        continue
    fi
    printf '%s\n' "$line" >> "$tmp_input"
    line_count=$((line_count + 1))
done

if [[ "$line_count" -eq 0 ]]; then
    printf 'dogfood-write: no valid JSON lines on stdin — nothing to write\n' >&2
    exit 0
fi

# --- write local log (flock-serialized) -------------------------------------

mkdir -p "$local_dir"
# touch so flock can open for exclusive append even on the first run
: >> "$local_log"

if command -v flock >/dev/null 2>&1; then
    (
        flock -x 9
        cat "$tmp_input" >> "$local_log"
    ) 9>>"$local_log"
else
    # flock missing (rare on macOS bare install) — fall back to plain append
    cat "$tmp_input" >> "$local_log"
fi

# --- ensure .gitignore has .claude/dogfood/ entry ---------------------------

gitignore_pattern='.claude/dogfood/'
if [[ -f "$gitignore_path" ]]; then
    if ! grep -qxF "$gitignore_pattern" "$gitignore_path"; then
        # append with leading newline if file doesn't already end with one
        if [[ -s "$gitignore_path" ]] && [[ "$(tail -c1 "$gitignore_path")" != "" ]]; then
            printf '\n' >> "$gitignore_path"
        fi
        printf '%s\n' "$gitignore_pattern" >> "$gitignore_path"
    fi
else
    printf '%s\n' "$gitignore_pattern" > "$gitignore_path"
fi

# --- optional global mirror -------------------------------------------------

global_log=""
if [[ "${CRUCIBLE_DOGFOOD_GLOBAL:-1}" != "0" ]]; then
    # shellcheck source=scripts/lib/project-id.sh
    # shellcheck disable=SC1091
    source "${script_dir}/lib/project-id.sh"
    # shellcheck source=scripts/project-slug-hash.sh
    # shellcheck disable=SC1091
    source "${script_dir}/project-slug-hash.sh"

    slug_hash="$(project_slug_hash_for "$project_root")"
    global_dir="${global_home}/.claude/dogfood/crucible/${slug_hash}"
    global_log="${global_dir}/log.jsonl"
    mkdir -p "$global_dir"
    : >> "$global_log"

    if command -v flock >/dev/null 2>&1; then
        (
            flock -x 9
            cat "$tmp_input" >> "$global_log"
        ) 9>>"$global_log"
    else
        cat "$tmp_input" >> "$global_log"
    fi
fi

# --- summary ----------------------------------------------------------------

if [[ -n "$global_log" ]]; then
    printf '✓ Wrote %d line(s) to:\n    local:  %s\n    global: %s\n' \
        "$line_count" "$local_log" "$global_log"
else
    printf '✓ Wrote %d line(s) to:\n    local:  %s\n    global: (skipped — CRUCIBLE_DOGFOOD_GLOBAL=0)\n' \
        "$line_count" "$local_log"
fi

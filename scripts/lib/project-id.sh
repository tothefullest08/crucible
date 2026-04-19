#!/usr/bin/env bash
# scripts/lib/project-id.sh — T-W5-10 · v3.3 §4.3.4 글로벌 메모리 모드
#
# Derives a short, stable project identifier from an absolute filesystem path
# so that global-mode memory files (`~/.claude/memory/`) can be tagged with a
# `project_id` and filtered to prevent cross-project contamination (v3.3 §2.1
# #6). The identifier is the first 8 hex chars of the SHA256 of the absolute
# path — 4 bytes of entropy, stable across sessions, short enough for
# frontmatter.
#
# CLI:
#   project-id.sh                # project id for $PWD
#   project-id.sh <path>         # project id for <path>
#
# Environment override (testing):
#   HARNESS_PROJECT_ID=<hex>     # bypass hashing, echoed verbatim
#
# Sourceable:
#   source scripts/lib/project-id.sh
#   id="$(project_id_for "/abs/path")"
#
# Runtime: bash + (shasum | sha256sum). Python forbidden (§4.1).
# Safety: all expansions quoted, no eval, shellcheck clean.

set -euo pipefail

project_id_for() {
    local target="${1:-}"
    if [[ -n "${HARNESS_PROJECT_ID:-}" ]]; then
        printf '%s' "${HARNESS_PROJECT_ID}"
        return 0
    fi
    if [[ -z "$target" ]]; then
        target="$PWD"
    fi
    # Canonicalize without requiring realpath (not installed on every macOS).
    local abs
    if [[ -d "$target" ]]; then
        abs="$(cd "$target" && pwd -P)"
    elif [[ "${target:0:1}" == "/" ]]; then
        abs="$target"
    else
        abs="$PWD/$target"
    fi
    local hash
    if command -v shasum >/dev/null 2>&1; then
        hash="$(printf '%s' "$abs" | shasum -a 256 | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        hash="$(printf '%s' "$abs" | sha256sum | awk '{print $1}')"
    else
        printf 'project-id: no sha256 tool available\n' >&2
        return 1
    fi
    printf '%s' "${hash:0:8}"
}

# CLI entry — only executes when invoked directly (not when sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    project_id_for "${1:-}"
    printf '\n'
fi

#!/usr/bin/env bash
# project-slug-hash.sh — compute `{slug}-{hash}` key for dogfood global mirror.
#
# slug = lowercased basename of target path, non-[a-zA-Z0-9_-] chars dropped,
#        truncated to 32 chars. Empty basename → "unnamed".
# hash = first 8 hex chars of SHA-256 of the absolute path (via
#        scripts/lib/project-id.sh::project_id_for — reuse, do not duplicate).
#
# Output goes to stdout as `{slug}-{hash}` with no trailing newline suppression
# (final `\n` appended by the CLI entry, matching project-id.sh style).
#
# Usage:
#   scripts/project-slug-hash.sh            # for $PWD
#   scripts/project-slug-hash.sh <path>     # for an arbitrary directory
#
# Runtime: bash + sed + tr + shasum|sha256sum (via project-id.sh). No Python.
# Safety: all expansions quoted, no eval, shellcheck clean.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/project-id.sh
# shellcheck disable=SC1091
source "${script_dir}/lib/project-id.sh"

project_slug_for() {
    local target="${1:-}"
    if [[ -z "$target" ]]; then
        target="$PWD"
    fi

    local abs
    if [[ -d "$target" ]]; then
        abs="$(cd "$target" && pwd -P)"
    elif [[ "${target:0:1}" == "/" ]]; then
        abs="$target"
    else
        abs="$PWD/$target"
    fi

    local base
    base="$(basename "$abs")"

    local lowered
    lowered="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"

    local filtered
    filtered="$(printf '%s' "$lowered" | LC_ALL=C sed -E 's/[^a-z0-9_-]/-/g; s/-+/-/g; s/^-+//; s/-+$//')"

    if [[ -z "$filtered" ]]; then
        filtered="unnamed"
    fi

    printf '%s' "${filtered:0:32}"
}

project_slug_hash_for() {
    local target="${1:-$PWD}"
    local slug hash
    slug="$(project_slug_for "$target")"
    hash="$(project_id_for "$target")"
    printf '%s-%s' "$slug" "$hash"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    project_slug_hash_for "${1:-}"
    printf '\n'
fi

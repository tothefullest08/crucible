#!/usr/bin/env bash
# scripts/global-memory-tag.sh — T-W5-10 [Stretch] · v3.3 §4.3.4 · AC-Stretch-2
#
# Glue layer that enforces project-id tagging on memory files when the global
# memory mode is opted in via `.claude-plugin/plugin.json.harness.global_memory_enabled`.
# Prevents cross-project contamination of `~/.claude/memory/` (v3.3 §2.1 #6).
#
# Commands:
#   root                     Print the active memory root (global vs. local).
#   mode                     Print "global" or "local".
#   tag   <file>             Inject `project_id: <hash>` into YAML frontmatter.
#                            Idempotent: skips when already present.
#   validate <file>          Exit 0 if frontmatter has a project_id when global
#                            mode is active; exit 1 otherwise (with stderr msg).
#   store <file>             validate + tag + copy into the active memory root,
#                            preserving the file basename. Rejects on missing
#                            project_id when global mode is ON and --auto-tag
#                            is NOT supplied.
#   list  [--all-projects]   List memory file paths, filtered to the current
#                            project_id by default.
#
# Options:
#   --auto-tag               For `store`: auto-inject project_id instead of
#                            rejecting when missing.
#
# Environment (testing):
#   HARNESS_MEMORY_ROOT      Override memory root (e.g. fixture dir).
#   HARNESS_PROJECT_ID       Override computed project id.
#
# Runtime: bash + jq + (shasum|sha256sum). Python forbidden (§4.1).
# Safety: all expansions quoted, no eval, no string-interpolated jq filters.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/project-id.sh
source "${script_dir}/lib/project-id.sh"

plugin_root="$(cd "${script_dir}/.." && pwd)"
manifest="${plugin_root}/.claude-plugin/plugin.json"

global_mode_enabled() {
    [[ -r "$manifest" ]] || { printf 'false'; return; }
    local val
    val="$(jq -r '.harness.global_memory_enabled // false' "$manifest")"
    printf '%s' "$val"
}

active_mode() {
    if [[ "$(global_mode_enabled)" == "true" ]]; then
        printf 'global'
    else
        printf 'local'
    fi
}

active_root() {
    if [[ -n "${HARNESS_MEMORY_ROOT:-}" ]]; then
        printf '%s' "${HARNESS_MEMORY_ROOT}"
        return
    fi
    if [[ "$(global_mode_enabled)" == "true" ]]; then
        printf '%s/.claude/memory' "${HOME}"
    else
        printf '%s/.claude/memory' "${plugin_root}"
    fi
}

# Extracts the value of a top-level YAML frontmatter key. Prints empty on miss.
# Expects the file to start with `---` on line 1.
read_frontmatter_key() {
    local file="$1" key="$2"
    awk -v k="$key" '
        NR == 1 && $0 == "---" { in_fm = 1; next }
        in_fm && $0 == "---"   { exit }
        in_fm {
            if (match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*")) {
                val = substr($0, RLENGTH + 1)
                sub(/[[:space:]]+$/, "", val)
                gsub(/^["'"'"']|["'"'"']$/, "", val)
                print val
                exit
            }
        }
    ' "$file"
}

has_frontmatter() {
    local file="$1"
    [[ -r "$file" ]] || return 1
    [[ "$(head -n1 "$file")" == "---" ]]
}

# Inject `project_id: <id>` into the frontmatter block. Writes the result to
# stdout. If frontmatter is absent, prepends one. Idempotent — returns input
# verbatim when the key is already present.
inject_project_id() {
    local file="$1" id="$2"
    if [[ -n "$(read_frontmatter_key "$file" project_id)" ]]; then
        cat "$file"
        return 0
    fi
    if has_frontmatter "$file"; then
        awk -v id="$id" '
            NR == 1 && $0 == "---" { print; inserted = 0; in_fm = 1; next }
            in_fm && $0 == "---" && !inserted { print "project_id: " id; inserted = 1 }
            { print }
        ' "$file"
    else
        printf -- '---\nproject_id: %s\n---\n' "$id"
        cat "$file"
    fi
}

cmd_root() {
    active_root
    printf '\n'
}

cmd_mode() {
    active_mode
    printf '\n'
}

cmd_tag() {
    local file="${1:-}"
    [[ -n "$file" && -r "$file" ]] || { printf 'global-memory-tag: file not readable: %s\n' "$file" >&2; exit 1; }
    local id
    id="$(project_id_for "$PWD")"
    inject_project_id "$file" "$id"
}

cmd_validate() {
    local file="${1:-}"
    [[ -n "$file" && -r "$file" ]] || { printf 'global-memory-tag: file not readable: %s\n' "$file" >&2; exit 1; }
    if [[ "$(active_mode)" != "global" ]]; then
        return 0
    fi
    local pid
    pid="$(read_frontmatter_key "$file" project_id)"
    if [[ -z "$pid" ]]; then
        printf 'global-memory-tag: REJECT — %s is missing project_id (global mode requires it)\n' "$file" >&2
        exit 1
    fi
    return 0
}

cmd_store() {
    local auto_tag=0
    local file=''
    while (( $# > 0 )); do
        case "$1" in
            --auto-tag) auto_tag=1; shift ;;
            *) file="$1"; shift ;;
        esac
    done
    [[ -n "$file" && -r "$file" ]] || { printf 'global-memory-tag: file not readable: %s\n' "$file" >&2; exit 1; }

    local pid
    pid="$(project_id_for "$PWD")"

    local existing
    existing="$(read_frontmatter_key "$file" project_id)"
    if [[ -z "$existing" ]]; then
        if [[ "$(active_mode)" == "global" && $auto_tag -eq 0 ]]; then
            printf 'global-memory-tag: REJECT — %s is missing project_id (use --auto-tag or add frontmatter)\n' "$file" >&2
            exit 1
        fi
        # local mode OR auto-tag: inject
        existing="$pid"
    fi

    local root base dest
    root="$(active_root)"
    mkdir -p "$root"
    base="$(basename "$file")"
    dest="${root}/${base}"
    inject_project_id "$file" "$existing" > "$dest"
    printf '%s\n' "$dest"
}

cmd_list() {
    local all_projects=0
    while (( $# > 0 )); do
        case "$1" in
            --all-projects) all_projects=1; shift ;;
            *) shift ;;
        esac
    done

    local root
    root="$(active_root)"
    [[ -d "$root" ]] || return 0

    local pid
    pid="$(project_id_for "$PWD")"

    while IFS= read -r -d '' f; do
        if [[ $all_projects -eq 1 ]]; then
            printf '%s\n' "$f"
            continue
        fi
        local tag
        tag="$(read_frontmatter_key "$f" project_id)"
        if [[ -z "$tag" ]]; then
            # Untagged files are ignored under filtering (global mode is the
            # only mode that mandates tags; local mode tolerates absence).
            continue
        fi
        if [[ "$tag" == "$pid" ]]; then
            printf '%s\n' "$f"
        fi
    done < <(find "$root" -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null)
}

main() {
    local cmd="${1:-}"
    shift || true
    case "$cmd" in
        root)     cmd_root "$@" ;;
        mode)     cmd_mode "$@" ;;
        tag)      cmd_tag "$@" ;;
        validate) cmd_validate "$@" ;;
        store)    cmd_store "$@" ;;
        list)     cmd_list "$@" ;;
        -h|--help|'')
            cat <<'USAGE'
Usage: global-memory-tag.sh <command> [args]

Commands:
  root                    Print active memory root directory.
  mode                    Print "global" or "local".
  tag <file>              Inject project_id into YAML frontmatter (stdout).
  validate <file>         Exit non-zero when global mode ON and project_id missing.
  store [--auto-tag] <file>
                          Validate + tag + copy into memory root.
  list [--all-projects]   List memory files filtered by current project_id.
USAGE
            ;;
        *)
            printf 'global-memory-tag: unknown command: %s\n' "$cmd" >&2
            exit 2
            ;;
    esac
}

main "$@"

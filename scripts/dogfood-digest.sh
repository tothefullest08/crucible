#!/usr/bin/env bash
# dogfood-digest.sh — aggregate crucible dogfood JSONL logs within a user-specified
# window (last N / since DATE / all) and emit a filtered JSONL stream on stdout.
#
# Each emitted line carries two extra fields for back-reference rendering:
#   _source_path : absolute path of the origin log file
#   _line        : 1-based line number within that file
#
# Read-only — reads from local + global mirrors, never writes to them.
#
# Flags:
#   --last <N>           take the most recent N events (default 10 when no
#                        window flag is given)
#   --since <DATE|Nd>    take events with ts >= cutoff. Accepts absolute
#                        YYYY-MM-DD / ISO8601, or "Nd" duration (e.g. 7d = 7 days
#                        ago relative to now).
#   --all                no filter (entire window)
#   --scope SCOPE        local | global | both (default both)
#   --project-root DIR   override PWD for local log resolution (test hook)
#   --home DIR           override $HOME for global mirror resolution (test hook)
#   -h | --help          print usage
#
# --last and --since are mutually exclusive. --all overrides both.
#
# Output: JSONL on stdout. Empty input → no lines, exit 0.
#
# Runtime: bash (>=4) + jq (>=1.6) + date. No Python / Node.

set -uo pipefail

print_help() {
    cat <<'USAGE'
Usage: dogfood-digest.sh [--last N | --since DATE|Nd | --all] [--scope local|global|both]
                         [--project-root DIR] [--home DIR]

Defaults: --last 10 --scope both.
Output: filtered JSONL on stdout, one event per line, each augmented with
_source_path and _line back-reference fields.
USAGE
}

# ----- argument parsing ------------------------------------------------------

window_mode="last"
window_last=10
window_since=""
scope="both"
project_root="${PWD}"
home_dir="${HOME}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --last)
            window_mode="last"
            window_last="${2:-}"
            shift 2 || { printf 'dogfood-digest: --last requires a value\n' >&2; exit 2; }
            ;;
        --since)
            window_mode="since"
            window_since="${2:-}"
            shift 2 || { printf 'dogfood-digest: --since requires a value\n' >&2; exit 2; }
            ;;
        --all)
            window_mode="all"
            shift
            ;;
        --scope)
            scope="${2:-}"
            shift 2 || { printf 'dogfood-digest: --scope requires a value\n' >&2; exit 2; }
            ;;
        --project-root)
            project_root="${2:-}"
            shift 2 || { printf 'dogfood-digest: --project-root requires a value\n' >&2; exit 2; }
            ;;
        --home)
            home_dir="${2:-}"
            shift 2 || { printf 'dogfood-digest: --home requires a value\n' >&2; exit 2; }
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            printf 'dogfood-digest: unknown argument: %s\n' "$1" >&2
            print_help >&2
            exit 2
            ;;
    esac
done

case "$scope" in
    local|global|both) ;;
    *)
        printf 'dogfood-digest: --scope must be local, global, or both (got: %s)\n' "$scope" >&2
        exit 2
        ;;
esac

if [[ "$window_mode" == "last" ]]; then
    if ! [[ "$window_last" =~ ^[0-9]+$ ]] || [[ "$window_last" -le 0 ]]; then
        printf 'dogfood-digest: --last expects a positive integer (got: %s)\n' "$window_last" >&2
        exit 2
    fi
fi

# ----- cutoff resolution for --since -----------------------------------------

cutoff_iso=""
if [[ "$window_mode" == "since" ]]; then
    if [[ -z "$window_since" ]]; then
        printf 'dogfood-digest: --since requires a DATE or Nd duration\n' >&2
        exit 2
    fi
    if [[ "$window_since" =~ ^([0-9]+)d$ ]]; then
        days="${BASH_REMATCH[1]}"
        if date -v-1d +%Y-%m-%d >/dev/null 2>&1; then
            cutoff_iso="$(date -u -v-"${days}"d +%Y-%m-%dT%H:%M:%SZ)"
        else
            cutoff_iso="$(date -u -d "${days} days ago" +%Y-%m-%dT%H:%M:%SZ)"
        fi
    elif [[ "$window_since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        cutoff_iso="${window_since}T00:00:00Z"
    elif [[ "$window_since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
        cutoff_iso="$window_since"
    else
        printf 'dogfood-digest: --since must be YYYY-MM-DD, full ISO8601, or Nd (got: %s)\n' "$window_since" >&2
        exit 2
    fi
fi

# ----- source resolution -----------------------------------------------------

# Root override for dogfood storage (CI/test hook). Falls back to project_root
# for locals, and $home_dir/.claude/dogfood/crucible for globals.
local_log="${CRUCIBLE_DOGFOOD_ROOT:-$project_root}/.claude/dogfood/log.jsonl"
global_glob="${CRUCIBLE_DOGFOOD_HOME:-$home_dir}/.claude/dogfood/crucible"

sources=()

if [[ "$scope" == "local" || "$scope" == "both" ]]; then
    if [[ -r "$local_log" ]]; then
        sources+=("$local_log")
    fi
fi

if [[ "$scope" == "global" || "$scope" == "both" ]]; then
    if [[ -d "$global_glob" ]]; then
        while IFS= read -r -d '' f; do
            sources+=("$f")
        done < <(find "$global_glob" -type f -name 'log.jsonl' -print0 2>/dev/null)
    fi
fi

# Zero sources = zero output (SC-6 compliant). Exit 0 silently.
if [[ "${#sources[@]}" -eq 0 ]]; then
    exit 0
fi

# ----- event extraction ------------------------------------------------------

# Emit augmented JSONL: each line gets _source_path + _line. Filter by cutoff
# when --since was provided; --last is applied after sort.

tmp_raw="$(mktemp -t dogfood-digest-raw.XXXXXX)"
trap 'rm -f "$tmp_raw"' EXIT

for src in "${sources[@]}"; do
    # Use jq to inject _source_path / _line. nl-free input: use input_line_number.
    # Skip lines that don't parse (defensive: malformed drift-era rows).
    jq -c --arg path "$src" '
        . + {_source_path: $path, _line: (input_line_number)}
    ' "$src" 2>/dev/null >> "$tmp_raw" || true
done

# Sort by ts ascending. Events without ts sort to the front (unlikely in practice).
jq -sc 'sort_by(.ts // "") | .[]' "$tmp_raw" > "${tmp_raw}.sorted"
mv "${tmp_raw}.sorted" "$tmp_raw"

# Apply window filter.
case "$window_mode" in
    all)
        cat "$tmp_raw"
        ;;
    since)
        jq -c --arg cut "$cutoff_iso" 'select((.ts // "") >= $cut)' "$tmp_raw"
        ;;
    last)
        # Take last N lines (after sort). On BSD/GNU coreutils, tail behaves identically.
        tail -n "$window_last" "$tmp_raw"
        ;;
esac

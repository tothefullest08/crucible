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
#   --project-root DIR   (CI/test only) override PWD for local log resolution
#   --home DIR           (CI/test only) override $HOME for global mirror
#   -h | --help          print usage
#
# --last and --since are mutually exclusive — passing both is an error (exit 2).
# --all overrides both.
#
# Env vars (CI/test only, override --project-root / --home when set):
#   CRUCIBLE_DOGFOOD_ROOT  overrides --project-root for local log resolution
#   CRUCIBLE_DOGFOOD_HOME  overrides --home for global mirror resolution
# When either env var is applied, a one-line info message is written to stderr
# so overrides are never silent.
#
# Output: JSONL on stdout. Empty input → no lines, exit 0.
#
# Exit codes:
#   0  success (including empty input / zero sources)
#   1  runtime failure (jq/date/mv pipeline error)
#   2  argument error (unknown flag, mutex violation, bad value, mktemp failure)
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

Mutually exclusive: --last and --since. --all overrides both.

Test-only flags (not for production):
  --project-root DIR   override local log resolution root
  --home DIR           override global mirror resolution root

Test-only env vars (take precedence over the matching flags when set):
  CRUCIBLE_DOGFOOD_ROOT   overrides --project-root
  CRUCIBLE_DOGFOOD_HOME   overrides --home
When either env var changes the resolved path, a one-line info message is
printed to stderr so the override is never silent.

Exit codes:
  0  success
  1  runtime failure
  2  argument error
USAGE
}

# ----- argument parsing ------------------------------------------------------

window_mode="last"
window_last=10
window_since=""
scope="both"
project_root="${PWD}"
home_dir="${HOME}"

# Track which window flags were actually passed so --last + --since can be
# rejected per the documented mutex contract (see header comment).
saw_last=0
saw_since=0
saw_all=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --last)
            saw_last=1
            window_mode="last"
            window_last="${2:-}"
            shift 2 || { printf 'dogfood-digest: --last requires a value\n' >&2; exit 2; }
            ;;
        --since)
            saw_since=1
            window_mode="since"
            window_since="${2:-}"
            shift 2 || { printf 'dogfood-digest: --since requires a value\n' >&2; exit 2; }
            ;;
        --all)
            saw_all=1
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

# Mutex: --last and --since cannot be combined. --all takes precedence and
# collapses the conflict (documented as "--all overrides both").
if [[ "$saw_all" -eq 0 && "$saw_last" -eq 1 && "$saw_since" -eq 1 ]]; then
    printf 'dogfood-digest: --last and --since are mutually exclusive — pass one or use --all\n' >&2
    exit 2
fi

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
# for locals, and $home_dir/.claude/dogfood/crucible for globals. When an env
# var actually changes the resolved path, emit a one-line stderr info so the
# override is never silent.
if [[ -n "${CRUCIBLE_DOGFOOD_ROOT:-}" && "${CRUCIBLE_DOGFOOD_ROOT}" != "$project_root" ]]; then
    printf 'dogfood-digest: info: CRUCIBLE_DOGFOOD_ROOT=%s overrides --project-root=%s\n' \
        "$CRUCIBLE_DOGFOOD_ROOT" "$project_root" >&2
fi
if [[ -n "${CRUCIBLE_DOGFOOD_HOME:-}" && "${CRUCIBLE_DOGFOOD_HOME}" != "$home_dir" ]]; then
    printf 'dogfood-digest: info: CRUCIBLE_DOGFOOD_HOME=%s overrides --home=%s\n' \
        "$CRUCIBLE_DOGFOOD_HOME" "$home_dir" >&2
fi
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

tmp_raw="$(mktemp -t dogfood-digest-raw.XXXXXX)" || {
    printf 'dogfood-digest: mktemp failed\n' >&2
    exit 2
}
# Clean up both the raw buffer and its transient .sorted sibling on exit.
trap 'rm -f "$tmp_raw" "${tmp_raw}.sorted"' EXIT

for src in "${sources[@]}"; do
    # Process line-by-line so a single malformed row does NOT drop every
    # valid row after it. jq aborts the whole invocation on the first parse
    # error, so we must isolate each line. _source_path/_line are injected
    # per-line using the source's 1-based line number.
    line_no=0
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line_no=$((line_no + 1))
        [[ -z "$raw_line" ]] && continue
        if ! printf '%s\n' "$raw_line" \
            | jq -c --arg path "$src" --argjson ln "$line_no" \
                '. + {_source_path: $path, _line: $ln}' \
                2>/dev/null >> "$tmp_raw"; then
            printf 'dogfood-digest: warn: skipping malformed row %s:%s\n' \
                "$src" "$line_no" >&2
        fi
    done < "$src"
done

# Sort by ts ascending. Events without ts sort to the front (unlikely in practice).
if ! jq -sc 'sort_by(.ts // "") | .[]' "$tmp_raw" > "${tmp_raw}.sorted"; then
    printf 'dogfood-digest: sort pipeline failed\n' >&2
    exit 1
fi
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

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
#                        YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ (Z/UTC required —
#                        see issue #8), or "Nd" duration (e.g. 7d = 7 days ago
#                        relative to now).
#   --all                no filter (entire window)
#   --scope SCOPE        local | global | both (default both)
#   --project-root DIR   (CI/test only) override PWD for local log resolution
#   --home DIR           (CI/test only) override $HOME for global mirror
#   -h | --help          print usage
#
# --last and --since are mutually exclusive — passing both is an error (exit 2).
# --all overrides both.
#
# --last is capped at 1_000_000 to prevent overflow of bash's signed-64-bit
# arithmetic; values above the cap exit 2 with an actionable error instead of
# silently falling through to tail(1) as an illegal offset (issue #14).
#
# Each named flag may appear at most once; passing the same flag twice exits 2
# (issue #9). The "last value silently wins" footgun particularly bit
# `--scope local --scope global` callers — the report frontmatter ended up
# carrying the wrong context.
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
#   1  runtime failure (jq/date/mv/tail pipeline error)
#   2  argument error (unknown flag, duplicate flag, mutex violation,
#                       bad value, mktemp failure)
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

Constraints:
  --last is a positive integer in [1, 1000000]; out-of-range → exit 2.
  Each named flag may appear at most once (duplicate → exit 2).
  --last and --since are mutually exclusive; --all overrides both.

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

For render-time flags (--window, --threshold-n), see:
  bash scripts/dogfood-digest-render.sh --help
USAGE
}

# ----- argument parsing ------------------------------------------------------

window_mode="last"
window_last=10
window_since=""
scope="both"
project_root="${PWD}"
home_dir="${HOME}"

# Track which flags were actually passed. saw_last/saw_since/saw_all are also
# consulted for the --last/--since mutex below; the rest exist solely to
# detect duplicate flags (issue #9 — "last-value-silently-wins" across all
# named flags poisoned wrappers that concatenated user args without dedup,
# and silently swapped --scope between aggregator and renderer halves of a
# pipeline).
saw_last=0
saw_since=0
saw_all=0
saw_scope=0
saw_project_root=0
saw_home=0

# Helper: reject a duplicate occurrence of $1 by exiting 2 with an actionable
# message. Centralised so adding a new dedup'd flag stays one line in the
# case branch instead of duplicating the printf.
reject_duplicate() {
    printf 'dogfood-digest: %s passed more than once — pass it at most once\n' "$1" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --last)
            if [[ "$saw_last" -eq 1 ]]; then reject_duplicate --last; fi
            saw_last=1
            window_mode="last"
            window_last="${2:-}"
            shift 2 || { printf 'dogfood-digest: --last requires a value\n' >&2; exit 2; }
            ;;
        --since)
            # `if [[ ]]; then …; fi` (not `[[ ]] && …`) so a future `set -e`
            # cannot abort on the first occurrence — pattern repeats across
            # every dedup'd flag (residual risk from PR #24 ce-review).
            if [[ "$saw_since" -eq 1 ]]; then reject_duplicate --since; fi
            saw_since=1
            window_mode="since"
            window_since="${2:-}"
            shift 2 || { printf 'dogfood-digest: --since requires a value\n' >&2; exit 2; }
            ;;
        --all)
            if [[ "$saw_all" -eq 1 ]]; then reject_duplicate --all; fi
            saw_all=1
            window_mode="all"
            shift
            ;;
        --scope)
            if [[ "$saw_scope" -eq 1 ]]; then reject_duplicate --scope; fi
            saw_scope=1
            scope="${2:-}"
            shift 2 || { printf 'dogfood-digest: --scope requires a value\n' >&2; exit 2; }
            ;;
        --project-root)
            if [[ "$saw_project_root" -eq 1 ]]; then reject_duplicate --project-root; fi
            saw_project_root=1
            project_root="${2:-}"
            shift 2 || { printf 'dogfood-digest: --project-root requires a value\n' >&2; exit 2; }
            ;;
        --home)
            if [[ "$saw_home" -eq 1 ]]; then reject_duplicate --home; fi
            saw_home=1
            home_dir="${2:-}"
            shift 2 || { printf 'dogfood-digest: --home requires a value\n' >&2; exit 2; }
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            printf 'dogfood-digest: unknown argument: %s\n' "$1" >&2
            # Recognized misroute: render-time flag passed to the aggregator.
            # Skip the ~40-line print_help dump and emit just the targeted
            # hint plus a one-line pointer to --help. The wall of help text
            # would scroll the actionable hint off screen on terminals with
            # short scrollback (codex pr#21 review). For unrecognized flags
            # the full help is still useful as a discovery aid.
            case "$1" in
                --window|--threshold-n)
                    printf 'dogfood-digest: hint — %s is a render-time flag; pass it to scripts/dogfood-digest-render.sh instead.\n' "$1" >&2
                    printf 'dogfood-digest: for full usage: bash scripts/dogfood-digest.sh --help\n' >&2
                    ;;
                *)
                    print_help >&2
                    ;;
            esac
            exit 2
            ;;
    esac
done

# Best-effort cleanup of stale orphans from prior SIGKILL/OOM-kill runs.
# Placed right after argument parsing — *before* mutex/scope/cutoff/source
# resolution — so the prune still fires on malformed-config invocations and
# on arg-error retries that follow a SIGKILL'd run (the very paths that leak
# tempfiles in the first place). The EXIT/INT/TERM/HUP trap below handles
# graceful exits, but SIGKILL is untrappable by design — every kill -9 leaks
# a dogfood-digest-raw.XXXXXX (and its .sorted sibling) of size O(JSONL
# bytes) into $TMPDIR. 60-minute window is far longer than any real digest
# run; -mmin is honoured by both BSD (macOS) and GNU find. Stderr suppression
# + `|| true` keep the prune best-effort: any pruning failure (permission,
# missing TMPDIR) must never block a legitimate run.
find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'dogfood-digest-raw.*' -mmin +60 -delete 2>/dev/null || true

# Mutex: --last and --since cannot be combined. --all takes precedence and
# collapses the conflict (documented as "--all overrides both").
if [[ "$saw_all" -eq 0 && "$saw_last" -eq 1 && "$saw_since" -eq 1 ]]; then
    printf 'dogfood-digest: --last and --since are mutually exclusive — pass one or use --all\n' >&2
    exit 2
fi

# --all must dominate regardless of flag order. The case loop above writes
# window_mode unconditionally on every flag match, so `--all --last 5` ended
# up windowed instead of full. Re-assert the documented contract here.
if [[ "$saw_all" -eq 1 ]]; then
    window_mode="all"
fi

case "$scope" in
    local|global|both) ;;
    *)
        printf 'dogfood-digest: --scope must be local, global, or both (got: %s)\n' "$scope" >&2
        exit 2
        ;;
esac

if [[ "$window_mode" == "last" ]]; then
    if ! [[ "$window_last" =~ ^[0-9]+$ ]]; then
        printf 'dogfood-digest: --last expects a positive integer (got: %s)\n' "$window_last" >&2
        exit 2
    fi
    # Length-bound the input BEFORE any bash arithmetic. The cap is 1_000_000
    # (7 digits), so any string longer than 7 chars is out-of-range without
    # needing to parse it. This guards against issue #14: values like
    # `99999999999999999999` overflow bash's signed-64-bit `[[ -le 0 ]]`
    # comparison, which under `set -uo pipefail` errors non-fatally and
    # leaves the bogus string to flow through to tail(1) — producing exit 0
    # with empty stdout, indistinguishable from a legitimate "no signal" run.
    # Both branches emit the SAME message — they are the same semantic error
    # ("out of contract"), just guarded at different stages. Two templates
    # would force stderr scrapers to handle both; ASCII <= avoids non-UTF-8
    # capture-pipeline corruption (PR #24 P3 #5 review).
    if [[ ${#window_last} -gt 7 ]]; then
        printf 'dogfood-digest: --last must be a positive integer <= 1000000 (got: %s)\n' "$window_last" >&2
        exit 2
    fi
    # Force base-10 so values like "010" are not interpreted as octal in
    # arithmetic contexts. Bash arithmetic treats a leading-zero literal as
    # octal, which causes "08"/"09" to error and "010" to silently mean 8 —
    # diverging from the value tail(1) actually receives downstream.
    window_last=$((10#$window_last))
    if [[ "$window_last" -le 0 ]] || [[ "$window_last" -gt 1000000 ]]; then
        printf 'dogfood-digest: --last must be a positive integer <= 1000000 (got: %s)\n' "$window_last" >&2
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
        # Capture date(1) exit so out-of-range durations like 99999d don't
        # silently produce an empty cutoff_iso (which then matches every
        # event in jq's lexicographic comparison) — that path looked like a
        # successful "--since-99999d" run while returning the entire log.
        if date -v-1d +%Y-%m-%d >/dev/null 2>&1; then
            if ! cutoff_iso="$(date -u -v-"${days}"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || [[ -z "$cutoff_iso" ]]; then
                printf 'dogfood-digest: --since %sd is out of range for date(1)\n' "$days" >&2
                exit 2
            fi
        else
            if ! cutoff_iso="$(date -u -d "${days} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || [[ -z "$cutoff_iso" ]]; then
                printf 'dogfood-digest: --since %sd is out of range for date(1)\n' "$days" >&2
                exit 2
            fi
        fi
    elif [[ "$window_since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        cutoff_iso="${window_since}T00:00:00Z"
    elif [[ "$window_since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$ ]]; then
        # Accept optional fractional seconds (e.g. `T10:00:00.123Z`) — GNU
        # `date -u +%Y-%m-%dT%H:%M:%S.%NZ` and `jq -n now | strftime` both
        # produce this shape, and rejecting it forced users into the wrong
        # error path on PR #23 review (codex). Lex compare against
        # second-precision `.ts` strings stays safe: '.' (0x2E) sorts below
        # 'Z' (0x5A), so a fractional cutoff only *widens* the inclusion
        # window vs. the equivalent second-precision cutoff (more events
        # included at the boundary second, never fewer) — no silent shift.
        cutoff_iso="$window_since"
    elif [[ "$window_since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
        # Catches TZ-offset (`+HH:MM`, `-0800`, etc.) and naive datetimes
        # (no TZ marker at all). cutoff_iso feeds jq's lexicographic ts
        # compare, where '+' (0x2B) sorts below 'Z' (0x5A) — silently
        # shifting the window by hours. See issue #8 (ADV-003):
        # `--since 2026-04-15T10:00:00+09:00` matched events ~9h earlier
        # than intended. Force UTC form so the compare is unambiguous;
        # date-only and Nd inputs are unaffected. Message describes the
        # expected shape (instead of imputing "non-UTC datetime") so the
        # user can map the error to their input regardless of which
        # malformed shape they passed.
        printf 'dogfood-digest: --since ISO8601 must be YYYY-MM-DDTHH:MM:SSZ (UTC); got: %s\n' "$window_since" >&2
        printf '  → rewrite with Z (UTC) suffix, or pass YYYY-MM-DD\n' >&2
        exit 2
    else
        printf 'dogfood-digest: --since must be YYYY-MM-DD, YYYY-MM-DDTHH:MM:SSZ, or Nd (got: %s)\n' "$window_since" >&2
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
# EXIT alone misses the SIGINT/SIGTERM/SIGHUP path on some shells, so the
# trap explicitly enumerates them. SIGKILL is not trappable; that case is
# left to the OS.
trap 'rm -f "$tmp_raw" "${tmp_raw}.sorted"' EXIT INT TERM HUP

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
# Without this guard, an mv failure (e.g. disk full between sort and rename)
# would silently leave the unsorted buffer in place; --last N would then
# return the last N rows by file order, not by timestamp — silent semantic
# drift instead of a visible failure.
if ! mv "${tmp_raw}.sorted" "$tmp_raw"; then
    printf 'dogfood-digest: failed to swap sorted buffer into place\n' >&2
    exit 1
fi

# Apply window filter.
case "$window_mode" in
    all)
        cat "$tmp_raw"
        ;;
    since)
        jq -c --arg cut "$cutoff_iso" 'select((.ts // "") >= $cut)' "$tmp_raw"
        ;;
    last)
        # Take last N lines (after sort). On BSD/GNU coreutils, tail behaves
        # identically. Check tail's exit code explicitly — without `set -e`, a
        # tail failure (e.g. internal arg-parse error from a value that snuck
        # past the parse-time cap) would leave this case branch with exit 0
        # and empty stdout, which the renderer indistinguishably reports as
        # "no signal in window". The parse-time cap above already rejects
        # extreme values; this is defense-in-depth (issue #14).
        if ! tail -n "$window_last" "$tmp_raw"; then
            printf 'dogfood-digest: tail failed for --last %s\n' "$window_last" >&2
            exit 1
        fi
        ;;
esac

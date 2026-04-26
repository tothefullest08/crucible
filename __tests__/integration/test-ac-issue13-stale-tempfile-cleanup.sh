#!/usr/bin/env bash
# __tests__/integration/test-ac-issue13-stale-tempfile-cleanup.sh
#
# Regression coverage for issue #13 (ADV-009, conf 100):
#   SIGKILL/OOM-kill bypasses the EXIT/INT/TERM/HUP trap in
#   scripts/dogfood-digest.sh and scripts/dogfood-digest-render.sh, leaking
#   `dogfood-digest-raw.*` (aggregator, plus `.sorted` siblings) and
#   `dogfood-digest-in.*` (renderer) tempfiles into $TMPDIR.
#
# The fix adds a startup `find ... -mmin +60 -delete` pass before each
# script's `mktemp` call. This test:
#   1. Plants a stale orphan (mtime well beyond 60 min) in $TMPDIR.
#   2. Plants a fresh file (current mtime) under the same prefix.
#   3. Runs the script under test in a sandboxed empty project.
#   4. Asserts the stale file was pruned and the fresh file was preserved.
#
# Exit 0 = both scripts pass. Exit 1 = at least one assertion failed.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
aggregator="$repo_root/scripts/dogfood-digest.sh"
renderer="$repo_root/scripts/dogfood-digest-render.sh"

for f in "$aggregator" "$renderer"; do
    if [[ ! -r "$f" ]]; then
        printf 'FAIL: missing prerequisite: %s\n' "$f" >&2
        exit 1
    fi
done

fail=0
pass() { printf '  ✓ %s\n' "$1"; }
faile() { fail=1; printf '  ✗ %s — %s\n' "$1" "${2:-}"; }

# Use a fresh isolated TMPDIR so we never delete the real user's tempfiles.
tmproot="$(mktemp -d -t dfd-issue13.XXXXXX)"
tmpproj="$(mktemp -d -t dfd-issue13-proj.XXXXXX)"
tmphome="$(mktemp -d -t dfd-issue13-home.XXXXXX)"
trap 'rm -rf "$tmproot" "$tmpproj" "$tmphome"' EXIT

# Project sandbox is intentionally empty (no log.jsonl) so the aggregator
# exits with zero sources after the cleanup pass runs. That is the path we
# want exercised — we are not testing aggregation here, only the prune.
mkdir -p "$tmpproj/.claude/dogfood"

# Pre-compute mtime stamps as ISO8601 UTC strings so `touch -d` interprets
# them as absolute UTC instants. `touch -t` would parse the prior
# YYYYMMDDhhmm.SS form in *local* time, which silently shifts the mtime by
# the local TZ offset (e.g. KST=+9h pushed a 30-min stamp ~9.5h into the
# past — surviving 60-min prunes for a different reason than intended).
# Both BSD (macOS) and GNU touch accept the `-d ISO8601[Z]` form.
stamp="$(date -u -r "$(( $(date -u +%s) - 7200 ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "@$(( $(date -u +%s) - 7200 ))" +%Y-%m-%dT%H:%M:%SZ)"

# Pre-compute a ~30-min-ago mtime stamp for the lower-bound assertion: files
# *just under* the 60-minute prune boundary must survive. This catches a
# regression that flips `find ... -mmin +60` to `-mmin -60` (the opposite
# condition), which would still pass the upper-bound (~120 min) and fresh
# (current mtime) assertions but silently delete files inside the 60-minute
# window — exactly the runs the prune is designed to spare.
stamp_30="$(date -u -r "$(( $(date -u +%s) - 1800 ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "@$(( $(date -u +%s) - 1800 ))" +%Y-%m-%dT%H:%M:%SZ)"

# ---------------------------------------------------------------------------
# Aggregator: dogfood-digest-raw.* prune
# ---------------------------------------------------------------------------

printf '\n[1/2] dogfood-digest.sh — stale dogfood-digest-raw.* prune\n'

stale_raw="$tmproot/dogfood-digest-raw.STALEXX"
stale_sorted="$tmproot/dogfood-digest-raw.STALEYY.sorted"
fresh_raw="$tmproot/dogfood-digest-raw.FRESHXX"
recent_raw="$tmproot/dogfood-digest-raw.RECENT30"

: > "$stale_raw"
: > "$stale_sorted"
: > "$fresh_raw"
: > "$recent_raw"

touch -d "$stamp" "$stale_raw" "$stale_sorted"
touch -d "$stamp_30" "$recent_raw"

TMPDIR="$tmproot" "$aggregator" --all --scope local \
    --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1

if [[ ! -e "$stale_raw" ]]; then
    pass "stale dogfood-digest-raw.* pruned on startup"
else
    faile "stale dogfood-digest-raw.* survived startup prune" "still present at $stale_raw"
fi
if [[ ! -e "$stale_sorted" ]]; then
    pass "stale dogfood-digest-raw.*.sorted pruned on startup"
else
    faile "stale dogfood-digest-raw.*.sorted survived startup prune" "still present at $stale_sorted"
fi
if [[ -e "$fresh_raw" ]]; then
    pass "fresh dogfood-digest-raw.* preserved (mtime within 60min window)"
else
    faile "fresh dogfood-digest-raw.* incorrectly pruned" "missing $fresh_raw"
fi
if [[ -e "$recent_raw" ]]; then
    pass "30-min-old dogfood-digest-raw.* preserved (lower-bound: just under 60min)"
else
    faile "30-min-old dogfood-digest-raw.* incorrectly pruned" "missing $recent_raw — find condition may have flipped from -mmin +60 to -mmin -60"
fi

# ---------------------------------------------------------------------------
# Renderer: dogfood-digest-in.* prune
# ---------------------------------------------------------------------------

printf '\n[2/2] dogfood-digest-render.sh — stale dogfood-digest-in.* prune\n'

stale_in="$tmproot/dogfood-digest-in.STALEXX"
fresh_in="$tmproot/dogfood-digest-in.FRESHXX"
recent_in="$tmproot/dogfood-digest-in.RECENT30"

: > "$stale_in"
: > "$fresh_in"
: > "$recent_in"

touch -d "$stamp" "$stale_in"
touch -d "$stamp_30" "$recent_in"

# Renderer reads JSONL on stdin; pipe an empty stream so it produces an
# empty-section report and exits 0. The startup cleanup runs before the
# mktemp call regardless of input shape.
printf '' | TMPDIR="$tmproot" "$renderer" --window all >/dev/null 2>&1

if [[ ! -e "$stale_in" ]]; then
    pass "stale dogfood-digest-in.* pruned on startup"
else
    faile "stale dogfood-digest-in.* survived startup prune" "still present at $stale_in"
fi
if [[ -e "$fresh_in" ]]; then
    pass "fresh dogfood-digest-in.* preserved (mtime within 60min window)"
else
    faile "fresh dogfood-digest-in.* incorrectly pruned" "missing $fresh_in"
fi
if [[ -e "$recent_in" ]]; then
    pass "30-min-old dogfood-digest-in.* preserved (lower-bound: just under 60min)"
else
    faile "30-min-old dogfood-digest-in.* incorrectly pruned" "missing $recent_in — find condition may have flipped from -mmin +60 to -mmin -60"
fi

printf '\n'
if [[ "$fail" -eq 0 ]]; then
    printf 'PASS — issue #13 stale-tempfile cleanup\n'
    exit 0
else
    printf 'FAIL — issue #13 stale-tempfile cleanup\n' >&2
    exit 1
fi

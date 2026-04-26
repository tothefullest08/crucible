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

# Pre-compute a ~120-min-ago mtime stamp portable across BSD (macOS) and GNU
# date. -t accepts [[CC]YY]MMDDhhmm[.SS] on both BSD touch and GNU touch.
stamp="$(date -u -r "$(( $(date -u +%s) - 7200 ))" +%Y%m%d%H%M.%S 2>/dev/null \
        || date -u -d "@$(( $(date -u +%s) - 7200 ))" +%Y%m%d%H%M.%S)"

# ---------------------------------------------------------------------------
# Aggregator: dogfood-digest-raw.* prune
# ---------------------------------------------------------------------------

printf '\n[1/2] dogfood-digest.sh — stale dogfood-digest-raw.* prune\n'

stale_raw="$tmproot/dogfood-digest-raw.STALEXX"
stale_sorted="$tmproot/dogfood-digest-raw.STALEYY.sorted"
fresh_raw="$tmproot/dogfood-digest-raw.FRESHXX"

: > "$stale_raw"
: > "$stale_sorted"
: > "$fresh_raw"

touch -t "$stamp" "$stale_raw" "$stale_sorted"

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

# ---------------------------------------------------------------------------
# Renderer: dogfood-digest-in.* prune
# ---------------------------------------------------------------------------

printf '\n[2/2] dogfood-digest-render.sh — stale dogfood-digest-in.* prune\n'

stale_in="$tmproot/dogfood-digest-in.STALEXX"
fresh_in="$tmproot/dogfood-digest-in.FRESHXX"

: > "$stale_in"
: > "$fresh_in"

touch -t "$stamp" "$stale_in"

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

printf '\n'
if [[ "$fail" -eq 0 ]]; then
    printf 'PASS — issue #13 stale-tempfile cleanup\n'
    exit 0
else
    printf 'FAIL — issue #13 stale-tempfile cleanup\n' >&2
    exit 1
fi

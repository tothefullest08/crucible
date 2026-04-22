#!/usr/bin/env bash
# __tests__/integration/test-dogfood-digest.sh — SC-1 ~ SC-7 coverage for the
# /crucible:dogfood-digest skill.
#
# SC-1: filename matches YYYY-MM-DD-dogfood-digest-{window}.md (last N · since · all).
# SC-2: report contains 3 fixed sections + each non-empty suggestion has a
#       `path:line` back-reference.
# SC-3: --since 7d · --last 20 · --all each apply the correct window filter.
# SC-4: running the aggregator + renderer + save does not mutate any tracked
#       file outside .claude/plans/ (read-only invariant).
# SC-5: when a section has at least 1 suggestion, every suggestion cites >=1
#       source event; empty sections render "no signal in window".
# SC-6: 0-event input produces a well-formed report with 3 empty sections and
#       exit 0 (never errors).
# SC-7: --scope local|global|both each return the expected subset of events.
#
# Isolation: runs inside a fresh mktemp-d "project" so the real repo is never
# touched. The aggregator is called with --project-root and --home so it reads
# only the sandbox copies of the fixture.
#
# Exit 0 = all sub-tests PASS. Exit 1 = at least one failure.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root" || exit 1

aggregator="$repo_root/scripts/dogfood-digest.sh"
renderer="$repo_root/scripts/dogfood-digest-render.sh"
fixture="$repo_root/__tests__/fixtures/dogfood-digest-fixture.jsonl"

for f in "$aggregator" "$renderer" "$fixture"; do
    if [[ ! -r "$f" ]]; then
        printf 'FAIL: missing prerequisite: %s\n' "$f" >&2
        exit 1
    fi
done

fail=0
details=""

pass() { printf '  ✓ %s\n' "$1"; }
faile() { fail=1; details+="  ✗ $1${2:+ — $2}\n"; printf '  ✗ %s %s\n' "$1" "${2:-}"; }

# ----------------------------------------------------------------------------
# sandbox setup — local + global fixture copies
# ----------------------------------------------------------------------------

tmpproj="$(mktemp -d -t dfd-proj.XXXXXX)"
tmphome="$(mktemp -d -t dfd-home.XXXXXX)"
trap 'rm -rf "$tmpproj" "$tmphome"' EXIT

mkdir -p "$tmpproj/.claude/dogfood"
cp "$fixture" "$tmpproj/.claude/dogfood/log.jsonl"

mkdir -p "$tmphome/.claude/dogfood/crucible/sandbox-deadbeef"
cp "$fixture" "$tmphome/.claude/dogfood/crucible/sandbox-deadbeef/log.jsonl"

fixture_lines=$(wc -l < "$fixture" | tr -d ' ')

# ----------------------------------------------------------------------------
# SC-7 — --scope routing
# ----------------------------------------------------------------------------

printf 'SC-7: --scope routing (local | global | both)\n'

local_count=$("$aggregator" --all --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$local_count" -eq "$fixture_lines" ]]; then pass "local scope returns $local_count events"; else faile "SC-7 local" "got $local_count want $fixture_lines"; fi

global_count=$("$aggregator" --all --scope global --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$global_count" -eq "$fixture_lines" ]]; then pass "global scope returns $global_count events"; else faile "SC-7 global" "got $global_count want $fixture_lines"; fi

both_count=$("$aggregator" --all --scope both --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
expected_both=$((fixture_lines * 2))
if [[ "$both_count" -eq "$expected_both" ]]; then pass "both scope returns $both_count events (2x fixture)"; else faile "SC-7 both" "got $both_count want $expected_both"; fi

# ----------------------------------------------------------------------------
# SC-3 — window filters
# ----------------------------------------------------------------------------

printf 'SC-3: window filters\n'

last_count=$("$aggregator" --last 20 --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$last_count" -eq "$fixture_lines" ]]; then pass "--last 20 returns all $last_count (fixture has $fixture_lines ≤ 20)"; else faile "SC-3 --last 20" "got $last_count"; fi

last5_count=$("$aggregator" --last 5 --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$last5_count" -eq 5 ]]; then pass "--last 5 returns 5 events"; else faile "SC-3 --last 5" "got $last5_count"; fi

# --since: 2026-04-17 cutoff → fixture events from that date onward.
since_count=$("$aggregator" --since 2026-04-17 --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
expected_since=$(jq -c --arg c "2026-04-17T00:00:00Z" 'select(.ts >= $c)' "$fixture" | wc -l | tr -d ' ')
if [[ "$since_count" -eq "$expected_since" ]]; then pass "--since 2026-04-17 returns $since_count (expected $expected_since)"; else faile "SC-3 --since ABS" "got $since_count want $expected_since"; fi

# --since Nd — fixture is from past, so "--since 1d" (yesterday-only) should return 0 because all events predate it.
since_1d=$("$aggregator" --since 1d --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$since_1d" -eq 0 ]]; then pass "--since 1d returns 0 (fixture predates yesterday)"; else faile "SC-3 --since 1d" "got $since_1d want 0"; fi

all_count=$("$aggregator" --all --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$all_count" -eq "$fixture_lines" ]]; then pass "--all returns $all_count events"; else faile "SC-3 --all" "got $all_count"; fi

# mutually exclusive flags — aggregator treats --last after --since as override (last wins),
# which is the documented behavior. No hard error needed.

# ----------------------------------------------------------------------------
# End-to-end render + save (SC-1, SC-2, SC-5)
# ----------------------------------------------------------------------------

printf 'SC-1/2/5: render + save\n'

mkdir -p "$tmpproj/.claude/plans"

window="last10"
today=$(date -u +%Y-%m-%d)
outfile="$tmpproj/.claude/plans/${today}-dogfood-digest-${window}.md"

"$aggregator" --last 10 --scope local --project-root "$tmpproj" --home "$tmphome" \
    | "$renderer" --window "$window" --scope local > "$outfile"

if [[ -s "$outfile" ]]; then pass "SC-1 report file created at ${outfile#$tmpproj/}"; else faile "SC-1 report file" "missing or empty: $outfile"; fi

# SC-1 filename regex assertion — accept last{N} | since-DATE | since-Nd | all.
if [[ "$(basename "$outfile")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-dogfood-digest-(last[0-9]+|since-[0-9]{4}-[0-9]{2}-[0-9]{2}|since-[0-9]+d|all)\.md$ ]]; then
    pass "SC-1 filename matches window pattern"
else
    faile "SC-1 filename pattern" "$(basename "$outfile")"
fi

# SC-2 three sections present
if grep -q '^## Threshold Calibration$' "$outfile" \
    && grep -q '^## Protocol Improvements$' "$outfile" \
    && grep -q '^## Promotion Candidates$' "$outfile"; then
    pass "SC-2 three fixed sections present"
else
    faile "SC-2 three sections"
fi

# SC-2 back-reference: at least one path:line citation exists somewhere in
# the report. With the fixture we expect pain + request notes to populate
# Protocol + Promotion sections, so back-references are guaranteed.
if grep -E -q '`[^`]+\.claude/dogfood/[^`]+:[0-9]+`' "$outfile"; then
    pass "SC-2 back-references present (path:line)"
else
    faile "SC-2 back-references"
fi

# SC-5 each non-empty suggestion cites >=1 source event. Simpler rule: the
# number of top-level suggestion bullets (`^- \*\*`) must equal the number
# of `근거:` citation markers, because the renderer emits exactly one 근거
# line per bullet (either as a sub-bullet or inline on the same line).
bullet_n=$(grep -cE '^- \*\*' "$outfile" || true)
cite_n=$(grep -cE '근거:' "$outfile" || true)
if [[ "$bullet_n" -gt 0 && "$bullet_n" -eq "$cite_n" ]]; then
    pass "SC-5 every non-empty suggestion cites a source ($bullet_n bullets, $cite_n citations)"
else
    faile "SC-5 suggestion citations" "bullets=$bullet_n citations=$cite_n"
fi

# SC-5 empty section handling — force an empty window and check "no signal".
empty_file="$tmpproj/.claude/plans/${today}-dogfood-digest-since-1d.md"
"$aggregator" --since 1d --scope local --project-root "$tmpproj" --home "$tmphome" \
    | "$renderer" --window "since-1d" --scope local > "$empty_file"

if grep -q 'no signal in window' "$empty_file"; then
    pass "SC-5 empty-section fallback renders 'no signal in window'"
else
    faile "SC-5 empty-section fallback"
fi

# ----------------------------------------------------------------------------
# SC-6 — zero-event input yields clean exit 0
# ----------------------------------------------------------------------------

printf 'SC-6: zero-event handling\n'

empty_proj="$(mktemp -d -t dfd-empty.XXXXXX)"
empty_home="$(mktemp -d -t dfd-emptyh.XXXXXX)"

set +e
"$aggregator" --all --scope both --project-root "$empty_proj" --home "$empty_home" \
    | "$renderer" --window "all" --scope both > "$empty_proj/out.md"
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then pass "SC-6 zero-event exit code = 0"; else faile "SC-6 exit code" "got $rc"; fi
if grep -q '^## Threshold Calibration$' "$empty_proj/out.md" \
    && grep -q '^## Protocol Improvements$' "$empty_proj/out.md" \
    && grep -q '^## Promotion Candidates$' "$empty_proj/out.md" \
    && grep -q 'no signal in window' "$empty_proj/out.md"; then
    pass "SC-6 zero-event report has 3 sections + no signal"
else
    faile "SC-6 zero-event content"
fi
rm -rf "$empty_proj" "$empty_home"

# ----------------------------------------------------------------------------
# SC-4 — read-only invariant (no mutation to tracked files)
# ----------------------------------------------------------------------------

printf 'SC-4: read-only invariant (no tracked-file mutation)\n'

# Snapshot the real repo's tracked files BEFORE running the pipeline against
# the real repo paths. We invoke the aggregator with --project-root = real
# repo (read-only usage), but we still write the report into the sandbox's
# plans dir via stdout redirection — never touching the real repo tree.

pre_hash="$(cd "$repo_root" && git ls-files -z | xargs -0 shasum -a 256 2>/dev/null | shasum -a 256 | awk '{print $1}')"

"$aggregator" --all --scope local --project-root "$repo_root" --home "$tmphome" \
    | "$renderer" --window "all" --scope local > "$tmpproj/.claude/plans/${today}-dogfood-digest-readonly-check.md"

post_hash="$(cd "$repo_root" && git ls-files -z | xargs -0 shasum -a 256 2>/dev/null | shasum -a 256 | awk '{print $1}')"

if [[ "$pre_hash" == "$post_hash" ]]; then
    pass "SC-4 tracked-file hashes unchanged (no mutation)"
else
    faile "SC-4 tracked-file mutation" "pre=$pre_hash post=$post_hash"
fi

# ----------------------------------------------------------------------------
# Recursion filter — SKILL.md validate_prompt #4 semantic check
# ----------------------------------------------------------------------------

printf 'RECURSION: self-skill_call is dropped from sections\n'

# The fixture contains one /crucible:dogfood-digest skill_call event. It
# should NOT appear as a back-reference inside the Protocol / Promotion
# sections. We check that no suggestion line cites a /crucible:dogfood-digest
# text token.
if grep -E -q '\*\*/crucible:dogfood-digest\*\*' "$outfile"; then
    faile "recursion filter" "self skill_call leaked into a section key"
else
    pass "recursion filter drops self skill_call events"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

if [[ "$fail" -eq 0 ]]; then
    printf '\ntest-dogfood-digest: ALL PASS (SC-1~7 + recursion filter)\n'
    exit 0
else
    printf '\ntest-dogfood-digest: FAIL\n'
    printf '%b' "$details"
    exit 1
fi

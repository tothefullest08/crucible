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

# --since future — pick a cutoff far enough ahead that no fixture event can
# ever match (date-stable; no dependency on `date -v-1d` vs today's clock).
since_future=$("$aggregator" --since 2099-01-01 --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$since_future" -eq 0 ]]; then pass "--since 2099-01-01 returns 0 (future cutoff never matches fixture)"; else faile "SC-3 --since future" "got $since_future want 0"; fi

all_count=$("$aggregator" --all --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$all_count" -eq "$fixture_lines" ]]; then pass "--all returns $all_count events"; else faile "SC-3 --all" "got $all_count"; fi

# Mutex — --last and --since cannot be combined (exit 2). --all overrides both.
printf 'SC-3/MUTEX: --last + --since mutual exclusion\n'
set +e
"$aggregator" --last 5 --since 2099-01-01 --scope local \
    --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
mutex_rc=$?
set -e
if [[ "$mutex_rc" -eq 2 ]]; then pass "mutex --last + --since exits 2"; else faile "mutex exit" "got $mutex_rc want 2"; fi
set +e
"$aggregator" --last 5 --since 2099-01-01 --all --scope local \
    --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
mutex_all_rc=$?
set -e
if [[ "$mutex_all_rc" -eq 0 ]]; then pass "mutex + --all overrides to 0"; else faile "mutex+all exit" "got $mutex_all_rc want 0"; fi

# --threshold-n validation — non-integer / zero / negative rejected (exit 2).
printf 'THRESHOLD-N: validation\n'
for bad in abc 0 -1 ""; do
    set +e
    echo '' | "$renderer" --window t --threshold-n "$bad" >/dev/null 2>&1
    rc=$?
    set -e
    if [[ "$rc" -eq 2 ]]; then pass "--threshold-n '$bad' rejected (exit 2)"; else faile "--threshold-n '$bad'" "got $rc want 2"; fi
done

# ADV-001: --all must dominate window_mode regardless of flag order.
# Without the post-parse override, "--all --last 5" used to silently
# narrow to the last 5 events instead of returning the full window.
printf 'ADV-001: --all dominates regardless of flag order\n'
all_first=$("$aggregator" --all --last 5 --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
last_first=$("$aggregator" --last 5 --all --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$all_first" -eq "$fixture_lines" && "$last_first" -eq "$fixture_lines" ]]; then
    pass "--all dominates --last regardless of order ($all_first / $last_first events)"
else
    faile "--all order dominance" "all-first=$all_first last-first=$last_first want $fixture_lines"
fi

# ADV-004: --last 010 must not be misread as octal 8 by bash arithmetic.
# Force base-10 means "010" is treated as decimal 10 (== fixture_lines if
# fixture has at least 10 events). The validator no longer errors on "08"/"09".
printf 'ADV-004: --last force-base-10\n'
set +e
last010_count=$("$aggregator" --last 010 --scope local --project-root "$tmpproj" --home "$tmphome" 2>/dev/null | wc -l | tr -d ' ')
last010_rc=$?
set -e
if [[ "$last010_rc" -eq 0 && "$last010_count" -eq 10 ]]; then
    pass "--last 010 treated as decimal 10 (got $last010_count events)"
else
    faile "--last 010 base-10" "rc=$last010_rc count=$last010_count want rc=0 count=10"
fi
set +e
"$aggregator" --last 09 --scope local --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
last09_rc=$?
set -e
if [[ "$last09_rc" -eq 0 ]]; then pass "--last 09 accepted as decimal 9"; else faile "--last 09 base-10" "rc=$last09_rc want 0"; fi

# ADV-002: --since with an unreasonable Nd value must surface a clear error
# instead of silently returning every event with exit 0.
printf 'ADV-002: --since out-of-range surfaces error\n'
set +e
"$aggregator" --since 99999d --scope local --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
since_rc=$?
set -e
if [[ "$since_rc" -eq 2 ]]; then
    pass "--since 99999d exits 2 (out of range)"
else
    faile "--since 99999d" "got $since_rc want 2"
fi

# cli-readiness #2: render.sh must validate --scope, mirroring the aggregator.
# Without it, --scope foo silently lands as "scope: foo" in the YAML
# frontmatter — divergent semantics across the two scripts.
printf 'CLI: render --scope validation\n'
set +e
echo '' | "$renderer" --window t --scope bogus >/dev/null 2>&1
render_scope_rc=$?
set -e
if [[ "$render_scope_rc" -eq 2 ]]; then
    pass "render --scope bogus rejected (exit 2)"
else
    faile "render --scope validation" "got $render_scope_rc want 2"
fi

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
# Section inner-block-empty fallback — Protocol & Promotion sections must
# emit "no signal in window" when the outer guard passes (e.g. skip_count >= 2)
# but EVERY inner block produces zero rows (e.g. all skip reasons are unique).
# Without the section_emitted tracker, this leaves a header followed
# immediately by the next section's header with no body — an SC-5 violation.
# ----------------------------------------------------------------------------

printf 'SECTION INNER-EMPTY: Protocol/Promotion fall back to "no signal"\n'

inner_proj="$(mktemp -d -t dfd-inner.XXXXXX)"
mkdir -p "$inner_proj/.claude/dogfood"
cat > "$inner_proj/.claude/dogfood/log.jsonl" <<'INNER_FIXTURE'
{"ts":"2026-04-20T00:00:00Z","type":"axis_skip","axis":"plan","reason":"unique-reason-a","acknowledged":true}
{"ts":"2026-04-20T00:00:01Z","type":"axis_skip","axis":"plan","reason":"unique-reason-b","acknowledged":true}
{"ts":"2026-04-20T00:00:02Z","type":"axis_skip","axis":"plan","reason":"unique-reason-c","acknowledged":true}
INNER_FIXTURE

inner_outfile="$inner_proj/digest.md"
"$aggregator" --all --scope local --project-root "$inner_proj" --home "$inner_proj" \
    | "$renderer" --window "all" --scope local > "$inner_outfile"

# Protocol section must NOT be empty body. Capture text between
# "## Protocol Improvements" and the next "##" header.
proto_body=$(awk '/^## Protocol Improvements$/{flag=1;next}/^## /{flag=0}flag' "$inner_outfile")
proto_signal=$(printf '%s\n' "$proto_body" | grep -c 'no signal in window' || true)
if [[ "$proto_signal" -ge 1 ]]; then
    pass "Protocol section emits 'no signal' when all skip reasons are unique"
else
    faile "Protocol inner-empty fallback" "section body missing 'no signal' marker"
fi
rm -rf "$inner_proj"

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
# Threshold Calibration + skip_reasons — full-fixture render coverage
# ----------------------------------------------------------------------------
#
# The --last 10 render above only captures qa_count=0 and skip_count=1 so the
# Threshold "else" branch and the Protocol skip_reasons sub-block never fire.
# Render the full fixture here to exercise p50/p95 awk, verdict histogram,
# axis_skip frequency, and recurring skip-reason grouping.

printf 'THRESHOLD+SKIP: full-fixture render coverage\n'

full_outfile="$tmpproj/.claude/plans/${today}-dogfood-digest-all.md"
"$aggregator" --all --scope local --project-root "$tmpproj" --home "$tmphome" \
    | "$renderer" --window "all" --scope local > "$full_outfile"

if grep -q 'qa_judge score distribution' "$full_outfile" \
    && grep -q 'p50=' "$full_outfile" \
    && grep -q 'verdicts:' "$full_outfile"; then
    pass "Threshold else branch renders qa_judge distribution + p50/p95 + verdicts"
else
    faile "Threshold else branch coverage"
fi

if grep -q 'axis_skip 빈도' "$full_outfile"; then
    pass "Threshold else branch renders axis_skip histogram"
else
    faile "axis_skip histogram coverage"
fi

# skip_reasons sub-block requires skip_count >= 2 AND a reason with n >= 2.
# Fixture has two "urgent prototype" axis_skip events.
if grep -q '반복 skip reason.*urgent prototype' "$full_outfile"; then
    pass "Protocol skip_reasons sub-block renders recurring reason"
else
    faile "skip_reasons sub-block coverage"
fi

# Back-reference density — at least 3 path:line citations in the full render.
back_refs=$(grep -cE '`[^`]+:[0-9]+`' "$full_outfile" || true)
if [[ "$back_refs" -ge 3 ]]; then
    pass "Full render has >= 3 back-references ($back_refs found)"
else
    faile "back-reference density" "got $back_refs want >=3"
fi

# ----------------------------------------------------------------------------
# --threshold-n render effects — n=1 surfaces signal, n=99 suppresses it.
# ----------------------------------------------------------------------------

printf 'THRESHOLD-N: render effect at boundary values\n'

tn1_outfile="$tmpproj/.claude/plans/${today}-dogfood-digest-all-tn1.md"
"$aggregator" --all --scope local --project-root "$tmpproj" --home "$tmphome" \
    | "$renderer" --window "all" --scope local --threshold-n 1 > "$tn1_outfile"
if grep -q 'qa_judge score distribution' "$tn1_outfile"; then
    pass "--threshold-n 1 surfaces qa_judge block even at low sample counts"
else
    faile "--threshold-n 1 effect"
fi

tn99_outfile="$tmpproj/.claude/plans/${today}-dogfood-digest-all-tn99.md"
"$aggregator" --all --scope local --project-root "$tmpproj" --home "$tmphome" \
    | "$renderer" --window "all" --scope local --threshold-n 99 > "$tn99_outfile"
if grep -q 'no signal in window (qa_judge n=.*threshold-n=99' "$tn99_outfile"; then
    pass "--threshold-n 99 suppresses Threshold section (no signal)"
else
    faile "--threshold-n 99 effect"
fi

# ----------------------------------------------------------------------------
# Malformed JSONL resilience — jq must NOT drop rows after a bad line.
# ----------------------------------------------------------------------------

printf 'MALFORMED: per-line parsing survives bad rows\n'

mal_proj="$(mktemp -d -t dfd-mal.XXXXXX)"
mkdir -p "$mal_proj/.claude/dogfood"
cat > "$mal_proj/.claude/dogfood/log.jsonl" <<'BAD_JSONL'
{"ts":"2020-01-01T00:00:00Z","type":"note","category":"pain","text":"before bad row"}
THIS_IS_NOT_JSON
{"ts":"2020-01-02T00:00:00Z","type":"note","category":"good","text":"after bad row"}
BAD_JSONL
mal_count=$("$aggregator" --all --scope local --project-root "$mal_proj" --home "$tmphome" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$mal_count" -eq 2 ]]; then
    pass "malformed row skipped, 2 valid rows survive"
else
    faile "malformed JSONL survivorship" "got $mal_count want 2"
fi

# Warning on malformed row goes to stderr.
mal_stderr=$("$aggregator" --all --scope local --project-root "$mal_proj" --home "$tmphome" 2>&1 >/dev/null)
if printf '%s' "$mal_stderr" | grep -q 'warn: skipping malformed row'; then
    pass "malformed row emits stderr warning"
else
    faile "malformed stderr warning" "no warning found"
fi
rm -rf "$mal_proj"

# ----------------------------------------------------------------------------
# Recursion filter — SKILL.md validate_prompt #4 semantic check
# ----------------------------------------------------------------------------
#
# Anchored regex ^/?crucible:dogfood-digest$ drops exactly one self-call from
# fixture (line 17 with skill="/crucible:dogfood-digest") and must PRESERVE
# sibling-skill calls like /crucible:dogfood-digest-v2 (fixture line 18).
# total_events in the full render should therefore equal (fixture_lines - 1).

printf 'RECURSION: self-skill_call dropped, sibling skills preserved\n'

total_events=$(grep -E '^total_events: ' "$full_outfile" | awk '{print $2}')
expected_total=$((fixture_lines - 1))
if [[ "$total_events" -eq "$expected_total" ]]; then
    pass "total_events=$total_events matches (fixture_lines - 1 recursion drop)"
else
    faile "recursion total_events" "got $total_events want $expected_total"
fi

# Sanity: the sibling-skill event must still be countable in the aggregator output.
sibling_present=$("$aggregator" --all --scope local --project-root "$tmpproj" --home "$tmphome" \
    | grep -c 'crucible:dogfood-digest-v2' || true)
if [[ "$sibling_present" -ge 1 ]]; then
    pass "anchored regex preserves crucible:dogfood-digest-v2 event"
else
    faile "anchored regex false positive" "sibling skill dropped"
fi

# Self-skill_call must NOT leak into a section key (keeps the original assertion).
if grep -E -q '\*\*/crucible:dogfood-digest\*\*' "$outfile"; then
    faile "recursion section leak" "self skill_call appeared as a section key"
else
    pass "recursion filter keeps self skill_call out of section keys"
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

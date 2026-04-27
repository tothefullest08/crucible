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

# ADV-003 (issue #8): --since with TZ-offset ISO8601 must be rejected. Without
# the regex tightening, `2099-01-01T00:00:00+09:00` flowed through to jq's
# lexicographic compare, where '+' (0x2B) < 'Z' (0x5A) shifted the window by
# hours and silently matched events the user did not intend.
printf 'ADV-003: --since TZ-offset rejected, Z-suffix preserved\n'

# Future TZ-offset cutoff: must be REJECTED with exit 2 (not silently accepted).
set +e
tz_stderr=$("$aggregator" --since '2099-01-01T00:00:00+09:00' --scope local \
    --project-root "$tmpproj" --home "$tmphome" 2>&1 >/dev/null)
tz_rc=$?
set -e
if [[ "$tz_rc" -eq 2 ]]; then
    pass "--since TZ-offset (+09:00) exits 2"
else
    faile "ADV-003 TZ-offset rc" "got $tz_rc want 2"
fi
if printf '%s' "$tz_stderr" | grep -q 'Z (UTC) suffix'; then
    pass "--since TZ-offset error names Z (UTC) suffix as the fix"
else
    faile "ADV-003 TZ-offset error message" "stderr did not mention Z (UTC) suffix"
fi

# Negative TZ-offset is the same failure class — must also exit 2.
set +e
"$aggregator" --since '2099-01-01T00:00:00-08:00' --scope local \
    --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
neg_rc=$?
set -e
if [[ "$neg_rc" -eq 2 ]]; then
    pass "--since negative TZ-offset (-08:00) exits 2"
else
    faile "ADV-003 negative TZ-offset" "got $neg_rc want 2"
fi

# Naive datetime (no TZ designator at all) is ambiguous and must also be
# rejected — same lexicographic-compare hazard, just less obvious.
set +e
"$aggregator" --since '2099-01-01T00:00:00' --scope local \
    --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
naive_rc=$?
set -e
if [[ "$naive_rc" -eq 2 ]]; then
    pass "--since naive datetime (no TZ) exits 2"
else
    faile "ADV-003 naive datetime" "got $naive_rc want 2"
fi

# Z-suffix ISO8601 must continue to work — regression guard for the existing
# accepted form. Use a future cutoff so the result is independent of fixture ts.
z_count=$("$aggregator" --since '2099-01-01T00:00:00Z' --scope local \
    --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$z_count" -eq 0 ]]; then
    pass "--since Z-suffix '2099-01-01T00:00:00Z' still accepted (returns 0 events)"
else
    faile "ADV-003 Z-suffix regression" "got $z_count want 0"
fi

# Z-suffix with fractional seconds must also be accepted — `date -u +...%NZ`
# and `jq -n now | strftime` both produce this shape, and rejecting it forced
# users into the wrong error path on PR #23 review (the rejection message told
# them to add Z, which they had already done).
z_frac_count=$("$aggregator" --since '2099-01-01T00:00:00.123Z' --scope local \
    --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$z_frac_count" -eq 0 ]]; then
    pass "--since Z-suffix with fractional seconds '2099-01-01T00:00:00.123Z' accepted (returns 0 events)"
else
    faile "ADV-003 Z-suffix fractional" "got $z_frac_count want 0"
fi

# Fractional seconds must NOT exit 2 — pin the contract so a future regex
# tightening cannot silently regress to the rejection path.
set +e
"$aggregator" --since '2099-01-01T00:00:00.123Z' --scope local \
    --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
z_frac_rc=$?
set -e
if [[ "$z_frac_rc" -eq 0 ]]; then
    pass "--since Z-suffix fractional exits 0 (regex accepts, no error path)"
else
    faile "ADV-003 Z-suffix fractional rc" "got $z_frac_rc want 0"
fi

# Error message for malformed datetimes must describe the expected shape
# rather than impute "non-UTC datetime". The previous wording was misleading
# for naive datetimes (no TZ marker at all) and contradicted user input on
# fractional-Z (which is now accepted, but the contract should still hold).
set +e
shape_stderr=$("$aggregator" --since '2099-01-01T00:00:00+09:00' --scope local \
    --project-root "$tmpproj" --home "$tmphome" 2>&1 >/dev/null)
set -e
if printf '%s' "$shape_stderr" | grep -q 'must be YYYY-MM-DDTHH:MM:SSZ'; then
    pass "--since malformed-TZ error describes expected shape"
else
    faile "ADV-003 shape error" "stderr did not describe expected shape"
fi

# Date-only and Nd inputs must be unaffected by the regex tightening.
date_only_count=$("$aggregator" --since 2099-01-01 --scope local \
    --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$date_only_count" -eq 0 ]]; then
    pass "--since date-only '2099-01-01' unaffected (returns 0 events)"
else
    faile "ADV-003 date-only regression" "got $date_only_count want 0"
fi

set +e
"$aggregator" --since 7d --scope local \
    --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
dur_rc=$?
set -e
if [[ "$dur_rc" -eq 0 ]]; then
    pass "--since duration '7d' unaffected (exit 0)"
else
    faile "ADV-003 duration regression" "got $dur_rc want 0"
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
# ADV-006 (issue #10) — recursion filter is case-insensitive.
# Mixed-case skill_call values from non-canonical upstream emitters must be
# dropped just like the lowercase canonical form. Sibling skills that happen
# to be uppercase must NOT be dropped.
# ----------------------------------------------------------------------------

printf 'ADV-006: case-insensitive recursion filter\n'

case_proj="$(mktemp -d -t dfd-case.XXXXXX)"
mkdir -p "$case_proj/.claude/dogfood"
cat > "$case_proj/.claude/dogfood/log.jsonl" <<'CASE_FIXTURE'
{"ts":"2026-04-20T00:00:00Z","type":"skill_call","skill":"/CRUCIBLE:DOGFOOD-DIGEST","args_summary":"upper"}
{"ts":"2026-04-20T00:00:01Z","type":"skill_call","skill":"/Crucible:Dogfood-Digest","args_summary":"mixed"}
{"ts":"2026-04-20T00:00:02Z","type":"skill_call","skill":"/crucible:dogfood-digest","args_summary":"lower"}
{"ts":"2026-04-20T00:00:03Z","type":"skill_call","skill":"/CRUCIBLE:DOGFOOD-DIGEST-V2","args_summary":"sibling upper"}
{"ts":"2026-04-20T00:00:04Z","type":"note","category":"pain","text":"/crucible:plan some pain"}
CASE_FIXTURE

case_outfile="$case_proj/digest.md"
"$aggregator" --all --scope local --project-root "$case_proj" --home "$case_proj" \
    | "$renderer" --window "all" --scope local > "$case_outfile"

# 5 input → 3 case-variants of self dropped → 2 surviving (sibling + note).
case_total=$(grep -E '^total_events: ' "$case_outfile" | awk '{print $2}')
if [[ "$case_total" -eq 2 ]]; then
    pass "ADV-006 lowercase + UPPER + Mixed self-calls all dropped (total_events=$case_total)"
else
    faile "ADV-006 case-insensitive recursion" "got $case_total want 2"
fi

# Sibling upper-case variant must survive in the rendered report (frontmatter
# total reflects post-recursion-filter count, so 2 includes the sibling row).
# Aggregator preserves all 5 (recursion filter lives in renderer); after
# render, the v2 sibling event is still represented.
case_section_leak=$(grep -cE '\*\*/[Cc][Rr][Uu][Cc][Ii][Bb][Ll][Ee]:[Dd][Oo][Gg][Ff][Oo][Oo][Dd]-[Dd][Ii][Gg][Ee][Ss][Tt]\*\*' "$case_outfile" || true)
if [[ "$case_section_leak" -eq 0 ]]; then
    pass "ADV-006 no case-variant of self leaked into section keys"
else
    faile "ADV-006 case-variant leak" "$case_section_leak self-call section keys present"
fi
rm -rf "$case_proj"

# ----------------------------------------------------------------------------
# ADV-007 (issue #11) — pipefail propagates aggregator failure.
# Without `set -o pipefail`, a failing aggregator (jq sort error, mktemp
# error, bad-args exit 2, etc.) is masked by the renderer's exit 0 — the
# pipeline reports success while emitting an empty 3-section "no signal in
# window" report. With pipefail enabled, the failure must surface as a
# non-zero exit code from the pipeline as a whole.
# ----------------------------------------------------------------------------

printf 'ADV-007: pipefail surfaces aggregator failure\n'

# The outer test file enables `set -uo pipefail` AND `set -e` further down,
# so we must use the same `set +e ... set -e` bracket pattern other tests
# use to capture expected non-zero exits. We also toggle pipefail itself
# between arms — without that toggle, the parent's pipefail would already
# mask the issue-#11 failure mode in the "without" arm.
# Without pipefail: bad-args aggregator exits 2; renderer reads no input,
# emits empty 3-section report, exits 0; pipeline returns 0 — the
# "success but wrong answer" failure mode this guard exists to prevent.
set +e
set +o pipefail
( "$aggregator" --bogus-flag 2>/dev/null \
    | "$renderer" --window "all" --scope local >/dev/null 2>&1 )
no_pipefail_rc=$?

# With pipefail: aggregator exit 2 must propagate as the pipeline exit code.
set -o pipefail
( "$aggregator" --bogus-flag 2>/dev/null \
    | "$renderer" --window "all" --scope local >/dev/null 2>&1 )
pipefail_rc=$?
set -e

if [[ "$no_pipefail_rc" -eq 0 && "$pipefail_rc" -ne 0 ]]; then
    pass "pipefail surfaces aggregator failure (without=$no_pipefail_rc → with=$pipefail_rc)"
else
    faile "ADV-007 pipefail propagation" "without=$no_pipefail_rc with=$pipefail_rc (want without=0 with≠0)"
fi

# SKILL.md Phase 4 must document both pipefail AND wrapper-via-tempfile —
# pipefail alone is the social-contract minimum, the wrapper pattern is
# the agent-resilient invocation form (issue #11 chose option 1+3).
skill_md="$repo_root/skills/dogfood-digest/SKILL.md"
if grep -q 'set -o pipefail' "$skill_md" \
    && grep -qi 'wrapper-via-tempfile' "$skill_md"; then
    pass "SKILL.md Phase 4 documents pipefail + wrapper-via-tempfile invocation pattern"
else
    faile "ADV-007 SKILL.md docs" "missing 'set -o pipefail' and/or 'wrapper-via-tempfile' guidance"
fi

# The wrapper-via-tempfile example must also include `set -e` (or an
# equivalent rc check) — without it, aggregator exit ≠ 0 still leaves the
# next line's renderer running on an empty tempfile, writing a clean
# "no signal" report and returning 0. That is exactly the issue #11
# regression. pipefail alone is no-op in the wrapper form (no pipe).
if grep -A3 -i 'wrapper-via-tempfile' "$skill_md" | grep -q 'set -e'; then
    pass "SKILL.md wrapper-via-tempfile example includes set -e"
else
    faile "ADV-007 SKILL.md set -e" "wrapper-via-tempfile example missing 'set -e' — aggregator failure would silently produce empty digest"
fi

# Runtime check: the wrapper-via-tempfile pattern from SKILL.md must
# itself surface aggregator failure. Replays the documented example with
# a forced aggregator failure (--bogus-flag → exit 2) and asserts the
# wrapper exits non-zero AND no clean "no signal" digest is written.
# Without this assertion, ADV-007 only verified the pipefail path (which
# the SKILL.md example does not actually use).
wrap_proj="$(mktemp -d -t dfd-wrapper.XXXXXX)"
wrap_raw="$wrap_proj/raw"
wrap_out="$wrap_proj/out.md"

set +e
(
    set -e
    "$aggregator" --bogus-flag > "$wrap_raw" 2>/dev/null
    "$renderer" --window "all" --scope local < "$wrap_raw" > "$wrap_out"
)
wrap_rc=$?
set -e

if [[ "$wrap_rc" -ne 0 ]]; then
    pass "wrapper-via-tempfile + set -e surfaces aggregator failure (rc=$wrap_rc)"
else
    faile "ADV-007 wrapper rc" "wrapper returned 0 despite aggregator --bogus-flag failure (silent wrong-answer regression)"
fi

# The renderer must NOT have produced a "clean empty digest" report
# (issue #11 silent-success). Either no file or no markdown body.
if [[ ! -s "$wrap_out" ]]; then
    pass "wrapper-via-tempfile wrote no digest body after aggregator failure"
elif grep -q 'no signal in window' "$wrap_out"; then
    faile "ADV-007 wrapper output" "renderer wrote 'no signal' digest after aggregator failure (issue #11 regression)"
else
    pass "wrapper-via-tempfile produced no clean-empty-digest output"
fi
rm -rf "$wrap_proj"

# ----------------------------------------------------------------------------
# ADV-008 (issue #12) — malformed .score values are filtered before
# percentile computation. String-with-comma scores must NOT split into
# extra awk records; nested-object scores must NOT produce literal "{"/"}"
# garbage in p50/p95. Out-of-range numeric scores (e.g. -1, 2) also pass
# `type == "number"` but violate the [0,1] contract — they must be dropped
# before the percentile / verdict aggregation runs.
# ----------------------------------------------------------------------------

printf 'ADV-008: malformed .score filtering\n'

bad_proj="$(mktemp -d -t dfd-bad-score.XXXXXX)"
mkdir -p "$bad_proj/.claude/dogfood"
cat > "$bad_proj/.claude/dogfood/log.jsonl" <<'BAD_SCORE_FIXTURE'
{"ts":"2026-04-20T00:00:00Z","type":"qa_judge","skill":"/crucible:plan","score":0.5,"verdict":"retry"}
{"ts":"2026-04-20T00:00:01Z","type":"qa_judge","skill":"/crucible:plan","score":"0.5,0.7","verdict":"retry"}
{"ts":"2026-04-20T00:00:02Z","type":"qa_judge","skill":"/crucible:plan","score":{"nested":1},"verdict":"retry"}
{"ts":"2026-04-20T00:00:03Z","type":"qa_judge","skill":"/crucible:plan","score":0.7,"verdict":"promote"}
{"ts":"2026-04-20T00:00:04Z","type":"qa_judge","skill":"/crucible:plan","score":0.9,"verdict":"promote"}
{"ts":"2026-04-20T00:00:05Z","type":"qa_judge","skill":"/crucible:plan","score":-1,"verdict":"reject"}
{"ts":"2026-04-20T00:00:06Z","type":"qa_judge","skill":"/crucible:plan","score":2,"verdict":"promote"}
BAD_SCORE_FIXTURE

bad_outfile="$bad_proj/digest.md"
"$aggregator" --all --scope local --project-root "$bad_proj" --home "$bad_proj" \
    | "$renderer" --window "all" --scope local --threshold-n 3 > "$bad_outfile"

# n must equal 3 (only the three numeric-and-in-range events), not 5 or 7.
qa_line=$(grep 'qa_judge score distribution' "$bad_outfile" || true)
if printf '%s' "$qa_line" | grep -qE 'n=3 '; then
    pass "ADV-008 malformed-and-out-of-range score events filtered: n=3"
else
    faile "ADV-008 score filter count" "expected n=3, got: $qa_line"
fi

# Sorted in-range numeric scores: [0.5, 0.7, 0.9]. p50_idx=floor((3-1)/2)=1 → 0.7.
if printf '%s' "$qa_line" | grep -qE 'p50=0\.7\b'; then
    pass "ADV-008 p50=0.7 reflects only in-range numeric scores"
else
    faile "ADV-008 p50 value" "expected p50=0.7, got: $qa_line"
fi

# p95_idx=floor((3-1)*0.95+0.5)=floor(2.4)=2 → 0.9.
if printf '%s' "$qa_line" | grep -qE 'p95=0\.9\b'; then
    pass "ADV-008 p95=0.9 reflects only in-range numeric scores"
else
    faile "ADV-008 p95 value" "expected p95=0.9, got: $qa_line"
fi

# Most importantly: no literal "{" garbage from object-typed scores.
if grep -qE 'p50=\{|p95=\{' "$bad_outfile"; then
    faile "ADV-008 object-score garbage" "report contains literal '{' from object score"
else
    pass "ADV-008 no literal '{' garbage from object scores"
fi

# Out-of-range scores (-1, 2) must not appear in p50/p95 either.
if printf '%s' "$qa_line" | grep -qE 'p(50|95)=(-1|2)\b'; then
    faile "ADV-008 out-of-range leak" "report contains -1 or 2 in p50/p95: $qa_line"
else
    pass "ADV-008 out-of-range scores (-1, 2) excluded from percentiles"
fi

# Verdict counts must reflect the same in-range filter — the rejected
# `score=-1` and the bogus `score=2 verdict=promote` rows must NOT bump
# the verdict histogram. Expected: promote=2, retry=1, reject=0.
if printf '%s' "$qa_line" | grep -qE 'promote=2 · retry=1 · reject=0'; then
    pass "ADV-008 verdict histogram matches in-range filter (promote=2 retry=1 reject=0)"
else
    faile "ADV-008 verdict counts" "expected promote=2 retry=1 reject=0, got: $qa_line"
fi

# Recursion filter resilience (P2 hardening): non-string `.skill` must
# pass through ascii_downcase without aborting the entire render. Before
# this fix, `{"skill": 12, "type": "skill_call"}` crashed with "explode
# input must be a string" and dropped every event in the batch.
nonstr_proj="$(mktemp -d -t dfd-nonstr-skill.XXXXXX)"
mkdir -p "$nonstr_proj/.claude/dogfood"
cat > "$nonstr_proj/.claude/dogfood/log.jsonl" <<'NONSTR_FIXTURE'
{"ts":"2026-04-20T00:00:00Z","type":"note","category":"pain","text":"/crucible:plan ok"}
{"ts":"2026-04-20T00:00:01Z","type":"skill_call","skill":12,"args_summary":"numeric"}
{"ts":"2026-04-20T00:00:02Z","type":"skill_call","skill":{"obj":1},"args_summary":"object"}
{"ts":"2026-04-20T00:00:03Z","type":"skill_call","skill":null,"args_summary":"null"}
NONSTR_FIXTURE

nonstr_outfile="$nonstr_proj/digest.md"
"$aggregator" --all --scope local --project-root "$nonstr_proj" --home "$nonstr_proj" \
    | "$renderer" --window "all" --scope local > "$nonstr_outfile"
nonstr_total=$(grep -E '^total_events: ' "$nonstr_outfile" | awk '{print $2}')
# All 4 events must survive — none are self-calls, the malformed skill
# rows can't be self-call candidates, the note is the pain signal.
if [[ "$nonstr_total" -eq 4 ]]; then
    pass "ADV-008 non-string .skill rows pass through (total_events=4)"
else
    faile "ADV-008 non-string skill" "expected 4 events, got $nonstr_total — render likely aborted on malformed skill"
fi
rm -rf "$nonstr_proj"
rm -rf "$bad_proj"

# ----------------------------------------------------------------------------
# Issue #15 — aggregator/renderer flag-grouping cross-reference
# (cli-readiness cli-1 + agent-native F1)
# ----------------------------------------------------------------------------

printf 'ISSUE-15: aggregator rejects --threshold-n with renderer cross-ref hint\n'

# (a) aggregator must exit 2 on --threshold-n AND emit a stderr hint that
#     mentions dogfood-digest-render.sh so a naive agent can self-recover.
i15_stderr="$(mktemp -t dfd-i15-err.XXXXXX)"
i15_rc=0
"$aggregator" --threshold-n 5 --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>"$i15_stderr" || i15_rc=$?
if [[ "$i15_rc" -eq 2 ]]; then
    pass "aggregator exits 2 when --threshold-n is passed"
else
    faile "issue-15 exit code" "expected 2, got $i15_rc"
fi
# Anchor on the targeted-hint discriminator (`info: hint:` AND `render-time
# flag`) so deleting the case "$1" in --window|--threshold-n) block in
# scripts/dogfood-digest.sh actually breaks this assertion. The bare string
# "dogfood-digest-render.sh" was satisfied by the print_help cross-reference
# alone (see codex review on pr #21) — the assertion would have stayed green
# even with the targeted hint removed. Format updated to severity-prefix
# scheme (issue #16): `info: hint:` replaces the old `hint —` em-dash.
if grep -F -q -- 'info: hint:' "$i15_stderr" && grep -q 'is a render-time flag' "$i15_stderr"; then
    pass "aggregator stderr emits targeted misroute hint on --threshold-n"
else
    faile "issue-15 stderr hint" "expected 'info: hint:' and 'is a render-time flag' in stderr; got: $(tr '\n' '|' < "$i15_stderr")"
fi
# Hint must reference the renderer script by name so a naive agent can
# self-recover without re-reading the help text.
if grep -q 'dogfood-digest-render.sh' "$i15_stderr"; then
    pass "aggregator stderr hint names dogfood-digest-render.sh"
else
    faile "issue-15 hint script name" "expected 'dogfood-digest-render.sh' in stderr; got: $(tr '\n' '|' < "$i15_stderr")"
fi
rm -f "$i15_stderr"

# (b) aggregator --help must cross-reference renderer for render-time flags so
#     agents discover --threshold-n placement without reading source.
i15_help="$("$aggregator" --help 2>&1)"
if grep -qE 'render-time flags|dogfood-digest-render\.sh --help' <<<"$i15_help"; then
    pass "aggregator --help cross-references renderer for render-time flags"
else
    faile "issue-15 help cross-ref" "expected 'render-time flags' or 'dogfood-digest-render.sh --help' in --help output"
fi

# ----------------------------------------------------------------------------
# Issue #9 — duplicate single-flag rejection (aggregator + renderer)
# Without dedup, `--scope local --scope global` silently kept the LAST value,
# producing a digest whose frontmatter labelled it `scope: global` while the
# wrapper believed scope was local — wrong-context attribution downstream.
# ----------------------------------------------------------------------------

printf 'ISSUE-9: duplicate single-flag rejection\n'

# (a) aggregator: each named flag must be at-most-once.
for flag_pair in '--scope local --scope global' \
                 '--last 5 --last 10' \
                 '--all --all' \
                 '--project-root /tmp --project-root /var' \
                 '--home /tmp --home /var'; do
    set +e
    # shellcheck disable=SC2086
    err=$("$aggregator" $flag_pair --scope local 2>&1 >/dev/null)
    rc=$?
    set -e
    # The duplicate-flag branch must fire BEFORE any other validation can
    # mask it (e.g. --scope local + --scope global must reject as duplicate,
    # not as "valid scope" silently overwritten).
    case "$flag_pair" in
        --scope*) flag_name="--scope" ;;
        --last*)  flag_name="--last" ;;
        --all*)   flag_name="--all" ;;
        --project-root*) flag_name="--project-root" ;;
        --home*)  flag_name="--home" ;;
    esac
    # `grep -F --` so flag-named patterns like `--scope passed more than once`
    # are not interpreted as grep options (BSD grep on macOS rejects them).
    if [[ "$rc" -eq 2 ]] && printf '%s' "$err" | grep -F -q -- "${flag_name} passed more than once"; then
        pass "aggregator rejects duplicate $flag_name (exit 2 + named in stderr)"
    else
        faile "aggregator dup $flag_name" "rc=$rc stderr=$(tr '\n' '|' <<<"$err")"
    fi
done

# --since duplicate (separate because it'd otherwise trip mutex with --last default).
set +e
since_dup_err=$("$aggregator" --since 2099-01-01 --since 2099-02-02 --scope local 2>&1 >/dev/null)
since_dup_rc=$?
set -e
if [[ "$since_dup_rc" -eq 2 ]] && printf '%s' "$since_dup_err" | grep -F -q -- '--since passed more than once'; then
    pass "aggregator rejects duplicate --since (exit 2 + named in stderr)"
else
    faile "aggregator dup --since" "rc=$since_dup_rc stderr=$(tr '\n' '|' <<<"$since_dup_err")"
fi

# (b) renderer: same contract on its own flags.
for flag_pair in '--window a --window b' \
                 '--scope local --scope global' \
                 '--threshold-n 1 --threshold-n 99'; do
    set +e
    # shellcheck disable=SC2086
    err=$(echo '' | "$renderer" $flag_pair 2>&1 >/dev/null)
    rc=$?
    set -e
    case "$flag_pair" in
        --window*) flag_name="--window" ;;
        --scope*)  flag_name="--scope" ;;
        --threshold-n*) flag_name="--threshold-n" ;;
    esac
    if [[ "$rc" -eq 2 ]] && printf '%s' "$err" | grep -F -q -- "${flag_name} passed more than once"; then
        pass "renderer rejects duplicate $flag_name (exit 2 + named in stderr)"
    else
        faile "renderer dup $flag_name" "rc=$rc stderr=$(tr '\n' '|' <<<"$err")"
    fi
done

# Single occurrence still works — regression guard so the dedup logic does
# not accidentally treat the FIRST occurrence as "already seen".
ok_count=$("$aggregator" --last 5 --scope local --project-root "$tmpproj" --home "$tmphome" | wc -l | tr -d ' ')
if [[ "$ok_count" -eq 5 ]]; then
    pass "single occurrence still works (--last 5 returns 5)"
else
    faile "single-flag regression" "got $ok_count want 5"
fi

# Single-occurrence regression guard for the OTHER dedup'd flags. Without
# these, a regression flipping `reject_duplicate`'s saw-check (`-eq 0`
# instead of `-eq 1`) would only be caught on the --last path (PR #24
# ce-review testing gap).
set +e
single_scope_rc=$("$aggregator" --scope local --last 3 --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1; echo $?)
set -e
if [[ "$single_scope_rc" -eq 0 ]]; then
    pass "single occurrence --scope still accepted (no false-positive dedup)"
else
    faile "single --scope regression" "got rc=$single_scope_rc want 0"
fi
set +e
single_all_rc=$("$aggregator" --all --scope local --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1; echo $?)
set -e
if [[ "$single_all_rc" -eq 0 ]]; then
    pass "single occurrence --all still accepted"
else
    faile "single --all regression" "got rc=$single_all_rc want 0"
fi
set +e
single_since_rc=$("$aggregator" --since 7d --scope local --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1; echo $?)
set -e
if [[ "$single_since_rc" -eq 0 ]]; then
    pass "single occurrence --since still accepted"
else
    faile "single --since regression" "got rc=$single_since_rc want 0"
fi
# --project-root and --home are exercised by every test above (passed once);
# their single-use path is implicitly regression-guarded by the rest of the
# suite running green.

# Dedup must fire BEFORE other validations. If `--scope local --scope
# global` ALSO has a value-validation issue (e.g. paired with `--since
# garbage`), the dedup error must win — pinning ordering so a future
# refactor cannot silently move the dedup check after value validation
# (PR #24 ce-review testing gap).
set +e
order_err=$("$aggregator" --scope local --scope global --since invalid_value \
    --project-root "$tmpproj" --home "$tmphome" 2>&1 >/dev/null)
order_rc=$?
set -e
if [[ "$order_rc" -eq 2 ]] && printf '%s' "$order_err" | grep -F -q -- '--scope passed more than once'; then
    pass "dedup fires before value validation (--scope dup wins over --since invalid)"
else
    faile "dedup ordering" "rc=$order_rc stderr=$(tr '\n' '|' <<<"$order_err")"
fi

# --last as the final positional arg: `shift 2 || …` guard must fire with
# its own error message (not fall through to a confusing `unknown
# argument: <next-flag>` after consuming the wrong value). PR #24
# ce-review testing gap.
set +e
trailing_err=$("$aggregator" --scope local --last 2>&1 >/dev/null)
trailing_rc=$?
set -e
# `--last` with no value → the case body assigns "${2:-}" which is empty,
# `shift 2` fails on missing positional, the guard fires. Some shells
# instead let the empty-string flow through to validation. Either way, the
# script must exit 2 cleanly without a confusing unrelated error.
if [[ "$trailing_rc" -eq 2 ]]; then
    pass "--last as final arg exits 2 (shift guard or value validation)"
else
    faile "trailing --last" "got $trailing_rc want 2"
fi

# ----------------------------------------------------------------------------
# Issue #14 — extreme --last and tail-failure surfacing
# Two layers of defense: (1) parse-time cap rejects values bash arithmetic
# would overflow; (2) explicit tail-exit check surfaces any future runtime
# failure instead of silently emitting "no signal".
# ----------------------------------------------------------------------------

printf 'ISSUE-14: --last cap + tail exit surfacing\n'

# (a) Out-of-range overflow value must exit 2 with a clear range message
#     (previously: tail printed `illegal offset` to stderr but script still
#     exited 0 with empty stdout — "quiet week" indistinguishable from a
#     genuine no-signal run).
set +e
huge_err=$("$aggregator" --last 99999999999999999999 --scope local \
    --project-root "$tmpproj" --home "$tmphome" 2>&1 >/dev/null)
huge_rc=$?
set -e
if [[ "$huge_rc" -eq 2 ]]; then
    pass "--last 99999999999999999999 exits 2 (parse-time cap)"
else
    faile "ISSUE-14 overflow rc" "got $huge_rc want 2 — bash arithmetic likely silently failed"
fi
if printf '%s' "$huge_err" | grep -qE 'too large|≤ 1000000|<= 1000000'; then
    pass "--last overflow error names the cap (1000000)"
else
    faile "ISSUE-14 overflow message" "stderr did not name the 1000000 cap: $(tr '\n' '|' <<<"$huge_err")"
fi

# (b) Just-over-cap (1000001) must also exit 2.
set +e
"$aggregator" --last 1000001 --scope local --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
over_rc=$?
set -e
if [[ "$over_rc" -eq 2 ]]; then
    pass "--last 1000001 exits 2 (cap is exclusive of 1000001)"
else
    faile "ISSUE-14 cap+1" "got $over_rc want 2"
fi

# (c) At-cap (1000000) must succeed (boundary regression guard) AND return
#     the same number of events as --all (since fixture << 1M). Without the
#     line-count assertion, a regression silently capping output to a
#     smaller value (e.g. wrapping `tail` to a low constant) would still
#     pass (PR #24 ce-review testing gap).
set +e
at_cap_count=$("$aggregator" --last 1000000 --scope local --project-root "$tmpproj" --home "$tmphome" 2>/dev/null | wc -l | tr -d ' ')
at_cap_rc=$?
set -e
if [[ "$at_cap_rc" -eq 0 && "$at_cap_count" -eq "$fixture_lines" ]]; then
    pass "--last 1000000 succeeds and returns all $fixture_lines fixture rows"
else
    faile "ISSUE-14 at-cap" "rc=$at_cap_rc count=$at_cap_count want rc=0 count=$fixture_lines"
fi

# (d) Pipeline empty-output sanity: --last with extreme value must NOT produce
#     a "looks-like-success but empty stdout" pipeline. Confirms that the
#     parse-time cap fires BEFORE the renderer ever sees the empty stream.
set +e
set +o pipefail
huge_pipe_out=$( "$aggregator" --last 99999999999999999999 --scope local \
    --project-root "$tmpproj" --home "$tmphome" 2>/dev/null \
    | "$renderer" --window all --scope local 2>/dev/null )
set -o pipefail
set -e
# Renderer always emits a header even on empty stdin, so empty pipe is
# expected; the critical check is that the aggregator's exit 2 is not
# masked. We re-run with pipefail to verify pipe rc.
set +e
( "$aggregator" --last 99999999999999999999 --scope local \
    --project-root "$tmpproj" --home "$tmphome" 2>/dev/null \
    | "$renderer" --window all --scope local >/dev/null 2>&1 )
huge_pipe_rc=$?
set -e
if [[ "$huge_pipe_rc" -ne 0 ]]; then
    pass "extreme --last propagates non-zero exit through pipefail (rc=$huge_pipe_rc)"
else
    faile "ISSUE-14 pipe propagation" "rc=0 — aggregator failure was masked"
fi

# Silence shellcheck about huge_pipe_out — it exists only to demonstrate the
# pre-pipefail capture path; the assertion lives in huge_pipe_rc above.
: "$huge_pipe_out"

# (e) Pinning the post-arithmetic upper bound: a 7-digit value that PASSES the
#     length cap but EXCEEDS 1000000 must be rejected by the second guard.
#     Without this, the two-layer defense degrades silently to single-layer
#     when the length-bound check never fires (PR #24 review test gap).
set +e
"$aggregator" --last 9999999 --scope local --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
worst7_rc=$?
set -e
if [[ "$worst7_rc" -eq 2 ]]; then
    pass "--last 9999999 (7 digits, > cap) rejected by post-arithmetic guard (exit 2)"
else
    faile "ISSUE-14 7-digit overcap" "got $worst7_rc want 2 — second guard regressed"
fi

# (f) --last 0 (boundary at the bottom edge) must reject. The split
#     regex/length/post-arithmetic path now routes 0 through the post-
#     arithmetic `-le 0` branch, which the prior tests did not exercise.
set +e
"$aggregator" --last 0 --scope local --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
zero_rc=$?
set -e
if [[ "$zero_rc" -eq 2 ]]; then
    pass "--last 0 rejected (post-arithmetic -le 0 guard)"
else
    faile "ISSUE-14 --last 0" "got $zero_rc want 2"
fi

# (g) Unified error message: both the length-cap branch and the post-
#     arithmetic branch must emit the SAME template (PR #24 P3 #5). Two
#     templates force stderr scrapers to handle both. Anchor on the
#     `<= 1000000` constraint (ASCII for non-UTF-8 capture safety) so a
#     future divergence regresses to FAIL.
for input in 99999999999999999999 1000001; do
    set +e
    err=$("$aggregator" --last "$input" --scope local --project-root "$tmpproj" --home "$tmphome" 2>&1 >/dev/null)
    set -e
    if printf '%s' "$err" | grep -F -q -- '<= 1000000' && \
       ! printf '%s' "$err" | grep -F -q -- 'too large'; then
        pass "--last $input emits unified ASCII '<= 1000000' template (no 'too large' divergence)"
    else
        faile "ISSUE-14 unified message for --last $input" "stderr=$(tr '\n' '|' <<<"$err")"
    fi
done

# ----------------------------------------------------------------------------
# Issue #14 (mirror) — renderer --threshold-n is the same arithmetic-overflow
# surface as --last. PR #24 ce-review P1 #1 surfaced that the same
# `99999999999999999999` overflow path that produces a silent empty digest on
# the aggregator side ALSO produces a silent empty digest on the renderer
# side: every `[[ qa_count -ge threshold_n ]]` becomes false, all sections
# collapse to "no signal in window", exit 0. Mirror the cap + tests here so
# the issue stays closed across both halves of the pipeline.
# ----------------------------------------------------------------------------

printf 'ISSUE-14-MIRROR: --threshold-n cap on renderer\n'

# Overflow value rejected at parse time.
set +e
huge_tn_err=$(echo '' | "$renderer" --window t --scope local --threshold-n 99999999999999999999 2>&1 >/dev/null)
huge_tn_rc=$?
set -e
if [[ "$huge_tn_rc" -eq 2 ]]; then
    pass "--threshold-n 99999999999999999999 exits 2 (parse-time cap)"
else
    faile "ISSUE-14-MIRROR overflow rc" "got $huge_tn_rc want 2 — bash arithmetic likely silently failed"
fi
if printf '%s' "$huge_tn_err" | grep -F -q -- '<= 1000000'; then
    pass "--threshold-n overflow error names the cap (1000000)"
else
    faile "ISSUE-14-MIRROR overflow message" "stderr did not name the 1000000 cap: $(tr '\n' '|' <<<"$huge_tn_err")"
fi

# Just-over-cap (1000001) rejected.
set +e
echo '' | "$renderer" --window t --scope local --threshold-n 1000001 >/dev/null 2>&1
tn_over_rc=$?
set -e
if [[ "$tn_over_rc" -eq 2 ]]; then
    pass "--threshold-n 1000001 exits 2 (cap+1)"
else
    faile "ISSUE-14-MIRROR cap+1" "got $tn_over_rc want 2"
fi

# At-cap (1000000) accepted (boundary regression guard).
set +e
echo '' | "$renderer" --window t --scope local --threshold-n 1000000 >/dev/null 2>&1
tn_at_cap_rc=$?
set -e
if [[ "$tn_at_cap_rc" -eq 0 ]]; then
    pass "--threshold-n 1000000 succeeds (cap inclusive)"
else
    faile "ISSUE-14-MIRROR at-cap" "got $tn_at_cap_rc want 0"
fi

# 7-digit value > cap rejected by post-arithmetic guard.
set +e
echo '' | "$renderer" --window t --scope local --threshold-n 9999999 >/dev/null 2>&1
tn_worst7_rc=$?
set -e
if [[ "$tn_worst7_rc" -eq 2 ]]; then
    pass "--threshold-n 9999999 rejected by post-arithmetic guard"
else
    faile "ISSUE-14-MIRROR 7-digit overcap" "got $tn_worst7_rc want 2"
fi

# ----------------------------------------------------------------------------
# Help-text constraint exposure (PR #24 P2 #2 + #3) — agents that consult
# `--help` must discover the cap and at-most-once contract there too. Without
# these assertions, a future cleanup that strips the Constraints block from
# print_help passes silently.
# ----------------------------------------------------------------------------

printf 'HELP-CONSTRAINTS: --help mentions cap + at-most-once\n'

agg_help=$("$aggregator" --help 2>&1)
if printf '%s' "$agg_help" | grep -F -q -- '1000000'; then
    pass "aggregator --help mentions 1000000 cap"
else
    faile "agg --help cap" "no '1000000' in help output"
fi
if printf '%s' "$agg_help" | grep -F -q -- 'at most once'; then
    pass "aggregator --help mentions at-most-once contract"
else
    faile "agg --help dedup" "no 'at most once' in help output"
fi

ren_help=$("$renderer" --help 2>&1)
if printf '%s' "$ren_help" | grep -F -q -- '1000000'; then
    pass "renderer --help mentions 1000000 cap"
else
    faile "render --help cap" "no '1000000' in help output"
fi
if printf '%s' "$ren_help" | grep -F -q -- 'at most once'; then
    pass "renderer --help mentions at-most-once contract"
else
    faile "render --help dedup" "no 'at most once' in help output"
fi

# ----------------------------------------------------------------------------
# Issue #16 — exit-code split + uniform stderr severity tagging
# Arg errors stay at exit 2 (recoverable, retry with fixed args). System
# errors (mktemp on full /tmp, missing tools) move to exit 3 (escalate, do
# not retry). Every stderr line is prefixed `<script>: <severity>: <msg>`
# where severity ∈ {info, warn, error}. Without uniform tagging, agents
# cannot keyword-match severity without parsing free-form prose.
# ----------------------------------------------------------------------------

printf 'ISSUE-16: severity prefixes + arg/system exit-code split\n'

# (a) Every fatal stderr line carries `error:` severity.
for case in '--bogus-flag' '--last 0' '--last 99999999999999999999' \
            '--last 5 --since 7d' '--since 99999d' '--since 2099-01-01T00:00:00+09:00' \
            '--scope bogus'; do
    set +e
    # shellcheck disable=SC2086
    err_out=$("$aggregator" $case --project-root "$tmpproj" --home "$tmphome" 2>&1 >/dev/null)
    set -e
    if printf '%s' "$err_out" | grep -F -q -- 'dogfood-digest: error:'; then
        pass "agg fatal stderr ($case) carries 'error:' severity prefix"
    else
        faile "agg severity prefix on $case" "stderr=$(tr '\n' '|' <<<"$err_out")"
    fi
done

# Renderer fatal stderr also carries `error:` severity.
for case in '--bogus-flag' '--threshold-n 0' '--threshold-n 99999999999999999999' \
            '--scope bogus'; do
    set +e
    # shellcheck disable=SC2086
    err_out=$(echo '' | "$renderer" --window t $case 2>&1 >/dev/null)
    set -e
    if printf '%s' "$err_out" | grep -F -q -- 'render: error:'; then
        pass "render fatal stderr ($case) carries 'error:' severity prefix"
    else
        faile "render severity prefix on $case" "stderr=$(tr '\n' '|' <<<"$err_out")"
    fi
done

# (b) mktemp failure routes to exit 3 (system error) instead of exit 2
# (arg error). Force mktemp failure by pointing TMPDIR at a non-existent
# directory and using a fixture that produces enough output to require
# tempfile creation (otherwise zero-source path exits 0 before mktemp runs).
mkdir_proj="$(mktemp -d -t dfd-mktemp.XXXXXX)"
mkdir -p "$mkdir_proj/.claude/dogfood"
cp "$fixture" "$mkdir_proj/.claude/dogfood/log.jsonl"

set +e
mktemp_err=$(TMPDIR=/no/such/dir/ever "$aggregator" --all --scope local \
    --project-root "$mkdir_proj" --home "$tmphome" 2>&1 >/dev/null)
mktemp_rc=$?
set -e
# Some shells/mktemp implementations may still succeed if /tmp is reachable
# via a fallback. Accept exit 3 OR a clean run (rc=0) — but if it errors,
# it MUST be exit 3, never exit 2. The latter would mean a system error
# was misclassified as recoverable.
if [[ "$mktemp_rc" -eq 3 ]]; then
    pass "mktemp failure routes to exit 3 (system error)"
    if printf '%s' "$mktemp_err" | grep -F -q -- 'system error'; then
        pass "mktemp error message names 'system error' (escalation hint)"
    else
        faile "mktemp escalation hint" "stderr=$(tr '\n' '|' <<<"$mktemp_err")"
    fi
elif [[ "$mktemp_rc" -eq 2 ]]; then
    faile "mktemp exit-code class" "got rc=2 (arg error) — expected rc=3 (system error)"
else
    pass "mktemp succeeded via fallback (rc=$mktemp_rc) — system path not exercised on this env"
fi

# Renderer mktemp also routes to exit 3.
# CRITICAL: `TMPDIR=val cmd1 | cmd2` scopes TMPDIR to cmd1 only (bash
# pipeline env-var rule). Putting it before `echo` would set TMPDIR for
# echo, not the renderer, and the renderer would inherit the parent's
# TMPDIR — never exercising the exit-3 path. Set it on the renderer side.
set +e
echo '' | TMPDIR=/no/such/dir/ever "$renderer" --window t --scope local >/dev/null 2>&1
ren_mktemp_rc=$?
set -e
# Renderer always creates a tempfile, so this almost always exercises mktemp.
if [[ "$ren_mktemp_rc" -eq 3 ]]; then
    pass "render mktemp failure routes to exit 3"
elif [[ "$ren_mktemp_rc" -eq 2 ]]; then
    faile "render mktemp exit-code" "got rc=2 — expected rc=3 (system error)"
else
    pass "render mktemp succeeded via fallback (rc=$ren_mktemp_rc) — system path not exercised"
fi

rm -rf "$mkdir_proj"

# (c) Arg-error sites still emit exit 2 (regression guard). The split must
# only move mktemp; everything else stays at exit 2.
for case in '--bogus-flag' '--last 0' '--last 99999999999999999999' \
            '--scope bogus' '--last 5 --since 7d'; do
    set +e
    # shellcheck disable=SC2086
    "$aggregator" $case --project-root "$tmpproj" --home "$tmphome" >/dev/null 2>&1
    rc=$?
    set -e
    if [[ "$rc" -eq 2 ]]; then
        pass "arg error ($case) stays at exit 2"
    else
        faile "arg-vs-system split on $case" "got rc=$rc want 2"
    fi
done

# ----------------------------------------------------------------------------
# Issue #17 — per-row malformed-line warn rate-limit
# First 5 malformed rows per source emit verbatim `warn:` lines. Anything
# beyond that gets folded into a single `N more malformed rows skipped`
# summary line. Without the cap, a corrupted JSONL with thousands of bad
# rows blew downstream agent context budgets and trained agents to ignore
# stderr entirely.
# ----------------------------------------------------------------------------

printf 'ISSUE-17: warn rate-limit per source\n'

# Derive WARN_CAP from the aggregator script so a future cap change in
# scripts/dogfood-digest.sh doesn't silently break four hardcoded test
# assertions (was: literal `5` and derived `7` baked across the block).
WARN_CAP=$(grep -E '^readonly WARN_CAP=' "$aggregator" | head -1 | cut -d= -f2)
if ! [[ "$WARN_CAP" =~ ^[0-9]+$ ]] || [[ "$WARN_CAP" -lt 1 ]]; then
    faile "issue-17 setup" "WARN_CAP could not be derived from aggregator (got: $WARN_CAP)"
    WARN_CAP=5  # fallback so subsequent assertions still execute
fi

flood_proj="$(mktemp -d -t dfd-flood.XXXXXX)"
mkdir -p "$flood_proj/.claude/dogfood"
# Generate (WARN_CAP + 7) malformed rows + 2 valid rows. With cap=5 by
# default that's 12 bad / 2 valid; expect WARN_CAP verbatim warn lines
# + 1 summary line naming the fold count (7 when cap=5).
flood_bad_total=$((WARN_CAP + 7))
flood_fold_count=$((flood_bad_total - WARN_CAP))
{
    for i in $(seq 1 7); do
        echo "BAD_ROW_${i}_NOT_JSON"
    done
    echo '{"ts":"2026-04-25T00:00:00Z","type":"note","category":"pain","text":"valid"}'
    for i in $(seq 8 "$flood_bad_total"); do
        echo "BAD_ROW_${i}_NOT_JSON"
    done
    echo '{"ts":"2026-04-25T00:00:01Z","type":"note","category":"good","text":"valid"}'
} > "$flood_proj/.claude/dogfood/log.jsonl"

set +e
flood_stderr=$("$aggregator" --all --scope local --project-root "$flood_proj" \
    --home "$tmphome" 2>&1 >/dev/null)
set -e

verbatim_count=$(printf '%s\n' "$flood_stderr" | grep -c 'warn: skipping malformed row' || true)
summary_count=$(printf '%s\n' "$flood_stderr" | grep -c 'more malformed rows skipped' || true)

if [[ "$verbatim_count" -eq "$WARN_CAP" ]]; then
    pass "warn cap honoured: exactly $WARN_CAP verbatim 'warn: skipping' lines (got $verbatim_count)"
else
    faile "warn cap" "got $verbatim_count verbatim warn lines, want $WARN_CAP"
fi
if [[ "$summary_count" -eq 1 ]]; then
    pass "warn summary line emitted exactly once"
else
    faile "warn summary count" "got $summary_count summary lines, want 1"
fi
# (WARN_CAP + 7) bad rows total, WARN_CAP emitted verbatim → 7 folded.
if printf '%s' "$flood_stderr" | grep -F -q -- "$flood_fold_count more malformed rows skipped"; then
    pass "warn summary names the correct fold count ($flood_fold_count)"
else
    faile "warn summary count value" "expected '$flood_fold_count more malformed rows skipped', stderr=$(tr '\n' '|' <<<"$flood_stderr")"
fi
# Valid rows must still survive — the flood doesn't drop downstream data.
flood_count=$("$aggregator" --all --scope local --project-root "$flood_proj" \
    --home "$tmphome" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$flood_count" -eq 2 ]]; then
    pass "warn rate-limit doesn't drop valid rows (2 valid survive flood of 12 bad)"
else
    faile "flood survivorship" "got $flood_count valid rows want 2"
fi
rm -rf "$flood_proj"

# Below-cap case: (WARN_CAP - 2) bad rows emit (WARN_CAP - 2) verbatim
# warn lines and zero summary line. Pins the boundary so a future
# off-by-one regresses.
under_bad_total=$((WARN_CAP - 2))
if [[ "$under_bad_total" -lt 1 ]]; then
    under_bad_total=1  # cap < 3 makes the boundary degenerate; floor at 1
fi
under_proj="$(mktemp -d -t dfd-under.XXXXXX)"
mkdir -p "$under_proj/.claude/dogfood"
{
    for i in $(seq 1 "$under_bad_total"); do
        echo "BAD_${i}"
    done
    echo '{"ts":"2026-04-25T00:00:00Z","type":"note","category":"pain","text":"a"}'
} > "$under_proj/.claude/dogfood/log.jsonl"
set +e
under_stderr=$("$aggregator" --all --scope local --project-root "$under_proj" \
    --home "$tmphome" 2>&1 >/dev/null)
set -e
under_verbatim=$(printf '%s\n' "$under_stderr" | grep -c 'warn: skipping malformed row' || true)
under_summary=$(printf '%s\n' "$under_stderr" | grep -c 'more malformed rows skipped' || true)
if [[ "$under_verbatim" -eq "$under_bad_total" && "$under_summary" -eq 0 ]]; then
    pass "below-cap ($under_bad_total bad rows, cap=$WARN_CAP) emits $under_bad_total verbatim, 0 summary"
else
    faile "below-cap behavior" "verbatim=$under_verbatim summary=$under_summary want $under_bad_total/0"
fi
rm -rf "$under_proj"

# Singular-noun boundary: when fold count == 1, summary must read
# "1 more malformed row skipped" (singular "row"), not "1 more
# malformed rows skipped" (plural noun + singular subject mismatch).
# Construct (WARN_CAP + 1) bad rows so exactly 1 row is folded.
singular_bad_total=$((WARN_CAP + 1))
sing_proj="$(mktemp -d -t dfd-sing.XXXXXX)"
mkdir -p "$sing_proj/.claude/dogfood"
{
    for i in $(seq 1 "$singular_bad_total"); do
        echo "BAD_${i}"
    done
    echo '{"ts":"2026-04-25T00:00:00Z","type":"note","category":"pain","text":"a"}'
} > "$sing_proj/.claude/dogfood/log.jsonl"
set +e
sing_stderr=$("$aggregator" --all --scope local --project-root "$sing_proj" \
    --home "$tmphome" 2>&1 >/dev/null)
set -e
if printf '%s' "$sing_stderr" | grep -F -q -- '1 more malformed row skipped'; then
    pass "warn summary uses singular 'row' when fold count == 1"
elif printf '%s' "$sing_stderr" | grep -F -q -- '1 more malformed rows skipped'; then
    faile "warn summary plural-noun bug" "got '1 more malformed rows skipped' (plural noun + singular subject)"
else
    faile "warn summary singular case" "no '1 more malformed' line in: $(tr '\n' '|' <<<"$sing_stderr")"
fi
rm -rf "$sing_proj"

# ----------------------------------------------------------------------------
# Issue #18 — CRUCIBLE_DOGFOOD_QUIET_OVERRIDE suppresses env-override info
# CI runs that legitimately set CRUCIBLE_DOGFOOD_ROOT/HOME on every
# invocation can opt into silence so the info-line noise doesn't push
# agents toward "ignore stderr entirely" (masking the warn/error lines
# that DO matter).
# ----------------------------------------------------------------------------

printf 'ISSUE-18: CRUCIBLE_DOGFOOD_QUIET_OVERRIDE\n'

# Default behavior: env override produces a stderr info line.
default_stderr=$(CRUCIBLE_DOGFOOD_ROOT="$tmpproj" "$aggregator" --all --scope local \
    --project-root "/some/other/path" --home "$tmphome" 2>&1 >/dev/null)
if printf '%s' "$default_stderr" | grep -F -q -- 'info: CRUCIBLE_DOGFOOD_ROOT='; then
    pass "default: env-override info line emitted"
else
    faile "default info emit" "stderr=$(tr '\n' '|' <<<"$default_stderr")"
fi

# Opt-in: CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=1 suppresses the info line.
quiet_stderr=$(CRUCIBLE_DOGFOOD_ROOT="$tmpproj" CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=1 \
    "$aggregator" --all --scope local --project-root "/some/other/path" --home "$tmphome" 2>&1 >/dev/null)
if ! printf '%s' "$quiet_stderr" | grep -F -q -- 'CRUCIBLE_DOGFOOD_ROOT'; then
    pass "QUIET_OVERRIDE=1 suppresses env-override info line"
else
    faile "QUIET_OVERRIDE suppression" "stderr should be empty on info, got: $(tr '\n' '|' <<<"$quiet_stderr")"
fi

# QUIET_OVERRIDE must NOT suppress warn or error severity. A bad-flag
# invocation under QUIET_OVERRIDE=1 must still emit the error line —
# otherwise the opt-in would silently mask real failures.
quiet_err_stderr=$(CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=1 "$aggregator" --bogus-flag 2>&1 >/dev/null || true)
if printf '%s' "$quiet_err_stderr" | grep -F -q -- 'error: unknown argument'; then
    pass "QUIET_OVERRIDE=1 does NOT suppress error: severity (error still emitted)"
else
    faile "QUIET_OVERRIDE error scope" "stderr=$(tr '\n' '|' <<<"$quiet_err_stderr")"
fi

# QUIET_OVERRIDE=0 (explicit) behaves like default — info still emits.
explicit0_stderr=$(CRUCIBLE_DOGFOOD_ROOT="$tmpproj" CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=0 \
    "$aggregator" --all --scope local --project-root "/some/other/path" --home "$tmphome" 2>&1 >/dev/null)
if printf '%s' "$explicit0_stderr" | grep -F -q -- 'info: CRUCIBLE_DOGFOOD_ROOT='; then
    pass "QUIET_OVERRIDE=0 keeps default behavior (info emitted)"
else
    faile "QUIET_OVERRIDE=0" "stderr=$(tr '\n' '|' <<<"$explicit0_stderr")"
fi

# QUIET_OVERRIDE must apply symmetrically to the HOME branch, not just
# ROOT. Without this, a future refactor splitting the two guards could
# silently leak HOME info while ROOT stays suppressed.
home_default_stderr=$(CRUCIBLE_DOGFOOD_HOME="$tmphome" "$aggregator" --all \
    --scope local --project-root "$tmpproj" --home "/some/other/home" 2>&1 >/dev/null)
if printf '%s' "$home_default_stderr" | grep -F -q -- 'info: CRUCIBLE_DOGFOOD_HOME='; then
    pass "default: HOME env-override info line emitted"
else
    faile "default HOME info" "stderr=$(tr '\n' '|' <<<"$home_default_stderr")"
fi
home_quiet_stderr=$(CRUCIBLE_DOGFOOD_HOME="$tmphome" CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=1 \
    "$aggregator" --all --scope local --project-root "$tmpproj" --home "/some/other/home" 2>&1 >/dev/null)
if ! printf '%s' "$home_quiet_stderr" | grep -F -q -- 'CRUCIBLE_DOGFOOD_HOME'; then
    pass "QUIET_OVERRIDE=1 suppresses HOME env-override info line (symmetric with ROOT)"
else
    faile "QUIET_OVERRIDE HOME suppression" "stderr should be empty on info, got: $(tr '\n' '|' <<<"$home_quiet_stderr")"
fi

# QUIET_OVERRIDE=1 must NOT suppress warn: severity. The PR contract
# states 'warn: and error: always emit'. Only the error: passthrough was
# previously verified — add a malformed-row source under QUIET_OVERRIDE=1
# and assert the warn: line still surfaces. A future refactor widening
# the QUIET guard to also wrap warn() would land green without this.
warn_quiet_proj="$(mktemp -d -t dfd-warnq.XXXXXX)"
mkdir -p "$warn_quiet_proj/.claude/dogfood"
{
    echo 'BAD_ROW_NOT_JSON'
    echo '{"ts":"2026-04-25T00:00:00Z","type":"note","category":"pain","text":"valid"}'
} > "$warn_quiet_proj/.claude/dogfood/log.jsonl"
warn_quiet_stderr=$(CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=1 "$aggregator" --all \
    --scope local --project-root "$warn_quiet_proj" --home "$tmphome" 2>&1 >/dev/null)
if printf '%s' "$warn_quiet_stderr" | grep -F -q -- 'warn: skipping malformed row'; then
    pass "QUIET_OVERRIDE=1 does NOT suppress warn: severity (warn still emitted)"
else
    faile "QUIET_OVERRIDE warn scope" "expected 'warn: skipping malformed row', stderr=$(tr '\n' '|' <<<"$warn_quiet_stderr")"
fi
rm -rf "$warn_quiet_proj"

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

if [[ "$fail" -eq 0 ]]; then
    printf '\ntest-dogfood-digest: ALL PASS (SC-1~7 + recursion filter + ADV-003/006/007/008 + issue-9/14/15/16/17/18 + 14-mirror + help-constraints)\n'
    exit 0
else
    printf '\ntest-dogfood-digest: FAIL\n'
    printf '%b' "$details"
    exit 1
fi

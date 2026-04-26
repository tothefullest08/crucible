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
if grep -q 'dogfood-digest-render.sh' "$i15_stderr"; then
    pass "aggregator stderr hints at dogfood-digest-render.sh on --threshold-n"
else
    faile "issue-15 stderr hint" "expected 'dogfood-digest-render.sh' in stderr; got: $(tr '\n' '|' < "$i15_stderr")"
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
# Summary
# ----------------------------------------------------------------------------

if [[ "$fail" -eq 0 ]]; then
    printf '\ntest-dogfood-digest: ALL PASS (SC-1~7 + recursion filter + ADV-006/007/008 + issue-15)\n'
    exit 0
else
    printf '\ntest-dogfood-digest: FAIL\n'
    printf '%b' "$details"
    exit 1
fi

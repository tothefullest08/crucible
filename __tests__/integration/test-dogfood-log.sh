#!/usr/bin/env bash
# __tests__/integration/test-dogfood-log.sh — SC-1 ~ SC-5 coverage for
# the /crucible:dogfood dogfooding skill.
#
# SC-1: single call writes ≤ 2s on a fixture (≤ 30s budget).
# SC-2: all four structured event types present in fixture are extracted.
# SC-3: local + global mirror JSONL both parse line-by-line with `jq .`.
# SC-4: .gitignore gains ".claude/dogfood/" exactly once (idempotent).
# SC-5: second invocation does NOT include /crucible:dogfood tool_use events.
#
# Exit 0 = all sub-tests PASS. Exit 1 = at least one failure.
#
# Isolation: every sub-test runs inside a fresh mktemp-d project so the real
# repo is untouched. CRUCIBLE_DOGFOOD_ROOT/HOME env vars redirect the writer.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root" || exit 1

fixture="$repo_root/__tests__/fixtures/dogfood-session.jsonl"
parser="$repo_root/scripts/parse-current-session.sh"
writer="$repo_root/scripts/dogfood-write.sh"
slug_hash="$repo_root/scripts/project-slug-hash.sh"

for f in "$fixture" "$parser" "$writer" "$slug_hash"; do
    if [[ ! -e "$f" ]]; then
        printf 'FAIL: missing prerequisite: %s\n' "$f" >&2
        exit 1
    fi
done

fail=0
details=""

assert_pass() {
    local label="$1"
    printf '  ✓ %s\n' "$label"
}

assert_fail() {
    local label="$1" extra="${2:-}"
    fail=1
    details+="  ✗ ${label}${extra:+ — $extra}\n"
    printf '  ✗ %s %s\n' "$label" "$extra"
}

# ----------------------------------------------------------------------------
# SC-2 — structured event coverage on the canonical fixture
# ----------------------------------------------------------------------------

printf 'SC-2: structured event coverage\n'

events_output="$("$parser" "$fixture")"
count_skill_call=$(printf '%s\n' "$events_output" | jq -c 'select(.type=="skill_call")' | wc -l | tr -d ' ')
count_promo=$(printf '%s\n' "$events_output" | jq -c 'select(.type=="promotion_gate")' | wc -l | tr -d ' ')
count_skip=$(printf '%s\n' "$events_output" | jq -c 'select(.type=="axis_skip")' | wc -l | tr -d ' ')
count_qa=$(printf '%s\n' "$events_output" | jq -c 'select(.type=="qa_judge")' | wc -l | tr -d ' ')

if [[ "$count_skill_call" -ge 1 ]]; then assert_pass "skill_call count = $count_skill_call"; else assert_fail "SC-2 skill_call" "got $count_skill_call, want >= 1"; fi
if [[ "$count_promo" -ge 1 ]]; then assert_pass "promotion_gate count = $count_promo"; else assert_fail "SC-2 promotion_gate" "got $count_promo, want >= 1"; fi
if [[ "$count_skip" -ge 1 ]]; then assert_pass "axis_skip count = $count_skip"; else assert_fail "SC-2 axis_skip" "got $count_skip, want >= 1"; fi
if [[ "$count_qa" -ge 1 ]]; then assert_pass "qa_judge count = $count_qa"; else assert_fail "SC-2 qa_judge" "got $count_qa, want >= 1"; fi

# ----------------------------------------------------------------------------
# SC-1, SC-3, SC-4 — timing, JSONL validity, gitignore idempotency
# ----------------------------------------------------------------------------

printf 'SC-1/3/4: write path (local + global mirror + gitignore)\n'

tmpproj="$(mktemp -d -t dogfood-sc1.XXXXXX)"
tmphome="$(mktemp -d -t dogfood-home.XXXXXX)"
trap 'rm -rf "$tmpproj" "$tmphome"' EXIT

export CRUCIBLE_DOGFOOD_ROOT="$tmpproj"
export CRUCIBLE_DOGFOOD_HOME="$tmphome"
unset CRUCIBLE_DOGFOOD_GLOBAL  # default opt-in

start=$(date +%s)
{
    printf '%s\n' "$events_output"
    printf '{"ts":"2026-04-22T10:05:00Z","type":"note","category":"good","text":"dogfood test"}\n'
} | "$writer" >/dev/null
end=$(date +%s)
elapsed=$((end - start))

if [[ "$elapsed" -le 30 ]]; then assert_pass "SC-1 elapsed = ${elapsed}s (<=30s)"; else assert_fail "SC-1 timing" "elapsed=${elapsed}s"; fi

local_log="$tmpproj/.claude/dogfood/log.jsonl"
if [[ -f "$local_log" ]]; then
    if jq -e . "$local_log" >/dev/null 2>&1; then
        assert_pass "SC-3 local JSONL parses"
    else
        # jq -e on concatenated JSONL may fail on multi-line; check line-by-line
        invalid=0
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            printf '%s\n' "$line" | jq -e . >/dev/null 2>&1 || invalid=$((invalid + 1))
        done < "$local_log"
        if [[ "$invalid" -eq 0 ]]; then
            assert_pass "SC-3 local JSONL parses (line-by-line)"
        else
            assert_fail "SC-3 local JSONL" "$invalid invalid lines"
        fi
    fi
else
    assert_fail "SC-3 local JSONL" "file missing: $local_log"
fi

slug_hash_val="$("$slug_hash" "$tmpproj")"
global_log="$tmphome/.claude/dogfood/crucible/${slug_hash_val}/log.jsonl"

if [[ -f "$global_log" ]]; then
    invalid=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf '%s\n' "$line" | jq -e . >/dev/null 2>&1 || invalid=$((invalid + 1))
    done < "$global_log"
    if [[ "$invalid" -eq 0 ]]; then
        assert_pass "SC-3 global JSONL parses"
    else
        assert_fail "SC-3 global JSONL" "$invalid invalid lines"
    fi
else
    assert_fail "SC-3 global mirror" "file missing: $global_log"
fi

gitignore="$tmpproj/.gitignore"
if [[ -f "$gitignore" ]]; then
    gi_count=$(grep -cxF '.claude/dogfood/' "$gitignore" || true)
    if [[ "$gi_count" -eq 1 ]]; then assert_pass "SC-4 gitignore entry exactly once"; else assert_fail "SC-4 gitignore" "found $gi_count occurrences"; fi
else
    assert_fail "SC-4 gitignore" ".gitignore not created"
fi

# Second call: gitignore must remain idempotent.
printf '{"ts":"2026-04-22T10:06:00Z","type":"note","category":"pain","text":"second call"}\n' \
    | "$writer" >/dev/null

gi_count=$(grep -cxF '.claude/dogfood/' "$gitignore" || true)
if [[ "$gi_count" -eq 1 ]]; then assert_pass "SC-4 gitignore idempotent on second call"; else assert_fail "SC-4 gitignore idempotency" "count=$gi_count"; fi

# ----------------------------------------------------------------------------
# SC-5 — recursion filter: /crucible:dogfood invocations are dropped
# ----------------------------------------------------------------------------

printf 'SC-5: recursion filter\n'

recursion_fixture="$(mktemp -t dogfood-recursion.XXXXXX)"
cat > "$recursion_fixture" << 'EOF'
{"type":"user","timestamp":"2026-04-22T11:00:00Z","message":{"content":"/crucible:dogfood"}}
{"type":"assistant","timestamp":"2026-04-22T11:00:05Z","message":{"content":[{"type":"tool_use","id":"r1","name":"Skill","input":{"skill":"crucible:dogfood","args":""}}]}}
{"type":"user","timestamp":"2026-04-22T11:05:00Z","message":{"content":"/crucible:dogfood"}}
{"type":"user","timestamp":"2026-04-22T11:05:05Z","message":{"content":"/crucible:plan"}}
EOF

recursion_out="$("$parser" "$recursion_fixture")"
log_count=$(printf '%s\n' "$recursion_out" | jq -c 'select(.type=="skill_call" and (.skill | contains("crucible:dogfood")))' | wc -l | tr -d ' ')
plan_count=$(printf '%s\n' "$recursion_out" | jq -c 'select(.type=="skill_call" and .skill=="/crucible:plan")' | wc -l | tr -d ' ')

if [[ "$log_count" -eq 0 ]]; then assert_pass "SC-5 /crucible:dogfood events dropped (count=0)"; else assert_fail "SC-5 recursion" "leaked $log_count /crucible:dogfood entries"; fi
if [[ "$plan_count" -eq 1 ]]; then assert_pass "SC-5 non-log events preserved (/crucible:plan count=1)"; else assert_fail "SC-5 preservation" "plan count=$plan_count"; fi

rm -f "$recursion_fixture"

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

if [[ "$fail" -eq 0 ]]; then
    printf '\ntest-dogfood-log: ALL PASS (SC-1~5)\n'
    exit 0
else
    printf '\ntest-dogfood-log: FAIL\n'
    printf '%b' "$details"
    exit 1
fi

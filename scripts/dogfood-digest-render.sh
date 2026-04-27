#!/usr/bin/env bash
# dogfood-digest-render.sh — render filtered dogfood JSONL (from dogfood-digest.sh)
# into a 3-section Markdown proposal report.
#
# Sections (fixed order, always present):
#   1. Threshold Calibration — qa_judge score distribution + axis_skip frequency.
#   2. Protocol Improvements — pain/ambiguous notes + recurring axis_skip reasons.
#   3. Promotion Candidates  — request/good notes + promotion_gate y-responses.
#
# Empty section → literal "> no signal in window" line per requirements SC-5.
#
# Each suggestion line includes a back-reference `\`path:line\`` (at least one).
#
# Recursion filter: drops skill_call events where skill references
# /crucible:dogfood-digest itself (dogfood skill also filters /crucible:dogfood).
#
# Input : JSONL on stdin (each line has _source_path, _line, ts, type, …).
# Args  :
#   --window <LABEL>     window label used in frontmatter + filename (required)
#   --scope  <SCOPE>     local | global | both — written to frontmatter
#                        (default: both); validated to mirror the aggregator
#   --threshold-n <N>    minimum observation count for threshold suggestions
#                        (default: 3; lower values mean quieter logs still emit)
#   -h | --help          print usage
# Output: Markdown on stdout.
#
# Each named flag may appear at most once; passing the same flag twice exits 2
# (issue #9). Without this check, a wrapper concatenating user flags with its
# own defaults would silently see "last value wins" — e.g.
# `--threshold-n 1 --threshold-n 99` would suppress signal a caller intended
# to surface.
#
# Stderr: every line carries `render: <severity>: <message>` where severity ∈
# {info, warn, error} (issue #16). Symmetric with the aggregator so a wrapper
# can keyword-match severity across both halves of the pipeline uniformly.
#
# Exit codes (issue #16 — arg vs system split):
#   0  success (including empty or no-signal input)
#   1  runtime data-pipeline failure (jq ingestion error)
#   2  argument error (unknown flag, duplicate flag, bad value)
#   3  system / environment failure (mktemp full disk, missing tools)
#
# Runtime: bash + jq. No Python / Node.

set -uo pipefail

# Severity-tagged stderr emitters (issue #16). Mirrors the aggregator's
# helpers so both halves of the pipeline emit `<script>: <severity>: <msg>`
# uniformly.
# shellcheck disable=SC2059  # fmt is an internal format string, not user input
err() { local fmt="$1"; shift; printf "render: error: ${fmt}\\n" "$@" >&2; }
# shellcheck disable=SC2059
warn() { local fmt="$1"; shift; printf "render: warn: ${fmt}\\n" "$@" >&2; }
# shellcheck disable=SC2059
info() { local fmt="$1"; shift; printf "render: info: ${fmt}\\n" "$@" >&2; }

print_help() {
    cat <<'USAGE'
Usage: dogfood-digest-render.sh --window LABEL [--scope SCOPE] [--threshold-n N]

Reads filtered dogfood JSONL on stdin and emits a 3-section Markdown proposal
report on stdout.

Flags:
  --window LABEL      window label used in frontmatter + filename (required)
  --scope SCOPE       local | global | both (default both); validated, mirrors
                      the aggregator's contract so the YAML frontmatter cannot
                      carry an out-of-domain label
  --threshold-n N     positive integer in [1, 1000000]; minimum observation
                      count for threshold suggestions (default: 3; lower values
                      mean quieter logs still emit)
  -h | --help         print usage

Constraints:
  --threshold-n is a positive integer in [1, 1000000]; out-of-range → exit 2.
  Each named flag may appear at most once (duplicate → exit 2).

Stderr severity tagging:
  Every stderr line below the targeted error/warn/info helpers is prefixed
  `render: <severity>: <msg>` where severity ∈ {info, warn, error}
  (matches the aggregator's contract). Aggregator prefix is
  `dogfood-digest: <severity>:` — for unified pipeline grep:
      grep -E '^(dogfood-digest|render): (info|warn|error):'

Exit codes (arg / runtime / system split, see issue #16):
  0  success (including empty or no-signal input)
  1  runtime data-pipeline failure (jq ingestion error)
  2  argument error — fix the flag and retry
  3  system/environment failure (mktemp full disk, missing tools) —
     escalate, do not retry the same args
USAGE
}

window_label=""
scope_label="both"
threshold_n=3

# Track per-flag occurrence so `--threshold-n 1 --threshold-n 99` no longer
# silently overwrites the first value (issue #9). Mirrors the aggregator's
# dedup contract so wrappers see the same shape on both halves of a pipeline.
saw_window=0
saw_scope=0
saw_threshold_n=0

reject_duplicate() {
    err '%s passed more than once — pass it at most once' "$1"
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --window)
            # `if [[ ]]; then …; fi` (not `[[ ]] && …`) so a future `set -e`
            # cannot abort on the first occurrence (residual risk from PR
            # #24 ce-review). Mirrors the aggregator's dedup pattern.
            if [[ "$saw_window" -eq 1 ]]; then reject_duplicate --window; fi
            saw_window=1
            window_label="${2:-}"
            shift 2 || { err '--window requires a value'; exit 2; }
            ;;
        --scope)
            if [[ "$saw_scope" -eq 1 ]]; then reject_duplicate --scope; fi
            saw_scope=1
            scope_label="${2:-}"
            shift 2 || { err '--scope requires a value'; exit 2; }
            ;;
        --threshold-n)
            if [[ "$saw_threshold_n" -eq 1 ]]; then reject_duplicate --threshold-n; fi
            saw_threshold_n=1
            threshold_n="${2:-}"
            shift 2 || { err '--threshold-n requires a value'; exit 2; }
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            err 'unknown argument: %s' "$1"
            # Drop the unprefixed `print_help >&2` dump (~30 lines) — it
            # bypassed the err/warn/info helpers and broke the
            # `^render:` anchored-grep contract that issue #16 enabled.
            # Mirror the aggregator: one actionable info line pointing
            # at --help.
            info 'for full usage: bash scripts/dogfood-digest-render.sh --help'
            exit 2
            ;;
    esac
done

# Best-effort cleanup of stale orphans from prior SIGKILL/OOM-kill runs.
# Placed right after argument parsing — *before* --window/--scope/--threshold-n
# validation — so the prune still fires on arg-error retries that follow a
# SIGKILL'd run (the very paths that leak tempfiles in the first place). The
# EXIT/INT/TERM/HUP trap below handles graceful exits, but SIGKILL is
# untrappable by design — every kill -9 leaks a dogfood-digest-in.XXXXXX of
# size O(JSONL bytes) into $TMPDIR. 60-minute window is far longer than any
# real render run; stderr suppression + `|| true` keep the prune best-effort
# so any pruning failure never blocks a legitimate run.
find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'dogfood-digest-in.*' -mmin +60 -delete 2>/dev/null || true

if [[ -z "$window_label" ]]; then
    err '--window is required'
    exit 2
fi

# Mirror the aggregator's --scope validation so the renderer cannot silently
# write a garbage `scope:` label into the report frontmatter (cli-readiness #2).
case "$scope_label" in
    local|global|both) ;;
    *)
        err '--scope must be local, global, or both (got: %s)' "$scope_label"
        exit 2
        ;;
esac

if ! [[ "$threshold_n" =~ ^[0-9]+$ ]]; then
    err '--threshold-n expects a positive integer (got: %s)' "$threshold_n"
    exit 2
fi
# Length-bound BEFORE arithmetic, mirroring the aggregator's --last guard
# (issue #14 hardening). Without this, --threshold-n 99999999999999999999
# overflows bash's signed-64-bit `[[ -le 0 ]]` compare and the value flows
# into every `[[ qa_count -ge threshold_n ]]` test as a number too large for
# any real signal — every section collapses to "no signal in window" with
# exit 0, exactly the silent-empty-report failure issue #14 was meant to
# close, just on a sibling flag. Cap is 1_000_000 (7 digits) to match the
# aggregator's --last contract; both are observation-count knobs.
if [[ ${#threshold_n} -gt 7 ]]; then
    err '--threshold-n must be a positive integer <= 1000000 (got: %s)' "$threshold_n"
    exit 2
fi
threshold_n=$((10#$threshold_n))
if [[ "$threshold_n" -le 0 ]] || [[ "$threshold_n" -gt 1000000 ]]; then
    err '--threshold-n must be a positive integer <= 1000000 (got: %s)' "$threshold_n"
    exit 2
fi

# mktemp failure is a system / environment issue (issue #16) — exit 3 lets
# retry-loop wrappers distinguish "fix the flag" (2) from "escalate" (3).
tmp_in="$(mktemp -t dogfood-digest-in.XXXXXX)" || {
    err 'mktemp failed (system error — escalate, do not retry)'
    exit 3
}
# EXIT covers normal exit; INT/TERM/HUP cover SIGINT/SIGTERM/SIGHUP so the
# tempfile does not leak when the renderer is interrupted mid-pipeline.
trap 'rm -f "$tmp_in"' EXIT INT TERM HUP

# Read stdin, drop blanks, filter recursion events at ingestion.
# Regex is anchored so sibling skills like `/crucible:dogfood-digest-v2` are NOT dropped.
# Case-insensitive: upstream wrappers / non-canonical emitters may carry mixed
# case (`/CRUCIBLE:DOGFOOD-DIGEST`). ascii_downcase normalises before the test
# AND the `i` flag is kept as belt-and-braces — either alone is sufficient,
# both together survive even if one side regresses.
# Non-string `.skill` values (number, object, null) cannot be self-call
# candidates and would crash `ascii_downcase` ("explode input must be a
# string"), killing the entire render for the batch. Pass them through so
# one malformed row does not poison all downstream sections — schema drift
# tolerance over recursion-filter strictness.
# A jq failure here would silently truncate $tmp_in and every downstream
# count would degrade to "no signal in window" with exit 0 — a "success
# but wrong answer" failure mode. Surface jq errors instead of swallowing.
if ! jq -c 'select(if .type == "skill_call" then (if (.skill | type) == "string" then ((.skill | ascii_downcase) | test("^/?crucible:dogfood-digest$"; "i") | not) else true end) else true end)' > "$tmp_in"; then
    err 'ingestion jq failed (malformed JSONL on stdin?)'
    exit 1
fi

total_events=$(wc -l < "$tmp_in" | tr -d ' ')

# ----- per-type aggregates ---------------------------------------------------

# qa_judge: score list + verdict histogram.
# Filter to events where .score is numeric AND inside the [0,1] contract —
# non-numeric scores poison percentile statistics (string-with-comma splits
# awk records; nested objects render as literal "{}" in the report), and
# out-of-range numbers (e.g. -1, 2) silently corrupt p50/p95 even though
# they pass `type == "number"`. The score contract is [0,1]; any other
# value is schema drift and dropped at ingestion. Dropping the entire row
# when score is malformed is the conservative call: a future skill that
# logs score as object/string would otherwise corrupt every digest forever
# (issue #12). Verdict counts and references therefore reflect well-formed
# in-range events only.
qa_json="$(jq -sc '[.[] | select(.type=="qa_judge" and (.score | type == "number") and .score >= 0 and .score <= 1)]' "$tmp_in")"
qa_count=$(printf '%s' "$qa_json" | jq 'length')

# axis_skip: axis histogram (only "acknowledged" true)
skip_json="$(jq -sc '[.[] | select(.type=="axis_skip")]' "$tmp_in")"
skip_count=$(printf '%s' "$skip_json" | jq 'length')

# notes (pain + ambiguous) — Protocol
pain_json="$(jq -sc '[.[] | select(.type=="note" and (.category=="pain" or .category=="ambiguous"))]' "$tmp_in")"
pain_count=$(printf '%s' "$pain_json" | jq 'length')

# notes (request + good) — Promotion
promo_notes_json="$(jq -sc '[.[] | select(.type=="note" and (.category=="request" or .category=="good"))]' "$tmp_in")"
promo_notes_count=$(printf '%s' "$promo_notes_json" | jq 'length')

# promotion_gate y-responses — Promotion (response may be "y" or similar)
gate_json="$(jq -sc '[.[] | select(.type=="promotion_gate" and (.response // "") == "y")]' "$tmp_in")"
gate_count=$(printf '%s' "$gate_json" | jq 'length')

# source path counts for frontmatter
source_counts_json="$(jq -sc '[.[]._source_path] | group_by(.) | map({(.[0]): length}) | add // {}' "$tmp_in")"

# ----- frontmatter -----------------------------------------------------------

today="$(date -u +%Y-%m-%d)"

printf -- '---\n'
printf 'generated_at: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'window: "%s"\n' "$window_label"
printf 'scope: "%s"\n' "$scope_label"
printf 'total_events: %s\n' "$total_events"
printf 'source_counts: %s\n' "$source_counts_json"
printf 'date: "%s"\n' "$today"
printf -- '---\n\n'

printf '# Dogfood Digest — %s (%s)\n\n' "$window_label" "$scope_label"
printf '> read-only proposal report generated by `/crucible:dogfood-digest`. this file is the only write.\n'
printf '> input: %s events from %s source(s).\n\n' "$total_events" "$(printf '%s' "$source_counts_json" | jq 'length')"

# ----- Section 1: Threshold Calibration --------------------------------------

printf '## Threshold Calibration\n\n'

if [[ "$qa_count" -lt "$threshold_n" && "$skip_count" -lt "$threshold_n" ]]; then
    printf '> no signal in window (qa_judge n=%s, axis_skip n=%s, threshold-n=%s)\n\n' \
        "$qa_count" "$skip_count" "$threshold_n"
else
    if [[ "$qa_count" -ge "$threshold_n" ]]; then
        # verdict histogram
        promote_n=$(printf '%s' "$qa_json" | jq '[.[] | select(.verdict=="promote")] | length')
        retry_n=$(printf '%s' "$qa_json" | jq '[.[] | select(.verdict=="retry")] | length')
        reject_n=$(printf '%s' "$qa_json" | jq '[.[] | select(.verdict=="reject")] | length')
        # Percentiles computed inside jq — stay in numeric domain instead of
        # round-tripping through awk's stringly-typed split on commas (which
        # is what poisoned p50/p95 when .score carried a "0.5,0.7" string in
        # issue #12). Index math mirrors the prior awk: p50 = floor((n-1)/2),
        # p95 = floor((n-1)*0.95 + 0.5), clamped to the last index.
        p50=$(printf '%s' "$qa_json" | jq -r '
            if length == 0 then "n/a"
            else ([.[].score] | sort) as $s
                | ($s | length) as $n
                | $s[(($n - 1) / 2) | floor]
            end
        ')
        p95=$(printf '%s' "$qa_json" | jq -r '
            if length == 0 then "n/a"
            else ([.[].score] | sort) as $s
                | ($s | length) as $n
                | ((($n - 1) * 0.95 + 0.5) | floor) as $i
                | $s[if $i >= $n then $n - 1 else $i end]
            end
        ')
        refs=$(printf '%s' "$qa_json" | jq -r '.[] | "\(._source_path):\(._line)"' | head -3 | awk '{printf "`%s` ", $0}')
        printf -- '- **qa_judge score distribution** — n=%s · p50=%s · p95=%s · verdicts: promote=%s · retry=%s · reject=%s — 근거(샘플 3건): %s\n' \
            "$qa_count" "$p50" "$p95" "$promote_n" "$retry_n" "$reject_n" "$refs"
        printf '  - 권고: 현행 임계값(promote ≥0.80 · reject ≤0.40) 재검토. p50 < 0.80 이면 해당 스킬의 평가 원칙 weight 재배분; retry 비율 > 40%% 이면 Ralph Loop 예산 (기본 3) 조정 검토.\n'
    else
        printf -- '- qa_judge 관측수 부족 (n=%s < %s) — 임계값 재조정 판단 보류.\n' "$qa_count" "$threshold_n"
    fi

    if [[ "$skip_count" -ge "$threshold_n" ]]; then
        axis_hist=$(printf '%s' "$skip_json" | jq -r '[.[].axis] | group_by(.) | map("axis=\(.[0]) ×\(length)") | join(" · ")')
        refs=$(printf '%s' "$skip_json" | jq -r '.[] | "\(._source_path):\(._line)"' | head -3 | awk '{printf "`%s` ", $0}')
        printf -- '- **axis_skip 빈도** — n=%s · 분포: %s — 근거(샘플 3건): %s\n' "$skip_count" "$axis_hist" "$refs"
        printf '  - 권고: 특정 축 skip 이 반복되면 ambiguity-gate 임계(현행 0.2) 재조정 또는 해당 축 HARD-GATE 완화 검토.\n'
    fi
    printf '\n'
fi

# ----- Section 2: Protocol Improvements --------------------------------------

printf '## Protocol Improvements\n\n'

# Guard must reflect the actual render thresholds: pain uses >0, skip uses >=2.
# Otherwise e.g. skip_count==1 with no pain leaves the section body empty.
# Inner blocks can ALSO collapse to empty (groups_json length==0 when all
# pain notes share an unmatched key, or skip_reasons map(select(.n>=2))
# filters out all unique reasons). Track whether anything was emitted so
# the section never ends up as just a header followed by the next section.
if [[ "$pain_count" -eq 0 && "$skip_count" -lt 2 ]]; then
    printf '> no signal in window\n\n'
else
    section_emitted=0
    if [[ "$pain_count" -gt 0 ]]; then
        # Group pain/ambiguous notes by first /crucible:* token in text; else bucket as "general".
        # Emit up to 5 grouped items.
        groups_json="$(printf '%s' "$pain_json" | jq -c '
            map({
                key: ((.text // "") | capture("(?<k>/crucible:[a-z0-9_-]+)"; "i").k // "general"),
                category: .category,
                text: (.text // ""),
                src: "\(._source_path):\(._line)"
            })
            | group_by(.key)
            | map({
                key: .[0].key,
                n: length,
                cats: [.[].category] | unique | join("+"),
                samples: [.[].text] | .[0:1],
                refs: [.[].src] | .[0:3]
            })
            | sort_by(-.n)
            | .[0:5]
        ')"
        if [[ "$(printf '%s' "$groups_json" | jq 'length')" -gt 0 ]]; then
            printf '%s' "$groups_json" | jq -r '.[] | "- **\(.key)** (\(.cats), n=\(.n)) — \(.samples[0] // "")\n  - 근거: \(.refs | map("`\(.)`") | join(" "))"'
            printf '\n\n'
            section_emitted=1
        fi
    fi
    if [[ "$skip_count" -ge 2 ]]; then
        skip_reasons=$(printf '%s' "$skip_json" | jq -c '
            [.[] | select(.reason != null) | {reason: .reason, src: "\(._source_path):\(._line)"}]
            | group_by(.reason)
            | map({reason: .[0].reason, n: length, refs: [.[].src] | .[0:3]})
            | map(select(.n >= 2))
            | .[0:3]
        ')
        if [[ "$(printf '%s' "$skip_reasons" | jq 'length')" -gt 0 ]]; then
            printf '%s' "$skip_reasons" | jq -r '.[] | "- **반복 skip reason**: \(.reason) (n=\(.n)) — 근거: \(.refs | map("`\(.)`") | join(" "))"'
            printf '\n\n'
            section_emitted=1
        fi
    fi
    if [[ "$section_emitted" -eq 0 ]]; then
        printf '> no signal in window\n\n'
    fi
fi

# ----- Section 3: Promotion Candidates ---------------------------------------

printf '## Promotion Candidates\n\n'

# Guard must reflect the actual render thresholds: promo_notes uses >=1 via
# map(select(.n>=1)), gate uses >=2. Otherwise gate_count==1 with no notes
# leaves the section body empty. Inner blocks can also collapse, so track
# emission and fall back to "no signal" if both inner blocks emit nothing.
if [[ "$promo_notes_count" -eq 0 && "$gate_count" -lt 2 ]]; then
    printf '> no signal in window\n\n'
else
    section_emitted=0
    if [[ "$promo_notes_count" -gt 0 ]]; then
        # Group request/good by first /crucible:* token.
        promo_groups="$(printf '%s' "$promo_notes_json" | jq -c '
            map({
                key: ((.text // "") | capture("(?<k>/crucible:[a-z0-9_-]+)"; "i").k // "general"),
                category: .category,
                text: (.text // ""),
                src: "\(._source_path):\(._line)"
            })
            | group_by(.key)
            | map({
                key: .[0].key,
                n: length,
                cats: [.[].category] | unique | join("+"),
                samples: [.[].text] | .[0:1],
                refs: [.[].src] | .[0:3]
            })
            | map(select(.n >= 1))
            | sort_by(-.n)
            | .[0:5]
        ')"
        if [[ "$(printf '%s' "$promo_groups" | jq 'length')" -gt 0 ]]; then
            printf '%s' "$promo_groups" | jq -r '.[] | "- **\(.key)** (\(.cats), n=\(.n)) — \(.samples[0] // "")\n  - 근거: \(.refs | map("`\(.)`") | join(" "))"'
            printf '\n\n'
            section_emitted=1
        fi
    fi
    if [[ "$gate_count" -ge 2 ]]; then
        gate_refs=$(printf '%s' "$gate_json" | jq -r '.[] | "\(._source_path):\(._line)"' | head -3 | awk '{printf "`%s` ", $0}')
        printf -- '- **promotion_gate y-response ≥ 2** — n=%s — 근거: %s\n' "$gate_count" "$gate_refs"
        printf '  - 권고: 유저가 반복 승인한 패턴은 `/compound` 스킬의 기본 제안 후보로 앞당길 가치.\n\n'
        section_emitted=1
    fi
    if [[ "$section_emitted" -eq 0 ]]; then
        printf '> no signal in window\n\n'
    fi
fi

# ----- footer ---------------------------------------------------------------

printf -- '---\n\n'
printf '*이 리포트는 제안 전용이며 어떤 SKILL.md · memory · plugin.json 파일도 자동 수정하지 않는다. 실행 판단은 사용자 몫.*\n'

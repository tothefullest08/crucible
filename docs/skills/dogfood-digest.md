# `/dogfood-digest` *(v1.2.0)*

> Turn accumulated `/crucible:dogfood` JSONL into a single read-only Markdown proposal report — three fixed sections (Threshold Calibration · Protocol Improvements · Promotion Candidates) with back-references to every source event cited.

English · [한국어](./dogfood-digest.ko.md)

## Paradigm

`/dogfood-digest` is the counterpart to `/dogfood`: if `/dogfood` is the only skill that collects evidence about the others, `/dogfood-digest` is the only skill that **reads** that evidence and suggests what to change. The failure mode it prevents is the one where evidence piles up in a JSONL file nobody ever rereads. The failure mode it refuses to enter is automatic change-application: thresholds and SKILL.md bodies are load-bearing across sessions, and a single noisy auto-edit degrades every downstream run. So the digest is deliberately **proposal-only** — it writes exactly one file (`.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md`) and relies on the human to decide whether a suggestion becomes a real change, via `/plan` or direct edit. The split between an aggregator (`scripts/dogfood-digest.sh`, flag parsing + jq filtering) and a renderer (`scripts/dogfood-digest-render.sh`, 3-section Markdown) keeps the two decision axes — which events to include vs. how to present them — independently tunable.

## Judgment

Input: any combination of local `.claude/dogfood/log.jsonl` and global mirror `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl`, filtered by one of `--last N` (default 10), `--since DATE|Nd`, or `--all`, and scoped via `--scope local|global|both` (default both). Output: a single Markdown file saved to `.claude/plans/`, never overwriting any other tracked file.

Every emitted JSONL line is augmented in-memory with `_source_path` and `_line` (1-based) so each suggestion in the report cites the originating event. The report is designed to read top-down:

| Section | Source events | Heuristic |
|---------|---------------|-----------|
| Threshold Calibration | `qa_judge`, `axis_skip` | p50/p95 of scores + verdict histogram; axis-skip frequency. Emits "insufficient signal" below an observation-count floor (`--threshold-n`, default 3) to resist premature tuning. |
| Protocol Improvements | `note` (pain/ambiguous), `axis_skip.reason` | Groups notes by the first `/crucible:*` token found in the text (fallback key `general`); surfaces recurring skip reasons with `n ≥ 2`. Top 5 only. |
| Promotion Candidates | `note` (request/good), `promotion_gate.response=="y"` | Same grouping rule as Protocol; adds a separate bullet when promotion gates have been approved `n ≥ 2` times, which is a strong signal that the pattern belongs in `/compound`. |

Empty sections render an explicit `> no signal in window` so a missing signal is never confused with a missing section.

Recursion guard: any `skill_call` event whose `skill` contains `crucible:dogfood-digest` is dropped at the renderer's ingestion step so a digest run never sees itself in the next digest.

## Design Choices

- **Read-only, not auto-apply.** `--apply`, in-place diff patching, and threshold rewriting were all rejected. Thresholds and SKILL.md bodies compound across sessions; a single wrong auto-edit survives and multiplies. The proposal-only boundary mirrors the `/compound` promotion gate: the system can suggest, but only a human promotes.
- **One Markdown file, no subcommand split.** A `--target threshold|protocol|promotion` split would triple the surface area for marginal gain — the three sections already fit on one page, and readers want to scan all three at once to cross-reference a pain note against a qa_judge retry cluster.
- **Three sections, fixed order, always present.** Rendering the section header even when empty makes two things explicit: (1) "this window produced no Threshold signal" is a different claim from "the skill forgot about Threshold," and (2) reports become diffable across windows since the skeleton never shifts.
- **User-specified window, not cursor-based auto-advance.** A cursor would append `cursor` fields to the source JSONL and require append-only discipline to bend. Instead, the user picks `--last N` / `--since` / `--all`; idempotent re-runs stay safe, and filenames encode the window (`-last10`, `-since-2026-04-15`, `-all`) so they don't collide.
- **`_source_path` + `_line` injected in-memory.** The back-reference is the non-negotiable piece: a suggestion without provenance is folklore. Injecting the fields at aggregation time costs one jq pipeline and never touches the source file.
- **Observation-count floor (`--threshold-n 3`).** Tuning a qa-judge band off two samples is worse than tuning off none — it codifies noise. The floor is low enough to surface real signal in a weekly run and high enough to suppress n=1 flukes. It is explicitly exposed so power users can override for quiet logs.
- **`/crucible:*` grouping token + `general` bucket.** A richer NLP grouping was tried and drifted: topic vectors don't tell the user which *skill* a complaint belongs to. The slash-command token is the coarsest key that still maps one-to-one to an actionable locus (the named skill's SKILL.md). Everything else falls into `general` so it isn't silently dropped.

## Thresholds

`/dogfood-digest` does not introduce new thresholds. It is the **consumer side** of thresholds surfaced in existing docs:

- `qa_judge` verdict bands — summarized by p50/p95 against [`../thresholds.md §1`](../thresholds.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040).
- `promotion_gate` y-response frequency — compared against the false-positive budget in [`../thresholds.md §5`](../thresholds.md#5-promotion-gate-false-positive-rate---20-).
- `axis_skip` policy — cross-referenced with [`../axes.md`](../axes.md).
- Observation-count floor (`--threshold-n`, default 3) — configurable knob local to this skill.

## References

- Sibling skill [`/dogfood`](./dogfood.md) — the event source this digest consumes.
- Complementary skill [`/compound`](./compound.md) — where a Promotion Candidate eventually graduates to persistent memory.
- [`../../skills/dogfood-digest/SKILL.md`](../../skills/dogfood-digest/SKILL.md) — the skill contract (`validate_prompt` 4-axis self-check).
- [`../../scripts/dogfood-digest.sh`](../../scripts/dogfood-digest.sh) — aggregator (flag parsing, jq filtering, back-reference injection).
- [`../../scripts/dogfood-digest-render.sh`](../../scripts/dogfood-digest-render.sh) — 3-section Markdown renderer.
- [`../../__tests__/integration/test-dogfood-digest.sh`](../../__tests__/integration/test-dogfood-digest.sh) — SC-1~7 integration coverage.

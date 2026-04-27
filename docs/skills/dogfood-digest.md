# `/dogfood-digest` *(v1.3.0)*

> Turn accumulated `/crucible:dogfood` JSONL into a single read-only Markdown proposal report — three fixed sections (Threshold Calibration · Protocol Improvements · Promotion Candidates) with back-references to every source event cited.

English · [한국어](./dogfood-digest.ko.md)

## Paradigm

`/dogfood-digest` is the counterpart to `/dogfood`: if `/dogfood` is the only skill that collects evidence about the others, `/dogfood-digest` is the only skill that **reads** that evidence and suggests what to change. The failure mode it prevents is the one where evidence piles up in a JSONL file nobody ever rereads. The failure mode it refuses to enter is automatic change-application: thresholds and SKILL.md bodies are load-bearing across sessions, and a single noisy auto-edit degrades every downstream run. So the digest is deliberately **proposal-only** — it writes exactly one file (`.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md`) and relies on the human to decide whether a suggestion becomes a real change, via `/plan` or direct edit. The split between an aggregator (`scripts/dogfood-digest.sh`, flag parsing + jq filtering) and a renderer (`scripts/dogfood-digest-render.sh`, 3-section Markdown) keeps the two decision axes — which events to include vs. how to present them — independently tunable.

## Judgment

Input: any combination of local `.claude/dogfood/log.jsonl` and global mirror `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl`, filtered by one of `--last N` (default 10), `--since DATE|Nd`, or `--all`, and scoped via `--scope local|global|both` (default both). Output: a single Markdown file saved to `.claude/plans/`, never overwriting any other tracked file.

Output format is selectable via `--format markdown|json` (default markdown). The JSON branch emits a single schema-versioned object on stdout (`schema_version: "1"` — JSON string, compare with `.schema_version == "1"`) with the same three fixed sections, so agent consumers parse with `jq` instead of regexing the Markdown report. Each item carries a `type` discriminator so wrappers switch on `type` rather than positional index. Discriminators: `qa_distribution`, `axis_skip_freq`, `pain_group`, `skip_reason`, `promo_group`, `promotion_gate`.

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

## Stderr & Exit Codes *(added in v1.3.0, issues #16/#17/#18)*

Both pipeline halves (`scripts/dogfood-digest.sh` aggregator and `scripts/dogfood-digest-render.sh` renderer) treat stderr as a structured channel for programmatic consumers. Three guarantees:

**Severity prefix.** Every stderr line emitted via the script's own `err`/`warn`/`info` helpers carries the shape `<script>: <severity>: <msg>` where severity ∈ `{info, warn, error}`. The aggregator prefixes with `dogfood-digest:`; the renderer with `render:`. Unified pipeline grep:

```bash
grep -E '^(dogfood-digest|render): (info|warn|error):'
```

Recovery hints sometimes follow an `error:` line as a separate `info: hint:` line (e.g. the `--since` UTC fix-it hint). Agents that grep only `error:` see the fault but not the suggested fix; grep `info: hint:` for guidance.

**3-way exit code split** (replaces the prior 2-way arg-vs-success):

| Code | Meaning | Caller action |
|---|---|---|
| 0 | success (including empty / no-signal input) | — |
| 1 | runtime data-pipeline failure (jq sort, mv swap, tail) | data-shape issue; inspect input |
| 2 | argument error (unknown flag, mutex, bad value, duplicate) | fix the flag and retry |
| 3 | system / environment failure (mktemp on full disk, missing tools) | escalate, do **not** retry the same args |

Only `mktemp` failures move from 2 → 3. Every other arg-validation site stays at exit 2.

**Per-source warn rate-limit.** A pathological JSONL log with thousands of malformed rows used to emit one `warn:` line per bad row, blowing agent context budgets and training agents to ignore stderr entirely. Now capped at 5 verbatim `warn:` lines per source; anything beyond emits a single summary line:

```
dogfood-digest: warn: N more malformed rows skipped in <path> (cap=5)
```

The cap value is interpolated dynamically (`(cap=5)`), so an agent reading the line can recover the cap without consulting `--help`. Counters reset between sources so one bad file doesn't shadow the warn budget for others.

**`CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=1`.** CI workflows that legitimately set `CRUCIBLE_DOGFOOD_ROOT` / `CRUCIBLE_DOGFOOD_HOME` on every invocation can opt into silence so the env-override `info:` line doesn't flood stderr. **Strict literal `"1"`** — `true`, `yes`, ` 1` (leading space), or any other value does NOT enable. Suppresses **only** the `info:` env-override line; `warn:` and `error:` always emit (the opt-in is chosen-noise reduction, never failure masking).

**Backward-compat caveat.** Wrappers that parse stderr by exact-line content or branch on exit 2 expecting "any failure" need to update. Substring matching (file paths, error keywords) is unaffected; exit-0 vs non-zero matchers are unaffected.

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

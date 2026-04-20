# `/compound`

> Promote user-approved learnings into durable memory through a 6-step gate, 3 triggers, and a 5-dimensional overlap check.

## Paradigm

Automatic memory writes are the failure mode `/compound` is designed to prevent. Every other plugin in the neighbourhood writes memory first and asks forgiveness later; `/compound` inverts the default — nothing reaches `.claude/memory/` without an explicit user approval. The three triggers decide *when* to ask, the 5-dimensional overlap decides *whether to ask at all*, and the 6-step gate decides *how the user answers*. Together they turn memory from a passive accumulator into a curated artifact.

## Judgment

Input: a candidate promotion event (one of three triggers). Output: zero, one, or several files written to `.claude/memory/{tacit,corrections,preferences}/*.md`, each containing only fields the user accepted.

The three triggers:

1. **`pattern_repeat`** — the same correction appears `≥ 2` times within a session window. Fires from the `Stop` hook.
2. **`user_correction`** — the user explicitly negates a previous action ("no, stop doing X"). Fires from the `PreToolUse` hook.
3. **`session_wrap`** — `/session-wrap` or session end; batches all pending candidates into a single prompt.

Decision flow for a candidate:

1. Compute 5-dimensional overlap against existing entries. If overlap `≥ 0.80` with any entry, the candidate is a duplicate — skip.
2. Oscillation guard: if the candidate overlaps `Gen N-2` at `≥ 0.80`, abort the promotion loop; a ping-pong has been detected.
3. Present the 6-step gate to the user (see below). Only entries approved at every step are written.

## Design Choices

- **3 triggers, not "write on every correction."** A single trigger (only corrections) would miss pattern-level signals; a single trigger (only session-wrap) would miss hot-in-the-moment context. Three triggers cover repeat, in-flight, and batched without overlapping by construction.
- **Batching in the `Stop` hook.** The 3rd trigger (`session_wrap`) exists specifically so the user is not interrupted for each candidate mid-session. All held candidates are presented once.
- **Auto-disable after 3 consecutive rejections.** If a detector produces 3 rejected candidates in a row, it is suppressed for 7 days. Noisy detectors pay the cost of being noisy.
- **6-step promotion gate.** The prompt walks the user through `summary → context → evidence → proposed entry → target path → final y/N/e/s`. Each step can be edited (`e`) or skipped (`s`); only the final step writes. Bundling all six into one prompt was tried and produced higher false-positive rates because users accepted bundled entries they would have rejected individually.
- **5-dimensional overlap, not token similarity.** Token cosine similarity misses semantic duplicates across rephrasings. Scoring `problem · cause · solution · files · prevention` independently captures the axes that matter for a correction.
- **Oscillation guard looks `N-2` back.** `N-1` is too tight (legitimate incremental improvement triggers false oscillation) and `N-3` is too loose (a two-step ping-pong cycles under the detector). `N-2` is the minimum window that catches the `A → B → A` case.
- **Three target directories, not one.** `tacit/` vs `corrections/` vs `preferences/` keeps retrieval scoped — a future `/brainstorm` can load corrections without polluting context with preferences.

## Thresholds

All numeric values live in [`../thresholds.md`](../thresholds.md):

- Promotion-gate false-positive ≤ `0.20` — [§5](../thresholds.md#5-promotion-gate-false-positive-rate---20-).
- 5-dimensional overlap weights `problem 0.30 · cause 0.20 · solution 0.20 · files 0.15 · prevention 0.15` (sum = 1.00) — [§7](../thresholds.md#7-5-dimensional-overlap-weights).
- Oscillation guard `overlap ≥ 0.80` within `Gen N-2` — [§8](../thresholds.md#8-oscillation-guard--overlap--080-within-gen-n-2).
- Auto-disable cadence (3 rejections / 7 days) — design convention, tracked in this file.

## References

- Upstream `compound-engineering-plugin` — 5-dimensional overlap scoring, Auto Memory conventions, persistence discipline.
- Upstream `p4cn` — `session-wrap` 2-phase pipeline that drives the 3rd trigger.
- [`../axes.md`](../axes.md) — `/compound`'s axis matrix row (Context ON, Execute ON, Improve ON).
- [`../faq.md`](../faq.md) — Q4 (gate annoyance), Q5 (`/orchestrate` vs manual chaining).
- [`../../skills/compound/SKILL.md`](../../skills/compound/SKILL.md) — the SKILL contract.

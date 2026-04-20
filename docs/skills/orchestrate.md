# `/orchestrate` *(Stretch)*

> Chain `/brainstorm → /plan → /verify → /compound` through six disk checkpoints, SHA256-pinned, crash-safe on resume.

English · [한국어](./orchestrate.ko.md)

## Paradigm

`/orchestrate` is the only skill that lights up all six axes at once. Every other skill owns a subset of the pipeline; `/orchestrate` owns the pipeline itself. The design tension it resolves is the gap between "I want the end-to-end run" and "I do not want to rerun the first three axes because the fourth crashed." Disk checkpoints are the cheapest mechanism we found that preserves both properties — the run goes fast when nothing breaks, and resumes cleanly from the last disk write when something does.

## Judgment

Input: a topic prompt (English or Korean). Output: a six-file checkpoint trail plus the final artifacts from each axis.

Sequential phases and checkpoints:

| CP | Phase | Checkpoint contents |
|----|-------|---------------------|
| **CP-0** | `/brainstorm` invocation | Input prompt + resolved ambiguities |
| **CP-1** | `/plan` emission | Hybrid Markdown + YAML plan file |
| **CP-2** | `/verify` verdict | `qa-judge` JSON report |
| **CP-3** | `/compound` gate result | Approved / rejected candidates |
| **CP-4** | Artifact link bundle | All file paths + SHA256s |
| **CP-5** | `experiment-log.yaml` commit | Git commit recording the full run |

Each checkpoint file lives under `.claude/state/orchestrate/<run-id>/cp-N.json` with its own SHA256 recorded in `cp-N.json.sha256`. On re-invocation, `/orchestrate` reads the latest valid CP file and resumes from the next phase. The SHA pin is what turns "resume from disk" from a liability into a guarantee — if any checkpoint has been tampered with, resume refuses and the run restarts from CP-0.

### Allowed `dispatch × work × verify` combinations

`/orchestrate` accepts exactly three combinations of dispatch strategy × worker shape × verify placement:

1. **sequential × single × end** — one worker, one axis at a time, verify at the very end. The default.
2. **sequential × single × per-axis** — one worker, one axis at a time, verify after *each* axis. Costs more but tightens the feedback loop.
3. **parallel-tasks × many × per-axis** — parallel workers on independent tasks within an axis, verify gated per-axis.

Other combinations (e.g. parallel × many × end-only) are rejected — they remove the axis-level blast radius control the harness is designed to enforce.

## Design Choices

- **4 axes in order, not in parallel.** Brainstorm must resolve before Plan; Plan must exist before Verify; Verify must pass before Compound. The sequential dependency is structural, not a performance choice.
- **Disk checkpoints, not in-memory state.** The whole point is surviving a crash. Anything short of disk is lost when the session dies.
- **SHA256 pin per checkpoint.** Without the pin, a tampered CP file would let resume start from a state that never existed. The pin turns resume into a verified operation.
- **`CP-4` bundles artifact paths, not the artifacts themselves.** Duplicating artifacts into the checkpoint trail bloats the run directory and guarantees drift. Paths + SHAs let the resume validate without copying.
- **`CP-5` is a git commit, not a file.** The final checkpoint has to be durable against workspace rm. A commit is the strongest portable durability boundary on a local machine.
- **Three `dispatch × work × verify` combinations, not arbitrary.** The restricted set is enumerable, reviewable, and safe. Any combination that removes per-axis verification defeats the harness.
- **Re-invocation is idempotent per checkpoint.** Running `/orchestrate` twice at CP-3 does not re-run CP-0..CP-2; it reads their outputs and resumes. Idempotency is the property that makes resume trustworthy.

## Thresholds

All numeric values live in [`../thresholds.md`](../thresholds.md):

- `qa-judge` verdict bands applied per axis — [§1](../thresholds.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040).
- Ralph Loop retry cap `3` inherited from `/verify` — [§6](../thresholds.md#6-ralph-loop-retry-cap--3).
- Oscillation guard (shared with `/compound`) — [§8](../thresholds.md#8-oscillation-guard--overlap--080-within-gen-n-2).
- SHA256 integrity per checkpoint — design convention, tracked here.

## References

- Upstream `ouroboros` — checkpoint + resume convention adapted for slash-command runs.
- Upstream `superpowers` — `SessionStart` hook and axis-scoped hook design.
- Upstream `agent-council` — marketplace minimal structure, Wait cursor UX during long runs.
- [`../axes.md`](../axes.md) — all six axes (this is the only row where every cell is ON).
- [`../faq.md`](../faq.md) — Q5 (`/orchestrate` vs manual chaining).
- [`../../skills/orchestrate/SKILL.md`](../../skills/orchestrate/SKILL.md) — the SKILL contract.

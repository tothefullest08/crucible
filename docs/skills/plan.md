# `/plan`

> Turn a requirements doc into a hybrid Markdown + YAML plan that both humans and `qa-judge` can parse.

## Paradigm

`/plan` takes a single input (`*-requirements.md` from `/brainstorm`) and produces a single file that serves two readers at once: a human reviewer who reads the Markdown body, and the `qa-judge` Evaluator that reads the YAML frontmatter. The dual-reader constraint is the whole point — a plan that only humans can parse cannot be verified, and a plan that only machines can parse cannot be reviewed. The hybrid format is the contract that keeps both honest.

## Judgment

Input is a requirements doc path; output is `.claude/plans/YYYY-MM-DD-{slug}-plan.md` containing:

- **YAML frontmatter** — `goal`, `slug`, `date`, `parent_seed_id`, `source_requirements`, `ambiguity_verdict`, `ambiguity_score`, `constraints`, `acceptance_criteria {hard, stretch}`, `evaluation_principles [{name, weight, description, metric}]`, `exit_conditions {success, failure, timeout}`.
- **Markdown body** — `Ambiguity Score Gate`, `Decisions`, `Tasks` (with dependency graph), `Gaps`, `Exit Conditions`, `Next Steps`.

The skill blocks on:

1. **Ambiguity Score Gate.** If `ambiguity_score > 0.20`, the skill refuses and redirects back to `/brainstorm`. The gate is computed from the number of unresolved Open Questions divided by a normalising constant.
2. **Evaluation principles sum to `1.00`.** Any weight set that does not sum cleanly is rejected before emission.
3. **Every Hard AC maps to at least one task.** An AC with no task is an AC that cannot pass; the skill refuses to emit.

## Design Choices

- **Markdown + YAML hybrid, not two files.** Two files (a `plan.md` and a `plan.yaml`) diverge in practice — someone edits one and forgets the other. A single file with frontmatter is self-consistent by construction.
- **Ambiguity Score Gate at `0.20`.** Below `0.20`, open questions are small enough that `/plan` can decide them inline (see the `Decisions` table every plan emits). Above `0.20`, the honest action is to go back to `/brainstorm`. The gate is a boundary, not a heuristic.
- **Weighted `evaluation_principles`, sum = 1.00.** Weights force the plan author to declare tradeoffs explicitly. `qa-judge` scores the artifact by the same weights, so the plan and the verification are measuring the same thing.
- **`exit_conditions` has three fields, not one.** `success`, `failure`, and `timeout` are distinct — success criteria are what we are trying to achieve, failure criteria are what forces a stop-and-rework, and timeout is the budget. Collapsing them loses the "we ran out of time, so ship P0 only" branch.
- **Task dependency graph is explicit.** Each task lists `depends_on: [task_ids]`. A graph is parseable; prose is not. This is what lets `/orchestrate` parallelise the independent branches.
- **No plan amends the requirements doc.** The requirements doc is immutable once `/plan` consumes it; drift goes into the `Decisions` table with a rationale.

## Thresholds

All quantitative values live in [`../thresholds.md`](../thresholds.md):

- Ambiguity Score Gate `0.20` — design-inferred boundary (see §2 derivation of sample sizes for the family of `1/√n` readability bounds).
- `qa-judge` verdict bands `0.80 / 0.40` that `/plan` outputs are scored against — [§1](../thresholds.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040).
- `validate_prompt` fire/response rates — [§3](../thresholds.md#3-validate_prompt--fire_rate--099-response_rate--090).

## References

- Upstream `ouroboros` — Seed YAML schema, Ambiguity Gate, `evaluation_principles` weighting.
- Upstream `hoyeon` — `validate_prompt` hook pattern (used by `/plan` to enforce the AC-to-task mapping).
- [`../axes.md`](../axes.md) — `/plan`'s axis matrix row (all six axes ON except Improve).
- [`../../skills/plan/SKILL.md`](../../skills/plan/SKILL.md) — the SKILL contract.
- Internal: final-spec v3.1 §2.2 Decision #10 for the Markdown + YAML choice.

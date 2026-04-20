# `/verify`

> Score an artifact with `qa-judge`, retry through Ralph Loop, and fall through to manual review when the cap hits.

## Paradigm

Verify is the one axis whose absence looks identical to a pass. `/verify` exists so that absence becomes impossible: it produces a numeric verdict (`qa-judge` score + dimensions) that any other skill (`/plan`, `/compound`, `/orchestrate`) can read without re-interpreting the artifact. The retry loop (Ralph Loop) and the fresh-context separation are there to make the verdict *credible*, not just present. If `/verify` were single-pass and reused the author's context, the verdict would be a self-review.

## Judgment

Input: an artifact path plus optional `--axis N` scope. Output: a `qa-judge` JSON report with `{score, verdict, dimensions, differences, suggestions}`.

Decision logic:

1. Run `qa-judge` in a **fresh Claude Code context** (no author turns loaded). This is what prevents the Evaluator from inheriting the author's blind spots.
2. Read `score` and place it into one of three bands:
   - `score ≥ 0.80` → `promote` (accept).
   - `0.40 ≤ score < 0.80` → `retry` (Ralph Loop with up to 3 attempts).
   - `score ≤ 0.40` → `reject` (return to author).
3. On `retry`, run the **3-stage Evaluator**: (a) diff the artifact against the acceptance criteria, (b) propose minimal edits, (c) re-score. If the post-edit score crosses into `promote`, accept; otherwise decrement the retry counter.
4. When the retry counter reaches zero, emit `verdict: manual_review` rather than forcing another loop. The cap is a circuit breaker, not a target.

`--axis N` narrows `qa-judge` to a single axis rubric (e.g. `--axis 5` runs Verify-only on a plan). `--skip-axis 5 --acknowledge-risk` is the only way to bypass `/verify` at the pipeline level; see [`../axes.md`](../axes.md#axis-5-is-different---skip-axis-5-requires---acknowledge-risk).

## Design Choices

- **Fresh context, not a persistent one.** A persistent Evaluator converges on the author's reasoning after a few rounds. A fresh context forces the Evaluator to re-derive its verdict from the artifact alone, which is what we want.
- **3 bands, not 2.** A binary `pass / fail` throws away the signal that an artifact is "almost good enough, try once more." The `retry` band is where Ralph Loop adds its value.
- **Ralph Loop, not an ad-hoc retry.** Ralph Loop is the `ouroboros` convention with a capped counter and a structured critic. Ad-hoc retries in the author's context would be self-review in a trench coat.
- **3-stage Evaluator inside the retry.** Splitting "diff → propose → re-score" keeps each stage simple. A one-shot "rewrite and re-score" was tried and tended to rewrite the acceptance criteria along with the artifact.
- **`qa-judge` emits structured JSON, not prose.** Consumers (`/compound`, `/orchestrate`, the skip log) need a parseable verdict. Prose-only reports are not parseable.
- **Fall-through to `manual_review` on cap.** A silent loop past the cap is worse than a loud escalation. The cap is the hand-off to a human, not a failure of the skill.

## Thresholds

All numeric values live in [`../thresholds.md`](../thresholds.md):

- Verdict bands `promote ≥ 0.80 / retry 0.40–0.80 / reject ≤ 0.40` — [§1](../thresholds.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040).
- Ralph Loop retry cap `3` — [§6](../thresholds.md#6-ralph-loop-retry-cap--3).
- `validate_prompt` fire/response rates `≥ 0.99 / 0.90` — [§3](../thresholds.md#3-validate_prompt--fire_rate--099-response_rate--090).
- KU-0 histogram behind the bands — [§1](../thresholds.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040) cites `p25 = 0.50`, `p75 = 0.86`.

## References

- Upstream `ouroboros` — `qa-judge` JSON schema, Ralph Loop convention, retry cap.
- Upstream `superpowers` (obra/superpowers) — `HARD-GATE` tag pattern and the 3-stage Evaluator.
- Upstream `hoyeon` — 6-agent verify stack referenced by the 3-stage Evaluator's diff-and-propose split.
- [`../axes.md`](../axes.md) — Axis 5 rationale and the `--acknowledge-risk` contract.
- [`../faq.md`](../faq.md) — Q3 (Ralph Loop infinite loop?), Q9 (`--acknowledge-risk`).
- [`../../skills/verify/SKILL.md`](../../skills/verify/SKILL.md) — the SKILL contract.

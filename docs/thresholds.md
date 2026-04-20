# Thresholds — single source of truth

> ⚠️ **MVP status.** Every number below is anchored to either an upstream convention, a design derivation, or a 20-sample **synthetic fixture** (KU-0 · KU-1 · KU-2 · KU-3 under `.claude/state/ku-results/`). Production tuning **is required** once real-session JSONL logs (≥ 100) are collected. Treat these values as defaults, not as validated production constants.

English · [한국어](./thresholds.ko.md)

All quantitative values used by `crucible` live in this file. Every other file links here; **no number may be duplicated**. Edits to a value must update this file first, then any referring doc.

---

## 0. How the numbers are produced

The numbers in this file are produced in two stages: **(A) obtaining raw observations** and **(B) aggregating them into quantiles or ratios**. In the MVP, stage (A) is replaced by synthetic fixtures; only stage (B) runs as real bash + awk + jq code. The question "how does a natural-language conversation become a number like `0.72`" splits across these two stages.

### (A) Raw observations — how "natural-language judgment" becomes a number

There are two kinds of raw values.

**1. `qa-judge` score (relevant to §1, §5)**

- The mechanism is **LLM-as-judge**. There is no separate calculator, rule engine, or formula. The prompt defined in `agents/evaluator/qa-judge.md:18-72` is invoked as an opus sub-agent.
- The call flow is:
  1. `/verify` hands the `qa-judge` sub-agent the artifact + `evaluation_criteria` + `pass_threshold`.
  2. The LLM, following the prompt, **self-scores** three dimensions (`correctness`, `clarity`, `maintainability`), each as a float in `[0.0, 1.0]`.
  3. It returns a single aggregated `score` + verdict (`promote | retry | reject`) + `differences[]` + `suggestions[]` as **strict JSON only** (no prose, no code fences).
  4. The `/verify` bash script parses this JSON with `jq` and compares against the thresholds in §1; it does not recompute the score.
- So `score = 0.72` is not an algorithmic result — it is **a label the LLM subjectively assigned based on the rubric ("this artifact is clarity 0.68, correctness 0.75…")**. The inherent limits of rubric-based LLM-as-judge — run-to-run variance, self-preference bias, rubric gaming, boundary-anchoring — are absorbed by three mechanisms rather than eliminated empirically:
  - **Grey zone**: a wide `0.40–0.80` retry interval instead of a single threshold (§1)
  - **Ralph Loop**: up to 3 regenerations + rescores in the retry band (§6)
  - **User approval gate**: even when `qa-judge` emits `promote`, `/compound` never writes to memory without explicit user approval (CLAUDE.md §6 Improve)

**2. `validate_prompt` fire / response observations (relevant to §3)**

- The production-intent mechanism is **observation of session JSONL tool_use events**: given an input prompt, did a `SKILL` tool_use actually occur (`fire`), and did the response string match the expected regex (`response`)?
- **In the MVP, these observations are fully replaced by fixtures.** Each sample in `__tests__/fixtures/ku-1-validate-prompt/*.json` carries `"actual_fire": true/false`, `"actual_response": "..."`, `"initial_match": true/false`, and `"expected_response_pattern": "..."` — **hand-authored**. No hook actually fires; the script just aggregates the hard-coded flags.

### (B) Aggregation — fixture → quantile · ratio

Once the raw values in (A) exist, bash + awk + jq scripts under `scripts/` perform pure arithmetic to extract quantiles and ratios. The LLM does not participate in this stage. Python is not used either (final-spec §4.1).

**KU-0 — `scripts/ku-0-run.sh` + `scripts/ku-histogram.sh`**

- Input: `__tests__/fixtures/ku-0-qa-judge/samples.jsonl` (20 lines, each a synthetic `qa-judge` response with `score`, `verdict`, `dimensions`)
- Processing:
  1. `jq -r '.score'` extracts 20 floats
  2. `sort -n` sorts them ascending
  3. awk performs linear-interpolation to compute p10 / p25 / p50 / p75 / p90 — formula: `pos = p × (n − 1) + 1`, `lo = floor(pos)`, `hi = min(lo + 1, n)`, `q = a[lo] + (pos − lo) × (a[hi] − a[lo])`
- Output: the `histogram` object in `.claude/state/ku-results/ku-0.json`
- **§1's `p25=0.50`, `p50=0.72`, `p75=0.86`, `p90=0.92` are precisely the quantiles of these 20 synthetic numbers** (`0.10, 0.22, 0.30, 0.38, 0.45, 0.52, 0.58, 0.62, 0.66, 0.70, 0.74, 0.78, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92, 0.93, 0.95`) — not a real-session `qa-judge` distribution. The numbers were **hand-authored by the fixture author** to spread evenly across the reject · retry · promote bands.

**KU-1 — `scripts/ku-1-run.sh`**

- Input: `__tests__/fixtures/ku-1-validate-prompt/*.json` (20 files, one sample each)
- Processing: aggregate each sample's `actual_fire` into `fire_rate = fired / 20`; among those that fired, count regex matches for `response_rate = matched / fired`. If `initial_match = false`, simulate a rule-based single retry (inject the primary keyword into the response, then re-match).
- Output: `.claude/state/ku-results/ku-1.json`
- **§3's `fire_rate = 1.00` means "all 20 fixture files have `actual_fire: true` written in them"**, not that the hook empirically fires ≥ 99 % of the time.

**KU-2, KU-3** follow the same pattern — fixtures carry pre-labeled ground truth and predictions, and the scripts compute accuracy · confusion matrix.

### Production migration plan

Every `ku-*-run.sh` reads the `KU_DATA_SOURCE` environment variable. The default is `synthetic` (fixture); setting `real_session` wires the script to consume real-session JSONL logs as raw input. **This switch does not happen until real-session logs ≥ 100 accumulate** — which is why every number here is "the quantile of a placeholder distribution that a developer hand-seeded across three bands". Treat the numbers in this file as **defaults**, not production constants — that is the meaning of the ⚠️ warning at the top.

---

## 1. `qa-judge` verdict bands — `promote ≥ 0.80`, `retry 0.40–0.80`, `reject ≤ 0.40`

| Band | Range | Action |
|------|-------|--------|
| promote | `score ≥ 0.80` | Artifact accepted. |
| retry | `0.40 ≤ score < 0.80` | Ralph Loop retry (see §6). |
| reject | `score ≤ 0.40` | Artifact rejected; require rework. |

- **Source.** Upstream `ouroboros` defaults (accept 0.80, retry 0.40).
- **How the score is produced.** The score is produced by the `qa-judge` LLM sub-agent (opus), which self-scores along a three-dimension rubric (`correctness` · `clarity` · `maintainability`) and aggregates. There is no separate computation algorithm — see §0 (A-1) for details.
- **Measurement (KU-0).** Running `scripts/ku-histogram.sh` over the 20 synthetic scores in `__tests__/fixtures/ku-0-qa-judge/samples.jsonl` (`0.10 … 0.95`, hand-authored to spread evenly across the reject/retry/promote bands) and computing linear-interpolation quantiles yields: `p25 = 0.50`, `p50 = 0.72`, `p75 = 0.86`, `p90 = 0.92`. This is **not** a distribution collected from 20 real `qa-judge` LLM invocations (see §0 B).
- **Observation.** KU-0 re-quantiled the upstream defaults to `accept 0.86 / retry 0.50`. We keep `0.80 / 0.40` for the MVP because the 20-sample fixture is too small to shift published thresholds.
- **Tuning plan.** Re-run KU-0 against ≥ 100 real-session `qa-judge` outputs via `KU_DATA_SOURCE=real_session scripts/ku-0-run.sh`. Adopt `accept = p75` and `retry = p25` if the production distribution is still right-skewed.

## 2. KU sample size — `n = 20`

- **Source.** Binary-verdict 95 % confidence-interval width.
- **Derivation.** For a binomial estimate with `p̂ ≈ 0.5`, CI half-width is roughly `1/√n`: `n=10 → ±30 %pp`, `n=20 → ±22 %pp`, `n=30 → ±17 %pp`. `n=20` is the smallest size where the CI half-width crosses below the 25 %pp readability threshold.
- **Tuning plan.** Raise to `n=30` for acceptance KUs once dogfooding produces enough qualifying sessions.

## 3. `validate_prompt` — `fire_rate ≥ 0.99`, `response_rate ≥ 0.90`

- **Source.** KU-1 acceptance thresholds (W7.5 AC-3).
- **How the observations are produced.** The production-intent definition of `fire_rate` and `response_rate` is session-JSONL tool_use observation — given an input prompt, did a `SKILL` tool_use fire (`fire`), and did the response match the expected regex (`response`)? In the MVP these observations are replaced by hand-coded fixtures — see §0 (A-2) for details.
- **Measurement (KU-1).** Each of the 20 files in `__tests__/fixtures/ku-1-validate-prompt/*.json` carries hand-authored `actual_fire`, `actual_response`, `initial_match`, and `expected_response_pattern` fields; `scripts/ku-1-run.sh` aggregates them to compute `fire_rate = fired/20 = 1.00`, `response_rate = matched/fired = 1.00`, `retried = 1`. No hook invocations or LLM responses actually occur.
- **Observation.** Fixture is fully synthetic; no real misses were observed — `fire_rate = 1.00` means "all 20 fixtures have `actual_fire: true` written in them", not an empirical fire rate.
- **Tuning plan.** When switched to `KU_DATA_SOURCE=real_session` mode, which uses production session JSONL as raw input, `fire ≥ 0.99` must be preserved; drop the threshold only if user-visible retries become the dominant class.

## 4. Description trigger accuracy — `|Δ(ko − en)| ≤ 5 %pp`

- **Source.** KU-2 acceptance threshold (W7.5 AC-4).
- **Measurement (KU-2).** Each of the 40 synthetic prompts (20 ko + 20 en) under `__tests__/fixtures/ku-2-description/` carries a pre-labeled expected trigger and predicted trigger; `scripts/ku-2-run.sh` computes accuracy: `ko_accuracy = 1.00`, `en_accuracy = 1.00`, `Δ_abs = |ko − en| = 0.00`. This is an aggregation of fixture labels, not a real description-matching run (same pattern as §0 B).
- **Observation.** Fixture shows Δ = 0 across languages; a production drift would first appear here.
- **Tuning plan.** Monitor Δ in real usage. A Δ above the threshold forces description rewrites before release.

## 5. Promotion-gate false-positive rate — `≤ 20 %`

- **Source.** KU-3 acceptance threshold (W7.5 AC-5).
- **Measurement (KU-3).** Each of the 20 synthetic candidates under `__tests__/fixtures/ku-3-promotion-gate/` carries a pre-labeled ground truth (`signal | noise`) and gate-predicted verdict; `scripts/ku-3-run.sh` computes the confusion matrix: `(TP=10, FP=0, TN=10, FN=0)`, `false_positive_rate = FP / (FP + TN) = 0.00`. This is an aggregation of fixture labels, not an actual `/compound` gate inference.
- **Observation.** The `/compound` gate rejected every non-signal candidate in the fixture. Real corrections will be harder to separate.
- **Tuning plan.** If production FP exceeds `0.20`, raise the overlap threshold (§7) or add a second reviewer pass to the promotion flow.

## 6. Ralph Loop retry cap — `3`

- **Source.** `ouroboros` convention — the same cap used in upstream retry loops to prevent runaway generation.
- **Derivation.** With `qa-judge` in the retry band (`0.40–0.80`), three retries give the model enough budget to respond to a single round of human feedback without turning into an infinite critic loop. Cap hits → fall through to manual intervention.
- **Tuning plan.** Raise only if real sessions show the third attempt consistently succeeding; otherwise the cap is the circuit breaker.

## 7. 5-dimensional overlap weights

Used by `/compound` to score whether a new correction is a duplicate of an existing memory entry:

| Dimension | Weight |
|-----------|:-----:|
| problem | `0.30` |
| cause | `0.20` |
| solution | `0.20` |
| files | `0.15` |
| prevention | `0.15` |
| **sum** | **1.00** |

- **Source.** Ported from the `compound-engineering-plugin` 5-dimensional overlap scoring, weights adjusted for `/compound`'s promotion semantics.
- **Derivation.** `problem` dominates because two corrections that name the same failure mode are duplicates even if they ship different fixes. `cause` and `solution` share the second tier because either alone is ambiguous. `files` and `prevention` are tiebreakers, so they sit at the lowest weight.
- **Tuning plan.** If promotion-gate FP (§5) rises above `0.20`, the first lever is raising `problem` to `0.40` and rebalancing the rest to keep the sum at `1.00`.

## 8. Oscillation guard — `overlap ≥ 0.80` within `Gen N-2`

- **Source.** Design inference — retry loops in `/verify` and re-promotion loops in `/compound` can ping-pong between two almost-identical candidates.
- **Derivation.** If the generation at `N` overlaps a generation from `N-2` (i.e. two steps back) at `≥ 0.80` by the 5-D score (§7), the harness aborts the loop as an oscillation rather than spending the remaining retries on the same pair.
- **Tuning plan.** Adjust the comparison window (`N-2`) and threshold jointly once we have real oscillation data — both levers are meaningless in isolation.

---

## Cross-reference summary

| # | Number | Used by |
|---|--------|---------|
| 0 | How the numbers are produced (LLM-as-judge + bash aggregation) | — (internal reference in this file) |
| 1 | `0.80 / 0.40` verdict bands | [`skills/verify.md`](./skills/verify.md), [`faq.md`](./faq.md) |
| 2 | `n = 20` KU sample size | [`faq.md`](./faq.md) |
| 3 | `fire ≥ 0.99`, `response ≥ 0.90` | [`axes.md`](./axes.md) §4 Execute |
| 4 | `Δ ≤ 5 %pp` | [`faq.md`](./faq.md) bilingual Q |
| 5 | `FP ≤ 20 %` | [`skills/compound.md`](./skills/compound.md) |
| 6 | Ralph Loop cap `3` | [`skills/verify.md`](./skills/verify.md), [`faq.md`](./faq.md) |
| 7 | Overlap weights | [`skills/compound.md`](./skills/compound.md) |
| 8 | Oscillation guard | [`skills/compound.md`](./skills/compound.md), [`skills/orchestrate.md`](./skills/orchestrate.md) |

When adding a new quantitative value anywhere in `docs/` or `README.md`, add a new numbered section here **first** and link to it from the consuming file.

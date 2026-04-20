# Thresholds — single source of truth

> ⚠️ **MVP status.** Every number below is anchored to either an upstream convention, a design derivation, or a 20-sample **synthetic fixture** (KU-0 · KU-1 · KU-2 · KU-3 under `.claude/state/ku-results/`). Production tuning **is required** once real-session JSONL logs (≥ 100) are collected. Treat these values as defaults, not as validated production constants.

English · [한국어](./thresholds.ko.md)

All quantitative values used by `crucible` live in this file. Every other file links here; **no number may be duplicated**. Edits to a value must update this file first, then any referring doc.

---

## 1. `qa-judge` verdict bands — `promote ≥ 0.80`, `retry 0.40–0.80`, `reject ≤ 0.40`

| Band | Range | Action |
|------|-------|--------|
| promote | `score ≥ 0.80` | Artifact accepted. |
| retry | `0.40 ≤ score < 0.80` | Ralph Loop retry (see §6). |
| reject | `score ≤ 0.40` | Artifact rejected; require rework. |

- **Source.** Upstream `ouroboros` defaults (accept 0.80, retry 0.40).
- **Measurement.** KU-0 histogram of 20 synthetic `qa-judge` runs: `p25 = 0.50`, `p50 = 0.72`, `p75 = 0.86`, `p90 = 0.92`.
- **Observation.** KU-0 re-quantiled the upstream defaults to `accept 0.86 / retry 0.50`. We keep `0.80 / 0.40` for the MVP because the 20-sample fixture is too small to shift published thresholds.
- **Tuning plan.** Re-run KU-0 against ≥ 100 real-session `qa-judge` outputs. Adopt `accept = p75` and `retry = p25` if the production distribution is still right-skewed.

## 2. KU sample size — `n = 20`

- **Source.** Binary-verdict 95 % confidence-interval width.
- **Derivation.** For a binomial estimate with `p̂ ≈ 0.5`, CI half-width is roughly `1/√n`: `n=10 → ±30 %pp`, `n=20 → ±22 %pp`, `n=30 → ±17 %pp`. `n=20` is the smallest size where the CI half-width crosses below the 25 %pp readability threshold.
- **Tuning plan.** Raise to `n=30` for acceptance KUs once dogfooding produces enough qualifying sessions.

## 3. `validate_prompt` — `fire_rate ≥ 0.99`, `response_rate ≥ 0.90`

- **Source.** KU-1 acceptance thresholds (W7.5 AC-3).
- **Measurement (KU-1).** 20 synthetic prompts → `fire_rate = 1.00`, `response_rate = 1.00`, `retried = 1` sample.
- **Observation.** Fixture is fully synthetic; no real misses were observed.
- **Tuning plan.** Production logs must preserve `fire ≥ 0.99`; drop the threshold only if user-visible retries become the dominant class.

## 4. Description trigger accuracy — `|Δ(ko − en)| ≤ 5 %pp`

- **Source.** KU-2 acceptance threshold (W7.5 AC-4).
- **Measurement (KU-2).** 40 synthetic prompts (20 ko + 20 en) → `ko_accuracy = 1.00`, `en_accuracy = 1.00`, `Δ_abs = 0.00`.
- **Observation.** Fixture shows Δ = 0 across languages; a production drift would first appear here.
- **Tuning plan.** Monitor Δ in real usage. A Δ above the threshold forces description rewrites before release.

## 5. Promotion-gate false-positive rate — `≤ 20 %`

- **Source.** KU-3 acceptance threshold (W7.5 AC-5).
- **Measurement (KU-3).** 20 synthetic candidates (`10 TP + 10 TN`) → `false_positive_rate = 0.00`, confusion `(TP=10, FP=0, TN=10, FN=0)`.
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
| 1 | `0.80 / 0.40` verdict bands | [`skills/verify.md`](./skills/verify.md), [`faq.md`](./faq.md) |
| 2 | `n = 20` KU sample size | [`faq.md`](./faq.md) |
| 3 | `fire ≥ 0.99`, `response ≥ 0.90` | [`axes.md`](./axes.md) §4 Execute |
| 4 | `Δ ≤ 5 %pp` | [`faq.md`](./faq.md) bilingual Q |
| 5 | `FP ≤ 20 %` | [`skills/compound.md`](./skills/compound.md) |
| 6 | Ralph Loop cap `3` | [`skills/verify.md`](./skills/verify.md), [`faq.md`](./faq.md) |
| 7 | Overlap weights | [`skills/compound.md`](./skills/compound.md) |
| 8 | Oscillation guard | [`skills/compound.md`](./skills/compound.md), [`skills/orchestrate.md`](./skills/orchestrate.md) |

When adding a new quantitative value anywhere in `docs/` or `README.md`, add a new numbered section here **first** and link to it from the consuming file.

# FAQ

> Plain-answer FAQ. Every numeric value points back to [`thresholds.md`](./thresholds.md); this file explains *why* those numbers exist, not what they are.

English · [한국어](./faq.ko.md)

---

## Q1. Why `0.80 / 0.40` for `qa-judge`?

The upstream `ouroboros` defaults are `promote ≥ 0.80` and `reject ≤ 0.40`, and we kept them for the MVP. KU-0 re-measured the actual distribution on 20 synthetic samples and found `p75 = 0.86` and `p25 = 0.50`, so the published bands are slightly conservative relative to the fixture. We do not shift the published thresholds on 20 samples alone; the plan is to re-run KU-0 on ≥ 100 real-session `qa-judge` outputs and adopt the measured `p75 / p25` at that point. See [`thresholds.md` §1](./thresholds.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040).

## Q2. You built everything on synthetic fixtures. Should I trust this in production?

**No — not as a validated system.** Trust it as an MVP. Every KU in `.claude/state/ku-results/` is marked `data_source: synthetic`, and every threshold in [`thresholds.md`](./thresholds.md) flags the same caveat. The fixtures prove the wiring, not the calibration. The production tuning loop is: dogfood → collect real sessions → re-run KU-0/1/2/3 against that pool → adopt the measured values. Until that pass completes, `crucible` is a structured harness with defaults, not a tuned release.

## Q3. Won't Ralph Loop run forever?

No. `/verify` caps Ralph Loop retries at `3` ([`thresholds.md` §6](./thresholds.md#6-ralph-loop-retry-cap--3)). When the cap hits, the loop falls through to a manual review instead of generating another candidate. The cap is the same convention `ouroboros` uses upstream, and it exists specifically to prevent `qa-judge` retry bands from turning into infinite critic loops. Raising the cap is a tuning decision we do not take on synthetic evidence.

## Q4. Isn't the promotion gate annoying?

The gate is the whole point — automatic memory writes are the failure mode we designed against. Two mitigations soften it: the `Stop` hook batches pending candidates into a single y/N/e/s prompt at session end, and a detector that is rejected three times in a row auto-disables itself for seven days. If the gate still feels noisy in a real workflow, the first lever to pull is the false-positive rate ([`thresholds.md` §5](./thresholds.md#5-promotion-gate-false-positive-rate---20-)) — a gate that is right more often costs less.

## Q5. How is `/orchestrate` different from calling `/brainstorm → /plan → /verify → /compound` manually?

`/orchestrate` is the same four axes, but it writes a checkpoint to disk after each one (`CP-0 … CP-5`) and each checkpoint is SHA256-pinned in the run log. If the session crashes between CP-2 and CP-3, re-invoking `/orchestrate` resumes from CP-2 — no rework, no silent state divergence. Manual chaining re-runs from scratch on any interruption and has no integrity record. Use the manual chain for exploration; use `/orchestrate` when you are cutting a release.

## Q6. Is Korean trigger parity real, or an MVP claim?

KU-2 measured `Δ_abs = 0.00` across 20 Korean + 20 English synthetic prompts ([`thresholds.md` §4](./thresholds.md#4-description-trigger-accuracy--δko--en--5-)). That is a fixture result, not a production result. The threshold is `≤ 5 %pp`, and if a production drift exceeds it the first corrective action is rewriting the skill `description` — not relaxing the threshold. Korean parity is a monitored property, not a promised one.

## Q7. Can I run this outside Claude Code?

No. `crucible` depends on the Claude Code skill protocol (`SKILL.md` frontmatter, `SessionStart` / `Stop` / `PreToolUse` hooks, `.claude-plugin/plugin.json` layout, `validate_prompt` hook). There is no generic LLM harness equivalent, so porting to another host would mean rebuilding every axis. The runtime requirements (`bash`, `jq`, `uuidgen`, `flock`) are deliberately minimal so that any machine that runs Claude Code already runs `crucible`.

## Q8. What is the smallest change I can make and still be useful?

Run `/verify` against any plan doc already in `.claude/plans/`. You get a `qa-judge` verdict without touching the rest of the pipeline, and the verdict is cheap feedback on whether a plan doc is Evaluator-parseable. This is also the fastest way to dogfood the thresholds — every real `qa-judge` score you capture this way moves the production tuning plan in Q1 one sample forward.

## Q9. What happens if I skip `--acknowledge-risk` on Axis 5?

The invocation is rejected. `--skip-axis 5` alone is not accepted by the harness — there is no `--force`, no env override. The rationale is in [`axes.md`](./axes.md#axis-5-is-different---skip-axis-5-requires---acknowledge-risk): skipping verification is the only axis whose absence looks like a pass from the outside, so the risky path is deliberately harder to type than the safe path. If you genuinely mean to skip Verify (e.g. you already ran `qa-judge` out-of-band), pass both flags and the skip goes into the audit log as `RISK-ACK`.

---

## Known limitations

Three limitations follow from the synthetic-fixture caveat (Q2) and are worth restating once:

1. **Thresholds are defaults, not tuned values.** Until dogfooding produces ≥ 100 real-session logs, all numbers in [`thresholds.md`](./thresholds.md) are MVP defaults.
2. **Oscillation guard is untested in production.** The `overlap ≥ 0.80` within `Gen N-2` rule ([`thresholds.md` §8](./thresholds.md#8-oscillation-guard--overlap--080-within-gen-n-2)) is a design inference; we have no real oscillation data yet.
3. **No drift automation.** `thresholds.md` is the single source but there is no script that flags when a README number drifts out of sync. The check is manual (T-README-11 checklist) and is scheduled for a later sprint.

---

## See also

- [`axes.md`](./axes.md) — the six axes and why each one is non-optional.
- [`thresholds.md`](./thresholds.md) — the numeric source of truth (all numbers in this FAQ link back there).
- `skills/` — per-skill paradigm and design choices.

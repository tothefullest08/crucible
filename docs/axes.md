# 6-Axis Harness

> Why six axes, why this specific matrix, why `--skip-axis 5` needs `--acknowledge-risk`.
> This document is **externally complete** — you do not need to open `final-spec.md` to act on it.

---

## The six axes

`crucible` forces every artifact it emits (requirements, plans, verify reports, compound candidates) through a six-axis loop. Skipping any axis silently is the failure mode the harness is designed to prevent.

| # | Axis | What it enforces | Failure it prevents |
|---|------|------------------|---------------------|
| 1 | **Structure** | Plugin layout, `.claude-plugin/plugin.json` integrity, slash-command registration | A skill that never loads, or loads under the wrong name |
| 2 | **Context** | `SessionStart` hook, `using-harness.md`, `MEMORY.md` injection | Claude Code starting a fresh session with no project memory |
| 3 | **Plan** | Hybrid Markdown + YAML artifacts, acceptance criteria, weighted `evaluation_principles` | Plans that humans can read but `qa-judge` cannot parse |
| 4 | **Execute** | Scoped skills, `validate_prompt` hook, SHA256-pinned payloads in `plugin.json` | A rogue skill body diverging from what the manifest advertises |
| 5 | **Verify** | `qa-judge` scoring, Ralph Loop retries, 3-stage Evaluator | Shipping an unverified artifact under time pressure |
| 6 | **Improve** | `/compound` promotion gate → `tacit/` · `corrections/` · `preferences/` memory | Auto-memory pollution from unapproved learnings |

### Why each axis is non-optional

- **Axis 1 — Structure.** A Claude Code plugin is only real when the manifest resolves. Layout drift (renamed skill, missing `commands/` entry, stale SHA256) is invisible until users hit it at runtime. Gating on Structure at session start catches the break before the first prompt.
- **Axis 2 — Context.** Without `MEMORY.md` injection, every session relearns the project from zero. The hook + index pair is the cheapest durable mechanism we found that survives `/clear` and does not depend on vendor-side memory.
- **Axis 3 — Plan.** `/plan` emits both Markdown (human review) and YAML frontmatter (`acceptance_criteria`, `evaluation_principles`, `exit_conditions`) in a single file so the same artifact is the source of truth for reviewer and Evaluator. Drop the YAML and verification becomes re-interpretation.
- **Axis 4 — Execute.** The SHA256 pin in `plugin.json` is how we detect a skill file that was edited out-of-band. Combined with `validate_prompt`, it blocks a silently mutated skill from running with the old manifest signature.
- **Axis 5 — Verify.** `qa-judge` produces a numeric verdict that drives Ralph Loop retries and the Charter Preflight decision. It is the only axis whose *absence* silently upgrades a draft into a release. That is why it is the only axis whose skip costs an extra flag.
- **Axis 6 — Improve.** Auto-memory plugins pollute context with unreviewed facts. The `/compound` promotion gate is the opposite default: nothing reaches `.claude/memory/` without an explicit y/N/e/s from the user.

---

## Skill × Axis matrix

`ON` = hard gate (the skill will not ship an artifact that fails the axis check).
`log-only` = the axis is *recorded* for later audit but does not block.
`OFF` = the axis is not relevant to this skill class.

| Skill | 1 Structure | 2 Context | 3 Plan | 4 Execute | 5 Verify | 6 Improve |
|-------|:-----------:|:---------:|:------:|:---------:|:--------:|:---------:|
| `/brainstorm`    | log-only | ON | OFF | OFF | OFF | log-only |
| `/plan`          | ON | ON | ON | ON | ON | OFF |
| `/verify`        | ON | ON | ON | ON | ON | OFF |
| `/compound`      | log-only | ON | OFF | ON | OFF | ON |
| `/orchestrate`   | ON | ON | ON | ON | ON | ON |

Notes:

- `/brainstorm` leaves Plan/Execute/Verify OFF because its only output is a *requirements* doc — there is nothing to plan-validate or execute yet. Context is still ON so the session is primed with MEMORY.
- `/compound` flips Plan/Verify OFF because promotion is a decision gate, not a planning or scoring task. Execute stays ON because memory writes must go through the hook-validated path.
- `/orchestrate` is the only skill that lights up all six axes — by construction it chains the other four, so every axis participates at least once.

---

## `--skip-axis N` — the escape hatch

`--skip-axis N` (repeatable) turns a hard gate into `log-only` for a single invocation. Use it when:

- The axis is genuinely not applicable to what you are shipping (e.g. `--skip-axis 6` when the current run is an experiment, not a compound candidate).
- You have already verified the axis out-of-band and do not want a redundant second pass.

Every skip is recorded to `.claude/memory/corrections/skip-log.md`. The log is local-only and never auto-promoted.

### Axis 5 is different: `--skip-axis 5` requires `--acknowledge-risk`

Skipping Verify is the one mistake that looks identical to a pass from the outside. The harness makes it a two-key action on purpose:

```
/plan --skip-axis 5                   # rejected
/plan --skip-axis 5 --acknowledge-risk  # accepted, logged as RISK-ACK
```

The rationale:

1. **No one skips Verify accidentally.** If you truly mean it, one extra flag is cheap. If you do not, the rejection is the correct outcome.
2. **Release auditability.** `RISK-ACK` entries in the skip log are what the `RELEASE-CHECKLIST.md` Hard AC table reviews before a tag. A plain `--skip-axis 5` would blend into routine skips.
3. **Defaults protect the common case.** 95% of the time Verify *should* run. Making the risky path more expensive than the safe path is the whole design.

There is no `--skip-axis 5 --force` or environment override. The flag is the contract.

---

## Terminology

The phrase **하네스 6축** (“harness six axes”) comes from the original lecture framing of Claude Code as a *harness* around the model rather than a wrapper. Each axis is one strap of that harness: remove a strap and the ride gets faster and less safe at the same rate. We keep the Korean phrase in commit messages and release notes because it is shorter than the English phrase and already load-bearing in the team's vocabulary. English readers can treat **6-axis harness** and **하네스 6축** as interchangeable.

---

## See also

- [`thresholds.md`](./thresholds.md) — the numbers each axis enforces (qa-judge 0.80/0.40, Ralph Loop cap, overlap weights).
- [`faq.md`](./faq.md) — why `--skip-axis 5` gates, why synthetic-fixture thresholds are the starting point, not the ending point.
- [`skills/verify.md`](./skills/verify.md) — how Axis 5 actually runs (qa-judge + Ralph Loop + 3-stage Evaluator).

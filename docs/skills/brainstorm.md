# `/brainstorm`

> Clarify a vague feature request into a concrete requirements doc through a 3-lens pass, then stop — do not plan.

English · [한국어](./brainstorm.ko.md)

## Paradigm

`/brainstorm` exists because the most expensive mistake in a Claude Code session is committing to a plan built on an ambiguous prompt. Every lens in the skill interrogates the prompt from a different direction, and the skill refuses to emit a requirements doc until all three have run. The output is deliberately not a plan: it is a `*-requirements.md` file that `/plan` can consume. Separating "what are we building?" from "how do we build it?" is the whole reason `/brainstorm` is its own skill.

## Judgment

Input is free-form user intent (English or Korean). Output is a single file at `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` with a fixed frontmatter schema (`slug`, `type: requirements`, `date`, `source_skill: clarify:vague`, `audience`) and body sections (`Goal` · `Scope {Included / Excluded}` · `Constraints` · `Success Criteria` · `Non-goals` · `Artifacts` · `Open Questions`).

The skill blocks on three gates:

1. **Each lens produces at least one resolved ambiguity.** If a lens cannot find anything to clarify, it explicitly records "no ambiguity on this lens"; silence is not allowed.
2. **Open Questions list is non-empty.** Every requirements doc ships with the handoff to `/plan` that names the decisions the plan phase must make.
3. **Goal line is ≤ 1 sentence.** Enforces a single testable outcome, which is what `/plan`'s Ambiguity Score Gate reads.

## Design Choices

- **3 lenses, not 1.** One lens (pure "vague → concrete") misses strategic blind spots and form-level reframings. Three lenses run cheap and cover more surface than a deeper single pass.
  - `vague` — turns imprecise wording into testable assertions.
  - `unknown` — applies the Known/Unknown 4-quadrant framework to surface hidden assumptions.
  - `metamedium` — asks whether the form (the *how*) should change, not just the content (the *what*).
- **Phases are 1 → 4, not parallel.** Phase 1 collects the raw request, Phase 2 runs lenses, Phase 3 drafts the doc, Phase 4 gates on Open Questions. Parallelising the lenses was tried and produced merge conflicts in the draft; serial is simpler.
- **No plan emission.** The skill deliberately stops at `*-requirements.md`. Attempting to write `plan.md` from `/brainstorm` would collapse the Plan-axis gate from `/plan`.
- **Korean + English trigger parity.** Both "브레인스토밍" and "spec this out" fire the same skill with the same schema. See [`../thresholds.md` §4](../thresholds.md#4-description-trigger-accuracy--δko--en--5-) for the bilingual accuracy bound.
- **Audience is declared.** The frontmatter `audience` field (e.g. `plugin_users_developer_primary`) is what `/plan` uses to scope Success Criteria.

## Thresholds

All bilingual and trigger-accuracy numbers live in [`../thresholds.md`](../thresholds.md):

- Description trigger Δ ≤ 5 %pp — [§4](../thresholds.md#4-description-trigger-accuracy--δko--en--5-).
- `validate_prompt` fire/response rates — [§3](../thresholds.md#3-validate_prompt--fire_rate--099-response_rate--090) (applies to all skills including `/brainstorm`).

## References

- Upstream `p4cn` (plugins-for-claude-natives) — clarify 3-lens pattern and the `requirements.md` schema.
- Upstream `ouroboros` — Ambiguity Gate concept that `/plan` reads from our Open Questions.
- [`../axes.md`](../axes.md) — `/brainstorm`'s axis matrix row (Context ON, Plan/Execute/Verify OFF, Improve log-only).
- [`../../skills/brainstorm/SKILL.md`](../../skills/brainstorm/SKILL.md) — the SKILL contract (frontmatter + hooks).

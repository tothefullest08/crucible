# AGENTS.md — Skill Compliance Checklist

> Enforcement contract for every skill in `crucible`. Paired with [CLAUDE.md](./CLAUDE.md) project guidance.
> All 6 skills must pass their applicable 6-axis checks **before** an artifact leaves `validate_prompt`.

---

## 6-axis compliance checklist

Each axis has a single pass condition. An artifact is compliant when every **ON** axis returns pass for the active skill class (final-spec §3.5.1).

- [ ] **Axis 1 — Structure** · pass when the artifact's destination path matches the skill's declared `output` schema and the plugin manifest (`.claude-plugin/plugin.json`) validates with `jq`.
- [ ] **Axis 2 — Context** · pass when `using-harness.md` was injected at session start and `MEMORY.md` index was consulted before new memory writes.
- [ ] **Axis 3 — Plan** · pass when the plan artifact contains YAML frontmatter with `goal`, `acceptance_criteria`, `evaluation_principles` (weights sum to 1.0 ± 0.05), `exit_conditions`, `parent_seed_id`.
- [ ] **Axis 4 — Execute** · pass when the skill ran through its registered slash command with hook-validated prompts and the payload SHA256 in `plugin.json` matches the on-disk file.
- [ ] **Axis 5 — Verify** · pass when `qa-judge` emits a 5-field JSON (`score`, `verdict`, `dimensions`, `differences`, `suggestions`) with `score ∈ [0.0, 1.0]` and `verdict ∈ {promote, retry, reject}`; Ralph Loop retries ≤ 3.
- [ ] **Axis 6 — Improve** · pass when promoted candidates went through the 6-step gate (candidate → score → verdict → UX → write → log) and user approval was recorded (`y`/`e`/`s` key).

Skipping axis 5 is a **release blocker** unless explicitly acknowledged via `--skip-axis 5 --acknowledge-risk`. Skips are logged to `.claude/memory/corrections/skip-log.md`.

---

## `validate_prompt` hook — per-skill summary

Each `SKILL.md` frontmatter declares a `validate_prompt` block. The `hooks/validate-output.sh` hook reads this block after the skill emits its artifact and runs the 6-axis pass check in shell.

### `/brainstorm` (Plan-axis self-check)

1. Requirements doc contains "user / pain / outcome" triad (Scope / Pain / Outcome).
2. Scope boundaries expressed as `Included` / `Excluded`.
3. Success criteria are measurable.
4. Selected lens (vague / unknown / metamedium) produced its lens-specific artifact.
5. Output path matches `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` with slug in `[a-zA-Z0-9_-]`.
6. Open Questions curated enough for `/plan` to pick up.

### `/plan` (Plan-3-axis self-check · T-W8-05 added)

1. Output path matches `.claude/plans/YYYY-MM-DD-{slug}-plan.md` with slug in `[a-zA-Z0-9_-]`.
2. YAML frontmatter carries `goal`, `acceptance_criteria`, `evaluation_principles` (with weights), `exit_conditions`, `parent_seed_id`.
3. Every task has an ID (`T-W{N}-{NN}` or free-form) and ≥ 1 acceptance criterion.
4. Ambiguity Score Gate (0.2 threshold) verdict stated at top. Failures route back to `/brainstorm`.
5. `evaluation_principles` weights sum to `1.0 ± 0.05`.
6. Exit conditions cover success / abort / retry with measurable rules.

### `/verify` (Verify-axis self-check)

1. `qa-judge` JSON includes the 5 required fields (`score`, `verdict`, `dimensions`, `differences`, `suggestions`).
2. `score` is within `[0.0, 1.0]`.
3. `verdict` is one of `promote` (≥ 0.80), `retry` (0.40–0.80), `reject` (≤ 0.40).
4. Ralph Loop retries did not exceed the configured cap (default 3).
5. Grey-zone auto-consensus stays deferred to v2 — MVP uses manual fallback.
6. Generator and Evaluator ran in separate contexts / fresh sessions.

### `/compound` (Improve-axis self-check · 6-step gate)

1. The three triggers (`pattern_repeat` / `user_correction` / `session_wrap`) are all recognised.
2. Promotion gate follows the v3.3 §3.4 6-step order (candidate → score → verdict → UX → write → log).
3. Response keys `y/N/e/s` default to `N`; prompts only appear at Stop-hook (never mid-session).
4. Memory file frontmatter respects `.claude/memory/README.md` schema (`name`/`description`/`type`/`candidate_id`/`promoted_at`/`evaluator_score`/`source_turn`).
5. Three consecutive rejects of the same pattern disable that detector for 7 days (`disabled_until`).
6. Bug track (`corrections/`) vs Knowledge track (`tacit/`) classification is automatic.

### `/orchestrate` (4-axis integrity self-check · Stretch)

1. Axis order (Brainstorm → Plan → Verify → Compound) is not violated.
2. Each axis records its Mandatory Disk Checkpoint (CP-0~CP-5) into `experiment-log.yaml`.
3. Cursor-bucket UI shows the active axis and progress ratio.
4. `dispatch × work × verify` combinations collapse to one of the 3 allowed modes.
5. Cross-axis artifact hand-off validates SHA256 payload integrity.
6. On failure, the skill halts in-axis; earlier checkpoints are preserved for resume.

### `/dogfood` (Dogfood 4-axis self-check · v1.1.0)

1. The parser attempted extraction of all four structured event types (`skill_call` · `promotion_gate` · `axis_skip` · `qa_judge`) from the current session JSONL.
2. At least one qualitative category (`good` / `pain` / `ambiguous` / `request`) was selected via `AskUserQuestion` multi-select.
3. The local log `.claude/dogfood/log.jsonl` parses line-by-line with `jq .`.
4. When `CRUCIBLE_DOGFOOD_GLOBAL` is unset or != `"0"`, the global mirror at `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` carries identical appended content.
5. `.gitignore` contains `.claude/dogfood/` exactly once (auto-added on first run, idempotent thereafter).
6. Recursion filter — `skill_call` events whose `skill` equals `/crucible:dogfood` are dropped during extraction.

6-axis scope: `/dogfood` emits **hint-level** signals on axis 2 (Context) and axis 6 (Improve). No hard gates — the skill is a user-driven data collector, not a release gate.

---

## Agent handoff protocol

- Upstream axes finish before downstream axes start.
- `experiment-log.yaml` is the only canonical state file between axes.
- Each agent reads the final skill frontmatter for its schema, not inferred defaults.
- Memory writes (axis 6) may only happen after a successful axis 5 pass.

---

*Skill Compliance Checklist v1 · keeps `crucible` agent behaviour honest at each axis boundary.*

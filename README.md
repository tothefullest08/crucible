# crucible

> **crucible compounds only user-approved learnings into durable memory across a six-axis Brainstorm→Plan→Verify→Compound Claude Code loop.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![SPDX](https://img.shields.io/badge/SPDX-MIT-blue.svg)](./LICENSE)
[![DCO](https://img.shields.io/badge/DCO-required-green.svg)](./CONTRIBUTING.md#dco-sign-off-required)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-8A2BE2.svg)](https://claude.com/claude-code)

English · [한국어](./README.ko.md)

---

## Why

Three failure modes repeatedly kill Claude Code sessions. `crucible` refuses to ship past any of them without a user-approved gate.

- **Repeated mistakes** — the same bug gets rediscovered every session because the correction never leaves working memory.
- **Tacit-knowledge evaporation** — project conventions, team decisions, and "that was wrong" moments never get written down.
- **No six-axis meta-loop** — Claude Code plugins typically automate *one* of brainstorm/plan/verify/compound; none enforce all six axes (Structure · Context · Plan · Execute · Verify · Improve) with a hard gate.
- **Auto-memory noise** — plugins that write memory automatically pollute future context with low-signal entries no one curated.
- **Skipped verification** — skipping the Verify axis is usually a one-keystroke mistake; `crucible` makes it a release blocker unless you explicitly acknowledge the risk.

---

## Install

`crucible` is a zero-dependency Claude Code plugin (`bash` + `jq` only). Drop the plugin directory into a Claude Code plugins path and the five slash commands register automatically.

```bash
# Option A — direct copy into Claude Code plugins
cp -r crucible ~/.claude-plugin-crucible

# Option B — clone into a plugins directory
git clone https://github.com/<owner>/crucible.git ~/.claude/plugins/crucible
```

Runtime requirements: `bash` (≥ 4), `jq` (≥ 1.6), `uuidgen`, `flock`. No Python or Node. See [CONTRIBUTING.md](./CONTRIBUTING.md#development-setup) for the full development environment.

---

## Skills (5)

- `/brainstorm` — Feature brainstorming with a 3-lens clarify pass (vague · unknown · metamedium). Emits a requirements doc at `.claude/plans/YYYY-MM-DD-{slug}-requirements.md`.
- `/plan` — Hybrid Markdown + YAML-frontmatter plan built from a requirements doc. Includes acceptance criteria, evaluation principles with weights, and exit conditions.
- `/verify` — Artifact scoring with `qa-judge`, Ralph Loop retries, and Charter Preflight.
- `/compound` — Promotion gate for repeated patterns, user corrections, and session-wrap summaries. Only user-approved candidates reach `.claude/memory/`.
- `/orchestrate` *(Stretch)* — End-to-end pipeline that chains the four skills above with CP-0 through CP-5 disk checkpoints for crash-safe resume.

**Details** → [`docs/skills/`](./docs/skills/) (per-skill paradigm, judgment, design choices).

---

## 6-Axis Harness

Every artifact passes a six-axis gate: **Structure · Context · Plan · Execute · Verify · Improve**. `--skip-axis N` is permitted, but `--skip-axis 5` additionally requires `--acknowledge-risk` — skipping verification is an explicit release blocker.

**Details** → [`docs/axes.md`](./docs/axes.md) (full matrix, skill × axis grid, skip-policy rationale).

---

## Example

**Single-skill call (`/verify` standalone):**

```bash
/verify .claude/plans/2026-04-20-dark-mode-plan.md --axis 5
# → qa-judge report:
#    {"score": 0.86, "verdict": "promote",
#     "dimensions": {"completeness": 0.9, "correctness": 0.85, ...},
#     "differences": [...],
#     "suggestions": [...]}
# → axis 5 PASS, artifact promoted.
```

**Full pipeline (`/orchestrate`):**

```bash
/orchestrate "add dark mode toggle to settings panel"
# → CP-0: brainstorm   → requirements.md
# → CP-1: plan         → plan.md (Markdown + YAML)
# → CP-2: verify       → qa-judge report
# → CP-3: compound     → promotion gate (user y/N/e/s)
# → CP-4: artifact link bundle
# → CP-5: experiment-log.yaml committed
```

If `/orchestrate` crashes between checkpoints, re-invocation resumes from the last CP written to disk — no rework.

**Details** → [`docs/thresholds.md`](./docs/thresholds.md) (verdict bands, retry cap, overlap weights) · [`docs/faq.md`](./docs/faq.md) (why these defaults, synthetic-fixture caveat, production tuning plan).

---

## License

**MIT** — see [LICENSE](./LICENSE). SPDX identifier: `MIT`.

Contributions require a **DCO sign-off** (`git commit -s`). The full workflow and Developer Certificate of Origin v1.1 reference live in [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## Acknowledgments

`crucible` ports and adapts work from six upstream Claude Code projects, all **MIT-licensed** and compatible with our redistribution (commit hashes and sync cadence summarised in `NOTICES.md`):

- **hoyeon** — `validate_prompt` hook pattern, 6-agent verify stack, Korean UX
- **ouroboros** — `qa-judge` JSON schema, Ralph Loop, Seed YAML, Ambiguity Gate
- **p4cn** (plugins-for-claude-natives) — `session-wrap` 2-phase pipeline, clarify 3-lens, `history-insight` parser
- **superpowers** (obra/superpowers) — `SessionStart` hook, `HARD-GATE` tag pattern, 3-stage Evaluator
- **compound-engineering-plugin** — 5-dimensional overlap scoring, Auto Memory conventions, persistence discipline
- **agent-council** — marketplace minimal structure, Wait cursor UX

Full copyright notices in [NOTICES.md](./NOTICES.md).

---

*[한국어 README →](./README.ko.md)*

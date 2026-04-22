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

`crucible` is a zero-dependency Claude Code plugin (`bash` + `jq` only). Install through the Claude Code plugin marketplace in three commands, typed inside any Claude Code session:

```
/plugin marketplace add tothefullest08/crucible
/plugin install crucible@crucible
/reload-plugins
```

After `/reload-plugins`, the six slash commands (`/crucible:brainstorm` · `/crucible:plan` · `/crucible:verify` · `/crucible:compound` · `/crucible:orchestrate` · `/crucible:log`) and the PreToolUse guard hooks are active in the current session. Confirm with:

```
/plugin list         # crucible@crucible should appear under Installed
```

Pick a scope at the interactive prompt:

- **User scope** — available in all your Claude Code sessions (recommended for regular use).
- **Project scope** — committed to `.claude/settings.json`, shared with collaborators on this repo.
- **Local scope** — this repo only, not shared (recommended for trial / dogfood).

Uninstall reverses the same two commands:

```
/plugin uninstall crucible@crucible
/plugin marketplace remove crucible
```

### Local-dev alternative (contributors only)

If you are modifying `crucible` itself, clone the repo and register it as a **local** marketplace instead of fetching from GitHub:

```bash
git clone https://github.com/tothefullest08/crucible.git ~/src/crucible
# then inside Claude Code:
#   /plugin marketplace add ~/src/crucible
#   /plugin install crucible@crucible
```

Runtime requirements: `bash` (≥ 4), `jq` (≥ 1.6), `uuidgen`, `flock`. No Python or Node. See [CONTRIBUTING.md](./CONTRIBUTING.md#development-setup) for the full development environment.

---

## Skills (6)

- `/brainstorm` — Feature brainstorming with a 3-lens clarify pass (vague · unknown · metamedium). Emits a requirements doc at `.claude/plans/YYYY-MM-DD-{slug}-requirements.md`.
- `/plan` — Hybrid Markdown + YAML-frontmatter plan built from a requirements doc. Includes acceptance criteria, evaluation principles with weights, and exit conditions.
- `/verify` — Artifact scoring with `qa-judge`, Ralph Loop retries, and Charter Preflight.
- `/compound` — Promotion gate for repeated patterns, user corrections, and session-wrap summaries. Only user-approved candidates reach `.claude/memory/`.
- `/orchestrate` *(Stretch)* — End-to-end pipeline that chains the four skills above with CP-0 through CP-5 disk checkpoints for crash-safe resume.
- `/log` — Manual dogfooding logger. Captures qualitative notes (4 categories: good · pain · ambiguous · request) plus auto-extracted structured events (skill_call · promotion_gate · axis_skip · qa_judge) to append-only JSONL at `.claude/dogfood/log.jsonl` (local) and `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` (opt-in global mirror). `.gitignore` is auto-updated; opt-out via `CRUCIBLE_DOGFOOD_GLOBAL=0`.

**Details** → [`docs/skills/`](./docs/skills/) (per-skill paradigm, judgment, design choices).

---

## 6-Axis Harness

Every artifact passes a six-axis gate: **Structure · Context · Plan · Execute · Verify · Improve**. `--skip-axis N` is permitted, but `--skip-axis 5` additionally requires `--acknowledge-risk` — skipping verification is an explicit release blocker.

**Details** → [`docs/axes.md`](./docs/axes.md) (full matrix, skill × axis grid, skip-policy rationale).

---

## Example

All slash commands use the `crucible:` namespace once the plugin is installed (see Install). Claude Code can resolve them without the prefix when the name is unambiguous, but the explicit form is always safe.

**Single-skill call (`/crucible:verify` standalone):**

```
/crucible:verify .claude/plans/2026-04-20-dark-mode-plan.md --axis 5
# → qa-judge report:
#    {"score": 0.86, "verdict": "promote",
#     "dimensions": {"completeness": 0.9, "correctness": 0.85, ...},
#     "differences": [...],
#     "suggestions": [...]}
# → axis 5 PASS, artifact promoted.
```

**Full pipeline (`/crucible:orchestrate`):**

```
/crucible:orchestrate "add dark mode toggle to settings panel"
# → CP-0: brainstorm   → requirements.md
# → CP-1: plan         → plan.md (Markdown + YAML)
# → CP-2: verify       → qa-judge report
# → CP-3: compound     → promotion gate (user y/N/e/s)
# → CP-4: artifact link bundle
# → CP-5: experiment-log.yaml committed
```

If `/crucible:orchestrate` crashes between checkpoints, re-invocation resumes from the last CP written to disk — no rework.

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

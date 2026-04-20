# crucible — CLAUDE.md

> Project-level guidance for Claude Code agents working in this repository.
> For Skill Compliance Checklists (6-axis + `validate_prompt`), see [AGENTS.md](./AGENTS.md).

---

## Project header

- **Project**: `crucible` — a Claude Code plugin that compounds user-approved learnings into durable memory.
- **Position**: crucible compounds only user-approved learnings into durable memory across a six-axis Brainstorm→Plan→Verify→Compound Claude Code loop.
- **Runtime**: `bash` (≥ 4), `jq` (≥ 1.6), `uuidgen`, `flock`. **Python and Node are prohibited** (final-spec §4.1).
- **Canonical spec**: internal dev doc (not distributed; see the development mirror) — v3.4, §3.5 · §4.5 · §11-5/6/7 locked.
- **Implementation plan**: internal dev doc (not distributed; see the development mirror) — §W0–§W8 + §W7.5.
- **License**: MIT (SPDX `MIT`) · DCO sign-off required on every commit.

---

## 6-axis compliance rules

Every artifact Claude emits must pass the axis checks relevant to its skill class (final-spec §3.5):

| Axis | # | Enforcement |
|------|---|-------------|
| Structure | 1 | Plugin layout, `.claude-plugin/plugin.json` integrity, slash-command registration |
| Context | 2 | `SessionStart` hook + `using-harness.md` + `MEMORY.md` index present |
| Plan | 3 | Hybrid Markdown + YAML artifacts with acceptance criteria and weighted evaluation principles |
| Execute | 4 | Scoped skills, hook-validated prompts, SHA256-pinned payloads in `plugin.json` |
| Verify | 5 | `qa-judge` scoring (promote ≥ 0.80, retry 0.40–0.80, reject ≤ 0.40), Ralph Loop retries |
| Improve | 6 | `/compound` promotion gate; memory writes require explicit user approval |

Enforcement per skill:

- `/plan`, `/verify`, `/orchestrate` → axes **ON** (hard gate via `validate_prompt`).
- `/brainstorm`, `/compound` → natural dialogue with axis logging only.
- General Q&A and tool-only calls → **OFF**.

Escape hatch `--skip-axis N` is permitted. **Skipping axis 5 requires `--acknowledge-risk`** and is logged to `.claude/memory/corrections/skip-log.md`.

---

## 5 skills — usage summary

| Skill | Trigger | Input | Output |
|-------|---------|-------|--------|
| [`/brainstorm`](./skills/brainstorm/SKILL.md) | "브레인스토밍", "spec this out" | Free-form topic | `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` |
| [`/plan`](./skills/plan/SKILL.md) | "plan this", "계획 세워줘" | requirements.md path | `.claude/plans/YYYY-MM-DD-{slug}-plan.md` |
| [`/verify`](./skills/verify/SKILL.md) | "verify", "검증해줘" | Artifact path `[--axis N]` | `qa-judge` JSON report |
| [`/compound`](./skills/compound/SKILL.md) | "compound", pattern_repeat, `/session-wrap` | Candidate queue | `.claude/memory/{tacit,corrections,preferences}/*.md` |
| [`/orchestrate`](./skills/orchestrate/SKILL.md) *(Stretch)* | "orchestrate", "4축 파이프라인" | Topic prompt | 4-axis pipeline + CP-0~CP-5 checkpoints |

Detailed `SKILL.md` frontmatter (6 fields × 5 skills) is audited in final-spec §11-7.1.

---

## Coding and commit conventions

- **Immutability first**: new objects over in-place mutation (global coding-style rule).
- **Many small files**: 200–400 lines typical, 800 max. High cohesion, low coupling.
- **TDD**: RED → GREEN → REFACTOR, ≥ 80 % coverage (project-wide testing rule).
- **Shell only**: `bash` + `jq` + `yq` + `uuidgen`. No Python, no Node (final-spec §4.1).
- **Commit format**: Conventional Commits (`feat:`, `fix:`, etc.) with `Signed-off-by:` trailer (DCO).
- **Secrets**: never commit `.env`, credentials, or secrets (global security rule).

Full workflow and validation steps live in [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## Pointers

- **[AGENTS.md](./AGENTS.md)** — Skill Compliance Checklist (6-axis + `validate_prompt` for each skill).
- **[NOTICES.md](./NOTICES.md)** — Upstream copyright notices (6 MIT-licensed sources).
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** — DCO sign-off procedure, PR checklist, development setup.
- **[RELEASE-CHECKLIST.md](./RELEASE-CHECKLIST.md)** — W8 release criteria, Hard AC judgment table.
- **[LICENSE](./LICENSE)** — MIT license text.

---

## When asked to work on this repo

1. Read the user's request and identify which skill class applies (`/plan`, `/verify`, etc.).
2. Confirm which axes are **ON** for that class (§3.5.1 summary table above).
3. If the task crosses final-spec §3.5/§4.5/§11 boundaries, update the spec *first*, then implement.
4. Keep edits minimal. Do not refactor out of scope. Do not add features the task did not ask for.
5. On commit: `git commit -s` (DCO). On push: follow `_git-workflow-template.md` for rebase-first policy.

---

## Non-goals

- Python/Node dependencies (permanent exclusion — final-spec §9.1).
- Automatic memory writes without user approval (contradicts `/compound` gate).
- Cross-project memory leakage (`~/.claude/memory/` is **off by default** — §4.3.4).
- Breaking any of the 8 Hard AC listed in [RELEASE-CHECKLIST.md](./RELEASE-CHECKLIST.md).

---

*Spec v3.4 · W8 release prep · MIT · DCO enforced.*

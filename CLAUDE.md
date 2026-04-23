# crucible — CLAUDE.md

> Project-level guidance for Claude Code agents working in this repository.
> For Skill Compliance Checklists (6-axis + `validate_prompt`), see [AGENTS.md](./AGENTS.md).

---

## Project header

- **Project**: `crucible` — a Claude Code plugin that compounds user-approved learnings into durable memory.
- **Position**: crucible compounds only user-approved learnings into durable memory across a six-axis Brainstorm→Plan→Verify→Compound Claude Code loop.
- **Runtime**: `bash` (≥ 4), `jq` (≥ 1.6), `uuidgen`, `flock`. **Python and Node are prohibited** (see Non-goals).
- **Authoritative references**: per-skill compliance → [AGENTS.md](./AGENTS.md) · release criteria → [RELEASE-CHECKLIST.md](./RELEASE-CHECKLIST.md) · project guardrails → [.claude/rules/project-guardrails.md](./.claude/rules/project-guardrails.md) · non-goals → bottom of this file.
- **License**: MIT (SPDX `MIT`) · DCO sign-off required on every commit.

---

## 6-axis compliance rules

Every artifact Claude emits must pass the axis checks relevant to its skill class. Per-skill enforcement detail lives in [AGENTS.md](./AGENTS.md).

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

## 7 skills — usage summary

| Skill | Trigger | Input | Output |
|-------|---------|-------|--------|
| [`/brainstorm`](./skills/brainstorm/SKILL.md) | "브레인스토밍", "spec this out" | Free-form topic | `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` |
| [`/plan`](./skills/plan/SKILL.md) | "plan this", "계획 세워줘" | requirements.md path | `.claude/plans/YYYY-MM-DD-{slug}-plan.md` |
| [`/verify`](./skills/verify/SKILL.md) | "verify", "검증해줘" | Artifact path `[--axis N]` | `qa-judge` JSON report |
| [`/compound`](./skills/compound/SKILL.md) | "compound", pattern_repeat, `/session-wrap` | Candidate queue | `.claude/memory/{tacit,corrections,preferences}/*.md` |
| [`/orchestrate`](./skills/orchestrate/SKILL.md) *(Stretch)* | "orchestrate", "4축 파이프라인" | Topic prompt | 4-axis pipeline + CP-0~CP-5 checkpoints |
| [`/dogfood`](./skills/dogfood/SKILL.md) | "dogfood", "도그푸드", "/crucible:dogfood" | Current session JSONL + 4-cat note | `.claude/dogfood/log.jsonl` (+ opt-in global mirror) |
| [`/dogfood-digest`](./skills/dogfood-digest/SKILL.md) | "dogfood digest", "도그푸드 리포트" | dogfood JSONL + window flags | `.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md` |

Per-skill `SKILL.md` frontmatter (6 fields × 7 skills) is audited via the checklist in [AGENTS.md](./AGENTS.md).

---

## Coding and commit conventions

- **Immutability first**: new objects over in-place mutation (global coding-style rule).
- **Many small files**: 200–400 lines typical, 800 max. High cohesion, low coupling.
- **TDD**: RED → GREEN → REFACTOR, ≥ 80 % coverage (project-wide testing rule).
- **Shell only**: `bash` + `jq` + `yq` + `uuidgen`. No Python, no Node (see Non-goals).
- **Commit format**: Conventional Commits (`feat:`, `fix:`, etc.) with `Signed-off-by:` trailer (DCO).
- **Secrets**: never commit `.env`, credentials, or secrets (enforced by `hooks/pretool-block-secrets.sh`).

Full workflow and validation steps live in [CONTRIBUTING.md](./CONTRIBUTING.md). Project-local guardrails (memory gate, axis skip policy, file policy) live in [.claude/rules/project-guardrails.md](./.claude/rules/project-guardrails.md).

---

## Pointers

- **[AGENTS.md](./AGENTS.md)** — Skill Compliance Checklist (6-axis + `validate_prompt` for each skill).
- **[NOTICES.md](./NOTICES.md)** — Upstream copyright notices (6 MIT-licensed sources).
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** — DCO sign-off procedure, PR checklist, development setup.
- **[RELEASE-CHECKLIST.md](./RELEASE-CHECKLIST.md)** — W8 release criteria, Hard AC judgment table.
- **[.claude/rules/project-guardrails.md](./.claude/rules/project-guardrails.md)** — project-local guardrails (runtime, memory gate, axis skip, file policy).
- **[LICENSE](./LICENSE)** — MIT license text.

---

## When asked to work on this repo

1. Read the user's request and identify which skill class applies (`/plan`, `/verify`, etc.).
2. Confirm which axes are **ON** for that class (see the summary table above).
3. If the task crosses axis rules, `SKILL.md` contracts, or release AC, update [AGENTS.md](./AGENTS.md) or [RELEASE-CHECKLIST.md](./RELEASE-CHECKLIST.md) *first*, then implement.
4. Keep edits minimal. Do not refactor out of scope. Do not add features the task did not ask for.
5. On commit: `git commit -s` (DCO). On push: rebase-first policy (see [CONTRIBUTING.md](./CONTRIBUTING.md)).

---

## Non-goals

- Python/Node dependencies (permanent exclusion).
- Automatic memory writes without user approval (contradicts `/compound` gate).
- Cross-project memory leakage (`~/.claude/memory/` is **off by default**).
- Breaking any of the 8 Hard AC listed in [RELEASE-CHECKLIST.md](./RELEASE-CHECKLIST.md).

---

*MIT · DCO enforced.*

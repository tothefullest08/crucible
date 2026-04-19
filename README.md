# harness

> **harness is a Claude Code plugin for developers who keep repeating the same mistakes session after session and watching their tacit knowledge evaporate — it accumulates personalized compounding memory through promotion gates and a six-axis verification loop. Unlike existing plugins like CE or hoyeon, only learnings that pass a user-approval gate are persisted.**
>
> **(한국어)** harness는 Claude Code로 반복 작업하는 개발자가 세션마다 같은 실수를 반복하고 암묵지가 휘발하는 문제를 해결하고 싶을 때, 승격 게이트와 6축 검증 루프로 개인화된 컴파운딩 메모리를 누적하는 플러그인이다. 기존 CE·hoyeon과는 "유저 승인 게이트를 통과한 학습만 영속 저장한다"는 점에서 구별된다.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Status: WIP](https://img.shields.io/badge/Status-Work%20In%20Progress-orange.svg)](#status)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-8A2BE2.svg)](https://claude.com/claude-code)
[![DCO](https://img.shields.io/badge/DCO-required-green.svg)](./.github/DCO.md)

English · [한국어](./README.ko.md) *(planned)*

---

## Overview

**harness** is a `.claude-plugin/` that structurally enforces the *six harness axes* — **Structure · Context · Plan · Execute · Verify · Improve** — across your Claude Code sessions. It combines a skeptical Evaluator loop with a promotion gate so that only **user-approved** learnings become persistent memory.

Where existing tooling either writes memory automatically (lossy, noisy) or skips verification entirely (drift, hallucination), harness insists every compounding decision pass through a human gate. The result is a lean, personalized knowledge base that compounds across sessions instead of decaying.

---

## Features

### The Six Harness Axes

| # | Axis | What it enforces |
|---|------|------------------|
| 1 | **Structure** | Plugin layout, manifest integrity, slash-command registration |
| 2 | **Context** | Session-bootstrapped `using-harness` guidance + memory index |
| 3 | **Plan** | Hybrid artifacts (Markdown body + YAML frontmatter) for both humans and Evaluators |
| 4 | **Execute** | Scoped skills, hook-validated prompts, isolated work |
| 5 | **Verify** | `qa-judge` scoring · Ralph Loop retries · grey-zone Consensus (v2) |
| 6 | **Improve** | `/compound` promotion gate → tacit / corrections / preferences memory |

Enforcement scope: `/plan`, `/verify`, and `/orchestrate` run with axes **ON by default**. `--skip-axis N` is permitted, but skipping the Verify axis (#5) triggers a hard warning.

### Three Core Mechanics

1. **Tacit-Knowledge Surfacing** — conversation-first elicitation plus a dedicated `corrections/` store for "that was wrong" moments. What you implicitly know gets written down once, not re-derived every session.
2. **Result Verification Loop** — every significant artifact is scored by a skeptical Evaluator running in a fresh context. Grey-zone outputs (0.40–0.80) trigger auto-retry; failures flow into the Ralph Loop.
3. **Compounding Memory** — hybrid triggers (3-time repetition detection · explicit "틀렸다" / "that was wrong" · `/session-wrap`) feed a six-step promotion gate. Nothing hits `.claude/memory/` without your approval.

### Memory Layout

```
.claude/memory/                # project-local by default
├── MEMORY.md                  # lightweight index (≤200 lines, loaded every session)
├── tacit/                     # surfaced implicit knowledge
├── corrections/               # "that was wrong" entries, dated
└── preferences/               # stable user/team preferences
```

Global memory (`~/.claude/memory/`) is **off by default** and must be explicitly opted in — this keeps cross-project leakage out of the loop.

---

## Installation

> ⚠️ **Work In Progress.** Official Claude Code marketplace distribution is planned for **W8** (see [Status](#status)). The commands below are the target install paths.

### Claude Code marketplace *(planned, W8)*

```bash
# Not yet available — this is the target surface
/plugin install harness@claude-plugins-official
```

### Local development install *(current path)*

```bash
# Clone
git clone https://github.com/<owner>/harness.git
cd harness

# Link as a local Claude Code plugin
# (exact linking command will be finalized in W8 install docs)
```

Requirements: `bash`, `jq`, Claude Code CLI. See [CONTRIBUTING.md](./CONTRIBUTING.md#development-setup) for full dev setup.

---

## Usage

Five slash commands drive the full loop. Each has its own skill under `skills/`; run the detailed walkthrough via `skills/using-harness`.

| Command | One-liner |
|---------|-----------|
| `/brainstorm [topic]` | Clarify vague intent with a 3-lens (vague · unknown · metamedium) pass and emit a requirements doc |
| `/plan [requirements.md]` | Produce a hybrid plan — Markdown body plus YAML frontmatter that the Evaluator can parse |
| `/verify [artifact] [--axis N]` | Score an artifact with `qa-judge`, decide promote / retry / reject, and run the Ralph Loop when needed |
| `/compound` | Manual or trigger-driven promotion gate: verify → user approval → write to `tacit` / `corrections` / `preferences` |
| `/orchestrate [topic]` | *(Stretch, W8 target)* Run the four internal skills end-to-end as a pipeline |

For the full axis-by-axis walkthrough, invoke `skills/using-harness` once the plugin is loaded.

### Typical flow

```
/brainstorm "add dark mode"
        │
        ▼   requirements.md
/plan requirements.md
        │
        ▼   plan.md (Markdown + YAML frontmatter)
/verify plan.md
        │
        ▼   qa-judge report — promote / retry / reject
/compound                       ← user-approval gate before memory write
        │
        ▼   .claude/memory/{tacit|corrections|preferences}/*.md
```

---

## Status

**Work In Progress — Phase 4 complete, W1 implementation in progress.**

| Milestone | State |
|-----------|-------|
| Phase 0–3 (design, research, spec v3.1) | ✅ Complete (see `.claude/plans/INDEX.md`) |
| Phase 4 (implementation plan) | ✅ Complete |
| **W1** — core skills scaffold | 🟡 In progress |
| W2–W7 — verify · compound · orchestrate | 🔲 Planned |
| **W8** — marketplace distribution + docs | 🔲 Target release |

Spec v3.1 is the single source of truth: `.claude/plans/03-design/final-spec.md`. Open questions live in §11; promoted items are tracked in `04-planning/section11-promotion-tracker.md`.

---

## Reference / Credits

harness is built on top of prior work from the Claude Code ecosystem. All six upstream sources are **MIT-licensed** (verified 2026-04-19) and compatible with our redistribution:

- [Compound Engineering plugin](./references/compound-engineering-plugin/) — 5-dimensional overlap model, Auto Memory conventions
- [hoyeon](./references/hoyeon/) — `validate_prompt` hook patterns, 6-agent verify stack, Korean UX patterns
- [superpowers](./references/superpowers/) — `SessionStart` hook, `HARD-GATE` tags, 3-stage Evaluator design
- [ouroboros](./references/ouroboros/) — `qa-judge` JSON schema, Ralph Loop pseudocode, Seed YAML
- `p4cn` — `session-wrap` 2-phase flow, `history-insight` JSONL parsing, clarify patterns
- `agent-council` — marketplace structure, Wait cursor UX

Copyright notices for all upstream works will ship in `NOTICES.md` at W8. Porting lineage is tracked per-asset in [`.claude/plans/04-planning/porting-matrix.md`](./.claude/plans/04-planning/porting-matrix.md).

---

## License

[MIT](./LICENSE) © 2026 Ethan

Contributions require a **DCO sign-off** (`git commit -s`). See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full workflow and [.github/DCO.md](./.github/DCO.md) for the Developer Certificate of Origin v1.1 text.

---

## Korean version

A Korean-language README ([`README.ko.md`](./README.ko.md)) is planned as a later addition — the upstream reference hoyeon ships parallel locales and harness intends to match that pattern. English remains the primary doc per OSS convention.

---
name: brainstorm
description: "요구사항 브레인스토밍 / Feature brainstorming — clarify 3-lens 내장"
when_to_use: "모호한 요구사항을 구체 스펙으로 정제할 때. 'brainstorm', '브레인스토밍', '요구사항 정리', 'spec this out' 등"
input: "주제 (자유 발화)"
output: ".claude/plans/YYYY-MM-DD-{slug}-requirements.md (slug 화이트리스트: [a-zA-Z0-9_-])"
---

# Brainstorm

Turn a vague topic into a concrete, file-backed requirements document. The skill embeds three clarification lenses (vague · unknown · metamedium) so a single entry point covers the common modes of pre-planning thinking.

> 6-axis activation: this skill emits **hint-level** signals on axes 1 (Structure), 2 (Context), and 3 (Plan). It does NOT emit hard gates. See `using-harness/SKILL.md` §5 for the full matrix.

---

## When to Use

Trigger when any of the following hold:

- The user describes a feature/idea that is too ambiguous to plan directly ("add a login feature", "make X faster").
- The user asks to "brainstorm", "spec this out", "scope this", "요구사항 정리", "브레인스토밍".
- The user has a strategy or plan and wants blind-spot analysis ("what am I missing?", "blind spots", "전략 점검").
- The user is stuck optimizing content with diminishing returns and may need a form/medium shift ("새로운 포맷", "관점 전환", "diminishing returns").

Do **not** use when:

- The requirement is already concrete and what is needed is decomposition into tasks → use `/plan`.
- An artifact already exists and the user wants to confirm it meets a spec → use `/verify`.
- The user just asked a one-shot question with no follow-on work.

---

## Protocol

### Phase 1: Intake

Capture the topic verbatim. Do not paraphrase yet.

1. Echo the user's topic in a single quoted line so the user can confirm framing.
2. Identify three things in plain text (≤ 3 bullets total):
   - The unit being discussed (feature / strategy / process / artifact).
   - The mode the user is in (exploring / committing / debugging diminishing returns).
   - The known constraints already mentioned (deadline, audience, stack, scope cap).
3. Do **not** ask clarifying questions yet — Phase 2 owns all questioning via `AskUserQuestion`.

If the topic is a single keyword with no surrounding context, proceed to Phase 2 with a deliberately rough framing — Round 1 questions exist to correct it.

---

### Phase 2: Clarify (3-lens)

This phase contains the embedded clarify protocol. Always use the `AskUserQuestion` tool — never ask clarifying questions in plain text. Each option you present is a hypothesis; the user's job is to confirm, correct, or surprise.

#### Phase 2.1 — Lens auto-selection (≤ 100 words)

Pick exactly one lens based on the topic and trigger keywords:

| Lens | Use when | Trigger keywords |
|------|----------|------------------|
| **vague** | The requirement itself is ambiguous and must become a concrete spec. | `clarify`, `요구사항 명확히`, `요구사항 정리`, `spec this out`, `scope`, `make this clearer` |
| **unknown** | A strategy/plan exists and hidden assumptions / blind spots are the risk. | `known unknown`, `blind spots`, `뭘 모르는지`, `가정 점검`, `전략 점검`, `assumption check`, `quadrant analysis` |
| **metamedium** | The question is "optimize content" vs "change form/medium" — content edits show diminishing returns. | `내용 vs 형식`, `metamedium`, `새로운 포맷`, `관점 전환`, `perspective shift`, `diminishing returns` |

If two or more lenses match, present a single `AskUserQuestion` call asking the user to pick one before continuing. Never run two lenses in parallel — that doubles the question budget and produces conflicting outputs.

If no lens clearly matches, default to **vague** — the safer choice for early-stage requirements.

#### Phase 2.2 — 3-Round depth pattern (shared across all lenses)

| Round | Purpose | Question count | Trait |
|-------|---------|----------------|-------|
| **R1** | Broad sweep — validate the rough framing. | 3–4 | Covers all major hypothesis space; batched in a single `AskUserQuestion` call. |
| **R2** | Drill into the weak spot R1 surfaced. | 2–3 | Designed *from* R1 answers. Never pre-prepared. |
| **R3** | Nail execution detail. | 2–3 | Optional. Skip if R2 already answers it. |

Hard cap: **7–10 questions total across all rounds**. Beyond this is fatigue. If you reach the cap with open questions remaining, write them into the output as `Open Questions` rather than asking more.

Critical rules:

- Generate Round N questions *from* Round N-1 answers. Pre-prepared multi-round scripts are performative and produce shallower insight.
- Use `multiSelect: true` only when compound causes are plausible (R2 weak-spot drill is the typical case).
- Always include "Other" as an option for out-of-frame answers.
- Each option is one phrase + one sentence of description. Five+ options per question causes choice fatigue — cap at 4.

#### Phase 2.3 — Lens-specific guidance

##### Lens A — vague (requirement clarification)

Goal: turn ambiguity into a concrete, decision-backed spec.

R1 question pattern (batch all 3–4 in one call):

```yaml
questions:
  - question: "Which authentication method should the login use?"
    header: "Auth method"
    options:
      - label: "Email + Password"
        description: "Traditional signup with email verification"
      - label: "OAuth (Google/GitHub)"
        description: "Delegated auth, no password management needed"
      - label: "Magic link"
        description: "Passwordless email-based login"
      - label: "Other"
        description: "None of the above"
    multiSelect: false
  - question: "What should happen after registration?"
    header: "Post-signup"
    options:
      - label: "Immediate access"
        description: "User can use the app right away"
      - label: "Email verification first"
        description: "Must confirm email before access"
      - label: "Other"
        description: "None of the above"
    multiSelect: false
```

Ambiguity categories to scan when designing R1 options:

| Category | Example hypotheses |
|----------|-------------------|
| Scope | All users / Admins only / Specific roles |
| Behavior | Fail silently / Show error / Auto-retry |
| Interface | REST API / GraphQL / CLI |
| Data | JSON / CSV / Both |
| Constraints | < 100 ms / < 1 s / No requirement |
| Priority | Must-have / Nice-to-have / Future |

R2: drill into whichever R1 answer was "Other" or revealed a contradiction.
R3 (optional): execution details (where the file lives, who owns it, when it ships).

Output: refined requirement with a `Decisions Made` table mapping each ambiguity to its chosen option.

##### Lens B — unknown (strategy blind-spot analysis)

Goal: surface what the user doesn't realize they don't know, using the Known/Unknown 4-quadrant framework.

R1 question pattern (batch all 3–4):

| Target | Question pattern | Example |
|--------|-----------------|---------|
| KK (Known Knowns) | "Is this really certain?" | "Primary revenue source?" with 3–4 hypotheses |
| KU (Known Unknowns) | "Where is the weakest link?" | "Which connection is weakest?" multiSelect |
| UK (Unknown Knowns) | "What asset exists but isn't used?" | Options derived from project context (CLAUDE.md, past artifacts) |
| UU (Unknown Unknowns) | "What is the biggest fear?" | Risk scenarios as options |

Before R1, glob for project context (`CLAUDE.md`, `README*`, `.claude/plans/*`, prior decision records) so UK options are grounded in real assets.

R2: drill the weakest area R1 exposed — typically a compound answer or an "Other" selection.
R3 (optional): execution details for the top KU/UK items.

Output structure:

```
# {Topic}: Known/Unknown Quadrant Analysis

## Current State Diagnosis
## Quadrant Matrix (ASCII with resource %)
## 1. Known Knowns: Systematize (~60%)
## 2. Known Unknowns: Design Experiments (~25%)
   - Each KU: Diagnosis → Experiment → Success Criteria → Deadline → Promotion Condition
## 3. Unknown Knowns: Leverage (~10%)
## 4. Unknown Unknowns: Set Up Antennas (~5%)
## Strategic Decision: What to Stop
## Execution Roadmap (week-by-week)
## Core Principles (3–5 decision criteria)
```

The 60/25/10/5 split is a default. Adjust based on context — a startup exploring product-market fit may shift to 40 % KU and 30 % KK. The **"Stop Doing"** section is mandatory: adding without subtracting is the most common failure mode.

##### Lens C — metamedium (content vs form)

Goal: decide whether the leverage is in optimizing content (what is being said/built) or inventing a new form (the medium itself). Based on Alan Kay's metamedium concept.

Phase 1 of this lens: classify each component of the user's current work as `[CONTENT]` or `[FORM]` in 3–5 lines.

R1 (single fork question):

```yaml
questions:
  - question: "This is currently [CONTENT/FORM]-level work. Where should effort go?"
    header: "Level"
    options:
      - label: "Proceed with content"
        description: "Optimize within the current form — faster, lower risk"
      - label: "Explore form change"
        description: "Change the medium/structure itself — higher leverage"
      - label: "Content now, note form"
        description: "Do the content work, but flag the form opportunity for later"
    multiSelect: false
```

R2 branch on R1 answer:

- **Proceed with content** → produce the content-level requirement, append a `Form Opportunity` note for future use.
- **Explore form change** → generate 2–3 form alternatives. For each: what the new form looks like concretely, what new properties it would have (automatic / repeatable / scalable / composable), the minimum viable version to test it.
- **Content now, note form** → proceed with content, append the form opportunity to the output.

R3 is rarely needed for this lens — R2 alternatives usually contain enough execution detail.

The metamedium question to keep in mind throughout: **"What new form/medium could make this problem disappear?"**

#### Phase 2.4 — Output schema

All three lenses produce a Markdown file at `.claude/plans/YYYY-MM-DD-{slug}-requirements.md` with a YAML frontmatter and a Markdown body. Slug must match `[a-zA-Z0-9_-]` only (validated via `templates/slug-validator.sh`, owned by panel B / T-W2-04).

Common frontmatter:

```yaml
---
lens: vague | unknown | metamedium
topic: <user topic verbatim>
date: YYYY-MM-DD
decisions:
  - question: <ambiguity addressed>
    decision: <chosen option>
    reasoning: <one-line why>
stop_doing: []   # required for unknown lens; optional for vague/metamedium
open_questions: []  # any R3+ items that hit the question cap
---
```

Body sections per lens:

- **vague** → `Goal` · `Scope` · `Constraints` · `Success Criteria` · `Decisions Made` table · `Before / After`.
- **unknown** → the 4-quadrant playbook structure listed in Lens B above.
- **metamedium** → `Classification` · `Form Opportunity` table · (if "Explore form change") `Alternative Forms`.

The exact body templates live in `templates/requirements-template.md` (panel B / T-W2-04). This SKILL.md is responsible only for telling the lens which template variant to render.

---

### Phase 3: Synthesize

After Phase 2 finishes, draft a **Before / After** summary in plain Markdown for the user to review *before* writing to disk.

```markdown
## Brainstorm Summary

### Before (Original)
"{user topic verbatim}"

### After (Clarified, lens=<lens>)
**Goal**: ...
**Scope (in / out)**: ...
**Decisions Made**: <count> (see file for table)
**Open Questions**: <count, 0 if all resolved>
**Stop Doing**: <count, only for unknown lens>
```

If the user pushes back on the framing, re-run the smallest applicable subset of Phase 2 (typically R2 only) before proceeding to Phase 4. Do not silently rewrite — surface the change.

---

### Phase 4: Save Requirements

1. Compute `slug` from the user-confirmed goal: lowercase, spaces → `-`, strip non-`[a-zA-Z0-9_-]`.
2. Validate slug via `templates/slug-validator.sh` (panel B). Reject and re-derive if validation fails — never write to disk with an unvalidated slug.
3. Compute `date` as `YYYY-MM-DD` from the system date.
4. Render the body using the lens-appropriate variant of `templates/requirements-template.md`.
5. Write to `.claude/plans/{date}-{slug}-requirements.md`.
6. Echo the absolute path back to the user as the final line of the response.

If the file already exists, prompt the user to choose: overwrite, append a `-v2` suffix, or abort. Never silently overwrite.

---

## Integration Points

- **Upstream**: SessionStart hook (`hooks/session-start.sh`) injects `using-harness/SKILL.md`, which lists `/brainstorm` as the entry point for the Plan axis when requirements are vague.
- **Downstream**: The output file (`.claude/plans/YYYY-MM-DD-{slug}-requirements.md`) is the canonical input for `/plan` (W3). `/plan` reads the YAML frontmatter to compute its Ambiguity Score gate.
- **Self-validation** (added in T-W2-05): a `validate_prompt` frontmatter field will trigger a PostToolUse re-injection if the lens's mandatory sections are missing from the output.
- **Hard gate placement** (added in T-W2-10): HARD-GATE markers will be placed at the Phase 1→2 and Phase 3→4 transitions to enforce the structure → context → plan progression.

---

## Notes

- Korean-first explanations are acceptable in user-facing dialogue, but the file body and frontmatter remain English-primary for OSS interoperability. See `using-harness/SKILL.md` §6 for the bilingual UX policy.
- This skill never writes outside `.claude/plans/`. Memory writes (`.claude/memory/...`) are reserved for `/compound`.
- The skill uses only `bash + jq` for any auxiliary scripting (slug validator, file writing). No Python or Node dependencies — see final-spec §4.1.

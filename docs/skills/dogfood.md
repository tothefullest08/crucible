# `/dogfood` *(v1.1.0)*

> Capture per-session crucible feedback as append-only JSONL — qualitative notes across four fixed categories plus four auto-extracted structured events — to a local log and an opt-in global mirror.

English · [한국어](./dogfood.ko.md)

## Paradigm

`/dogfood` is the only skill whose job is to collect evidence about the other skills. The failure mode it prevents is the one every self-improving system eventually runs into: the thresholds in `docs/thresholds.md` were hand-authored from synthetic fixtures, so production-grade tuning requires real usage data. Automatic capture was rejected because it produces low-signal noise that crowds out curated entries; manual invocation accepts a smaller sample size in exchange for a higher signal-to-noise ratio per record. The split between **qualitative notes** (what the user felt) and **structured events** (what the tools did) keeps the two analysis modes — UX iteration versus threshold tuning — from contaminating each other.

## Judgment

Input: the current Claude Code session JSONL plus four category-scoped free-form texts. Output: JSONL appended to `.claude/dogfood/log.jsonl` (local, primary) and, opt-in, to `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` (global mirror for cross-project aggregation).

Four structured event types are extracted from the session JSONL:

| Event | Source | Key fields |
|-------|--------|------------|
| `skill_call` | User slash command (`/crucible:*`) or `Skill` tool_use | `skill`, `args_summary` |
| `promotion_gate` | `AskUserQuestion` with wording like "승격" / "promotion" / "저장할까요" | `candidate_id`, `response`, `detector` |
| `axis_skip` | `Bash` tool_use carrying `--skip-axis` | `axis`, `acknowledged`, `reason` |
| `qa_judge` | `tool_result` body containing `{"score":…,"verdict":…}` | `score`, `verdict` |

Four qualitative categories selected by the user (multi-select):

- **`good`** — what worked, keep it.
- **`pain`** — friction, change it.
- **`ambiguous`** — unclear response, needed a re-ask.
- **`request`** — feature wishlist.

Recursion guard: `/crucible:dogfood` invocations are dropped during extraction so repeated calls never see themselves in the log.

## Design Choices

- **Manual trigger, not auto Stop-hook.** Auto-capture tried first; too many low-signal entries degraded the dataset. The user invokes `/crucible:dogfood` when something worth recording happens. Fewer entries, higher signal.
- **Four fixed categories + free-form, not pure free-form.** Pure free-form makes aggregation impossible across months; pure categorical loses nuance. The hybrid lets queries like "all `pain` entries mentioning `/verify`" stay cheap while preserving context.
- **Append-only JSONL, not a relational store.** JSONL is the simplest format that keeps the log git-diffable, shell-greppable, and trivial to stream into analysis notebooks. A schema change does not require a migration — old lines keep their old shape.
- **Local primary + opt-in global mirror, not one or the other.** Local-only loses the cross-project aggregation this is designed for; global-only raises privacy questions on every write. Two targets with one opt-out env var (`CRUCIBLE_DOGFOOD_GLOBAL=0`) covers both needs without a plugin-level schema change.
- **`{slug}-{hash}` directory key.** `slug` alone collides across users with identically-named repos; `hash` alone is unreadable. 8-char SHA256 of the absolute path (matching `scripts/lib/project-id.sh`) disambiguates without sacrificing human scan-ability.
- **`.gitignore` auto-registration, idempotent.** The log is meant to stay local — the gitignore line is the blast-radius control. Auto-adding it on first call means forgetting to configure the ignore is impossible; idempotency means repeated calls never dirty the file.
- **Recursion filter as a skill-name blacklist inside the parser.** Tried an event-type marker first; the marker leaked into later analyses as a third axis nobody needed. The blacklist is one jq `startswith` check and leaves the schema clean.
- **Four event types, not every tool_use.** A broader capture (Bash, Read, Write, …) inflates the log by 10× with events that don't map to any tuning decision. The four chosen types correspond one-to-one with the thresholds in `docs/thresholds.md` that tuning will eventually touch.

## Thresholds

`/dogfood` does not introduce new numeric thresholds; it is the **data source** that existing thresholds will eventually be re-tuned against. Cross-references:

- `qa_judge` score/verdict bands — [`../thresholds.md §1`](../thresholds.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040).
- `promotion_gate` false-positive budget — [`../thresholds.md §5`](../thresholds.md#5-promotion-gate-false-positive-rate---20-).
- 5-dimensional overlap weights — [`../thresholds.md §7`](../thresholds.md#7-5-dimensional-overlap-weights).
- `axis_skip` policy (`--skip-axis 5 --acknowledge-risk`) — [`../axes.md`](../axes.md).

Recording cadence: manual, no scheduled reminder (deferred to v1.2+). Mirror opt-out: `CRUCIBLE_DOGFOOD_GLOBAL=0`.

## References

- Upstream p4cn `history-insight` — influenced the JSONL-first, shell-only parsing approach.
- [`../axes.md`](../axes.md) — `/dogfood`'s axis-matrix row (Context hint, Improve hint; no hard gates).
- [`../faq.md`](../faq.md) — threshold tuning roadmap, why the defaults are synthetic.
- [`../../skills/dogfood/SKILL.md`](../../skills/dogfood/SKILL.md) — the SKILL contract (`validate_prompt` self-check).
- [`../../scripts/parse-current-session.sh`](../../scripts/parse-current-session.sh) — the four-event extractor.
- [`../../scripts/dogfood-write.sh`](../../scripts/dogfood-write.sh) — writer + gitignore + global-mirror logic.

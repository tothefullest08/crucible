# NOTICES

> Third-party attributions for `crucible`. All upstream projects are **MIT-licensed** (scenario A — final-spec §4.5). No GPL contamination, no missing-license items.

`crucible` itself is distributed under [MIT](./LICENSE) (SPDX `MIT`). The notices below satisfy the attribution clause of MIT for each upstream.

---

## Upstream attributions (6)

### 1. hoyeon

- **Source**: [`references/hoyeon/`](./references/hoyeon/)
- **License**: MIT — [`references/hoyeon/LICENSE`](./references/hoyeon/LICENSE)
- **Copyright**: © 2026 team-attention
- **Snapshot commit**: `4a4e0f3` (captured 2026-04-20 · sync cadence: quarterly)
- **Ported assets**: `validate_prompt` hook pattern, 6-agent verify stack (`verifier`, `verification-planner`, `verify-planner`, `qa-verifier`, `ralph-verifier`, `spec-coverage`), Charter Preflight block, Korean UX idioms.

### 2. ouroboros

- **Source**: [`references/ouroboros/`](./references/ouroboros/)
- **License**: MIT — [`references/ouroboros/LICENSE`](./references/ouroboros/LICENSE)
- **Copyright**: © 2025 Q00
- **Snapshot commit**: `23426b5` (captured 2026-04-20 · sync cadence: quarterly)
- **Ported assets**: `qa-judge` JSON schema (0.80 / 0.40 thresholds), Ralph Loop pseudocode, Seed YAML schema, Ambiguity Score Gate (0.2 threshold), drift-monitor / keyword-detector (bash+jq rewrite).

### 3. plugins-for-claude-natives (p4cn)

- **Source**: [`references/plugins-for-claude-natives/`](./references/plugins-for-claude-natives/)
- **License**: MIT — [`references/plugins-for-claude-natives/LICENSE`](./references/plugins-for-claude-natives/LICENSE)
- **Copyright**: © 2025 Team Attention
- **Snapshot commit**: `7895a58` (captured 2026-04-20 · sync cadence: biannual)
- **Ported assets**: `session-wrap` 2-phase pipeline (4 parallel + 1 sequential), clarify 3-lens (vague / unknown / metamedium), `history-insight` JSONL parser, `session-analyzer` expected-vs-actual table.

### 4. superpowers (obra/superpowers)

- **Source**: [`references/superpowers/`](./references/superpowers/)
- **License**: MIT — [`references/superpowers/LICENSE`](./references/superpowers/LICENSE)
- **Copyright**: © 2025 Jesse Vincent
- **Snapshot commit**: `b557648` (captured 2026-04-20 · sync cadence: biannual)
- **Ported assets**: `SessionStart` hook + `using-harness.md` injection pattern, `HARD-GATE` tag convention, 3-stage Evaluator (implementer / spec-reviewer / code-quality), writing-skills Skill TDD structure.

### 5. compound-engineering-plugin (CE)

- **Source**: [`references/compound-engineering-plugin/`](./references/compound-engineering-plugin/)
- **License**: MIT — [`references/compound-engineering-plugin/LICENSE`](./references/compound-engineering-plugin/LICENSE)
- **Copyright**: © 2025 Every
- **Snapshot commit**: `b575e49` (captured 2026-04-20 · sync cadence: annual)
- **Ported assets**: 5-dimensional overlap scoring (problem / cause / solution / files / prevention), Auto Memory supplementary-block convention, Mandatory Disk Checkpoints (CP-0~CP-5), Always-on + Conditional persona split, 4-stage merge/dedup pipeline, Bug vs Knowledge track schema.

### 6. agent-council

- **Source**: [`references/agent-council/`](./references/agent-council/)
- **License**: MIT — [`references/agent-council/LICENSE`](./references/agent-council/LICENSE)
- **Copyright**: © 2024 Team Attention
- **Snapshot commit**: `79a13ee` (captured 2026-04-20 · sync cadence: annual)
- **Ported assets**: `.claude-plugin/marketplace.json` minimal structure, Host UI payload, Wait cursor bucket UX for progress visualisation.

---

## Compatibility summary

| Upstream | SPDX | MIT compatible | Notes |
|----------|------|----------------|-------|
| hoyeon | `MIT` | ✅ | quarterly sync |
| ouroboros | `MIT` | ✅ | quarterly sync |
| p4cn | `MIT` | ✅ | biannual sync |
| superpowers | `MIT` | ✅ | biannual sync |
| compound-engineering-plugin | `MIT` | ✅ | annual sync |
| agent-council | `MIT` | ✅ | annual sync |

No GPL or All-Rights-Reserved upstream in scope. Scenario B/C fallbacks (final-spec §4.5.4) remain unused.

---

*Last verified 2026-04-20 · corresponds to final-spec §4.5 and [`porting-matrix.md`](./.claude/plans/04-planning/porting-matrix.md) §4.*

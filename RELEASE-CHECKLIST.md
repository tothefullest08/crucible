# RELEASE-CHECKLIST — harness MVP (W8)

> Gate document for the MVP release. All 8 Hard AC must be **PASS** before publishing the plugin.
> Paired artifacts: [`.claude/state/ac-final.json`](./.claude/state/ac-final.json), [`final-spec.md`](./.claude/plans/03-design/final-spec.md) §10.1.

**Release gate (2026-04-20): GREEN — 8/8 Hard AC PASS.**

---

## Hard AC judgment table (8/8)

| AC | Title | Status | Evidence |
|----|-------|--------|----------|
| AC-1 | Plugin install (external deps = 0) | ✅ PASS | `__tests__/integration/test-clean-install.sh` (T-W8-08) |
| AC-2 | 4 skills callable (/brainstorm /plan /verify /compound) | ✅ PASS | test-clean-install.sh yq parse + test-ac2 + §11-7.1 field audit |
| AC-3 | `validate_prompt` fire-rate ≥ 99% · response-rate ≥ 90% | ✅ PASS | `.claude/state/ku-results/ku-1.json` GREEN (W7.5) |
| AC-4 | Description 한·영 trigger accuracy (ko/en 20 each) | ✅ PASS | `.claude/state/ku-results/ku-2.json` GREEN (W7.5) |
| AC-5 | Promotion gate false-positive rate < 20% | ✅ PASS | `.claude/state/ku-results/ku-3.json` GREEN (W7.5) |
| AC-6 | JSONL parser detects 3 compounding triggers | ✅ PASS | `__tests__/integration/test-ac6-compound-triggers.sh` (W6) |
| AC-7 | qa-judge distribution KU-0 + thresholds locked | ✅ PASS | `.claude/state/ku-results/ku-0.json` GREEN (W7.5) |
| AC-8 | README.md + README.ko.md bilingual + 한·영 description | ✅ PASS | T-W8-01, T-W8-02, T-W8-05 + §11-7.2 positioning |

Supplementary (not counted in 8 Hard AC but release-blocking):

| Item | Status | Evidence |
|------|--------|----------|
| LICENSE MIT + NOTICES (6 upstreams) + CONTRIBUTING DCO | ✅ PASS | T-W8-07 · §4.5 · SPDX `MIT` in both files |

---

## W0 → W8 gate retrospective

- **W0 — Premise re-verification**: Scenario-A license scan + harness differentiator reaffirmed (6-axis + promotion gate). Gate decision: proceed to W1.
- **W1 — Scaffold + JSONL smoke + SessionStart**: plugin.json/marketplace.json minimal manifest, session-start hook with payload SHA256 guard, history-insight JSONL parser (jq-only rewrite).
- **W2 — `/brainstorm` MVP**: clarify 3-lens (vague/unknown/metamedium), validate_prompt hook, HARD-GATE tag convention ported from superpowers.
- **W3 — `/plan` hybrid**: Markdown body + YAML frontmatter (Seed schema from ouroboros), Ambiguity Gate 0.2, Model Tiering policy.
- **W4 — `/verify` + qa-judge + Ralph Loop**: 6-agent verify stack, qa-judge JSON schema 0.80/0.40, drift-monitor.sh (bash+jq rewrite of ouroboros Python original), SHA256 hook integrity.
- **W5 — Memory + promotion gate UX**: 6-step gate (candidate → score → verdict → UX → write → log), 5-dim overlap scoring, `y/N/e/s` response keys, bug vs knowledge track split.
- **W6 — `/compound` triggers**: 3-trigger detection (pattern_repeat · user_correction · session_wrap), keyword-detector.sh (bash+jq rewrite), pathology pattern detection 4 types, AC-6 test PASS.
- **W7 `[Stretch]` — `/orchestrate` B**: 4-axis end-to-end pipeline, CP-0~CP-5 mandatory disk checkpoints, Host UI payload + Wait cursor, 3-axis dispatch×work×verify.
- **W7.5 — KU execution + hardening**: KU-0/1/2/3 all GREEN, synthetic 20-sample baselines, threshold rebase (accept 0.86 / retry 0.50), writing-skills Skill TDD.
- **W8 — Documentation + OSS release**: §11-5/6/7 promoted, README.md + README.ko.md, CLAUDE.md + AGENTS.md, LICENSE/NOTICES/CONTRIBUTING, test-clean-install.sh AC-1 PASS, Hard AC 8/8 locked.

---

## Pre-release checklist (≥ 20 items)

Code and tests

- [x] 1. All 8 Hard AC PASS (see table above)
- [x] 2. test-clean-install.sh AC-1 PASS (clean tmpdir, no python/node refs, /brainstorm yq parse)
- [x] 3. test-ac2-brainstorm-validate.sh PASS
- [x] 4. test-ac3-plan-format.sh PASS
- [x] 5. test-ac4-qa-judge-threshold.sh PASS
- [x] 6. test-ac6-compound-triggers.sh PASS
- [x] 7. KU-0/1/2/3 all GREEN in `.claude/state/ku-results/`
- [x] 8. `shellcheck` clean on hooks/ and scripts/ (T-W1-09 security linter delegate)

Manifests and metadata

- [x] 9. `.claude-plugin/plugin.json` has `license: "MIT"`
- [x] 10. `.claude-plugin/plugin.json` payload SHA256 map matches on-disk files
- [x] 11. `.claude-plugin/marketplace.json` plugins[0].name matches plugin.json.name
- [x] 12. All 5 `skills/*/SKILL.md` frontmatter parses via yq (`awk` extract + `yq eval '.name'`)
- [x] 13. All 5 SKILL.md carry 6 frontmatter fields (name, description, when_to_use, input, output, validate_prompt) — §11-7.1

License and attribution

- [x] 14. `LICENSE` carries `SPDX-License-Identifier: MIT` header + full MIT text
- [x] 15. `NOTICES.md` lists 6 upstream projects with commit hashes, copyright lines, MIT SPDX
- [x] 16. `CONTRIBUTING.md` carries `SPDX-License-Identifier: MIT` + DCO sign-off procedure
- [x] 17. `porting-matrix.md` §2 tables include commit hash + sync cadence columns for 32 assets

Documentation

- [x] 18. `README.md` contains positioning sentence ≤ 140 chars + 5 skills + License + Acknowledgments (≥ 80 lines)
- [x] 19. `README.ko.md` mirrors README.md sections + carries a Korean-only trigger example
- [x] 20. `CLAUDE.md` references AGENTS.md/NOTICES.md/CONTRIBUTING.md + 6-axis rules (≤ 200 lines)
- [x] 21. `AGENTS.md` contains 6-axis checklist + per-skill validate_prompt summaries (≤ 120 lines)

Release operations

- [ ] 22. CI green on `main` (not yet wired — W8+ follow-up)
- [ ] 23. Git tag `v0.1.0` pushed with release notes referencing this checklist
- [ ] 24. Plugin marketplace listing submitted (W8+ follow-up — requires marketplace account)
- [x] 25. DCO sign-off enforced on all commits since W0 (local convention; GitHub Actions bot deferred to post-W8)

Items 22/23/24 are post-merge release operations performed after this branch ships to `main`.

---

## Hard AC summary (one-line)

```
AC-1 ✅  AC-2 ✅  AC-3 ✅  AC-4 ✅  AC-5 ✅  AC-6 ✅  AC-7 ✅  AC-8 ✅   → release-gate GREEN
```

Full JSON: [`.claude/state/ac-final.json`](./.claude/state/ac-final.json).

---

*Generated 2026-04-20 · T-W8-06 · corresponds to final-spec §10.1 and porting-matrix §6.*

# README Integrity Checklist — T-README-11

> Execution of AC-11.1 / AC-11.2 / AC-11.3 against the post-Phase-3 tree.
> Branch: `feat/readme-verify` · run date: `2026-04-20`.

---

## AC-11.1 — Link integrity

**Method.** Python validator resolves every `]( ./... )` and `]( ../... )` relative link in `README.md`, `README.ko.md`, and `docs/**/*.md` against the working tree. Anchor fragments (`#...`) are stripped before `os.path.exists` — GitHub rendering resolves anchors at display time.

**Result.** `Resolved links: 87 · Broken: 0` → **PASS**.

Full command (reproducible):

```bash
python3 - <<'PY'
import os, re, glob
p = re.compile(r"\]\((\.\.?/[^)\s]+)\)")
ok = fail = 0; bad = []
files = ["README.md", "README.ko.md"] + glob.glob("docs/**/*.md", recursive=True)
for f in files:
    d = os.path.dirname(os.path.abspath(f))
    with open(f) as fh: text = fh.read()
    for link in p.findall(text):
        cand = os.path.normpath(os.path.join(d, link.split("#",1)[0]))
        if os.path.exists(cand): ok += 1
        else: fail += 1; bad.append((f, link, cand))
print(f"ok={ok} fail={fail}")
for b in bad: print(b)
PY
```

---

## AC-11.2 — Number traceability

Every quantitative value in `docs/thresholds.md` must be referenced at least once elsewhere in `README.*` or `docs/`. Measured by keyword signature on 8 items (excluding `thresholds.md` itself).

| # | Item | Refs | Files |
|---|------|:---:|-------|
| 1 | `qa-judge` bands `0.80 / 0.40` | 4 | `docs/axes.md`, `docs/faq.md`, `docs/skills/plan.md`, `docs/skills/verify.md` |
| 2 | KU sample size `n = 20` | 1 | `docs/faq.md` |
| 3 | `validate_prompt` `≥ 0.99 / 0.90` | 1 | `docs/skills/verify.md` |
| 4 | Bilingual `Δ ≤ 5 %pp` | 2 | `docs/faq.md`, `docs/skills/brainstorm.md` |
| 5 | Promotion-gate FP `≤ 20 %` | 1 | `docs/skills/compound.md` |
| 6 | Ralph Loop cap `3` | 4 | `docs/axes.md`, `docs/faq.md`, `docs/skills/orchestrate.md`, `docs/skills/verify.md` |
| 7 | 5-D overlap weights `0.30 / 0.20 / …` | 3 | `README.md` *(mentioned via pointer label)*, `docs/axes.md`, `docs/skills/compound.md` |
| 8 | Oscillation `overlap ≥ 0.80` within `Gen N-2` | 3 | `docs/faq.md`, `docs/skills/compound.md`, `docs/skills/orchestrate.md` |

**Result.** All 8 items referenced ≥ 1 time outside `thresholds.md` → **PASS**.

---

## AC-11.3 — Manual 4 items

| # | Check | Result |
|---|-------|:-----:|
| 1 | Every `docs/**/*.md` (8 files) starts with a `# ` header on line 1 | PASS |
| 2 | Section-title language consistency — English primary in `docs/`, Korean parenthetical only in `README.ko.md` | PASS |
| 3 | `docs/skills/*.md` (5 files) all contain the 5-section template (`## Paradigm` · `## Judgment` · `## Design Choices` · `## Thresholds` · `## References`) | PASS |
| 4 | `docs/thresholds.md` top 10 lines contain a synthetic-fixture disclaimer (`synthetic` + (`MVP` ∨ `fixture`)) | PASS |

---

## Additional sanity checks

- **AC-H1 — file size cap.** All 8 `docs/` files ≤ 200 lines: `axes 92 · thresholds 93 · faq 59 · skills/brainstorm 42 · skills/plan 45 · skills/verify 50 · skills/compound 50 · skills/orchestrate 62` → **PASS**.
- **AC-H3 — matrix relocation.** `README.md` and `README.ko.md` no longer contain a 6-axis matrix table; both carry a 1-line summary + `docs/axes.md` pointer → **PASS**.
- **AC-H4 — single-source for numbers.** Numeric values appear only inside `docs/thresholds.md`; every other reference is prose (`≥ 0.80`) or a hyperlink anchor. No duplicated threshold tables outside `thresholds.md` → **PASS**.
- **AC-H6 — synthetic disclaimer in FAQ.** `docs/faq.md` Q2 explicitly states "synthetic fixture · production tuning required" → **PASS**.
- **AC-S1 — bilingual symmetry.** Section-heading `##` count and order match between `README.md` and `README.ko.md`; only in-code-block comments differ (per-language examples preserved) → **PASS**.

---

## Verdict

All AC-11 checks green. Phase 4 closes the README enhancement sprint.

*Generated as part of T-README-11 on `feat/readme-verify`.*

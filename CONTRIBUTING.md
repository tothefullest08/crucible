# Contributing to crucible

<!-- SPDX-License-Identifier: MIT -->

Thanks for your interest in contributing! crucible is an **MIT-licensed** (SPDX `MIT`) Claude Code plugin, and we welcome issues, patches, docs, and new porting candidates from the wider Claude Code ecosystem.

This document covers the workflow, commit/PR rules, and the **DCO sign-off** that every contribution must carry.

---

## How to contribute

### Reporting issues

- Search existing issues before opening a new one.
- Use a descriptive title and include: Claude Code version, crucible commit hash, and the minimal reproduction steps.
- For suspected spec drift, link the relevant section of `.claude/plans/2026-04-19/03-design/final-spec.md` (v3.1 is the single source of truth).

### Submitting pull requests

1. **Fork and branch.** Branch names follow `<type>/<short-topic>` (e.g., `feat/verify-gate`, `fix/hook-race`).
2. **Write tests first.** crucible follows the project-wide TDD rule — RED → GREEN → REFACTOR, ≥ 80% coverage.
3. **Run validation locally** before pushing (see [PR checklist](#pr-checklist)).
4. **Sign off every commit** (DCO — see next section).
5. **Open a PR** against `main` with a summary, test plan, and links to any `.claude/plans/` sections touched.

---

## DCO sign-off (required)

crucible uses the **Developer Certificate of Origin (DCO) v1.1** instead of a Contributor License Agreement. This is the same mechanism used by the Linux kernel, Git, and most major OSS projects — it keeps the barrier to entry low while giving the project baseline legal protection.

### What you need to do

Every commit must carry a `Signed-off-by:` trailer that matches the author name and email on the commit. The easiest way to add it is the `-s` flag:

```bash
git commit -s -m "feat(verify): add grey-zone Consensus path"
```

This appends a line like:

```
Signed-off-by: Jane Doe <jane@example.com>
```

If you already wrote the commit, amend it:

```bash
git commit --amend -s --no-edit
```

For a range of existing commits on your branch:

```bash
git rebase --signoff <base-branch>
```

### What signing off means

By adding `Signed-off-by:`, you are certifying the statements in the DCO — essentially, that you wrote the patch (or have the right to submit it) under the project's license. The **full text of the DCO v1.1** lives at [.github/DCO.md](./.github/DCO.md). Read it once before your first contribution.

### Enforcement

PRs whose commits lack DCO sign-offs will be asked to rebase before merge. A GitHub Actions DCO bot will be wired up in a future release to flag missing sign-offs automatically.

---

## Commit message convention

crucible follows [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short imperative summary>

<optional body explaining the why>

Signed-off-by: Your Name <you@example.com>
```

Allowed types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `ci`.

- Keep the summary ≤ 72 chars, imperative mood ("add", not "added").
- Reference related tasks with the task ID (e.g., `T-W1-03`) when relevant.

---

## PR checklist

Before marking a PR ready for review, confirm:

- [ ] All commits carry `Signed-off-by:` (DCO)
- [ ] Commit messages follow Conventional Commits
- [ ] Tests pass locally (unit + integration + e2e where applicable)
- [ ] `shellcheck` passes on any touched shell scripts
- [ ] `yq` parses every skill's YAML frontmatter (`yq eval '.name' skills/*/SKILL.md`)
- [ ] JSON manifests validate (`.claude-plugin/plugin.json`, `marketplace.json`)
- [ ] 6-axis compliance: state which of axes 1–6 the change affects and confirm `validate_prompt` still passes for affected skills
- [ ] Hard AC impact: list any of the 8 Hard AC (final-spec §10.1) the change touches
- [ ] Any `§11` open-item deadline referenced in `.claude/plans/2026-04-19/03-design/final-spec.md` is respected (or you've explicitly flagged that the PR postpones one)
- [ ] Docs and `MEMORY.md` pointers are updated when behavior changes
- [ ] No secrets, API keys, or local paths committed
- [ ] `SPDX-License-Identifier: MIT` preserved in `LICENSE` and this file

---

## Code of Conduct

A formal Code of Conduct will be added in a future release. Until then, the short version: be kind, assume good intent, and focus critique on code rather than people. Harassment or discrimination will not be tolerated.

*(Placeholder — link to be added once `CODE_OF_CONDUCT.md` lands.)*

---

## Development setup

### Prerequisites

- `bash` (4+ preferred)
- `jq` (for JSON validation and hook scripts)
- Claude Code CLI installed and authenticated
- A POSIX-ish shell environment (macOS or Linux). See spec §4.1 for the full runtime contract.

### Local install

```bash
git clone https://github.com/<owner>/crucible.git
cd crucible

# Link the plugin into your Claude Code plugins dir
# (exact command will be finalized alongside the W8 install docs)
```

### Running tests

```bash
# Shell-level unit tests
./scripts/run-tests.sh

# JSON manifest validation
./scripts/validate-manifests.sh
```

*(Script paths above are placeholders until the W1–W2 testing scaffold lands. Until then, see individual skill directories under `skills/` for ad-hoc test instructions.)*

---

## Questions?

Open a GitHub issue with the `question` label, or link to the relevant `.claude/plans/` section so we can respond in context.

Thanks for contributing to crucible.

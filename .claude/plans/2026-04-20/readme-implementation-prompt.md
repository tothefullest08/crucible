# README 고도화 구현 스프린트 — T-README-01~11 · Phase별 브랜치 · 태스크별 커밋

> plan: `.claude/plans/2026-04-20/readme-enhancement-plan.md` (11 태스크, 4 phase, 8h 상한)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-20/readme-enhancement-plan.md` — 본 plan (단일 진실 소스)
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-20/readme-enhancement-requirements.md` — 요구사항
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v3.4 (내부 스펙 참조용)
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/prompts/_git-workflow-template.md` — rebase-first 정책
5. `/Users/ethan/Desktop/personal/harness/README.md` · `README.ko.md` · `skills/*/SKILL.md` (독해만)
6. `/Users/ethan/Desktop/personal/harness/.claude/state/ku-results/ku-{0,1,2,3}.json` — KU 실측 데이터 (thresholds.md 근거)

## 🌲 브랜치 전략 (엄수)

**4 phase × 1 브랜치 = 4 브랜치 · 태스크별 커밋 = 총 11 커밋**

```
main ─┬─► feat/readme-p0-foundations ─► 3 commits (T-01·02·03) ─► PR → merge
      ├─► feat/readme-p1-skills      ─► 5 commits (T-04·05·06·07·08) ─► PR → merge
      ├─► feat/readme-polish         ─► 2 commits (T-09·10) ─► PR → merge
      └─► feat/readme-verify         ─► 1 commit (T-11) ─► PR → merge
```

**각 phase 완료 시 main에 regular merge (`--no-ff`)로 태스크별 커밋 보존**. 다음 phase는 최신 main에서 새로 checkout.

## ⚙️ 공통 실행 제약

- bash + jq + yq + uuidgen (v3.4 §4.1). Python/Node 금지.
- `_git-workflow-template.md` rebase-first: `git pull --rebase origin main` 먼저.
- 각 커밋 `git commit -s` (DCO sign-off 필수)
- 커밋 메시지 Conventional Commits (`docs(readme): ...`, `feat(docs): ...` 등)
- 태스크별 커밋 1개 원칙 (하나의 파일·하나의 태스크·하나의 커밋)
- 파일당 **≤ 200 라인** (plan constraints)
- 모든 정량 수치는 `docs/thresholds.md`에만 숫자 보유, 다른 파일은 링크로만 참조 (중복 금지)
- skills/SKILL.md 본문 수정 금지 (description frontmatter 미세 조정 예외)
- 새 훅·스크립트 추가 금지 (문서 전용)
- 권한 dialog 나오면 "2" always allow

---

## 🎯 Phase 1 — P0 Foundations (T-README-01·02·03)

### 시작

```bash
cd /Users/ethan/Desktop/personal/harness
git checkout main
git pull --rebase origin main
git checkout -b feat/readme-p0-foundations
```

### Task 1 — T-README-01: `docs/axes.md`

**요구사항**: plan.md §Tasks → T-README-01 AC-01.1~01.3 엄수.
**내용 골격**:
- 6축 정의표 (Structure · Context · Plan · Execute · Verify · Improve)
- 스킬 5개 × 6축 ON/OFF/log-only matrix
- 각 축별 "왜 필요한가" 단락 (2~4 문장)
- `--skip-axis N` 스펙 + Axis 5 스킵 시 `--acknowledge-risk` 필수 이유
- "하네스 6축" 용어 각주 (강의 어원)
- **≤ 200 라인**

```bash
git add docs/axes.md
git commit -s -m "feat(docs): add axes.md — 6-axis matrix + skip policy (T-README-01)"
```

### Task 2 — T-README-02: `docs/thresholds.md`

**요구사항**: plan.md → T-README-02 AC-02.1~02.3.
**필수 8개 정량 항목** (각 출처 + 측정 방법 + 튜닝 계획 포함):
1. qa-judge 0.80/0.40 → ouroboros 원본 + KU-0 재측정 (p75=0.86·p25=0.50)
2. KU sample size = 20 → 이진 판정 95% CI 폭 근거
3. validate_prompt fire ≥ 99% · response ≥ 90% → KU-1 기준
4. description 한·영 정확도 Δ ≤ 5%p → KU-2 기준
5. 승격 게이트 false positive < 20% → KU-3 기준
6. Ralph Loop 상한 3회 → ouroboros 관례
7. 5-차원 overlap 가중치 (problem 0.3·cause 0.2·solution 0.2·files 0.15·prevention 0.15)
8. oscillation 차단 기준 (overlap ≥ 0.8 within Gen N-2)

- 상단에 "⚠️ MVP synthetic fixture 기반 · production tuning 필요" 디스클레이머
- **≤ 200 라인**

```bash
git add docs/thresholds.md
git commit -s -m "feat(docs): add thresholds.md — 8 quantitative items with provenance (T-README-02)"
```

### Task 3 — T-README-03: `docs/faq.md`

**요구사항**: plan.md → T-README-03 AC-03.1~03.3.
**8~12개 Q&A 목표, A ≤ 5 문장**:
- Q1. 왜 임계값이 0.80/0.40인가?
- Q2. synthetic fixture 기반인데 production에서 신뢰할 수 있나? *(AC-H6 필수)*
- Q3. Ralph Loop가 무한 루프 되지 않나?
- Q4. 승격 게이트가 번거롭지 않나?
- Q5. /orchestrate와 /brainstorm 4번의 차이?
- Q6. 한국어 트리거가 영어와 동등한가?
- Q7. Claude Code 외 LLM에서 쓸 수 있나?
- Q8. (추가) dogfooding 예상 Q 1~2개
- **≤ 200 라인**

```bash
git add docs/faq.md
git commit -s -m "docs(faq): add Q&A covering thresholds·limits·trade-offs (T-README-03)"
```

### Phase 1 종료: PR + merge

```bash
git push -u origin feat/readme-p0-foundations

gh pr create --title "Phase 1 · P0 foundations (T-README-01·02·03)" --body "$(cat <<'EOF'
## Summary
- T-README-01: docs/axes.md — 6-axis matrix + skip policy
- T-README-02: docs/thresholds.md — 8 quantitative items with provenance
- T-README-03: docs/faq.md — 8+ Q&A including synthetic fixture disclaimer

## AC
- AC-H1 partial (3/8 files) · AC-H2 n/a · AC-H6 PASS

## Next
Phase 2 (P1 · 5 skills) starts from main post-merge.
EOF
)"

# Self-merge (solo repo). Regular merge preserves per-task commits.
gh pr merge --merge --delete-branch=false
git checkout main
git pull --rebase origin main
```

---

## 🎯 Phase 2 — P1 Skills (T-README-04~08)

### 시작

```bash
git checkout -b feat/readme-p1-skills
mkdir -p docs/skills
```

### 공통 템플릿 — 5 스킬 동형 5-섹션 구조

각 `docs/skills/<skill>.md`에 **동일 구조** 적용:

```markdown
# <skill>

## Paradigm
<근본 철학 · 1~2 단락>

## Judgment
<판단 기준 · 입력→출력 결정 로직>

## Design Choices
<주요 설계 선택과 근거 · bullet 5~10>

## Thresholds
<정량 수치는 ../thresholds.md#<anchor>로만 링크 — 숫자 중복 금지>

## References
<상류(ouroboros/hoyeon/p4cn/superpowers/CE/agent-council) 포팅 출처 + SKILL.md 링크>
```

### Task 4~8 (병렬 작성, 커밋은 순차)

| Task | 파일 | 핵심 내용 |
|------|------|----------|
| T-README-04 | `docs/skills/brainstorm.md` | 3-lens 선택 이유, Phase 1~4, requirements.md 스키마 |
| T-README-05 | `docs/skills/plan.md` | Markdown+YAML 하이브리드 근거, Ambiguity Gate 0.2, 가중치 합 1.0 |
| T-README-06 | `docs/skills/verify.md` | qa-judge 선택, Ralph Loop, 3-stage Evaluator, fresh-context |
| T-README-07 | `docs/skills/compound.md` | 3 트리거 선정, 6-Step 승격, 5-차원 overlap (링크만) |
| T-README-08 | `docs/skills/orchestrate.md` | 4축 순차 · CP-0~CP-5 · dispatch×work×verify 3 조합 |

각 파일 **≤ 200 라인**, 5-섹션 준수, thresholds는 링크.

```bash
git add docs/skills/brainstorm.md
git commit -s -m "feat(docs): add skills/brainstorm.md — 3-lens paradigm (T-README-04)"

git add docs/skills/plan.md
git commit -s -m "feat(docs): add skills/plan.md — hybrid Markdown+YAML rationale (T-README-05)"

git add docs/skills/verify.md
git commit -s -m "feat(docs): add skills/verify.md — qa-judge + Ralph Loop rationale (T-README-06)"

git add docs/skills/compound.md
git commit -s -m "feat(docs): add skills/compound.md — 3-trigger + 6-step gate rationale (T-README-07)"

git add docs/skills/orchestrate.md
git commit -s -m "feat(docs): add skills/orchestrate.md — 4-axis CP-0~5 rationale (T-README-08)"
```

### Phase 2 종료: PR + merge

```bash
git push -u origin feat/readme-p1-skills
gh pr create --title "Phase 2 · P1 skills (T-README-04~08)" --body "$(cat <<'EOF'
## Summary
5 skill docs in docs/skills/ following the 5-section template (Paradigm · Judgment · Design Choices · Thresholds · References).

## AC
- AC-H2 PASS (5/5 template compliance)
- AC-H1 partial (8/8 files complete after this merge)

## Next
Phase 3 (README polish) aligns README.md + README.ko.md to new docs/.
EOF
)"
gh pr merge --merge --delete-branch=false
git checkout main
git pull --rebase origin main
```

---

## 🎯 Phase 3 — README Polish (T-README-09·10)

### 시작

```bash
git checkout -b feat/readme-polish
```

### Task 9 — T-README-09: `README.md`

- 6축 matrix 표 → 제거, 1줄 요약 + `docs/axes.md` 링크로 대체
- 각 주요 섹션 하단에 `**Details** → [docs/...]` 포인터 (axes · thresholds · faq · skills 최소 4개)
- 설치·예제 섹션 구조 **유지** (Constraint 준수)

```bash
git add README.md
git commit -s -m "docs(readme): relocate 6-axis matrix to docs/axes.md + add pointers (T-README-09)"
```

### Task 10 — T-README-10: `README.ko.md`

- README.md와 **섹션 순서·포인터 스타일 1:1 동형**
- 한국어 고유 예제 1개 이상 유지
- 6축 matrix → 한국어 1줄 요약 + `docs/axes.md` 링크

```bash
git add README.ko.md
git commit -s -m "docs(readme): mirror README.md structure in Korean (T-README-10)"
```

### Phase 3 종료: PR + merge

```bash
git push -u origin feat/readme-polish
gh pr create --title "Phase 3 · README polish (T-README-09·10)" --body "$(cat <<'EOF'
## Summary
- README.md: 6-axis matrix relocated to docs/axes.md, pointer style
- README.ko.md: mirrored structure, Korean-only example preserved

## AC
- AC-H3 PASS (matrix relocated)
- AC-S1 PASS (bilingual symmetry)

## Next
Phase 4 (T-README-11) runs link-integrity + number-drift check.
EOF
)"
gh pr merge --merge --delete-branch=false
git checkout main
git pull --rebase origin main
```

---

## 🎯 Phase 4 — Verification (T-README-11)

### 시작

```bash
git checkout -b feat/readme-verify
```

### Task 11 — T-README-11: 링크·수치 무결성 체크리스트

본 체크리스트를 `.claude/plans/2026-04-20/readme-integrity-checklist.md` 로 저장 + 실행 결과 기록.

**체크 항목**:
- **Link integrity (AC-11.1)**: `grep -rn "docs/" README.md README.ko.md docs/ 2>/dev/null` 결과 각 상대 경로가 실제 파일에 대응
  - 스크립트: 추출된 경로마다 `test -f` 검증
- **Number traceability (AC-11.2)**: `docs/thresholds.md` 8개 수치 항목이 README 또는 docs/ 어딘가에서 최소 1회 참조됨
  - 수동 매핑 표 작성 (수치 → 참조 파일)
- **Manual 4 items (AC-11.3)**:
  1. 각 `docs/*.md` 파일 헤더 1줄 존재
  2. 섹션 제목 한글/영문 일관성
  3. `docs/skills/*.md` 5개가 5-섹션 템플릿 100% 준수
  4. `docs/thresholds.md` 상단 synthetic 디스클레이머 존재

**체크리스트 통과 시 파일 커밋**:

```bash
git add .claude/plans/2026-04-20/readme-integrity-checklist.md
git commit -s -m "test(readme): add integrity checklist — all links + number drift pass (T-README-11)"
```

### Phase 4 종료: PR + merge

```bash
git push -u origin feat/readme-verify
gh pr create --title "Phase 4 · Integrity verification (T-README-11)" --body "$(cat <<'EOF'
## Summary
Manual integrity checklist for link health + number drift across README + docs/.

## AC
- AC-11.1 links OK
- AC-11.2 8 numbers traced
- AC-11.3 4 manual items PASS
- AC-H5 PASS (integrity closure)

## Release note
README 고도화 스프린트 완료. 4 PR 순차 merge. 11 commits preserved in main.
EOF
)"
gh pr merge --merge --delete-branch=false
git checkout main
git pull --rebase origin main
```

---

## ✅ 최종 완료 기준

1. `docs/` 8파일 모두 존재하고 각 ≤ 200 라인 (AC-H1)
2. `docs/skills/*.md` 5개 동일 5-섹션 템플릿 준수 (AC-H2)
3. README·README.ko 6축 matrix 이관 완료 (AC-H3)
4. 8개 정량 수치 thresholds.md 집중, 다른 곳엔 링크 (AC-H4)
5. 내부 링크 깨짐 0건 (AC-H5)
6. FAQ에 synthetic fixture 한계 최소 1회 언급 (AC-H6)
7. 4 PR × 11 커밋 main에 merge 완료 (regular merge로 모든 태스크 커밋 보존)
8. plan 체크박스 업데이트 불필요 (plan은 implementation-plan이 아님, 산출 체크는 checklist로)

## 🛑 금지

- 단일 브랜치에 11 태스크 일괄 커밋
- squash merge (태스크 커밋 유실)
- 8h 초과 시 강제 계속 — P1은 차기 스프린트 이월 (exit_conditions.timeout 준수)
- final-spec·implementation-plan 수정
- skills/SKILL.md 본문 변경
- 새 훅·스크립트 추가
- force-push to main

시작하세요.

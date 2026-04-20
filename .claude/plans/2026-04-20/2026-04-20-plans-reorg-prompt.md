# plans/ 재구성 — 날짜 폴더 분리 스프린트

> **.claude/plans/ 내부를 에픽별 날짜 폴더로 재구성.** 초기 구현 에픽(2026-04-19) + README 고도화 에픽(2026-04-20).

## 📖 컨텍스트

- `.claude/plans/` 현재 구조:
  ```
  .claude/plans/
  ├── 00-recommendations/
  ├── 01-requirements/
  ├── 02-research/
  ├── 03-design/
  ├── 04-planning/
  ├── prompts/
  ├── INDEX.md
  ├── 2026-04-20-readme-enhancement-plan.md
  └── 2026-04-20-readme-enhancement-requirements.md
  ```
- 오늘 날짜: **2026-04-20**
- 작업 디렉토리: `/Users/ethan/Desktop/personal/harness`

## 🎯 목표

```
.claude/plans/
├── 2026-04-19/                  ← 초기 구현 에픽 (W0~W8)
│   ├── 00-recommendations/
│   ├── 01-requirements/
│   ├── 02-research/
│   ├── 03-design/
│   ├── 04-planning/
│   ├── prompts/
│   └── INDEX.md
└── 2026-04-20/                  ← README 고도화 에픽
    ├── 2026-04-20-readme-enhancement-plan.md
    └── 2026-04-20-readme-enhancement-requirements.md
```

## 🔧 작업 순서

### 1️⃣ 영향 범위 스캔 (before any moves)

```bash
cd /Users/ethan/Desktop/personal/harness

# plans/ 내부 경로를 참조하는 파일 전수 조사 (references/, lecture/ 제외)
grep -rn "\.claude/plans/" \
  --include="*.md" --include="*.json" --include="*.sh" --include="*.yaml" --include="*.yml" \
  2>/dev/null \
  | grep -v "^./references/" \
  | grep -v "^./lecture/" \
  | grep -v "^./.claude/plans/2026-04-19" \
  | grep -v "^./.claude/plans/2026-04-20" \
  > /tmp/plans-refs-before.txt

wc -l /tmp/plans-refs-before.txt
```

### 2️⃣ git mv 로 이동 (히스토리 보존)

```bash
# 2026-04-19 폴더 생성 후 기존 7 하위 이동
mkdir -p .claude/plans/2026-04-19
git mv .claude/plans/2026-04-19/00-recommendations   .claude/plans/2026-04-19/00-recommendations
git mv .claude/plans/2026-04-19/01-requirements      .claude/plans/2026-04-19/01-requirements
git mv .claude/plans/2026-04-19/02-research          .claude/plans/2026-04-19/02-research
git mv .claude/plans/2026-04-19/03-design            .claude/plans/2026-04-19/03-design
git mv .claude/plans/2026-04-19/04-planning          .claude/plans/2026-04-19/04-planning
git mv .claude/plans/2026-04-19/prompts              .claude/plans/2026-04-19/prompts
git mv .claude/plans/2026-04-19/INDEX.md             .claude/plans/2026-04-19/INDEX.md

# 2026-04-20 폴더 생성 후 오늘 2 파일 이동
mkdir -p .claude/plans/2026-04-20
git mv .claude/plans/2026-04-20/readme-enhancement-plan.md         .claude/plans/2026-04-20/readme-enhancement-plan.md
git mv .claude/plans/2026-04-20/readme-enhancement-requirements.md .claude/plans/2026-04-20/readme-enhancement-requirements.md
```

> 주의: 2026-04-20 파일 2개는 날짜 접두사 제거 (`readme-enhancement-plan.md`)로 rename — 폴더 이름이 이미 날짜임. 중복 제거.

### 3️⃣ 전역 경로 치환 — `.claude/plans/<subpath>` → `.claude/plans/2026-04-19/<subpath>`

**대상 디렉토리**: 레포 루트 (단, `references/`·`lecture/`·`.claude/plans/2026-04-19/`·`.claude/plans/2026-04-20/` 제외)

```bash
# 치환 패턴 (고정 순서로 7종)
PATTERNS=(
  ".claude/plans/2026-04-19/00-recommendations:.claude/plans/2026-04-19/00-recommendations"
  ".claude/plans/2026-04-19/01-requirements:.claude/plans/2026-04-19/01-requirements"
  ".claude/plans/2026-04-19/02-research:.claude/plans/2026-04-19/02-research"
  ".claude/plans/2026-04-19/03-design:.claude/plans/2026-04-19/03-design"
  ".claude/plans/2026-04-19/04-planning:.claude/plans/2026-04-19/04-planning"
  ".claude/plans/2026-04-19/prompts:.claude/plans/2026-04-19/prompts"
  ".claude/plans/2026-04-19/INDEX.md:.claude/plans/2026-04-19/INDEX.md"
)

# 치환 대상 파일 리스트
FILES=$(
  grep -rln "\.claude/plans/" \
    --include="*.md" --include="*.json" --include="*.sh" --include="*.yaml" --include="*.yml" \
    2>/dev/null \
    | grep -v "^./references/" \
    | grep -v "^./lecture/" \
)

for f in $FILES; do
  for p in "${PATTERNS[@]}"; do
    from="${p%%:*}"
    to="${p##*:}"
    # 이미 2026-04-19 접두가 있으면 skip (재치환 방지 — from 문자열이 to와 부분 겹침 방지)
    # PATTERNS 순서상 `.claude/plans/` 접두만 매칭하므로 안전
    sed -i '' "s|${from}|${to}|g" "$f" 2>/dev/null || true
  done
done
```

**검증**: 치환 후 `grep -rn "\.claude/plans/[0-9]" --include="*.md"` 결과 전부 `2026-04-19` 또는 `2026-04-20` prefix인지 확인.

### 4️⃣ 2026-04-20 파일 2개 내부 링크 갱신 (파일명 변경분)

```bash
# plan.md가 requirements.md를 참조하면 새 경로로
# - old: .claude/plans/2026-04-20/readme-enhancement-requirements.md
# - new: .claude/plans/2026-04-20/readme-enhancement-requirements.md
sed -i '' 's|\.claude/plans/2026-04-20-readme-enhancement-plan\.md|.claude/plans/2026-04-20/readme-enhancement-plan.md|g' \
  .claude/plans/2026-04-20/*.md

sed -i '' 's|\.claude/plans/2026-04-20-readme-enhancement-requirements\.md|.claude/plans/2026-04-20/readme-enhancement-requirements.md|g' \
  .claude/plans/2026-04-20/*.md

# 전역 치환도 필요 (루트 문서에서 참조할 수도)
for f in $(grep -rln "2026-04-20-readme-enhancement" --include="*.md" 2>/dev/null | grep -v "^./references/" | grep -v "^./lecture/"); do
  sed -i '' 's|\.claude/plans/2026-04-20-readme-enhancement-plan\.md|.claude/plans/2026-04-20/readme-enhancement-plan.md|g' "$f"
  sed -i '' 's|\.claude/plans/2026-04-20-readme-enhancement-requirements\.md|.claude/plans/2026-04-20/readme-enhancement-requirements.md|g' "$f"
done
```

### 5️⃣ plugin.json SHA256 payload 영향 확인

- `plugin.json.harness.payload_sha256` 내 3 파일 경로:
  - `skills/using-harness/SKILL.md` (plans 외부 ✓)
  - `hooks/session-start.sh` (plans 외부 ✓)
  - `hooks/validate-output.sh` (plans 외부 ✓)
- **전부 plans 외부 파일 → SHA256 영향 없음**. 재계산 불필요.

### 6️⃣ 검증

```bash
# 6a. broken internal links 체크 (markdown 링크 추정)
grep -rn "\.claude/plans/[0-9]" --include="*.md" 2>/dev/null \
  | grep -v "^./references/" \
  | grep -v "^./lecture/" \
  | grep -v "2026-04-19" \
  | grep -v "2026-04-20" \
  > /tmp/plans-refs-broken.txt
wc -l /tmp/plans-refs-broken.txt  # 0이어야 함

# 6b. 이동 후 실제 파일 존재 확인
for p in 00-recommendations 01-requirements 02-research 03-design 04-planning prompts INDEX.md; do
  [ -e ".claude/plans/2026-04-19/$p" ] && echo "OK: 2026-04-19/$p" || echo "FAIL: 2026-04-19/$p"
done
[ -e ".claude/plans/2026-04-20/readme-enhancement-plan.md" ] && echo "OK: 2026-04-20/plan" || echo "FAIL"
[ -e ".claude/plans/2026-04-20/readme-enhancement-requirements.md" ] && echo "OK: 2026-04-20/req" || echo "FAIL"

# 6c. plans 직속에 더 이상 파일이 없는지 (날짜 폴더 2개 + 이 프롬프트만)
ls -1 .claude/plans/
# Expected:
#   2026-04-19
#   2026-04-20
#   (prompts가 2026-04-19 안으로 이동했으므로 plans/prompts는 없음)
```

> 만약 `.claude/plans/2026-04-19/prompts/2026-04-20-plans-reorg-prompt.md`(본 프롬프트)도 있다면 **그것도 2026-04-19/prompts/ 안으로 이동 완료된 상태**. 본 프롬프트는 초기 구현 에픽 결과물이 아니지만, 프롬프트 관리 일관성을 위해 기존 prompts/ 폴더에 있었으면 이동 대상에 포함.
>
> **하지만 본 프롬프트는 2026-04-20 에픽 것이므로** 이동 후 `git mv .claude/plans/2026-04-19/prompts/2026-04-20-plans-reorg-prompt.md .claude/plans/2026-04-20/2026-04-20-plans-reorg-prompt.md` 로 재조정.

### 7️⃣ git commit + push

```bash
git add -A .claude/plans/
git add -A \
  README.md README.ko.md CLAUDE.md AGENTS.md CONTRIBUTING.md NOTICES.md \
  RELEASE-CHECKLIST.md .github/DCO.md 2>/dev/null || true

# skills/, agents/, hooks/, scripts/ 등도 변경됐으면 add
for dir in skills agents hooks scripts __tests__; do
  if ! git diff --quiet "$dir/" 2>/dev/null; then
    git add -A "$dir/"
  fi
done

git status --short | head -50

git commit -s -m "$(cat <<'EOF'
chore(plans): reorganize into date-based epic folders

- 2026-04-19/: initial plugin implementation epic (W0~W8)
  - 00-recommendations/ · 01-requirements/ · 02-research/
  - 03-design/ · 04-planning/ · prompts/ · INDEX.md
- 2026-04-20/: README enhancement epic
  - readme-enhancement-requirements.md (clarify:vague output)
  - readme-enhancement-plan.md (/plan output)
  - 2026-04-20-plans-reorg-prompt.md (this sprint)

Updated all cross-references to use new paths:
- README.md · README.ko.md · CLAUDE.md · AGENTS.md · NOTICES.md
- CONTRIBUTING.md · RELEASE-CHECKLIST.md · .github/DCO.md
- .claude/plans/2026-04-19/{INDEX,03-design,04-planning,prompts}/*.md
- skills/using-harness/SKILL.md (if it referenced plans paths)

plugin.json payload_sha256 unaffected — all 3 pinned files are
outside .claude/plans/ (skills/using-harness/, hooks/*).

Git history preserved via `git mv`. Broken-link check: 0 remaining.
EOF
)"

for attempt in 1 2 3; do
  if git push origin main; then break; fi
  if [ "$attempt" -eq 3 ]; then echo "push failed 3x, abort"; exit 1; fi
  git fetch origin main
  git rebase origin/main || { echo "rebase conflict, abort"; exit 1; }
done
```

## ✅ 완료 기준

1. `.claude/plans/2026-04-19/` 아래 기존 7 서브 전부 존재
2. `.claude/plans/2026-04-20/` 아래 readme-enhancement 2 파일 존재
3. `.claude/plans/` 직속에는 **2 날짜 폴더만** 존재 (ls 결과 2 라인)
4. 전역 `grep -rn "\.claude/plans/"` 결과 모두 `2026-04-19` 또는 `2026-04-20` prefix
5. 6a broken-link 스크립트 결과 0 라인
6. git history 보존 (`git log --follow .claude/plans/2026-04-19/03-design/final-spec.md` 커밋 이력 복원 가능)
7. plugin.json SHA256 unchanged
8. push 성공

## 🛑 금지

- `references/` · `lecture/` 내부 수정
- `skills/*/SKILL.md` · `agents/*/*.md` 본문 수정 (경로 참조만 sed로 업데이트)
- `scripts/ku-harness.sh` · `scripts/update-payload-hashes.sh` 등 스크립트 재실행 (SHA256 재계산 불필요)
- 새 훅 추가
- W7.5 산출물(ku-*.json) 이동 (`.claude/state/` 외부이므로 영향 없음)
- force-push
- 3회 push 실패 시 중단

시작하세요.

# W3 Sprint 2 Chain A — T-W3-08 (AC-3 plan format unit test)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v3.1 (§10 AC 기준)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/implementation-plan.md` §W3 — T-W3-08 정의
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/prompts/_git-workflow-template.md` — **반드시 이 워크플로우 사용**
5. `/Users/ethan/Desktop/personal/harness/skills/plan/SKILL.md` — Phase 1~5 본문 + frontmatter
6. `/Users/ethan/Desktop/personal/harness/skills/plan/templates/plan-template.md` — output 스키마
7. `/Users/ethan/Desktop/personal/harness/skills/plan/templates/validate-weights.sh` — weight 합 assertion
8. `/Users/ethan/Desktop/personal/harness/skills/plan/templates/output-slug-hook.sh` — slug 검증
9. `/Users/ethan/Desktop/personal/harness/scripts/ambiguity-gate.sh` · `gap-analyzer.sh`

## 🎯 태스크

### T-W3-08 — AC-3 plan 포맷 unit test (4h) → **AC-3 Hard Gate**

**경로**: `__tests__/integration/test-ac3-plan-format.sh` (실행 가능)

**목표**: `/plan` 산출물(plan.md)의 하이브리드 포맷(Markdown 본문 + YAML frontmatter) 스키마 검증. 3 fixture 모두 통과 → **AC-3 PASS**.

> 주의: implementation-plan.md §W3 T-W3-08에 `AC-2` 표기는 오타. 실제로는 **AC-3**. 커밋 메시지·출력 로그는 AC-3로 표기.

**시나리오**:

1. **3 fixture 준비**: `__tests__/fixtures/plan-ac3/`
   - `plan-1-complete.md` — 완전한 plan.md (모든 필드·weight 1.0·Phase 1~5·유효 slug)
   - `plan-2-missing-field.md` — 의도적으로 `exit_conditions.timeout` 누락 (FAIL 기대)
   - `plan-3-invalid-weight.md` — weight 합 0.9 (FAIL 기대)

2. **검증 7 체크** (각 fixture에 대해):
   - C-1: YAML frontmatter 파싱 가능 (`yq eval '.' $file`)
   - C-2: 필수 필드 6개 존재 (`goal`·`constraints`·`AC`·`evaluation_principles`·`exit_conditions`·`parent_seed_id`)
   - C-3: `exit_conditions.success`·`failure`·`timeout` 3개 모두 null 아님
   - C-4: `evaluation_principles` weight 합 1.0±0.01 (`validate-weights.sh` 호출)
   - C-5: frontmatter `slug` 화이트리스트 통과 (`output-slug-hook.sh` 호출 또는 정규식 `^[a-zA-Z0-9_-]+$`)
   - C-6: 본문에 "Phase 1:"·"Phase 2:"·"Phase 3:"·"Phase 4:"·"Phase 5:" 모두 등장
   - C-7: 본문 길이 > 100 라인 (너무 짧으면 실질 내용 부재)

3. **기대 결과**:
   - `plan-1-complete.md`: 7/7 PASS → **PASS**
   - `plan-2-missing-field.md`: C-3 FAIL → **FAIL**
   - `plan-3-invalid-weight.md`: C-4 FAIL → **FAIL**
   - 3/3 기대 매칭 → **AC-3 PASS** (최종 stdout에 `AC-3 PASS` 출력)

**스크립트 구조**:
```bash
#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
fixtures_dir="$root/__tests__/fixtures/plan-ac3"

check_plan() {
    local file="$1"
    local expected="$2"  # "PASS" | "FAIL"
    # ... 7 체크 ...
    # actual 계산
    if [ "$actual" == "$expected" ]; then return 0; else return 1; fi
}

pass=0
for spec in "$fixtures_dir"/plan-*.md; do
    expected=$(yq eval '.test_expected' "$spec")  # fixture frontmatter에 test_expected 필드
    if check_plan "$spec" "$expected"; then pass=$((pass+1)); fi
done

if [ "$pass" -eq 3 ]; then
    echo "AC-3 PASS (3/3)"
    exit 0
else
    echo "AC-3 FAIL ($pass/3)"
    exit 1
fi
```

**Fixture 작성 가이드**:
- `plan-1-complete.md`: plan-template.md 스키마 그대로 따르며 3 principle(correctness 0.5, clarity 0.3, maintainability 0.2)·exit_conditions 3필드·Phase 1~5 각 최소 20라인
- `plan-2-missing-field.md`: plan-1 복사 후 `exit_conditions` 에서 `timeout:` 라인 제거
- `plan-3-invalid-weight.md`: plan-1 복사 후 principle weight를 (0.4, 0.3, 0.2)로 변경 (합 0.9)
- 각 fixture frontmatter에 `test_expected: PASS | FAIL` 필드 추가 (test 스크립트가 참조)

**보안 제약** (v3.1 §4.3):
- `"$var"` 쌍따옴표
- `eval` 금지
- shellcheck 통과

## 📁 산출물

- `__tests__/integration/test-ac3-plan-format.sh` (실행 가능)
- `__tests__/fixtures/plan-ac3/plan-1-complete.md`
- `__tests__/fixtures/plan-ac3/plan-2-missing-field.md`
- `__tests__/fixtures/plan-ac3/plan-3-invalid-weight.md`

## ⚙️ 실행 제약

- bash + jq + yq만 (v3 §4.1)
- 다른 파일(특히 skills/plan/SKILL.md, templates/, scripts/) 수정 금지
- 패널 B(T-W3-09)와 파일 충돌 없음: 본 패널 `__tests__/` 전담, 패널 B `skills/plan/README.md` 전담
- _git-workflow-template.md 순서 엄수

## ✅ 완료 기준

1. `test-ac3-plan-format.sh` 실행 시 `AC-3 PASS (3/3)` 출력
2. 3 fixture 기대 매칭
3. shellcheck 통과
4. 체크박스 T-W3-08 업데이트
5. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

# Step 1: pull --rebase FIRST
git pull --rebase origin main || { echo "pull failed"; exit 1; }

# Step 2: 체크박스
sed -i '' \
  -e 's|^- \[ \] \*\*T-W3-08\*\*|- [x] **T-W3-08**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

# Step 3: stage
git add __tests__/integration/test-ac3-plan-format.sh __tests__/fixtures/plan-ac3/ .claude/plans/2026-04-19/04-planning/implementation-plan.md

# Step 4: commit
git commit -s -m "$(cat <<'EOF'
feat(W3): T-W3-08 AC-3 plan format unit test

- __tests__/integration/test-ac3-plan-format.sh: 3 fixture · 7 체크 (yq·필드·weight·slug·Phase·length)
- __tests__/fixtures/plan-ac3/: complete · missing-field · invalid-weight
- AC-3 Hard Gate 3/3 기대 매칭 (PASS·FAIL·FAIL)
EOF
)"

# Step 5: push
for attempt in 1 2 3; do
  if git push origin main; then break; fi
  if [ "$attempt" -eq 3 ]; then echo "push failed 3x, abort"; exit 1; fi
  git fetch origin main
  git rebase origin/main || { echo "rebase conflict, abort"; exit 1; }
done
```

## 🛑 금지

- `skills/plan/` 수정 (Sprint 1에서 확정)
- `skills/plan/README.md` 작성 (T-W3-09 패널 B 범위)
- `final-spec.md`, `implementation-plan.md`(체크박스 제외) 수정
- push 3회 실패 시 중단

시작하세요.

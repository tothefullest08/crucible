# W3 Sprint 2 Chain B — T-W3-09 (/plan 사용 예제 한·영 README)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v3.1 (§3.1·§3.2 I/O 계약)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W3 — T-W3-09 정의
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/prompts/_git-workflow-template.md`
5. `/Users/ethan/Desktop/personal/harness/skills/plan/SKILL.md` — Phase 1~5 본문
6. `/Users/ethan/Desktop/personal/harness/skills/plan/templates/plan-template.md` — output 스키마
7. `/Users/ethan/Desktop/personal/harness/skills/brainstorm/README.md` — W2 README 패턴 참조 (한·영 예제 구조)

## 🎯 태스크

### T-W3-09 — `/plan` 사용 예제 한·영 README (4h)

**경로**: `skills/plan/README.md` (신규, 사용자용 문서)

**구조** (W2 brainstorm/README.md 패턴 준수):

- 상단: `/plan` 사용법 개요 (영어 primary + 한국어 병기)
  - 한 줄 description (v3 §1 포지셔닝 참조)
  - 언제 쓰는지·기대 산출물
  - `/brainstorm` → `/plan` → `/verify` 연결 1줄
- **영어 예제 2개**:
  1. **Feature plan** — 입력: login feature brainstorm requirements → /plan 호출 → plan.md 산출물 (hybrid Markdown + YAML frontmatter)
     - 입력 요구사항 요약 (3줄)
     - Claude의 Phase 1~5 진행 요약
     - 산출물 경로 표기 (`.claude/plans/YYYY-MM-DD-login-feature-plan.md`)
     - frontmatter 주요 필드 샘플 표기
  2. **Refactor plan** — 입력: legacy code refactor requirements → /plan 호출
     - evaluation_principles 예시 (correctness 0.5, clarity 0.3, maintainability 0.2)
     - exit_conditions 구체 예시
- **한국어 예제 2개**:
  1. **기능 계획** — 로그인 기능 요구사항 → `/plan`
     - 한국어 입력·Claude 응답 발췌
     - `evaluation_principles` 한·영 설명 병기
  2. **리팩터링 계획** — 레거시 코드 정리
     - Ambiguity Gate 동작 예시 (한국어 요구사항이 모호하면 re-`/brainstorm` 제안)
- **Integration** 섹션:
  - 입력: `/brainstorm` 산출물 (requirements.md)
  - 출력: `.claude/plans/...plan.md`
  - 다음: `/verify`, `/compound`
- **각 예제 최소 3섹션**: `### Input` → `### Claude's Phases` → `### Output`

**길이**: 300~500 라인

**검증**:
- 영어·한국어 섹션 각 2예제 이상 (h2 또는 h3 카운트)
- 각 예제 Input/Claude/Output 3 섹션 (h3 또는 h4 카운트)
- plan-template.md 참조 링크 1개 이상
- `/brainstorm`·`/verify` 상호 참조 각 1개 이상

## 📁 산출물

- `skills/plan/README.md` (신규)

## ⚙️ 실행 제약

- 영어 primary + 한국어 섹션 병기 (v3 §3.3 한국어 UX MVP)
- 다른 파일 수정 금지
- 패널 A(T-W3-08)와 파일 충돌 없음: 본 패널 `skills/plan/README.md`만, 패널 A는 `__tests__/`
- _git-workflow-template.md 순서 엄수

## ✅ 완료 기준

1. `skills/plan/README.md` 생성 (300+ 라인)
2. 영어 2 + 한국어 2 예제 (각 Input/Claude/Output 3섹션)
3. plan-template.md 링크 + `/brainstorm` · `/verify` 상호 참조
4. 체크박스 T-W3-09 업데이트
5. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

# Step 1: pull --rebase FIRST
git pull --rebase origin main || { echo "pull failed"; exit 1; }

# Step 2: 체크박스
sed -i '' \
  -e 's|^- \[ \] \*\*T-W3-09\*\*|- [x] **T-W3-09**|' \
  .claude/plans/04-planning/implementation-plan.md

# Step 3: stage
git add skills/plan/README.md .claude/plans/04-planning/implementation-plan.md

# Step 4: commit
git commit -s -m "$(cat <<'EOF'
docs(W3): T-W3-09 /plan 사용 예제 한·영 README

- skills/plan/README.md 신규 (300+ 라인)
- 영어 2 예제 + 한국어 2 예제 (각 Input/Claude/Output)
- /brainstorm → /plan → /verify 연결 문서화
- plan-template.md 링크 포함
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

- `skills/plan/SKILL.md`, `skills/plan/templates/`, `scripts/`, `__tests__/` 수정
- `final-spec.md`, `implementation-plan.md`(체크박스 제외) 수정
- T-W3-08 범위 작업 선수행
- push 3회 실패 시 중단

시작하세요.

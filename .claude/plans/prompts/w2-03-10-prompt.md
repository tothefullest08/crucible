# W2 Chain B (Sprint 2) — T-W2-03 + T-W2-10

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v3.1 (§2.2 Dec 13 한·영 병기 정책, §3.3 한국어 UX, §3.5 6축 전환점)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W2 — T-W2-03·10 정의
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/prompts/_git-workflow-template.md` — **반드시 이 워크플로우 사용**
5. `/Users/ethan/Desktop/personal/harness/skills/brainstorm/SKILL.md` (T-W2-01·02 산출)
6. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/clarify/` — description 한·영 병기 패턴 (p4cn 스타일, v3 Dec 13 선택안)
   - `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/brainstorming/` — HARD-GATE 태그 원본 (포팅 자산 #7)

## 🎯 태스크 (순차)

### T-W2-03 — description 한·영 병기 작성 (2h)

**경로**: `skills/brainstorm/SKILL.md` frontmatter의 **`description` 필드만** 수정

**목표**: v3.1 §2.2 Dec 13 MVP 정책("한·영 병기") 반영. KU-2 실증 준비.

**필수 구성**:
- **한국어 트리거 5~6개** + **영어 "Use when ..." 문장**
- 둘을 단일 description에 병기 (p4cn clarify 스타일)

**예시 (참고, 실제는 더 풍부하게)**:
```yaml
description: |
  Feature brainstorming with clarify 3-lens (vague/unknown/metamedium).
  Use when requirements are ambiguous, hidden assumptions need surfacing, or content-vs-form reframing is needed.
  트리거: "브레인스토밍", "요구사항 정리", "요구사항 명확히", "spec this out", "뭘 만들지", "아이디어 정리"
```

**주의**:
- T-W2-01이 만든 기본 description 덮어쓰기 (확장)
- 다른 frontmatter 필드 (name/when_to_use/input/output/validate_prompt) **절대 건드리지 않음**
- 본문 건드리지 않음

**검증**:
- `yq eval '.description' skills/brainstorm/SKILL.md` 가 한국어·영어 모두 포함
- 한국어 트리거 키워드 5개 이상 (간단 grep 카운트)
- 영어 "Use when" 문장 1개 이상

---

### T-W2-10 — HARD-GATE 태그 배치 (2h)

**경로**: `skills/brainstorm/SKILL.md` **본문 수정**

**목표**: superpowers HARD-GATE 패턴 (포팅 자산 #7) 차용. 구조→맥락→계획 전환 지점에 명시적 게이트 표시.

**HARD-GATE 블록 포맷** (superpowers 원본 참조):
```markdown
<!-- HARD-GATE: {axis-transition-name} -->
> ⛔ **HARD-GATE**: {설명. 이 지점 전에 다음 조건이 충족되어야 진행}
> - ✅ {조건 1}
> - ✅ {조건 2}
> - ✅ {조건 3}
<!-- /HARD-GATE -->
```

**배치 위치** (T-W2-02가 만든 Phase 1~4 사이):

1. **Phase 1 → Phase 2 게이트** (Intake → Clarify)
   - 조건: 주제 명확히 파악됨 / lens 자동 선택 완료 / 유저 동의 받음
2. **Phase 2 → Phase 3 게이트** (Clarify → Synthesize)
   - 조건: 3-Round depth pattern 완료 / 질문 cap (7-10) 이내 / 모든 critical ambiguity 해소
3. **Phase 3 → Phase 4 게이트** (Synthesize → Save)
   - 조건: Before/After 정제본 확정 / decisions 배열 채워짐 / lens 특화 산출물(stop_doing 등) 포함
4. **Phase 4 → `/plan` 연결 게이트** (Requirements → Planning)
   - 조건: requirements-template 스키마 유효 / slug 화이트리스트 통과 / next-step `/plan` 명시

**주의**:
- T-W2-01·02가 만든 Phase 헤더·본문 내용 **보존**. 게이트 블록만 **추가**.
- frontmatter 건드리지 않음 (패널 A 범위)
- description 필드 건드리지 않음 (T-W2-03 범위)

**검증**:
- 4개 HARD-GATE 블록 모두 존재 (grep으로 `<!-- HARD-GATE:` 4회 카운트)
- 각 게이트에 "✅ 조건" 3개 이상
- SKILL.md 전체 length <800 lines 유지 (context 맥락 원칙)

---

## 📁 산출물

- `skills/brainstorm/SKILL.md` (T-W2-03: `description` 필드 수정 / T-W2-10: 본문에 HARD-GATE 블록 4개 추가)

## ⚙️ 실행 제약

- **한국어 주석 · description 한·영 병기**
- **파일 충돌 대비**: 패널 A와 같은 `skills/brainstorm/SKILL.md` 수정. 단 다른 영역:
  - 패널 A(T-W2-05): frontmatter에 `validate_prompt` 필드 **신규 추가**
  - 본 패널 B(T-W2-03): frontmatter `description` 필드 **수정**
  - 본 패널 B(T-W2-10): **본문**에 HARD-GATE 블록 **추가**
  - 이론상 rebase 자동 merge 가능. 충돌 시 수동 해결 (본인 변경분 유지 + 패널 A 변경분 흡수).
- **_git-workflow-template.md 워크플로우 엄수** (pull 먼저!)
- 레퍼런스 수정 금지
- final-spec.md · implementation-plan.md(체크박스 제외) 수정 금지
- 다른 파일(hooks/, scripts/, __tests__/, templates/) 건드리지 않음

## ✅ 완료 기준

1. T-W2-03 description 한·영 병기 (한국어 트리거 5개 이상 + 영어 Use when)
2. T-W2-10 HARD-GATE 블록 4개 배치 + 각 조건 3개 이상
3. SKILL.md 길이 <800 lines 유지
4. 체크박스 T-W2-03·10 업데이트
5. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시 (개선된 순서)

**⚠️ `_git-workflow-template.md` 순서 엄수**

```bash
cd /Users/ethan/Desktop/personal/harness

# Step 1: pull --rebase FIRST
git pull --rebase origin main || { echo "pull failed"; exit 1; }

# Step 2: 체크박스 (sed)
sed -i '' \
  -e 's|^- \[ \] \*\*T-W2-03\*\*|- [x] **T-W2-03**|' \
  -e 's|^- \[ \] \*\*T-W2-10\*\*|- [x] **T-W2-10**|' \
  .claude/plans/04-planning/implementation-plan.md

# Step 3: stage
git add skills/brainstorm/SKILL.md .claude/plans/04-planning/implementation-plan.md

# Step 4: commit (DCO sign-off)
git commit -s -m "$(cat <<'EOF'
feat(W2): T-W2-03·10 description 한·영 병기 + HARD-GATE 태그

- skills/brainstorm/SKILL.md frontmatter.description: 한국어 트리거 5+ + Use when
- skills/brainstorm/SKILL.md 본문: Phase 전환점 4개에 HARD-GATE 블록 배치
- 포팅 자산 #7 (superpowers HARD-GATE 패턴) 적용
EOF
)"

# Step 5: push (재시도 3회)
for attempt in 1 2 3; do
  if git push origin main; then break; fi
  if [ "$attempt" -eq 3 ]; then echo "push failed 3x, abort"; exit 1; fi
  git fetch origin main
  git rebase origin/main || { echo "rebase conflict, abort"; exit 1; }
done
```

## 🛑 금지

- `skills/brainstorm/SKILL.md` frontmatter의 **`validate_prompt` 필드** 건드리기 (T-W2-05 패널 A 범위)
- `skills/brainstorm/SKILL.md` frontmatter의 **name/when_to_use/input/output** 수정
- `skills/brainstorm/templates/`, `hooks/`, `scripts/`, `__tests__/`, `skills/brainstorm/README.md` 수정
- T-W2-05·06·07·09 선수행
- final-spec.md, references/ 수정
- push 3회 실패 시 중단

시작하세요.

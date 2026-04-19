# W2 Chain B — T-W2-04 + T-W2-08 (output 템플릿 + slug 보안 smoke test)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v3.1 (**§4.3 보안 제약** 특히 slug 화이트리스트, §3.1 user story #1 brainstorm 출력 경로)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W2 — T-W2-04·08 정의
4. `/Users/ethan/Desktop/personal/harness/__tests__/security/custom-security-linter.sh` (T-W1-09 산출, R3 slug 화이트리스트 패턴 참조)
5. `/Users/ethan/Desktop/personal/harness/__tests__/security/run.sh` (entry point 패턴 참조)

## 🎯 태스크 (순차)

### T-W2-04 — output 템플릿 + slug 화이트리스트 (2h) 🚨 P0-8

**목표**: `/brainstorm` 스킬의 output 파일 포맷 규격. 저장 경로: `.claude/plans/YYYY-MM-DD-{slug}-requirements.md`. slug는 화이트리스트 `[a-zA-Z0-9_-]` 이외 문자 주입 시 reject.

**경로**:
- `skills/brainstorm/templates/requirements-template.md` (템플릿)
- `skills/brainstorm/templates/slug-validator.sh` (slug 검증 bash 함수)

**템플릿 스키마** (`requirements-template.md`):
```markdown
---
lens: {vague | unknown | metamedium}    # lens 식별
topic: "{주제 (≤ 120자)}"
slug: "{slug (화이트리스트 통과)}"
date: "{YYYY-MM-DD}"
decisions:
  - question: "{질문}"
    answer: "{응답}"
    reasoning: "{근거}"
stop_doing:    # unknown lens 필수, 그 외 선택
  - "{항목}"
---

# {topic}

## Before
"{원본 발화 verbatim}"

## After
### Goal
{구체 목표}

### Scope
- Included: [...]
- Excluded: [...]

### Constraints
{제약사항}

### Success Criteria
{완료 판정 기준}

## Decisions (auto-filled from frontmatter)

## Stop Doing (unknown lens only)
```

**slug 검증 bash 함수** (`slug-validator.sh`):
- 입력: `$1` = 후보 slug 문자열
- 동작:
  - 화이트리스트: `^[a-zA-Z0-9_-]+$` 정규식
  - 길이 제한: 1~64자
  - 통과: exit 0 + stdout `<slug>` 그대로
  - 실패: exit 1 + stderr `INVALID SLUG: <reason>`
- 예시 reject 케이스 (smoke test로 검증): `../../etc/passwd`, `slug with space`, `slug;rm`, `slug$(echo)`, `` slug`whoami` ``
- `"$var"` 쌍따옴표 + `eval` 금지 + shellcheck 통과

**검증**: bash -n + shellcheck 통과

---

### T-W2-08 — slug 화이트리스트 smoke test (2h) 🚨 P0-8

**목표**: T-W2-04의 `slug-validator.sh`에 대한 injection payload 5종 smoke test. 모두 reject 확인.

**경로**: `__tests__/security/slug-smoke.sh`

**Injection payload 5종** (fixtures):
- `__tests__/security/fixtures/slug-injection/`
  - `payload-1-path-traversal.txt`: `../../etc/passwd`
  - `payload-2-whitespace.txt`: `slug with space`
  - `payload-3-semicolon.txt`: `slug;rm -rf /`
  - `payload-4-command-sub.txt`: `slug$(whoami)`
  - `payload-5-backtick.txt`: `slug\`whoami\``

**Smoke test 로직**:
```bash
#!/usr/bin/env bash
set -euo pipefail

for payload_file in __tests__/security/fixtures/slug-injection/*.txt; do
    payload=$(cat "$payload_file")
    if bash skills/brainstorm/templates/slug-validator.sh "$payload" > /dev/null 2>&1; then
        echo "FAIL: $payload_file PASSED slug-validator (should have been rejected)"
        exit 1
    fi
done

# PASS case 검증
if ! bash skills/brainstorm/templates/slug-validator.sh "valid_slug-123" > /dev/null 2>&1; then
    echo "FAIL: valid_slug-123 rejected (should pass)"
    exit 1
fi

echo "slug-smoke PASS: 5/5 injection rejected + 1/1 valid accepted"
```

**`__tests__/security/run.sh` 업데이트**: 기존 runner에 `bash __tests__/security/slug-smoke.sh` 호출 추가.

**검증**:
- 5개 injection 모두 reject (exit 1)
- valid slug `valid_slug-123` accept (exit 0)
- `bash __tests__/security/slug-smoke.sh` 최종 출력 `PASS`

---

## 📁 산출물

- `skills/brainstorm/templates/requirements-template.md`
- `skills/brainstorm/templates/slug-validator.sh` (실행 가능)
- `__tests__/security/slug-smoke.sh` (실행 가능)
- `__tests__/security/fixtures/slug-injection/payload-{1..5}-*.txt` (5개)
- `__tests__/security/run.sh` (slug-smoke 호출 한 줄 추가)

## ⚙️ 실행 제약

- **패널 A와 파일 충돌 없음**: 본 패널은 `skills/brainstorm/templates/` + `__tests__/security/`. 패널 A는 `skills/brainstorm/SKILL.md`만.
- **`__tests__/security/run.sh`는 기존 파일 수정** — git rebase 시 충돌 주의. 한 줄 추가만 (`bash __tests__/security/slug-smoke.sh`)
- bash + shellcheck만 (v3 §4.1)
- slug 화이트리스트 정확히 `[a-zA-Z0-9_-]` (final-spec §4.3 그대로)
- final-spec.md · implementation-plan.md(체크박스 제외) 수정 금지

## ✅ 완료 기준

1. T-W2-04 템플릿 + slug-validator shellcheck 통과 + 수동 테스트 (valid/invalid 각 1회)
2. T-W2-08 smoke test 5/5 injection reject + 1/1 valid accept
3. 체크박스 T-W2-04·08 업데이트
4. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

# 1. 체크박스
sed -i '' \
  -e 's|^- \[ \] \*\*T-W2-04\*\*|- [x] **T-W2-04**|' \
  -e 's|^- \[ \] \*\*T-W2-08\*\*|- [x] **T-W2-08**|' \
  .claude/plans/04-planning/implementation-plan.md

# 2. pull rebase
git pull --rebase origin main

# 3. stage (본인 영역만)
git add skills/brainstorm/templates/ __tests__/security/slug-smoke.sh __tests__/security/fixtures/slug-injection/ __tests__/security/run.sh .claude/plans/04-planning/implementation-plan.md

# 4. commit (DCO sign-off)
git commit -s -m "$(cat <<'EOF'
feat(W2): T-W2-04·08 output 템플릿 + slug 화이트리스트 smoke

- skills/brainstorm/templates/requirements-template.md: lens/topic/slug/decisions/stop_doing 스키마
- skills/brainstorm/templates/slug-validator.sh: [a-zA-Z0-9_-] 화이트리스트 1~64자
- __tests__/security/slug-smoke.sh: 5 injection payload + valid slug 검증
- __tests__/security/fixtures/slug-injection/: path-traversal·whitespace·semicolon·cmd-sub·backtick
- __tests__/security/run.sh: slug-smoke 호출 추가
- 🚨 P0-8 (훅·파일명 보안) 강화
EOF
)"

# 5. push (재시도 3회)
git push origin main || (git pull --rebase origin main && git push origin main) || (git pull --rebase origin main && git push origin main)
```

## 🛑 금지

- `skills/brainstorm/SKILL.md` 수정 (패널 A 범위)
- `hooks/`, `scripts/`, `.claude-plugin/`, `final-spec.md` 수정
- T-W2-03·05·06·07·09·10 작업 선수행 (다음 sprint)
- `eval` 또는 화이트리스트 외 문자를 slug에 허용하는 코드 작성
- push 3회 실패 시 중단 + 알림

시작하세요.

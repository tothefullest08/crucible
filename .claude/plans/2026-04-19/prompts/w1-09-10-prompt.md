# W1 Chain C — T-W1-09 + T-W1-10 (hooks 보안 unit test + integration AC-1)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v3.1 **§4.3 보안 제약** (쌍따옴표·eval 금지·slug 화이트리스트)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/implementation-plan.md` §W1 — T-W1-09·10 정의
4. `/Users/ethan/Desktop/personal/harness/hooks/session-start.sh` — 보안 linter 검증 대상 (T-W1-04 산출)
5. `/Users/ethan/Desktop/personal/harness/.claude-plugin/plugin.json` + `marketplace.json` — 설치 단위
6. `/Users/ethan/Desktop/personal/harness/skills/using-harness/SKILL.md` — SessionStart 페이로드

## 🎯 태스크 (순차)

### T-W1-09 — `hooks` bash 보안 unit test (2h) 🚨 P0-8

**목표**: hooks/*.sh 스크립트에 대한 보안 lint + shellcheck 자동 검증. shellcheck + 커스텀 보안 linter 2종 모두 통과.

**경로**: `__tests__/security/`
- `shellcheck-runner.sh` — shellcheck 실행 래퍼 (모든 hooks/*.sh 순회, 경고 0 요구)
- `custom-security-linter.sh` — 아래 3종 보안 규칙 검증:
  1. 변수 참조 `"$var"` 쌍따옴표 강제 (`grep -E '\$[a-zA-Z_]' | grep -vE '"\$[a-zA-Z_]'`가 검출 시 FAIL)
  2. `eval` 사용 0회 (`grep -wE 'eval'` 검출 시 FAIL)
  3. 파일 경로 생성 시 slug 화이트리스트 `[a-zA-Z0-9_/.-]` 이외 문자 보간 감지
- `run.sh` — 위 2개를 모두 실행하는 엔트리 포인트 (CI에서 호출)

**검증 대상 파일**:
- `hooks/session-start.sh` (T-W1-04 산출)
- 이후 추가될 `hooks/*.sh` 전체 (glob)

**Fixture**:
- `__tests__/security/fixtures/`
  - `bad-unquoted.sh` — 의도적으로 `$var` 미인용 포함 (FAIL 기대)
  - `bad-eval.sh` — 의도적으로 `eval` 포함 (FAIL 기대)
  - `good.sh` — 모든 규칙 준수 (PASS 기대)

**완료 기준**:
- `bash __tests__/security/run.sh` 실행 시 real `hooks/session-start.sh` PASS
- Fixture 3종에 대해 기대대로 PASS/FAIL 판정
- 모든 테스트 로직 bash+grep만 사용 (Python/Node 금지)

---

### T-W1-10 — integration test → **AC-1** (2h)

**목표**: 플러그인 설치 → SessionStart 훅 발화 → `using-harness.md` 페이로드 주입 end-to-end 검증. **AC-1 Hard Gate 충족 확인**.

**경로**: `__tests__/integration/`
- `test-ac1-install-sessionstart.sh` — AC-1 검증 엔트리 포인트

**시나리오**:
```
1. plugin.json + marketplace.json 구조 JSON 유효성 재검증
2. hooks/session-start.sh 실행 가능 권한 확인 (-x)
3. hooks/session-start.sh 실제 실행 (stdout 캡처)
4. stdout에 skills/using-harness/SKILL.md 본문(최소 헤더 1줄) 포함 검증
5. 보안 linter (T-W1-09 run.sh) 호출하여 PASS 확인
```

Claude Code **실제 설치** 대신 **설치 준비 상태 검증**:
- Claude Code 실세션에서 직접 확인은 유저 수동 작업 (T-W7.5 하드닝에서 스모크 테스트)
- 이 단계에서는 "플러그인 패키지가 Claude Code 설치 인터페이스 규격을 만족하는지"만 자동 검증

**체크 항목**:
- [ ] plugin.json에 필수 필드 5종 (name/version/description/author/license) 전부 존재
- [ ] marketplace.json plugins[0].name == plugin.json.name
- [ ] hooks/hooks.json에 SessionStart·UserPromptSubmit·PostToolUse·Stop 4이벤트 등록
- [ ] hooks/session-start.sh 존재 + 실행 권한 + shellcheck 통과
- [ ] skills/using-harness/SKILL.md frontmatter 파싱 가능 (name/description)
- [ ] 실행 시 stdout에 SKILL.md 첫 100 bytes 포함

**완료 기준**:
- `bash __tests__/integration/test-ac1-install-sessionstart.sh` 실행 시 6개 체크 모두 PASS
- 실패 시 명확한 에러 메시지 (어느 체크가 왜 실패했는지)
- **AC-1 Hard Gate 충족 확인 보고** (마지막 출력에 `AC-1 PASS` 표기)

---

## 📁 산출물

- `__tests__/security/shellcheck-runner.sh`
- `__tests__/security/custom-security-linter.sh`
- `__tests__/security/run.sh`
- `__tests__/security/fixtures/{bad-unquoted,bad-eval,good}.sh`
- `__tests__/integration/test-ac1-install-sessionstart.sh`

## ⚙️ 실행 제약

- **bash + grep + jq + shellcheck만** (v3 §4.1)
- 다른 패널(T-W1-08 CI)과 파일 충돌 없음:
  - 본 패널: `__tests__/security/`, `__tests__/integration/`
  - T-W1-08: `.github/workflows/`
- 레퍼런스 수정 금지
- `final-spec.md`, `implementation-plan.md`(체크박스 제외) 수정 금지

## ✅ 완료 기준

1. T-W1-09 산출물 5개 + 실행 `bash run.sh` PASS
2. T-W1-10 산출물 1개 + 실행 시 `AC-1 PASS` 출력
3. 체크박스 T-W1-09·10 업데이트
4. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시 (필수)

```bash
cd /Users/ethan/Desktop/personal/harness

# 1. 체크박스
sed -i '' \
  -e 's|^- \[ \] \*\*T-W1-09\*\*|- [x] **T-W1-09**|' \
  -e 's|^- \[ \] \*\*T-W1-10\*\*|- [x] **T-W1-10**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

# 2. pull rebase
git pull --rebase origin main

# 3. stage
git add __tests__/security/ __tests__/integration/ .claude/plans/2026-04-19/04-planning/implementation-plan.md

# 4. commit (DCO sign-off)
git commit -s -m "$(cat <<'EOF'
feat(W1): T-W1-09·10 hooks 보안 linter + AC-1 integration test

- __tests__/security/: shellcheck + 커스텀 보안 linter 2종 (쌍따옴표·eval 금지·slug 화이트리스트)
- __tests__/security/fixtures/: bad-unquoted·bad-eval·good 3 fixture
- __tests__/integration/test-ac1-install-sessionstart.sh: 6체크 AC-1 Hard Gate 검증
- 🚨 P0-8 (훅 보안) 완화
- 체크박스 T-W1-09·10 업데이트
EOF
)"

# 5. push (재시도 3회)
git push origin main || (git pull --rebase origin main && git push origin main) || (git pull --rebase origin main && git push origin main)
```

## 🛑 금지

- `.github/workflows/` 작성 (T-W1-08 범위, 다른 패널)
- `hooks/`, `skills/`, `scripts/`, `.claude-plugin/` 수정 (이전 태스크에서 완료)
- `final-spec.md`, references/ 수정
- push 3회 실패 시 중단 + 알림

시작하세요.

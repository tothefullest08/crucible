# W1 Chain B (종결) — T-W1-08 (CI JSONL 72h smoke test)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — **v3.1 §4.2.3 72h smoke 체크리스트** (C-1~C-5)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W1 — T-W1-08 정의
4. `/Users/ethan/Desktop/personal/harness/scripts/extract-session.sh` + `scripts/schema-adapter.sh` — T-W1-06·07 산출, CI가 호출할 대상

## 🎯 태스크

### T-W1-08 — CI JSONL 72h smoke test (4h) 🚨 P0-2

**목표**: GitHub Actions cron으로 3일(72h)마다 JSONL 스키마 smoke test 자동 실행. `final-spec v3.1 §4.2.3` 체크리스트 C-1~C-5 전부 자동 검증.

**핵심 파일**: `.github/workflows/jsonl-smoke.yml`

**cron 스케줄**:
- `cron: '0 9 */3 * *'` (UTC 09:00 매 3일마다 ≈ 72h 간격)
- + `workflow_dispatch:` 수동 트리거도 허용

**Job 구성** (단일 job, ubuntu-latest):

#### Step 1: Checkout + 환경 셋업
- `actions/checkout@v4`
- bash·jq 설치 확인 (ubuntu-latest 기본 제공)
- shellcheck 설치

#### Step 2: v3.1 §4.2.3 체크리스트 실행 (5가지)
각 체크는 별도 step으로. 실패 시 CI fail + Slack/이슈 알림 placeholder.

**C-1. JSONL 파싱 에러율 < 5%**
- 방법: 저장소에 `__tests__/fixtures/jsonl-smoke/` 레퍼런스 JSONL 샘플 제공 (100줄 이상)
- 실행: `scripts/extract-session.sh <fixture>` + stderr line 수 / total line 수 계산
- 임계: 5% 초과 시 FAIL

**C-2. unknown type 출현 여부**
- 방법: `scripts/schema-adapter.sh < <fixture>` 실행 후 stderr에 `unknown dispatch:` 라인 수 집계
- 임계: >0 시 WARN (FAIL 아님). 신규 type 출현 알림.

**C-3. schema_version 분포 변화 감지**
- 방법: 지난 주 snapshot(`__tests__/fixtures/jsonl-smoke/last-known-distribution.json`)과 현재 fixture 분포 비교
- 임계: 특정 버전 비중 > 90% 변화 시 FAIL (예: v0이 90% → 이번 주 50%면 FAIL)
- last-known-distribution.json은 본 PR에서 초기값 생성 (현재 fixture 분포 그대로)

**C-4. adapter dispatch 누락 카운트 = 0**
- 방법: schema-adapter.sh 출력 line 수 + stderr skip 수 합 == input line 수 검증
- 임계: 불일치 시 FAIL

**C-5. Claude Code 최근 릴리스 72h 내 여부 + 키워드 grep**
- 방법: GitHub API로 `anthropics/claude-code` (또는 Claude Code 공식 저장소) 최근 릴리스 조회 — `gh release list -R anthropics/claude-code --limit 5 --json publishedAt,body`
- 72h 내 릴리스 body에 `jsonl`·`session`·`schema` 키워드 grep
- 해당 시 CI에 WARN 이슈 생성 (Claude Code 측 포맷 변화 가능성) — placeholder로 `echo`만, 실제 이슈 생성은 유저 수동 결정

#### Step 3: 결과 리포트
- smoke-report.json 생성 (체크 항목별 PASS/WARN/FAIL)
- FAIL 1건 이상 시 job exit 1
- WARN만 있으면 exit 0 but 로그 남김

#### Step 4: 알림 placeholder
- FAIL 시 GitHub Issue 생성 (`actions/github-script@v7` 사용) — 초안 코멘트:
  ```
  JSONL smoke FAIL at {timestamp}
  Failing checks: {C-X, C-Y}
  See run: {actions_url}
  ```
- 실제 동작은 `if: failure()` + placeholder `echo` (초기 릴리스에선 로그만)

### 필수 fixture 생성

`__tests__/fixtures/jsonl-smoke/`:
- `baseline.jsonl` — 실제 `~/.claude/projects/*.jsonl` 구조를 모방한 100줄 이상 샘플 (p4cn session-file-format.md 참조). 정상 + 일부 unknown type + schema_version v0·v1 mix.
- `last-known-distribution.json`:
  ```json
  {
    "snapshot_date": "2026-04-19",
    "total_lines": 100,
    "by_type": {"file-history-snapshot": 67, "queue-operation": 27, "prompt": 6},
    "by_schema_version": {"v0": 95, "v1": 5}
  }
  ```
- baseline.jsonl은 **합성 데이터** (실 세션 캡처 금지, 개인정보 섞일 수 있음)

### 완료 기준

1. `.github/workflows/jsonl-smoke.yml` 생성 + YAML 유효성 (`yq eval` 또는 `actionlint`)
2. 수동 트리거 로컬 테스트: `bash` 상에서 workflow 각 step의 shell 명령을 직접 실행해서 PASS/FAIL 판단 가능한 상태 (전체 actions 구조는 GitHub에서 실행됨)
3. `__tests__/fixtures/jsonl-smoke/baseline.jsonl` + `last-known-distribution.json`
4. 체크박스 T-W1-08 업데이트
5. 자체 커밋+푸시

---

## 📁 산출물

- `.github/workflows/jsonl-smoke.yml`
- `__tests__/fixtures/jsonl-smoke/baseline.jsonl` (100줄 이상)
- `__tests__/fixtures/jsonl-smoke/last-known-distribution.json`

## ⚙️ 실행 제약

- **GitHub Actions YAML + bash + jq만** (v3 §4.1)
- 합성 JSONL fixture만 (실세션 JSONL 복사 금지 — 개인정보)
- 다른 패널(T-W1-09·10)과 파일 충돌 없음:
  - 본 패널: `.github/workflows/`, `__tests__/fixtures/jsonl-smoke/`
  - T-W1-09·10: `__tests__/security/`, `__tests__/integration/`

## ✅ 완료 기준

1. workflow YAML + fixture 2개 생성
2. YAML 유효 (shellcheck는 workflow 내 bash 블록 일부만 대상)
3. 체크박스 T-W1-08 업데이트
4. 자체 커밋+푸시

---

## 🔄 완료 후 자동 커밋+푸시 (필수)

```bash
cd /Users/ethan/Desktop/personal/harness

# 1. 체크박스
sed -i '' \
  -e 's|^- \[ \] \*\*T-W1-08\*\*|- [x] **T-W1-08**|' \
  .claude/plans/04-planning/implementation-plan.md

# 2. pull rebase
git pull --rebase origin main

# 3. stage
git add .github/workflows/ __tests__/fixtures/jsonl-smoke/ .claude/plans/04-planning/implementation-plan.md

# 4. commit (DCO sign-off)
git commit -s -m "$(cat <<'EOF'
feat(W1): T-W1-08 CI JSONL 72h smoke test (GitHub Actions cron)

- .github/workflows/jsonl-smoke.yml: 3일 cron + workflow_dispatch, v3.1 §4.2.3 C-1~C-5 체크
- __tests__/fixtures/jsonl-smoke/baseline.jsonl: 합성 100+ 라인 (실세션 복사 금지)
- last-known-distribution.json: 초기 분포 스냅샷
- 🚨 P0-2 (JSONL 스키마 안정성) 자동 감시
- 체크박스 T-W1-08 업데이트
EOF
)"

# 5. push (재시도 3회)
git push origin main || (git pull --rebase origin main && git push origin main) || (git pull --rebase origin main && git push origin main)
```

## 🛑 금지

- `__tests__/security/`, `__tests__/integration/` 작성 (T-W1-09·10 범위, 다른 패널)
- `hooks/`, `skills/`, `scripts/`, `.claude-plugin/` 수정
- `final-spec.md` 수정
- 실세션 JSONL 파일 복사 (개인정보)
- push 3회 실패 시 중단 + 알림

시작하세요.

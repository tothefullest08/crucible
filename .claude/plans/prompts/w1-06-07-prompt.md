# W1 Chain B — T-W1-06 + T-W1-07 (extract-session.sh + schema-adapter.sh)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — **v3.1 §4.2 정식 사양** (어댑터 타입 시그니처·3단 fallback·72h smoke·degradation UX) 반드시 준수
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W1 — T-W1-06·07 정의
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/02-research/plugins-for-claude-natives.md` — p4cn history-insight 원본 패턴
5. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/history-insight/` 하위 스크립트 (핵심 원본)
   - `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/history-insight/docs/session-file-format.md` (JSONL 포맷 역공학 문서)

## 🎯 태스크 (순차)

### T-W1-06 — `scripts/extract-session.sh` (6h) 🚨 P0-1 🚨 P0-2

**목표**: p4cn history-insight를 **bash+jq로 재작성**한 Claude Code 세션 JSONL 파서. Python 원본 포팅 금지 (v3 §4.1).

**경로**: `scripts/extract-session.sh` (실행 가능, chmod +x)
**셰뱅**: `#!/usr/bin/env bash`

**입력**:
- `$1` (선택): 프로젝트 CWD (기본값: `$PWD`)
- CWD를 `~/.claude/projects/` 경로 인코딩 규칙으로 변환 (슬래시 → 하이픈 등, p4cn 참조)

**출력**:
- stdout: 정규화된 턴 리스트 JSON (array of objects)
- 각 객체 구조: `{"turn_index", "role", "content", "timestamp", "type", "schema_version"}`

**에러 처리** (v3.1 §4.2 방어적 파서):
- 손상 JSONL 라인 → skip + stderr 로그
- unknown `type` → skip + stderr 로그 (schema_version 분포는 집계)
- 파일 없음 → exit 1 + 명확한 에러 메시지
- `jq` 미설치 → exit 2 + 설치 가이드

**보안 제약** (v3.1 §4.3):
- `"$var"` 쌍따옴표
- `eval` 금지
- 파일 경로 slug `[a-zA-Z0-9_/.-]` 검증
- jq filter에 유저 입력 직접 보간 금지 (--arg 사용)
- `set -euo pipefail`

**unit test 3종** (T-W1-09에서 사용할 fixture 준비):
- 경로: `__tests__/fixtures/extract-session/`
  - `normal.jsonl` (정상 3턴)
  - `unknown-type.jsonl` (정상 2턴 + unknown type 1턴)
  - `corrupted.jsonl` (정상 2턴 + 손상 라인 1개)

**검증**:
- `shellcheck scripts/extract-session.sh` 통과
- 3개 fixture에 대해 기대 출력 산출 (unit test는 T-W1-09 범위이지만, fixture는 여기서 생성)

---

### T-W1-07 — `scripts/schema-adapter.sh` (4h) 🚨 P0-2

**목표**: v3.1 §4.2.1 어댑터 타입 시그니처를 bash+jq로 구현. `extract-session.sh`가 이 어댑터를 호출.

**경로**: `scripts/schema-adapter.sh` (실행 가능, chmod +x)
**셰뱅**: `#!/usr/bin/env bash`

**기능** (v3.1 §4.2.1 스펙 그대로):
```
입력: JSONL 라인 (stdin)
처리:
  1. .type 필드 추출: jq -r '.type // "unknown"'
  2. .schema_version 필드 추출: jq -r '.schema_version // "v0"'
  3. (type, schema_version) 쌍을 adapter 함수로 dispatch
  4. 함수 매핑표:
     - "file-history-snapshot-v0" → parse_fhs_v0
     - "queue-operation-v0" → parse_queue_v0
     - "prompt-v0" → parse_prompt_v0
     (최소 3개 type 파서)
  5. 매핑 없는 경우 → skip + stderr 로그 ("unknown dispatch: $type v$schema_version")
출력: 정규화된 JSON (stdout)
```

**adapter 함수 규약**:
- 각 함수는 stdin에서 JSONL 라인 받음
- stdout으로 정규화된 JSON 객체 하나 출력
- 에러 시 stderr로 로그 + 빈 출력 (호출 측이 skip 처리)

**bash 함수 선언** (`hash dispatch` 패턴):
```bash
declare -A ADAPTERS
ADAPTERS["file-history-snapshot-v0"]="parse_fhs_v0"
ADAPTERS["queue-operation-v0"]="parse_queue_v0"
ADAPTERS["prompt-v0"]="parse_prompt_v0"
```

**unit test** (fixture 재사용):
- `__tests__/fixtures/schema-adapter/`
  - `three-types.jsonl` (3종 타입 각 1라인)
  - `unknown-dispatch.jsonl` (알 수 없는 type 포함)

**검증**:
- `shellcheck scripts/schema-adapter.sh` 통과
- 3개 버전 JSONL 샘플에서 모두 적절한 adapter 함수 dispatch

---

## 📁 산출물

- `scripts/extract-session.sh`
- `scripts/schema-adapter.sh`
- `__tests__/fixtures/extract-session/{normal,unknown-type,corrupted}.jsonl`
- `__tests__/fixtures/schema-adapter/{three-types,unknown-dispatch}.jsonl`

## ⚙️ 실행 제약

- **bash+jq만** — Python/Node 금지 (v3 §4.1)
- **v3.1 §4.2 사양 그대로 구현** — 어댑터 타입 시그니처·3개 타입 파서·unknown skip-and-continue
- **레퍼런스 수정 금지** — references/ read-only
- **다른 패널과 파일 충돌 없음**:
  - 패널 1이 hooks/session-start, skills/using-harness/ 건드림 (충돌 없음)
  - 패널 3이 루트 docs 건드림 (충돌 없음)
  - 패널 4가 04-planning/s11-3-ux-draft.md 건드림 (충돌 없음)

## ✅ 완료 기준

1. `scripts/extract-session.sh` + `scripts/schema-adapter.sh` 둘 다 shellcheck 통과
2. 5개 fixture JSONL 생성 (3개 extract + 2개 adapter)
3. 수동 테스트: `bash scripts/extract-session.sh` + `bash scripts/schema-adapter.sh < fixture` 성공
4. 체크박스 업데이트 + 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시 워크플로우 (필수)

```bash
# 1. implementation-plan 체크박스
sed -i '' \
  -e 's|^- \[ \] \*\*T-W1-06\*\*|- [x] **T-W1-06**|' \
  -e 's|^- \[ \] \*\*T-W1-07\*\*|- [x] **T-W1-07**|' \
  .claude/plans/04-planning/implementation-plan.md

# 2. pull rebase
cd /Users/ethan/Desktop/personal/harness && git pull --rebase origin main

# 3. stage
git add scripts/ __tests__/ .claude/plans/04-planning/implementation-plan.md

# 4. commit
git commit -m "$(cat <<'EOF'
feat(W1): T-W1-06·07 JSONL 파서 + schema adapter (bash+jq)

- scripts/extract-session.sh: Claude JSONL 파서, p4cn history-insight bash 재작성, 🚨 P0-1·P0-2
- scripts/schema-adapter.sh: v3.1 §4.2.1 어댑터 타입 시그니처 (3 타입 파서 + unknown skip)
- __tests__/fixtures/: 5개 JSONL fixture (extract 3 + adapter 2)
- 체크박스 T-W1-06·07 업데이트
EOF
)"

# 5. push (재시도 3회)
git push origin main || (git pull --rebase origin main && git push origin main) || (git pull --rebase origin main && git push origin main)
```

## 🛑 금지

- `hooks/`, `skills/`, `.claude-plugin/` 수정 (다른 패널 범위)
- `final-spec.md` 수정
- Python/Node 스크립트 작성
- references/ 수정
- push 3회 실패 시 중단 + 알림

시작하세요.

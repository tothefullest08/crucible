# W4 Sprint 1 Chain B — T-W4-05 + T-W4-06 (페이로드 SHA256 + Secrets redaction)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — **v3.2** (§4.3.1~§4.3.7 보안 제약 전체)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W4 — T-W4-05·06
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/prompts/_git-workflow-template.md`
5. `/Users/ethan/Desktop/personal/harness/skills/verify/SKILL.md` (T-W4-01 스켈레톤, frontmatter validate_prompt 보강 대상)
6. `/Users/ethan/Desktop/personal/harness/.claude-plugin/plugin.json` (T-W4-05에서 `harness.payload_sha256` 필드 추가)
7. `/Users/ethan/Desktop/personal/harness/hooks/session-start.sh` (T-W4-05에서 해시 검증 구현)

## 🎯 태스크 (순차)

### T-W4-05 — validate_prompt + 페이로드 SHA256 해시 검증 (4h) 🚨 P0-8 → AC

**경로**:
- `.claude-plugin/plugin.json` 에 `harness.payload_sha256` 객체 추가 (v3.2 §4.3.5 참조)
- `hooks/session-start.sh` 에 해시 검증 로직 구현
- `scripts/update-payload-hashes.sh` 신규 (개발자용 해시 갱신 도구)

**동작** (v3.2 §4.3.5 스펙 그대로):
1. `plugin.json.harness.payload_sha256` 객체: 각 파일 경로 → 기대 SHA256
2. `session-start.sh` 실행 초기에 `sha256sum` (or `shasum -a 256`)으로 현재 해시 계산
3. plugin.json 값과 비교
4. 불일치 시 stderr `WARN: payload hash mismatch for <file>` + 해당 페이로드 주입 스킵 + `exit 0` (세션 차단 금지)
5. `update-payload-hashes.sh` 실행 시 `jq`로 plugin.json의 해시 필드 in-place 갱신

**대상 파일**:
- `skills/using-harness/SKILL.md`
- `hooks/session-start.sh`
- `hooks/validate-output.sh`
- (향후 추가 훅은 개발자가 수동 등록)

**Fixture·검증**:
- `__tests__/security/fixtures/hash-mismatch/` — 의도 변조된 파일 사본 3개
- `__tests__/security/test-payload-hash.sh` — 해시 변조 시 3/3 주입 거부 실측

### T-W4-06 — Secrets redaction 정규식 7종 (6h) 🚨 P0-5

**경로**: `scripts/secrets-redaction.sh` (신규, 실행 가능)

**목표**: v3 §4.3.3에서 채택한 **범용 7종 secrets 정규식** 구현 + drop 시 `{redacted: N}` 기록 (user-decisions-5 §1).

**7종 정규식**:
1. **AWS Access Key**: `AKIA[0-9A-Z]{16}`
2. **GCP Service Account**: `AIza[0-9A-Za-z\-_]{35}`
3. **GitHub PAT**: `gh[ops]_[0-9A-Za-z]{36}`
4. **Slack Token**: `xox[baprs]-[0-9A-Za-z\-]{10,}`
5. **JWT**: `eyJ[A-Za-z0-9\-_]+\.eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+`
6. **DB URL**: `(postgres|mysql|mongodb|redis)://[^\s@]+@[^\s/]+`
7. **Bearer Token**: `Bearer\s+[A-Za-z0-9\-._~+/]{20,}=*`

**동작**:
1. stdin으로 텍스트 수신
2. 7 정규식 중 하나라도 매칭 → 해당 턴(line or block) drop
3. drop된 턴 수를 `MEMORY.md` 상단 frontmatter `{redacted: N}` 필드에 누적 기록 (W5 이후 실제 연동)
4. stdout: redaction된 텍스트

**Unit test** (`__tests__/security/test-secrets-redaction.sh`):
- 각 정규식 positive 3건 + negative 1건 = **28 케이스** 통과
- 예시:
  - Positive AWS: `AKIAIOSFODNN7EXAMPLE` → drop
  - Negative AWS: `AKIA123` (15자, too short) → keep
- 7/7 정규식 전부 28/28 PASS 시 test 성공

### (보너스) `skills/verify/SKILL.md` frontmatter 보강

T-W4-05 맥락에서 `validate_prompt` 필드가 이미 T-W4-01 스켈레톤에 포함됨. 본 패널은 **추가 보강 필요 시에만** 수정 (현재 스켈레톤 이미 충분). 불필요 시 skip.

## 📁 산출물

- `.claude-plugin/plugin.json` (수정: `harness.payload_sha256` 추가)
- `hooks/session-start.sh` (수정: 해시 검증 로직)
- `scripts/update-payload-hashes.sh` (신규, 실행 가능)
- `scripts/secrets-redaction.sh` (신규, 실행 가능)
- `__tests__/security/fixtures/hash-mismatch/` (3 변조 fixture)
- `__tests__/security/test-payload-hash.sh` (신규, 실행 가능)
- `__tests__/security/test-secrets-redaction.sh` (신규, 실행 가능)

## ⚙️ 실행 제약

- bash + jq + sha256sum/shasum만 (v3 §4.1)
- 패널 A와 파일 충돌 없음: 본 패널 `.claude-plugin/plugin.json` · `hooks/session-start.sh` · `scripts/secrets-*` · `__tests__/security/`. 패널 A는 `agents/` · `hooks/drift-monitor.sh` · `skills/verify/SKILL.md` 본문 · `__tests__/integration/`.
- 레퍼런스 수정 금지
- v3.2 §4.3.5·§4.3.6·§4.3.7 스펙 준수
- _git-workflow-template.md 순서 엄수

## ✅ 완료 기준

1. plugin.json에 `harness.payload_sha256` 객체 + 3 파일 해시 채워짐
2. session-start.sh 해시 검증 + 변조 fixture 3/3 주입 거부
3. 7 secrets 정규식 각 positive 3 + negative 1 = 28/28 PASS
4. 체크박스 T-W4-05·06 업데이트
5. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

git pull --rebase origin main || { echo "pull failed"; exit 1; }

sed -i '' \
  -e 's|^- \[ \] \*\*T-W4-05\*\*|- [x] **T-W4-05**|' \
  -e 's|^- \[ \] \*\*T-W4-06\*\*|- [x] **T-W4-06**|' \
  .claude/plans/04-planning/implementation-plan.md

git add .claude-plugin/plugin.json hooks/session-start.sh scripts/update-payload-hashes.sh scripts/secrets-redaction.sh __tests__/security/fixtures/hash-mismatch/ __tests__/security/test-payload-hash.sh __tests__/security/test-secrets-redaction.sh .claude/plans/04-planning/implementation-plan.md

git commit -s -m "$(cat <<'EOF'
feat(W4): T-W4-05·06 페이로드 SHA256 + Secrets redaction 7종

- .claude-plugin/plugin.json: harness.payload_sha256 객체 (using-harness·session-start·validate-output)
- hooks/session-start.sh: 해시 검증 로직 + 불일치 시 주입 거부 + 세션 차단 금지 (v3.2 §4.3.5)
- scripts/update-payload-hashes.sh: 개발자용 해시 갱신 도구
- scripts/secrets-redaction.sh: AWS/GCP/GitHub/Slack/JWT/DB URL/Bearer 7 정규식, 🚨 P0-5
- __tests__/security/: 3 hash-mismatch fixture + 28 케이스 (7 × 4) redaction test
EOF
)"

for attempt in 1 2 3; do
  if git push origin main; then break; fi
  if [ "$attempt" -eq 3 ]; then echo "push failed 3x, abort"; exit 1; fi
  git fetch origin main
  git rebase origin/main || { echo "rebase conflict, abort"; exit 1; }
done
```

## 🛑 금지

- `agents/`, `hooks/drift-monitor.sh`, `skills/verify/SKILL.md` 본문 수정 (패널 A 범위)
- `final-spec.md` 수정
- T-W4-02·03·04·07·08 선수행
- 실제 시크릿 값을 fixture에 사용 (가짜 예시 패턴만)
- push 3회 실패 시 중단

시작하세요.

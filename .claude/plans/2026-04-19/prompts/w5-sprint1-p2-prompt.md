# W5 Sprint 1 Chain B — T-W5-09 + T-W5-10 (correction-detector + Stretch 글로벌 메모리)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — **v3.3** (§4.3.7 correction-detector 부정 문맥, §3.4 승격 게이트, §2.1 #6 오염 방지)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/implementation-plan.md` §W5 — T-W5-09·10
4. `/Users/ethan/Desktop/personal/harness/.claude/memory/README.md` — 글로벌 메모리 정책 (`global_memory_enabled`)
5. `/Users/ethan/Desktop/personal/harness/.claude-plugin/plugin.json` — 기존 구조
6. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/prompts/_git-workflow-template.md`

## 🎯 태스크 (순차)

### T-W5-09 — correction-detector 문자열 매칭 + 직전 assistant 턴 부정 문맥 확인 (2h)

**경로**: `hooks/correction-detector.sh` (신규, 실행 가능, PostToolUse 3번 훅 — v3.3 §4.3.6)

**목표**: v3.3 §4.3.7 부정 문맥 규칙 구현. false positive 억제 (P1-7).

**로직**:
1. stdin으로 PostToolUse payload(JSON) 수신
2. `jq`로 `tool_response` 내 유저 발화 부분 추출
3. 키워드 매칭: `틀렸`, `wrong`, `incorrect`, `잘못` (case-insensitive)
4. **부정 문맥 확인**:
   - 직전 assistant 턴 length ≥ 20자 (완전한 주장 확인)
   - 매칭 문장이 직전 assistant 턴의 핵심 명사 포함 (간이 coreference — 공통 단어 ≥ 1)
5. 매칭 시: stdout JSON `{"detected": true, "reason": "...", "suggested_action": "promotion_gate_user_correction"}`
6. 부정 문맥 실패 시: stdout JSON `{"detected": false, "reason": "no prior assistant claim"}`
7. MVP는 Consent 게이트로 최종 확정 (false positive 허용, v3.3 §3.4에서 유저 거부 가능)

**보안 제약** (v3.3 §4.3):
- `"$var"` 쌍따옴표 · `eval` 금지 · shellcheck 통과

**Fixture**: `__tests__/security/fixtures/correction-detector/` 5 샘플
- `1-kr-valid.json` — 한국어 "틀렸다" + 직전 assistant 완전 응답 → detect
- `2-kr-false-positive.json` — 3인칭 "X가 틀렸다" → 명사 매칭 없음 → no detect
- `3-en-valid.json` — "wrong" + prior claim → detect
- `4-short-prior.json` — 직전 assistant 턴 < 20자 → no detect
- `5-no-keyword.json` — 키워드 없음 → no detect

**검증** (v3.3 §4.3.7 정확도 목표): 5/5 기대 매칭 + precision ≥ 0.7 KU 입력 준비

### T-W5-10 — `[Stretch]` 글로벌 `~/.claude/memory/` 프로젝트 ID 태그 옵션 (4h)

**목표**: v3.3 §4.3.4 글로벌 모드 활성화 시 모든 메모리 파일 frontmatter에 `project_id` 태그 자동 부여. 교차 오염 방지.

**경로**:
- `.claude-plugin/plugin.json` 에 `harness.global_memory_enabled: false` 필드 추가 (기본 OFF, 명시 opt-in)
- `scripts/global-memory-tag.sh` (신규) — 글로벌 모드 시 모든 메모리 쓰기에 project_id 자동 주입
- `scripts/lib/project-id.sh` — CWD 기반 project_id 생성 (예: `sha256(abs_path) 첫 8바이트`)

**로직**:
1. `plugin.json.harness.global_memory_enabled` 읽기
2. `true`인 경우에만 메모리 저장 경로 `~/.claude/memory/`로 분기
3. 모든 쓰기 전 frontmatter에 `project_id: <hash>` 필드 필수화
4. 읽기 시 project_id 일치하는 파일만 필터 (기본은 현재 프로젝트, `--all-projects` 플래그로 교차 접근)

**Fixture**: `__tests__/security/fixtures/global-memory/`
- `proj-a.yaml` (project_id: aaa) 저장
- `proj-b.yaml` (project_id: bbb) 저장
- 읽기 테스트: proj-a 컨텍스트에서 proj-b 필터링 확인

**검증** → **AC-Stretch-2**:
- 글로벌 모드 활성화 시 모든 파일에 project_id 필수
- 누락 시 저장 거부

## 📁 산출물

- `hooks/correction-detector.sh`
- `__tests__/security/fixtures/correction-detector/` (5 샘플)
- `.claude-plugin/plugin.json` (필드 추가)
- `scripts/global-memory-tag.sh`
- `scripts/lib/project-id.sh`
- `__tests__/security/fixtures/global-memory/`

## ⚙️ 실행 제약

- bash + jq만 (v3.3 §4.1). Python 금지.
- `"$var"` 쌍따옴표 · `eval` 금지 · shellcheck 통과
- 패널 A와 파일 충돌 없음: 본 패널 `hooks/correction-detector.sh`·`scripts/global-memory-tag.sh`·`scripts/lib/project-id.sh`·`.claude-plugin/plugin.json`·`__tests__/security/fixtures/*`. 패널 A는 `scripts/(track-router/overlap-score/promotion-gate)` + `hooks/stop.sh` + `skills/compound/templates/` + `__tests__/fixtures/` + `.claude/state/`.
- **참고**: `plugin.json`에 `harness.payload_sha256` 이미 있음 (W4) → 본 패널은 `harness.global_memory_enabled: false` 한 필드 추가만. 기존 필드 건드리지 않기.
- `_git-workflow-template.md` 순서 엄수
- 권한 dialog 나오면 "2" always allow

## ✅ 완료 기준

1. T-W5-09 5/5 fixture 기대 매칭
2. T-W5-10 글로벌 모드 활성화 시 project_id 자동 주입 확인 + 누락 시 거부
3. 체크박스 T-W5-09·10 업데이트
4. 자체 커밋+푸시 완료

---

## 🔄 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

git pull --rebase origin main || { echo "pull failed"; exit 1; }

sed -i '' \
  -e 's|^- \[ \] \*\*T-W5-09\*\*|- [x] **T-W5-09**|' \
  -e 's|^- \[ \] \*\*T-W5-10\*\*|- [x] **T-W5-10**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

git add hooks/correction-detector.sh scripts/global-memory-tag.sh scripts/lib/project-id.sh .claude-plugin/plugin.json __tests__/security/fixtures/correction-detector/ __tests__/security/fixtures/global-memory/ .claude/plans/2026-04-19/04-planning/implementation-plan.md

git commit -s -m "$(cat <<'EOF'
feat(W5): T-W5-09·10 correction-detector 부정 문맥 + [Stretch] 글로벌 메모리 project_id

- hooks/correction-detector.sh: 키워드 + 직전 assistant 턴 부정 문맥 확인 (v3.3 §4.3.7 P1-7 완화)
- __tests__/security/fixtures/correction-detector/: 5 샘플 (kr/en valid + false-positive + short-prior + no-keyword)
- plugin.json: harness.global_memory_enabled: false (기본 OFF, opt-in)
- scripts/global-memory-tag.sh + lib/project-id.sh: project_id 자동 주입 [Stretch AC-Stretch-2]
- __tests__/security/fixtures/global-memory/: 교차 오염 방지 검증
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

- `scripts/track-router.sh`, `scripts/overlap-score.sh`, `scripts/promotion-gate.sh`, `hooks/stop.sh`, `skills/compound/` 수정 (패널 A 범위)
- `final-spec.md`, `skills/verify/`, `agents/`, `skills/plan/`, `skills/brainstorm/` 수정
- T-W5-04·05·06·07·08 선수행
- plugin.json의 기존 필드(`payload_sha256` 등) 수정
- push 3회 실패 시 중단

시작하세요.

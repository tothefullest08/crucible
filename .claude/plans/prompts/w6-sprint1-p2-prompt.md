# W6 Sprint 1 Chain B — T-W6-04 → 05 → 06 → 07 → 08 (keyword·correction·pattern·session-wrap·AC-6)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v3.3 (§3.4·§4.3.6·§4.3.7·§4.2)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W6
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/prompts/_git-workflow-template.md`
5. `/Users/ethan/Desktop/personal/harness/hooks/correction-detector.sh` (T-W5-09 산출, 본 패널 확장 대상)
6. `/Users/ethan/Desktop/personal/harness/scripts/extract-session.sh` (W1 산출, 재사용)
7. `/Users/ethan/Desktop/personal/harness/scripts/schema-adapter.sh` (W1 산출, 재사용)
8. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/ouroboros/` — `keyword-detector.py` 원본 (bash+jq 재작성 대상)
   - `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/history-insight/` — 3회 반복 감지 패턴 참고

## 🎯 태스크 (순차)

### T-W6-04 — `scripts/keyword-detector.sh` Python → bash+jq 재작성 (6h) 🚨 P0-1

**경로**: `scripts/keyword-detector.sh` (신규, 실행 가능)

ouroboros 원본 `keyword-detector.py`를 **bash+jq로 재작성** (v3.3 §4.1 Python 금지). 
- 입력: 세션 JSONL 파일 경로
- 동작: 사전 정의 키워드 리스트 매칭 → stdout JSON (매칭된 키워드·turn·line 정보)
- 키워드 목록: ouroboros 원본과 동일 (프로젝트 루트 기준)
- 로직 파리티: 원본 출력과 동일 포맷
- **Fixture** (원본과 공유): `__tests__/fixtures/keyword-detector/` 10 샘플
- **검증**: 원본 파리티 10/10 + Python 런타임 의존 0 assertion + shellcheck 통과

### T-W6-05 — `hooks/correction-detector.sh` UserPromptSubmit 훅 확장 (4h) 🚨 P0-8

**경로**: `hooks/correction-detector.sh` (T-W5-09 기존 파일 **확장**)

**배경**: T-W5-09가 부정 문맥 확인 로직을 구현. 본 태스크는 이를 UserPromptSubmit 훅으로 통합 + `/compound --candidate correction` 프리셋 생성.

**확장 로직**:
1. UserPromptSubmit payload에서 유저 발화 추출 (기존 로직 유지)
2. 부정 문맥 확인 통과 시 **후보 객체 생성**:
   - `candidate_id`: uuid (bash `uuidgen`)
   - `trigger_source: user_correction`
   - `content`: 유저 발화
   - `context.session_id`, `turn_range`: 메타 수집
   - `detected_at`: ISO-8601 UTC
3. `.claude/state/promotion_queue/<candidate_id>.yaml` 에 적재 (v3.3 §3.4.1)
4. **10샘플 감지율 ≥ 90%** (Fixture 확장, T-W5-09 fixture 5 + 신규 5)

**주의**: T-W5-09 기존 로직은 **보존**. 본 태스크는 감지 후 큐 적재 단계 추가.

**Fixture**: `__tests__/fixtures/correction-detector-w6/` (T-W5-09 재사용 + 신규 5 샘플)
**검증**: 10샘플 ≥ 90% 감지율

### T-W6-06 — 3회 반복 패턴 감지 (4h) — 포팅 자산 #25

**경로**: `scripts/pattern-repeat-detector.sh` (신규, 실행 가능)

**목표**: p4cn history-insight 방식으로 Claude Code JSONL 세션 파일을 파싱해 **동일 토픽 3회 반복** 감지.

**로직**:
1. W1 `scripts/extract-session.sh` + `scripts/schema-adapter.sh` 재사용해 JSONL 파싱
2. `prompt-v0` 타입 턴만 필터 (유저 발화)
3. 각 턴에서 핵심 명사/토큰 추출 (간단 tokenize + stopword 제거)
4. 동일 토픽/토큰이 3회 이상 등장 시 pattern_repeat 후보 생성:
   - `candidate_id`: uuid
   - `trigger_source: pattern_repeat`
   - `content`: "Repeated topic: <token>. Occurrences: turn X, Y, Z"
   - 후보 `.claude/state/promotion_queue/` 적재
5. **Fixture**: `__tests__/fixtures/pattern-repeat/` 3 샘플 (3회 반복 · 1회만 · 2회만)
6. **검증**: 3 fixture 정확 감지 3/3

### T-W6-07 — `/session-wrap` 수동 호출 트리거 (2h)

**경로**: `skills/compound/commands/session-wrap.md` (신규, slash command SKILL)

**목표**: `/session-wrap` 슬래시 명령어. 수동 호출 시 현재 `.claude/state/promotion_queue/` 전체를 승격 게이트(T-W5-06 `promotion-gate.sh`)로 전달.

**frontmatter**:
```yaml
---
name: session-wrap
description: "세션 종료 승격 후보 큐 일괄 제시 / Session-end promotion queue review"
when_to_use: "세션 종료 직전 또는 유저가 수동 호출 시 현재 누적된 승격 후보를 y/N/e/s로 처리"
---
```

**본문**: Stop hook (T-W5-07 `hooks/stop.sh`) 호출 + y/N/e/s UX 통해 각 후보 처리. 수동 실행 시에만 동작.

### T-W6-08 — 3 트리거 감지 AC-6 unit test (4h) → **AC-6**

**경로**: `__tests__/integration/test-ac6-compound-triggers.sh` (신규)

> 주의: implementation-plan §W6 T-W6-08에 "AC-6" 기록됨 (AC 번호 올바름. 혼동 주의 필요 없음).

**3 트리거 각 1건 최소 실측** + 각 fixture:
- `correction` 트리거: T-W6-05 fixture 재사용 — 부정 문맥 통과 후 큐 적재
- `pattern_repeat` 트리거: T-W6-06 fixture 재사용 — 3회 반복 후 큐 적재
- `session_wrap` 트리거: T-W6-07 수동 호출 — 큐 일괄 제시

**검증**:
- 3 트리거 각각 ≥ 1건 성공 → **AC-6 PASS** 출력
- 실패 시 어느 트리거가 실패했는지 명시

**감지 정확도 엄밀 측정은 KU-3 (W7.5)으로 이월** (MVP는 smoke 수준).

## 📁 산출물

- `scripts/keyword-detector.sh` (신규) + `__tests__/fixtures/keyword-detector/`
- `hooks/correction-detector.sh` (확장) + `__tests__/fixtures/correction-detector-w6/`
- `scripts/pattern-repeat-detector.sh` (신규) + `__tests__/fixtures/pattern-repeat/`
- `skills/compound/commands/session-wrap.md` (신규)
- `__tests__/integration/test-ac6-compound-triggers.sh` (신규)

## ⚙️ 실행 제약

- bash + jq + yq + uuidgen만 (v3.3 §4.1). Python 금지.
- 파일 충돌 없음: 본 패널 `scripts/keyword-detector.sh`·`hooks/correction-detector.sh`(확장)·`scripts/pattern-repeat-detector.sh`·`skills/compound/commands/`·`__tests__/integration/test-ac6-*`·`__tests__/fixtures/*`. 패널 A는 `skills/compound/SKILL.md` 본문·`scripts/session-wrap-pipeline.sh`·`agents/compound/`.
- T-W5-09의 `hooks/correction-detector.sh` 기존 로직 **보존** (확장만)
- `_git-workflow-template.md` 순서 엄수
- 권한 dialog 나오면 "2" always allow

## ✅ 완료 기준

1. T-W6-04 keyword-detector.sh shellcheck + ouroboros 파리티 10/10
2. T-W6-05 correction-detector 10샘플 ≥ 90% 감지
3. T-W6-06 pattern-repeat-detector 3 fixture 3/3 PASS
4. T-W6-07 session-wrap.md frontmatter 유효
5. T-W6-08 3 트리거 AC-6 PASS 출력
6. 체크박스 T-W6-04·05·06·07·08 업데이트
7. 자체 커밋+푸시

---

## 🔄 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

git pull --rebase origin main || { echo "pull failed"; exit 1; }

sed -i '' \
  -e 's|^- \[ \] \*\*T-W6-04\*\*|- [x] **T-W6-04**|' \
  -e 's|^- \[ \] \*\*T-W6-05\*\*|- [x] **T-W6-05**|' \
  -e 's|^- \[ \] \*\*T-W6-06\*\*|- [x] **T-W6-06**|' \
  -e 's|^- \[ \] \*\*T-W6-07\*\*|- [x] **T-W6-07**|' \
  -e 's|^- \[ \] \*\*T-W6-08\*\*|- [x] **T-W6-08**|' \
  .claude/plans/04-planning/implementation-plan.md

git add scripts/keyword-detector.sh scripts/pattern-repeat-detector.sh hooks/correction-detector.sh skills/compound/commands/ __tests__/fixtures/keyword-detector/ __tests__/fixtures/correction-detector-w6/ __tests__/fixtures/pattern-repeat/ __tests__/integration/test-ac6-compound-triggers.sh .claude/plans/04-planning/implementation-plan.md

git commit -s -m "$(cat <<'EOF'
feat(W6): T-W6-04·05·06·07·08 /compound 트리거 3종 + AC-6

- scripts/keyword-detector.sh: Python → bash+jq 재작성, ouroboros 파리티 10/10, 🚨 P0-1
- hooks/correction-detector.sh 확장: UserPromptSubmit 훅 + 큐 적재, 10샘플 ≥90%, 🚨 P0-8
- scripts/pattern-repeat-detector.sh: 3회 반복 감지 (W1 JSONL 파서 재사용, 포팅 #25)
- skills/compound/commands/session-wrap.md: /session-wrap slash command (Stop hook 연결)
- __tests__/integration/test-ac6-compound-triggers.sh: 3 트리거 AC-6 PASS
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

- `skills/compound/SKILL.md` 수정 (패널 A 범위)
- `scripts/session-wrap-pipeline.sh`, `agents/compound/` 작성 (패널 A 범위)
- `skills/compound/templates/` 수정 (W5 산출물)
- final-spec · implementation-plan(체크박스 외) 수정
- T-W5-09의 correction-detector.sh 부정 문맥 로직 삭제 (확장만 허용)
- T-W6-02·03 선수행
- Python/Node 사용
- push 3회 실패 시 중단

시작하세요.

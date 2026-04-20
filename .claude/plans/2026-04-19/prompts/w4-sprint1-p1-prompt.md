# W4 Sprint 1 Chain A — T-W4-02 → 03 → 04 → 07 → 08 (verify 에이전트 + qa-judge + Ralph + drift-monitor + AC-4)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — **v3.2** (§2.1 #5 Evaluator, §4.3.5·6·7 보안, §4.2 JSONL)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/implementation-plan.md` §W4
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/prompts/_git-workflow-template.md`
5. `/Users/ethan/Desktop/personal/harness/skills/verify/SKILL.md` — T-W4-01 스켈레톤
6. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/hoyeon/agents/` — verify 6-에이전트 (verifier · verification-planner · verify-planner · qa-verifier · ralph-verifier · spec-coverage) + `drift-monitor.py`
   - `/Users/ethan/Desktop/personal/harness/references/ouroboros/` — Ralph Loop 의사코드 + qa-judge 원본

## 🎯 태스크 (순차)

### T-W4-02 — `agents/verify/` 6-에이전트 스텁 (8h, 4h W7.5로 이월)

**경로**: `agents/verify/{verifier,verification-planner,verify-planner,qa-verifier,ralph-verifier,spec-coverage}.md` (6 파일 신규)

각 에이전트 frontmatter + 최소 stub 응답 정의. hoyeon 원본 구조 차용하되 본 플러그인 포맷(name·description·when_to_use)으로 재작성.

- `verifier`: 일반 검증 dispatcher
- `verification-planner`: 검증 전략 수립
- `verify-planner`: plan.md 특화 검증
- `qa-verifier`: QA 관점 검증
- `ralph-verifier`: Ralph Loop 재시도 관리
- `spec-coverage`: 스펙 커버리지 체크

**MVP 범위**: 각 에이전트 frontmatter + 1~2 paragraph 기본 프롬프트. 실제 로직 W7.5 하드닝에서 확장.

### T-W4-03 — `agents/evaluator/qa-judge.md` JSON 스키마 (4h)

**경로**: `agents/evaluator/qa-judge.md` (신규)

qa-judge 응답 JSON 스키마 정의. ouroboros 원본 참조 (포팅 자산 #3):

```json
{
  "score": 0.0,        // [0.0, 1.0]
  "verdict": "promote | retry | reject",
  "dimensions": {
    "correctness": 0.0,
    "clarity": 0.0,
    "maintainability": 0.0
  },
  "differences": ["..."],   // 기대 vs 실제 차이
  "suggestions": ["..."]    // 개선 제안
}
```

임계값 분기:
- `score >= 0.80` → `verdict: "promote"`
- `0.40 < score < 0.80` → `verdict: "retry"` (회색지대, MVP는 수동 승격 fallback)
- `score <= 0.40` → `verdict: "reject"`

**산출물**: `agents/evaluator/qa-judge.md` (frontmatter + 스키마 + 분기 로직 설명)

### T-W4-04 — Ralph Loop 의사코드 본문 내장 (4h)

**경로**: `skills/verify/SKILL.md` 본문 Phase 4 확장

ouroboros Ralph Loop 의사코드 (포팅 자산 #2, `skills/ralph/SKILL.md:50-99` 라인 커버리지 ≥ 80%):
- non-blocking + level-based polling
- 재시도 상한 3회
- 각 시도마다 qa-judge 점수 기록
- 3회 실패 시 reject + 사용자 수동 승격 fallback
- verify SKILL.md Phase 4 소절에 의사코드 삽입

### T-W4-07 — `hooks/drift-monitor.sh` bash+jq 재작성 (4h) 🚨 P0-1

**경로**: `hooks/drift-monitor.sh` (신규, 실행 가능)

ouroboros 원본 `drift-monitor.py` → **bash+jq 재작성** (v3 §4.1 Python 금지). 
- 로직 파리티: 원본의 stdout 메시지 형식 · 드리프트 임계 · 종료 코드 동일
- PostToolUse 이벤트에서 호출 (§4.3.6 순서 2번)
- 검증: 원본과 동일 JSONL fixture 10건에 대해 동일 advisory 출력

### T-W4-08 — qa-judge 임계값 분기 unit test → **AC-4** (2h)

**경로**: `__tests__/integration/test-ac4-qa-judge-threshold.sh` (신규)

> 주의: implementation-plan §W4 T-W4-08에 "AC-2" 표기는 오타. 실제 **AC-4** (W1=1, W2=2, W3=3, W4=4).

3 샘플 입력으로 qa-judge 분기:
- score 0.85 → promote (PASS)
- score 0.60 → retry (PASS)
- score 0.30 → reject (PASS)
- 3/3 통과 시 stdout `AC-4 PASS`

## 📁 산출물

- `agents/verify/{verifier,verification-planner,verify-planner,qa-verifier,ralph-verifier,spec-coverage}.md` (6)
- `agents/evaluator/qa-judge.md` (1)
- `skills/verify/SKILL.md` (Phase 4 Ralph Loop 본문 확장)
- `hooks/drift-monitor.sh` (신규, 실행 가능)
- `__tests__/integration/test-ac4-qa-judge-threshold.sh` (신규, 실행 가능)

## ⚙️ 실행 제약

- bash + jq + yq만 (v3 §4.1). Python 금지.
- `"$var"` 쌍따옴표 + `eval` 금지 + shellcheck 통과 (v3.2 §4.3)
- 패널 B와 파일 충돌 없음: 본 패널 `agents/verify/`·`agents/evaluator/`·`hooks/drift-monitor.sh`·`skills/verify/SKILL.md` 본문·`__tests__/integration/`. 패널 B는 `hooks/session-start.sh` 확장·`scripts/secrets-redaction.sh`·`.claude-plugin/plugin.json` 해시 필드·`__tests__/security/`.
- 레퍼런스 수정 금지
- `skills/verify/SKILL.md` **frontmatter 미터치** (패널 B가 T-W4-05에서 validate_prompt 보강 가능성)
- _git-workflow-template.md 순서 엄수 (pull → sed → add → commit → push)

## ✅ 완료 기준

1. 6 verify agents + qa-judge frontmatter 정상
2. Ralph Loop 의사코드 ouroboros 대비 80% 커버
3. drift-monitor.sh shellcheck 통과 + Python 파리티
4. `test-ac4-qa-judge-threshold.sh` 3/3 PASS (`AC-4 PASS` 출력)
5. 체크박스 T-W4-02·03·04·07·08 업데이트
6. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

git pull --rebase origin main || { echo "pull failed"; exit 1; }

sed -i '' \
  -e 's|^- \[ \] \*\*T-W4-02\*\*|- [x] **T-W4-02**|' \
  -e 's|^- \[ \] \*\*T-W4-03\*\*|- [x] **T-W4-03**|' \
  -e 's|^- \[ \] \*\*T-W4-04\*\*|- [x] **T-W4-04**|' \
  -e 's|^- \[ \] \*\*T-W4-07\*\*|- [x] **T-W4-07**|' \
  -e 's|^- \[ \] \*\*T-W4-08\*\*|- [x] **T-W4-08**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

git add agents/verify/ agents/evaluator/ skills/verify/SKILL.md hooks/drift-monitor.sh __tests__/integration/test-ac4-qa-judge-threshold.sh .claude/plans/2026-04-19/04-planning/implementation-plan.md

git commit -s -m "$(cat <<'EOF'
feat(W4): T-W4-02·03·04·07·08 verify 6-에이전트 + qa-judge + Ralph + drift-monitor + AC-4

- agents/verify/: 6-에이전트 스텁 (verifier·verification-planner·verify-planner·qa-verifier·ralph-verifier·spec-coverage), MVP 범위
- agents/evaluator/qa-judge.md: score·verdict·dimensions·differences·suggestions 스키마 + 0.80/0.40 분기
- skills/verify/SKILL.md Phase 4: Ralph Loop 의사코드 (ouroboros 포팅, non-blocking + 3회 상한)
- hooks/drift-monitor.sh: bash+jq 재작성 (ouroboros .py Python 제거), 🚨 P0-1
- __tests__/integration/test-ac4-qa-judge-threshold.sh: 3샘플 분기 AC-4 검증 (promote/retry/reject)
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

- `skills/verify/SKILL.md` **frontmatter** 수정 (패널 B 잠재 범위)
- `hooks/session-start.sh` 수정 (패널 B T-W4-05)
- `scripts/secrets-*`, `.claude-plugin/plugin.json` 수정 (패널 B)
- `final-spec.md` 수정
- T-W4-05·06 선수행
- Python/Node 사용
- push 3회 실패 시 중단

시작하세요.

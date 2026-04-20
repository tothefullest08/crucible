# W6 Sprint 1 Chain A — T-W6-02 + T-W6-03 (session-wrap 2-Phase + agents/compound 5종)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v3.3 (§3.4 승격 게이트, §2.1 #6 오염 방지)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/implementation-plan.md` §W6 — T-W6-02·03
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/prompts/_git-workflow-template.md`
5. `/Users/ethan/Desktop/personal/harness/skills/compound/SKILL.md` — T-W6-01 스켈레톤
6. `/Users/ethan/Desktop/personal/harness/.claude/memory/README.md` — frontmatter 스키마
7. `/Users/ethan/Desktop/personal/harness/skills/compound/templates/gate-dialog.md` — T-W5-06 산출 (참조)
8. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/` — 2-Phase 원본 (포팅 자산 #4: 4 분석자 병렬 + 1 validator 순차)
   - `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/session-wrap/agents/` — 5 에이전트 원본 이름 참조

## 🎯 태스크 (순차)

### T-W6-02 — session-wrap 2-Phase 파이프라인 포팅 (8h) — 포팅 자산 #4

**경로**: `skills/compound/SKILL.md` Phase 1~5 본문 확장 (frontmatter 미터치) + `scripts/session-wrap-pipeline.sh` (신규, 실행 가능)

**목표**: p4cn session-wrap의 2-Phase 파이프라인을 하네스에 포팅 — **4 분석자 병렬** (Phase A) + **1 validator 순차** (Phase B).

**Phase A** (병렬 4 분석자, SKILL.md Phase 2에 내장):
1. `tacit-extractor`: 세션에서 암묵지 후보 추출
2. `correction-recorder`: 유저 정정 정리
3. `pattern-detector`: 반복 패턴 요약
4. `preference-tracker`: 작업 선호 추정

각 분석자는 동일 세션 JSONL을 독립 fresh-context로 읽어 병렬 실행. stdout = 승격 후보 JSON 리스트.

**Phase B** (순차 1 validator, SKILL.md Phase 3 내장):
- `duplicate-checker`: 4 분석자 출력 병합 + 기존 `.claude/memory/` 파일과 dedup 검증
- T-W5-05 5-dim overlap scoring 호출 → overlap_band 할당
- 최종 candidate 큐에 적재

**SKILL.md 확장 포인트**:
- Phase 1 Intake: 세션 JSONL 파싱 (W1 scripts/extract-session.sh 재사용)
- Phase 2: 4 분석자 병렬 (Task 도구 4회 동시 호출)
- Phase 3: duplicate-checker (validator) 순차
- Phase 4: 승격 게이트 (T-W5-06 재사용)
- Phase 5: 저장 + MEMORY.md 인덱스 (T-W5-08 재사용)

**파이프라인 스크립트** (`scripts/session-wrap-pipeline.sh`):
- 입력: 세션 ID (기본 현재)
- 동작: 4 agent stub 호출 (MVP는 fixed fixture 반환) → validator → 큐 출력
- shellcheck 통과

### T-W6-03 — `agents/compound/` 5종 (8h)

**경로**: `agents/compound/{tacit-extractor,correction-recorder,pattern-detector,preference-tracker,duplicate-checker}.md` (5 파일 신규)

각 에이전트 frontmatter + MVP stub 본문:
- `tacit-extractor`: Knowledge track (tacit) 후보 추출 — fresh context · 세션 JSONL 입력 · 패턴/경험 요약 출력
- `correction-recorder`: Bug track (correction) 기록 — original_claim · user_correction · prevention 필드 채움
- `pattern-detector`: 반복 패턴 요약 (3회 이상 등장 토픽) — detector 규칙 참고
- `preference-tracker`: 유저 선호 추정 — scope (session/project/user) 분류 제안
- `duplicate-checker`: Phase B validator — 4 분석자 출력과 기존 memory dedup + overlap_band

**이름 네임스페이스 규약** (하네스 P1 규약):
- 에이전트 파일 이름: kebab-case
- frontmatter `name` 필드: `compound/{name}` 형태 또는 단순 `{name}` (선택, 일관성 유지)

**검증**:
- 5 에이전트 모두 frontmatter yq 파싱 통과
- 각 에이전트 description에 역할 1문장 + "fresh context" 명시
- MVP stub는 최소 동작 (실제 LLM 호출은 W7 이후)

## 📁 산출물

- `skills/compound/SKILL.md` (본문 Phase 1~5 확장, frontmatter 미터치)
- `scripts/session-wrap-pipeline.sh` (신규, 실행 가능)
- `agents/compound/{tacit-extractor,correction-recorder,pattern-detector,preference-tracker,duplicate-checker}.md` (5 파일)

## ⚙️ 실행 제약

- bash + jq + yq만 (v3.3 §4.1). Python 금지.
- 파일 충돌 없음: 본 패널 `skills/compound/SKILL.md` 본문·`scripts/session-wrap-pipeline.sh`·`agents/compound/`. 패널 B는 `scripts/keyword-detector.sh`·`hooks/correction-detector.sh`·`scripts/pattern-repeat-detector.sh`·`skills/compound/commands/session-wrap.md`·`__tests__/integration/test-ac6-*.sh`.
- `skills/compound/SKILL.md` **frontmatter 미터치** (기존 validate_prompt 보존)
- 레퍼런스 수정 금지
- final-spec · implementation-plan(체크박스 제외) 수정 금지
- `_git-workflow-template.md` 순서 엄수
- 권한 dialog 나오면 "2" always allow

## ✅ 완료 기준

1. SKILL.md Phase 1~5 본문 완성 (5섹션 × 5 Phase 구조)
2. session-wrap-pipeline.sh shellcheck 통과
3. 5 에이전트 frontmatter yq 파싱 + description/name 기본값
4. 체크박스 T-W6-02·03 업데이트
5. 자체 커밋+푸시

---

## 🔄 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

git pull --rebase origin main || { echo "pull failed"; exit 1; }

sed -i '' \
  -e 's|^- \[ \] \*\*T-W6-02\*\*|- [x] **T-W6-02**|' \
  -e 's|^- \[ \] \*\*T-W6-03\*\*|- [x] **T-W6-03**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

git add skills/compound/SKILL.md scripts/session-wrap-pipeline.sh agents/compound/ .claude/plans/2026-04-19/04-planning/implementation-plan.md

git commit -s -m "$(cat <<'EOF'
feat(W6): T-W6-02·03 session-wrap 2-Phase 파이프라인 + agents/compound 5종

- skills/compound/SKILL.md Phase 1~5 본문: 2-Phase(4 분석자 병렬 + 1 validator) 포팅 (포팅 #4)
- scripts/session-wrap-pipeline.sh: Phase A 병렬 + Phase B 순차 파이프라인 스텁
- agents/compound/: tacit-extractor · correction-recorder · pattern-detector · preference-tracker · duplicate-checker (5 파일, fresh context)
- 하네스 P1 네임스페이스 규약 준수
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

- `scripts/keyword-detector.sh`, `hooks/correction-detector.sh`, `scripts/pattern-repeat-detector.sh`, `skills/compound/commands/`, `__tests__/integration/` 수정 (패널 B 범위)
- `skills/compound/SKILL.md` **frontmatter** 수정 (T-W6-01 스켈레톤 보존)
- `skills/compound/templates/` 수정 (W5 산출물 보존)
- final-spec · implementation-plan(체크박스 외) 수정
- T-W6-04·05·06·07·08 선수행
- Python/Node 사용
- push 3회 실패 시 중단

시작하세요.

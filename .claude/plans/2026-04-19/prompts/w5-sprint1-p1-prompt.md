# W5 Sprint 1 Chain A — T-W5-04 → 05 → 06 → 07 → 08 (track 분기 + 5-dim overlap + y/N/e/s + Stop hook + 거부 이력)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — **v3.3** (§3.4 승격 게이트 UX 정식, §2.1 #6 오염 방지)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/implementation-plan.md` §W5 — T-W5-04·05·06·07·08
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/s11-3-ux-draft.md` — 승격 게이트 상세
5. `/Users/ethan/Desktop/personal/harness/.claude/memory/README.md` — frontmatter 스키마 · 포맷 규약
6. `/Users/ethan/Desktop/personal/harness/.claude/memory/MEMORY.md` — 인덱스 포맷
7. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/prompts/_git-workflow-template.md`
8. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/skills/ce-compound/` — 5-dim overlap 원본 (포팅 자산 #18)
   - `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/` — Bug/Knowledge track 분기 (포팅 자산 #24)

## 🎯 태스크 (순차)

### T-W5-04 — Bug track vs Knowledge track 분기 (4h)

**경로**: `scripts/track-router.sh` (신규, 실행 가능)

후보 객체(.yaml)를 읽어 `trigger_source = user_correction` → `corrections/` (Bug), 그 외 → `tacit/` (Knowledge) 자동 분류. stdout에 최종 저장 경로 출력.

**Fixture**: `__tests__/fixtures/track-router/` (3 case — user_correction / session_wrap / pattern_repeat)
**검증**: 3/3 자동 분류 정확

### T-W5-05 — 5-dimension overlap scoring (8h) — 포팅 자산 #18

**경로**: `scripts/overlap-score.sh` (신규, 실행 가능) + `scripts/lib/overlap-dims.sh` (helper)

CE ce-compound 5-dim (problem / cause / solution / files / prevention) 각각 0~1 점수. 합산 4-5 → High, 2-3 → Moderate, 0-1 → Low.

- 입력: 후보 객체 경로 + 기존 MEMORY.md index
- 동작: 후보 content와 기존 tacit/ · corrections/ 파일을 문자열 유사도 + 필드 매칭 heuristic로 5축 비교
- 출력: JSON `{"problem":0.X,"cause":0.X,"solution":0.X,"files":0.X,"prevention":0.X,"total_band":"High|Moderate|Low"}`
- **Fixture**: `__tests__/fixtures/overlap-score/` (10 샘플 — High/Moderate/Low 각 3~4 샘플)
- **검증**: 10 샘플 정확도 ≥ 80% (expected_band vs actual_band)

### T-W5-06 — 승격 게이트 UX: y/N/e/s AskUserQuestion (6h)

**경로**: `scripts/promotion-gate.sh` (신규, 실행 가능) + `skills/compound/templates/gate-dialog.md` (텍스트 포맷)

Stop hook에서 호출되어 승격 큐를 일괄 제시. 각 후보에 대해 `[y]승인 [N]거부 [e]수정 후 승인 [s]건너뛰기` 제공. 기본값 `N`.

**응답 분기** (v3.3 §3.4.3):
- `y` → Step 5 저장 (다음 훅·스크립트에 파이프)
- `N` → Step 6 `_rejected/` 이력
- `e` → 별도 프롬프트로 content 편집 → y 경로
- `s` → 큐에 남김 (다음 session_wrap 재제시)

**Fixture**: 4 응답 시나리오 (각 분기 1회) — stdin 시뮬레이션으로 테스트
**검증**: 4 분기 각각 저장/거부/편집/스킵 동작 실측

### T-W5-07 — Stop hook 일괄 제시 + 3회 연속 거부 detector 임시 비활성화 (4h)

**경로**: `hooks/stop.sh` (신규 실행 가능) + `.claude/state/detector-status.json` (상태 저장)

Stop 이벤트에서 `.claude/state/promotion_queue/` 전체를 읽어 T-W5-06 호출. 각 detector별 연속 거부 count 추적 → 3회 연속 시 해당 detector `disabled_until: <now + 7d>` 기록.

**Fixture**: `__tests__/fixtures/stop-hook/` 3회 거부 시나리오
**검증**: 3회 reject 후 detector-status.json의 `disabled_until` 7일 값 기록

### T-W5-08 — 거부 이력 저장 (4h)

**경로**: `.claude/memory/corrections/_rejected/` 에 거부 후보 파일 이동 + `_rejections.log` timestamp+pattern 기록

**로직**:
- promotion_queue/{id}.yaml → corrections/_rejected/{id}.md (content + frontmatter 변환)
- _rejections.log에 `{ISO timestamp} {detector_id} {pattern_hash}` append
- 과적합 감지 입력으로 사용 (T-W5-07이 읽음)

**Fixture**: `__tests__/fixtures/rejection-log/` 3건
**검증**: 3건 후 `_rejections.log` 3 라인 + 파일 3개 이동

## 📁 산출물

- `scripts/track-router.sh` · `__tests__/fixtures/track-router/`
- `scripts/overlap-score.sh` · `scripts/lib/overlap-dims.sh` · `__tests__/fixtures/overlap-score/` (10 샘플)
- `scripts/promotion-gate.sh` · `skills/compound/templates/gate-dialog.md`
- `hooks/stop.sh` · `.claude/state/detector-status.json` (초기 빈 객체) · `__tests__/fixtures/stop-hook/`
- `.claude/memory/corrections/_rejected/.gitkeep` · `__tests__/fixtures/rejection-log/`

**참고**: `.claude/state/` 신규 디렉토리. `.gitignore`에 `.claude/state/promotion_queue/`·`.claude/state/*.lock` 추가 필요 (이건 메인이 처리, 본 패널은 `detector-status.json`만 템플릿 형태로 커밋).

## ⚙️ 실행 제약

- bash + jq + yq만 (v3.3 §4.1). Python 금지.
- `"$var"` 쌍따옴표 + `eval` 금지 + shellcheck 통과
- 패널 B와 파일 충돌 없음: 본 패널 `scripts/`·`hooks/stop.sh`·`skills/compound/templates/`·`__tests__/fixtures/`·`.claude/memory/corrections/_rejected/`. 패널 B는 `hooks/correction-detector.sh`·`scripts/global-memory-tag.sh`·`__tests__/security/`.
- `_git-workflow-template.md` 순서 엄수 (pull → sed → add → commit → push)
- **권한 dialog 나오면 "2" always allow 선택**

## ✅ 완료 기준

1. 5 태스크 모두 산출물 생성 + shellcheck 통과
2. 각 fixture 기대 매칭
3. 체크박스 T-W5-04·05·06·07·08 업데이트
4. 자체 커밋+푸시 완료

---

## 🔄 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

git pull --rebase origin main || { echo "pull failed"; exit 1; }

sed -i '' \
  -e 's|^- \[ \] \*\*T-W5-04\*\*|- [x] **T-W5-04**|' \
  -e 's|^- \[ \] \*\*T-W5-05\*\*|- [x] **T-W5-05**|' \
  -e 's|^- \[ \] \*\*T-W5-06\*\*|- [x] **T-W5-06**|' \
  -e 's|^- \[ \] \*\*T-W5-07\*\*|- [x] **T-W5-07**|' \
  -e 's|^- \[ \] \*\*T-W5-08\*\*|- [x] **T-W5-08**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

git add scripts/ hooks/stop.sh skills/compound/templates/ __tests__/fixtures/ .claude/memory/corrections/_rejected/ .claude/state/detector-status.json .claude/plans/2026-04-19/04-planning/implementation-plan.md

git commit -s -m "$(cat <<'EOF'
feat(W5): T-W5-04·05·06·07·08 승격 게이트 본체

- scripts/track-router.sh: Bug(corrections) vs Knowledge(tacit) 자동 분류 (포팅 #24)
- scripts/overlap-score.sh + lib/overlap-dims.sh: 5-dim overlap scoring (포팅 #18), 10샘플 정확도 ≥80%
- scripts/promotion-gate.sh + skills/compound/templates/gate-dialog.md: y/N/e/s UX (§3.4.3)
- hooks/stop.sh + .claude/state/detector-status.json: Stop hook 일괄 + 3회 거부 비활성화
- .claude/memory/corrections/_rejected/: 거부 이력 + _rejections.log
- fixtures: track-router · overlap-score · stop-hook · rejection-log
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

- `hooks/correction-detector.sh`, `scripts/global-memory-tag.sh`, `.claude-plugin/plugin.json` 수정 (패널 B 범위)
- `final-spec.md`, `skills/verify/`, `agents/`, `skills/plan/`, `skills/brainstorm/` 수정
- T-W5-09·10 선수행
- Python/Node 사용
- push 3회 실패 시 중단

시작하세요.

# W8 Sprint 1 (단일 패널) — 문서화 + 오픈소스 배포 (T-W8-PRE-01/02/03 + T-W8-01~08) · 52h

> **MVP 릴리스 주차**. 남은 Hard AC 3종(AC-1·2·8) 확정 + §11-5/6/7 최종 승격 + 공개 배포.

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v3.3 (§1 TL;DR 포지셔닝 · §3.5 6축 강제 · §4.5 라이선스 · §11-5·6·7)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W8
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/porting-matrix.md` — 상류 라이선스 매트릭스 대상
5. `/Users/ethan/Desktop/personal/harness/.claude/plans/prompts/_git-workflow-template.md`
6. `/Users/ethan/Desktop/personal/harness/.claude-plugin/plugin.json` · `marketplace.json`
7. `/Users/ethan/Desktop/personal/harness/skills/{brainstorm,plan,verify,compound,orchestrate}/SKILL.md` — 5 스킬 description

## 🎯 작업 원칙

- **영문 우선, 한국어 병기**: description 포맷(영문 1줄 + 한국어 1줄)을 README·CONTRIBUTING에 동일 적용
- **MIT + DCO**: LICENSE(MIT) · CONTRIBUTING(DCO sign-off 절차) · NOTICES.md (6 상류 저작권)
- **AC-1 차단 금지**: 클린 머신 설치 시 외부 의존 0 — 플러그인 디렉토리만 복사하면 `/brainstorm` 호출 가능해야
- **실측 우선**: T-W8-08에서 실제 `~/.claude-plugin-harness-test/` 등 별도 디렉토리에 복사 → `/brainstorm` 콜드 스타트 검증
- bash + jq + yq만 (v3.3 §4.1)

---

## 🎯 태스크 (순차)

### T-W8-PRE-01 — §11-5 승격: 6축 강제 적용 범위 확정 (4h)

**경로**: `.claude/plans/03-design/final-spec.md` §3.5 보강 + §11-5 status → 승격 완료

**작업**:
1. §3.5 내부에 "축별 활성 규칙" 표 추가:
   - `/plan` · `/verify` · `/orchestrate` → 6축 검증 **ON** (validate_prompt 훅 강제)
   - `/brainstorm` · `/compound` → 자연 대화 (축 번호만 로그, 훅 강제 X)
   - 일반 Q&A · 도구 호출 → **OFF**
2. `--skip-axis N` 이스케이프 해치 스펙 (N=1..6):
   - `/plan --skip-axis 3` 형태 cli 플래그
   - 검증 축(5) 스킵 시 stderr에 **강경 경고** 출력 (예: "⚠️ Axis 5 (Verify) skipped — release blocker for production deployments")
3. 실효성 지표 KU (KU-6) → **2차 릴리스 유지** 명시
4. §11-5 표에 "→ §3.5 참조" 축소

**검증**: §3.5 표 6행 존재 + §11-5 status "승격 완료"

---

### T-W8-PRE-02 — §11-6 승격: 라이선스 · 상류 sync 매트릭스 (4h)

**경로**: `final-spec.md` §4.5 보강 + `porting-matrix.md` §2 갱신

**작업**:
1. `porting-matrix.md` §2 테이블에 컬럼 2개 추가:
   - **상류 커밋 해시**: hoyeon/ouroboros/p4cn/superpowers/CE/agent-council 각 레퍼런스 ref
   - **sync 주기**: 분기(quarterly)/반기(biannual)/연(annual) 차등
2. 라이선스 호환성 매트릭스 (4 상류 + 2 추가):
   - 전부 MIT 확인 (2026-04-19 실측, §4.5 기록 유지)
3. 본 플러그인 최종 라이선스: **MIT** 재확인 + SPDX identifier `MIT`
4. §11-6 status "승격 완료"

**검증**: porting-matrix §2 6행 × 2 신규 컬럼 + SPDX 명시

---

### T-W8-PRE-03 — §11-7 승격: 기타 설계 미결 정리 (4h)

**경로**: `final-spec.md` §11-7 status + 해당 섹션 보강

**작업**:
1. **프론트매터 필드 5 스킬 전부 확정**: 5 스킬(brainstorm·plan·verify·compound·orchestrate) SKILL.md frontmatter 필드 6개(name·description·when_to_use·input·output·validate_prompt) 일관성 확인 표 작성
2. **포지셔닝 1문장 README 확정**: §1 TL;DR 2문장 버전을 README 최상단용으로 단축안 1개 생성 (≤ 140자, 영어+한국어 각 1줄)
3. **OSS composability**: 각 스킬이 독립 사용 가능한지 명세 (의존 관계 DAG 포함)
4. **`/orchestrate` 실질 가치 비교표**: 수동 호출(/brainstorm → /plan → /verify → /compound 4회) vs `/orchestrate` 1회 — 항목(타이핑·컨텍스트 보존·체크포인트·실패 복구) 4행 비교
5. §11-7 status "승격 완료"

**검증**: final-spec §11-7 4 항목 체크리스트 전부 GREEN

---

### T-W8-05 — 각 스킬 description 한·영 병기 최종 점검 (2h)

**경로**: `skills/{brainstorm,plan,verify,compound,orchestrate}/SKILL.md` frontmatter description

**작업**:
1. 5 스킬 description 스캔 → 포맷 일관성 확인:
   - **표준 포맷**: `영어 1줄. / Korean 1줄.` 또는 `description: |\n  영어\n  한국어`
2. 누락·불일치 발견 시 **최소 수정**으로 통일 (본문 보존)
3. 트리거 키워드(한·영) 각 스킬당 최소 5개 포함 확인

**검증**: `yq eval '.description' skills/*/SKILL.md` 5 스킬 전부 파싱 + 한·영 각 포함

---

### T-W8-01 — README.md 영어 (6h) → **AC-8**

**경로**: `README.md` (루트, 신규 또는 기존 대체)

**구성**:
```markdown
# harness

<!-- 포지셔닝 1문장 (T-W8-PRE-03 산출) -->

## Why
<3~5 bullet: 반복 실수·암묵지 휘발·6축 강제 메타 부재>

## Install
```bash
cp -r harness ~/.claude-plugin-harness
# or clone directly into .claude/plugins/
```

## Skills (5)
- `/brainstorm` — ...
- `/plan` — ...
- `/verify` — ...
- `/compound` — ...
- `/orchestrate` [Stretch] — ...

## 6-Axis Harness
Structure · Context · Plan · Execute · Verify · Compound

## Example
<단일 스킬 호출 1개 + /orchestrate 호출 1개 = 2 예제>

## License
MIT — see LICENSE. DCO sign-off required (CONTRIBUTING.md).

## Acknowledgments
<6 상류 — hoyeon/ouroboros/p4cn/superpowers/CE/agent-council — NOTICES.md 참조>
```

**검증**: 포지셔닝 1문장 · 5 스킬 사용 예제 · License 섹션 전부 포함 + 분량 ≥ 80 라인

---

### T-W8-02 — README.ko.md (4h) → **AC-8**

**경로**: `README.ko.md` (루트)

**작업**:
1. T-W8-01 README.md 섹션 구성과 **동형**
2. 예제 중 최소 1개는 **한국어 고유 예제** (예: "브레인스토밍하자" 트리거)
3. 영문 README와 상호 링크 (`[English](README.md)` / `[한국어](README.ko.md)`)

**검증**: 섹션 순서/개수 동일 + ko 고유 예제 1개 이상

---

### T-W8-03 — CLAUDE.md 작성 (4h)

**경로**: `CLAUDE.md` (루트)

**작업**: hoyeon 2중 구조(프로젝트 가이드라인 + AGENTS.md 링크) 차용
- 프로젝트 헤더 · 6축 준수 규칙 · 5 스킬 사용법 요약 · AGENTS.md/NOTICES.md/CONTRIBUTING.md 포인터
- 길이 ≤ 200 라인

**검증**: 6축 언급 + AGENTS.md 링크 + 5 스킬 링크

---

### T-W8-04 — AGENTS.md 작성 (2h)

**경로**: `AGENTS.md` (루트)

**작업**: Skill Compliance Checklist 섹션
- 6축 체크리스트 각 1행 + pass 조건
- 5 스킬 각 validate_prompt 훅 명세 요약
- 길이 ≤ 120 라인

**검증**: 6축 체크박스 + 5 스킬 validate_prompt 언급

---

### T-W8-07 — 오픈소스 라이선스 파일 + CONTRIBUTING (2h)

**경로**: `LICENSE` · `NOTICES.md` · `CONTRIBUTING.md` (루트)

**작업**:
1. `LICENSE`: MIT 전문 + 저작권 (2026 harness contributors)
2. `NOTICES.md`: 6 상류(hoyeon/ouroboros/p4cn/superpowers/CE/agent-council) 각 저작권 + 해당 라이선스 링크
3. `CONTRIBUTING.md`:
   - DCO sign-off 절차 (`git commit -s`)
   - PR 가이드라인 (6축 준수·shellcheck·yq 파싱·AC 영향)
   - SPDX-License-Identifier: MIT
4. `.claude-plugin/plugin.json`에 `license: "MIT"` 필드 추가 (없으면)

**검증**: `grep -l "SPDX-License-Identifier: MIT" LICENSE CONTRIBUTING.md` 양쪽 출력 + DCO 섹션 존재

---

### T-W8-06 — 릴리스 체크리스트 + Hard AC 8개 판정 (4h)

**경로**: `RELEASE-CHECKLIST.md` (루트, 신규) + `.claude/state/ac-final.json`

**작업**:
1. Hard AC 8개 각각 현재 상태 확인:
   - AC-1·2·8: T-W8-08 결과 참조 (또는 이 태스크 후 갱신)
   - AC-3·4·5·7: W7.5 ku-*.json 참조
   - AC-6: W6 AC-6 PASS 참조
2. W0~W8 게이트 회고 (각 주차 1~2줄)
3. `.claude/state/ac-final.json`: `{ac_1: pass|fail|pending, ...}`
4. RELEASE-CHECKLIST.md:
   - 릴리스 전 체크리스트 20 항목 (테스트 · LICENSE · NOTICES · README · CI · tag · PR)
   - Hard AC 판정 요약 표

**검증**: AC 8개 전부 명시 + 체크리스트 ≥ 20 항목

---

### T-W8-08 — 배포 검증: 클린 머신에서 플러그인 설치 → `/brainstorm` 호출 (4h) → **AC-1**

**경로**: `__tests__/integration/test-clean-install.sh` (신규)

**작업**:
1. 스크립트 로직:
   - 임시 디렉토리 `$(mktemp -d)/clean-harness` 생성
   - 현 플러그인 전체 복사 (`.claude-plugin/` + `skills/` + `agents/` + `scripts/` + `hooks/` + `__tests__/` + `LICENSE` + `README.md`)
   - 복사 후 `cd` 하여 **외부 의존 검증**:
     - `command -v bash jq yq uuidgen flock` 모두 존재?
     - Python/Node 바이너리 참조가 플러그인 내부에 없는지 (`grep -r "python\|node " scripts/ hooks/` — shebang만 있으면 OK)
   - 간이 `/brainstorm` 호출 시뮬레이션: `yq eval '.name' skills/brainstorm/SKILL.md` → "brainstorm" 확인
2. 플러그인 사이즈 (`du -sh clean-harness`) 출력 (정보용)
3. 스크립트 종료 시 tmpdir cleanup

**검증 (AC-1)**:
- 외부 의존(Python/Node) 0개 확인
- `/brainstorm` 호출 시뮬 성공
- 스크립트 exit 0

---

## 📁 산출물

- `.claude/plans/03-design/final-spec.md` (§3.5·§4.5·§11-5·6·7 보강)
- `.claude/plans/04-planning/porting-matrix.md` (§2 컬럼 추가)
- `README.md` · `README.ko.md`
- `CLAUDE.md` · `AGENTS.md`
- `LICENSE` · `NOTICES.md` · `CONTRIBUTING.md`
- `RELEASE-CHECKLIST.md`
- `.claude/state/ac-final.json`
- `__tests__/integration/test-clean-install.sh`
- `skills/*/SKILL.md` description 미세 수정 (필요 시만)

## ⚙️ 실행 제약

- bash + jq + yq + uuidgen만 (v3.3 §4.1). **Python 금지**.
- SPDX identifier `MIT` · DCO sign-off 절차 필수
- final-spec 수정 범위 **§3.5 · §4.5 · §11-5·6·7 한정**. 다른 섹션 미수정.
- 5 스킬 SKILL.md 본문 수정 금지 (description frontmatter만 T-W8-05에서 미세 조정)
- implementation-plan 체크박스만 수정
- `_git-workflow-template.md` 순서 엄수
- 권한 dialog 나오면 "2" always allow

## ✅ 완료 기준

1. T-W8-PRE-01: §3.5 6축 강제 표 + --skip-axis 스펙 + §11-5 승격
2. T-W8-PRE-02: porting-matrix §2 2 컬럼 + SPDX `MIT` + §11-6 승격
3. T-W8-PRE-03: 프론트매터 5 스킬 일관성 + 포지셔닝 1문장 + composability + /orchestrate 비교표 + §11-7 승격
4. T-W8-01·02: README.md + README.ko.md 동형 섹션 + 한·영 예제 → **AC-8 GREEN**
5. T-W8-03·04: CLAUDE.md + AGENTS.md
6. T-W8-05: 5 스킬 description 한·영 병기 확인
7. T-W8-06: RELEASE-CHECKLIST + ac-final.json 8 AC 판정
8. T-W8-07: LICENSE(MIT) + NOTICES(6 상류) + CONTRIBUTING(DCO)
9. T-W8-08: test-clean-install.sh PASS → **AC-1 GREEN**
10. 체크박스 T-W8-PRE-01·02·03 + T-W8-01~08 업데이트 (11개)
11. 자체 커밋+푸시

---

## 🔄 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

git pull --rebase origin main || { echo "pull failed"; exit 1; }

sed -i '' \
  -e 's|^- \[ \] \*\*T-W8-PRE-01\*\*|- [x] **T-W8-PRE-01**|' \
  -e 's|^- \[ \] \*\*T-W8-PRE-02\*\*|- [x] **T-W8-PRE-02**|' \
  -e 's|^- \[ \] \*\*T-W8-PRE-03\*\*|- [x] **T-W8-PRE-03**|' \
  -e 's|^- \[ \] \*\*T-W8-01\*\*|- [x] **T-W8-01**|' \
  -e 's|^- \[ \] \*\*T-W8-02\*\*|- [x] **T-W8-02**|' \
  -e 's|^- \[ \] \*\*T-W8-03\*\*|- [x] **T-W8-03**|' \
  -e 's|^- \[ \] \*\*T-W8-04\*\*|- [x] **T-W8-04**|' \
  -e 's|^- \[ \] \*\*T-W8-05\*\*|- [x] **T-W8-05**|' \
  -e 's|^- \[ \] \*\*T-W8-06\*\*|- [x] **T-W8-06**|' \
  -e 's|^- \[ \] \*\*T-W8-07\*\*|- [x] **T-W8-07**|' \
  -e 's|^- \[ \] \*\*T-W8-08\*\*|- [x] **T-W8-08**|' \
  .claude/plans/04-planning/implementation-plan.md

git add .claude/plans/03-design/final-spec.md .claude/plans/04-planning/porting-matrix.md README.md README.ko.md CLAUDE.md AGENTS.md LICENSE NOTICES.md CONTRIBUTING.md RELEASE-CHECKLIST.md .claude/state/ac-final.json __tests__/integration/test-clean-install.sh .claude-plugin/plugin.json skills/ .claude/plans/04-planning/implementation-plan.md

git commit -s -m "$(cat <<'EOF'
feat(W8): 문서화 + 오픈소스 배포 — MVP 릴리스 준비 완료

- T-W8-PRE-01: §11-5 승격 — 6축 강제 범위 + --skip-axis 스펙
- T-W8-PRE-02: §11-6 승격 — 라이선스 매트릭스 + 상류 sync (SPDX MIT)
- T-W8-PRE-03: §11-7 승격 — 프론트매터/포지셔닝/composability/orchestrate 비교
- T-W8-01·02: README.md 영어 + README.ko.md → AC-8
- T-W8-03·04: CLAUDE.md + AGENTS.md
- T-W8-05: 5 스킬 description 한·영 병기 점검
- T-W8-06: RELEASE-CHECKLIST + ac-final.json (Hard AC 8 판정)
- T-W8-07: LICENSE(MIT) + NOTICES(6 상류) + CONTRIBUTING(DCO)
- T-W8-08: test-clean-install.sh → AC-1
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

- final-spec §3.5·4.5·11-5·6·7 외 섹션 수정
- 5 스킬 SKILL.md 본문 수정 (description frontmatter만 T-W8-05에서 미세 수정)
- implementation-plan 체크박스 외 라인 수정
- `.claude/memory/` 직접 쓰기
- Python/Node 사용
- `LICENSE`를 MIT 이외로 변경
- push 3회 실패 시 중단

시작하세요.

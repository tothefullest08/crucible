# W1 Chain A — T-W1-04 + T-W1-05 (hooks/session-start + using-harness SKILL)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v3.1 최신 (§4.3 보안 제약 필수 준수)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/implementation-plan.md` §W1 — T-W1-04·05 정의
4. `/Users/ethan/Desktop/personal/harness/hooks/hooks.json` — SessionStart 경로 등록됨
5. `/Users/ethan/Desktop/personal/harness/hooks/README.md` — 이벤트 역할
6. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/superpowers/hooks/session-start` 패턴
   - `/Users/ethan/Desktop/personal/harness/references/superpowers/skills/` 하위 SKILL.md 구조
   - `/Users/ethan/Desktop/personal/harness/references/hoyeon/skills/` 하위 SKILL.md 한·영 병기 패턴

## 🎯 태스크 (순차)

### T-W1-04 — `hooks/session-start` 스크립트 (4h) 🚨 P0-8

**경로**: `hooks/session-start` (실행 가능, chmod +x)
**셰뱅**: `#!/usr/bin/env bash`

**기능**:
- `skills/using-harness/SKILL.md`를 읽어 stdout 출력 → Claude가 SessionStart 페이로드로 주입
- 페이로드 파일 SHA256 해시 검증 placeholder: `plugin.json`에 `harness.payload_sha256` 필드가 있으면 비교, 없으면 skip (MVP 단계)
- 오류 시 stderr 로그 후 exit 0 (세션 진입 차단 금지)

**보안 제약** (v3.1 §4.3 준수):
- 모든 변수는 `"$var"` 쌍따옴표
- `eval` 금지
- 파일 경로 생성 시 `[a-zA-Z0-9_/.-]` 화이트리스트 검증 (slug)
- 외부 입력을 command argument로 직접 보간 금지
- `set -euo pipefail` 선언

**검증**:
- `shellcheck hooks/session-start` 통과 (경고 0)
- `bash -n hooks/session-start` 문법 OK
- 수동 실행: `bash hooks/session-start` 시 SKILL.md 내용 그대로 출력

---

### T-W1-05 — `skills/using-harness/SKILL.md` (4h)

**경로**: `skills/using-harness/SKILL.md`

**frontmatter** (YAML, CE/hoyeon 스타일):
```yaml
---
name: using-harness
description: "하네스 6축 런북 / Harness 6-axis runbook — SessionStart 시 자동 주입되는 현재 세션의 6축 진입 가이드"
---
```

**본문 필수 섹션** (superpowers 패턴 7항 체크리스트 준수):
1. **하네스 6축 개요** — 구조·맥락·계획·실행·검증·개선 1줄씩
2. **진입 명령 매핑** —
   - 계획: `/brainstorm` → `/plan`
   - 실행: (사용자 수동 작업)
   - 검증: `/verify`
   - 개선: `/compound`
   - 오케스트레이션: `/orchestrate` (Stretch)
3. **언제 무엇을 쓰나** — 시나리오별 권장 진입점
4. **승격 게이트 원칙** — 자동 저장 금지, 유저 승인 필수 (v3 §3 참조)
5. **6축 강제 적용 범위** — /plan·/verify·/orchestrate 기본 ON, /brainstorm·/compound OFF (v3 §3.5 참조)
6. **한국어 / 영어 UX** — description 한·영 병기 원칙
7. **에러·제한사항** — JSONL 스키마 변화 시 컴파운딩 비활성화 (v3 §4.2 degradation 참조)

**길이**: 200줄 이내 (200줄 초과 시 AI 성능 저하, v3 §2 맥락 원칙)

**검증**:
- frontmatter YAML 파싱 가능
- 7섹션 모두 존재
- `skills/using-harness/SKILL.md` 경로 정확

---

## 📁 산출물

- `hooks/session-start` (실행 가능 bash 스크립트)
- `skills/using-harness/SKILL.md` (frontmatter + 7섹션)

## ⚙️ 실행 제약

- **한국어 주석 · 영어 코드** — bash 스크립트 내부는 영어, SKILL.md 본문은 한국어 primary + 영어 병기
- **bash+jq만** — Python/Node 사용 금지
- **레퍼런스 파일 수정 금지** — `references/` read-only
- **다른 패널과 파일 충돌 없음**: hooks/session-start, skills/using-harness/만 건드림
  - 패널 2가 scripts/ 건드림 (충돌 없음)
  - 패널 3이 README/LICENSE 등 루트 건드림 (충돌 없음)
  - 패널 4가 04-planning/s11-3-ux-draft.md 건드림 (충돌 없음)

## ✅ 완료 기준

1. `hooks/session-start` 생성 + chmod +x + shellcheck 통과
2. `skills/using-harness/SKILL.md` 생성 + 7섹션 + 200줄 이내
3. 수동 테스트: `bash hooks/session-start` 실행 시 SKILL.md 출력
4. 체크박스 업데이트 + 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시 워크플로우 (필수)

각 태스크 완료 후 **본 패널에서 직접** git 작업 수행:

```bash
# 1. implementation-plan.md 체크박스 업데이트
#    T-W1-04, T-W1-05 각각 - [ ] → - [x]
sed -i '' \
  -e 's|^- \[ \] \*\*T-W1-04\*\*|- [x] **T-W1-04**|' \
  -e 's|^- \[ \] \*\*T-W1-05\*\*|- [x] **T-W1-05**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

# 2. pull rebase (다른 패널의 push 흡수)
cd /Users/ethan/Desktop/personal/harness && git pull --rebase origin main

# 3. 본인 파일만 stage
git add hooks/session-start skills/using-harness/ .claude/plans/2026-04-19/04-planning/implementation-plan.md

# 4. 커밋
git commit -m "$(cat <<'EOF'
feat(W1): T-W1-04·05 hooks/session-start + using-harness SKILL

- hooks/session-start: bash 스크립트, shellcheck 통과, 🚨 P0-8 보안 제약 적용
- skills/using-harness/SKILL.md: 6축 런북, frontmatter + 7섹션, 200줄 이내
- 체크박스 T-W1-04·05 업데이트
EOF
)"

# 5. push (실패 시 pull --rebase 후 재시도, 최대 3회)
git push origin main || (git pull --rebase origin main && git push origin main) || (git pull --rebase origin main && git push origin main)
```

## 🛑 금지

- `.claude-plugin/`, `hooks/hooks.json`, `hooks/README.md` 수정 (T-W1-01·02·03에서 생성 완료)
- `scripts/`, `final-spec.md`, `implementation-plan.md` 외 문서 수정 (다른 패널 범위)
- T-W1-06 이후 태스크 선수행
- references/ 수정
- push 실패 3회 연속 시 추가 시도 금지, 메시지로 알림

시작하세요.

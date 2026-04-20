# OSS 배포 문서 4종 초안 지시서 (패널 3, Sonnet)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v3.1 (§1 포지셔닝 · §4.5 라이선스 정책)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/user-decisions-5.md` — 포지셔닝 최종안 (§5)
4. **레퍼런스 README** (참고용, 수정 금지):
   - `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/README.md`
   - `/Users/ethan/Desktop/personal/harness/references/hoyeon/README.md` + `README.ko.md`
   - `/Users/ethan/Desktop/personal/harness/references/superpowers/README.md`
   - `/Users/ethan/Desktop/personal/harness/references/ouroboros/README.md`

## 🎯 태스크

오픈소스 배포용 4개 문서를 **초안** 수준으로 작성. W8 정식 배포 전이지만 초기 커밋 시 표준 관행.

### 1. `README.md` (루트, 영어 primary)

- **상단**: v3.1 §1 포지셔닝 2문장 (영어 번역 + 한국어 병기)
- 섹션:
  - Badges placeholder (License MIT · Status WIP · Claude Code compatible)
  - Overview (2~3줄)
  - Features (6축 + 핵심 기능 3: 암묵지 해소·검증 루프·컴파운딩)
  - Installation (Claude Code marketplace 등록 예정 주석 + 로컬 설치 placeholder)
  - Usage (5개 slash command 예시 — 각 1줄 설명, 상세는 skills/using-harness)
  - Status: **Work In Progress** (현재 Phase 4 완료, W1 구현 진행 중)
  - Reference/Credits (Built on top of CE, hoyeon, superpowers, ouroboros, p4cn, agent-council — MIT compatible)
  - License (MIT, DCO 필수 — CONTRIBUTING.md 참조)
  - Korean version link: [README.ko.md](./README.ko.md) (선택적 추가, 시간 되면 한국어 버전도)
- **길이**: 150~250줄

### 2. `LICENSE` (루트)

- 표준 **MIT License** 텍스트
- Copyright line: `Copyright (c) 2026 Ethan <tothefullest08@gmail.com>`
- 정확한 MIT 원문 (opensource.org/licenses/MIT 기준) 그대로 복사

### 3. `CONTRIBUTING.md` (루트)

- 섹션:
  - How to contribute (issues, PRs)
  - **DCO sign-off** 필수: 모든 커밋에 `Signed-off-by: Name <email>` (git commit -s 안내)
  - Commit message convention (conventional commits: feat·fix·docs·chore·refactor·test·perf·ci)
  - PR checklist (test pass · shellcheck · JSON validate · 관련 §11 deadline 확인)
  - Code of conduct link (placeholder — 추후 추가)
  - Development setup (bash, jq 필요 — v3 §4.1 준수)
- **길이**: 80~150줄

### 4. `.github/DCO.md` (DCO 전문)

- Developer Certificate of Origin v1.1 **원문** (developercertificate.org)
- 서명 방법: `git commit -s` 또는 `Signed-off-by: Name <email>` 수동 추가
- CI/PR에서의 DCO 검증 정책 placeholder (추후 GitHub Actions DCO bot 추가 예정)

---

## 📁 산출물

- `/Users/ethan/Desktop/personal/harness/README.md` (신규)
- `/Users/ethan/Desktop/personal/harness/LICENSE` (신규)
- `/Users/ethan/Desktop/personal/harness/CONTRIBUTING.md` (신규)
- `/Users/ethan/Desktop/personal/harness/.github/DCO.md` (신규, `.github/` 디렉토리 생성)

## ⚙️ 실행 제약

- **README·CONTRIBUTING은 영어 primary** (OSS 관행). 한국어 README.ko.md는 선택.
- **LICENSE는 MIT 원문 그대로** — 변형 금지
- **DCO.md는 원문 그대로** (developercertificate.org)
- **다른 패널과 파일 충돌 없음**:
  - 루트의 README, LICENSE, CONTRIBUTING, .github/ 만 생성
  - 패널 1(hooks/skills) · 패널 2(scripts/__tests__) · 패널 4(04-planning/) 영역 안 건드림
- **Sonnet 모델** — 템플릿 기반 반복 작업, 빠른 생성 OK

## ✅ 완료 기준

1. 4개 신규 파일 생성
2. README.md 150줄 이상 + v3.1 포지셔닝 영어 번역 상단에 삽입
3. LICENSE MIT 원문 + 2026 Ethan 저작권 표기
4. CONTRIBUTING DCO sign-off 안내 포함
5. .github/DCO.md developercertificate.org 원문
6. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시 워크플로우 (필수)

OSS 배포 문서는 W8 태스크 선취이므로 implementation-plan 체크박스 업데이트는 **안 함**. 커밋 메시지에 명시.

```bash
cd /Users/ethan/Desktop/personal/harness

# 1. pull rebase
git pull --rebase origin main

# 2. stage (루트 + .github/)
git add README.md LICENSE CONTRIBUTING.md .github/

# 3. commit
git commit -s -m "$(cat <<'EOF'
docs(OSS): README + LICENSE + CONTRIBUTING + DCO 초안 (W8 선취)

- README.md: v3.1 §1 포지셔닝 기반 + 6축 소개 + WIP 상태
- LICENSE: MIT (Copyright 2026 Ethan)
- CONTRIBUTING.md: DCO sign-off 필수 + conventional commits + PR 체크리스트
- .github/DCO.md: Developer Certificate of Origin v1.1 원문
EOF
)"

# 4. push (재시도 3회)
git push origin main || (git pull --rebase origin main && git push origin main) || (git pull --rebase origin main && git push origin main)
```

**주의**: 커밋 자체도 DCO sign-off 포함(`-s` 플래그). 기존 커밋들은 과거 메인 세션에서 이미 생성되어 소급 적용 불가. 본 커밋부터 적용 원칙 시작.

## 🛑 금지

- `.claude-plugin/`, `hooks/`, `skills/`, `scripts/`, `__tests__/` 수정 (다른 패널 범위)
- `final-spec.md`, `implementation-plan.md` 수정
- references/ 수정
- LICENSE 원문 변형 (토씨 하나도 건드리지 말 것)

시작하세요.

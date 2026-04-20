# W1 기초 스캐폴드 — T-W1-01·02·03 지시서 (하단 패널)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v3 최신 (§2.1~§5 아키텍처, §4.1 런타임 · §4.3 보안 · §4.5 라이선스)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` §W1 — T-W1-01·02·03 정의
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/porting-matrix.md` — 포팅 자산 #28 (agent-council marketplace 구조)
5. **레퍼런스 실물** (참고용, 수정 금지):
   - `/Users/ethan/Desktop/personal/harness/references/agent-council/.claude-plugin/marketplace.json`
   - `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/.claude-plugin/plugin.json`
   - `/Users/ethan/Desktop/personal/harness/references/hoyeon/hooks/hooks.json` (존재 시, 없으면 `references/hoyeon/.claude-plugin/`)

## 🎯 태스크

W1의 **첫 3개 실질 스캐폴드 태스크**를 순차 수행. 실제 파일 생성 Phase 진입 지점.

### T-W1-01 — `.claude-plugin/plugin.json` 5필드 minimal (2h) → AC-1

**목표**: 플러그인을 Claude Code가 인식하도록 최소 메타데이터.

**기본 5필드** (CE plugin.json 참조):
- `name`: `harness`
- `version`: `0.1.0` (semver 초기)
- `description`: v3 §1 TL;DR의 포지셔닝 2문장 중 **한국어 단축판 1줄** + 영어 단축판 1줄 (description 한·영 병기, v3 §2.2 Dec 13 기반)
- `author`: Git config `user.name` + `user.email` 포함 (`ethan <tothefullest08@gmail.com>`)
- `license`: `MIT` (v3 §4.5)

그 외 필드 (CE 레퍼런스에 있으면 복사):
- `keywords`: ["crucible", "compound", "6-axis", "planning", "brainstorm"] 등 5~8개
- `repository`: GitHub URL `https://github.com/tothefullest08/crucible` (HTTPS)

**경로**: `/Users/ethan/Desktop/personal/harness/.claude-plugin/plugin.json`

**검증**:
- JSON 유효성 (jq가 파싱 가능)
- 외부 의존 0 — `dependencies` 필드 비우기
- CE plugin.json과 동일 스키마 구조 유지

---

### T-W1-02 — `.claude-plugin/marketplace.json` agent-council 구조 (2h) → AC-1

**목표**: 플러그인 마켓플레이스 manifest (agent-council 스타일 = primary).

**기본 구조** (agent-council marketplace.json 참조):
- `name`: `harness`
- `owner`: `{ "name": "ethan", "email": "tothefullest08@gmail.com" }`
- `plugins`: 단일 엔트리 — name `harness`, source `./` 또는 동일 repo
- (선택) `categories`, `tags`

**경로**: `/Users/ethan/Desktop/personal/harness/.claude-plugin/marketplace.json`

**검증**:
- JSON 유효성
- agent-council marketplace.json 스키마와 동형
- `plugin.json`과 name 일치

---

### T-W1-03 — `hooks/hooks.json` 4이벤트 등록 (2h)

**목표**: Claude Code가 SessionStart · UserPromptSubmit · PostToolUse · Stop 4개 이벤트에서 우리 훅을 호출하도록 등록.

**기본 구조**:
```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start" }] }
    ],
    "UserPromptSubmit": [...],
    "PostToolUse": [...],
    "Stop": [...]
  }
}
```

**주의**: 실제 스크립트 파일(`hooks/session-start` 등)은 **T-W1-04 이후 생성** — 이 태스크에서는 **경로 등록만** 하고 스크립트 파일은 아직 안 만듦. 경로가 미리 선언되어 있어야 T-W1-04가 이어받을 수 있음.

**이벤트별 용도 주석** (JSON은 주석 불가 → 별도 `hooks/README.md`에 기록):
- SessionStart: `using-harness.md` 페이로드 주입 (superpowers 패턴, T-W1-04·05)
- UserPromptSubmit: `correction-detector.sh` 트리거 (W6 구현)
- PostToolUse: `validate-output.sh` + `drift-monitor.sh` (W4·W6 구현)
- Stop: `/session-wrap` 트리거 (W6 구현)

**경로**: 
- `/Users/ethan/Desktop/personal/harness/hooks/hooks.json`
- `/Users/ethan/Desktop/personal/harness/hooks/README.md` (각 훅 역할·추가 예정 주차)

**검증**:
- JSON 유효성
- 4이벤트 모두 선언
- hoyeon 훅 패턴과 구조 일관성

---

## 📁 산출물 (최종)

1. `.claude-plugin/plugin.json` (신규)
2. `.claude-plugin/marketplace.json` (신규)
3. `hooks/hooks.json` (신규)
4. `hooks/README.md` (신규, 훅 역할 주석)

## ⚙️ 실행 제약

- **한국어 주석 · 영어 JSON 값** (description 병기 허용)
- **레퍼런스 파일 수정 금지** — `references/` 는 read-only
- **final-spec.md · implementation-plan.md 수정 금지** — 상단 패널 전담
- **T-W1-04 이후 태스크 선점 금지** — 실제 훅 스크립트 본문은 이 패널에서 작성하지 않음
- **bash+jq만** — Python/Node 사용 금지 (v3 §4.1)
- **외부 의존 0** — 플러그인 설치에 npm/pip/brew 불필요

## ✅ 완료 기준

1. 4개 신규 파일 생성 (`.claude-plugin/plugin.json`·`marketplace.json`, `hooks/hooks.json`·`README.md`)
2. `jq empty <file>` 로 JSON 유효성 통과 (3개 JSON 모두)
3. `plugin.json` name = `marketplace.json` plugins[0].name = `harness`
4. `hooks.json` 4개 이벤트 등록 (SessionStart·UserPromptSubmit·PostToolUse·Stop)
5. 상단 패널 작업(§11-1 승격)과 **파일 충돌 없음**

## 🛑 금지

- `final-spec.md`, `implementation-plan.md`, 기타 plans/ 수정 (상단 패널 전담)
- T-W1-04 이후 태스크 범위 (session-start 스크립트 · using-harness SKILL 등) 선수행
- references/ 수정
- git commit/push — 구현 작업만, 커밋은 이후 별도 이터레이션에서 일괄

시작하세요.

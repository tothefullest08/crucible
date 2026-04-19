# harness Hooks

Claude Code 이벤트에 등록된 훅 스크립트의 역할과 도입 주차를 기록한다.
`hooks.json` 은 경로 등록만 담당하며, 실제 스크립트 본문은 아래 표의 "도입 주차" 에 맞춰 순차 구현된다.

## 등록된 이벤트

| 이벤트 | 스크립트 | 역할 | 도입 주차 |
| --- | --- | --- | --- |
| `SessionStart` | `hooks/session-start.sh` | `using-harness.md` 페이로드 주입 (superpowers 패턴). 플러그인 활성화 시 1회 실행되어 현재 세션에 하네스 6축 런북을 로드한다. | T-W1-04 · T-W1-05 |
| `UserPromptSubmit` | `hooks/correction-detector.sh` | 유저 프롬프트에서 재지시·수정 패턴을 탐지해 KU(Knowledge Unit) 후보를 표지한다. 승격 게이트(§11-1)의 입력 수집 지점. | W6 |
| `PostToolUse` (`Task\|Skill`) | `hooks/validate-output.sh` | 에이전트·스킬 종료 시 `validate_prompt` 프론트매터 기반 출력 검증. 6축 중 **검증** 축의 자동화 지점. | W4 |
| `PostToolUse` (all) | `hooks/drift-monitor.sh` | 도구 사용 패턴의 드리프트(반복 실패·스코프 이탈)를 모니터링해 세션 말미 `/session-wrap` 에 요약 신호를 전달한다. | W6 |
| `Stop` | `hooks/session-wrap.sh` | 세션 종료 시 `/session-wrap` 스킬을 트리거해 KU 승격·로그 적재를 수행한다. | W6 |

## 작성 제약

- **bash + jq 만 사용** — Python/Node 금지 (final-spec v3 §4.1 런타임 정책).
- **외부 의존 0** — 플러그인 설치에 npm/pip/brew 불필요.
- **`${CLAUDE_PLUGIN_ROOT}` 사용** — Claude Code가 플러그인 루트로 해석하는 환경변수. 절대 경로 하드코딩 금지.
- **실패 시 non-fatal** — 훅 스크립트는 exit 0 이 기본. 사용자 작업을 막지 않도록 방어적으로 작성한다.
- **스크립트 작성 시 `hooks.json` 경로와 일치 확인** — 파일명 변경 시 `hooks.json` 과 본 표를 동시에 업데이트해야 한다.

## 참고 레퍼런스

- `references/hoyeon/hooks/hooks.json` — 이벤트별 다중 매처 패턴.
- `references/superpowers/` — `using-*.md` SessionStart 주입 패턴.
- `references/compound-engineering-plugin/` — PostToolUse 검증 훅 구조.

# Project Guardrails — crucible

> 프로젝트 전용 규칙. 글로벌 `~/.claude/rules/*` 위에 덮어쓴다.
> 에이전트는 이 파일을 모든 세션에서 읽는다고 가정하고 작성할 것.

---

## 1. Runtime

- **bash (≥ 4) + `jq` (≥ 1.6) + `uuidgen` + `flock` 만 사용**. Python·Node 금지.
- 쉘 외 도구가 필요하면 먼저 [CLAUDE.md](../../CLAUDE.md) Non-goals 섹션을 업데이트하고 사용자 승인을 받은 후에 도입한다.
- 새 의존성 추가 시 `NOTICES.md`에 upstream 라이선스 기록 의무.

## 2. Memory write gate

- `.claude/memory/{tacit,corrections,preferences}/*` 쓰기는 **사용자 명시 승인 후에만** 수행.
- `/compound` 스킬이 promotion 후보를 제시할 때 반드시:
  1. 후보 요약을 사용자에게 보여주고
  2. 저장 여부를 묻고
  3. 승인이 있는 경우에만 쓰기 수행.
- 자동 저장 금지. "저장할까요?"를 먼저 물어라.

## 3. Axis skip policy

- 세션에서 `--skip-axis N` 은 허용.
- **단, axis 5(검증)을 skip 하려면 `--acknowledge-risk` 플래그 필수**.
- skip이 발생하면 `.claude/memory/corrections/skip-log.md`에 다음 포맷으로 기록:
  ```
  - {ISO8601} · axis={N} · reason="…" · session_id={id}
  ```

## 4. Session end protocol

- 작업 종료 전 변경 영역을 커버하는 `__tests__/integration/test-ac*.sh` 스크립트 **1개 이상** 실행.
- 스크립트 실패 시 종료 금지 — 실패 로그를 사용자에게 보여주고 대응 방향을 합의.
- UI/frontend 변경이 있으면 실제 브라우저에서 한 번 직접 확인한 후 종료.

## 5. Commit / push

- 커밋은 **`git commit -s`** (DCO Signed-off-by 의무). hook 우회(`--no-verify`) 금지.
- 메시지는 Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `perf:`, `ci:`).
- push는 rebase-first: `git pull --rebase origin <branch>` → 충돌 없으면 `git push`.
- `--force` push는 사용자가 명시적으로 허락한 경우에만.
- `main` / `master` 에 `--force` push는 합의되었어도 한 번 더 확인.

## 6. File policy

- `.env`, `.env.*`, `credentials.*`, `*.pem`, `*.key`, SSH 키 파일은 **쓰기 자체를 금지**. PreToolUse 훅이 block 한다.
- `.claude/settings.local.json` 은 커밋 금지 (`.gitignore` 반영됨).
- `.claude/` 전체가 `.gitignore` 됨 (commit `96977fc`). 배포 산출물은 plugin 디렉토리에만 존재.

## 7. Scope discipline

- 한 번의 요청 범위 밖으로 리팩터링·기능 추가 금지. 버그 수정은 수정만.
- "주변 정리" 본능은 막는다. 별도 티켓을 제안할 것.
- 의심스러우면 멈추고 사용자에게 묻는다.

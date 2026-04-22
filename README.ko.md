# crucible

> **crucible은 승격 게이트 통과 학습만 저장하는, 6축(Brainstorm→Plan→Verify→Compound) 컴파운딩 메모리 Claude Code 플러그인입니다.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![SPDX](https://img.shields.io/badge/SPDX-MIT-blue.svg)](./LICENSE)
[![DCO](https://img.shields.io/badge/DCO-required-green.svg)](./CONTRIBUTING.md#dco-sign-off-required)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-8A2BE2.svg)](https://claude.com/claude-code)

[English](./README.md) · 한국어

---

## 왜 crucible 인가 (Why)

Claude Code 세션에서 반복되는 3가지 실패 모드. `crucible`은 유저 승인 게이트를 통과하지 않은 어떤 학습도 영속 저장하지 않습니다.

- **반복 실수** — 같은 버그를 매 세션마다 다시 발견합니다. 수정은 세션 메모리에서 증발합니다.
- **암묵지 휘발** — 프로젝트 컨벤션, 팀 결정, "아 그거 틀렸다" 순간이 기록되지 않고 사라집니다.
- **6축 메타 루프 부재** — 기존 플러그인은 brainstorm/plan/verify/compound 중 *하나*만 자동화합니다. 6축(Structure · Context · Plan · Execute · Verify · Improve)을 하드 게이트로 강제하는 플러그인은 없습니다.
- **Auto-memory 노이즈** — 자동 메모리 저장 플러그인은 큐레이션 없는 저신호 항목으로 이후 컨텍스트를 오염시킵니다.
- **검증 스킵** — Verify 축 스킵은 보통 키 한 번 실수로 발생합니다. `crucible`는 `--acknowledge-risk` 플래그 없이는 스킵 자체를 릴리스 블로커로 취급합니다.

---

## 설치 (Install)

`crucible`는 외부 의존이 0인 Claude Code 플러그인입니다 (`bash` + `jq`만 사용). Claude Code 세션 내에서 아래 3줄로 marketplace 등록 · 설치 · 리로드까지 완료됩니다:

```
/plugin marketplace add tothefullest08/crucible
/plugin install crucible@crucible
/reload-plugins
```

`/reload-plugins` 직후부터 6개 슬래시 커맨드 (`/crucible:brainstorm` · `/crucible:plan` · `/crucible:verify` · `/crucible:compound` · `/crucible:orchestrate` · `/crucible:log`)와 PreToolUse 가드 훅이 현재 세션에서 바로 활성화됩니다. 확인:

```
/plugin list         # Installed 탭에 crucible@crucible 표시
```

`/plugin install` 실행 시 스코프 선택 대화상자가 뜹니다:

- **User scope** — 본인의 모든 Claude Code 세션에서 사용 (상시 사용 권장).
- **Project scope** — `.claude/settings.json`에 커밋, 레포 협업자 전원 공유.
- **Local scope** — 현재 레포 한정, 공유 안 됨 (임시 시도 · dogfood 권장).

제거는 설치와 대칭:

```
/plugin uninstall crucible@crucible
/plugin marketplace remove crucible
```

### 로컬 개발 경로 (컨트리뷰터용)

`crucible` 자체를 수정하는 경우 GitHub에서 가져오지 말고 로컬 경로를 marketplace로 등록하세요:

```bash
git clone https://github.com/tothefullest08/crucible.git ~/src/crucible
# 이후 Claude Code 내에서:
#   /plugin marketplace add ~/src/crucible
#   /plugin install crucible@crucible
```

런타임 요구사항: `bash` (≥ 4), `jq` (≥ 1.6), `uuidgen`, `flock`. Python/Node 불필요. 개발 환경 상세는 [CONTRIBUTING.md](./CONTRIBUTING.md#development-setup) 참조.

---

## 6 스킬 (Skills)

- `/brainstorm` — 3-lens(vague · unknown · metamedium) clarify 패스로 진행하는 요구사항 브레인스토밍. `.claude/plans/YYYY-MM-DD-{slug}-requirements.md`로 저장.
- `/plan` — 요구사항 문서에서 Markdown + YAML frontmatter 하이브리드 플랜 생성. acceptance criteria · evaluation principles(가중치) · exit conditions 포함.
- `/verify` — `qa-judge`로 산출물 채점 + Ralph Loop 재시도 + Charter Preflight.
- `/compound` — 반복 패턴·유저 정정·`/session-wrap` 트리거를 위한 승격 게이트. 유저 승인된 후보만 `.claude/memory/`에 저장.
- `/orchestrate` *(Stretch)* — 위 4 스킬을 end-to-end 파이프라인으로 연결. CP-0~CP-5 디스크 체크포인트로 크래시 안전.
- `/log` — 수동 dogfooding 로거. qualitative 노트(4 카테고리: good · pain · ambiguous · request) + 자동 추출 structured 이벤트(skill_call · promotion_gate · axis_skip · qa_judge)를 append-only JSONL 로 저장. 로컬은 `.claude/dogfood/log.jsonl`, 글로벌 mirror 는 `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` (opt-in, `CRUCIBLE_DOGFOOD_GLOBAL=0` 으로 비활성). `.gitignore` 자동 등록.

**상세** → [`docs/skills/`](./docs/skills/) (스킬별 Paradigm · Judgment · Design Choices — 한국어: [`brainstorm.ko.md`](./docs/skills/brainstorm.ko.md) · [`plan.ko.md`](./docs/skills/plan.ko.md) · [`verify.ko.md`](./docs/skills/verify.ko.md) · [`compound.ko.md`](./docs/skills/compound.ko.md) · [`orchestrate.ko.md`](./docs/skills/orchestrate.ko.md) · [`dogfood.ko.md`](./docs/skills/dogfood.ko.md)).

---

## 6축 하네스 (6-Axis Harness)

모든 산출물은 6축 게이트(**Structure · Context · Plan · Execute · Verify · Improve**)를 통과합니다. `--skip-axis N`은 허용되지만 `--skip-axis 5`는 `--acknowledge-risk` 조합이 필수 — 검증 스킵은 명시적 릴리스 블로커입니다.

**상세** → [`docs/axes.ko.md`](./docs/axes.ko.md) (전체 matrix · 스킬 × 축 표 · skip 정책 근거).

---

## 예제 (Example)

플러그인 설치 후 모든 슬래시 커맨드는 `crucible:` 네임스페이스를 가집니다 (설치 섹션 참조). Claude Code는 이름이 모호하지 않으면 prefix 없이도 해석하지만, 명시형이 항상 안전합니다.

**한국어 트리거로 단일 스킬 호출:**

```
"브레인스토밍하자 - 다크 모드 토글 추가"
# → /crucible:brainstorm 자동 호출 (description 트리거 매칭)
# → 3-lens clarify:
#    [vague]     사용자가 누구? 어떤 설정 패널?
#    [unknown]   시스템 다크 모드와 분리? 토글 persistence?
#    [metamedium] 토글 UI vs 자동 감지?
# → .claude/plans/2026-04-20-dark-mode-requirements.md 생성
```

**4축 파이프라인 (`/crucible:orchestrate`):**

```
/crucible:orchestrate "settings 패널에 다크 모드 토글 추가"
# → CP-0: brainstorm   → requirements.md
# → CP-1: plan         → plan.md (Markdown + YAML)
# → CP-2: verify       → qa-judge 리포트
# → CP-3: compound     → 승격 게이트 (y/N/e/s 응답)
# → CP-4: 산출물 링크 번들
# → CP-5: experiment-log.yaml 커밋
```

`/crucible:orchestrate`가 체크포인트 사이에서 중단되어도, 재실행 시 디스크에 기록된 마지막 CP부터 재개합니다 — 재작업 없음.

**상세** → [`docs/thresholds.ko.md`](./docs/thresholds.ko.md) (verdict band · retry cap · overlap 가중치) · [`docs/faq.ko.md`](./docs/faq.ko.md) (이 기본값의 근거 · synthetic fixture 한계 · production 튜닝 로드맵).

---

## 라이선스 (License)

**MIT** — [LICENSE](./LICENSE) 참조. SPDX 식별자: `MIT`.

기여는 **DCO sign-off** (`git commit -s`) 필수. 전체 워크플로와 Developer Certificate of Origin v1.1 원문은 [CONTRIBUTING.md](./CONTRIBUTING.md)에 있습니다.

---

## 감사의 말 (Acknowledgments)

`crucible`는 6개 상류 Claude Code 프로젝트의 자산을 포팅·각색했습니다. 전부 **MIT 라이선스**이며 재배포 호환입니다 (커밋 해시·sync 주기는 `NOTICES.md`에 요약):

- **hoyeon** — `validate_prompt` 훅 패턴, 6-agent verify 스택, 한국어 UX
- **ouroboros** — `qa-judge` JSON 스키마, Ralph Loop, Seed YAML, Ambiguity Gate
- **p4cn** (plugins-for-claude-natives) — `session-wrap` 2-phase 파이프라인, clarify 3-lens, `history-insight` 파서
- **superpowers** (obra/superpowers) — `SessionStart` 훅, `HARD-GATE` 태그, 3-stage Evaluator
- **compound-engineering-plugin** — 5-차원 overlap scoring, Auto Memory 규약, persistence discipline
- **agent-council** — marketplace 최소 구조, Wait cursor UX

저작권 고지 전문은 [NOTICES.md](./NOTICES.md)에 있습니다.

---

*[← English README](./README.md)*

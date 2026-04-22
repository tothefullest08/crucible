# `/dogfood` *(v1.1.0)*

> crucible 세션 피드백을 append-only JSONL 로 수집 — 고정 4 카테고리 qualitative 노트 + 자동 추출 4 structured 이벤트 — 를 로컬 로그와 opt-in 글로벌 mirror 에 기록.

[English](./dogfood.md) · 한국어

## 패러다임 (Paradigm)

`/dogfood`는 다른 스킬들에 대한 **근거 데이터를 수집하는 유일한 스킬**입니다. 방어하려는 실패 모드는 모든 자기개선 시스템이 결국 부딪히는 문제: `docs/thresholds.md`의 임계값은 synthetic fixture 기반 수작업 숫자이므로, 프로덕션 튜닝에는 실사용 데이터가 필수입니다. 자동 캡처는 저신호 엔트리로 큐레이트된 기록을 덮어버려 배제됐고, 수동 호출은 샘플 수를 희생해 레코드당 신호 대 잡음비를 올리는 trade-off 입니다. **qualitative 노트**(유저가 느낀 것)와 **structured 이벤트**(도구가 한 것)를 분리하는 설계는 UX 개선 분석과 임계값 튜닝 분석이 서로를 오염시키지 않게 합니다.

## 판정 (Judgment)

입력: 현재 Claude Code 세션 JSONL + 카테고리별 free-form 텍스트. 출력: `.claude/dogfood/log.jsonl` (로컬 primary) + opt-in `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` (크로스 프로젝트 집계용 글로벌 mirror) 에 append 되는 JSONL.

세션 JSONL 에서 추출되는 4 structured 이벤트:

| Event | 출처 | 주요 필드 |
|-------|------|----------|
| `skill_call` | 유저 슬래시 커맨드 (`/crucible:*`) 또는 `Skill` tool_use | `skill`, `args_summary` |
| `promotion_gate` | `AskUserQuestion` 중 "승격" / "promotion" / "저장할까요" 문구 포함 | `candidate_id`, `response`, `detector` |
| `axis_skip` | `--skip-axis` 를 담은 `Bash` tool_use | `axis`, `acknowledged`, `reason` |
| `qa_judge` | `{"score":…,"verdict":…}` 를 담은 `tool_result` 본문 | `score`, `verdict` |

유저가 multiSelect 로 선택하는 4 qualitative 카테고리:

- **`good`** — 잘 동작한 것, 유지할 가치.
- **`pain`** — 불편한 점, 개선 대상.
- **`ambiguous`** — 모호해서 되물은 것.
- **`request`** — 추가 feature 요청.

재귀 방지: `/crucible:dogfood` 호출은 파싱 단계에서 drop → 반복 호출 시 자기 자신이 로그에 쌓이지 않음.

## 설계 선택 (Design Choices)

- **수동 트리거, 자동 Stop-hook 아님.** 자동 캡처를 먼저 시도했으나 저신호 엔트리가 너무 많아 데이터셋 질이 낮아졌습니다. 유저가 기록할 만한 순간에 `/crucible:dogfood` 를 직접 호출 — 엔트리 수는 적지만 신호 밀도는 높습니다.
- **4 고정 카테고리 + free-form, 순수 free-form 아님.** 순수 free-form 은 몇 달 뒤 집계 불가, 순수 categorical 은 뉘앙스 손실. 하이브리드는 "모든 `pain` 중 `/verify` 언급된 건" 같은 쿼리를 저렴하게 유지하면서 맥락도 보존합니다.
- **Append-only JSONL, RDB 아님.** JSONL 은 git-diff 가능 · 쉘 grep 가능 · 분석 노트북으로 스트림하기 단순함. 스키마 변경이 마이그레이션을 요구하지 않음 — 옛 라인은 옛 모양 그대로 유지.
- **로컬 primary + opt-in 글로벌 mirror, 양자택일 아님.** 로컬 only 는 크로스 프로젝트 집계 상실, 글로벌 only 는 쓸 때마다 프라이버시 질문. 두 경로 + 단일 env var (`CRUCIBLE_DOGFOOD_GLOBAL=0`) opt-out 이 plugin-level 스키마 변경 없이 둘 다 커버합니다.
- **`{slug}-{hash}` 디렉토리 키.** slug 단독은 동명 레포 간 충돌, hash 단독은 가독성 zero. 절대 경로의 SHA256 앞 8자 (글로벌 메모리 `scripts/lib/project-id.sh` 와 동일 규칙) 가 가독성과 충돌 방지를 동시에 해결.
- **`.gitignore` 자동 등록, 멱등.** 로그는 로컬에 머물러야 함 — gitignore 라인이 blast-radius 방어선. 첫 호출 시 자동 추가 → 설정을 잊을 수 없음; 멱등성 → 반복 호출이 파일을 더럽히지 않음.
- **재귀 필터는 파서 내부의 skill-name 블랙리스트.** event-type 마커를 먼저 시도했으나 마커가 이후 분석에서 "아무도 원치 않는 3번째 축"으로 누출됨. 블랙리스트는 jq `startswith` 체크 1개 → 스키마가 깨끗하게 유지.
- **4 이벤트 타입, 모든 tool_use 아님.** Bash · Read · Write 등을 전부 담으면 로그가 10배로 팽창하지만 튜닝 결정에 매핑되는 이벤트는 거의 없음. 선택된 4종은 `docs/thresholds.md` 의 튜닝 대상 임계값과 1:1 대응.

## Thresholds

`/dogfood` 자체는 새로운 수치 임계값을 도입하지 않습니다 — **근거 데이터 소스**로서 기존 임계값이 나중에 재튜닝될 대상입니다. 교차 참조:

- `qa_judge` 점수/판정 밴드 — [`../thresholds.ko.md §1`](../thresholds.ko.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040).
- `promotion_gate` 오탐 예산 — [`../thresholds.ko.md §5`](../thresholds.ko.md#5-승격-게이트-오탐률--20-).
- 5-차원 overlap 가중치 — [`../thresholds.ko.md §7`](../thresholds.ko.md#7-5-차원-overlap-가중치).
- `axis_skip` 정책 (`--skip-axis 5 --acknowledge-risk`) — [`../axes.ko.md`](../axes.ko.md).

기록 cadence: 수동, 스케줄 리마인더 없음 (v1.2+ 로 이월). Mirror opt-out: `CRUCIBLE_DOGFOOD_GLOBAL=0`.

## 참고

- 상류 p4cn `history-insight` — JSONL-first · 쉘 only 파싱 접근에 영향.
- [`../axes.ko.md`](../axes.ko.md) — `/dogfood` 축 매트릭스 행 (Context hint, Improve hint; 하드 게이트 없음).
- [`../faq.ko.md`](../faq.ko.md) — 임계값 튜닝 로드맵, 기본값이 synthetic 인 이유.
- [`../../skills/dogfood/SKILL.md`](../../skills/dogfood/SKILL.md) — SKILL 계약 (`validate_prompt` 자기검증).
- [`../../scripts/parse-current-session.sh`](../../scripts/parse-current-session.sh) — 4 이벤트 추출기.
- [`../../scripts/dogfood-write.sh`](../../scripts/dogfood-write.sh) — writer + gitignore + 글로벌 mirror 로직.

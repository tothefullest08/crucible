# `/dogfood-digest` *(v1.2.0)*

> 누적된 `/crucible:dogfood` JSONL 을 read-only Markdown 제안 리포트 1건으로 정리 — 고정 3섹션(Threshold Calibration · Protocol Improvements · Promotion Candidates) + 인용된 모든 이벤트의 원본 위치 back-reference.

[English](./dogfood-digest.md) · 한국어

## 패러다임 (Paradigm)

`/dogfood-digest`는 `/dogfood`의 짝입니다. `/dogfood`가 다른 스킬에 대한 근거를 수집하는 유일한 스킬이라면, `/dogfood-digest`는 그 근거를 **읽고 개선안을 제안하는** 유일한 스킬입니다. 이 스킬이 방어하는 실패 모드는 "근거가 JSONL 에 쌓여도 아무도 다시 읽지 않는" 경우이고, 결코 진입하지 않는 모드는 "자동 변경 적용"입니다. 임계값과 SKILL.md 본문은 세션 간 load-bearing 이어서 단 한 번의 노이즈 기반 auto-edit 도 다음 모든 세션을 오염시킵니다. 그래서 digest 는 의도적으로 **제안 전용** — 정확히 한 파일(`.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md`)만 쓰고, 제안 수용 여부는 사람이 `/plan` 혹은 수동 편집 경로로 처리합니다. 집계기(`scripts/dogfood-digest.sh`, 플래그 파싱 + jq 필터)와 렌더러(`scripts/dogfood-digest-render.sh`, 3섹션 Markdown) 분리는 "어떤 이벤트를 포함할지"와 "어떻게 보여줄지"를 서로 독립적으로 튜닝 가능하게 합니다.

## 판정 (Judgment)

입력: 로컬 `.claude/dogfood/log.jsonl` 과 글로벌 mirror `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` 의 조합. `--last N`(기본 10) / `--since DATE|Nd` / `--all` 중 하나로 window, `--scope local|global|both`(기본 both) 로 scope 를 선택합니다. 출력: `.claude/plans/` 안의 Markdown 1건 — 그 외 추적 파일은 절대 건드리지 않습니다.

모든 JSONL 라인은 메모리 상에서 `_source_path` + `_line`(1-based) 이 주입되므로 리포트의 각 제안이 원본 이벤트를 인용할 수 있습니다. 리포트는 위에서 아래로 읽도록 설계돼 있습니다:

| 섹션 | 소스 이벤트 | 휴리스틱 |
|------|-------------|----------|
| Threshold Calibration | `qa_judge`, `axis_skip` | 점수 p50/p95 + verdict 분포, 축별 skip 빈도. 관측수 하한(`--threshold-n`, 기본 3) 미만이면 "insufficient signal" 로 명시해 섣부른 튜닝을 막습니다. |
| Protocol Improvements | `note`(pain/ambiguous), `axis_skip.reason` | note 를 text 내 첫 `/crucible:*` 토큰 기준 그룹핑(미매치는 `general`) + 반복 skip 사유 `n ≥ 2`. 상위 5건만. |
| Promotion Candidates | `note`(request/good), `promotion_gate.response=="y"` | Protocol 와 같은 그룹핑 + promotion gate 가 `n ≥ 2`회 승인된 패턴을 별도 bullet 로 제안 (`/compound` 로 보낼 강한 신호). |

빈 섹션은 반드시 `> no signal in window` 로 표기해 "신호 없음"과 "섹션 누락"이 혼동되지 않게 합니다.

재귀 방지: `skill_call` 이벤트 중 `skill` 에 `crucible:dogfood-digest` 가 포함되면 렌더러 ingestion 단계에서 drop 합니다. 자기 호출이 다음 digest 리포트를 오염시키지 않습니다.

## 설계 선택 (Design Choices)

- **Read-only, auto-apply 아님.** `--apply`, in-place diff 패칭, 임계값 자동 수정은 모두 거부. 임계값·SKILL.md 는 세션 간 compound 되며, 잘못된 auto-edit 한 번이 살아남아 증폭됩니다. 제안-전용 경계는 `/compound` 의 promotion 게이트와 같은 원칙 — 시스템은 제안만 하고 승격은 사람만.
- **1 Markdown, 서브커맨드 분리 없음.** `--target threshold|protocol|promotion` 으로 쪼개면 표면적만 3배가 됩니다. 3섹션은 한 페이지에 담기며, 읽는 사람은 한 번에 섹션들을 cross-reference 하길 원합니다(예: pain 노트와 qa_judge retry 군집 대조).
- **3섹션 고정 순서, 항상 렌더.** 빈 섹션에도 헤더를 찍는 이유: ① "이 window 에 Threshold 신호 없음"과 "스킬이 Threshold 를 잊음"은 다른 주장, ② 리포트를 window 간 diff 하려면 뼈대가 흔들리면 안 됨.
- **유저 지정 window, cursor auto-advance 아님.** cursor 는 원본 JSONL 에 필드를 추가해 append-only 를 훼손합니다. 대신 `--last/--since/--all` 플래그로 사용자가 명시 → idempotent 재실행 안전 + 파일명에 window 인코딩(`-last10`, `-since-2026-04-15`, `-all`) → 충돌 없음.
- **`_source_path` + `_line` 메모리 주입.** back-reference 는 타협 불가 — 근거 없는 제안은 민담입니다. 집계 단계에서 jq 한 줄로 주입되고 원본 파일은 mutate 하지 않습니다.
- **관측수 하한(`--threshold-n 3`).** 샘플 2개로 qa-judge 밴드를 튜닝하는 것은 튜닝하지 않는 것보다 나쁩니다 — 노이즈를 공식화하니까요. 주간 실행에서 실제 신호를 surfacing 할 만큼 낮고 n=1 우연을 억제할 만큼 높습니다. 조용한 로그를 위해 override 가능하도록 플래그로 노출.
- **`/crucible:*` 그룹 토큰 + `general` 버킷.** 더 풍부한 NLP 그룹핑은 drift 합니다 — 토픽 벡터는 불만이 어느 스킬의 것인지 알려주지 않습니다. 슬래시 커맨드 토큰은 여전히 *이름이 붙은 스킬의 SKILL.md*라는 actionable 지점과 1:1 매핑되는 가장 거친 키입니다. 나머지는 `general` 로 흘러 silently drop 되지 않습니다.

## 임계값 (Thresholds)

`/dogfood-digest`는 새 임계값을 도입하지 않습니다. 기존 문서의 임계값을 **소비하는 쪽**입니다:

- `qa_judge` verdict 밴드 — [`../thresholds.ko.md §1`](../thresholds.ko.md#1-qa-judge-verdict-bands--promote--080-retry-040080-reject--040) 기준 p50/p95 요약.
- `promotion_gate` y-response 빈도 — [`../thresholds.ko.md §5`](../thresholds.ko.md#5-승격-게이트-오탐률--20-) 의 false-positive 예산과 비교.
- `axis_skip` 정책 — [`../axes.ko.md`](../axes.ko.md) 과 cross-reference.
- 관측수 하한(`--threshold-n`, 기본 3) — 본 스킬의 로컬 knob.

## 참조 (References)

- 형제 스킬 [`/dogfood`](./dogfood.ko.md) — digest 가 소비하는 이벤트 소스.
- 연계 스킬 [`/compound`](./compound.ko.md) — Promotion Candidate 가 실제로 영구 메모리로 승격되는 경로.
- [`../../skills/dogfood-digest/SKILL.md`](../../skills/dogfood-digest/SKILL.md) — 스킬 계약 (`validate_prompt` 4축 자기검증).
- [`../../scripts/dogfood-digest.sh`](../../scripts/dogfood-digest.sh) — 집계기 (플래그 파싱, jq 필터, back-reference 주입).
- [`../../scripts/dogfood-digest-render.sh`](../../scripts/dogfood-digest-render.sh) — 3섹션 Markdown 렌더러.
- [`../../__tests__/integration/test-dogfood-digest.sh`](../../__tests__/integration/test-dogfood-digest.sh) — SC-1~7 통합 테스트.

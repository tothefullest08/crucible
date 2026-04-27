# `/dogfood-digest` *(v1.3.0)*

> 누적된 `/crucible:dogfood` JSONL 을 read-only Markdown 제안 리포트 1건으로 정리 — 고정 3섹션(Threshold Calibration · Protocol Improvements · Promotion Candidates) + 인용된 모든 이벤트의 원본 위치 back-reference.

[English](./dogfood-digest.md) · 한국어

## 패러다임 (Paradigm)

`/dogfood-digest`는 `/dogfood`의 짝입니다. `/dogfood`가 다른 스킬에 대한 근거를 수집하는 유일한 스킬이라면, `/dogfood-digest`는 그 근거를 **읽고 개선안을 제안하는** 유일한 스킬입니다. 이 스킬이 방어하는 실패 모드는 "근거가 JSONL 에 쌓여도 아무도 다시 읽지 않는" 경우이고, 결코 진입하지 않는 모드는 "자동 변경 적용"입니다. 임계값과 SKILL.md 본문은 세션 간 load-bearing 이어서 단 한 번의 노이즈 기반 auto-edit 도 다음 모든 세션을 오염시킵니다. 그래서 digest 는 의도적으로 **제안 전용** — 정확히 한 파일(`.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md`)만 쓰고, 제안 수용 여부는 사람이 `/plan` 혹은 수동 편집 경로로 처리합니다. 집계기(`scripts/dogfood-digest.sh`, 플래그 파싱 + jq 필터)와 렌더러(`scripts/dogfood-digest-render.sh`, 3섹션 Markdown) 분리는 "어떤 이벤트를 포함할지"와 "어떻게 보여줄지"를 서로 독립적으로 튜닝 가능하게 합니다.

## 판정 (Judgment)

입력: 로컬 `.claude/dogfood/log.jsonl` 과 글로벌 mirror `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` 의 조합. `--last N`(기본 10) / `--since DATE|Nd` / `--all` 중 하나로 window, `--scope local|global|both`(기본 both) 로 scope 를 선택합니다. 출력: `.claude/plans/` 안의 Markdown 1건 — 그 외 추적 파일은 절대 건드리지 않습니다.

출력 형식은 `--format markdown|json`(기본 markdown) 로 선택. `json` 분기는 `schema_version: "1"`(JSON 문자열 — `.schema_version == "1"` 로 비교) 이 박힌 단일 객체를 stdout 으로 emit, 같은 3섹션 구조를 유지해 에이전트 호출자가 Markdown 정규식 대신 jq 로 파싱합니다. 각 item 은 `type` 디스크리미네이터를 들고 있어 wrapper 가 위치 인덱스 대신 type 으로 분기합니다. 디스크리미네이터: `qa_distribution`, `axis_skip_freq`, `pain_group`, `skip_reason`, `promo_group`, `promotion_gate`.

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

## 표준에러 & 종료 코드 (Stderr & Exit Codes) *(v1.3.0 추가, issues #16/#17/#18)*

파이프라인의 두 절반 (`scripts/dogfood-digest.sh` 집계기, `scripts/dogfood-digest-render.sh` 렌더러) 모두 stderr 를 프로그램 호출자를 위한 구조화된 채널로 다룹니다. 세 가지 보장:

**Severity prefix.** 스크립트 자체의 `err`/`warn`/`info` 헬퍼를 통해 방출되는 모든 stderr 라인은 `<script>: <severity>: <msg>` 형태이며 severity ∈ `{info, warn, error}`. 집계기는 `dogfood-digest:`, 렌더러는 `render:` 접두사. 통합 grep:

```bash
grep -E '^(dogfood-digest|render): (info|warn|error):'
```

복구 힌트는 `error:` 라인 뒤에 별도 `info: hint:` 라인으로 따라올 수 있습니다 (예: `--since` UTC 보정 힌트). `error:` 만 grep 하는 에이전트는 결함만 보고 권고는 놓치므로, 권고는 `info: hint:` 로 grep.

**3-way 종료 코드 분리** (이전의 arg-vs-success 2-way 대체):

| 코드 | 의미 | 호출자 액션 |
|---|---|---|
| 0 | 성공 (빈 입력 / no-signal 포함) | — |
| 1 | 런타임 데이터-파이프라인 실패 (jq sort, mv swap, tail) | 데이터 형상 문제; 입력 점검 |
| 2 | 인자 오류 (unknown flag, mutex, 잘못된 값, 중복) | 플래그 수정 후 재시도 |
| 3 | 시스템 / 환경 실패 (디스크 가득, 도구 누락 시 mktemp) | 에스컬레이트, 동일 인자로 **재시도 금지** |

`mktemp` 실패만 2 → 3 으로 이동. 다른 모든 인자 검증 사이트는 exit 2 유지.

**Per-source warn rate-limit.** 수천 건의 malformed row 가 든 병적 JSONL 로그는 row 마다 `warn:` 한 줄을 방출해 에이전트 컨텍스트 예산을 폭파시키고 stderr 를 무시하도록 학습시켰습니다. 이제 source 당 verbatim `warn:` 5 줄로 cap; 그 이상은 단일 요약 라인으로 폴딩:

```
dogfood-digest: warn: N more malformed rows skipped in <path> (cap=5)
```

cap 값은 동적으로 보간(`(cap=5)`)되어 라인을 읽는 에이전트가 `--help` 없이도 cap 을 복원할 수 있습니다. Counter 는 source 마다 리셋되어 한 파일이 다른 파일의 warn 예산을 가리지 않습니다.

**`CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=1`.** 매 호출마다 `CRUCIBLE_DOGFOOD_ROOT` / `CRUCIBLE_DOGFOOD_HOME` 을 정상적으로 설정하는 CI 워크플로는 침묵을 opt-in 해서 env-override `info:` 라인이 stderr 를 흐리지 않도록 할 수 있습니다. **엄격한 리터럴 `"1"`** — `true`, `yes`, ` 1`(앞쪽 공백) 등 다른 값은 활성화되지 **않습니다**. **오직 `info:` env-override 라인만 억제**; `warn:` 와 `error:` 는 항상 방출됩니다 (opt-in 은 선택적 노이즈 감소이지 결함 마스킹이 아닙니다).

**호환성 주의사항.** stderr 를 정확한 라인 일치로 파싱하거나 exit 2 를 "모든 실패"로 분기하던 wrapper 는 업데이트가 필요합니다. 부분 문자열 매칭(파일 경로, 오류 키워드)이나 exit-0 vs non-zero 매처는 영향 없음.

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

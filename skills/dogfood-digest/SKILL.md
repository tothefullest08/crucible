---
name: dogfood-digest
description: |
  dogfood 로그 요약·제안 (한·영) / Manual dogfood-log digest — read-only aggregator that distills crucible dogfood JSONL (local + global mirror) into a 3-section Markdown proposal report covering threshold calibration, skill-protocol improvements, and /compound promotion candidates.
  Use whenever you want to turn accumulated /crucible:dogfood events into a human-reviewable proposal, not to mutate any skill, memory, plugin.json, or threshold directly. Run it manually — there is no auto trigger.
  트리거: "dogfood digest", "도그푸드 다이제스트", "도그푸드 리포트", "dogfood report", "/crucible:dogfood-digest", "로그 집계 제안", "dogfood summary", "피드백 요약".
when_to_use: "dogfood JSONL이 여러 건 누적된 뒤, 임계값·스킬 프로토콜·승격 후보 개선 아이디어를 사람이 읽고 판단할 수 있는 제안 리포트로 뽑아내고 싶을 때. 수동 호출 전용 — Stop hook / cron 자동 실행 없음."
input: |
  플래그는 두 스크립트로 나뉘며, 잘못된 쪽에 패스하면 unknown-argument
  로 exit 2 한다. `--scope` 만 양쪽이 공유한다.

  Aggregator (`scripts/dogfood-digest.sh`) — window · scope · 경로 resolve:
    --last N           최근 N 이벤트 (기본 10). 양의 정수, 최대 1_000_000.
                       범위 밖 / 비숫자는 exit 2.
    --since DATE|Nd    절대 날짜(YYYY-MM-DD / ISO8601) 또는 상대 기간(예: 7d).
    --all              전체 window. --last/--since 조합은 error(exit 2),
                       --all 이 함께 오면 overrides.
    --scope local|global|both   기본 both.
    --project-root DIR (CI/test only) PWD 대신 사용할 로컬 로그 루트.
    --home DIR         (CI/test only) $HOME 대신 사용할 글로벌 mirror 루트.
    env CRUCIBLE_DOGFOOD_ROOT  위 --project-root 보다 우선. 적용 시 stderr 에 info.
    env CRUCIBLE_DOGFOOD_HOME  위 --home 보다 우선. 적용 시 stderr 에 info.
    env CRUCIBLE_DOGFOOD_QUIET_OVERRIDE=1  env-override info 라인 억제 (issue
                       #18). CI 가 매 호출마다 위 두 env 를 set 하는 경우 stderr
                       노이즈를 제거하기 위한 옵트인. error/warn 은 영향 없음.
  같은 플래그를 두 번 패스하면 exit 2 — wrapper 가 사용자 인자를 자기
  default 와 단순 concat 할 때 마지막 값이 조용히 이기는 footgun을 차단한다
  (issue #9).

  Renderer (`scripts/dogfood-digest-render.sh`) — Markdown 변환 단계 knob.
  **`--threshold-n` 은 renderer 전용** — aggregator 에 전달하면 unknown
  argument 로 exit 2 한다. aggregator 와 마찬가지로 같은 플래그를 두 번
  패스하면 exit 2 (issue #9).
    --window LABEL     window 라벨(파일명 + frontmatter, 필수). 호출자가
                       aggregator 의 window 플래그에 맞춰 합성한다.
    --scope local|global|both   기본 both. aggregator 의 --scope 와 동일하게
                       검증되어 frontmatter 의 `scope:` 에 그대로 쓰인다.
    --threshold-n N    Threshold 섹션에서 qa_judge / axis_skip 관측수 하한
                       (기본 3). 양의 정수, 최대 1_000_000.
                       범위 밖 / 비숫자는 exit 2 (PR #24 ce-review P1 — same
                       arithmetic-overflow surface as aggregator's --last).
    --format markdown|json   기본 markdown. `json` 은 단일 구조화 객체를
                       stdout 으로 emit (issue #19) — 에이전트 호출자가 jq 로
                       파싱 가능. 알 수 없는 값(`jason` 등)은 exit 2.
                       스키마: `{schema_version, frontmatter, sections[]}`,
                       각 section 은 `{title, items[], note?}`. 각 item 은
                       `type` discriminator (qa_distribution · axis_skip_freq ·
                       pain_group · skip_reason · promo_group · promotion_gate)
                       를 들고 있어 wrapper 가 위치 인덱스 대신 type 으로
                       분기한다.

  입력 소스 (aggregator 가 resolve, renderer 는 stdin 만 읽음):
    로컬  `${CRUCIBLE_DOGFOOD_ROOT:-${PROJECT_ROOT}}/.claude/dogfood/log.jsonl`
    글로벌 `${CRUCIBLE_DOGFOOD_HOME:-$HOME}/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl`
output: |
  `.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md`
  {window} ∈ { last{N}, since-{YYYY-MM-DD|Nd}, all }
  프론트매터(generated_at · window · scope · total_events · source_counts) + Markdown 본문 3섹션
  (Threshold Calibration · Protocol Improvements · Promotion Candidates).

  Renderer `--format json` (issue #19): `.md` 대신 단일 JSON 객체를 stdout 으로
  emit. 에이전트 호출자는 jq 로 파싱한다. 호출자가 redirect 하는 경로의
  관례는 `.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.json` 이지만
  스크립트는 파일을 직접 쓰지 않는다 (Phase 4 와 동일).

  Stderr (issue #16): 모든 라인이 `<script>: <severity>: <msg>` 형식.
    severity ∈ {info, warn, error}. 에이전트가 자유 텍스트 파싱 없이
    severity 키워드만으로 분류 가능. 파일별 malformed-row warn 은 5건까지
    verbatim emit 후 1줄 summary 로 fold (issue #17).

  Exit codes (aggregator + renderer 공통, 3-way 분리 — issue #16):
    0  성공 (zero-source / zero-signal 포함)
    1  런타임 데이터 파이프라인 실패 (jq/mv/tail) — 입력 데이터 invariant 위반
    2  인자 오류 (unknown flag, duplicate flag, mutex 위반, 잘못된 값,
                  --last 범위 위반) — recoverable, 인자 고쳐 재시도
    3  시스템/환경 실패 (mktemp full disk, missing tools) — escalate, 동일
                  인자 재시도 금지
validate_prompt: |
  /crucible:dogfood-digest 완료 시 자기검증 (Dogfood-Digest 4축):
  1. 산출 파일 경로가 `.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md` 규약을 만족하고 slug `[a-zA-Z0-9_-]` 화이트리스트 내인가?
  2. Read-only 불변식 — 스킬 실행 전/후 `git status --short` 차이가 오직 방금 생성한 리포트 1줄(`.claude/plans/…`) 만인가? `.claude/memory/·skills/*/SKILL.md·.claude-plugin/plugin.json` 변경 0?
  3. 본문에 3섹션(Threshold Calibration · Protocol Improvements · Promotion Candidates) 전부 존재하며, 각 제안 항목은 근거 이벤트의 `\`path:line\``형식 back-reference 최소 1건을 인용하는가? 빈 섹션은 명시적으로 `> no signal in window` 문구로 대체되는가?
  4. 재귀 방지 — 리포트 본문에 `skill_call` 타입 중 `skill == "/crucible:dogfood-digest"` 이벤트가 Protocol/Promotion 섹션 근거로 채택되지 않았는가? (렌더 단계에서 drop 하는지 확인)
---

# Dogfood Digest — /crucible:dogfood-digest

> crucible `dogfood` JSONL을 window 플래그로 집계해 **제안 리포트 1건**만 `.claude/plans/` 에 남기는 read-only 스킬. 임계값·SKILL.md·메모리·plugin.json 은 손대지 않는다. 실행 판단은 전적으로 사용자 몫.

> 6-axis activation: this skill emits **hint-level** signals on axis 1 (Structure — 산출물 경로 규약) and axis 2 (Context — 읽기 소스 나열). **HARD-GATE 없음** — 제안 생성 전용이므로 `/plan` · `/verify` 처럼 축 통과를 강제하지 않는다. `using-harness/SKILL.md` §5 의 힌트 수준 분류.

---

## When to Use

- 유저가 `/crucible:dogfood-digest`, "dogfood digest", "도그푸드 리포트", "로그 집계 제안" 등으로 명시 호출할 때.
- `/crucible:dogfood` 로그가 일정 수준 누적된 뒤, 관찰된 이벤트를 바탕으로 **임계값 재조정 · 스킬 프로토콜 개선 · /compound 승격 후보**를 사람이 판단 가능한 제안으로 뽑고 싶을 때.
- 한 세션 내 여러 번 호출 가능 — window 플래그를 바꿔 재실행하면 파일명의 `{window}` 구간이 달라져 기존 리포트를 덮지 않는다.

Do **not** use when:
- 유저가 명시 호출하지 않았을 때. 자동 트리거 없음 (Stop hook / cron 부재는 의도적 설계).
- 리포트에서 제안된 변경사항을 자동 적용하고 싶을 때 — 본 스킬은 **읽기 + 리포트 1건 쓰기** 외 어떤 파일도 수정하지 않는다 (강 알레르겐).
- crucible 외부 로그를 집계하고 싶을 때. 입력 소스는 crucible `dogfood` JSONL 에 한정.

---

## Why it is read-only

파일 변경을 제안으로만 남기는 이유는 *신뢰*다. 임계값과 SKILL.md 본문은 세션 간 영향력이 크고, 자동 적용 시 한 번의 노이즈가 다음 세션 전체를 오염시킨다. 리포트는 **사람이 읽고 재-/plan 또는 수동 편집 경로로 들어가는 큐**로 동작하고, 스킬 자신은 `.claude/plans/` 한 곳에만 쓴다. 이 경계는 프로젝트 가드레일(`.claude/rules/project-guardrails.md` §4 · §7)과 `/compound` 의 promotion 게이트(§2)와 같은 원칙을 따른다.

---

## Protocol

각 Phase는 **목표 / 입력 / 동작 / 출력 / 실패 시 fallback** 5 섹션 고정.

### Phase 1 — Intake (flag parsing)

**목표**: 사용자 플래그와 기본값을 확정하고 window/scope 레이블을 만든다.

**입력**: 슬래시 커맨드 인자.

**동작**:
1. 플래그 파싱: `--last N` / `--since DATE|Nd` / `--all` / `--scope local|global|both`.
2. 기본값: `--last 10` · `--scope both`.
3. `--last` 와 `--since` 동시 지정 시 오류 반환 (mutually exclusive). `--all` 는 둘 다 override.
4. 파일명 window 토큰 산출:
   - `--last N` → `last{N}`
   - `--since 2026-04-15` → `since-2026-04-15`
   - `--since 7d` → `since-7d`
   - `--all` → `all`

**출력**: 메모리 상 `{ window_label, scope, cli_args }`.

**실패 시 fallback**: 알 수 없는 플래그는 `scripts/dogfood-digest.sh --help` 안내 후 exit 2.

---

### Phase 2 — Aggregate (read sources)

**목표**: 로컬 + 글로벌 mirror JSONL 을 window 에 맞춰 필터하고, 각 이벤트에 back-reference (`_source_path`, `_line`) 를 주입한 스트림을 만든다.

**입력**: Phase 1 `{window, scope}`.

**동작**:
1. `bash scripts/dogfood-digest.sh <flags>` 를 호출한다.
2. 집계기는 `scope` 에 따라 다음 소스들을 읽는다 (모두 append-only, 원본 mutate 금지):
   - local: `${PROJECT_ROOT}/.claude/dogfood/log.jsonl`
   - global: `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` (여러 프로젝트 가능)
3. 각 라인을 `jq input_line_number` 로 보강해 `{_source_path, _line}` 를 주입한다.
4. `ts` 기준 오름차순 정렬 후 window 필터 적용:
   - `--since` → `ts >= cutoff` select
   - `--last` → tail N
   - `--all` → no-op
5. 결과를 pipe (stdout JSONL) 로 Phase 3 에 전달.

**출력**: filtered JSONL stream on stdout.

**실패 시 fallback**: 소스 0개 → 빈 stream (exit 0). 파싱 실패 이벤트는 조용히 skip (schema drift 대비).

---

### Phase 3 — Render (3 sections + back-references)

**목표**: filtered stream 을 3섹션 Markdown 으로 변환한다. 빈 섹션은 명시적 `no signal` 문구로 대체해 "섹션 누락"으로 오해되지 않게 한다.

**입력**: Phase 2 stream + `{window, scope}`.

**동작**:
1. renderer (`bash scripts/dogfood-digest-render.sh --window {window} --scope {scope}`) 가 Phase 2 의 filtered JSONL 을 **stdin** 으로 읽어 변환한다. 호출형(직결 파이프 vs wrapper-via-tempfile) 은 Phase 3 의 책임이 아니라 Phase 4 가 정의한다 — 둘 다 renderer 입장에서는 동일한 stdin 입력이다.
2. 재귀 필터: 입력 중 `.type == "skill_call" && .skill == "/crucible:dogfood-digest"` (앵커 regex `^/?crucible:dogfood-digest$`, 대소문자 무시) 는 ingestion 단계에서 drop. 자기 호출이 Protocol/Promotion 섹션을 오염시키지 않도록 한다. 앵커가 있어 `crucible:dogfood-digest-v2` 같은 미래 형제 스킬 호출은 보존된다. `.skill` 이 string 이 아닌 malformed 행은 self-call 로 단정할 수 없으므로 통과 처리(schema-drift tolerance).
3. 섹션별 휴리스틱 — 관측수 하한은 `--threshold-n N`(기본 3, 양의 정수) 로 조정 가능:
   - **Threshold Calibration**: `qa_judge` 중 `.score` 가 `[0,1]` 범위의 number 인 행만 카운트한다 (n=numeric-and-in-range). n≥threshold-n 이면 p50/p95 + verdict 분포. 문자열·중첩 객체·범위 밖 score 는 통계 오염 방지를 위해 ingestion 단계에서 drop 되며 `total_events` 에는 남고 `qa_judge n` 에서는 빠진다 (issue #12 + 추가 hardening). `axis_skip` n≥threshold-n 이면 축별 histogram. 둘 다 관측수 미만이면 `no signal in window (qa_judge n=X, axis_skip n=Y, threshold-n=N)`.
   - **Protocol Improvements**: `note` 중 category ∈ {pain, ambiguous} 를 text 내 첫 `/crucible:*` 토큰 기준 그룹핑 (미매치는 `general`) + `axis_skip.reason` 동일 키 ≥ 2. 상위 5건만.
   - **Promotion Candidates**: `note` 중 category ∈ {request, good} 을 같은 방식으로 그룹핑 + `promotion_gate.response == "y"` 빈도 ≥ 2.
4. 각 제안 라인은 `- **{key}** ({cats}, n={count}) — {sample}\n  - 근거: \`{path}:{line}\` …` 형식. 최소 1건의 back-reference 를 반드시 포함.
5. 프론트매터에 `generated_at · window · scope · total_events · source_counts · date` 기재.

**출력**: Markdown 문자열 (stdout).

**실패 시 fallback**: 섹션 휴리스틱이 모든 관측수 하한 미만 → 빈 섹션 대신 명시적 안내. jq 파이프 실패 → stderr 경고 후 섹션을 `> no signal in window` 로 채워 리포트 완결.

---

### Phase 4 — Save (single-file write)

**목표**: Phase 3 Markdown 을 `.claude/plans/{date}-dogfood-digest-{window}.md` 경로로 **단 1건**만 저장. 스킬 자체는 쉘 스크립트 2개 (aggregator · renderer) 로만 구성돼 있고 이들은 stdout 으로 출력만 한다. **파일로 남기는 주체는 호출자(에이전트) 이다** — 호출자가 redirect (`> path`) 또는 Write 도구로 최종 파일을 남긴다.

**입력**: Phase 3 Markdown (stdout) + Phase 1 `{window}`.

**호출자(에이전트) 책임**:
1. `date = $(date -u +%Y-%m-%d)` 계산.
2. 파일 경로 조립: `.claude/plans/${date}-dogfood-digest-${window_label}.md`. slug `dogfood-digest` 는 고정 문자열이라 별도 sanitize 불필요 — `{window_label}` 만 `[a-zA-Z0-9_-]` 화이트리스트 내에 있는지 확인.
3. `.claude/plans/` 디렉토리 부재 시 `mkdir -p`.
4. **이미 같은 경로의 파일이 있으면** 덮어쓰지 말고 `{window}-v2` / `{window}-v3` … 처럼 suffix 를 바꿔 재호출할 것. 재조회가 필요하면 Phase 1 부터 다시 돈다. (스크립트에 `--out` / `--force` flag 는 의도적으로 두지 않음 — 충돌 처리는 호출자 문맥에서 판단.)
5. **호출 패턴 (필수)** — aggregator → renderer 단계 분리 없이 호출하면 aggregator 가 `jq sort` / `mktemp` 등으로 실패해도 renderer 는 EOF 까지 읽고 깨끗한 "no signal in window" 리포트를 exit 0 으로 뱉어 "성공처럼 보이는 잘못된 결과(success but wrong answer)" 실패를 만든다(issue #11). 두 가지 호출형 모두 **aggregator 실패가 호출자 exit code 로 surface 되도록** 보호장치를 따로 둬야 한다:
   - **wrapper-via-tempfile (권장)**: aggregator 출력을 `mktemp` 임시파일로 받고 renderer 에 stdin 으로 주입한다. **`set -e`** 또는 aggregator 호출 직후 `if ! ... ; then exit 1; fi` 명시 rc 체크가 **필수** — 둘 중 하나라도 없으면 aggregator 가 exit 2 로 죽어도 renderer 가 빈 입력으로 정상 리포트를 만들어 issue #11 회귀가 된다. 단계별 exit code 를 독립 검사할 수 있는 게 추가 이점.
   - **direct pipe**: `set -o pipefail` 을 호출 전에 켠다. aggregator 실패가 전체 exit code 로 전파된다(테스트는 ADV-007 참조). 단, 단계별 디버깅이 어렵다.
6. 저장 후 최종 응답 마지막 줄에 저장 경로 echo.

**출력**: 디스크 상의 리포트 파일 1건.

**실패 시 fallback**: 파일 쓰기 실패 → 에러 원문을 사용자에게 노출하고 중단. 부분 쓰기 잔해 제거. 스크립트 자체의 exit code 는 출력 섹션 참조 (0/1/2).

**예시 호출 (bash, wrapper-via-tempfile)**:
```bash
set -e   # aggregator 실패가 빈 리포트로 가려지지 않도록 (issue #11).
         # set -o pipefail 은 이 형태에서 파이프가 없어 무효 — set -e 가 핵심.

win=last10
date=$(date -u +%Y-%m-%d)
mkdir -p .claude/plans

# wrapper-via-tempfile: aggregator → tempfile → renderer.
# 각 단계 exit code 를 독립 검사 가능. 위 `set -e` 가 없으면 aggregator
# 가 exit 2 로 죽어도 다음 줄의 renderer 가 빈 입력으로 정상 리포트를
# 저장한다.
tmp_raw="$(mktemp -t dogfood-digest-raw.XXXXXX)"
trap 'rm -f "$tmp_raw"' EXIT INT TERM HUP

bash scripts/dogfood-digest.sh --last 10 --scope both > "$tmp_raw"
# --threshold-n 은 renderer 에만 — aggregator 에 패스하면 exit 2.
bash scripts/dogfood-digest-render.sh --window "$win" --scope both --threshold-n 5 \
    < "$tmp_raw" \
    > ".claude/plans/${date}-dogfood-digest-${win}.md"
```

**대체 호출 (direct pipe, ADV-007 검증 형태)**:
```bash
set -o pipefail   # 직결 파이프에서 aggregator 실패를 전체 exit code 로 전파.
# --threshold-n 은 파이프 오른쪽(renderer) 에만 둔다.
bash scripts/dogfood-digest.sh --last 10 --scope both \
    | bash scripts/dogfood-digest-render.sh --window last10 --scope both --threshold-n 5 \
    > ".claude/plans/${date}-dogfood-digest-last10.md"
```

---

## Integration Points

- **입력**: `/crucible:dogfood` 가 append 한 JSONL (`.claude/dogfood/log.jsonl` + opt-in 글로벌 mirror).
- **출력**: `.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md` (Markdown + YAML frontmatter).
- **재사용 대상 아님**: 본 리포트는 사람이 읽는 큐. 자동화된 downstream 스킬이 frontmatter 를 parse 해 변경을 적용하는 경로는 **제공하지 않는다** (신뢰 경계 유지).
- **다음 단계**: 제안 항목을 사용자가 수용하면 `/crucible:plan` 으로 실제 변경안을 계획하거나 `/crucible:compound` 로 승격 후보를 통과시킨다.

---

## Storage Layout

```
{PROJECT_ROOT}/
├── .claude/
│   ├── dogfood/
│   │   └── log.jsonl                 # read-only 입력 (dogfood 가 append)
│   └── plans/
│       └── 2026-04-22-dogfood-digest-last10.md   # 이 스킬의 유일한 산출물

~/.claude/dogfood/crucible/
├── {slug}-{hash}/
│   └── log.jsonl                     # opt-in 글로벌 mirror 입력
```

파일명 예시:
- `2026-04-22-dogfood-digest-last10.md` (기본값)
- `2026-04-22-dogfood-digest-since-2026-04-15.md`
- `2026-04-22-dogfood-digest-since-7d.md`
- `2026-04-22-dogfood-digest-all.md`

---

## Example

```bash
/crucible:dogfood-digest --since 7d --scope both
# → .claude/plans/2026-04-22-dogfood-digest-since-7d.md 생성
```

리포트 본문 발췌 (pain note 5건·request 2건 관측):
```markdown
## Threshold Calibration
> no signal in window (qa_judge n=2, axis_skip n=0, threshold-n=3)

## Protocol Improvements
- **general** (pain, n=5) — 영어 추상어 혼동으로 재설명 루프 2회 …
  - 근거: `~/.claude/dogfood/crucible/windly-10fbfe8c/log.jsonl:1` …

## Promotion Candidates
- **general** (request, n=2) — 한국어 풀어쓰기 기본화 — bilingual UX 확장
  - 근거: `~/.claude/dogfood/crucible/windly-10fbfe8c/log.jsonl:5` …
```

---

## Limitations

- **자동 실행 없음** — Stop hook / cron / 세션 자동 진입 경로 없음. 수동 호출만.
- **파일 변경 금지 (strong allergen)** — 스킬 본체는 읽기 + 리포트 1건 쓰기만. 임계값·SKILL.md·plugin.json·`.claude/memory/` 수정은 사용자 intent 를 거친 별도 경로를 따라야 한다.
- **append-only 존중** — dogfood JSONL 원본에 cursor 필드 추가·라인 재배열 같은 mutate 금지. back-reference 는 메모리 상 주입(`_source_path`, `_line`)에 한정.
- **섹션 추출 휴리스틱은 MVP** — grouping 키가 `/crucible:*` 토큰 + `general` 버킷에 한정. 더 정교한 NLP 추출은 향후 버전 범위 밖.
- **관측수 하한(threshold-n, 기본 3)** — 샘플이 적으면 "insufficient signal" 을 감수하고 보수적으로 제안을 미룬다. 잘못된 일반화보다 침묵이 안전하다.
- **성능 경계** — `--all --scope both` 에서 글로벌 미러 로그가 기가바이트급이면 jq 스트리밍 비용이 커진다. 구체적 벤치는 본 버전 범위 밖.

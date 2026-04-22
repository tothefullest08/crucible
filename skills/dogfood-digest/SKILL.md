---
name: dogfood-digest
description: |
  dogfood 로그 요약·제안 (한·영) / Manual dogfood-log digest — read-only aggregator that distills crucible dogfood JSONL (local + global mirror) into a 3-section Markdown proposal report covering threshold calibration, skill-protocol improvements, and /compound promotion candidates.
  Use whenever you want to turn accumulated /crucible:dogfood events into a human-reviewable proposal, not to mutate any skill, memory, plugin.json, or threshold directly. Run it manually — there is no auto trigger.
  트리거: "dogfood digest", "도그푸드 다이제스트", "도그푸드 리포트", "dogfood report", "/crucible:dogfood-digest", "로그 집계 제안", "dogfood summary", "피드백 요약".
when_to_use: "dogfood JSONL이 여러 건 누적된 뒤, 임계값·스킬 프로토콜·승격 후보 개선 아이디어를 사람이 읽고 판단할 수 있는 제안 리포트로 뽑아내고 싶을 때. 수동 호출 전용 — Stop hook / cron 자동 실행 없음."
input: |
  인자 플래그:
    --last N           최근 N 이벤트 (기본 10)
    --since DATE|Nd    절대 날짜(YYYY-MM-DD / ISO8601) 또는 상대 기간(예: 7d)
    --all              전체 window
    --scope local|global|both   기본 both
  입력 소스:
    로컬  `.claude/dogfood/log.jsonl`
    글로벌 `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl`
output: |
  `.claude/plans/YYYY-MM-DD-dogfood-digest-{window}.md`
  {window} ∈ { last{N}, since-{YYYY-MM-DD|Nd}, all }
  프론트매터(generated_at · window · scope · total_events · source_counts) + Markdown 본문 3섹션
  (Threshold Calibration · Protocol Improvements · Promotion Candidates).
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
1. `bash scripts/dogfood-digest-render.sh --window {window} --scope {scope}` 에 stdin pipe.
2. 재귀 필터: 입력 중 `.type == "skill_call" && .skill ~= "crucible:dogfood-digest"` 는 ingestion 단계에서 drop. 자기 호출이 Protocol/Promotion 섹션을 오염시키지 않도록 한다.
3. 섹션별 휴리스틱:
   - **Threshold Calibration**: `qa_judge` n≥3 이면 p50/p95 + verdict 분포, `axis_skip` n≥3 이면 축별 histogram. 둘 다 관측수 미만이면 `no signal in window (qa_judge n=X, axis_skip n=Y, threshold-n=3)`.
   - **Protocol Improvements**: `note` 중 category ∈ {pain, ambiguous} 를 text 내 첫 `/crucible:*` 토큰 기준 그룹핑 (미매치는 `general`) + `axis_skip.reason` 동일 키 ≥ 2. 상위 5건만.
   - **Promotion Candidates**: `note` 중 category ∈ {request, good} 을 같은 방식으로 그룹핑 + `promotion_gate.response == "y"` 빈도 ≥ 2.
4. 각 제안 라인은 `- **{key}** ({cats}, n={count}) — {sample}\n  - 근거: \`{path}:{line}\` …` 형식. 최소 1건의 back-reference 를 반드시 포함.
5. 프론트매터에 `generated_at · window · scope · total_events · source_counts · date` 기재.

**출력**: Markdown 문자열 (stdout).

**실패 시 fallback**: 섹션 휴리스틱이 모든 관측수 하한 미만 → 빈 섹션 대신 명시적 안내. jq 파이프 실패 → stderr 경고 후 섹션을 `> no signal in window` 로 채워 리포트 완결.

---

### Phase 4 — Save (single-file write)

**목표**: `.claude/plans/{date}-dogfood-digest-{window}.md` 경로로 **단 1건**만 쓰고 종료한다.

**입력**: Phase 3 Markdown + Phase 1 `{window}`.

**동작**:
1. `date = $(date -u +%Y-%m-%d)`.
2. 파일명: `.claude/plans/${date}-dogfood-digest-${window_label}.md`.
3. slug `dogfood-digest` 는 `[a-zA-Z0-9_-]` 준수 — 별도 hook 불필요 (고정 문자열).
4. 이미 파일이 존재하면 사용자에게 (overwrite / `-v2` suffix / abort) 3지선다 제시 후 대기.
5. `.claude/plans/` 디렉토리 부재 시 `mkdir -p`.
6. 저장 후 절대 경로를 최종 응답 마지막 줄에 echo.

**출력**: 디스크 상의 리포트 파일 1건.

**실패 시 fallback**: 파일 쓰기 실패 → 에러 원문을 사용자에게 노출하고 중단. 부분 쓰기 잔해 제거.

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

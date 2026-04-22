---
name: dogfood
description: |
  dogfooding 로그 수집 (한·영) / Manual dogfooding logger — captures qualitative notes (4 categories) plus auto-extracted structured events from the current Claude Code session and appends to local + optional global-mirror JSONL.
  Use when the user wants to record feedback about a crucible session (pain points, good moments, ambiguities, feature requests) as durable dogfooding data for threshold tuning and UX iteration.
  트리거: "dogfood", "도그푸드", "로그 남겨", "/crucible:log", "feedback log", "세션 피드백", "dogfooding".
when_to_use: "crucible 플러그인 사용 중 세션 피드백을 append-only JSONL 로 남기고 싶을 때. 자동 캡처 없음 — 사용자가 명시적으로 호출한다."
input: "없음 (현재 세션 JSONL 자동 탐색) + AskUserQuestion 으로 4 카테고리 multiSelect + free-form 텍스트"
output: "{PROJECT}/.claude/dogfood/log.jsonl (로컬 primary) · ~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl (opt-in 글로벌 mirror)"
validate_prompt: |
  /crucible:log 완료 시 자기검증 (Dogfood 4축):
  1. 현재 세션 JSONL 에서 4 structured event (skill_call · promotion_gate · axis_skip · qa_judge) 추출을 시도했는가?
  2. Qualitative note 입력 시 최소 1개 이상 카테고리가 선택되었는가? (AskUserQuestion multiSelect)
  3. 로컬 `.claude/dogfood/log.jsonl` 에 append 되었고 line-by-line `jq .` 로 파싱되는가?
  4. `CRUCIBLE_DOGFOOD_GLOBAL` 이 "0" 이 아닐 때 글로벌 mirror `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` 에도 동일 내용이 append 되었는가?
  5. `.gitignore` 에 `.claude/dogfood/` 라인이 존재하는가? (없으면 1회만 추가)
  6. 재귀 방지 — /crucible:log 자신의 skill_call 이벤트가 structured events 배열에 포함되지 않는가?
---

# Dogfood — /crucible:log

> crucible 세션 피드백 수동 수집 스킬. qualitative(4 카테고리 + free-form) + structured(4 자동 이벤트) → append-only JSONL.

> 6-axis activation: this skill emits **hint-level** signals on axis 2 (Context) and axis 6 (Compound). It does NOT emit hard gates. See `using-harness/SKILL.md` §5.

---

## When to Use

- 유저가 `/crucible:log`, "dogfood", "로그 남겨", "세션 피드백" 등으로 명시 호출할 때.
- 한 세션 내 여러 번 호출 가능 — 매 호출이 개별 로그 레코드 묶음으로 append 된다.
- 자동 Stop hook 캡처는 **의도적으로 배제** (유저 큐레이션 철학).

Do **not** use when:
- 유저가 명시적으로 호출하지 않았을 때 (자동 저장 금지).
- crucible 외부 스킬 전용 피드백 — 본 스킬은 crucible dogfooding 목적에 한정.

---

## Protocol

### Phase 1 — Intake

1. **현재 세션 경로 탐색**: `scripts/parse-current-session.sh` 이 `~/.claude/projects/<encoded-cwd>/` 에서 mtime 최신 `*.jsonl` 을 선택한다. 실패 시 사용자에게 알림 후 structured events = 빈 배열로 진행.
2. **Qualitative 카테고리 질의**: `AskUserQuestion` (multiSelect) — `good` · `pain` · `ambiguous` · `request` 중 1개 이상.
3. **카테고리별 free-form 텍스트**: 선택된 카테고리마다 `AskUserQuestion` 1회씩 (간단 텍스트). 빈 문자열은 허용 (noop).

### Phase 2 — Collect

1. **Structured events 추출**: `bash scripts/parse-current-session.sh` 실행 → stdout JSONL. 4 event type(skill_call · promotion_gate · axis_skip · qa_judge) 이 regex/jq 기반으로 추출된다.
2. **재귀 필터**: `skill_call` 이벤트 중 `skill == "/crucible:log"` 인 라인은 parser 내부에서 drop. SKILL.md `validate_prompt` #6 이 사후 확인.
3. **Notes 조립**: Phase 1 입력을 `{"ts":"…","type":"note","category":"…","text":"…"}` JSONL 라인으로 변환.

### Phase 3 — Write

1. **writer 호출**: `bash scripts/dogfood-write.sh` 에 stdin JSONL(notes + structured events 합본)을 파이프.
2. **로컬 쓰기**: `flock` 으로 `.claude/dogfood/log.jsonl` 에 append (동시 호출 직렬화).
3. **글로벌 mirror** (opt-in):
   - `CRUCIBLE_DOGFOOD_GLOBAL=0` 이면 skip.
   - 그 외 경우 `~/.claude/dogfood/crucible/{slug}-{hash}/log.jsonl` 에도 동일 내용 append.
   - `{slug}-{hash}` 는 `scripts/project-slug-hash.sh` 출력 — slug=pwd basename 소문자, hash=abs-path SHA-256 앞 8자.
4. **gitignore 자동 등록**: `.gitignore` 에 `.claude/dogfood/` 라인이 없으면 1회 추가. 이미 있으면 noop.
5. **결과 요약**: stdout 에 `✓ Wrote N notes + M events to local / global` 출력.

---

## Opt-out

글로벌 mirror 가 싫으면 현재 세션에서:

```bash
export CRUCIBLE_DOGFOOD_GLOBAL=0
```

셋한 뒤 `/crucible:log` 를 호출하면 로컬 `.claude/dogfood/log.jsonl` 에만 기록된다. 기본값은 활성(1).

`~/.claude/dogfood/` 디렉터리 자체를 비활성화하려면 위 env var 를 쉘 rc 파일에 영구 export.

---

## Event Schemas

### Structured (auto-extracted)

```jsonl
{"ts":"2026-04-22T10:15:00Z","type":"skill_call","skill":"/crucible:plan","duration_ms":4521,"args_summary":"requirements.md","session_id":"<uuid>"}
{"ts":"2026-04-22T10:18:32Z","type":"promotion_gate","candidate_id":"dark-mode-toggle","response":"y","memory_path":".claude/memory/tacit/dark-mode.md","detector":"pattern_repeat"}
{"ts":"2026-04-22T10:22:10Z","type":"axis_skip","axis":5,"acknowledged":true,"reason":"긴급 프로토타입","session_id":"<uuid>"}
{"ts":"2026-04-22T10:28:45Z","type":"qa_judge","skill":"/verify","score":0.86,"verdict":"promote","dimensions":{}}
```

### Qualitative (AskUserQuestion 입력)

```jsonl
{"ts":"2026-04-22T10:30:00Z","type":"note","category":"good","text":"/plan evaluation_principles 자동 계산 편리"}
{"ts":"2026-04-22T10:30:00Z","type":"note","category":"pain","text":"..."}
```

| 카테고리 | 정의 |
|---------|------|
| `good` | 잘 동작한 것, 유지할 가치 |
| `pain` | 불편한 점, 개선 대상 |
| `ambiguous` | 모호해서 되물은 것 |
| `request` | 추가 feature 요청 |

---

## Storage Layout

```
{PROJECT_ROOT}/
├── .gitignore              # ".claude/dogfood/" 자동 등록
└── .claude/
    └── dogfood/
        └── log.jsonl       # append-only, 본 프로젝트 한정
```

글로벌 mirror (opt-in, 기본 활성):

```
~/.claude/dogfood/crucible/
├── harness-a3b4f1c2/
│   └── log.jsonl
└── my-app-f7e2d901/
    └── log.jsonl
```

---

## Integration Points

- **입력**: 현재 세션 JSONL (`~/.claude/projects/<encoded-cwd>/*.jsonl`) + AskUserQuestion 응답.
- **출력**: 로컬 `.claude/dogfood/log.jsonl` + 글로벌 mirror(opt-in).
- **재사용**: `scripts/lib/project-id.sh::project_id_for` (SHA-256 8자 해시), `scripts/extract-session.sh` (세션 경로 인코딩).
- **다음 단계**: 누적된 로그는 향후 `/crucible:dogfood-report` (v1.2+) 또는 수동 분석에 사용.

---

## Limitations (v1.1 MVP)

- **자동 캡처 없음** — Stop hook 배제. 유저 수동 호출만.
- **크로스 세션 리포트 없음** — append 만, 조회/요약은 별도 스킬 필요.
- **Remote 전송 없음** — `.gitignore` 차단이 본질 설계.
- **파싱 커버리지** — 4 event type 외 다른 이벤트(예: Bash 호출, Read/Write)는 structured events 에 포함되지 않음.

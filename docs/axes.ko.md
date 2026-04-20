# 6축 하네스 (6-Axis Harness)

> 왜 6축인지, 왜 이 매트릭스인지, 왜 `--skip-axis 5`는 `--acknowledge-risk`를 요구하는지.
> 이 문서는 **외부적으로 자족적(externally complete)** — `final-spec.md`를 열지 않고도 바로 행동할 수 있도록 작성됨.

[English](./axes.md) · 한국어

---

## 6가지 축

`crucible`은 모든 산출물(requirements, plans, verify 리포트, compound 후보)을 6축 루프에 강제로 통과시킵니다. 어떤 축이든 **조용히 건너뛰는 것**이야말로 하네스가 막으려는 실패 모드입니다.

| # | 축 | 강제 대상 | 방지하는 실패 |
|---|----|----------|--------------|
| 1 | **Structure** | 플러그인 레이아웃, `.claude-plugin/plugin.json` 무결성, 슬래시 커맨드 등록 | 로딩되지 않는 스킬, 잘못된 이름으로 로딩되는 스킬 |
| 2 | **Context** | `SessionStart` 훅, `using-harness.md`, `MEMORY.md` 주입 | 프로젝트 메모리 없이 새 세션이 시작되는 상황 |
| 3 | **Plan** | Markdown + YAML 하이브리드 산출물, acceptance criteria, 가중치 기반 `evaluation_principles` | 사람은 읽지만 `qa-judge`는 파싱 못 하는 플랜 |
| 4 | **Execute** | 범위 지정된 스킬, `validate_prompt` 훅, `plugin.json`의 SHA256 핀 payload | manifest가 광고한 것과 스킬 본문이 달라지는 상황 |
| 5 | **Verify** | `qa-judge` 채점, Ralph Loop 재시도, 3-stage Evaluator | 시간 압박 속에서 검증되지 않은 산출물을 릴리스하는 사고 |
| 6 | **Improve** | `/compound` 승격 게이트 → `tacit/` · `corrections/` · `preferences/` 메모리 | 승인되지 않은 학습이 자동 저장되어 발생하는 메모리 오염 |

### 각 축이 필수(non-optional)인 이유

- **Axis 1 — Structure.** Claude Code 플러그인은 manifest가 resolve될 때만 "실제로" 존재합니다. 레이아웃 drift(스킬 rename, `commands/` 항목 누락, 오래된 SHA256)는 사용자가 런타임에 부딪힐 때까지 보이지 않습니다. 세션 시작 시점에 Structure 게이트를 거는 것이 첫 프롬프트 이전에 이를 잡아내는 방법입니다.
- **Axis 2 — Context.** `MEMORY.md` 주입이 없으면 매 세션이 프로젝트를 제로부터 다시 배웁니다. 훅 + 인덱스 쌍은 `/clear`에도 살아남고 벤더 측 메모리에 의존하지 않는, 가장 저비용의 내구성 메커니즘입니다.
- **Axis 3 — Plan.** `/plan`은 Markdown(사람 리뷰)과 YAML frontmatter(`acceptance_criteria`, `evaluation_principles`, `exit_conditions`)를 한 파일에 동시에 emit합니다. 리뷰어와 Evaluator가 같은 단일 소스를 보게 하기 위함입니다. YAML을 빼면 검증은 재해석이 되어버립니다.
- **Axis 4 — Execute.** `plugin.json`의 SHA256 핀은 out-of-band로 편집된 스킬 파일을 감지하는 수단입니다. `validate_prompt`와 결합되면, 조용히 변형된 스킬이 기존 manifest 서명으로 실행되는 것을 차단합니다.
- **Axis 5 — Verify.** `qa-judge`는 Ralph Loop 재시도와 Charter Preflight 결정을 이끄는 수치 판정을 냅니다. **부재가 외부적으로 통과처럼 보이는** 유일한 축이고, 그래서 이 축의 스킵에만 추가 플래그 비용이 붙습니다.
- **Axis 6 — Improve.** 자동 메모리 플러그인들은 리뷰되지 않은 사실로 컨텍스트를 오염시킵니다. `/compound` 승격 게이트는 그 반대 기본값 — 사용자의 명시적 y/N/e/s 없이는 어떤 것도 `.claude/memory/`에 도달하지 못합니다.

---

## 스킬 × 축 매트릭스

`ON` = 하드 게이트 (축 체크를 통과하지 못한 산출물은 출고되지 않음).
`log-only` = 축이 감사용으로 *기록*되지만 블록하지는 않음.
`OFF` = 이 스킬 클래스에 해당 축이 적용되지 않음.

| 스킬 | 1 Structure | 2 Context | 3 Plan | 4 Execute | 5 Verify | 6 Improve |
|------|:-----------:|:---------:|:------:|:---------:|:--------:|:---------:|
| `/brainstorm`    | log-only | ON | OFF | OFF | OFF | log-only |
| `/plan`          | ON | ON | ON | ON | ON | OFF |
| `/verify`        | ON | ON | ON | ON | ON | OFF |
| `/compound`      | log-only | ON | OFF | ON | OFF | ON |
| `/orchestrate`   | ON | ON | ON | ON | ON | ON |

메모:

- `/brainstorm`은 Plan/Execute/Verify가 OFF입니다. 유일한 산출물이 *requirements* 문서이기 때문 — 아직 계획-검증하거나 실행할 대상이 없습니다. Context는 여전히 ON이라 세션에 MEMORY가 주입됩니다.
- `/compound`는 Plan/Verify가 OFF입니다. 승격은 계획/채점 작업이 아니라 결정 게이트이기 때문입니다. 메모리 쓰기는 훅으로 검증된 경로를 거쳐야 하므로 Execute는 ON으로 남습니다.
- `/orchestrate`는 6축이 전부 켜지는 유일한 스킬입니다. 설계상 다른 네 스킬을 체이닝하므로 모든 축이 최소 한 번은 참여합니다.

---

## `--skip-axis N` — 탈출구

`--skip-axis N` (반복 가능)은 단일 호출에 한해 하드 게이트를 `log-only`로 낮춥니다. 사용 시점:

- 출고 대상에 해당 축이 **정말 적용되지 않을 때** (예: 실험일 뿐 compound 후보가 아닌 경우 `--skip-axis 6`).
- 해당 축을 이미 out-of-band로 검증해 중복 pass를 원치 않을 때.

모든 스킵은 `.claude/memory/corrections/skip-log.md`에 기록됩니다. 이 로그는 로컬 전용이며 자동 승격되지 않습니다.

### Axis 5는 다릅니다: `--skip-axis 5`는 `--acknowledge-risk` 필수

Verify 스킵은 외부에서 봤을 때 pass와 동일하게 보이는 유일한 실수입니다. 하네스는 이것을 의도적으로 **2-key 동작**으로 만듭니다:

```
/plan --skip-axis 5                   # rejected
/plan --skip-axis 5 --acknowledge-risk  # accepted, logged as RISK-ACK
```

근거:

1. **아무도 Verify를 우발적으로 스킵하지 않는다.** 정말 그 의도라면 플래그 하나 추가는 저렴합니다. 그 의도가 아니라면 rejection이 올바른 결과입니다.
2. **릴리스 감사성.** skip 로그의 `RISK-ACK` 엔트리는 태그 이전에 `RELEASE-CHECKLIST.md` Hard AC 표가 리뷰하는 대상입니다. 그냥 `--skip-axis 5`였다면 일상 스킵 사이에 묻혀버립니다.
3. **기본값이 일반 케이스를 보호한다.** 95%의 경우 Verify는 *실행되어야* 합니다. 위험 경로를 안전 경로보다 비싸게 만드는 것이 전체 설계입니다.

`--skip-axis 5 --force`도, 환경변수 override도 없습니다. 이 플래그가 계약입니다.

---

## 용어

**하네스 6축**은 Claude Code를 모델 주위의 *wrapper*가 아닌 *harness*로 보는 원래 강의 프레이밍에서 왔습니다. 각 축은 하네스의 한 스트랩 — 한 개를 떼면 더 빠르고 덜 안전해지는 속도가 같은 비율로 증가합니다. 팀의 어휘에서 이미 load-bearing인 짧은 표현이라 커밋 메시지·릴리스 노트에서 한국어 표현을 유지합니다. 영어 독자는 **6-axis harness**와 **하네스 6축**을 상호 교환 가능한 표현으로 취급해도 됩니다.

---

## 관련 문서

- [`thresholds.ko.md`](./thresholds.ko.md) — 각 축이 강제하는 수치 (qa-judge 0.80/0.40, Ralph Loop cap, overlap 가중치).
- [`faq.ko.md`](./faq.ko.md) — 왜 `--skip-axis 5`가 게이트인지, 왜 합성 fixture 임계값은 출발점이지 종착점이 아닌지.
- [`skills/verify.ko.md`](./skills/verify.ko.md) — Axis 5가 실제로 어떻게 돌아가는지 (qa-judge + Ralph Loop + 3-stage Evaluator).

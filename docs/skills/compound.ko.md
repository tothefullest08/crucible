# `/compound`

> 사용자 승인된 학습을 6-step 게이트 · 3 트리거 · 5-차원 overlap 체크를 통해 내구성 있는 메모리로 승격합니다.

[English](./compound.md) · 한국어

## 패러다임 (Paradigm)

`/compound`가 방어하려고 설계된 실패 모드는 바로 **자동 메모리 쓰기**입니다. 이웃의 다른 모든 플러그인은 메모리를 먼저 쓰고 나중에 용서를 구합니다; `/compound`는 기본값을 뒤집습니다 — 사용자의 명시적 승인 없이는 어떤 것도 `.claude/memory/`에 도달하지 못합니다. 세 트리거는 *언제 물을지*, 5-차원 overlap은 *물을지 말지*, 6-step 게이트는 *사용자가 어떻게 답할지*를 결정합니다. 셋이 함께 메모리를 **수동 누적기**에서 **큐레이트된 산출물**로 전환시킵니다.

## 판정 (Judgment)

입력: 승격 후보 이벤트(세 트리거 중 하나). 출력: `.claude/memory/{tacit,corrections,preferences}/*.md`에 쓰인 0개·1개·여러 파일, 각각 사용자가 수용한 필드만 담김.

세 트리거:

1. **`pattern_repeat`** — 같은 correction이 세션 윈도우 내 `≥ 2`회 출현. `Stop` 훅에서 fire.
2. **`user_correction`** — 사용자가 이전 행동을 명시적으로 부정 ("no, stop doing X"). `PreToolUse` 훅에서 fire.
3. **`session_wrap`** — `/session-wrap` 또는 세션 종료; 모든 대기 후보를 단일 프롬프트로 batch.

후보에 대한 결정 흐름:

1. 기존 엔트리 대비 5-차원 overlap 계산. 어떤 엔트리와 `≥ 0.80`이면 중복 — skip.
2. Oscillation guard: 후보가 `Gen N-2`와 `≥ 0.80`으로 overlap하면 승격 루프 중단; ping-pong 감지.
3. 사용자에게 6-step 게이트 제시(아래). 모든 step에서 승인된 엔트리만 쓰임.

## 설계 선택 (Design Choices)

- **3 트리거, "모든 correction마다 쓰기" 아님.** 단일 트리거(correction만)는 패턴-수준 시그널을 놓치고, 단일 트리거(session-wrap만)는 hot-in-the-moment 컨텍스트를 놓칩니다. 3 트리거는 반복·진행 중·batch 케이스를 **겹침 없이 by construction**으로 커버합니다.
- **`Stop` 훅에서 batching.** 3번째 트리거(`session_wrap`)는 세션 중간에 매 후보마다 사용자를 방해하지 않게 하려 존재. 보류 중인 모든 후보가 한 번에 제시됩니다.
- **3회 연속 거부 후 자동 비활성화.** detector가 연속 3회 거부 후보를 내면 7일 동안 억제. 시끄러운 detector는 시끄러움의 비용을 지불.
- **6-step 승격 게이트.** 프롬프트는 사용자를 `summary → context → evidence → proposed entry → target path → final y/N/e/s`로 안내. 각 step은 편집(`e`) 또는 skip(`s`) 가능; 최종 step만 쓰기. 6개를 하나의 프롬프트에 묶어보니 FP rate가 더 높게 — 개별적으로라면 거부했을 bundled 엔트리를 사용자가 수용.
- **5-차원 overlap, 토큰 유사도 아님.** 토큰 코사인 유사도는 re-phrasing 간의 의미론적 중복을 놓칩니다. `problem · cause · solution · files · prevention`을 독립적으로 채점하는 것이 correction에서 중요한 축을 포착.
- **Oscillation guard는 `N-2` 뒤를 봄.** `N-1`은 너무 타이트(합법적 점진 개선이 false oscillation 유발), `N-3`은 너무 느슨(2-step ping-pong이 detector 아래로 순환). `N-2`가 `A → B → A` 케이스를 잡는 최소 윈도우.
- **Target 디렉토리 3개, 1개 아님.** `tacit/` vs `corrections/` vs `preferences/`는 조회를 scope된 상태로 유지 — 이후 `/brainstorm`은 preferences로 컨텍스트 오염 없이 corrections만 로드 가능.

## Thresholds

모든 수치 값은 [`../thresholds.ko.md`](../thresholds.ko.md)에 거주:

- 승격 게이트 오탐 ≤ `0.20` — [§5](../thresholds.ko.md#5-승격-게이트-오탐률--20-).
- 5-차원 overlap 가중치 `problem 0.30 · cause 0.20 · solution 0.20 · files 0.15 · prevention 0.15` (합 = 1.00) — [§7](../thresholds.ko.md#7-5-차원-overlap-가중치).
- Oscillation guard `overlap ≥ 0.80` within `Gen N-2` — [§8](../thresholds.ko.md#8-oscillation-guard--overlap--080-within-gen-n-2).
- 자동 비활성화 케이던스 (3 거부 / 7일) — 설계 관례, 이 파일에서 추적.

## 참고

- 상류 `compound-engineering-plugin` — 5-차원 overlap 스코어링, Auto Memory 관례, 영속성 원칙.
- 상류 `p4cn` — 3번째 트리거를 구동하는 `session-wrap` 2-phase 파이프라인.
- [`../axes.ko.md`](../axes.ko.md) — `/compound`의 축 매트릭스 행 (Context ON, Execute ON, Improve ON).
- [`../faq.ko.md`](../faq.ko.md) — Q4 (게이트 귀찮음), Q5 (`/orchestrate` vs 수동 체이닝).
- [`../../skills/compound/SKILL.md`](../../skills/compound/SKILL.md) — SKILL 계약.

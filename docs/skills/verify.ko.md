# `/verify`

> `qa-judge`로 산출물을 채점하고, Ralph Loop로 재시도하며, cap 도달 시 수동 리뷰로 폴스루합니다.

[English](./verify.md) · 한국어

## 패러다임 (Paradigm)

Verify는 부재가 pass와 외부에서 동일하게 보이는 유일한 축입니다. `/verify`는 그 부재를 **불가능하게** 만들기 위해 존재합니다: 다른 스킬(`/plan`, `/compound`, `/orchestrate`)이 산출물을 재해석하지 않고 읽을 수 있는 수치 판정(`qa-judge` score + dimensions)을 냅니다. 재시도 루프(Ralph Loop)와 fresh-context 분리는 판정이 단지 존재하는 것을 넘어 *신뢰할 수 있도록* 만드는 장치입니다. `/verify`가 단일-패스에 작성자 컨텍스트를 재사용한다면 판정은 자기 리뷰가 됩니다.

## 판정 (Judgment)

입력: 산출물 경로 + 옵션 `--axis N` scope. 출력: `{score, verdict, dimensions, differences, suggestions}`를 담은 `qa-judge` JSON 리포트.

결정 로직:

1. `qa-judge`를 **fresh Claude Code 컨텍스트**(작성자 턴 없음)에서 실행. 이것이 Evaluator가 작성자의 블라인드 스팟을 상속받지 않게 막습니다.
2. `score`를 읽어 세 밴드 중 하나에 배치:
   - `score ≥ 0.80` → `promote` (수용).
   - `0.40 ≤ score < 0.80` → `retry` (최대 3회 Ralph Loop).
   - `score ≤ 0.40` → `reject` (작성자에게 반환).
3. `retry`시 **3-stage Evaluator** 실행: (a) acceptance criteria 대비 산출물 diff, (b) 최소 수정 제안, (c) 재채점. post-edit score가 `promote`로 교차하면 수용, 아니면 retry counter 감소.
4. retry counter가 0에 도달하면 또 다른 루프를 강요하지 않고 `verdict: manual_review`를 emit. cap은 목표가 아니라 회로 차단기.

`--axis N`은 `qa-judge`를 단일 축 루브릭으로 좁힘(예: `--axis 5`는 플랜에 Verify-only 실행). `--skip-axis 5 --acknowledge-risk`는 파이프라인 수준에서 `/verify`를 우회하는 **유일한** 방법. [`../axes.ko.md`](../axes.ko.md#axis-5는-다릅니다---skip-axis-5는---acknowledge-risk-필수) 참조.

## 설계 선택 (Design Choices)

- **Fresh 컨텍스트, 지속 컨텍스트 아님.** 지속 Evaluator는 몇 라운드 후 작성자의 추론으로 수렴합니다. fresh 컨텍스트는 Evaluator가 산출물만으로 판정을 재도출하도록 강제 — 우리가 원하는 것.
- **3 밴드, 2개 아님.** 이진 `pass / fail`은 "거의 충분, 한 번 더"라는 시그널을 버립니다. `retry` 밴드가 Ralph Loop가 가치를 더하는 곳.
- **Ralph Loop, 임시 재시도 아님.** Ralph Loop는 capped counter + structured critic을 갖춘 `ouroboros` 관례. 작성자 컨텍스트에서의 임시 재시도는 **트렌치코트 입은 자기 리뷰**.
- **재시도 내부의 3-stage Evaluator.** "diff → propose → re-score" 분리는 각 stage를 단순하게 유지. "한 번에 다시 써서 다시 채점"을 시도했으나 acceptance criteria까지 같이 다시 쓰는 경향이 발견.
- **`qa-judge`는 구조화된 JSON을 emit, 산문 아님.** 소비자(`/compound`, `/orchestrate`, skip 로그)는 파싱 가능한 판정이 필요. 산문-only 리포트는 파싱 불가.
- **Cap 시 `manual_review`로 폴스루.** cap 너머의 조용한 루프는 큰 소리의 에스컬레이션보다 **더 나쁩니다**. cap은 스킬의 실패가 아니라 사람에게 넘기는 핸드오프.

## Thresholds

모든 수치 값은 [`../thresholds.ko.md`](../thresholds.ko.md)에 거주:

- 판정 밴드 `promote ≥ 0.80 / retry 0.40–0.80 / reject ≤ 0.40` — [§1](../thresholds.ko.md#1-qa-judge-판정-밴드--promote--080-retry-040080-reject--040).
- Ralph Loop 재시도 cap `3` — [§6](../thresholds.ko.md#6-ralph-loop-재시도-cap--3).
- `validate_prompt` fire/response rate `≥ 0.99 / 0.90` — [§3](../thresholds.ko.md#3-validate_prompt--fire_rate--099-response_rate--090).
- 밴드 뒤의 KU-0 히스토그램 — [§1](../thresholds.ko.md#1-qa-judge-판정-밴드--promote--080-retry-040080-reject--040)이 `p25 = 0.50`, `p75 = 0.86`을 인용.

## 참고

- 상류 `ouroboros` — `qa-judge` JSON 스키마, Ralph Loop 관례, 재시도 cap.
- 상류 `superpowers` (obra/superpowers) — `HARD-GATE` 태그 패턴과 3-stage Evaluator.
- 상류 `hoyeon` — 3-stage Evaluator의 diff-and-propose 분리가 참조하는 6-agent verify 스택.
- [`../axes.ko.md`](../axes.ko.md) — Axis 5 근거와 `--acknowledge-risk` 계약.
- [`../faq.ko.md`](../faq.ko.md) — Q3 (Ralph Loop 무한 루프?), Q9 (`--acknowledge-risk`).
- [`../../skills/verify/SKILL.md`](../../skills/verify/SKILL.md) — SKILL 계약.

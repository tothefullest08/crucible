# Thresholds — 수치 단일 소스(single source of truth)

> ⚠️ **MVP 상태.** 아래 모든 수치는 (a) 상류 관례, (b) 설계 파생, 또는 (c) 20-샘플 **합성 fixture**(`.claude/state/ku-results/` 하의 KU-0 · KU-1 · KU-2 · KU-3) 중 하나에 anchor되어 있습니다. 실세션 JSONL 로그 ≥ 100건이 수집되면 프로덕션 튜닝이 **필수**입니다. 이 값들은 기본값으로 취급하지 검증된 프로덕션 상수로 취급하지 마세요.

[English](./thresholds.md) · 한국어

`crucible`이 사용하는 모든 정량 값은 이 파일에 거주합니다. 다른 모든 파일은 이쪽을 링크합니다. **어떤 수치도 중복 정의되지 않습니다.** 값 수정은 이 파일을 먼저 바꾼 다음, 참조하는 문서를 갱신하는 순서로 진행합니다.

---

## 0. 수치 도출 메커니즘 (how the numbers are produced)

이 파일의 수치는 두 단계로 생산됩니다. **(A) 원시 관측치를 얻는 단계**와 **(B) 분위수·비율로 집계하는 단계**. MVP 현재는 (A)가 합성 fixture로 대체되어 있고, (B)만 실제 bash + awk + jq 스크립트로 돌아갑니다. "자연어 대화가 어떻게 `0.72` 같은 숫자가 되는가"의 답도 이 두 단계에 나뉘어 있습니다.

### (A) 원시 관측치 — "자연어 판정"이 어떻게 숫자로 바뀌는가

두 종류의 원시 값이 있습니다.

**1. `qa-judge` score (§1, §5와 관련)**

- 실체는 **LLM-as-judge**입니다. 별도 계산기 · 규칙 엔진 · 공식은 존재하지 않습니다. `agents/evaluator/qa-judge.md:18-72`에 정의된 프롬프트가 opus 서브에이전트로 호출됩니다.
- 호출 흐름은 다음과 같습니다.
  1. `/verify`가 `qa-judge` 서브에이전트에 artifact + `evaluation_criteria` + `pass_threshold`를 넘김.
  2. LLM이 프롬프트 지시에 따라 3개 차원(`correctness`, `clarity`, `maintainability`)을 각각 `[0.0, 1.0]` float으로 **자가 채점**.
  3. aggregate한 단일 `score` + verdict(`promote | retry | reject`) + `differences[]` + `suggestions[]`를 **strict JSON**으로만 반환 (prose · code fence 금지).
  4. `/verify` bash 스크립트는 이 JSON을 `jq`로 파싱해 임계값(§1)과 비교할 뿐, 점수를 재계산하지 않음.
- 즉 `score = 0.72`는 알고리즘 결과가 아니라 **"이 artifact는 clarity 0.68, correctness 0.75…"라고 LLM이 rubric에 근거해 주관적으로 붙인 라벨**입니다. rubric-based LLM-as-judge 방식의 본질적 한계 — run-to-run variance, self-preference bias, rubric gaming, boundary-anchoring — 는 다음 3가지 장치로 흡수하도록 설계되어 있지 실측으로 제거된 것이 아닙니다.
  - **Grey zone**: 단일 임계값이 아닌 넓은 `0.40–0.80` retry 구간 (§1)
  - **Ralph Loop**: retry 밴드에서 최대 3회 재생성 + 재채점 (§6)
  - **User approval gate**: qa-judge가 promote해도 `/compound`는 사용자 승인 없이 메모리에 쓰지 않음 (CLAUDE.md §6 Improve)

**2. `validate_prompt` fire / response 관측치 (§3과 관련)**

- 실체는 **세션 JSONL의 tool_use 이벤트 관찰**입니다 (프로덕션 의도). 특정 프롬프트가 들어왔을 때 `SKILL` tool_use가 실제로 발생했는지(`fire`), 응답 문자열이 기대 정규식과 매칭되는지(`response`)를 이벤트로 기록하는 방식입니다.
- **MVP 현재 이 관측은 모두 fixture로 대체**되어 있습니다. `__tests__/fixtures/ku-1-validate-prompt/*.json`의 각 샘플이 `"actual_fire": true/false`, `"actual_response": "..."`, `"initial_match": true/false`, `"expected_response_pattern": "..."`를 **사람이 손으로 미리 채워둠**. 실제 훅은 호출되지 않으며, 스크립트는 이 하드코딩된 플래그를 집계할 뿐입니다.

### (B) 집계 — fixture → 분위수 · 비율

(A)의 원시 값이 모이면, `scripts/`의 bash + awk + jq 스크립트가 순수 산술로 분위수와 비율을 뽑습니다. LLM은 이 단계에 개입하지 않습니다. Python도 사용되지 않습니다 (final-spec §4.1).

**KU-0 — `scripts/ku-0-run.sh` + `scripts/ku-histogram.sh`**

- 입력: `__tests__/fixtures/ku-0-qa-judge/samples.jsonl` (20줄, 각 줄에 하나의 합성 `qa-judge` 응답 — `score`, `verdict`, `dimensions`)
- 처리:
  1. `jq -r '.score'`로 float 20개 추출
  2. `sort -n`으로 오름차순 정렬
  3. awk 선형 보간으로 p10 / p25 / p50 / p75 / p90 계산 — 공식: `pos = p × (n − 1) + 1`, `lo = floor(pos)`, `hi = min(lo + 1, n)`, `q = a[lo] + (pos − lo) × (a[hi] − a[lo])`
- 출력: `.claude/state/ku-results/ku-0.json`의 `histogram` 객체
- **§1의 `p25=0.50`, `p50=0.72`, `p75=0.86`, `p90=0.92`는 정확히 이 20개 합성 숫자(`0.10, 0.22, 0.30, 0.38, 0.45, 0.52, 0.58, 0.62, 0.66, 0.70, 0.74, 0.78, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92, 0.93, 0.95`)에서 나온 분위수**입니다. 실세션 `qa-judge` 분포가 아닙니다. 숫자들은 reject · retry · promote 3밴드에 고르게 분포하도록 **fixture 제작자가 수동 작성**했습니다.

**KU-1 — `scripts/ku-1-run.sh`**

- 입력: `__tests__/fixtures/ku-1-validate-prompt/*.json` (20개 파일, 각 파일이 한 샘플)
- 처리: 각 샘플의 `actual_fire`를 집계해 `fire_rate = fired / 20`, 발화된 것 중 정규식 매칭된 비율로 `response_rate = matched / fired` 계산. `initial_match = false`면 규칙 기반 1회 retry를 시뮬레이션(프라이머리 키워드를 응답에 주입 후 재매칭).
- 출력: `.claude/state/ku-results/ku-1.json`
- **§3의 `fire_rate = 1.00`은 "20개 fixture 모두에 `actual_fire: true`가 적혀 있다"는 뜻**이지, 실제 훅이 99% 이상 발동한다는 경험적 증거가 아닙니다.

**KU-2, KU-3** — 동일 패턴. fixture에 ground-truth 라벨과 예측치가 미리 적혀 있고, 스크립트는 accuracy · confusion matrix만 계산.

### 프로덕션 전환 계획

각 `ku-*-run.sh`는 `KU_DATA_SOURCE` 환경 변수를 봅니다. 기본값은 `synthetic` (fixture), `real_session`으로 돌리면 실세션 JSONL 로그를 원시 입력으로 사용하도록 설계되어 있습니다. **실세션 로그 ≥ 100건이 쌓이기 전까지 이 전환은 일어나지 않습니다** — 현재 모든 수치가 "개발자가 3밴드에 고르게 분포하도록 손으로 찍어둔 placeholder의 분위수"인 이유입니다. 따라서 이 파일의 수치는 프로덕션 상수가 아닌 **기본값(default)**으로 취급해야 하며, 파일 상단 ⚠️ 경고의 의미도 이것입니다.

---

## 1. `qa-judge` 판정 밴드 — `promote ≥ 0.80`, `retry 0.40–0.80`, `reject ≤ 0.40`

| 밴드 | 범위 | 행동 |
|------|-----|------|
| promote | `score ≥ 0.80` | 산출물 수용. |
| retry | `0.40 ≤ score < 0.80` | Ralph Loop 재시도 (§6). |
| reject | `score ≤ 0.40` | 산출물 거부; rework 요구. |

- **출처.** 상류 `ouroboros` 기본값 (accept 0.80, retry 0.40).
- **스코어 생성 방식.** 점수는 `qa-judge` LLM 서브에이전트(opus)가 3차원(`correctness` · `clarity` · `maintainability`) rubric에 근거해 자가 채점한 후 aggregate한 값입니다. 별도 계산 알고리즘이 없습니다 — 상세는 §0 (A-1).
- **측정 (KU-0).** `__tests__/fixtures/ku-0-qa-judge/samples.jsonl`의 합성 점수 20개(`0.10 … 0.95`, reject/retry/promote 3밴드에 고르게 분포하도록 수동 작성)에 대해 `scripts/ku-histogram.sh`가 선형 보간 분위수를 계산한 결과: `p25 = 0.50`, `p50 = 0.72`, `p75 = 0.86`, `p90 = 0.92`. 실제 `qa-judge` LLM을 20회 돌려 수집한 분포가 아닙니다 (§0 B).
- **관찰.** KU-0은 상류 기본값을 `accept 0.86 / retry 0.50`으로 재quantile화했습니다. 20-샘플 fixture는 공개 임계값을 옮기기엔 작아서 MVP는 `0.80 / 0.40`을 유지합니다.
- **튜닝 계획.** 실세션 `qa-judge` 출력 ≥ 100건에 대해 `KU_DATA_SOURCE=real_session scripts/ku-0-run.sh` 재실행. 프로덕션 분포가 여전히 우편향이라면 `accept = p75`, `retry = p25` 채택.

## 2. KU 샘플 사이즈 — `n = 20`

- **출처.** Binary-verdict 95% 신뢰구간 폭.
- **파생.** `p̂ ≈ 0.5`인 이항 추정에서 CI 반폭은 대략 `1/√n`: `n=10 → ±30 %pp`, `n=20 → ±22 %pp`, `n=30 → ±17 %pp`. `n=20`은 CI 반폭이 25 %pp 가독성 임계 아래로 교차하는 최소 크기입니다.
- **튜닝 계획.** dogfooding이 충분한 적격 세션을 만들어내면 acceptance KU에 대해 `n=30`으로 상향.

## 3. `validate_prompt` — `fire_rate ≥ 0.99`, `response_rate ≥ 0.90`

- **출처.** KU-1 acceptance 임계 (W7.5 AC-3).
- **관측치 생성 방식.** `fire_rate`와 `response_rate`의 프로덕션 의도 정의는 세션 JSONL tool_use 이벤트 관찰입니다 — 특정 프롬프트 입력 시 `SKILL` tool_use가 발생했는지(`fire`), 응답이 기대 정규식에 매칭됐는지(`response`). MVP에서는 이 관측이 fixture 하드코딩으로 대체 — 상세는 §0 (A-2).
- **측정 (KU-1).** `__tests__/fixtures/ku-1-validate-prompt/*.json` 20개 각각에 `actual_fire`, `actual_response`, `initial_match`, `expected_response_pattern` 필드가 수동 작성되어 있고, `scripts/ku-1-run.sh`가 이를 집계해 `fire_rate = fired/20 = 1.00`, `response_rate = matched/fired = 1.00`, `retried = 1`을 계산. 실제 훅 호출이나 LLM 응답은 발생하지 않습니다.
- **관찰.** Fixture가 완전 합성이므로 실제 miss는 관측되지 않음 — `fire_rate = 1.00`은 "20개 fixture 모두에 `actual_fire: true`가 적혀 있다"는 뜻이지 경험적 발동률이 아님.
- **튜닝 계획.** 프로덕션 세션 JSONL을 원시 입력으로 쓰는 `KU_DATA_SOURCE=real_session` 모드로 전환 시 `fire ≥ 0.99`를 유지해야 함. user-visible retry가 지배적 class가 될 때만 임계 하향.

## 4. Description 트리거 정확도 — `|Δ(ko − en)| ≤ 5 %pp`

- **출처.** KU-2 acceptance 임계 (W7.5 AC-4).
- **측정 (KU-2).** `__tests__/fixtures/ku-2-description/` 아래 합성 프롬프트 40개(ko 20 + en 20)에 각 샘플의 expected trigger와 predicted trigger가 미리 라벨링되어 있고, `scripts/ku-2-run.sh`가 accuracy를 계산: `ko_accuracy = 1.00`, `en_accuracy = 1.00`, `Δ_abs = |ko − en| = 0.00`. 실제 description 매칭 로직이 아니라 fixture 라벨을 집계한 값입니다 (§0 B와 동일 패턴).
- **관찰.** Fixture는 언어 간 Δ = 0; 프로덕션 drift는 여기서 먼저 나타날 것.
- **튜닝 계획.** 실사용에서 Δ 모니터링. 임계 초과 Δ는 릴리스 전 description 재작성을 강제.

## 5. 승격 게이트 오탐률 — `≤ 20 %`

- **출처.** KU-3 acceptance 임계 (W7.5 AC-5).
- **측정 (KU-3).** `__tests__/fixtures/ku-3-promotion-gate/` 아래 합성 후보 20개에 각 샘플의 ground truth(`signal | noise`)와 게이트의 predicted verdict가 라벨링되어 있고, `scripts/ku-3-run.sh`가 confusion matrix를 계산: `(TP=10, FP=0, TN=10, FN=0)`, `false_positive_rate = FP / (FP + TN) = 0.00`. 실제 `/compound` 게이트 추론이 아니라 fixture 라벨의 집계값입니다.
- **관찰.** `/compound` 게이트가 fixture의 모든 비-시그널 후보를 거부. 실제 corrections는 분리가 더 어려울 것.
- **튜닝 계획.** 프로덕션 FP가 `0.20`을 초과하면 overlap 임계(§7) 상향 또는 승격 흐름에 2차 리뷰어 패스 추가.

## 6. Ralph Loop 재시도 cap — `3`

- **출처.** `ouroboros` 관례 — 상류 retry 루프가 runaway generation을 막기 위해 쓰는 동일한 cap.
- **파생.** `qa-judge`가 retry 밴드(`0.40–0.80`)에 있을 때, 3회 재시도는 무한 비평 루프로 가지 않으면서 사람 피드백 한 라운드에 대응할 예산을 모델에 줍니다. Cap 도달 → 수동 개입으로 폴스루.
- **튜닝 계획.** 실세션에서 3차 시도가 일관되게 성공하면만 상향. 그렇지 않으면 cap은 회로 차단기입니다.

## 7. 5-차원 overlap 가중치

`/compound`가 새 correction이 기존 메모리 엔트리의 중복인지 채점할 때 사용:

| 차원 | 가중치 |
|------|:----:|
| problem | `0.30` |
| cause | `0.20` |
| solution | `0.20` |
| files | `0.15` |
| prevention | `0.15` |
| **합** | **1.00** |

- **출처.** `compound-engineering-plugin`의 5-차원 overlap 스코어링에서 포팅. `/compound`의 승격 의미론에 맞춰 가중치 조정.
- **파생.** `problem`이 지배적 — 같은 실패 모드를 명명한 두 correction은 다른 fix를 배포해도 중복입니다. `cause`와 `solution`은 2단 — 단독으로는 모호합니다. `files`와 `prevention`은 tiebreaker이므로 최저 가중치.
- **튜닝 계획.** 승격 게이트 FP(§5)가 `0.20`을 넘으면 첫 레버는 `problem`을 `0.40`으로 올리고 나머지를 재조정해 합을 `1.00`으로 유지.

## 8. Oscillation guard — `overlap ≥ 0.80` within `Gen N-2`

- **출처.** 설계 추론 — `/verify`의 재시도 루프와 `/compound`의 재승격 루프가 거의 동일한 두 후보 사이를 왕복할 수 있음.
- **파생.** `N` 세대가 `N-2` 세대(두 단계 전)와 5-D 점수(§7) 기준 `≥ 0.80`으로 overlap하면, 남은 재시도를 같은 쌍에 소진하는 대신 oscillation으로 판단해 루프를 중단.
- **튜닝 계획.** 실제 oscillation 데이터가 생기면 비교 윈도우(`N-2`)와 임계를 함께 조정 — 두 레버는 따로는 무의미.

---

## 교차 참조 요약

| # | 수치 | 사용처 |
|---|-----|-------|
| 0 | 수치 도출 메커니즘 (LLM-as-judge + bash 집계) | — (이 파일 내부 참조) |
| 1 | `0.80 / 0.40` 판정 밴드 | [`skills/verify.ko.md`](./skills/verify.ko.md), [`faq.ko.md`](./faq.ko.md) |
| 2 | `n = 20` KU 샘플 크기 | [`faq.ko.md`](./faq.ko.md) |
| 3 | `fire ≥ 0.99`, `response ≥ 0.90` | [`axes.ko.md`](./axes.ko.md) §4 Execute |
| 4 | `Δ ≤ 5 %pp` | [`faq.ko.md`](./faq.ko.md) 이중언어 Q |
| 5 | `FP ≤ 20 %` | [`skills/compound.ko.md`](./skills/compound.ko.md) |
| 6 | Ralph Loop cap `3` | [`skills/verify.ko.md`](./skills/verify.ko.md), [`faq.ko.md`](./faq.ko.md) |
| 7 | Overlap 가중치 | [`skills/compound.ko.md`](./skills/compound.ko.md) |
| 8 | Oscillation guard | [`skills/compound.ko.md`](./skills/compound.ko.md), [`skills/orchestrate.ko.md`](./skills/orchestrate.ko.md) |

`docs/`나 `README.md` 어디든 새 정량 값을 추가할 때는, 이 파일에 새 번호 섹션을 **먼저** 추가하고 소비 파일에서 그쪽을 링크하세요.

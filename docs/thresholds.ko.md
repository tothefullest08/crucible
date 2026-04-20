# Thresholds — 수치 단일 소스(single source of truth)

> ⚠️ **MVP 상태.** 아래 모든 수치는 (a) 상류 관례, (b) 설계 파생, 또는 (c) 20-샘플 **합성 fixture**(`.claude/state/ku-results/` 하의 KU-0 · KU-1 · KU-2 · KU-3) 중 하나에 anchor되어 있습니다. 실세션 JSONL 로그 ≥ 100건이 수집되면 프로덕션 튜닝이 **필수**입니다. 이 값들은 기본값으로 취급하지 검증된 프로덕션 상수로 취급하지 마세요.

[English](./thresholds.md) · 한국어

`crucible`이 사용하는 모든 정량 값은 이 파일에 거주합니다. 다른 모든 파일은 이쪽을 링크합니다. **어떤 수치도 중복 정의되지 않습니다.** 값 수정은 이 파일을 먼저 바꾼 다음, 참조하는 문서를 갱신하는 순서로 진행합니다.

---

## 1. `qa-judge` 판정 밴드 — `promote ≥ 0.80`, `retry 0.40–0.80`, `reject ≤ 0.40`

| 밴드 | 범위 | 행동 |
|------|-----|------|
| promote | `score ≥ 0.80` | 산출물 수용. |
| retry | `0.40 ≤ score < 0.80` | Ralph Loop 재시도 (§6). |
| reject | `score ≤ 0.40` | 산출물 거부; rework 요구. |

- **출처.** 상류 `ouroboros` 기본값 (accept 0.80, retry 0.40).
- **측정.** KU-0, 합성 `qa-judge` 실행 20회 히스토그램: `p25 = 0.50`, `p50 = 0.72`, `p75 = 0.86`, `p90 = 0.92`.
- **관찰.** KU-0은 상류 기본값을 `accept 0.86 / retry 0.50`으로 재quantile화했습니다. 20-샘플 fixture는 공개 임계값을 옮기기엔 작아서 MVP는 `0.80 / 0.40`을 유지합니다.
- **튜닝 계획.** 실세션 `qa-judge` 출력 ≥ 100건에 KU-0 재실행. 프로덕션 분포가 여전히 우편향이라면 `accept = p75`, `retry = p25` 채택.

## 2. KU 샘플 사이즈 — `n = 20`

- **출처.** Binary-verdict 95% 신뢰구간 폭.
- **파생.** `p̂ ≈ 0.5`인 이항 추정에서 CI 반폭은 대략 `1/√n`: `n=10 → ±30 %pp`, `n=20 → ±22 %pp`, `n=30 → ±17 %pp`. `n=20`은 CI 반폭이 25 %pp 가독성 임계 아래로 교차하는 최소 크기입니다.
- **튜닝 계획.** dogfooding이 충분한 적격 세션을 만들어내면 acceptance KU에 대해 `n=30`으로 상향.

## 3. `validate_prompt` — `fire_rate ≥ 0.99`, `response_rate ≥ 0.90`

- **출처.** KU-1 acceptance 임계 (W7.5 AC-3).
- **측정 (KU-1).** 합성 프롬프트 20개 → `fire_rate = 1.00`, `response_rate = 1.00`, `retried = 1` 샘플.
- **관찰.** Fixture가 완전 합성이므로 실제 miss는 관측되지 않음.
- **튜닝 계획.** 프로덕션 로그는 `fire ≥ 0.99`를 유지해야 함. user-visible retry가 지배적 class가 될 때만 임계 하향.

## 4. Description 트리거 정확도 — `|Δ(ko − en)| ≤ 5 %pp`

- **출처.** KU-2 acceptance 임계 (W7.5 AC-4).
- **측정 (KU-2).** 합성 프롬프트 40개(ko 20 + en 20) → `ko_accuracy = 1.00`, `en_accuracy = 1.00`, `Δ_abs = 0.00`.
- **관찰.** Fixture는 언어 간 Δ = 0; 프로덕션 drift는 여기서 먼저 나타날 것.
- **튜닝 계획.** 실사용에서 Δ 모니터링. 임계 초과 Δ는 릴리스 전 description 재작성을 강제.

## 5. 승격 게이트 오탐률 — `≤ 20 %`

- **출처.** KU-3 acceptance 임계 (W7.5 AC-5).
- **측정 (KU-3).** 합성 후보 20개 (`TP 10 + TN 10`) → `false_positive_rate = 0.00`, confusion `(TP=10, FP=0, TN=10, FN=0)`.
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
| 1 | `0.80 / 0.40` 판정 밴드 | [`skills/verify.ko.md`](./skills/verify.ko.md), [`faq.ko.md`](./faq.ko.md) |
| 2 | `n = 20` KU 샘플 크기 | [`faq.ko.md`](./faq.ko.md) |
| 3 | `fire ≥ 0.99`, `response ≥ 0.90` | [`axes.ko.md`](./axes.ko.md) §4 Execute |
| 4 | `Δ ≤ 5 %pp` | [`faq.ko.md`](./faq.ko.md) 이중언어 Q |
| 5 | `FP ≤ 20 %` | [`skills/compound.ko.md`](./skills/compound.ko.md) |
| 6 | Ralph Loop cap `3` | [`skills/verify.ko.md`](./skills/verify.ko.md), [`faq.ko.md`](./faq.ko.md) |
| 7 | Overlap 가중치 | [`skills/compound.ko.md`](./skills/compound.ko.md) |
| 8 | Oscillation guard | [`skills/compound.ko.md`](./skills/compound.ko.md), [`skills/orchestrate.ko.md`](./skills/orchestrate.ko.md) |

`docs/`나 `README.md` 어디든 새 정량 값을 추가할 때는, 이 파일에 새 번호 섹션을 **먼저** 추가하고 소비 파일에서 그쪽을 링크하세요.

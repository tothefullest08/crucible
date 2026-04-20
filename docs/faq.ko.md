# FAQ

> 단순 답변 형식 FAQ. 모든 수치 값은 [`thresholds.ko.md`](./thresholds.ko.md)로 되짚어 갑니다. 이 문서는 해당 값이 *왜* 존재하는지 설명하지, 값이 무엇인지 나열하지는 않습니다.

[English](./faq.md) · 한국어

---

## Q1. `qa-judge`가 왜 `0.80 / 0.40`인가?

상류 `ouroboros` 기본값이 `promote ≥ 0.80`, `reject ≤ 0.40`이고 MVP에서 그대로 유지했습니다. KU-0이 20개 합성 샘플에 실제 분포를 재측정한 결과 `p75 = 0.86`, `p25 = 0.50`이 나와 fixture 대비 보수적입니다. 20샘플만으로 공개 임계값을 옮기지는 않습니다. 계획은 `qa-judge` 실세션 로그 ≥ 100건에 KU-0을 재실행하고 그 시점에 측정된 `p75 / p25`를 채택하는 것입니다. [`thresholds.ko.md` §1](./thresholds.ko.md#1-qa-judge-판정-밴드--promote--080-retry-040080-reject--040) 참조.

## Q2. 전부 합성 fixture로 구축했다. 프로덕션에서 신뢰해도 되나?

**아니요 — 검증된 시스템으로는 신뢰하지 마세요.** MVP로서 신뢰하세요. `.claude/state/ku-results/`의 모든 KU는 `data_source: synthetic`으로 표시되어 있고, [`thresholds.ko.md`](./thresholds.ko.md)의 모든 임계값은 동일한 주의사항을 달고 있습니다. fixture는 *배선*을 증명하지 *캘리브레이션*을 증명하지 않습니다. 프로덕션 튜닝 루프는: dogfood → 실세션 수집 → 해당 풀에 KU-0/1/2/3 재실행 → 측정값 채택. 이 통과가 완료되기 전까지 `crucible`은 기본값을 가진 구조적 하네스이지, 튜닝된 릴리스가 아닙니다.

## Q3. Ralph Loop가 영원히 돌지 않나?

아닙니다. `/verify`는 Ralph Loop 재시도를 `3`으로 상한 처리합니다 ([`thresholds.ko.md` §6](./thresholds.ko.md#6-ralph-loop-재시도-cap--3)). cap에 도달하면 루프는 다시 후보를 생성하지 않고 수동 리뷰로 폴스루(fall-through)합니다. 이 cap은 상류 `ouroboros`가 사용하는 관례이며, `qa-judge` retry 밴드가 무한 비평 루프로 전환되는 것을 막기 위해 존재합니다. cap을 올리는 것은 합성 증거만으로는 내리지 않는 튜닝 결정입니다.

## Q4. 승격 게이트가 귀찮지 않나?

게이트가 핵심입니다 — 자동 메모리 쓰기가 바로 우리가 방어하는 실패 모드입니다. 두 가지 완화책이 부드럽게 해줍니다: `Stop` 훅이 세션 말미에 대기 중인 후보들을 하나의 y/N/e/s 프롬프트로 batch하고, 3회 연속 거부된 detector는 7일 동안 자동 비활성화됩니다. 실제 워크플로에서도 게이트가 시끄럽게 느껴진다면 제일 먼저 당길 레버는 False Positive rate입니다 ([`thresholds.ko.md` §5](./thresholds.ko.md#5-승격-게이트-오탐률--20-)) — 더 자주 옳은 게이트는 비용이 적습니다.

## Q5. `/orchestrate`는 `/brainstorm → /plan → /verify → /compound`를 수동으로 호출하는 것과 뭐가 다른가?

`/orchestrate`는 같은 4축이지만, 각 축 뒤에 디스크에 체크포인트(`CP-0 … CP-5`)를 쓰고 각 체크포인트는 실행 로그에 SHA256으로 핀 처리됩니다. CP-2와 CP-3 사이에 세션이 크래시해도 `/orchestrate` 재호출 시 CP-2부터 재개 — 재작업 없음, 조용한 상태 분기 없음. 수동 체이닝은 방해를 받을 때마다 제로부터 재실행되고 무결성 기록이 없습니다. 탐색에는 수동 체인을, 릴리스를 낼 때는 `/orchestrate`를 쓰세요.

## Q6. 한국어 트리거 동등성(parity)은 실제인가, MVP 주장인가?

KU-2가 한국어 20 + 영어 20 합성 프롬프트에 대해 `Δ_abs = 0.00`을 측정했습니다 ([`thresholds.ko.md` §4](./thresholds.ko.md#4-description-트리거-정확도--δko--en--5-)). fixture 결과이지 프로덕션 결과가 아닙니다. 임계값은 `≤ 5 %pp`이고, 프로덕션 drift가 이를 넘으면 첫 번째 시정 조치는 스킬 `description` 재작성이지 임계값 완화가 아닙니다. 한국어 parity는 **모니터링되는 속성**이지 보증된 속성은 아닙니다.

## Q7. Claude Code 밖에서 돌릴 수 있나?

아닙니다. `crucible`은 Claude Code 스킬 프로토콜(`SKILL.md` frontmatter, `SessionStart` / `Stop` / `PreToolUse` 훅, `.claude-plugin/plugin.json` 레이아웃, `validate_prompt` 훅)에 의존합니다. 일반 LLM 하네스 등가물이 없으므로 다른 호스트로 포팅하면 모든 축을 재구축해야 합니다. 런타임 요구사항(`bash`, `jq`, `uuidgen`, `flock`)은 의도적으로 최소화되어 있어 Claude Code가 돌아가는 모든 머신은 `crucible`도 돌릴 수 있습니다.

## Q8. 가장 작게 유용한 변화는 뭐지?

이미 `.claude/plans/`에 있는 아무 플랜 문서에 `/verify`를 돌리세요. 파이프라인 나머지를 건드리지 않고 `qa-judge` 판정을 얻고, 그 판정은 플랜 문서가 Evaluator-parseable인지에 대한 저렴한 피드백입니다. 이 방법이 임계값을 dogfood하는 가장 빠른 길이기도 합니다 — 이런 식으로 캡처한 실제 `qa-judge` 점수 하나하나가 Q1의 프로덕션 튜닝 계획을 한 샘플 앞으로 밀어줍니다.

## Q9. Axis 5에서 `--acknowledge-risk`를 빼면 어떻게 되나?

호출이 거부됩니다. `--skip-axis 5` 단독은 하네스가 받지 않습니다 — `--force`도, 환경변수 override도 없습니다. 근거는 [`axes.ko.md`](./axes.ko.md#axis-5는-다릅니다---skip-axis-5는---acknowledge-risk-필수)에 있습니다: 검증 스킵은 부재가 외부에서 pass처럼 보이는 유일한 축이라, 위험 경로는 안전 경로보다 타이핑하기 의도적으로 어렵게 설계됐습니다. 정말로 Verify를 스킵할 의도라면(예: `qa-judge`를 out-of-band로 이미 돌렸음), 두 플래그를 전부 넘기고 감사 로그에 `RISK-ACK`로 기록되게 하세요.

---

## 알려진 한계

Q2의 합성 fixture 주의사항에서 파생되는 세 한계를 한 번 명시해둡니다:

1. **임계값은 기본값이지 튜닝된 값이 아니다.** dogfooding이 실세션 로그 ≥ 100건을 만들어낼 때까지 [`thresholds.ko.md`](./thresholds.ko.md)의 모든 수치는 MVP 기본값입니다.
2. **Oscillation guard는 프로덕션에서 검증 안 됨.** `Gen N-2` 이내 `overlap ≥ 0.80` 규칙 ([`thresholds.ko.md` §8](./thresholds.ko.md#8-oscillation-guard--overlap--080-within-gen-n-2))은 설계 추론이며 실제 oscillation 데이터는 아직 없습니다.
3. **Drift 자동화 없음.** `thresholds.md`가 단일 소스지만 README 수치가 어긋날 때 이를 플래그하는 스크립트가 없습니다. 체크는 수동(T-README-11 체크리스트)이며 이후 스프린트에 예정되어 있습니다.

---

## 관련 문서

- [`axes.ko.md`](./axes.ko.md) — 6가지 축과 각각이 필수인 이유.
- [`thresholds.ko.md`](./thresholds.ko.md) — 수치적 단일 소스 (이 FAQ의 모든 수치는 이쪽을 링크).
- `skills/` — 스킬별 패러다임과 설계 선택.

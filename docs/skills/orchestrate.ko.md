# `/orchestrate` *(Stretch)*

> `/brainstorm → /plan → /verify → /compound`를 6개의 디스크 체크포인트로 체이닝, SHA256-핀, 재개 시 크래시-안전.

[English](./orchestrate.md) · 한국어

## 패러다임 (Paradigm)

`/orchestrate`는 6축을 동시에 모두 켜는 유일한 스킬입니다. 다른 모든 스킬은 파이프라인의 부분집합을 소유하고; `/orchestrate`는 파이프라인 그 자체를 소유합니다. 이 설계가 해결하는 긴장은 "end-to-end 실행을 원한다"와 "4번째가 크래시했다고 앞 3축을 다시 돌리고 싶진 않다" 사이의 간극입니다. 디스크 체크포인트는 양쪽을 보존하는 가장 저렴한 메커니즘 — 아무것도 깨지지 않으면 실행은 빠르고, 뭔가 깨지면 마지막 디스크 쓰기로부터 깔끔하게 재개.

## 판정 (Judgment)

입력: 주제 프롬프트(영어 또는 한국어). 출력: 6개 파일 체크포인트 트레일 + 각 축의 최종 산출물.

순차 단계 및 체크포인트:

| CP | 단계 | 체크포인트 내용 |
|----|----|------|
| **CP-0** | `/brainstorm` 호출 | 입력 프롬프트 + 해결된 모호점 |
| **CP-1** | `/plan` emit | 하이브리드 Markdown + YAML 플랜 파일 |
| **CP-2** | `/verify` 판정 | `qa-judge` JSON 리포트 |
| **CP-3** | `/compound` 게이트 결과 | 승인/거부 후보 |
| **CP-4** | 산출물 링크 번들 | 모든 파일 경로 + SHA256 |
| **CP-5** | `experiment-log.yaml` 커밋 | 전체 실행을 기록한 Git 커밋 |

각 체크포인트 파일은 `.claude/state/orchestrate/<run-id>/cp-N.json`에 거주하며 자기 SHA256을 `cp-N.json.sha256`에 기록. 재호출 시 `/orchestrate`는 가장 최신 유효 CP 파일을 읽고 다음 단계부터 재개. SHA 핀은 "디스크에서 재개"를 부채에서 **보증**으로 바꿉니다 — 어떤 체크포인트라도 변조되었다면 재개는 거부하고 실행은 CP-0부터 재시작.

### 허용된 `dispatch × work × verify` 조합

`/orchestrate`는 dispatch 전략 × 워커 형태 × verify 배치의 정확히 세 조합을 수용:

1. **sequential × single × end** — 워커 하나, 한 번에 한 축, verify는 맨 마지막. 기본.
2. **sequential × single × per-axis** — 워커 하나, 한 번에 한 축, *각* 축 이후 verify. 비용은 더 크지만 피드백 루프가 타이트.
3. **parallel-tasks × many × per-axis** — 한 축 내 독립 task 병렬 워커, per-axis로 verify 게이팅.

다른 조합(예: parallel × many × end-only)은 거부됨 — 하네스가 강제하도록 설계된 **축 수준 blast radius 제어**를 제거하기 때문.

## 설계 선택 (Design Choices)

- **4축 순서대로, 병렬 아님.** Brainstorm이 resolve되어야 Plan; Plan이 존재해야 Verify; Verify가 통과해야 Compound. 이 순차 의존성은 성능 선택이 아니라 **구조적**.
- **디스크 체크포인트, in-memory 상태 아님.** 전체 목적이 크래시 생존입니다. 디스크 이외의 모든 것은 세션이 죽을 때 사라집니다.
- **체크포인트당 SHA256 핀.** 핀이 없으면 변조된 CP 파일이 존재한 적 없는 상태에서 재개를 시작하게 됩니다. 핀은 재개를 **검증된 연산**으로 전환.
- **`CP-4`는 산출물 자체가 아닌 경로 번들.** 체크포인트 트레일에 산출물을 복제하면 실행 디렉토리가 부풀고 drift가 보장됩니다. 경로 + SHA는 복사 없이 재개 검증 가능.
- **`CP-5`는 파일이 아닌 git 커밋.** 최종 체크포인트는 워크스페이스 rm에 대한 내구성이 필요. 커밋은 로컬 머신에서 가장 강한 portable 내구성 경계.
- **`dispatch × work × verify` 3 조합, 임의적 아님.** 제한된 집합은 열거 가능·리뷰 가능·안전. per-axis 검증을 제거하는 어떤 조합도 하네스를 무력화.
- **체크포인트당 재호출은 멱등.** CP-3에서 `/orchestrate`를 두 번 돌려도 CP-0..CP-2를 재실행하지 않음; 출력을 읽고 재개. 멱등성이 재개를 **신뢰 가능**하게 만드는 속성.

## Thresholds

모든 수치 값은 [`../thresholds.ko.md`](../thresholds.ko.md)에 거주:

- 축별 적용되는 `qa-judge` 판정 밴드 — [§1](../thresholds.ko.md#1-qa-judge-판정-밴드--promote--080-retry-040080-reject--040).
- `/verify`에서 상속된 Ralph Loop 재시도 cap `3` — [§6](../thresholds.ko.md#6-ralph-loop-재시도-cap--3).
- Oscillation guard (`/compound`와 공유) — [§8](../thresholds.ko.md#8-oscillation-guard--overlap--080-within-gen-n-2).
- 체크포인트당 SHA256 무결성 — 설계 관례, 이 파일에서 추적.

## 참고

- 상류 `ouroboros` — 슬래시 커맨드 실행에 적응시킨 체크포인트 + 재개 관례.
- 상류 `superpowers` — `SessionStart` 훅과 축-scope된 훅 설계.
- 상류 `agent-council` — marketplace 최소 구조, 긴 실행 동안의 Wait 커서 UX.
- [`../axes.ko.md`](../axes.ko.md) — 6축 전체 (모든 셀이 ON인 유일한 행).
- [`../faq.ko.md`](../faq.ko.md) — Q5 (`/orchestrate` vs 수동 체이닝).
- [`../../skills/orchestrate/SKILL.md`](../../skills/orchestrate/SKILL.md) — SKILL 계약.

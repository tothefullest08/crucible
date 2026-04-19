# 하네스 플러그인 최종 스펙 — 종합 리뷰 리포트

> **검토 대상**: `.claude/plans/03-design/final-spec.md` (Phase 1+2+3 통합 스펙, 257 lines)
> **검토 방식**: document-review 스킬 — 7개 페르소나 병렬 디스패치 → 통합/중복 제거
> **작성일**: 2026-04-19
> **저자 권고**: `/ce-plan` 실행 **이전에** P0 전체 + P1 주요 이슈 해소 필요. 지금 상태로 태스크 분해에 들어가면 설계 결정이 구현 단계로 새어나감.

---

## 0. Executive Summary

### Coverage
| 페르소나 | 상태 | 핵심 관찰 |
|---------|------|---------|
| coherence | ✅ | 언어 제약(bash-only) ↔ 구현 필요성(jq/Python) 치명적 모순. 용어/카운트 드리프트 다수 |
| feasibility | ✅ | JSONL 포맷 가정 취약, W4-W6 언더스코프, "1× 비용" 주장 틀림 |
| scope-guardian | ✅ | 2차 항목(Consensus 자동, /orchestrate C)이 MVP Acceptance Criteria로 새어들어옴 |
| adversarial | ✅ | 프리미스 근거 빈약, "6축 강제" ↔ Non-Goal #7 운영 모순, KU 실험 오너십 갭 |
| design-lens | ✅ | 승격 게이트·Ralph Loop·온보딩·/orchestrate 파이프라인 UX 전원 미정의 |
| product-lens | ✅ | 차별점 4개 = 0개, OSS 타겟 ↔ 단일 완결형 상충, CE/hoyeon와 정체성 중복 |
| security-lens | ✅ | JSONL secrets redaction 부재, bash hook injection 위험, 배포 서명 없음 |

### Findings 통계
- **P0 (출시 전 반드시 해결)**: 9건
- **P1 (본 문서 업데이트 권장)**: 10건
- **P2 (형식/명확성)**: 8건
- **P3 (사소)**: 3건
- 총 30건 (7개 페르소나 70건을 테마별 통합·중복 제거)

### 가장 뾰족한 결론 (Top 3)
1. **문서가 "단일 진실 소스"가 아니다.** §11에 이관한 "열린 주제" 중 라이선스·프론트매터 필드·KU 실행계획은 설계 결정이지 구현 태스크가 아니다. `/ce-plan` 입력 전 본 문서에서 닫아야 한다.
2. **"6축 강제 MVP" 라는 정체성이 스펙 내부에서 자기모순이다.** 5개 스킬이 6축 중 4개만 커버하고, Non-Goal #7에서 체크리스트식 6축을 배제하면서도 primary로 '강제'를 유지한다. 이 긴장이 해소되지 않으면 구현자가 임의 해석한다.
3. **3개의 load-bearing 결정이 검증되지 않은 전제 위에 있다** — (a) JSONL 포맷 안정성, (b) "기존 플러그인에 6축 레퍼런스 없음", (c) "단일 완결형"이 OSS에 맞는 형태. 각각에 대한 falsification test 없이 8주 작업 착수 금지.

---

## 1. P0 Findings — `/ce-plan` 이전 반드시 해결

### P0-1. 언어 제약 vs 실제 구현 필요성 — 치명적 모순
**페르소나**: coherence F001 + feasibility F1·F2 + security F-06
**증거**:
- §4 비기능: `"순수 Markdown + JSON + bash 훅. Python/Node 미사용 (MVP)"`
- §9 Non-Goals #1: `"Python/Node 런타임 의존 (MVP는 bash + Markdown + JSON만)"`
- §5 architecture: `scripts/extract-session.sh — p4cn history-insight 포팅 (Claude JSONL 파서)`
- p4cn extract-session.sh 실제 구현: `if ! command -v jq &> /dev/null; then ... exit 1; fi`
- ouroboros 원본 스크립트는 `drift-monitor.py`, `keyword-detector.py` (pathlib/json/Path.home 사용) — bash 재작성 태스크 없음

**왜 P0**: 이 모순이 해소되지 않으면 W1 스캐폴드부터 결정이 표류한다. 또한 "순수 bash로 JSONL 파싱"은 **shell injection vector**가 된다 (JSONL 값에 $()/\`\`/;가 들어오면 파일명/grep 패턴으로 실행됨).

**구체적 수정 제안** (둘 중 택1, 하이브리드 권장):
- **(A) 런타임 허용 확대**: §4와 §9를 다음으로 교체:
  ```
  의존성: bash ≥ 4, jq ≥ 1.6, awk (macOS/Linux 표준). Python/Node 불허.
  JSONL 파싱은 jq로만 수행하며, bash 변수 보간은 "$var" 쌍따옴표 + printf '%s' 패턴으로만 제한한다.
  Non-Goals #1: Python/Node 런타임 의존 (jq/awk는 허용)
  ```
- **(B) Python 경량 허용**: §9 Non-Goals #1을 "Node 런타임 의존" 으로 축소하고 Python 3.9+ 허용. ouroboros 스크립트를 원본 그대로 포팅.
- **추가 조항**: `hooks/`, `scripts/` 내부에서 `eval` 금지, LLM/유저 입력을 command argument로 직접 보간 금지 명시 (Security F-04 대응).

---

### P0-2. Claude Code JSONL 포맷을 안정 계약처럼 가정함
**페르소나**: feasibility F3 + adversarial (environmental_assumption)
**증거**:
- §2.2 결정 #12: `"Claude가 이미 저장 중인 ~/.claude/projects/*.jsonl을 p4cn history-insight 방식으로 파싱. 별도 EventStore 없음"`
- §4 복원성: `"세션 로그는 Claude Code JSONL 재사용 → 우리 플러그인 오류로 데이터 소실 없음"`
- p4cn의 `session-file-format.md`는 12MB 샘플 기반 역공학 문서 — Anthropic 공식 스키마 아님. `file-history-snapshot(67%)`, `queue-operation(27%)` 등 CC 내부 타입은 이미 릴리스 간 변경된 이력 있음.

**왜 P0**: 메모리 + 컴파운딩 트리거 3종 + KU-1/KU-3가 **모두** 이 포맷 위에 얹혀 있다. Anthropic이 포맷을 바꾸는 순간 플러그인 전체가 고장난다. 이것은 단일 최고 위험 의존성이며 대안(UserPromptSubmit 훅 기반 라이브 캡처) 비교가 문서에 없다.

**구체적 수정 제안**:
- §4에 **"외부 스키마 안정성"** 행 추가:
  ```
  외부 스키마 안정성: ~/.claude/projects/*.jsonl은 Anthropic 비공식 포맷. 
  (1) 스키마 어댑터 레이어(schema_version 감지)로 파서 격리, 
  (2) 알 수 없는 type은 스킵(defensive parser), 
  (3) UserPromptSubmit 훅 기반 라이브 캡처를 2차 fallback으로 병기,
  (4) CC 릴리스 후 72시간 내 smoke test 실행(W1 CI 포함).
  ```
- 포맷 붕괴 시 degradation 시나리오(컴파운딩 비활성화 vs 전체 실패)를 §4 복원성에 명시.

---

### P0-3. 프리미스 "6축 레퍼런스 없음"이 표본 6개에 한정된 부재 증명
**페르소나**: adversarial (premise_unverified) + product-lens F1
**증거**: §1 TL;DR: `"기존 플러그인들(superpower/CE/hoyeon/ouroboros/agent-council/p4cn)이 각 축은 다루지만 '6축 메타-프레임워크'를 표면화한 레퍼런스가 없음. 우리의 순수 차별점."`

**왜 P0**: 8주 작업의 primary differentiator가 (a) 6개 플러그인만 조사한 표본 편향, (b) 사용자 요구 증거가 아닌 저자-가정 갭 위에 있다. Anthropic 공식 harness 문서, DSPy/Inspect-AI/LangGraph/AutoGen, 강의 저자(lecture/harness-day2-summary.md 원본)의 구현체가 조사되지 않았다. KU 어떤 것도 "사용자가 6축 프레임워크를 원한다"를 검증하지 않는다.

**구체적 수정 제안**:
- W0 태스크 추가: **"프리미스 재검증 (1일)"**
  1. Anthropic Cookbook `harness` 패턴 검색
  2. DSPy/Inspect-AI/LangGraph/AutoGen 공식문서에서 "meta-framework" 섹션 확인
  3. 강의 원저자(harness-day2-summary.md)의 공개 구현체 검색
  4. 3-5명의 실사용자 인터뷰 또는 본인 dogfooding 로그에서 "6축 축별 실제 통증" 관찰 증거 수집
- 재검증 결과가 **전제를 훼손하지 않을 때만** W1 착수. 훼손 시 primary differentiator를 `개인화 컴파운딩`(유일하게 구체적 메카닉을 가진 항목)으로 좁혀 재스코프.

---

### P0-4. Acceptance Criteria에 2차 릴리스 항목이 섞여 있음
**페르소나**: scope-guardian F-01 + F-03 + F-06
**증거**:
- §10 AC 6번: `"qa-judge 회색지대 자동 Consensus 동작 (Dec 11)"`
- §2.2 결정 #11 & §7 2차 릴리스 계획: Consensus 회색지대 자동은 **~W12 2차 릴리스**로 명시적 연기
- §10 AC 8번: `".claude/memory/ 로컬 + ~/.claude/memory/ 글로벌 전환 옵션 (Dec 12-a)"` — W5 로드맵 산출물에 없음
- §10 AC 10번: `"/orchestrate 단일 완결형 B 동작 ... (Dec 14)"` — §2.1 #3에서 오케스트레이션은 secondary('2차')로 분류

**왜 P0**: "단일 완결형 MVP" 원칙(§1)과 직접 충돌. 이 상태로 W8 배포하면 (a) AC 미달로 미배포, (b) AC 통과를 위해 2차 기능을 급조 — 둘 다 잘못된 결과.

**구체적 수정 제안** — §10 Acceptance Criteria를 다음으로 재구성:
```markdown
## 10. 성공 기준 (MVP, W8 기준)

### 10.1 기능 AC (Hard Gate)
- [ ] .claude-plugin/plugin.json + marketplace.json 설치 성공 (외부 의존 0)
- [ ] /brainstorm·/plan·/verify·/compound 4개 스킬 호출 가능 
      (※ /orchestrate는 10.2로 이동)
- [ ] 각 스킬 validate_prompt 자기검증 통과율 ≥ 90% (KU-1)
- [ ] description 한·영 병기 트리거 영어만과 동등 (KU-2)
- [ ] 승격 게이트 오검지 < 20% (KU-3)
- [ ] 세션 JSONL 파서가 3가지 컴파운딩 트리거 모두 감지 (MVP: 감지만. 자동 Consensus는 2차)
- [ ] README + README.ko.md 이중 + 한·영 description 실증

### 10.2 Stretch (W8 목표, 미달 시 2차로 연기)
- [ ] /orchestrate 단일 완결형 B 동작 (내부 6축 순차)
- [ ] .claude/memory/ 글로벌 전환 옵션

### 10.3 2차 릴리스 (~W12)로 명시 연기
- qa-judge 회색지대 자동 Consensus
- /orchestrate C (외부 플러그인 감지 위임)
- skill-rules.json 이전 검토
```
- §9 Non-Goals에 위 연기 3항목을 명시 추가 (Scope-guardian F-08).

---

### P0-5. JSONL 세션에 포함된 시크릿/PII의 redaction 부재
**페르소나**: security-lens F-01 + F-02
**증거**: §2.2 #12-a (글로벌 메모리 옵션), §5 `extract-session.sh`. 문서 전체에 "redaction", "sanitization", "secret scanning" 언급 0회.

**왜 P0**: 사용자는 대화 중 API 키/DB URL/토큰을 **평소대로** 타이핑한다. extract-session이 JSONL 발화를 `.claude/memory/tacit/`로 promotion하는 순간 평문 저장 → git push되면 공개 유출. 글로벌 모드에서는 Project A → Project B로 시크릿 교차 오염.

**구체적 수정 제안**:
- §4 비기능 또는 §5 `scripts/extract-session.sh` 설명에 명시:
  ```
  secrets 검사 게이트: memory 쓰기 전 필수 단계
  - 정규식 패턴 리스트(AWS/GCP/GitHub/Slack/JWT/DB URL/Bearer token) 매칭 시 해당 턴 전체 드롭
  - (선택) detect-secrets/trufflehog을 선택적 의존으로 지원
  - 드롭된 턴 수는 MEMORY.md에 {redacted: N} 형태로만 기록, 원문 저장 금지
  ```
- §2.2 #12-a 글로벌 옵션에는 추가 조항: "글로벌 memory는 기본 비활성. 활성화 시 프로젝트 ID 태그 필수 + 승격 게이트에서 전체 원문 공개 표시."

---

### P0-6. 승격 게이트(Promotion Gate) UX 전원 미정의
**페르소나**: design-lens F1 + security F-03 + coherence F004
**증거**: §2.1 #6, §4, §3.1 #4 — 모두 "승격 게이트 통과" 언급하지만 어디서, 어떻게 사용자가 승인/거부하는지 명세 0. KU-3(오검지 < 20%)도 게이트 UX 정의 없이는 측정 불가.

**왜 P0**: 오염 방지의 **유일한** 차단 메카닉인데 구현자별 해석 가능. "명시적 승인"이 버튼 한 번 클릭이면 consent fatigue로 rubber stamp 됨 (HCI classic failure mode).

**구체적 수정 제안** — §3에 신규 §3.4 추가:
```markdown
### 3.4 승격 게이트 상세 사양

**트리거**: /compound 수동 호출 또는 자동 트리거(3회 반복/틀렸다/session-wrap) 감지 시

**단계**:
1. 후보 생성: correction-detector 또는 패턴 감지기가 candidate 목록 작성
2. Evaluator 점수: qa-judge 호출 → 점수 ∈ [0.0, 1.0]
3. 자동 판정:
   - 점수 ≥ 0.80: "자동 승격" 큐로
   - 점수 ≤ 0.40: 자동 기각 (corrections/_rejected/에 참고용 보존)
   - 0.40 < 점수 < 0.80 (회색지대): Consensus 재검증 (2차 기능; MVP는 수동 승격으로 fallback)
4. 사용자 확인 (MVP는 모든 승격 케이스에 대해):
   - **표시 내용**: 전체 원문 + 저장 경로 + 소스 JSONL 턴 timestamp
   - 응답: [y=승인 / N=거부 / e=수정 후 승인 / s=건너뛰기]
5. 저장: 승인 시에만 .claude/memory/{tacit|corrections|preferences}/ 기록
6. 거부 이력: corrections/_rejected/에 기록 (과적합 감지 KU-5 입력으로 사용)

**Consent fatigue 완화**:
- 세션 종료 시(Stop hook) 일괄 제시 (mid-session 인터럽트 최소화)
- 동일 패턴 3회 연속 거부 시 해당 detector 임시 비활성화 제안
```

---

### P0-7. KU 실험의 오너십·실행 시점 공백
**페르소나**: adversarial (experiment_ownership_gap) + feasibility F5 + scope-guardian F-05
**증거**:
- §8: `"각 KU는 ... MVP 출시 전 완료 대상"`
- §10: KU-1·KU-2·KU-3이 하드 AC로 지정됨
- §7 로드맵 W1~W8에는 KU 실행 주차 없음
- §11 열린 주제: `"KU 실험 실행 계획 (수동 vs 자동)"`이 "/ce-plan에서 다룰 것"으로 연기
- KU-1은 "hook 발동률"(기계적)과 "Claude가 실제 응답"(행동적)이 섞여 있음. hoyeon validate-output.sh는 advisory만 출력하므로 "강제"가 불가능한 soft metric.

**왜 P0**: 릴리스를 하드 블록하는 지표인데 (a) 데이터 수집 방법, (b) 샘플 수, (c) 실행 주체, (d) 실패 시 차단/비차단 결정이 전원 미정. 실제로는 W8 배포가 "KU 미완료 상태로" 강행되거나, "/ce-plan에서 알아서 처리" 로 표류하는 구조적 위험.

**구체적 수정 제안**:
- §7 로드맵에 **W7.5 (KU 수행 & 하드닝) 전용 주차** 삽입. 기존 W8을 W9로 밀거나 범위 축소.
- §8 테이블에 컬럼 3개 추가:
  ```
  | KU | 실험 | 성공 기준 | 데이터 소스 | 샘플 수 | 실패 시 |
  | KU-1a | hook 발동률 | ≥ 99% | 훅 로그 | 자동 계측 (W4-W7 전체) | P0 블록 |
  | KU-1b | 실제 응답률 | ≥ 90% | 별도 judge 에이전트 + fresh context | 스킬당 20건 | P1 경고 |
  ...
  ```
- KU-4(Consensus 편향)·KU-5(oscillation 과적합)는 **2차 릴리스 KU로 이동**. 기술적 의존성이 2차 기능이므로.

---

### P0-8. Bash 훅들의 command injection 공격면 + SessionStart 페이로드 무결성
**페르소나**: security-lens F-04 + F-05 + F-06
**증거**: §5의 `validate-output.sh`·`drift-monitor.sh`·`correction-detector.sh`가 모두 LLM/유저 입력을 처리. `session-start` 훅은 `skills/using-harness/` 페이로드를 system-prompt 권한으로 주입하는데 해당 파일 무결성 검증 없음.

**왜 P0**: 
- `correction-detector.sh`는 "틀렸다" 문자열 매칭으로 트리거 — 유저가 `"틀렸다; rm -rf ~/.claude/memory"` 입력 + 스크립트가 값을 따옴표 없이 보간 → 임의 실행
- using-harness.md가 악성 PR로 오염되면 **모든 세션에서 시스템 프롬프트 권한으로 prompt injection 실행**

**구체적 수정 제안**:
- §5 또는 §4에 **"훅 스크립트 보안 제약"** 박스 추가:
  ```
  - 모든 bash 훅은 외부 입력을 "$var" 쌍따옴표로만 사용, command argument로 직접 보간 금지
  - eval 사용 금지
  - 파일명 생성 시 [a-zA-Z0-9_-] 화이트리스트로 slug 변환
  - using-harness.md 및 SessionStart 페이로드는 plugin.json에 SHA256 해시 고정
  - 세션 시작 시 해시 불일치 감지하면 주입 거부 + 사용자에게 경고
  ```
- W1 스캐폴드에 해시 검증 테스트 케이스 포함.

---

### P0-9. §11 "열린 주제"에 설계 결정이 섞여 /ce-plan으로 떠넘겨짐
**페르소나**: adversarial (phase_offloading_risk)
**증거**: §11의 6개 항목 중:
- `"각 스킬의 SKILL.md 프론트매터 정확한 필드"` — §2.2 #10 "하이브리드 포맷" 결정의 **실체**
- `"훅 스크립트 bash 실제 구현"` — 구현 태스크처럼 보이지만 P0-1(언어 제약), P0-8(보안 제약)이 해소돼야 분해 가능
- `"KU 실험 실행 계획 (수동 vs 자동)"` — P0-7 참조
- `"오픈소스 라이선스 선택"` — §6 포팅 자산의 상류 라이선스 호환성(MIT/Apache-2.0/GPL 전염)을 사전 결정해야 포팅 자체가 성립

**왜 P0**: L4의 자기선언 `"/ce-plan 입력으로 바로 쓰기 위한 단일 진실 소스(single source of truth)"`와 정면 상충. /ce-plan은 구현 분해 단계이지 추가 설계 라운드가 아니다.

**구체적 수정 제안** — §11을 두 섹션으로 분리:
```markdown
## 11. 설계 미결 (본 문서 업데이트 필요 — /ce-plan 입력 전)
- 프론트매터 필드 (스킬 5개 각각의 name/description/when_to_use/input/output 확정)
- 오픈소스 라이선스 선택 (포팅 자산 상류와 호환성 매트릭스)
- 훅 스크립트 보안 제약 (P0-8 참조)
- KU 실험 실행 계획 (주체·샘플 수·실패 시 결정)

## 12. Phase 4 이관 (태스크 분해)
- W1~W8 주차별 구현 태스크 분해
- marketplace.json 카테고리·태그 세부
- 훅 스크립트 구현 코드 작성
```

---

## 2. P1 Findings — 본 문서 업데이트 권장

### P1-1. "차별점 4개" = 사실상 0개 — 포지셔닝 미결정
**페르소나**: product-lens F2
**핵심**: §2.1 #3 `"오케스트레이션(2차)·6축 강제(1차)·개인화 컴파운딩(1차)·한국어 최적화(2차)"` — 4개 나열은 저자가 포지셔닝 선택을 안 했다는 신호. 사용자는 "프레임워크"를 사지 않고 "결과"를 산다.

**수정 제안**: §1 TL;DR 상단에 **one-sentence positioning** 추가:
> "harness는 [구체 사용자] 가 [구체 통증] 을 해결하고 싶을 때, [핵심 메카닉 1-2개] 로 [구체 결과] 를 얻는 플러그인이다. 기존 [CE/hoyeon] 와는 [구체 차이] 에서 구별된다."

가장 구체적인 메카닉이 "개인화 컴파운딩"이면 primary를 여기로 좁히고, "6축"은 내부 설계 휴리스틱으로 강등 (사용자 대면 카피에서 제거).

---

### P1-2. OSS 배포 타겟 ↔ "단일 완결형 MVP" 상충
**페르소나**: product-lens F3 + F6 + adversarial (contradiction_in_strategy)
**핵심**: OSS Claude Code 생태계는 composability로 가고 있음 (CE의 `"cross-skill 참조 금지"` 정책이 증거). harness는 `"반대 정책"` 을 Non-Goal #4에 각주 한 줄로 처리하고 1차는 5-스킬 monolith로 배포. 사용자가 `/verify` 만 떼어 쓰고 싶어도 불가.

**수정 제안**:
- §1 TL;DR 하단에 **"composability 선택"** 박스 추가:
  ```
  각 스킬의 독립 사용 가능성:
  - /brainstorm, /plan, /verify는 단독 설치·사용 가능 (MEMORY.md 없어도 동작)
  - /compound, /orchestrate는 다른 스킬 결과물을 전제로 함
  ```
- MVP 성공 기준에 "1개 스킬만 사용한 사용자 시나리오가 end-to-end 가치를 제공" 추가.

---

### P1-3. 타겟 사용자 이중성 (글로벌 OSS vs 한국 개발자)
**페르소나**: product-lens F3
**핵심**: `"오픈소스 배포"`(글로벌) + `"한국어 UX"`(한국) + `"본문/프롬프트/SKILL.md 영어 고정"` = 두 청중 모두 반쪽 만족. KU-2 성공 기준 "영어만과 동등"은 병기가 순이득 아님을 자인한 상태.

**수정 제안** — 한쪽 선택:
- **(A) 한국 우선**: 내부·트리거·README.ko를 primary. 글로벌은 courtesy 영어 번역. §2.1 #4 target을 "한국 Claude Code 사용자"로 명시.
- **(B) 글로벌 우선**: description에서 한국어 제거. README.ko는 courtesy. §3.3 한국어 UX 전체를 2차로 연기.
- **하이브리드(현재) 유지 시**: KU-2를 "한국어 정확도 ≥ X% AND 영어 저하 ≤ Y%pt" 양방향 기준으로 재정의.

---

### P1-4. /orchestrate MVP=B의 실질 가치 미증명
**페르소나**: product-lens F8 + scope-guardian F-03
**핵심**: `/orchestrate` MVP는 `"4개 스킬 순차 실행"` — 사용자가 수동으로 4개를 순차 호출하는 것과 구별되는 구체 가치가 문서에 없음. 오케스트레이션은 secondary인데 MVP AC에 하드로 걸려 있음.

**수정 제안**: §3.1 user story #5에 2열 비교표 추가:
```
| 상황 | /orchestrate topic | 수동 4개 호출 |
| 컨텍스트 전달 | 스킬 간 산출물 자동 참조 | 사용자가 매번 경로 명시 |
| 실패 복구 | /verify 실패 시 자동 /plan 재시도 (Ralph Loop) | 사용자 수동 재시도 |
| 중간 산출물 검토 | [정의 필요] | 가능 |
```
3개 차별점을 구체로 쓸 수 없으면 **/orchestrate를 MVP에서 cut하고 2차 C와 함께 등장** 시키는 것을 권장.

---

### P1-5. "6축 강제" ↔ Non-Goal #7 운영 모순
**페르소나**: adversarial (user_behavior_assumption) + design-lens F10
**핵심**: §2.1 #2 "6축 강제"(primary) ↔ §9 #7 `"체크리스트식 6축 준수 (실효성 지표 없는 형식 포함)"` 배제. 운영상 유저가 단순 질문에도 6축을 요구받으면 "플러그인이 내 워크플로우를 재단한다"는 저항.

**수정 제안**: §3 또는 §4에 **"강제 적용 범위"** 명시:
```
6축 강제는 다음 컨텍스트에서만 활성:
- /plan, /verify, /orchestrate 호출 시 (기본 ON)
- /brainstorm, /compound는 자연 대화 (적용 안 함)
- 일반 대화·짧은 Q&A는 적용 안 함

축별 생략 허용:
- 이미 완료된 축(예: 계획이 제공된 상태의 /verify)은 skip
- --skip-axis N 이스케이프 해치 제공
```
Non-Goal #7이 "형식 체크"를 배제한 것을 운영으로 살리려면 "실효성 지표" (축 통과가 실제 산출물 품질과 상관되는지)를 KU에 추가.

---

### P1-6. 정체성 중복 — CE/hoyeon와 사용자 관점 차별점 모호
**페르소나**: product-lens F4
**핵심**: 5개 스킬 모두 "superpowers + CE + hoyeon + ouroboros + p4cn 조각 합성". 원본 콘텐츠는 (a) 6축 라벨 + (b) correction-detector 2개 정도. 사용자 입장에서 "왜 CE + hoyeon 같이 쓰지 않고 harness를?" 답이 없음.

**수정 제안** — §1 또는 §2 상단에 **"왜 새 플러그인인가 (vs. 기존 기여)"** 섹션 추가. 3개 진정 신규 메카닉(correction-detector / 승격 게이트 / JSONL 기반 컴파운딩 트리거)에 대해:
```
| 메카닉 | 상류 PR 가능? | 상류 PR 공수 vs harness 공수 | 결정 |
| correction-detector | hoyeon 기여 가능 | 1주 vs 2주 harness 부담 | ? |
| 승격 게이트 | CE 기여 가능 | 2주 vs 3주 | ? |
| JSONL 컴파운딩 | p4cn 기여 가능 | 1주 vs 2주 | ? |
```
상류 기여 경로가 < 30% 공수로 비슷한 리치를 확보하면 그것이 정답. harness는 "6축 메타 프레임 자체가 상품" 으로 논증될 때만 정당화됨 (→ P0-3 재검증 결과와 연결).

---

### P1-7. "틀렸다" 감지 false positive 폭증 위험
**페르소나**: adversarial (false_positive_risk_unbounded) + design-lens F3
**핵심**: 문자열 매칭은 (a) 3인칭 서술(`A가 틀렸다`), (b) 코드 리뷰(`이 assertion은 틀렸다`), (c) 반어법, (d) 영어 사용자(`you're wrong`), (e) 한국어 어미 변화 — 모두 오검지. KU-3(게이트 오검지)은 detector 자체의 precision을 측정하지 않음.

**수정 제안**:
- §5 `correction-detector.sh`를 다음 중 선택으로 명세:
  - **(A)** 키워드+문맥 휴리스틱 (직전 assistant 턴의 답변 내용을 부정하는 문장인지 확인)
  - **(B)** 가벼운 LLM 분류 호출 (Haiku 1 call/detection, 비용 < $0.001)
  - **(C)** 감지 시 즉시 유저에게 "이것을 correction으로 기록할까요? [y/N]" 확인 강제
- KU에 `correction-detector 단독 precision ≥ 0.7 AND recall ≥ 0.6` 추가.

---

### P1-8. Consensus 임계값 0.40/0.80 cargo-cult 의심
**페르소나**: adversarial (magic_number_unjustified)
**핵심**: qa-judge에서 그대로 상속. 우리 도메인(6축 + 한국어 UX + 포팅 스택)에서 최적이라는 증거 없음. 점수 분포가 우측 치우치면 대부분 Consensus 없이 통과 → 차별점 #3 품질 상한 제약.

**수정 제안**: W7.5 KU 주차에 **KU-0** 추가:
```
KU-0: qa-judge 점수 분포 측정
- 샘플: MVP 스킬 호출 100건
- 측정: 점수 histogram
- 결정: 0.40/0.80 대신 하위 20% / 상위 20% 분위수로 재조정
- 노출: 임계값을 .claude-plugin/config.json에 사용자 재정의 가능하게
```

---

### P1-9. W4-W6 일정 언더스코프
**페르소나**: feasibility F6
**핵심**:
- W4 = hoyeon 6 에이전트 포팅 + Ralph Loop + qa-judge + 회색지대 처리 (실제로는 다-주 작업)
- W6 = 신규 correction-detector + CE 5-dim overlap + ouroboros 병리 감지 (레퍼런스 구현 없는 신규 항목 다수)
- KU 실행 주차 0주

**수정 제안** — §7 로드맵 분할:
```
W4a: verify 6-에이전트 scaffolding (stub 응답)
W4b: Ralph Loop + qa-judge JSON scoring + 회색지대 dispatch
W5 : 메모리 + 승격 게이트 (UX 포함, P0-6)
W6a: /compound 트리거 3종 감지
W6b: correction-detector + overlap 감지
W7 : /orchestrate B (내부 순차)
W7.5: KU 실행 + 하드닝 (신규)
W8 : 문서화 + OSS 배포
```
기존 8주 → 9주로 늘어남. 아니면 W6b / /orchestrate 중 하나를 2차로 이동.

---

### P1-10. 포팅 자산 4곳 상류 sync 전략 공백
**페르소나**: adversarial (maintenance_burden_unaddressed) + feasibility F10
**핵심**: §6의 7개 P0 자산은 hoyeon/ouroboros/p4cn/superpowers 4곳에서 fork-and-own. 상류 버그 수정·개선 자동 수혜 없음. 2차의 `/orchestrate C`(외부 위임)가 실현되려면 포팅 버전과 원본 API 호환성 유지 필수 — 현재 계획에 없음.

**수정 제안**: §6 테이블에 컬럼 추가:
```
| # | 자산 | 원본 | 우리 위치 | 상류 커밋 해시 | sync 주기 |
| 1 | verify 6-에이전트 | hoyeon@abc1234 | agents/verify/ | abc1234 | 분기별 |
```
W8 이전에 **라이선스 호환성 매트릭스** 작성 (MIT/Apache-2.0/GPL 전염 여부 — Non-Goal #1 연관).

추가로 §5 `hooks.json`의 다중 이벤트 훅 스크립트 순서(PostToolUse에 validate-output + drift-monitor + correction-detector 3개 공존 시) 명세.

---

## 3. P2 Findings — 형식·명확성

| # | 이슈 | 섹션 | 수정 |
|---|------|-----|------|
| P2-1 | `keyword-detector.sh` vs `.py` 불일치 (coherence F001과 연결) | §5 | P0-1 해결 시 자동 해소 |
| P2-2 | `evaluator/` 소문자 vs `Evaluator` 대문자 드리프트 | §5 line 134 | `evaluator/` 소문자로 통일 (파일 시스템 관례) |
| P2-3 | `Consensus` vs `consensus` 대소문자 드리프트 (L47, L61, L74, L103) | 전역 | 대문자 `Consensus` 로 통일 + §2.3 또는 용어집 추가 |
| P2-4 | §2.2 `"(5가지)"` but 6개 결정 (#10/11/12/12-a/13/14) | §2.2 header | `"(6가지)"` 로 변경 또는 #12-a → #12.2 로 리네이밍 후 `(5가지 + 1 부결정)` |
| P2-5 | §3.1 `"브레인스토밍→계획→실행→검증→컴파운딩"` 5단 중 "실행" 스킬이 없음 | §3.1 line 76 | `"/plan 완료 후 사용자 실행 작업 진행 → /verify"` 로 명확화 또는 /execute 스킬 추가 여부 결정 |
| P2-6 | 로드맵 W3/W7/W8에 `Dec 10/13/14` 섞여 있으나 문서일자 2026-04-19 | §7 | 주차 기준 날짜(2026-04-21 시작 W1)로 통일, Dec 표기 제거 |
| P2-7 | `/compound` 명칭이 비전문가에게 "컴파운딩"이 무엇인지 불투명 | §3.2 | 테이블에 한 줄 사용자-향 설명 컬럼 추가. `/compound` → "암묵지·수정사항을 영구 메모리에 저장" 병기 |
| P2-8 | 승격 게이트 단계(`검증 → 유저 승인 → 저장`)의 구체 절차 미정 | §3.1 #4 | P0-6의 §3.4로 해결 |

---

## 4. P3 Findings — 사소

| # | 이슈 | 수정 |
|---|------|------|
| P3-1 | §7 로드맵에서 /brainstorm을 P1으로 표기했으나 §3.1에서는 gateway 스킬 | `P0` 재분류 또는 "second implementation priority" 주석 |
| P3-2 | §9 Non-Goals에 2차 릴리스 항목(Consensus 자동/orchestrate C/skill-rules.json) 미포함 | P0-4 해결 시 해소 |
| P3-3 | `/verify --deep`, `--axis N` 플래그 동작 미정의 | §3.2 플래그별 비용 영향·N 유효값 명시 |

---

## 5. 페르소나별 Residual Risks (미확정 위험)

- **feasibility**: bilingual description → skill-rules.json 마이그레이션이 hoyeon-only 인프라에 의존. Claude Code 네이티브 지원 여부 확인 필요.
- **adversarial**: `/orchestrate` 외부 플러그인 감지 메커니즘 (marketplace cache 스캔? SlashCommand probe?)이 2차 계획에 없어 "B→C 전환"이 실현 가능한지 불명.
- **design-lens**: 새 세션 시작 시 메모리 자동 주입을 사용자가 인지하지 못하면 "Claude가 왜 이전 컨텍스트를 아는가?" 불신 유발 가능. 세션 시작 알림 필요.
- **product-lens**: 포스트 릴리스 adoption signal (외부 설치 수, 비저자 correction 발생)이 AC에 없음. 메카닉은 통과하지만 "아무도 안 씀"이 catch되지 않음.
- **security-lens**: 2차 Consensus 3-model 호출 시 credential 관리 계획 없음. marketplace.json/plugin.json 서명·해시 검증 없음.

---

## 6. 권고 사항

### 즉시 실행 (이번 주 내)
1. **P0-3 (프리미스 재검증)** → W0 하루 투입. 결과에 따라 primary differentiator 재정의 가능성 고려.
2. **P0-1 (언어 제약)** → 본 문서에 jq/awk 허용 명시 또는 Python 허용으로 결정.
3. **P0-4 (AC ↔ 2차 혼재)** → §10을 10.1/10.2/10.3 3단 구조로 재작성.
4. **P0-9 (§11 정리)** → 설계 미결 vs Phase 4 이관 분리.

### /ce-plan 착수 전 (다음 주)
5. **P0-2, P0-5, P0-6, P0-7, P0-8** 을 본 문서에 구체 사양으로 반영.
6. **P1-1, P1-2, P1-3** 포지셔닝/타겟 결정.

### 2차 릴리스 기획 시
7. P1-4 (/orchestrate 실질 가치), P1-6 (CE/hoyeon 기여 경로), P1-10 (상류 sync) 을 별도 설계 라운드.

### 지금 `/ce-plan` 하면?
P0 9건이 미해결 상태로 구현 태스크 분해에 들어가면, 태스크 중 다수가 실제로는 **설계 결정**을 포함하게 된다. 구현자(또는 서브에이전트)가 임의 해석 → 일관성 없는 구현. 본 리포트의 P0만이라도 먼저 해결 후 /ce-plan 권장.

---

*Generated by compound-engineering:document-review — 7 personas, 70 raw findings → 30 synthesized.*

# 유저 판단 5건 결정 결과

> **세션**: 2026-04-19 AskUserQuestion 대화 (총 11개 질문)
> **입력**: `.claude/plans/prompts/user-decisions-prompt.md`
> **연결**: `04-planning/section11-promotion-tracker.md` §2·§4·§5·§6·§7
> **범위**: 본 문서는 **결정만** 기록. `final-spec.md` §11 → §N 승격은 별도 이터레이션에서 진행.

---

## 1. 보안 범위 (§11-2)

### 결정

- **secrets redaction 정규식 리스트**: 범용 7종 + 로컬 확장 훅 (Recommended 채택)
  - 기본 탑재: AWS · GCP · GitHub · Slack · JWT · DB URL · Bearer token
  - 확장: `secrets-patterns.local.json` 로드 훅 — 사내 커스텀 패턴 추가 가능
- **외부 secrets 탐지 도구 의존**: 불허 — bash+jq 정규식만 (Recommended 채택)
  - `detect-secrets` / `trufflehog` 등 Python/Node 외부 도구 금지
- **글로벌 `~/.claude/memory/` 기본 모드**: 기본 OFF · opt-in (Recommended 채택)
  - 프로젝트 로컬 `.claude/memory/`만 기본 활성
  - 글로벌은 플러그인 설정으로 명시 활성 + 프로젝트 ID 태그 필수

### 근거 및 Trade-off

- **근거**
  - v2 §4.1 P0-1 런타임 제약 (bash+jq만) 준수 — 외부 도구는 설치 부담·의존성 전파 리스크
  - v2 §9.2 #11 "글로벌 메모리 완전 교차 오염 방지"는 MVP 밖 (2차) — 기본 OFF가 v2 원칙 부합
  - tracker §2 위험 플래그: secrets 유출 시 컴파운딩 저장소 영구 오염
- **Trade-off**
  - 범용 7종만: 단순·일관 / 사내 확장 불가 → fallback 훅으로 양립
  - 외부 도구 불허: 설치 0·P0-1 준수 / 정밀도는 자체 정규식에 한정
  - 글로벌 OFF 기본: 교차 오염 리스크 0 / 크로스 프로젝트 학습 기회↓ (opt-in으로 보완)

### v2 스펙 반영 위치

- §11-2 → §4.3 확장 (신규 §4.3.1~§4.3.4) 승격 예정 (W4 이전, T-W4-PRE-01)
- 신규 필드 명세:
  - `plugin.json`에 `secrets_patterns_builtin`(7종 해시) + `secrets_patterns_local_path` 옵션
  - 글로벌 메모리 활성 플래그(기본값 `false`) + 프로젝트 ID 태그 스키마

---

## 2. KU 샘플 수·정책 (§11-4)

### 결정

- **각 KU(KU-0/1/2/3)별 샘플 수**: **20 샘플** (Recommended 채택)
  - KU-2는 A/B 양방향 기준(한·영) — 실효 샘플 40건
- **Hard AC 미달 시 정책**: **재시도 1회 후 차단** (Recommended 채택)
  - 1차 미달 → 스키마/프롬프트 튜닝 → 재측정 → 2차 미달 시 W8 릴리스 차단
- **KU-1b judge 에이전트 (validate_prompt 실제 응답률) 평가 모드**: **자동 LLM judge 서브에이전트** (Recommended 채택)
  - 프롬프트 기반 판정 에이전트 · 기대 출력 스키마 명세 · CI 재실행 가능
  - 모델 편향 교차 검증은 KU-4(2차 릴리스)로 위임

### 근거 및 Trade-off

- **근거**
  - 이진 판정 95% CI 폭: n=10이면 ±30%p, n=20이면 ±22%p, n=30이면 ±17%p — 20이 MVP 실행 가능성·통계 유의성 타협점
  - tracker §4 "더 엄격한 통계적 유의 시 20 이상 권장" 정합
  - 재시도 1회는 tracker §4 기본안 — 품질 시그널 유지 + 일정 유연성
  - 자동 judge는 reproducibility 확보 및 W7.5 자동화 스크립트(T-W7.5-01~04)와 결합 용이
- **Trade-off**
  - 20 vs 10: 신뢰도+8%p / 실행 부담 2× (4×20=80건)
  - 20 vs 30: 실행 부담 50%↓ / 신뢰도 -5%p
  - 재시도 1회 후 차단 vs 베타 태그: 품질 명확성↑ / 부분 릴리스 유연성↓
  - 자동 judge vs 수동: reproducibility↑·편향 위험 (KU-4로 교차 검증)

### v2 스펙 반영 위치

- §11-4 → §8 KU 테이블 확장 (샘플 수·자동/수동·실패 정책 컬럼 추가) 승격 예정 (W7.5 이전, T-W7.5-PRE-01)
- 신규 §8 말미 "§11-4 KU 실행 스펙" 소절
- §10.1 Hard AC에 "재시도 1회 후 차단" 정책 반영

---

## 3. 6축 강제 적용 범위 (§11-5)

### 결정

- **6축 강제 활성 스킬**: `/plan` · `/verify` · `/orchestrate` (Recommended 채택)
  - `/brainstorm` · `/compound`는 자연 대화 모드 · 6축 힌트만 참조 (강제 OFF)
  - 일반 Q&A는 6축 적용 완전 제외
- **`--skip-axis N` 이스케이프 해치**: 전 축 허용 · **검증 축(축 5) 스킵 시 강경 경고** (Recommended 채택)
  - 스킵 시 stderr 경고 + 스킬 응답 상단 경고 배너
  - 검증 축 스킵은 특별 플래그 조합 요구 (`--skip-axis 5 --acknowledge-risk`)
- **"실효성 지표" KU (6축 통과 ↔ 산출물 품질 상관)**: **MVP 연기 · 2차 릴리스** (Recommended 채택)
  - W8 릴리스 메모에 "2차에서 반드시 측정" 명시
  - MVP 기간 동안 dogfooding 로그 수집하여 2차 KU 설계 input으로 활용

### 근거 및 Trade-off

- **근거**
  - v2 §3.1 유저 스토리 기반 4개 스킬 중 `/brainstorm`·`/compound`는 자유발화 성격 — 강제 시 UX 저항
  - tracker §5 기본안과 일치 · 중심축(구조·계획·실행·검증) 명확화
  - 검증 축 스킵 시 강경 경고는 `/verify` 스킬의 핵심 가치 보호
  - 실효성 KU 연기는 v2 §9.1 #7 충족 시점을 2차로 미루는 것이나 W7.5 부담(4×20=80건) 이미 포화
- **Trade-off**
  - 3개 스킬 ON vs 5개 전체: 중심축 명확 / 자연 대화 유연성 유지
  - skip 허용 vs 불허: 실사용 유연성 / 강제성 희석 (검증 축 특수 경고로 보완)
  - 실효성 KU 연기 vs 추가: W7.5 부담 관리 / v2 §9.1 #7 자기모순 2차까지 잠재 (릴리스 노트에 명시)

### v2 스펙 반영 위치

- §11-5 → §3 신규 소절 "§3.5 6축 강제 적용 범위" 승격 예정 (W8 이전, T-W8-PRE-01)
- §9.1 #7 "체크리스트식 6축 준수"에 2차 실효성 KU 각주 추가
- §10.3 2차 릴리스 항목에 "실효성 지표 KU" 등재

---

## 4. 라이선스 선택 (§11-6)

### 결정

- **본 플러그인 최종 라이선스**: **MIT** (Recommended 채택)
  - 전제: 6개 상류 라이선스 스캔 결과 전부 MIT/Apache-2.0 (시나리오 A)
  - 시나리오 B(일부 GPL 발견) 시 해당 자산 포팅 제외 + MIT 유지로 대체 경로
- **기여 수용 정책 (CLA)**: **DCO (Developer Certificate of Origin) sign-off** (Recommended 채택)
  - `git commit -s` 필수 · CLA 작성·서명 불필요
  - 초기 커뮤니티 성장 저해 방지
- **상류 sync 주기 자동화**: **수동 · 분기/반기 차등** (Recommended 채택)
  - 핵심 상류(hoyeon · ouroboros): 분기 1회
  - 중간 상류(p4cn · superpowers): 반기 1회
  - 약한 상류(CE · agent-council): 연 1회
  - 자동 CI cron은 2차 릴리스

### 근거 및 Trade-off

- **근거**
  - tracker §6 기본안 시나리오 A 권장
  - porting-matrix §4.2 시나리오 A에서 MIT 권장 (Apache-2.0 NOTICE 조항 회피)
  - porting-matrix §5 차등 sync 주기 표 기반 의존 강도 매핑
  - DCO는 Linux Kernel·Git 등 대형 OSS 프로젝트 표준 — 법적 최소 보호 + 기여 장벽↓
- **Trade-off**
  - MIT vs Apache-2.0: permissive 극대화·NOTICE 면제 / 특허 방어 조항 포기
  - MIT vs GPL-3.0: Claude Code 생태계 조화 / 파생물 보호 포기
  - DCO vs CLA: 기여 유입↑ / 저작권 분쟁 방어 약함
  - sync 수동 vs 자동: 유지보수 제어↑ / 상류 변경 감지 지연 (2차 자동화 전환 여지)

### v2 스펙 반영 위치

- §11-6 → §6 테이블 확장 (상류 커밋 해시·sync 주기 컬럼 추가) + 신규 §6.1 "라이선스 호환성" + §6.2 "상류 sync 주기" 승격 예정 (W8 이전, T-W8-PRE-02)
- `LICENSE` 파일 (MIT) + `NOTICES.md` 초안 작성
- `CONTRIBUTING.md`에 DCO sign-off 절차 명시
- porting-matrix.md §4.1 6개 상류 라이선스 TBD → 실측 스캔 후 SPDX identifier 확정 (선행 작업)

### 조건부 대안 (시나리오 B·C 발생 시)

- 시나리오 B (일부 GPL 전염): GPL 상류 자산 포팅 제외 + 대체 경로 수립 (알고리즘만 참조)
- 시나리오 C (라이선스 부재): 해당 상류 포팅 불가 + 원저자 연락 시도 + 실패 시 차별화 재평가

---

## 5. 포지셔닝 1문장 (P1-1)

### 최종 문장

> **"harness는 Claude Code로 반복 작업하는 개발자가 세션마다 같은 실수를 반복하고 암묵지가 휘발하는 문제를 해결하고 싶을 때, 승격 게이트와 6축 검증 루프로 개인화된 컴파운딩 메모리를 누적하는 플러그인이다. 기존 CE·hoyeon과는 '유저 승인 게이트를 통과한 학습만 영속 저장한다'는 점에서 구별된다."**

### 대안 문장 (검토됨, 기각 이유 포함)

- **B: "하네스 6축(구조·맥락·계획·실행·검증·개선)을 구조적으로 강제하는 Claude Code 공용 플러그인"**
  - 기각 이유: review P1-1 요구(구체 사용자·통증·결과) 미충족. "무엇을 해주는 플러그인인지"는 드러나지만 "누가 왜 사는지"가 공백
- **C: "AI 코딩 에이전트의 작업 품질을 6축 메타-프레임워크로 검증하고 컴파운딩하는 플러그인"**
  - 기각 이유: "메타-프레임워크" 추상어가 review P1-1 비판("프레임워크를 사지 않고 결과를 산다")에 정면 재해당
- **단축안**: "harness는 반복 작업에서 암묵지가 휘발하는 개발자를 위해, 승격 게이트로 검증된 학습만 영속 저장하는 Claude Code 플러그인 — CE·hoyeon과 달리 유저 승인 없이는 메모리에 쓰지 않는다."
  - 기각 이유: 최종 선택안의 단축 버전. 필요 시 소셜/짧은 소개용으로 재활용 가능

### 근거 및 Trade-off

- **근거**
  - review P1-1 수정 제안 형식 100% 준수: 사용자·통증·메카닉·결과·차별화 5요소 충족
  - v2 §1 TL;DR의 "암묵지 해소" 핵심 기능을 사용자 통증으로 구체화
  - review F2 지적 "4개 나열 = 포지셔닝 미선택"을 "승인 게이트 컴파운딩" 단일 primary로 좁힘
  - CE(코드 리뷰 중심) · hoyeon(에이전트 체계 중심)과의 실질적 차이 = "유저 승인 게이트"로 명시
- **Trade-off**
  - 길이 2문장 (64단어): 정보 밀도↑ / 읽기 부담 · 단축안 병기로 보완
  - "승격 게이트" 용어 노출: 본 플러그인 고유 메카닉 표면화 / 첫 접촉 사용자는 후속 설명 필요 (README 본문에서 해소)

### v2 스펙 반영 위치

- §11-7 → §1 TL;DR 상단 + README.md 첫 문장 삽입 승격 예정 (W8, T-W8-PRE-03)
- README.ko.md에 대응 한국어 번역 (본 결정문 한국어 원문 활용)
- `marketplace.json` `description` 필드에 단축안 반영 검토

---

## 후속 조치 체크리스트

### v2 스펙 승격 (별도 이터레이션)

- [ ] `final-spec.md` §11-2 → §4.3 신규 §4.3.1~§4.3.4 승격 (W4 이전, T-W4-PRE-01)
  - secrets 정규식 7종 + 로컬 훅 명세 / 외부 도구 불허 원칙 / 글로벌 메모리 기본 OFF 명시
- [ ] `final-spec.md` §11-4 → §8 KU 테이블 확장 + 신규 §8 말미 KU 실행 스펙 소절 승격 (W7.5 이전, T-W7.5-PRE-01)
  - KU별 샘플 수 20 / 재시도 1회 후 차단 정책 / 자동 judge 에이전트 명세
- [ ] `final-spec.md` §11-5 → §3 신규 §3.5 "6축 강제 적용 범위" 승격 + §9.1 #7 각주 + §10.3 실효성 KU 등재 (W8 이전, T-W8-PRE-01)
- [ ] `final-spec.md` §11-6 → §6 테이블 확장 + 신규 §6.1·§6.2 승격 (W8 이전, T-W8-PRE-02)
- [ ] `final-spec.md` §1 TL;DR 상단 + README 첫 문장에 포지셔닝 1문장 반영 (W8, T-W8-PRE-03)

### 선행 실측 작업

- [ ] porting-matrix.md §4.1 6개 상류(hoyeon · ouroboros · p4cn · superpowers · CE · agent-council) 라이선스 실측 스캔 → SPDX identifier 확정 (W8 이전)
- [ ] 시나리오 B·C 발견 시 대체 경로 재수립 (T-W8-PRE-02 역소급)

### 산출물 작성

- [ ] `LICENSE` 파일 (MIT)
- [ ] `NOTICES.md` — 상류 6곳 저작권 고지 일괄 수록
- [ ] `CONTRIBUTING.md` — DCO sign-off 절차 + `git commit -s` 예시
- [ ] `secrets-patterns.local.json` 스키마 문서 (opt-in 사내 확장 가이드)
- [ ] README 템플릿 작성 시 포지셔닝 1문장 상단 삽입 (W8, T-W8-01·T-W8-02)

### Tracker 갱신 제안 (다음 이터레이션에서 반영)

- [ ] `section11-promotion-tracker.md` §2 "유저 판단 요청 사항" → "결정 완료" 체크
- [ ] `section11-promotion-tracker.md` §4 "유저 판단 요청 사항 1·2" → "결정 완료" 체크
- [ ] `section11-promotion-tracker.md` §5 "유저 판단 요청 사항 1·2·3" → "결정 완료" 체크
- [ ] `section11-promotion-tracker.md` §6 "유저 판단 요청 사항 1·2" → "결정 완료" 체크
- [ ] `section11-promotion-tracker.md` §7 "유저 판단 요청 사항" → "결정 완료" 체크

---

*5건 결정 완료 (AskUserQuestion 11개 질문 · 모두 Recommended 채택). 본 문서는 결정만 기록 · 실제 §11 → §N 승격은 별도 이터레이션에서 진행.*

---
goal: "crucible 근거 자료를 docs/ 폴더 8파일로 분리하고 README는 사용자 중심으로 경량화한다"
slug: "readme-enhancement"
date: "2026-04-20"
parent_seed_id: null
source_requirements: ".claude/plans/2026-04-20-readme-enhancement-requirements.md"
ambiguity_verdict: pass
ambiguity_score: 0.12
constraints:
  - "각 docs/ 파일 ≤ 200 라인 (가독성)"
  - "영어 primary, 필요 시 한국어 병기 (기존 포맷 준수)"
  - "모든 정량 수치는 출처(ouroboros·KU-X·설계 추론) 명시"
  - "synthetic fixture 기반 임을 thresholds.md / faq.md에 명시"
  - "루트 파일(README·CLAUDE·AGENTS·CONTRIBUTING·NOTICES·LICENSE·RELEASE-CHECKLIST) 구조 보존 — 포인터 추가만 허용"
  - "skills/*/SKILL.md 본문 수정 금지 (description 미세 조정 제외)"
  - "새 훅·스크립트 추가 금지 (문서 전용 스프린트)"
  - "bash + jq + yq 외 의존성 금지 (final-spec §4.1)"
acceptance_criteria:
  hard:
    - "AC-H1: docs/ 8개 파일(axes · thresholds · faq · skills/{brainstorm,plan,verify,compound,orchestrate}.md) 모두 존재하고 각 ≤ 200 라인"
    - "AC-H2: docs/skills/*.md 5개가 동일 5-섹션 템플릿(Paradigm · Judgment · Design Choices · Thresholds · References) 준수"
    - "AC-H3: README.md·README.ko.md 6축 matrix 섹션이 docs/axes.md로 이관되고 README에는 1줄 요약 + 링크만 남음"
    - "AC-H4: README·docs 전체 정량 수치가 docs/thresholds.md 항목 1개씩에 대응 (수동 체크리스트 통과)"
    - "AC-H5: 내부 링크 무결성 — README → docs + docs 상호 링크 전부 유효 (깨진 링크 0건)"
    - "AC-H6: docs/faq.md가 synthetic fixture 기반·production tuning 필요를 최소 1개 Q&A에서 명시"
  stretch:
    - "AC-S1: README.ko.md가 README.md와 섹션 순서·포인터 스타일 동형 유지"
    - "AC-S2: docs/axes.md만 읽어도 6축 강제 규칙 + --skip-axis / --acknowledge-risk 정책 이해 가능 (final-spec 링크 없이)"
evaluation_principles:
  - name: "correctness"
    weight: 0.35
    description: "docs 8파일·README 정돈이 Success Criteria 1·2·6을 만족한다"
    metric: "AC-H1·H2·H3·H5 모두 통과"
  - name: "traceability"
    weight: 0.30
    description: "정량 수치·6축 규칙이 외부 독자에게 추적 가능하다"
    metric: "AC-H4 통과 + docs/axes.md 외부 완결성 수동 리뷰 (AC-S2)"
  - name: "transparency"
    weight: 0.20
    description: "synthetic fixture 한계·튜닝 로드맵이 FAQ에 명시된다"
    metric: "AC-H6 통과 + Known Limitations 최소 3건 포함"
  - name: "maintainability"
    weight: 0.15
    description: "각 docs 파일이 독립 수정 가능한 크기·구조"
    metric: "파일당 ≤ 200 라인 + 5-섹션 템플릿 일관성"
exit_conditions:
  success: "11개 태스크 모두 각자의 AC 통과 + evaluation_principles 가중 합산 ≥ 0.80 (qa-judge)"
  failure: "AC-H1~H6 중 1건이라도 위반 + 재작업 불가 판정 시 즉시 중단"
  timeout: "8h (단일 스프린트 상한). 초과 시 P1(skills/*.md) 작업을 차기 스프린트로 이월"
---

# crucible README 고도화 — Implementation Plan

> 요구사항 문서 `.claude/plans/2026-04-20-readme-enhancement-requirements.md` (clarify:vague 산출) 기반 태스크 분해.
> 프로토콜: `skills/plan/SKILL.md` Phase 1~5.

## Ambiguity Score Gate

- **Score**: 0.12 (임계 0.20 하회) → **pass** · `/brainstorm` 재진입 불필요.
- 근거: Goal·Scope·Success Criteria·Excluded 모두 명시 + 8 ambiguity가 clarify:vague 2 라운드에서 해소됨.

---

## Decisions (Open Questions 4 선결)

요구사항 문서 말미의 Open Questions 4건을 `/plan` 단계에서 아래와 같이 확정:

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| Q1 | `docs/skills/*.md` 동일 섹션 템플릿 강제? | **YES** — 5-섹션 고정: **Paradigm · Judgment · Design Choices · Thresholds · References** | AC-H2로 승격. Success Criteria #2("docs 일관성") 측정 가능화. |
| Q2 | 작성 우선순위 P0 vs P1 분할? | **P0 먼저** — axes → thresholds → faq → skills/* | P0 3파일이 "근거 자료"이므로 skills/*에서 역참조 가능. 의존성 그래프 참조. |
| Q3 | thresholds.md drift 자동 체크 스크립트? | **범위 제외** — 수동 체크리스트 대체 (T-README-11) | 요구사항 Constraint "새 훅·스크립트 추가 금지"(문서 전용 스프린트)와 충돌. 자동화는 차기 스프린트 이월. |
| Q4 | faq.md Q&A 초안 수집처? | **3 소스 병합**: ① 요구사항 §Artifacts 8 예시 Q ② RELEASE-CHECKLIST Known Limitations ③ dogfooding 예상 질문 | 8~12개 Q&A 목표(요구사항 §Success Criteria) 달성에 충분. |

---

## Tasks

### 의존성 그래프

```
T-README-01 (axes.md)  ─┐
T-README-02 (thresh)   ─┼─► T-README-04~08 (skills/*.md)  ─┐
T-README-03 (faq.md)   ─┘                                   ├─► T-README-11 (integrity)
                          T-README-09 (README.md)          ─┤
                          T-README-10 (README.ko.md)       ─┘
```

P0 3파일(01·02·03) → P1 5파일(04~08) 병렬 → README 2파일(09·10) 병렬 → 최종 검증(11).

### P0 · 근거 자료 (depends_on: [])

#### T-README-01 — docs/axes.md 작성
- **Goal**: 6축 matrix + 철학 + `--skip-axis` / `--acknowledge-risk` 정책을 final-spec 링크 없이 외부 완결.
- **Files**: `docs/axes.md` (신규)
- **Scope**: 6축 정의표(Structure · Context · Plan · Execute · Verify · Improve) · 스킬별 ON/OFF/log-only matrix · 축별 "왜 필요한가" 단락 · skip 정책 · "하네스 6축" 용어 각주.
- **Model tier**: subagent
- **Acceptance**:
  - AC-01.1: 6축 전부 정의 + 스킬 5개 × 6축 matrix 표 포함
  - AC-01.2: `--skip-axis N` + Axis 5 스킵 시 `--acknowledge-risk` 필수 이유 명시
  - AC-01.3: 파일 ≤ 200 라인

#### T-README-02 — docs/thresholds.md 작성
- **Goal**: 모든 정량 수치(0.80 / 0.40 / n=20 / 3회 / 99% / 90% / 5%p / 20% / 5-차원 가중치)의 출처·측정 근거 단일 챕터화.
- **Files**: `docs/thresholds.md` (신규)
- **Scope**: 요구사항 §Included.3의 8개 수치 항목 + 각 항목의 출처(ouroboros 원본 / KU-X 실측 / 설계 추론) + 튜닝 로드맵.
- **Model tier**: subagent
- **Acceptance**:
  - AC-02.1: 8개 수치 항목 각각 출처 + 측정 방법 명시
  - AC-02.2: "synthetic fixture 기반" 디스클레이머 상단 포함
  - AC-02.3: 파일 ≤ 200 라인

#### T-README-03 — docs/faq.md 작성
- **Goal**: 8~12개 Q&A로 한계·의사결정 투명 공개.
- **Files**: `docs/faq.md` (신규)
- **Scope**: 요구사항 §Included.5 예시 Q 7건 + Known Limitations 1~2건 + dogfooding 예상 Q 1~2건. 각 A ≤ 5문장.
- **Model tier**: subagent
- **Acceptance**:
  - AC-03.1: Q&A 8건 이상 수록, A 당 ≤ 5문장
  - AC-03.2: synthetic fixture 한계 + production tuning 로드맵을 최소 1개 Q&A에서 언급 (AC-H6 충족)
  - AC-03.3: 파일 ≤ 200 라인

### P1 · 스킬별 패러다임 (depends_on: [T-README-01, T-README-02])

#### T-README-04 — docs/skills/brainstorm.md
- **Goal**: 왜 3-lens(vague·unknown·metamedium) + 왜 Phase 1~4 + 입출력 스펙.
- **Files**: `docs/skills/brainstorm.md` (신규)
- **Model tier**: subagent
- **Acceptance**:
  - AC-04.1: 5-섹션 템플릿(Paradigm · Judgment · Design Choices · Thresholds · References) 전부 채움
  - AC-04.2: Thresholds 섹션은 thresholds.md로 링크 (숫자 중복 금지)
  - AC-04.3: 파일 ≤ 200 라인

#### T-README-05 — docs/skills/plan.md
- **Goal**: 왜 Markdown+YAML 하이브리드 · Ambiguity Gate 0.2 근거 · 가중치 합 1.0 이유.
- **Files**: `docs/skills/plan.md` (신규)
- **Model tier**: subagent
- **Acceptance**:
  - AC-05.1: 5-섹션 템플릿 준수
  - AC-05.2: Markdown+YAML 선택 근거(v3.1 §2.2 결정 #10) 인용
  - AC-05.3: 파일 ≤ 200 라인

#### T-README-06 — docs/skills/verify.md
- **Goal**: 왜 qa-judge · 왜 Ralph Loop · 왜 3-stage Evaluator · 왜 fresh-context.
- **Files**: `docs/skills/verify.md` (신규)
- **Model tier**: subagent
- **Acceptance**:
  - AC-06.1: 5-섹션 템플릿 준수
  - AC-06.2: Ralph Loop 3회 상한 근거를 thresholds.md로 링크
  - AC-06.3: 파일 ≤ 200 라인

#### T-README-07 — docs/skills/compound.md
- **Goal**: 왜 3 트리거 · 승격 6-Step · 5-차원 overlap 가중치.
- **Files**: `docs/skills/compound.md` (신규)
- **Model tier**: subagent
- **Acceptance**:
  - AC-07.1: 5-섹션 템플릿 준수
  - AC-07.2: 5-차원 가중치(problem 0.3·cause 0.2·solution 0.2·files 0.15·prevention 0.15) 단일 출처(thresholds.md)만 참조
  - AC-07.3: 파일 ≤ 200 라인

#### T-README-08 — docs/skills/orchestrate.md
- **Goal**: 왜 4축 순차 · CP-0~CP-5 체크포인트 · dispatch×work×verify 3 허용 조합.
- **Files**: `docs/skills/orchestrate.md` (신규)
- **Model tier**: subagent
- **Acceptance**:
  - AC-08.1: 5-섹션 템플릿 준수
  - AC-08.2: CP-0~CP-5 전부 정의 + SHA256 무결성 근거 1줄 이상
  - AC-08.3: 파일 ≤ 200 라인

### README 정돈 (depends_on: [T-README-01])

#### T-README-09 — README.md 포인터 정돈
- **Goal**: 6축 matrix → docs/axes.md 이관 · 각 주요 섹션 하단 "Details → docs/..." 포인터.
- **Files**: `README.md` (수정)
- **Model tier**: subagent
- **Acceptance**:
  - AC-09.1: 6축 matrix 표가 README에서 제거되고 1줄 요약 + `docs/axes.md` 링크로 대체
  - AC-09.2: 설치·예제 섹션 구조 변경 없음 (Constraint 준수)
  - AC-09.3: "Details → docs/..." 포인터가 axes · thresholds · faq · skills 링크 최소 4개 이상

#### T-README-10 — README.ko.md 동형 유지
- **Goal**: README.md와 섹션 순서·포인터 스타일 동형.
- **Files**: `README.ko.md` (수정)
- **Model tier**: validator
- **Acceptance**:
  - AC-10.1: AC-09.1~09.3 모두 한국어 판에서 동일하게 성립
  - AC-10.2: 섹션 개수·순서가 README.md와 1:1 대응

### 검증 (depends_on: [T-README-01..10])

#### T-README-11 — 내부 링크 + 수치 drift 수동 체크리스트
- **Goal**: 깨진 링크 0건 + README/docs 수치가 thresholds.md 항목과 1:1 대응.
- **Files**: 검증 산출 (체크리스트를 본 plan의 progress note 또는 커밋 메시지에 기록)
- **Model tier**: validator
- **Acceptance**:
  - AC-11.1: `grep -r "docs/" README.md README.ko.md docs/` 의 모든 상대 경로가 실제 파일에 대응
  - AC-11.2: thresholds.md 8개 수치 항목 각각이 README 또는 docs/ 어딘가에서 최소 1회 참조됨
  - AC-11.3: 4개 수동 항목(각 docs 파일 헤더 + 섹션 제목 + 5-섹션 템플릿 준수 + synthetic 디스클레이머) 체크 통과

---

## Gaps (Phase 4)

요구사항 대비 현 repo 상태 격차 (gap-analyzer 수동 대체):

| Gap | 대응 태스크 |
|-----|------------|
| `docs/` 디렉터리 자체가 부재 | T-README-01 (신규 생성 시 자동 해소) |
| README에 인라인 6축 matrix 존재 | T-README-09 에서 이관 |
| synthetic fixture 한계가 RELEASE-CHECKLIST에만 명시 (외부 독자 접근성 낮음) | T-README-03 FAQ로 노출 |
| 정량 수치 단일 출처 부재 (final-spec·KU 리포트·코드에 분산) | T-README-02 에서 통합 |
| drift 자동화 부재 (Q3 결정으로 배제) | 차기 스프린트 이월 — 본 plan 범위 밖 |

---

## Exit Conditions (상세)

- **Success**: 11개 태스크 AC 전부 통과 + `/verify` 호출 시 evaluation_principles 가중 합산 ≥ 0.80.
- **Failure**: AC-H1~H6 위반 + 재작업 불가 판정 → 즉시 중단, 요구사항 재작성 권고.
- **Timeout**: 8h 초과 시 P1(T-README-04~08)을 차기 스프린트로 이월 + P0 + README 정돈만 우선 릴리스.

---

## Next Steps

1. `/verify .claude/plans/2026-04-20-readme-enhancement-plan.md` 로 본 plan 검증.
2. 승인 시 T-README-01·02·03 병렬 착수 (P0 먼저 · Q2 결정).
3. 완료 시 `/compound` 로 plan → seed 승격 검토.

---

*Generated via `/plan` (skills/plan/SKILL.md Phase 1~5) on 2026-04-20. parent_seed_id=null (루트 플랜).*

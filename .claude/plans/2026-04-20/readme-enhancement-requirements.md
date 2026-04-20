---
slug: readme-enhancement
type: requirements
date: 2026-04-20
parent_plugin: crucible
source_skill: clarify:vague
audience: plugin_users_developer_primary
---

# crucible README 고도화 — Requirements

> 1차 독자는 **플러그인 사용자(개발자)**. README는 간결 유지하고 기여자/리뷰어·깊이 독자를 위해 `docs/` 폴더에 주제별 8 파일로 패러다임·판단 기준·근거를 드러낸다. synthetic fixture 한계는 FAQ 식으로 투명 공개.

## Goal (1-line)

각 스킬의 **패러다임·판단 기준·근거(계산식·아이디어)**를 외부 독자가 final-spec 링크 없이도 추적 가능하게 `docs/` 폴더에 분리 정리하고, README는 사용자 중심으로 경량화한다.

---

## Scope

### Included

1. **README 정돈**
   - 현재 README 내 6축 matrix 섹션 → `docs/axes.md`로 이관 후 README에는 요약 1줄 + 링크
   - 각 주요 섹션 하단에 "Details → docs/..." 포인터 추가 (인라인 포인터 스타일)
   - README.ko.md 동형 유지

2. **`docs/skills/` 5 파일** — 스킬별 패러다임·판단 기준·주요 설계 선택 근거

   | 파일 | 담아야 할 내용 |
   |------|----------------|
   | `docs/skills/brainstorm.md` | 왜 3-lens(vague · unknown · metamedium) · 왜 Phase 1~4 구조 · 입출력 스펙 |
   | `docs/skills/plan.md` | 왜 Markdown+YAML 하이브리드 · Ambiguity Score Gate 0.2 근거 · evaluation_principles 가중치 합 1.0 이유 |
   | `docs/skills/verify.md` | 왜 qa-judge · 왜 Ralph Loop · 왜 3-stage Evaluator · 왜 fresh-context 분리 |
   | `docs/skills/compound.md` | 왜 3 트리거(pattern_repeat · user_correction · session_wrap) · 승격 게이트 6-Step · 5-차원 overlap 가중치 |
   | `docs/skills/orchestrate.md` | 왜 4축 순차 (Brainstorm→Plan→Verify→Compound) · CP-0~CP-5 체크포인트 · dispatch×work×verify 3 허용 조합 |

3. **`docs/thresholds.md`** — 정량 수치 근거 (별도 챕터 "왜 이 수치인가")
   - qa-judge 임계값: 0.80 (promote) · 0.40 (reject) · 0.40~0.80 (retry)
     - 출처: ouroboros 원본 → KU-0(W7.5)에서 20 synthetic 샘플 p75/p25 = 0.86/0.50 실측
     - 튜닝 로드맵: real-session JSONL 100+ 수집 시 재측정
   - KU 샘플 수 = 20: 이진 판정 95% CI 폭 근거 (n=10 ±30%p · n=20 ±22%p · n=30 ±17%p)
   - validate_prompt 발동률 ≥ 99% · 응답률 ≥ 90% (KU-1 기준)
   - 승격 게이트 false-positive < 20% (KU-3)
   - description 한·영 정확도 차 ≤ 5%p (KU-2)
   - Ralph Loop 상한 3회 (ouroboros 관례, retry 폭주 방지)
   - 5-차원 overlap 가중치: problem 0.3 · cause 0.2 · solution 0.2 · files 0.15 · prevention 0.15
   - oscillation 감지: Gen N vs Gen N-2 overlap ≥ 0.8 시 차단

4. **`docs/axes.md`** — 6축 matrix + 각 축의 "왜 이 축이 필요한가"
   - 6축 정의 (Structure · Context · Plan · Execute · Verify · Improve)
   - 스킬별 매트릭스 (ON/OFF/log-only)
   - 각 축의 필요성 철학 (예: Structure → 매니페스트 무결성 · Context → 세션 시작 시 MEMORY 주입 · Verify → release blocker)
   - `--skip-axis N` 이스케이프 해치 스펙 + Axis 5 스킵은 `--acknowledge-risk` 필수 이유
   - 원 강의 어휘 "하네스 6축" 출처 각주

5. **`docs/faq.md`** — FAQ 식 질문-답변으로 한계·의사결정 투명 공개
   - Q: 왜 임계값이 0.80/0.40인가? A: 원본 + synthetic 재측정 + production 튜닝 로드맵
   - Q: synthetic fixture 기반인데 production에서 신뢰해도 되나? A: MVP 가이드 + dogfooding 로그 수집 중
   - Q: Ralph Loop가 무한 루프 되지 않나? A: 3회 상한 + ouroboros 관례 근거
   - Q: 승격 게이트가 항상 번거롭지 않나? A: Stop hook 일괄 제시 + 거부 3회 연속 시 detector 7일 자동 비활성
   - Q: /orchestrate가 /brainstorm 4번 부르는 것과 뭐가 다른가? A: CP-0~CP-5 크래시 안전 재개 + 축 간 SHA256 무결성
   - Q: 한국어 트리거가 영어와 동등한가? A: KU-2 실측 Δ=0.00 (synthetic) + 프로덕션 차이 모니터링
   - Q: 이 플러그인을 다른 LLM에서 쓸 수 있나? A: Claude Code 전용 (SKILL protocol 의존)
   - 총 8~12개 Q&A 목표, 각 A ≤ 5문장

### Excluded

- SKILL.md frontmatter 6 필드 스키마 해설 → 기존 AGENTS.md 유지
- README.md · README.ko.md의 설치법·예제 섹션 구조 변경 (현행 유지)
- final-spec.md · implementation-plan.md · porting-matrix.md 수정 (내부 문서, 별도 이력 가치)
- `skills/*/SKILL.md` 본문 수정 (독립적, description 미세 조정 제외)
- CLAUDE.md · AGENTS.md 대대적 재작성 (포인터 추가만 허용)
- 새 훅·스크립트 추가 (문서 전용 스프린트)

---

## Constraints

- 각 `docs/` 파일 **≤ 200 라인** (가독성)
- 영어 primary, 필요 시 한국어 병기 (기존 포맷 준수)
- 근거 범위 = **정량 수치 + 주요 설계 선택** (frontmatter 필드 전부는 제외)
- 정직성 = FAQ 식 Q&A로 한계 투명 공개
- 링크 스타일 = 각 섹션 하단 "Details → docs/..." 포인터
- 모든 수치는 출처(ouroboros 원본·KU-X 결과·설계 추론) 명시
- synthetic fixture 기반 임을 thresholds.md 및 faq.md에 명시
- 기존 루트 파일(README·README.ko·CLAUDE·AGENTS·CONTRIBUTING·NOTICES·LICENSE·RELEASE-CHECKLIST) **구조 보존**

---

## Success Criteria

1. **README-only 완결성**: 사용자가 README.md만 읽어도 5 스킬 사용법·설치·예제 명확
2. **docs 일관성**: `docs/skills/<skill>.md` 5개가 동일 섹션 구조 (Paradigm · Judgment · Design Choices · References)
3. **정량 추적성**: README·docs 전체의 모든 정량 수치가 `docs/thresholds.md`에 항목 1개씩 대응
4. **6축 외부 완결성**: `docs/axes.md`만 읽어도 6축 강제 규칙·스킵 정책 이해 가능 (final-spec.md 링크 없이)
5. **한계 투명성**: `docs/faq.md`가 synthetic fixture 기반·production tuning 필요를 명시
6. **내부 링크 무결성**: `docs/` 내부 상호 링크 + README → docs 링크 전부 유효
7. **파일 크기**: 각 docs/ 파일 ≤ 200 라인

---

## Non-goals (confirmed Excluded above)

- 스킬 내부 로직 수정
- `.claude/plans/` 내부 개발 이력 정리 (별도 정리 작업)
- 기존 AC·KU 재측정 (W7.5 완료분 그대로 재사용)

---

## Artifacts (expected)

```
docs/
├── skills/
│   ├── brainstorm.md    # paradigm + design choices
│   ├── plan.md
│   ├── verify.md
│   ├── compound.md
│   └── orchestrate.md
├── thresholds.md        # 정량 수치 근거 챕터
├── axes.md              # 6축 matrix + 철학
└── faq.md               # FAQ 식 Q&A

README.md                # 기존 유지 + 링크 포인터 추가 · 6축 matrix 링크화
README.ko.md             # 동형
```

---

## Open Questions (for /plan)

1. `docs/skills/<skill>.md` 5개 작성 시 **동일 섹션 템플릿**을 강제할지 (예: Paradigm / Judgment / Design Choices / Thresholds / References 5-section)
2. 각 파일 우선순위: P0(axes·thresholds·faq 먼저) vs P1(skills/*) 분할할지
3. `docs/thresholds.md` 값 갱신 시 자동 체크 스크립트(예: README 숫자 vs thresholds 숫자 drift 검사)를 추가할지
4. `docs/faq.md`의 Q&A 초안을 어디서 수집할지 (가상 + dogfooding 예상 질문 + 현 release notes의 Known Limitations)

→ `/plan`에서 이 네 가지를 해소한 후 태스크 ID 부여.

---

*This requirements document was produced via `clarify:vague` on 2026-04-20. 8 ambiguities resolved through 2 question batches.*

# Harness Plugin 계획 문서 인덱스

> 작성: 2026-04-19 | 프로젝트: Claude Code Harness Plugin 설계·구현

---

## Phase 흐름 (0 → 1 → 2 → 3 → 4)

```
Phase 0 ─── 도구 추천
    │
Phase 1 ─── 요구사항 명확화
    │
Phase 2 ─── 레퍼런스 리서치 (6개 대상 병렬 분석 → 종합)
    │
Phase 3 ─── 최종 스펙 작성 + document-review (7-페르소나)
    │
Phase 4 ─── 구현 계획 (태스크·포팅·§11 미결 추적)
```

---

## 00-recommendations/ — Phase 0: 도구 추천

| 파일 | 설명 |
|------|------|
| [tool-recommendations.md](00-recommendations/tool-recommendations.md) | 프로젝트 초기 도구 스택 추천 (프레임워크·라이브러리 선정 근거) |

---

## 01-requirements/ — Phase 1: 요구사항 명확화

| 파일 | 설명 |
|------|------|
| [clarified-spec.md](01-requirements/clarified-spec.md) | 10개 결정 매트릭스 포함 명확화된 스펙 — Phase 1 최종 산출물 |

---

## 02-research/ — Phase 2: 레퍼런스 리서치

| 파일 | 설명 |
|------|------|
| [superpowers.md](02-research/superpowers.md) | Claude Superpowers 레퍼런스 분석 |
| [compound-engineering-plugin.md](02-research/compound-engineering-plugin.md) | Compound Engineering Plugin 레퍼런스 분석 |
| [hoyeon.md](02-research/hoyeon.md) | Hoyeon 레퍼런스 분석 |
| [ouroboros.md](02-research/ouroboros.md) | Ouroboros 레퍼런스 분석 |
| [agent-council.md](02-research/agent-council.md) | Agent Council 레퍼런스 분석 |
| [plugins-for-claude-natives.md](02-research/plugins-for-claude-natives.md) | Plugins for Claude Natives 레퍼런스 분석 |
| [**synthesis.md**](02-research/synthesis.md) | ⭐ 6개 분석 종합 — 포팅 Top-32 자산·차별점 순위·KU 실험 설계 |

---

## 03-design/ — Phase 3: 최종 스펙 + 리뷰

| 파일 | 설명 |
|------|------|
| [**final-spec.md**](03-design/final-spec.md) | ⭐ v2 최종 스펙 — Phase 1+2+3 통합, 단일 진실 소스 (257 lines) |
| [final-spec-review.md](03-design/final-spec-review.md) | 7-페르소나 document-review 결과 (P0 9건·P1 10건·총 30 findings) |

---

## 04-planning/ — Phase 4: 구현 계획

| 파일 | 설명 |
|------|------|
| [**implementation-plan.md**](04-planning/implementation-plan.md) | ⭐ 메인 태스크 분해 (W0~W4 스프린트, 의존성·공수 포함) |
| [porting-matrix.md](04-planning/porting-matrix.md) | 포팅 자산 매트릭스 — 어떤 자산을 어디서 가져오는지 |
| [section11-promotion-tracker.md](04-planning/section11-promotion-tracker.md) | §11 미결 7항목 승격 체크리스트 |

---

## prompts/ — Phase 지시서 원본 (재사용·감사용)

| 파일 | 설명 |
|------|------|
| [phase2-research-prompt.md](prompts/phase2-research-prompt.md) | Phase 2 리서치 6개 병렬 에이전트 실행 지시서 |
| [phase4-ce-plan-prompt.md](prompts/phase4-ce-plan-prompt.md) | Phase 4 CE Plan 실행 지시서 |
| [reorganize-plans-prompt.md](prompts/reorganize-plans-prompt.md) | 이 폴더 정리 지시서 (현재 문서) |

---

## 다음 세션 재개 가이드

### 처음 컨텍스트를 파악하려면
1. **[final-spec.md](03-design/final-spec.md)** 읽기 — 전체 스펙의 단일 진실 소스
2. **[implementation-plan.md](04-planning/implementation-plan.md)** 읽기 — 현재 진행 상황과 다음 태스크 확인

### 특정 Phase가 궁금하다면
- Phase 1 결정 근거: [clarified-spec.md](01-requirements/clarified-spec.md)
- 레퍼런스 자산 요약: [synthesis.md](02-research/synthesis.md)
- 스펙 리뷰 피드백: [final-spec-review.md](03-design/final-spec-review.md)
- 포팅 전략: [porting-matrix.md](04-planning/porting-matrix.md)

### 구현 착수 시 체크
- [ ] `implementation-plan.md` — W0 태스크 상태 확인
- [ ] `section11-promotion-tracker.md` — §11 미결 항목 검토
- [ ] `porting-matrix.md` — 포팅 대상 우선순위 확인

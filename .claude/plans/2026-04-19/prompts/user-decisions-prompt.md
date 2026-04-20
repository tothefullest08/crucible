# 유저 판단 5건 결정 세션 지시서

## 📖 필수 컨텍스트 (먼저 모두 읽을 것)

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md` — 전체 프로젝트 맥락
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v2 최종 스펙 (특히 §11 설계 미결)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/section11-promotion-tracker.md` — **§11-1~7 승격 체크리스트, 유저 판단 5건 상세 포함**
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec-review.md` — P0/P1 finding 원천 (P1-1 포지셔닝 등)

## 🎯 태스크

Phase 4 `/ce-plan`의 `section11-promotion-tracker.md`에서 식별된 **유저 판단 필요 5건**을 유저와의 대화를 통해 결정하고 문서화하세요.

### 5건 목록

1. **보안 범위 (§11-2)**
   - secrets 패턴 리스트 어디까지? (AWS/GCP/GitHub/Slack/JWT/DB URL/Bearer token + 추가?)
   - `detect-secrets` / `trufflehog` 같은 외부 도구 의존성 허용 여부?
   - 글로벌 `~/.claude/memory/` 기본 비활성 유지? 아니면 opt-in?

2. **KU 샘플 수·정책 (§11-4)**
   - 각 KU(KU-0·1·2·3)별 필요 샘플 수 (예: 스킬당 20건? 100건?)
   - 실패 시 결정: W8 릴리스 **차단**인가 **경고만**인가
   - judge 에이전트(KU-1b 실제 응답률)는 수동 평가인가 자동인가

3. **6축 강제 범위 (§11-5)**
   - 활성 스킬: `/plan`·`/verify`·`/orchestrate`만? `/brainstorm`·`/compound`는 적용 제외 확정?
   - `--skip-axis N` 이스케이프 해치 허용 여부
   - "실효성 지표" (축 통과 ↔ 산출물 품질 상관) 메트릭을 KU에 추가할지

4. **라이선스 선택 (§11-6)**
   - MIT / Apache-2.0 / GPL-3.0 중 어느 것?
   - 포팅 자산 4곳(hoyeon/ouroboros/p4cn/superpowers) 상류 라이선스 호환 여부 먼저 확인 필요
   - 이 플러그인의 기여 수용 정책(CLA 등)

5. **포지셔닝 1문장 (P1-1)**
   - README 상단 one-sentence positioning
   - 형식: "harness는 [구체 사용자]가 [구체 통증]을 해결하고 싶을 때, [핵심 메카닉 1-2개]로 [구체 결과]를 얻는 플러그인이다. 기존 [CE/hoyeon]와는 [구체 차이]에서 구별된다."

### 진행 방식

각 건을 **하나씩** AskUserQuestion으로 결정:

- **가설 옵션 제시** — 각 선택지에 대해 2~4개 hypothesis를 option으로 제시
- **가능하면 "권장 (Recommended)" 첫 옵션으로** — 근거를 v2 스펙 + review 문서에서 인용
- **유저가 "Other" 선택하거나 추가 조건 제시하면** 필요한 만큼 follow-up 질문
- **질문 총량 cap: 10~12개** (5건 × 최대 2~3질문). 과도한 질문은 fatigue 유발

### 근거 수집

각 결정 이전에:
- v2 스펙의 해당 섹션(§4.2·§4.3·§8·§11)
- review 문서의 관련 P0/P1 finding
- porting-matrix의 라이선스 초안 (§11-6 관련)

을 1~2분 리서치해서 hypothesis 옵션의 품질을 높이세요.

## 📁 산출물

**`/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/user-decisions-5.md`** 생성:

```markdown
# 유저 판단 5건 결정 결과

## 1. 보안 범위 (§11-2)
### 결정
- secrets 패턴 리스트: [...]
- 외부 도구 의존성: [...]
- 글로벌 메모리 기본값: [...]

### 근거 및 Trade-off
- ...

### v2 스펙 반영 위치
- §11-2 → §4 (§X.Y) 로 승격 예정 (주차: W4 이전)

## 2. KU 샘플 수·정책 (§11-4)
...

## 3. 6축 강제 범위 (§11-5)
...

## 4. 라이선스 선택 (§11-6)
...

## 5. 포지셔닝 1문장 (P1-1)
### 최종 문장
> "..."

### 대안 문장 (검토됨, 기각 이유 포함)
- ...

---

## 후속 조치 체크리스트

- [ ] final-spec.md §11-2 → §4 승격 (W4 이전)
- [ ] final-spec.md §11-4 → §8 KU 테이블 확정 (W7.5 이전)
- [ ] final-spec.md §11-5 → §3 또는 §4 승격
- [ ] final-spec.md §11-6 + porting-matrix.md 라이선스 매트릭스 업데이트
- [ ] README 템플릿 작성 시 포지셔닝 1문장 상단 삽입 (W8)
- [ ] section11-promotion-tracker.md 해당 항목 "결정 완료" 체크
```

## ⚙️ 실행 제약

- **한국어 대화** — AskUserQuestion 질문과 옵션 모두 한국어
- **이미 결정된 것 재결정 금지** — Phase 1·2·3·4의 결정 사항(v2 스펙 §2.1·§2.2 + section11-promotion-tracker 확정 항목)은 재확인 불필요
- **구현 코드 작성 금지** — 결정 문서화만
- **final-spec.md 수정 금지** — 이 세션은 결정만. 실제 §11 → §N 승격은 별도 이터레이션에서 진행

## ✅ 완료 기준

1. 5건 모두 확정 (유저 답변 또는 기본값 승인)
2. `03-design/user-decisions-5.md` 생성
3. 후속 조치 체크리스트 명시
4. section11-promotion-tracker에 결정 상태 반영 제안 (문서 수정은 다음 이터레이션)

## 🛑 금지

- 질문 12개 초과
- 유저 명시 승인 없이 "기본값으로 진행" 처리 (시간 촉박 시에만, 명시적으로 알림)
- v2 스펙·implementation-plan·porting-matrix 수정 (이 세션 범위 밖)

시작하세요.

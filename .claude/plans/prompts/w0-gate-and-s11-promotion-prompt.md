# W0 게이트 판정 + §11-1 승격 지시서 (상단 패널)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/03-design/final-spec.md` — v3 최신 (§11-1 승격 대상)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/implementation-plan.md` — T-W0-05 · T-W1-PRE-01 정의
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/w0-results/t-w0-01-anthropic-cookbook.md` — W0 조사 1
5. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/w0-results/t-w0-02-framework-comparison.md` — W0 조사 2
6. `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/section11-promotion-tracker.md` — §11-1 현재 상태

## 🎯 태스크

두 가지 작업을 **순차**로 수행:

### Task 1 — T-W0-05 게이트 판정 메모 작성 (30분)

유저 결정: **"W0 결과는 인지만, 작업 계획 변경 없음. TL;DR 유지"**

산출물: `/Users/ethan/Desktop/personal/harness/.claude/plans/04-planning/w0-gate-decision.md` (1쪽, 간결)

필수 섹션:
1. **판정 요약**: "TL;DR 유지 · 재스코프·§11 재설계 없이 W1 진입"
2. **W0 결과 인지 사항**:
   - T-W0-01 Anthropic Cookbook 결과 요약 (🟡 부분 훼손)
   - T-W0-02 4-framework 비교 결과 요약 (🟢 강화 + 🟡 축 깊이 리스크)
   - **개선(Compounding) 축만 공백** → 유일 고유 차별화 지점 (참고로만 보존)
3. **판정 근거**: 조사 결과가 "6축 메타 레이어 부재" 프리미스를 전면 훼손하지 않음. 플러그인 레이어는 여전히 공백. 재정의 필요성 < 실행 모멘텀 손실.
4. **T-W0-03·04 처리**: 스킵 (W7.5 하드닝 시 필요하면 재개)
5. **다음 액션**: W1 착수. 첫 태스크는 T-W1-PRE-01(§11-1 승격).

**제약**: 1쪽 이내. 결정·근거·다음 액션만.

---

### Task 2 — T-W1-PRE-01 §11-1 승격 작업 (8h)

`final-spec.md`의 §11-1 (JSONL 외부 스키마 안정성)을 §4.2 정식 섹션으로 **승격**. v3 현재는 "기본 방향만 있고 상세는 §11-1 참조" 구조 → **§4.2를 완전 사양으로 재작성**하고 §11-1은 "→ §4.2 참조"로 축소.

#### §4.2 정식화 — 다음 4가지 모두 확정 (implementation-plan T-W1-PRE-01 검증 기준)

**1. 스키마 어댑터 타입 시그니처**

`scripts/schema-adapter.sh`의 동작 명세. 예:
```
입력: JSONL 라인 (stdin)
처리:
  - .type 필드 추출 (jq -r '.type // "unknown"')
  - .schema_version 필드 추출 (jq -r '.schema_version // "v0"')
  - (type, schema_version) 쌍을 adapter 함수로 dispatch
  - 함수 매핑표: { "file-history-snapshot-v0" → parse_fhs_v0, ... }
  - 매핑 없는 경우 → skip + log (stderr)
출력: 정규화된 JSON (stdout)
```
최소 3개 type(현재 p4cn session-file-format.md 확인된 것) 파서 선언. 알 수 없는 type은 **skip-and-continue** (방어적 파서 원칙).

**2. UserPromptSubmit 훅 기반 라이브 캡처 fallback 순서도**

JSONL 파싱 실패 시 Fallback 전환:
```
[Primary] JSONL 파서
   │ 실패 (schema mismatch 임계 이상)
   ▼
[Secondary] UserPromptSubmit 훅에서 live 캡처
   │ 실패
   ▼
[Tertiary] 컴파운딩 비활성화 (사용자 알림)
```

전환 조건 수치화: 예) "마지막 10 세션 중 schema error > 30% 시 Secondary 전환"

**3. 72h smoke test 체크리스트**

GitHub Actions cron으로 3일마다 자동 실행. 체크 항목:
- [ ] JSONL 파싱 에러율 < 5%
- [ ] unknown type 출현 여부 (새 type 나타나면 알림)
- [ ] schema_version 분포 (특정 버전 비중 > 90% 변화 감지)
- [ ] adapter dispatch 누락 카운트 = 0
- [ ] Claude Code 최근 릴리스 72h 내 여부 + 릴리스 노트 키워드 grep (`jsonl`, `session`, `schema`)

**4. Degradation UX**

포맷 붕괴 시 사용자에게 어떻게 알릴지:
- 컴파운딩 **비활성화 시** SessionStart 페이로드에 경고 배너 1줄
- `/compound` 호출 시 명시적 에러 메시지 (원인 · Fallback 전환 여부)
- `MEMORY.md` 헤더에 `{degraded: true, since: <date>}` YAML 플래그

---

## 📁 산출물

1. **`04-planning/w0-gate-decision.md`** — 1쪽 판정 메모
2. **`03-design/final-spec.md`** — §4.2 정식화 + §11-1 축소 (`"→ §4.2 참조, 승격 완료 2026-04-19"`)
3. **`03-design/v3-change-log.md`** — "W1 진입 승격 내역" 섹션 추가 (§11-1 승격 diff 요약)
4. **`04-planning/section11-promotion-tracker.md`** — §11-1 상태 ✅ 완료로 업데이트

## ⚙️ 실행 제약

- **한국어**
- **final-spec.md 버전 표기**: v3 → v3.1 (상단 변경 이력에 "§11-1 승격 (T-W1-PRE-01 완료)")
- **§11-1은 완전 삭제 금지** — "→ §4.2 참조" 한 줄로 축소 (추적성 보존)
- **구현 코드 생성 금지** — 이 패널은 **설계 문서만**. 실제 `scripts/schema-adapter.sh` 등 파일 생성은 하단 패널 W1-06·07에서 수행됨 (이 세션 밖)
- **하단 패널 작업과 충돌 없음**: 하단은 `.claude-plugin/plugin.json` 등 신규 파일. `final-spec.md`는 상단 전담.

## ✅ 완료 기준

1. `w0-gate-decision.md` 생성 (1쪽)
2. `final-spec.md` §4.2 4개 항목 전부 확정 + §11-1 축소
3. `v3-change-log.md` 추가 섹션
4. `section11-promotion-tracker.md` §11-1 ✅ 완료
5. 하단 패널의 T-W1-01·02·03 작업과 **파일 충돌 없음** (다른 파일만 건드림)

## 🛑 금지

- `.claude-plugin/`, `hooks/`, `scripts/` 실제 파일 생성 (하단 패널 범위)
- `implementation-plan.md` · `porting-matrix.md` 수정
- §11-1 외 다른 §11 항목 건드리기
- W0 재조사 (T-W0-03·04 실행 금지)

시작하세요.

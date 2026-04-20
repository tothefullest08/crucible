# §11 승격 이터레이션 — final-spec v3 생성 지시서

## 📖 필수 컨텍스트 (먼저 모두 읽을 것)

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — **v2 현재 상태 (수정 대상)**
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/user-decisions-5.md` — **유저 판단 5건 확정 (반영 소스)**
4. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec-review.md` — 원 리뷰 findings
5. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/section11-promotion-tracker.md` — §11-1~7 체크리스트
6. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/porting-matrix.md` — 라이선스 매트릭스 업데이트 대상

## 🎯 태스크

v2 `final-spec.md`를 **v3로 승격**하세요. `user-decisions-5.md` 5건의 결정을 v2 §11 해당 섹션에서 **정식 §로 이관**합니다.

### 구체 승격 매핑

| user-decisions-5 결정 | v3 반영 위치 |
|---------------------|------------|
| **1. 보안 범위** (범용 7종 + 로컬 확장 훅, 외부 도구 불허, 글로벌 메모리 기본 OFF) | §4.3 보안 제약 **확장** + §11-2 해당 항목 **제거** 혹은 "W4 구현 전 확정 완료" 표기 |
| **2. KU 샘플·정책** (20 샘플, 재시도 1회 후 차단, 자동 LLM judge) | §8 KU 테이블에 **"샘플 수 / 실패 시 결정 / judge 방식"** 3개 컬럼 추가 + §11-4 제거 |
| **3. 6축 강제 범위** (/plan·/verify·/orchestrate ON, --skip-axis N 허용, 검증 축 강경 경고, 실효성 KU 2차) | §3 또는 §4에 **§3.4 6축 강제 적용 범위** 신설 + §11-5 제거 |
| **4. 라이선스** (MIT, DCO sign-off, 분기/반기 sync 차등) | §4.4 또는 신규 §4.5 라이선스 정책 신설 + §11-6 제거. **`porting-matrix.md` 라이선스 컬럼도 MIT/호환 여부로 업데이트** |
| **5. 포지셔닝 1문장** | §1 TL;DR **최상단 1문장** 삽입 + §11-7 포지셔닝 항목 제거 |

### v3 문서 구조 규칙

- **버전 명시**: 상단 "v3 (user-decisions-5 반영)" + 변경 이력에 "v2 → v3 (2026-04-19): user-decisions-5.md 5건 승격" 추가
- **§11 잔여 항목**: 아직 미결인 §11-1(JSONL 스키마 세부) + §11-3(승격 게이트 UX) + §11-7 기타 일부는 **유지** (각각 W1·W5·주차별 승격 deadline은 그대로)
- **§2.2 Phase 3 신규 결정 테이블**: 6가지 유지. 단 user-decisions-5 5건은 별도 §2.3 "Phase 3.5 User Decisions 반영" 섹션으로 추가 (상충 재검토는 §2.4로 밀기)
- **문서 일관성**: 용어 드리프트 없는지 점검 (리뷰 P2 지적 - Consensus 대소문자, evaluator 디렉토리 등)

### 라이선스 매트릭스 업데이트 (`porting-matrix.md`)

`user-decisions-5.md §4` 결정에 따라 `porting-matrix.md` 라이선스 컬럼 업데이트:
- 포팅 자산 4곳(hoyeon/ouroboros/p4cn/superpowers) 실제 라이선스 확인 (각 레포 LICENSE 파일 확인 — `references/` 하위)
- MIT / Apache-2.0 / 기타 분류
- MIT 플러그인 기준으로 **호환 여부** 표기 (MIT·Apache-2.0·BSD = OK / GPL·AGPL = 회피)
- 비호환 발견 시 해당 자산 포팅 중단 or 재작성 필요 플래그

### section11-promotion-tracker 업데이트

`section11-promotion-tracker.md` 각 항목 상태 업데이트:
- §11-2·4·5·6: **"결정 완료 (user-decisions-5 + v3 §N 승격 완료)"**
- §11-7 포지셔닝: **"결정 완료 (v3 §1 TL;DR 반영)"**
- §11-1·3·나머지 7: **"미결 — 해당 주차 이전 승격 예정"** 유지

## 📁 산출물

1. **`.claude/plans/2026-04-19/03-design/final-spec.md`** — v3 덮어쓰기 (v2 구조 유지 + 위 5건 승격)
2. **`.claude/plans/2026-04-19/04-planning/porting-matrix.md`** — 라이선스 컬럼 업데이트 + 비호환 플래그
3. **`.claude/plans/2026-04-19/04-planning/section11-promotion-tracker.md`** — §11 각 항목 상태 업데이트
4. **`.claude/plans/2026-04-19/03-design/v3-change-log.md`** (신규) — v2 → v3 변경 요약 (각 승격별 before/after)

## ⚙️ 실행 제약

- **한국어**
- **내용 추가만, 삭제 최소화** — §11 해당 항목은 "이관 완료" 표시로 축소 (완전 삭제 대신 한 줄 참조 "→ §N.Y 참조")
- **user-decisions-5.md는 수정 금지** (결정 원본 보존)
- **implementation-plan.md 수정 금지** (태스크 분해는 별도 이터레이션)
- **INDEX.md 업데이트는 선택적** (v3 명시가 도움 되면 추가)

## ✅ 완료 기준

1. `final-spec.md` 상단에 v3 표기 + 변경 이력
2. user-decisions-5 5건 모두 정식 § 이관 완료 (각 §에 "결정 근거: user-decisions-5 §N" 주석)
3. `porting-matrix.md` 라이선스 매트릭스에 실제 라이선스 + 호환 플래그
4. `section11-promotion-tracker.md` 상태 업데이트
5. `v3-change-log.md` 생성
6. 기존 §11 잔여 미결(§11-1·3·기타) deadline 유지 확인

## 🛑 금지

- 새로운 설계 결정 추가 (v3는 **반영만** 하는 이터레이션)
- `user-decisions-5.md` 내용 재해석 (결정문 그대로 반영)
- W0 관련 작업 (T-W0-01·02는 별도 패널 병렬 진행 중)

시작하세요.

# `.claude/plans/` 문서 정리 지시서 (Sonnet 모델 사용)

## 📖 대상

`/Users/ethan/Desktop/personal/harness/.claude/plans/` 하위 16개 문서를 **의미 단위 카테고리**로 폴더 정리하고, **모든 문서 간 참조 경로도 함께 업데이트** 해주세요.

## 🎯 태스크

### 1단계: 분류 설계
현재 16개 문서를 모두 읽을 필요는 없지만, 파일명과 상위 10~20줄의 제목·summary를 읽고 의미를 파악하세요. 그 다음 **Phase 기반 카테고리**로 분류하세요.

**권장 구조** (조정 가능):

```
.claude/plans/
├── 00-recommendations/           # Phase 0: 도구 추천
│   └── tool-recommendations.md
├── 01-requirements/              # Phase 1: 요구사항 명확화
│   └── clarified-spec.md
├── 02-research/                  # Phase 2: 레퍼런스 리서치
│   ├── agent-council.md
│   ├── compound-engineering-plugin.md
│   ├── hoyeon.md
│   ├── ouroboros.md
│   ├── plugins-for-claude-natives.md
│   ├── superpowers.md
│   └── synthesis.md              # 종합 문서
├── 03-design/                    # Phase 3: 최종 스펙 + 리뷰
│   ├── final-spec.md             # v2 (Phase 1+2+3 통합 + review 반영)
│   └── final-spec-review.md      # document-review 결과
├── 04-planning/                  # Phase 4: 구현 계획
│   ├── implementation-plan.md
│   ├── porting-matrix.md
│   └── section11-promotion-tracker.md
└── prompts/                      # 각 Phase 지시서 원본 (재사용/감사용)
    ├── phase2-research-prompt.md
    ├── phase4-ce-plan-prompt.md
    └── (이 지시서도 이곳으로 이동: reorganize-plans-prompt.md)
```

카테고리 명이 더 적절하다고 판단되면 수정 가능. 단 **Phase 순서가 드러나는 숫자 prefix 유지** 권장.

### 2단계: 파일 이동

- `mkdir -p` 로 폴더 생성
- `mv` 로 파일 이동
- **파일명에서 `2026-04-19-` 날짜 prefix 제거** (폴더로 시점이 드러나므로 중복). 단, 일부 파일명이 너무 짧아지면 유지 판단.
  - 예: `01-requirements/clarified-spec.md` → `01-requirements/clarified-spec.md`
  - 예: `02-research/hoyeon.md` → `02-research/hoyeon.md`
- 단, "research" 접두사처럼 폴더명과 중복되는 prefix도 제거

### 3단계: 참조 경로 업데이트 (**가장 중요**)

이동한 파일들은 서로를 참조한다. 각 문서 내부의 모든 `.claude/plans/...` 경로를 **새 경로로 업데이트**해야 한다.

**참조 경로 패턴 예시** (실제 문서에서 확인):
- `.claude/plans/2026-04-19/01-requirements/clarified-spec.md` → `.claude/plans/2026-04-19/01-requirements/clarified-spec.md`
- `.claude/plans/2026-04-19/02-research/synthesis.md` → `.claude/plans/2026-04-19/02-research/synthesis.md`
- `.claude/plans/2026-04-19/03-design/final-spec.md` → `.claude/plans/2026-04-19/03-design/final-spec.md`

**권장 절차**:
1. `grep -r "2026-04-19-" /Users/ethan/Desktop/personal/harness/.claude/plans/` 로 모든 참조 찾기
2. 각 참조를 새 경로로 치환 (sed 또는 Edit)
3. 절대 경로(`/Users/ethan/Desktop/personal/harness/.claude/plans/...`) 형태도 동일하게 업데이트

**주의**:
- 문서 내 **메타데이터**(예: "작성일: 2026-04-19") 같은 날짜 언급은 건드리지 말 것. 파일 경로 참조만 수정.
- git-style 마크다운 링크 `[text](path)` 와 코드 블록 내 참조도 모두 업데이트
- 참조된 파일이 존재하는지 `ls` 로 사후 검증

### 4단계: INDEX 문서 생성

`.claude/plans/2026-04-19/INDEX.md` 파일 생성:
- 카테고리별 파일 목록
- 각 파일 한 줄 설명
- Phase 흐름(0→1→2→3→4) 시각화
- "다음 세션에서 이 프로젝트를 재개할 때 어디서부터 읽으면 되는지" 가이드

### 5단계: 검증

- [ ] 16개 파일 모두 새 경로에 있는지 `find` 로 확인
- [ ] 루트 `.claude/plans/`에는 `INDEX.md`와 폴더들만 남아있는지
- [ ] `grep -r "2026-04-19-" .claude/plans/` 로 구 경로 참조가 남아있는지 확인 (없어야 함, 단 메타데이터의 날짜는 OK)
- [ ] 각 폴더 내부에 파일이 예상대로 배치됐는지

## ⚙️ 실행 제약

- **Sonnet 모델 사용** — 파일 이동·grep·sed 중심 작업이라 reasoning 부담 적음, Sonnet이 충분. 세션 시작 시 `/model sonnet` 전환 (또는 `claude --dangerously-skip-permissions --model sonnet`로 시작됨)
- **한국어 INDEX.md** 작성
- **원본 파일 수정 최소화** — 카테고리 이동 + 참조 경로 업데이트만. 내용 변경 금지.
- **Git이 아님** — 이 프로젝트는 git repo가 아니므로 git mv 불필요, 일반 mv 사용.

## ✅ 완료 기준

1. 16개 파일 모두 카테고리 폴더로 이동 (prompts 포함, 이 지시서도 prompts/로)
2. 모든 파일 내부 참조가 새 경로로 업데이트됨
3. `.claude/plans/2026-04-19/INDEX.md` 생성됨
4. 루트에는 `INDEX.md` + 폴더들만
5. grep으로 구 경로 참조 0건 (메타데이터 날짜 제외)

## 🛑 금지

- 파일 내용 수정 (카테고리 이동 + 참조 경로만 업데이트)
- 16개 외 추가 파일 생성 (INDEX.md만 예외)
- 카테고리 간 병합·분할 (의미 단위가 분명한 경우에만)
- Python/Node 사용 (bash/grep/sed만 사용)

시작하세요.

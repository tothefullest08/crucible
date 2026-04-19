# `.claude/memory/` — 개인화 컴파운딩 메모리

하네스 플러그인의 승격 게이트(v3.3 §3.4)를 통과한 지식이 영구 저장되는 위치. 본 디렉토리는 기본 **프로젝트 로컬**(v3.3 §2.2 Dec 12.2). `~/.claude/memory/` 글로벌 모드는 `plugin.json.global_memory_enabled` 설정으로 opt-in.

## 디렉토리 구조

```
.claude/memory/
├── MEMORY.md                    # 1줄 포인터 인덱스 (자동 로드 대상)
├── README.md                    # 본 문서 (포맷 규약 · frontmatter 스키마)
├── tacit/                       # 일반 암묵지 (승격된 패턴·경험)
├── corrections/                 # 유저 "틀렸다" 기록 (Bug track)
│   └── _rejected/               # 승격 게이트 Step 6 거부 이력 (과적합 감지 입력)
└── preferences/                 # 유저 선호 · 작업 습관
```

## Frontmatter 스키마 (T-W5-03)

모든 메모리 파일은 다음 YAML frontmatter를 가진다.

### 공통 필수 필드
```yaml
---
name: <slug — a-zA-Z0-9_-만>
description: <한 줄 요약 (≤ 120자)>
type: tacit | correction | preference
candidate_id: <uuid-v4 — 승격 후보 단계에서 부여>
promoted_at: <ISO-8601 UTC — 저장 승인 시점>
evaluator_score: <0.0~1.0 — qa-judge 점수>
source_turn: <session_id:turn_range>
---
```

### type별 추가 필드

#### `type: tacit` (일반 암묵지 · Knowledge track)
```yaml
domain: <선택 — 예: "kotlin", "react", "ops">
confidence: high | moderate | low    # Phase 2 Evaluator dimensions 요약
```

#### `type: correction` (Bug track)
```yaml
trigger: user_correction    # 항상 고정
original_claim: <AI의 틀린 원 주장 요지>
user_correction: <유저 정정 발언>
prevention: <재발 방지 지침>
```

#### `type: preference` (유저 선호)
```yaml
scope: session | project | user    # 적용 범위
override_priority: high | normal    # 다른 규칙과 충돌 시 우선순위
```

## MEMORY.md 인덱스 포맷 규약 (T-W5-02)

`MEMORY.md`는 빠른 로딩을 위한 포인터만 담는다. 본문은 개별 파일 참조.

```markdown
- [{Title}]({relative_path}) — {≤150자 one-line hook}
```

정규식: `^- \[([^\]]+)\]\(([^)]+)\) — (.{1,150})$`

**예시**:
```markdown
- [Kotlin CoroutineScope 수명](tacit/kotlin-coroutine-scope.md) — CoroutineScope는 suspend 함수 밖에서 관리, `lifecycleScope`·`viewModelScope` 활용
- [React useEffect 의존성 배열](corrections/react-useeffect-deps.md) — 모든 참조 값은 의존성 배열에 포함, eslint-plugin-react-hooks 사용
```

## Bug track vs Knowledge track 분류 (T-W5-04)

- `corrections/` → **Bug track** (유저가 명시 정정한 AI 오류, 재발 방지 우선)
- `tacit/` → **Knowledge track** (일반 암묵지, 도메인 지식 축적)
- 자동 분류 기준: `trigger_source = user_correction` → Bug, 그 외 → Knowledge (T-W5-04 구현)

## 오염 방지 (v3.3 §2.1 #6)

- **모든 쓰기는 승격 게이트 통과 시에만** (v3.3 §3.4 참조)
- `_rejected/` 이력 누적 시 과적합 감지기가 동일 패턴 3회 연속 거부 시 detector 임시 비활성화 제안 (v3.3 §3.4.4)
- **글로벌 모드(`~/.claude/memory/`)는 기본 OFF** — 활성 시 모든 파일 frontmatter에 `project_id` 태그 필수 (교차 오염 방지)

## 컨텍스트 로드 정책

- `MEMORY.md` (1줄 인덱스, ≤200줄)는 SessionStart 훅으로 자동 주입
- 개별 메모리 파일은 **필요 시 Claude가 읽기** (Progressive Disclosure, v3.3 §2 맥락)
- 전체 자동 로드 금지 (컨텍스트 오염 방지)

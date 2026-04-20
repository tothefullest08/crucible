---
name: plan
description: |
  구현 계획 수립 (한·영) / Implementation planning with hybrid Markdown + YAML frontmatter.
  Use when a requirements document is ready for task decomposition, evaluation principles, and exit conditions.
  트리거: "plan this", "계획 세워줘", "구현 계획", "implementation plan", "break this down", "태스크 분해"
when_to_use: "요구사항 문서에서 구현 태스크 · 평가 원칙 · exit 조건을 정리할 때"
input: "요구사항 문서 (.claude/plans/YYYY-MM-DD-{slug}-requirements.md 혹은 임의 경로)"
output: ".claude/plans/YYYY-MM-DD-{slug}-plan.md (Markdown 본문 + YAML frontmatter)"
validate_prompt: |
  /plan 자기검증 (Plan 3축):
  1. 산출물 경로가 `.claude/plans/YYYY-MM-DD-{slug}-plan.md` 규약 + slug 화이트리스트([a-zA-Z0-9_-])를 만족하는가?
  2. YAML frontmatter 필수 필드(goal · acceptance_criteria · evaluation_principles[with weights] · exit_conditions · parent_seed_id)가 전부 존재하는가?
  3. 각 태스크가 ID 체계(T-W{주차}-{순번} 또는 자유 ID)와 acceptance criteria를 최소 1개씩 포함하는가?
  4. Ambiguity Score Gate(0.2 임계) 통과 판정이 본문 상단에 명시되는가? (미통과 시 `/brainstorm` 재진입 권고)
  5. 평가 원칙(evaluation_principles)의 weight 합이 1.0 ± 0.05 범위인가?
  6. Exit conditions 3종(성공 · 중단 · 재시도)이 측정 가능한 기준으로 서술되는가?
---

# Plan

> `/brainstorm` 산출물(requirements)을 받아 Markdown 본문 + YAML frontmatter 하이브리드 플랜으로 정제. v3 Dec 10 결정.

## When to Use

구체화된 요구사항이 있지만 구현 태스크로 분해되지 않았을 때. `/brainstorm`이 선행됐거나 수동으로 준비한 requirements.md 경로를 입력으로 받음.

## Protocol

CE `ce-plan` 5-Phase 패턴을 하네스 6축(계획 축)에 맞춰 차용. 각 Phase는 **목표 / 입력 / 동작 / 출력 / 실패 시 fallback** 5섹션으로 고정.

> 6-axis activation: this skill emits **HARD-GATE** signals on axis 3 (Plan) and **hint-level** signals on axes 2 (Context) and 4 (Execution). HARD-GATE 배치 자체는 T-W3-XX 후속 태스크 범위. 본 섹션은 Phase 본문만 정의.

### Phase 1: Intake

**목표**: 요구사항 문서를 파싱해 계획 수립에 필요한 입력(goal · scope · constraints · decisions · open_questions)을 확정하고, 모호도가 `/plan` 게이트 임계를 넘는지 판정한다.

**입력**:
- `$REQUIREMENTS_PATH`: `/brainstorm` 산출물 (`.claude/plans/YYYY-MM-DD-{slug}-requirements.md`) 또는 수동 경로. 절대·상대 경로 모두 허용.
- 선택: 프로젝트 `CLAUDE.md` / `AGENTS.md` (있으면 컨텍스트 참조).

**동작**:
1. `$REQUIREMENTS_PATH` 존재·읽기 권한을 검증한다. 미존재 시 즉시 실패.
2. `yq` 로 frontmatter(`lens` · `topic` · `decisions[]` · `stop_doing[]` · `open_questions[]`)를 파싱한다.
3. 본문에서 `## Goal` · `## Scope` (Included / Excluded) · `## Constraints` · `## Success Criteria` 섹션을 `awk`로 추출한다.
4. **Ambiguity Score Gate 호출** — `bash scripts/ambiguity-gate.sh "$REQUIREMENTS_PATH"` 를 실행하고 stdout JSON의 `verdict` 필드로 분기한다. v3.1 §4.3 보안 제약(쌍따옴표 변수 · `eval` 금지)을 엄수.
5. verdict가 `reject`면 사용자에게 `AskUserQuestion` (Claude Code) 또는 그 platform 상응 도구로 재-`/brainstorm` 여부를 묻는다. 플랫폼 도구 부재 시 번호 옵션 제시 후 대기.
6. 컨텍스트 수집 루틴(local research)은 CE ce-plan §1.1 패턴을 축약한다 — Task 도구가 있을 때 `research:ce-repo-research-analyst` 등을 병렬 호출, 부재 시 로컬 `Glob`/`Grep`으로 패턴·기존 파일 파악.

**출력**: 메모리 상 `intake_record` (아직 디스크 저장 없음) —
```yaml
goal: <string>
scope:
  included: [...]
  excluded: [...]
constraints: [...]
decisions: [...]          # frontmatter carry-over
open_questions: [...]
ambiguity_score: 0.XX
ambiguity_verdict: pass | reject
```

**실패 시 fallback**:
- 파일 미존재 → 사용자에게 경로 확인 요청 후 중단. 추측 경로 사용 금지.
- frontmatter 파싱 실패 → `yq` 에러 메시지 전체를 사용자에게 그대로 표시하고 재작성 권고 (`/brainstorm` 재실행).
- verdict=reject → **Phase 2 이후 진입 금지**. 재-`/brainstorm` 또는 수동 보강 후 재실행.
- 컨텍스트 수집 도구 부재 → 경고만 출력하고 local 파일 탐색만으로 계속 진행 (Plan 축 핵심 경로가 아님).

---

### Phase 2: Decomposition

**목표**: 확정된 요구사항을 주차(W) · 태스크(T) 단위 구현 단위(Implementation Unit)로 분해하고, 의존성 그래프와 Model Tiering(포팅 자산 #15)을 지정한다.

**입력**: Phase 1의 `intake_record`, Phase 1 local research 결과.

**동작**:
1. Plan 깊이를 **Lightweight / Standard / Deep** 중 하나로 분류한다 (CE ce-plan §0.6 계승). 분류 불명확 시 `AskUserQuestion` 1회로 확정.
2. Goal → 구현 단위(Implementation Unit) 목록으로 분해한다. 각 단위는:
   - 하나의 원자적 커밋 단위에 대응
   - 영향 파일은 **repo-relative 경로만** 사용 (v3.1 §4.3 포터빌리티)
   - 의존성(`depends_on`)으로 순서 명시
3. **Model Tiering 지정 (포팅 자산 #15)** — 각 단위에 다음 역할 중 하나를 부여한다:
   - `orchestrator`: 전체 계획 · 의사결정 · 교차 주차 합치 → Opus 권장
   - `subagent`: 개별 기능 구현 · 중간 추론 → Sonnet / mid-tier 권장
   - `validator`: 린트 · 스키마 검증 · 단일 반환값 체크 → Haiku 권장
   이 힌트는 `/plan` 산출물의 각 단위 `model_tier` 필드로 기록된다 (강제 아님, 참고).
4. 의존성 그래프를 Markdown 또는 Mermaid로 작성한다 (단위 4개 이상일 때 Mermaid 권장).
5. 각 단위에 **Test Scenarios** (happy · edge · error · integration) 카테고리 중 해당되는 것만 enumerate. Non-feature-bearing 단위는 `Test expectation: none — <reason>` 으로 명시.

**출력**: 메모리 상 `decomposition_record` —
```yaml
depth: lightweight | standard | deep
units:
  - id: U1
    goal: ...
    files: [...]
    depends_on: []
    model_tier: orchestrator | subagent | validator
    test_scenarios: [...]
  - id: U2
    depends_on: [U1]
    ...
```

**실패 시 fallback**:
- 단위 수가 15개를 초과하면 **Deep** 재분류 + 주차 단위 그룹핑을 강제. CE ce-plan는 4-8을 권장하나 하네스 W-태스크 분해는 주차당 6-10이 현실적.
- 순환 의존성 감지 시 중단하고 사용자에게 재-디자인 요청.
- Model Tiering 판단 불가 → 기본값 `subagent` 로 고정 + 사용자 확인 노트.

---

### Phase 3: Evaluation Principles

**목표**: 계획의 성공·실패를 판정할 `evaluation_principles` (qa-judge 입력이 되는 평가 기준)을 정의하고, weight 합이 **정확히 1.0** 임을 assertion 으로 검증한다.

**입력**: Phase 1 Success Criteria, Phase 2 분해 결과, (선택) 도메인별 사전 정의 principle 라이브러리.

**동작**:
1. Success Criteria의 각 항목을 최소 1개의 principle로 매핑한다.
2. 각 principle은 4필드를 가진다:
   - `name`: snake_case 식별자
   - `weight`: 0.0–1.0 float, 전체 합 = 1.0
   - `description`: 1줄 자연어 설명
   - `metric`: 측정 방식 (예: `"unit_test pass ratio"`, `"qa-judge score >= 0.8"`)
3. weight 합을 `jq` 또는 bash 연산으로 검증. |sum − 1.0| > 0.001 이면 **즉시 실패**하고 재배분 요청.
4. qa-judge 회색지대(0.40~0.80, v3.1 §2.2 결정 #11) 재검증 대상이 될 principle을 플래그 지정 (MVP는 스텁).

**출력**: `evaluation_principles[]` 배열 (frontmatter에 직렬화될 예정 — 스키마는 T-W3-03 범위).

**실패 시 fallback**:
- weight 합 mismatch → 사용자에게 재배분 요구. 자동 정규화 **금지** (설계 의도를 왜곡할 수 있음).
- principle 수 0개 → Success Criteria 재작성 요구.
- Success Criteria 자체가 측정 불가 → Phase 1 verdict가 `pass` 였더라도 여기서 중단하고 `/brainstorm` 재실행 권고.

---

### Phase 4: Gap Analysis

**목표**: 요구사항 문서 또는 분해 결과에서 **미결 항목 · 누락 요구사항 · 암묵 가정**을 추출해 계획 확정 전에 surfacing 한다. hoyeon `gap-analyzer` 에이전트 개념을 하네스 스텁(bash+jq)으로 포팅.

**입력**: `$REQUIREMENTS_PATH`, Phase 1~3 기록.

**동작**:
1. `bash scripts/gap-analyzer.sh "$REQUIREMENTS_PATH"` 를 호출한다. MVP는 정적 휴리스틱 스텁 (`## Scope`에 `Excluded` 누락 · Success Criteria 측정 불가 · frontmatter `decisions` 비어있음 · Constraints `TBD` 포함 등).
2. 반환 JSON 리스트의 각 항목을 사용자에게 표시하고 결정 경로를 분기한다:
   - **결정 가능**: 해당 gap을 현재 계획에 통합 (Phase 2·3 보강).
   - **결정 불가**: `open_questions` 배열에 이월 (frontmatter).
   - **의도적 배제**: `scope.excluded` 에 명시.
3. LLM 기반 심화 gap 분석은 W4 이후 `research:ce-learnings-researcher` 등과 연동 (MVP 범위 밖).

**출력**: `gap_resolutions[]` 배열 + Phase 2·3 업데이트 반영.

**실패 시 fallback**:
- `scripts/gap-analyzer.sh` 실행 실패 (shellcheck · 권한 · jq 부재) → 사용자에게 에러 표시하고 수동 gap 체크리스트로 전환 (아래 4항목 최소 검증):
  - Scope Excluded 명시됨
  - Success Criteria 측정 가능
  - Decisions ≥ 1
  - Constraints에 TBD 없음
- gap 수 > 10 → 계획 저장 전 `/brainstorm` 재-round 권고.

---

### Phase 5: Finalize + Save

**목표**: Phase 1~4 결과를 하이브리드 포맷(Markdown 본문 + YAML frontmatter, v3.1 §2.2 결정 #10)으로 직렬화하고, 파일명 slug 화이트리스트를 통과시킨 뒤 `.claude/plans/` 하위에 저장한다.

**입력**: `intake_record` · `decomposition_record` · `evaluation_principles[]` · `gap_resolutions[]`.

**동작**:
1. 출력 템플릿(`skills/plan/templates/plan-template.md`, T-W3-03 산출물)을 로드한다. 템플릿 부재 시 본 SKILL.md 하단 Output Schema 설명으로 fallback.
2. `date = YYYY-MM-DD` (시스템 날짜) + `slug` 계산 (`goal` 혹은 frontmatter `topic`에서 lowercase · 공백→`-` · 비허용 문자 제거).
3. slug hook (`scripts/plan-slug-hook.sh`, T-W3-06 산출물)로 **슬러그 화이트리스트 `[a-zA-Z0-9_-]` 통과 여부 검증**. 실패 시 **파일 저장 중단** + 사용자에게 재입력 요청 (v3.1 §4.3 보안 제약).
4. weight 합 1.0 재확인 (Phase 3 assertion 재실행, 2차 방어).
5. 파일명: `.claude/plans/{date}-{slug}-plan.md`. 이미 존재하면 사용자에게 (overwrite / `-v2` / abort) 3지선다 제시.
6. 저장 후 절대 경로를 최종 응답의 마지막 줄에 에코하고, 다음 단계로 `/verify` 호출을 제안한다.

**출력**: 디스크 상 `.claude/plans/YYYY-MM-DD-{slug}-plan.md` (Markdown 본문 + YAML frontmatter).

**실패 시 fallback**:
- slug 검증 실패 → 저장 금지, 사용자 재입력 요청. 자동 치환 금지.
- weight 재확인 실패 → Phase 3 로 회귀.
- 파일 충돌에 3지선다 응답 없음 → 기본값 `abort` (데이터 보존 우선).
- 템플릿 파일 부재 (T-W3-03 선행 실패) → 경고 로그 + Output Schema 기반 최소 포맷으로 저장 (단위 테스트 AC-2 충족 목적).

## Integration Points

- **입력**: `/brainstorm`의 requirements.md (또는 수동 작성)
- **출력**: `.claude/plans/YYYY-MM-DD-{slug}-plan.md` — Markdown 본문 + YAML frontmatter 하이브리드
- **다음 단계**: `/verify` (plan 산출물 검증), `/compound` (학습 승격)
- **사전 게이트**: Ambiguity Score Gate (T-W3-05, 0.2 임계)

## Output Schema

output 파일의 frontmatter 구조는 `skills/plan/templates/plan-template.md` 참조 (T-W3-03 산출).
주요 필드: `goal`, `constraints`, `AC`, `evaluation_principles` (weight 합 1.0), `exit_conditions`, `parent_seed_id`.

## TODO (후속 주차 작업)

| 태스크 | 범위 | 주차 |
|-------|------|------|
| T-W3-02 | Phase 1~5 본문 완성 (CE 5-Phase) | W3 |
| T-W3-03 | `templates/plan-template.md` YAML 스키마 | W3 |
| T-W3-04 | gap-analyzer 호출 레이어 | W3 |
| T-W3-05 | Ambiguity Score Gate (0.2 임계) | W3 |
| T-W3-06 | output slug hook | W3 |
| T-W3-07 | `validate_prompt` frontmatter 필드 (계획 축 자기검증) | W3 |
| T-W3-08 | 3 샘플 unit test → AC-3 | W3 |
| T-W3-09 | 한·영 사용 예제 README | W3 |

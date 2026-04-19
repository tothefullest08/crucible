---
name: verify
description: |
  산출물 검증 / Artifact verification with qa-judge + Ralph Loop.
  Use when a plan or implementation output requires scoring, gray-zone dispatch, or Ralph-style retry.
  트리거: "verify this", "검증해줘", "qa-judge", "Ralph Loop", "산출물 검증", "재시도"
when_to_use: "스킬·에이전트 산출물을 평가자 서브에이전트가 회의적 관점에서 채점하고 임계값 분기(승격/재시도/기각)를 수행할 때"
input: "산출물 경로 + (선택) --axis N · --acknowledge-risk"
output: "qa-judge JSON 리포트 (score/verdict/dimensions/differences/suggestions) + 승격/재시도 결정"
validate_prompt: |
  /verify 자기검증 (검증 축):
  1. qa-judge JSON 스키마 5필드 (score, verdict, dimensions, differences, suggestions) 모두 존재하는가?
  2. score가 [0.0, 1.0] 범위인가?
  3. verdict가 promote(≥0.80) / retry(0.40~0.80) / reject(≤0.40) 중 하나인가?
  4. Ralph Loop 재시도 횟수가 상한(기본 3회) 이내인가?
  5. 회색지대 자동 Consensus는 2차 릴리스 분리 유지 — MVP는 수동 승격 fallback인가?
  6. Generator(원 산출물 에이전트)와 Evaluator가 다른 context/fresh session인가?
---

# Verify

> `/plan` 산출물 혹은 구현 결과물을 **회의적으로 튜닝된 Evaluator 서브에이전트**로 채점하고, 임계값(0.80 / 0.40)에 따라 승격·재시도·기각을 분기. Ralph Loop로 재시도 자동화. v3.1 §2.1 #5 (Evaluator 분리) + §2.2 Dec 11 (Consensus 회색지대 자동, 2차).

## When to Use

- `/plan` 산출물(plan.md)을 실행 전 품질 검증
- 구현된 코드·문서의 AC 충족도 판정
- Ralph Loop("될 때까지 반복") 자동 재시도가 필요한 작업
- 컴파운딩 승격 게이트(§11-3)의 점수 산출

## Protocol

각 Phase는 **목표 / 입력 / 동작 / 출력 / 실패 시 fallback** 5섹션 고정.

### Phase 1: Intake

(T-W4-XX에서 확장 예정 — 검증 대상 파일 읽기 + 축 선택 + 필수 컨텍스트 수집)

### Phase 2: Evaluator Dispatch

(T-W4-02·03에서 확장 예정 — 6-에이전트 스택 중 축별 선택, qa-judge 호출)

### Phase 3: Scoring & Threshold

(T-W4-03·08에서 확장 예정 — qa-judge JSON 스키마 수신, 임계값 분기 `>=0.80 promote / 0.40~0.80 retry / <=0.40 reject`)

### Phase 4: Ralph Loop (retry branch)

**목표**: qa-judge `verdict: "retry"` (0.40 < score < 0.80 회색지대)에 대해 최대 3회 자동 재시도. 3회 모두 실패 시 수동 승격 fallback으로 에스컬레이션 (v3.2 §2.2 Dec 11).
**입력**: Phase 3 JSON 리포트 + `artifact_path` + `retry_budget`(기본 3)
**동작**: 아래 의사코드를 따라 non-blocking + level-based polling으로 재시도를 수행한다 (ouroboros 포팅 자산 #2 — `references/ouroboros/skills/ralph/SKILL.md:50-99` 커버리지 ≥ 80%).

```
# Ralph Loop pseudocode — ported from ouroboros, adapted to bash+jq harness
iteration = 0
max_iterations = 3
verification_history = []
session_id = uuidgen

while iteration < max_iterations:

    # 1) Kick off a fresh regeneration in background — returns job_id immediately
    job = start_evolve_step(
        lineage_id   = session_id,
        seed_content = artifact_path,
        execute      = true
    )
    job_id, cursor = job.meta.job_id, job.meta.cursor

    # 2) Level-based polling — wait up to 120s per level, only report on AC advance
    prev_completed = 0
    terminal = false
    while not terminal:
        wait_result = job_wait(job_id, cursor, timeout_seconds=120)
        cursor      = wait_result.meta.cursor
        status      = wait_result.meta.status
        current_completed = parse_ac_completed(wait_result)
        if current_completed > prev_completed:
            emit("[Level complete] AC: {current_completed}/{total} | phase: {phase}")
            prev_completed = current_completed
        terminal = status in ("completed", "failed", "cancelled")

    # 3) Fetch final artifact + re-run qa-judge in a FRESH evaluator context
    result  = job_result(job_id)
    verdict = qa_judge(result.artifact)          # re-score this iteration
    verification_history.append({
        "iteration": iteration,
        "score":     verdict.score,
        "verdict":   verdict.verdict             # promote | retry | reject
    })

    # 4) Branch on verdict
    if verdict.verdict == "promote":
        return { status: "promoted", history: verification_history }
    if verdict.verdict == "reject":
        return { status: "rejected", history: verification_history }

    iteration = iteration + 1   # retry grey-zone

# 5) Exhausted retries — MVP fallback is MANUAL promotion, not auto-Consensus (v3.2 §2.2 Dec 11)
return {
    status:    "escalate_manual",
    reason:    "retry_budget_exhausted",
    history:   verification_history,
    next_step: "user decides promote / reject; auto-Consensus defers to 2차 릴리스"
}
```

**출력**: 위 블록 중 하나의 JSON (`promoted` / `rejected` / `escalate_manual`)을 Phase 5로 전달.
**실패 시 fallback**: `escalate_manual`로 수렴되면 사용자 확인 후 수동으로 promote 또는 reject. 자동 Consensus 회색지대 해소는 2차 릴리스 범위 (v3.2 §2.2 Dec 11).

**키 불변식**:
- 재시도 상한 3회 (하드 캡).
- 각 iteration의 Evaluator는 Generator와 **다른 context / fresh session** — 자기검증 편향 제거 (§2.1 #5).
- `verification_history`는 모든 iteration의 score·verdict를 남겨 승격 게이트(§11-3) 판정에 활용.
- polling은 level-based (AC 완료 개수 변화 시에만 보고) — 컨텍스트 소비 최소화.

### Phase 5: Report & Promote

(T-W4-XX에서 확장 예정 — JSON 리포트 출력 + 승격 큐 전송 or reject 사유 로그)

## Integration Points

- **입력**: `/plan` 산출물(plan.md) · 임의 구현 파일
- **출력**: qa-judge JSON (score·verdict·dimensions·differences·suggestions)
- **다음 단계**:
  - `promote`: `/compound` 승격 게이트로 전달
  - `retry`: Ralph Loop 자동 재실행 (상한 내) 또는 사용자 수동 승격
  - `reject`: 이력 `corrections/_rejected/`로 저장 (W5·W6 구현)
- **보안**: §4.3.5 페이로드 SHA256 · §4.3.6 훅 실행 순서 · §4.3.7 부정 문맥 준수

## TODO (W4 후속 태스크)

| 태스크 | 범위 | 공수 |
|-------|------|------|
| T-W4-02 | `agents/verify/` 6-에이전트 스텁 | 8h (4h W7.5 이월) |
| T-W4-03 | `agents/evaluator/qa-judge.md` JSON 스키마 | 4h |
| T-W4-04 | Ralph Loop 의사코드 본문 | 4h |
| T-W4-05 | `validate_prompt` + 페이로드 SHA256 검증 | 4h |
| T-W4-06 | Secrets redaction 정규식 7종 | 6h |
| T-W4-07 | `hooks/drift-monitor.sh` (bash+jq 재작성) | 4h |
| T-W4-08 | qa-judge 임계값 분기 3종 unit test → AC-4 | 2h |

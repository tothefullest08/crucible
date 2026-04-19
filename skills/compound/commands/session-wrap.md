---
name: session-wrap
description: "세션 종료 승격 후보 큐 일괄 제시 / Session-end promotion queue review"
when_to_use: "세션 종료 직전 또는 유저가 수동 호출 시 현재 누적된 승격 후보를 y/N/e/s로 처리"
---

# /session-wrap — 세션 종료 승격 후보 일괄 처리 (T-W6-07)

> v3.3 §3.4 Step 4 · §3.4.4 Consent fatigue 완화.
> 수동 호출 시 `.claude/state/promotion_queue/` 전체를 승격 게이트로 제시.

## When to Use

- **수동 호출**: 유저가 `/session-wrap` 입력
- **자동 호출**: Stop hook (`hooks/stop.sh`) 가 세션 종료 시점에 동일 파이프라인 실행

본 명령은 **Mid-session 중단 금지** 원칙에 따라 "누적 후보 재제시"로만 사용된다.
세션 중간에 호출해도 안전하다 — y/N/e/s 로 건별 처리 후 큐에서 제거된다.

## Protocol

### Phase 1: 큐 스캔

`.claude/state/promotion_queue/*.yaml` 을 스코어 내림차순으로 정렬. 3-트리거
각각에서 적재된 후보를 하나의 배치로 합친다. 최대 10건/세션 (§3.4.4).

### Phase 2: 게이트 제시

`hooks/stop.sh` 본체를 그대로 호출:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/hooks/stop.sh" \
    --memory-root ".claude/memory" \
    --state-root  ".claude/state"
```

스크립트는 각 후보에 대해 `scripts/promotion-gate.sh` 를 실행하고, `y/N/e/s`
응답을 stdin 으로 받아 처리한다.

### Phase 3: 응답 키 (기본 N)

| 키 | 의미 | 다음 동작 |
|----|------|----------|
| `y` | 승인 | `.claude/memory/{tacit\|corrections\|preferences}/` 저장 + MEMORY.md 인덱스 |
| `N` | 거부 (기본값) | `corrections/_rejected/<candidate_id>.md` 이력 + detector 거부 카운터 +1 |
| `e` | 수정 후 승인 | 본문 수정 프롬프트 → 승인 |
| `s` | 건너뛰기 | 다음 `session_wrap` 에서 재제시 (큐 보존) |

### Phase 4: Consent Fatigue 가드

- 동일 `detector_id` 가 3회 연속 거부되면 `.claude/state/detector-status.json`
  에 `disabled_until: <now + 7d>` 기록 (§3.4.4). 해당 detector 는 7일간
  비활성화된다.
- `/compound --reactivate <detector_id>` 로 수동 복구.

## Input

없음 (stdin 으로 큐 파일을 직접 받지 않음). `.claude/state/promotion_queue/`
현재 상태를 읽는다.

## Output

- **stdout**: 후보별 NDJSON 결과 + 마지막 `{"summary":{...}}` (stop.sh 계약 동일)
- **stderr**: 후보별 gate-dialog ASCII wireframe (§3.4.5)
- **side effects**: 승인/거부/수정에 따른 memory/rejected 파일 쓰기

## Integration Points

- **입력**: `.claude/state/promotion_queue/*.yaml` (T-W6-05·06 + 본 태스크 Stop hook)
- **내부 호출**: `hooks/stop.sh` → `scripts/promotion-gate.sh` → `scripts/track-router.sh`
- **템플릿**: `skills/compound/templates/gate-dialog.md`

## Failure Modes

| 실패 조건 | Fallback |
|-----------|----------|
| 큐 디렉토리 없음 | 배너 "no pending candidates" 1줄 출력 후 정상 종료 |
| `hooks/stop.sh` 미존재 | stderr 에 경로 명시 + exit 2 |
| `yq` 미설치 | stop.sh 가 자체 exit 2 (bash/jq/yq만 허용 — v3.3 §4.1) |

## Notes

- 본 커맨드는 감지 자체는 수행하지 않는다. 큐 적재는 T-W6-05·06 detector 의
  책임이며, `/session-wrap` 은 **제시 단계** 만 담당한다.
- AC-6 수동 트리거 검증에 쓰이는 기본 진입점 (`test-ac6-compound-triggers.sh`).

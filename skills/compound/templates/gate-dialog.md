# 승격 게이트 UX 템플릿 (gate-dialog)

> v3.3 §3.4 Step 4 · T-W5-06 · Stop hook 일괄 제시용.
> 템플릿은 `promotion-gate.sh` 가 치환 변수를 채워 stderr 에 출력한다.

## 배너

```
════════════════════════════════════════════════════════════════
  Harness Compound — 세션 종료 승격 후보 ({{COUNT}}건)
  세션: {{SESSION_ID}} · turn {{TURN_RANGE}}
════════════════════════════════════════════════════════════════
```

## 후보 블록 (1건당)

```
[{{INDEX}}/{{COUNT}}] {{BADGE}} score={{SCORE}} · trigger={{TRIGGER_SOURCE}}
  저장 경로: {{SUGGESTED_PATH}}
  요약: "{{CONTENT_SUMMARY}}"
  source: {{SESSION_ID}} · turn {{TURN_RANGE}}
  dimensions: {{TOP_DIMENSIONS}}

  [y]승인  [N]거부  [e]수정 후 승인  [s]건너뛰기
  > _
```

## 치환 변수

| 변수 | 설명 |
|------|------|
| `{{COUNT}}` | 현재 큐의 후보 총 개수 |
| `{{INDEX}}` | 1부터 시작하는 현재 후보 순번 |
| `{{BADGE}}` | score 기반 배지 (🟢 ≥0.80, 🟡 0.40-0.80, 🔴 ≤0.40) |
| `{{SCORE}}` | qa-judge 점수 (소수점 2자리) |
| `{{TRIGGER_SOURCE}}` | `pattern_repeat` / `user_correction` / `session_wrap` |
| `{{SUGGESTED_PATH}}` | `track-router.sh` 로 결정된 저장 경로 |
| `{{CONTENT_SUMMARY}}` | content 첫 80자 + `…` |
| `{{SESSION_ID}}` | `sess_<YYYYMMDD>_<HHMMSS>` |
| `{{TURN_RANGE}}` | `<start>-<end>` |
| `{{TOP_DIMENSIONS}}` | dim 2개 요약 (예: `correctness=0.90 · clarity=0.85`) |

## 응답 키 (v3.3 §3.4.3)

| 키 | 의미 | 다음 동작 |
|----|------|----------|
| `y` | 승인 | Step 5 저장 (track-router → `.claude/memory/{tacit|corrections|preferences}/`) |
| `N` | 거부 (기본값) | Step 6 이력 (`corrections/_rejected/` + `_rejections.log`) |
| `e` | 수정 후 승인 | 별도 프롬프트로 content 편집 → Step 5 저장 |
| `s` | 건너뛰기 | 큐에 남김 (다음 session_wrap 에서 재제시) |

## 기본값 정책

- Enter 만 누르면 `N` (거부). 오염 방지가 핵심(§2.1 #6).
- `/session-wrap` 수동 트리거 와 Stop hook 자동 트리거 모두 동일 UI 재사용.
- mid-session 중단 금지 — Stop 시점에만 제시.

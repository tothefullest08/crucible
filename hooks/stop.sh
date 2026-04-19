#!/usr/bin/env bash
# hooks/stop.sh — T-W5-07 · v3.3 §3.4 Step 4 · Stop hook 일괄 제시
#
# Claude Code Stop 이벤트에서 호출. `.claude/state/promotion_queue/` 하위
# 후보 전부를 읽어 promotion-gate.sh 에 일괄 전달한다. 각 후보의 거부
# 누적 상태는 `.claude/state/detector-status.json` 에 기록되며, 동일
# detector_id 가 3회 연속 거부되면 `disabled_until: <now + 7d>` 을
# 자동 설정한다 (v3.3 §3.4.4 consent fatigue 완화).
#
# 사용법:
#   hooks/stop.sh [--memory-root <dir>] [--state-root <dir>] \
#                 [--response <y|N|e|s>]   # 전체 후보에 동일 응답 (fixture 전용)
#                 [--edited-content <file>] # --response e 전용
#
# 출력 (stdout):
#   NDJSON — 후보별 promotion-gate.sh 결과 1라인.
#   마지막 1줄: {"summary":{"processed":N,"approved":A,"rejected":R,"edited":E,"skipped":S}}
#
# 상태 파일 (`.claude/state/detector-status.json`):
#   {
#     "detectors": {
#       "<detector_id>": {
#         "consecutive_rejects": N,
#         "disabled_until": "<ISO8601 UTC>" | null,
#         "last_rejected_at": "<ISO8601 UTC>" | null
#       }
#     }
#   }
#
# 3회 연속 거부 임계값:
#   • 거부 시 consecutive_rejects += 1 + last_rejected_at 갱신
#   • 승인/편집/스킵은 reset 하지 않음 (§3.4.4 "동일 패턴 3회 연속 거부")
#     ※ MVP 에서는 거부 카운터만 누적. 승인 시 리셋은 2차 릴리스 검토 항목.
#   • consecutive_rejects 가 3 도달 시 disabled_until = now + 7d
#
# 보안 (§4.3 P0-8):
#   • set -euo pipefail · "$var" · eval 금지

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATE="${REPO_ROOT}/scripts/promotion-gate.sh"

if [[ ! -x "$GATE" ]]; then
  echo "Error: promotion-gate.sh not found: $GATE" >&2
  exit 2
fi

# --- 인자 파싱 ----------------------------------------------------------------

MEMORY_ROOT=".claude/memory"
STATE_ROOT=".claude/state"
RESPONSE=""
EDITED_CONTENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --memory-root)    MEMORY_ROOT="$2"; shift 2 ;;
    --state-root)     STATE_ROOT="$2"; shift 2 ;;
    --response)       RESPONSE="$2"; shift 2 ;;
    --edited-content) EDITED_CONTENT="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0" >&2; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

STATUS_FILE="${STATE_ROOT}/detector-status.json"
QUEUE_DIR="${STATE_ROOT}/promotion_queue"

mkdir -p "$STATE_ROOT"
if [[ ! -f "$STATUS_FILE" ]]; then
  printf '%s\n' '{"detectors":{}}' > "$STATUS_FILE"
fi

# --- 보조 함수 ----------------------------------------------------------------

iso_now() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }

iso_plus_7d() {
  # GNU/BSD date 호환 — +7d
  if date -u -v+7d +'%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
    date -u -v+7d +'%Y-%m-%dT%H:%M:%SZ'
  else
    date -u -d '+7 days' +'%Y-%m-%dT%H:%M:%SZ'
  fi
}

# detector 상태 갱신 (거부 시에만 호출)
bump_reject_counter() {
  local detector_id="$1"
  local now_iso
  now_iso="$(iso_now)"

  local current_count
  current_count="$(jq -r --arg d "$detector_id" \
    '.detectors[$d].consecutive_rejects // 0' "$STATUS_FILE")"
  local new_count=$((current_count + 1))

  local disabled_until="null"
  if [[ "$new_count" -ge 3 ]]; then
    local until_iso
    until_iso="$(iso_plus_7d)"
    disabled_until="$(jq -nc --arg v "$until_iso" '$v')"
  fi

  local tmp
  tmp="$(mktemp)"
  jq \
    --arg d "$detector_id" \
    --argjson c "$new_count" \
    --argjson du "$disabled_until" \
    --arg now "$now_iso" \
    '
    .detectors = (.detectors // {})
    | .detectors[$d] = {
        consecutive_rejects: $c,
        disabled_until: $du,
        last_rejected_at: $now
      }
    ' "$STATUS_FILE" > "$tmp"
  mv "$tmp" "$STATUS_FILE"
}

is_detector_disabled() {
  local detector_id="$1"
  local until
  until="$(jq -r --arg d "$detector_id" \
    '.detectors[$d].disabled_until // "null"' "$STATUS_FILE")"
  if [[ "$until" == "null" || -z "$until" ]]; then
    return 1
  fi
  # until 이 now 보다 미래면 disabled
  local now_iso
  now_iso="$(iso_now)"
  # ISO8601 UTC 문자열 비교 (Z 접미사 공통) 는 정렬 비교 가능
  [[ "$until" > "$now_iso" ]]
}

# --- 큐 스캔 및 처리 ----------------------------------------------------------

if [[ ! -d "$QUEUE_DIR" ]]; then
  echo '{"summary":{"processed":0,"approved":0,"rejected":0,"edited":0,"skipped":0}}'
  exit 0
fi

processed=0
approved=0
rejected=0
edited=0
skipped=0
disabled_skips=0

# LC_ALL=C sort 로 결정적 순서
mapfile -t QUEUE_FILES < <(find "$QUEUE_DIR" -maxdepth 1 -type f -name '*.yaml' 2>/dev/null | LC_ALL=C sort)

total="${#QUEUE_FILES[@]}"
if [[ "$total" -eq 0 ]]; then
  echo '{"summary":{"processed":0,"approved":0,"rejected":0,"edited":0,"skipped":0}}'
  exit 0
fi

idx=0
for cand in "${QUEUE_FILES[@]}"; do
  idx=$((idx + 1))

  # detector_id 선확인 → 비활성이면 이 세션 skip 하고 다음 세션 재제시
  detector_id_field="$(yq -r '.detector_id // ""' "$cand")"
  if [[ -z "$detector_id_field" ]]; then
    trig="$(yq -r '.trigger_source // ""' "$cand")"
    cid="$(yq -r '.candidate_id // ""' "$cand")"
    detector_id_field="${trig}:${cid:0:8}"
  fi

  if is_detector_disabled "$detector_id_field"; then
    disabled_skips=$((disabled_skips + 1))
    jq -nc \
      --arg d "$detector_id_field" \
      --arg f "$cand" \
      '{action:"disabled_skip",detector_id:$d,candidate:$f}'
    continue
  fi

  # promotion-gate.sh 호출
  gate_args=("$cand" --memory-root "$MEMORY_ROOT" --state-root "$STATE_ROOT" \
             --index "$idx" --count "$total")
  if [[ -n "$RESPONSE" ]]; then
    gate_args+=(--response "$RESPONSE")
  fi
  if [[ -n "$EDITED_CONTENT" ]]; then
    gate_args+=(--edited-content "$EDITED_CONTENT")
  fi

  # promotion-gate.sh stderr 는 dialog UX (사용자에게 표시용). stdout 만 캡처.
  result="$("$GATE" "${gate_args[@]}" 2>/dev/null)"
  echo "$result"

  action="$(printf '%s' "$result" | jq -r '.action')"
  processed=$((processed + 1))

  case "$action" in
    approved)
      approved=$((approved + 1))
      ;;
    edited_approved)
      edited=$((edited + 1))
      ;;
    rejected)
      rejected=$((rejected + 1))
      det_id="$(printf '%s' "$result" | jq -r '.detector_id')"
      bump_reject_counter "$det_id"
      # 거부 완료 후 큐 파일 제거
      rm -f "$cand"
      ;;
    skipped)
      skipped=$((skipped + 1))
      ;;
    *)
      echo "Warning: unknown action '$action'" >&2
      ;;
  esac

  # 승인/편집 후에는 큐에서 제거 (skip 은 유지)
  if [[ "$action" == "approved" || "$action" == "edited_approved" ]]; then
    rm -f "$cand"
  fi
done

# 요약 라인
jq -nc \
  --argjson p "$processed" \
  --argjson a "$approved" \
  --argjson r "$rejected" \
  --argjson e "$edited" \
  --argjson s "$skipped" \
  --argjson ds "$disabled_skips" \
  '{summary:{processed:$p,approved:$a,rejected:$r,edited:$e,skipped:$s,disabled_skips:$ds}}'

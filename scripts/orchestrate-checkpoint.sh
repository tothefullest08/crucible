#!/usr/bin/env bash
# scripts/orchestrate-checkpoint.sh — T-W7-05 · 포팅 #17 (ouroboros)
#
# Mandatory Disk Checkpoints — /orchestrate 파이프라인의 CP-0~CP-5 기록 라이브러리.
# 모든 단계 종료 시 experiment-log.yaml 에 디스크 기록 강제.
#
# 본 파일은 **라이브러리 모드** (source) 와 **CLI 모드** 를 모두 지원한다.
#
# CLI 사용법:
#   orchestrate-checkpoint.sh init   <run_dir> <topic> [skip_axes] [dispatch_mode]
#   orchestrate-checkpoint.sh write  <run_dir> <cp_name> <status> <data_json>
#   orchestrate-checkpoint.sh get    <run_dir> <cp_name> [.field]
#   orchestrate-checkpoint.sh list   <run_dir>
#
# 라이브러리 사용법 (source):
#   source scripts/orchestrate-checkpoint.sh
#   cp_write "$RUN_DIR" CP-1 done '{"requirements_path":"..."}'
#
# 체크포인트 스펙:
#   CP-0 Intake     : {run_id, topic, skip_axes, dispatch_mode, started_at}
#   CP-1 Brainstorm : {requirements_path, turn_count, started_at, completed_at}
#   CP-2 Plan       : {plan_path, task_count, completed_at}
#   CP-3 Verify     : {qa_score, verdict, ralph_loop_iterations, completed_at}
#   CP-4 Compound   : {promoted_count, rejected_count, completed_at}
#   CP-5 Finalize   : {total_duration_sec, artifacts_paths, completed_at}
#
# 저장 포맷 (YAML):
#   run_id: <uuid>
#   topic: "<input>"
#   checkpoints:
#     CP-0: { timestamp: ..., status: done, data: {...} }
#     CP-1: { ... }
#
# 종료 코드:
#   0 — 정상
#   1 — 입력 오류
#   2 — 런타임 의존성 부재 (jq/yq)
#   3 — CP 순서 위반 (예: CP-3 없이 CP-4)

set -euo pipefail

# --- 런타임 선행 검증 ----------------------------------------------------------

_cp_require_deps() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required (brew install jq)" >&2
    return 2
  fi
  if ! command -v yq >/dev/null 2>&1; then
    echo "Error: yq is required (brew install yq)" >&2
    return 2
  fi
}

# 유효 CP 이름: CP-0..CP-5
_cp_valid_name() {
  case "$1" in
    CP-0|CP-1|CP-2|CP-3|CP-4|CP-5) return 0 ;;
    *) return 1 ;;
  esac
}

# 유효 status: done|failed|skipped|paused|active|pending
_cp_valid_status() {
  case "$1" in
    done|failed|skipped|paused|active|pending) return 0 ;;
    *) return 1 ;;
  esac
}

# 파일 잠금 — flock 이 있으면 flock, 없으면 mkdir-lock 폴백
_cp_with_lock() {
  local lockfile="$1"
  shift
  if command -v flock >/dev/null 2>&1; then
    # shellcheck disable=SC2094
    (
      exec 9>"$lockfile"
      flock -x 9
      "$@"
    )
  else
    local lockdir="${lockfile}.d"
    local tries=0
    while ! mkdir "$lockdir" 2>/dev/null; do
      tries=$((tries + 1))
      if [[ "$tries" -gt 50 ]]; then
        echo "Error: could not acquire lock: $lockdir" >&2
        return 1
      fi
      sleep 0.1
    done
    # shellcheck disable=SC2064
    trap "rmdir '$lockdir' 2>/dev/null || true" EXIT
    "$@"
    rmdir "$lockdir" 2>/dev/null || true
    trap - EXIT
  fi
}

_cp_now() {
  # UTC ISO8601 초단위
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_cp_log_path() {
  printf '%s/experiment-log.yaml\n' "$1"
}

# cp_init <run_dir> <topic> [skip_axes_csv] [dispatch_mode]
#   run_dir: .claude/state/orchestrate/<run_id>
cp_init() {
  _cp_require_deps || return $?
  local run_dir="${1:-}"
  local topic="${2:-}"
  local skip_axes="${3:-}"
  local dispatch_mode="${4:-sequential×fresh-context×strict}"

  if [[ -z "$run_dir" || -z "$topic" ]]; then
    echo "Error: cp_init needs <run_dir> <topic>" >&2
    return 1
  fi

  mkdir -p "$run_dir"
  local run_id
  run_id="$(basename "$run_dir")"
  local log
  log="$(_cp_log_path "$run_dir")"
  local ts
  ts="$(_cp_now)"

  _cp_with_lock "$log" _cp_init_write \
    "$log" "$run_id" "$topic" "$skip_axes" "$dispatch_mode" "$ts"
}

_cp_init_write() {
  local log="$1" run_id="$2" topic="$3" skip_axes="$4" dispatch_mode="$5" ts="$6"
  # 초기 YAML 문서 생성 — 이미 존재하면 덮어쓰지 않고 반환
  if [[ -s "$log" ]]; then
    return 0
  fi
  # jq 로 JSON 만든 후 yq 로 YAML 로 변환 → 사용자 입력 안전 보간
  jq -n \
    --arg run_id "$run_id" \
    --arg topic "$topic" \
    --arg skip "$skip_axes" \
    --arg disp "$dispatch_mode" \
    --arg ts "$ts" \
    '{
       run_id: $run_id,
       topic: $topic,
       skip_axes: ($skip | split(",") | map(select(length > 0))),
       dispatch_mode: $disp,
       started_at: $ts,
       checkpoints: {
         "CP-0": {timestamp: $ts, status: "done",
                  data: {run_id: $run_id, topic: $topic,
                         skip_axes: ($skip | split(",") | map(select(length > 0))),
                         dispatch_mode: $disp, started_at: $ts}}
       }
     }' | yq eval -P - >"$log"
}

# cp_write <run_dir> <cp_name> <status> <data_json>
cp_write() {
  _cp_require_deps || return $?
  local run_dir="${1:-}" cp_name="${2:-}" status="${3:-}" data_json="${4:-}"

  if [[ -z "$run_dir" || -z "$cp_name" || -z "$status" ]]; then
    echo "Error: cp_write needs <run_dir> <cp_name> <status> <data_json>" >&2
    return 1
  fi
  if ! _cp_valid_name "$cp_name"; then
    echo "Error: invalid cp name: $cp_name (CP-0..CP-5)" >&2
    return 1
  fi
  if ! _cp_valid_status "$status"; then
    echo "Error: invalid status: $status" >&2
    return 1
  fi
  # 기본값: 빈 객체
  if [[ -z "$data_json" ]]; then
    data_json='{}'
  fi
  # JSON 검증
  if ! printf '%s' "$data_json" | jq empty >/dev/null 2>&1; then
    echo "Error: data_json is not valid JSON" >&2
    return 1
  fi

  local log
  log="$(_cp_log_path "$run_dir")"
  if [[ ! -s "$log" ]]; then
    echo "Error: experiment-log.yaml missing; call cp_init first: $log" >&2
    return 1
  fi

  _cp_with_lock "$log" _cp_write_impl "$log" "$cp_name" "$status" "$data_json"
}

_cp_write_impl() {
  local log="$1" cp_name="$2" status="$3" data_json="$4"
  local ts
  ts="$(_cp_now)"

  # CP 순서 검증: 현재 기록된 최고 CP 번호 + 1 (또는 동일 CP 업데이트)
  local idx="${cp_name#CP-}"
  if [[ "$idx" -gt 0 ]]; then
    local prev="CP-$((idx - 1))"
    local prev_status
    prev_status="$(yq eval ".checkpoints.\"$prev\".status // \"\"" "$log")"
    if [[ -z "$prev_status" ]]; then
      echo "Error: out-of-order checkpoint: $cp_name requires $prev first" >&2
      return 3
    fi
  fi

  # JSON 으로 merge 후 YAML 재기록
  local tmp
  tmp="$(mktemp -t orch-cp.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  yq eval -o=json '.' "$log" \
    | jq \
        --arg name "$cp_name" \
        --arg status "$status" \
        --arg ts "$ts" \
        --argjson data "$data_json" \
        '.checkpoints[$name] = {timestamp: $ts, status: $status, data: $data}' \
    | yq eval -P - >"$tmp"

  mv "$tmp" "$log"
}

# cp_get <run_dir> <cp_name> [.field]
cp_get() {
  _cp_require_deps || return $?
  local run_dir="${1:-}" cp_name="${2:-}" field="${3:-}"
  local log
  log="$(_cp_log_path "$run_dir")"
  if [[ ! -s "$log" ]]; then
    echo "" ; return 0
  fi
  if [[ -z "$field" ]]; then
    yq eval ".checkpoints.\"$cp_name\"" "$log"
  else
    yq eval ".checkpoints.\"$cp_name\"${field}" "$log"
  fi
}

# cp_list <run_dir>  — 모든 기록된 CP 이름과 status 한 줄씩
cp_list() {
  _cp_require_deps || return $?
  local run_dir="${1:-}"
  local log
  log="$(_cp_log_path "$run_dir")"
  if [[ ! -s "$log" ]]; then
    return 0
  fi
  yq eval '.checkpoints | to_entries | .[] | .key + "\t" + .value.status' "$log"
}

# cp_exists <run_dir> <cp_name>
cp_exists() {
  _cp_require_deps || return $?
  local run_dir="${1:-}" cp_name="${2:-}"
  local log
  log="$(_cp_log_path "$run_dir")"
  if [[ ! -s "$log" ]]; then
    return 1
  fi
  local s
  s="$(yq eval ".checkpoints.\"$cp_name\".status // \"\"" "$log")"
  [[ -n "$s" ]]
}

# --- CLI 디스패처 --------------------------------------------------------------

# 소스 모드로 로드되면 CLI 로 빠지지 않음
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    init)   cp_init   "$@" ;;
    write)  cp_write  "$@" ;;
    get)    cp_get    "$@" ;;
    list)   cp_list   "$@" ;;
    exists) cp_exists "$@" ;;
    -h|--help|"")
      sed -n '2,40p' "$0" >&2
      exit 0
      ;;
    *)
      echo "Error: unknown command: $cmd" >&2
      exit 1
      ;;
  esac
fi

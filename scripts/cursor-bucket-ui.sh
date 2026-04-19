#!/usr/bin/env bash
# scripts/cursor-bucket-ui.sh — T-W7-03 · 포팅 #12 (agent-council wait cursor)
#
# 6 bucket 진행 시각화. experiment-log.yaml 을 읽어 CP-0~CP-5 상태를
# ANSI 색상 + cursor spinner 로 stdout 렌더링.
#
# 6 bucket 상태:
#   pending · active · done · skipped · failed · paused
#
# 사용법:
#   cursor-bucket-ui.sh <run_dir>                 # 단발 렌더
#   cursor-bucket-ui.sh --watch <run_dir>         # 1초 간격 반복 (Ctrl+C 종료)
#   cursor-bucket-ui.sh --no-color <run_dir>      # ANSI 끄기
#   cursor-bucket-ui.sh --simulate                # 6 bucket 전이 수동 시뮬레이션
#
# 종료 코드:
#   0 — 정상
#   1 — 입력 오류
#   2 — 런타임 의존성 부재

set -euo pipefail

# --- 의존성 검사 ---------------------------------------------------------------

if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq is required (brew install yq)" >&2
  exit 2
fi

# --- ANSI 색상 -----------------------------------------------------------------

NO_COLOR="${NO_COLOR:-}"
if [[ -t 1 && -z "$NO_COLOR" ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_BLUE=$'\033[34m'
  C_GREY=$'\033[90m'
  C_MAGENTA=$'\033[35m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""
  C_GREEN=""; C_YELLOW=""; C_RED=""
  C_BLUE=""; C_GREY=""; C_MAGENTA=""
fi

# cursor frames (braille spinner)
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# CP-N → 라벨 매핑
CP_NAMES=(CP-0 CP-1 CP-2 CP-3 CP-4 CP-5)
CP_LABELS=(Intake Brainstorm Plan Verify Compound Finalize)

# --- 렌더링 헬퍼 ---------------------------------------------------------------

# status → (icon, color) 조회
status_icon() {
  case "$1" in
    done)    printf '%s[✓]%s' "$C_GREEN"   "$C_RESET" ;;
    failed)  printf '%s[✗]%s' "$C_RED"     "$C_RESET" ;;
    skipped) printf '%s[→]%s' "$C_GREY"    "$C_RESET" ;;
    paused)  printf '%s[⏸]%s' "$C_YELLOW"  "$C_RESET" ;;
    active)  printf '%s[%s]%s' "$C_BLUE" "${SPINNER_FRAMES[$2]}" "$C_RESET" ;;
    pending) printf '%s[ ]%s' "$C_DIM"     "$C_RESET" ;;
    *)       printf '%s[?]%s' "$C_MAGENTA" "$C_RESET" ;;
  esac
}

status_color() {
  case "$1" in
    done)    printf '%s' "$C_GREEN"   ;;
    failed)  printf '%s' "$C_RED"     ;;
    skipped) printf '%s' "$C_GREY"    ;;
    paused)  printf '%s' "$C_YELLOW"  ;;
    active)  printf '%s' "$C_BLUE"    ;;
    pending) printf '%s' "$C_DIM"     ;;
    *)       printf '%s' "$C_MAGENTA" ;;
  esac
}

# read_status <log> <cp_name> → 존재하지 않으면 "pending"
read_status() {
  local log="$1" cp="$2"
  local s
  s="$(yq eval ".checkpoints.\"$cp\".status // \"pending\"" "$log" 2>/dev/null || echo pending)"
  # cp 가 기록되지 않았다면 pending
  if [[ -z "$s" || "$s" == "null" ]]; then s="pending"; fi
  printf '%s' "$s"
}

# 현재 active bucket 계산: 기록된 CP 이후 첫 pending → active 로 표시
compute_active_index() {
  local log="$1"
  local last_done=-1
  local i=0
  for cp in "${CP_NAMES[@]}"; do
    local s
    s="$(read_status "$log" "$cp")"
    if [[ "$s" == "done" || "$s" == "skipped" ]]; then
      last_done=$i
    elif [[ "$s" == "failed" || "$s" == "paused" ]]; then
      # failed/paused 는 active 가 없음 (그 위치에 머묾)
      printf '%d' "-1"
      return 0
    fi
    i=$((i + 1))
  done
  # 다음 pending index
  local next=$((last_done + 1))
  if [[ "$next" -ge "${#CP_NAMES[@]}" ]]; then
    printf '%d' "-1"
  else
    printf '%d' "$next"
  fi
}

# 실제 렌더 — 주어진 status 맵과 active-idx / frame 으로 한 화면 출력
render_from_statuses() {
  local active_idx="$1"
  local frame="$2"
  shift 2
  local -a statuses=("$@")

  local header="${C_BOLD}/orchestrate progress${C_RESET}"
  printf '%s\n' "$header"
  printf '%s\n' "${C_DIM}─────────────────────────────────${C_RESET}"

  local i=0
  for cp in "${CP_NAMES[@]}"; do
    local s="${statuses[$i]}"
    local label="${CP_LABELS[$i]}"
    local effective="$s"
    if [[ "$i" -eq "$active_idx" && "$s" == "pending" ]]; then
      effective="active"
    fi

    local icon
    icon="$(status_icon "$effective" "$frame")"
    local color
    color="$(status_color "$effective")"

    printf '%s %s%-3s %-12s%s %s(%s)%s\n' \
      "$icon" \
      "$color" "$cp" "$label" "$C_RESET" \
      "$C_DIM" "$effective" "$C_RESET"
    i=$((i + 1))
  done
  printf '%s\n' "${C_DIM}─────────────────────────────────${C_RESET}"
}

# render <run_dir> <frame>
render() {
  local run_dir="$1"
  local frame="${2:-0}"
  local log="$run_dir/experiment-log.yaml"
  if [[ ! -s "$log" ]]; then
    echo "Error: experiment-log.yaml not found in: $run_dir" >&2
    return 1
  fi
  local active_idx
  active_idx="$(compute_active_index "$log")"
  local -a statuses=()
  for cp in "${CP_NAMES[@]}"; do
    statuses+=("$(read_status "$log" "$cp")")
  done
  render_from_statuses "$active_idx" "$frame" "${statuses[@]}"
}

# simulate: 6 bucket 상태 전이 수동 시뮬레이션 (실험용)
simulate() {
  local frame=0
  local -a seq=(
    "pending pending pending pending pending pending -1"
    "done    active  pending pending pending pending 1"
    "done    done    active  pending pending pending 2"
    "done    done    done    active  pending pending 3"
    "done    done    done    done    skipped active  5"
    "done    done    done    done    skipped done    -1"
  )
  for step in "${seq[@]}"; do
    # shellcheck disable=SC2206
    local arr=( $step )
    local s0="${arr[0]}" s1="${arr[1]}" s2="${arr[2]}" s3="${arr[3]}" s4="${arr[4]}" s5="${arr[5]}" active="${arr[6]}"
    clear_screen
    printf '%s[simulate]%s frame=%d\n' "$C_MAGENTA" "$C_RESET" "$frame"
    render_from_statuses "$active" "$frame" "$s0" "$s1" "$s2" "$s3" "$s4" "$s5"
    frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
    sleep 0.6
  done
}

clear_screen() {
  if [[ -t 1 && -z "$NO_COLOR" ]]; then
    printf '\033[2J\033[H'
  else
    printf '\n---\n'
  fi
}

# --- 인자 파싱 -----------------------------------------------------------------

WATCH=0
DO_SIMULATE=0
RUN_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch)     WATCH=1; shift ;;
    --simulate)  DO_SIMULATE=1; shift ;;
    --no-color)  NO_COLOR=1; export NO_COLOR; shift ;;
    -h|--help)
      sed -n '2,25p' "$0" >&2
      exit 0
      ;;
    -*)
      echo "Error: unknown flag: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$RUN_DIR" ]]; then
        RUN_DIR="$1"
      else
        echo "Error: unexpected extra arg: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ "$DO_SIMULATE" -eq 1 ]]; then
  simulate
  exit 0
fi

if [[ -z "$RUN_DIR" ]]; then
  echo "Error: run_dir required (or use --simulate)" >&2
  exit 1
fi

if [[ "$WATCH" -eq 1 ]]; then
  frame=0
  while true; do
    clear_screen
    render "$RUN_DIR" "$frame" || exit $?
    frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
    sleep 1
  done
else
  render "$RUN_DIR" 0
fi

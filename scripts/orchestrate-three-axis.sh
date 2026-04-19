#!/usr/bin/env bash
# scripts/orchestrate-three-axis.sh — T-W7-04 · 포팅 #16 (hoyeon 3-Axis)
#
# dispatch × work × verify = 9 조합 중 허용된 3 조합만 통과시켜
# orchestrate-pipeline.sh 에 전달하는 래퍼.
#
# 3-Axis 정의:
#   dispatch : sequential · parallel · lazy
#   work     : fresh-context · shared-context · hybrid
#   verify   : strict · lenient · skip
#
# 허용 3 조합:
#   1. sequential × fresh-context × strict     (default)
#   2. parallel   × shared-context × lenient   (fast)
#   3. lazy       × hybrid         × skip      (debug)
#
# 사용법:
#   orchestrate-three-axis.sh \
#       --axis dispatch=sequential,work=fresh-context,verify=strict \
#       -- <topic> [pipeline args...]
#
#   orchestrate-three-axis.sh --list          # 허용 조합 출력
#   orchestrate-three-axis.sh --validate-only \
#       --axis dispatch=lazy,work=hybrid,verify=skip
#
# 종료 코드:
#   0 — 허용 조합 / validate OK / pipeline 성공
#   1 — 인자 오류 / 미허용 조합
#   2 — 런타임 의존성 부재
#   N — pipeline 본체 종료 코드 (그대로 전파)

set -euo pipefail

# --- 허용 조합 정의 ------------------------------------------------------------

ALLOWED_COMBOS=(
  "sequential:fresh-context:strict"
  "parallel:shared-context:lenient"
  "lazy:hybrid:skip"
)

COMBO_LABELS=(
  "default (MVP): 단일 패널, 보수적 검증"
  "fast       : 축 간 병렬 + 공유 컨텍스트 + lenient verify"
  "debug      : lazy stub 모드, verify skip"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SH="${SCRIPT_DIR}/orchestrate-pipeline.sh"

# --- 인자 파싱 -----------------------------------------------------------------

AXIS_SPEC=""
VALIDATE_ONLY=0
DO_LIST=0
PASSTHROUGH=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --axis)
      AXIS_SPEC="${2:-}"; shift 2 ;;
    --axis=*)
      AXIS_SPEC="${1#--axis=}"; shift ;;
    --list)
      DO_LIST=1; shift ;;
    --validate-only)
      VALIDATE_ONLY=1; shift ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do PASSTHROUGH+=("$1"); shift; done
      break
      ;;
    -h|--help)
      sed -n '2,30p' "$0" >&2
      exit 0
      ;;
    *)
      # passthrough
      PASSTHROUGH+=("$1"); shift ;;
  esac
done

# --- --list 모드 --------------------------------------------------------------

if [[ "$DO_LIST" -eq 1 ]]; then
  printf 'Allowed 3-Axis combinations (dispatch × work × verify):\n'
  i=0
  for combo in "${ALLOWED_COMBOS[@]}"; do
    IFS=':' read -r d w v <<<"$combo"
    printf '  %d. %-42s  — %s\n' \
      "$((i + 1))" "$d × $w × $v" "${COMBO_LABELS[$i]}"
    i=$((i + 1))
  done
  exit 0
fi

# --- AXIS_SPEC 파싱 ------------------------------------------------------------

if [[ -z "$AXIS_SPEC" ]]; then
  echo "Error: --axis dispatch=<>,work=<>,verify=<> is required" >&2
  exit 1
fi

DISPATCH=""
WORK=""
VERIFY=""

IFS=',' read -ra pairs <<<"$AXIS_SPEC"
for pair in "${pairs[@]}"; do
  key="${pair%%=*}"
  val="${pair#*=}"
  # shellcheck disable=SC2076
  if [[ -z "$val" || "$key" == "$val" ]]; then
    echo "Error: malformed axis pair: $pair (expected key=value)" >&2
    exit 1
  fi
  case "$key" in
    dispatch) DISPATCH="$val" ;;
    work)     WORK="$val" ;;
    verify)   VERIFY="$val" ;;
    *)
      echo "Error: unknown axis key: $key (allowed: dispatch, work, verify)" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$DISPATCH" || -z "$WORK" || -z "$VERIFY" ]]; then
  echo "Error: --axis must specify all three: dispatch, work, verify" >&2
  exit 1
fi

# --- 조합 검증 -----------------------------------------------------------------

combo_key="${DISPATCH}:${WORK}:${VERIFY}"
allowed=0
for c in "${ALLOWED_COMBOS[@]}"; do
  if [[ "$c" == "$combo_key" ]]; then
    allowed=1
    break
  fi
done

if [[ "$allowed" -ne 1 ]]; then
  {
    echo "Error: disallowed 3-Axis combination: $DISPATCH × $WORK × $VERIFY"
    echo ""
    echo "Allowed combinations:"
    i=0
    for c in "${ALLOWED_COMBOS[@]}"; do
      IFS=':' read -r d w v <<<"$c"
      echo "  - $d × $w × $v"
      i=$((i + 1))
    done
  } >&2
  exit 1
fi

if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
  printf 'OK: %s × %s × %s\n' "$DISPATCH" "$WORK" "$VERIFY"
  exit 0
fi

# --- pipeline 위임 -------------------------------------------------------------

if [[ ! -x "$PIPELINE_SH" ]]; then
  echo "Error: pipeline driver not found/executable: $PIPELINE_SH" >&2
  exit 2
fi

# 환경 변수로 조합 주입 + 파이프라인 실행
export ORCH_DISPATCH="$DISPATCH"
export ORCH_WORK="$WORK"
export ORCH_VERIFY="$VERIFY"

exec "$PIPELINE_SH" "${PASSTHROUGH[@]}"

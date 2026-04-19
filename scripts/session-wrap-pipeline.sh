#!/usr/bin/env bash
# scripts/session-wrap-pipeline.sh — T-W6-02 · 포팅 자산 #4
#
# p4cn session-wrap 2-Phase 파이프라인 포팅.
#   Phase A: 4 분석자 병렬 (tacit-extractor · correction-recorder ·
#            pattern-detector · preference-tracker)
#   Phase B: 1 validator 순차 (duplicate-checker) + overlap scoring
#
# 본 스크립트는 MVP 스텁 — 실제 LLM 호출은 W7 이후. 현재는 fixed
# fixture(또는 환경 변수로 주입된 stub 출력)를 반환해 파이프라인의
# 배선·순서만 검증한다. shellcheck 통과를 1차 목표로 한다.
#
# 사용법:
#   scripts/session-wrap-pipeline.sh \
#       [--session-id <id>]              # 기본: $CLAUDE_SESSION_ID 또는 sess_<date>
#       [--turns <path>]                 # 기본: extract-session.sh 결과
#       [--trigger <source>]             # pattern_repeat|user_correction|session_wrap
#       [--state-root <dir>]             # 기본 .claude/state/sessions
#       [--memory-root <dir>]            # 기본 .claude/memory
#       [--agents-root <dir>]            # 기본 agents/compound
#       [--fixture <dir>]                # 분석자 stub 출력 JSON 디렉토리 (테스트용)
#
# 출력 (stdout, single-line JSON):
#   {"session_id":"...","candidates_dir":"...","raw_count":N,"validated_count":M}
#
# 종료 코드:
#   0 — 정상 (전체 또는 부분 성공)
#   1 — 입력 오류 (필수 인자/파일 누락)
#   2 — 런타임 의존성 부재 (jq/yq)
#   3 — Phase A 전원(4/4) 실패 → 빈 큐 반환
#
# 보안 (§4.3 P0-8):
#   • set -euo pipefail · "$var" · eval 금지
#   • slug 화이트리스트 [a-zA-Z0-9_-]
#   • jq/yq 에 사용자 입력 직접 보간 금지 (--arg / stdin)

set -euo pipefail

# --- 런타임 선행 검증 ---------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. 설치: brew install jq" >&2
  exit 2
fi

# yq 는 Phase B 의 overlap-score / promotion-gate 체인에서 요구 — pipeline
# 자체는 스텁이라 필수는 아니지만, 실제 호출 시 사전에 잡아준다.
if ! command -v yq >/dev/null 2>&1; then
  echo "Warning: yq not found — validator chain will be limited (stub only)." >&2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 인자 파싱 -----------------------------------------------------------------

SESSION_ID=""
TURNS_PATH=""
TRIGGER="session_wrap"
STATE_ROOT=".claude/state/sessions"
MEMORY_ROOT=".claude/memory"
AGENTS_ROOT="agents/compound"
FIXTURE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)   SESSION_ID="${2:-}"; shift 2 ;;
    --turns)        TURNS_PATH="${2:-}"; shift 2 ;;
    --trigger)      TRIGGER="${2:-}"; shift 2 ;;
    --state-root)   STATE_ROOT="${2:-}"; shift 2 ;;
    --memory-root)  MEMORY_ROOT="${2:-}"; shift 2 ;;
    --agents-root)  AGENTS_ROOT="${2:-}"; shift 2 ;;
    --fixture)      FIXTURE_DIR="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0" >&2
      exit 0
      ;;
    *)
      echo "Error: unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

# --- 기본값 채우기 -------------------------------------------------------------

if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="${CLAUDE_SESSION_ID:-sess_$(date +%Y%m%d_%H%M%S)}"
fi

# slug 검증 (§4.3 P0-8)
if [[ ! "$SESSION_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: invalid session-id (allowed: [a-zA-Z0-9_-]): $SESSION_ID" >&2
  exit 1
fi

case "$TRIGGER" in
  pattern_repeat|user_correction|session_wrap) ;;
  *)
    echo "Error: --trigger must be one of pattern_repeat|user_correction|session_wrap" >&2
    exit 1
    ;;
esac

# MEMORY_ROOT / AGENTS_ROOT 는 W7 이후 Phase B(duplicate-checker) 와 분석자
# 실행에서 참조된다. 현재(MVP 스텁)에도 하위 프로세스에서 읽을 수 있도록
# 내보낸다. shellcheck SC2034 대응.
export MEMORY_ROOT AGENTS_ROOT

# state 디렉토리 준비
STATE_DIR="${STATE_ROOT}/${SESSION_ID}"
CANDIDATES_DIR="${STATE_DIR}/candidates"
RAW_OUT="${STATE_DIR}/candidates.raw.json"
MERGED_OUT="${STATE_DIR}/candidates.merged.json"

mkdir -p "$CANDIDATES_DIR"

# --- Phase 1: Intake (간이) ---------------------------------------------------
#
# TURNS_PATH 가 주어지지 않으면 extract-session.sh 호출. 실패는 skip.

if [[ -z "$TURNS_PATH" ]]; then
  TURNS_PATH="${STATE_DIR}/turns.json"
  if [[ -x "${SCRIPT_DIR}/extract-session.sh" ]]; then
    if ! "${SCRIPT_DIR}/extract-session.sh" >"$TURNS_PATH" 2>/dev/null; then
      echo "[compound] intake skipped — extract-session.sh failed (using empty turns)" >&2
      printf '[]\n' >"$TURNS_PATH"
    fi
  else
    printf '[]\n' >"$TURNS_PATH"
  fi
fi

if [[ ! -f "$TURNS_PATH" ]]; then
  echo "Error: turns file not found: $TURNS_PATH" >&2
  exit 1
fi

# --- Phase A: 4 분석자 병렬 (MVP 스텁) -----------------------------------------
#
# 실제 W7 이후에는 Task 도구 4회 동시 호출로 fresh-context agents 를 띄운다.
# MVP 는 fixture 디렉토리의 고정 JSON 을 병렬로 읽어 합산한다. fixture 미지정
# 시 빈 배열을 사용해 파이프라인 배선만 검증한다.

ANALYZERS=(tacit-extractor correction-recorder pattern-detector preference-tracker)

tmpdir="$(mktemp -d -t session-wrap.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

run_analyzer_stub() {
  # 1인자: 분석자 이름
  local name="$1"
  local out="${tmpdir}/${name}.json"

  if [[ -n "$FIXTURE_DIR" && -f "${FIXTURE_DIR}/${name}.json" ]]; then
    cp "${FIXTURE_DIR}/${name}.json" "$out"
  else
    # 빈 배열 — 실제 동작은 W7 이후
    printf '[]\n' >"$out"
  fi
  printf '%s\n' "$out"
}

pids=()
result_files=()
fail_count=0

for name in "${ANALYZERS[@]}"; do
  {
    run_analyzer_stub "$name" >"${tmpdir}/${name}.path"
  } &
  pids+=("$!")
done

for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    echo "[compound] analyzer failed: ${ANALYZERS[$i]}" >&2
    fail_count=$((fail_count + 1))
    continue
  fi
  path_file="${tmpdir}/${ANALYZERS[$i]}.path"
  if [[ -s "$path_file" ]]; then
    result_files+=("$(cat "$path_file")")
  fi
done

if [[ "$fail_count" -ge 4 ]]; then
  echo "[compound] all analyzers failed — aborting pipeline" >&2
  printf '{"session_id":"%s","candidates_dir":"%s","raw_count":0,"validated_count":0,"error":"all_analyzers_failed"}\n' \
    "$SESSION_ID" "$CANDIDATES_DIR"
  exit 3
fi

# --- Phase A 결과 병합 --------------------------------------------------------

if [[ "${#result_files[@]}" -eq 0 ]]; then
  printf '[]\n' >"$RAW_OUT"
else
  jq -s 'add // []' "${result_files[@]}" >"$RAW_OUT"
fi

raw_count="$(jq 'length' "$RAW_OUT")"

# --- Phase B: duplicate-checker (순차 validator 스텁) -------------------------
#
# 실제 W7 이후에는 agents/compound/duplicate-checker 를 Task 도구로 호출.
# MVP 는 raw 큐에서 content 기준 단순 dedup 만 수행한다.

jq 'unique_by(.content // "")' "$RAW_OUT" >"$MERGED_OUT"

merged_count="$(jq 'length' "$MERGED_OUT")"

# --- 후보 YAML 파일 분할 저장 (Phase 4 입력) ----------------------------------

validated_count=0

if [[ "$merged_count" -gt 0 ]]; then
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    # slug 검증
    if [[ ! "$cid" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo "[compound] skipping invalid candidate id: $cid" >&2
      continue
    fi
    yaml_path="${CANDIDATES_DIR}/${cid}.yaml"
    jq -r --arg cid "$cid" \
      '.[] | select((.candidate_id // "") == $cid)' "$MERGED_OUT" \
      >"${yaml_path}.json" || true
    # JSON → YAML 은 yq 가 필요. 없으면 JSON 으로만 남긴다(스텁).
    if command -v yq >/dev/null 2>&1; then
      yq -P '.' "${yaml_path}.json" >"$yaml_path" 2>/dev/null || cp "${yaml_path}.json" "$yaml_path"
    else
      cp "${yaml_path}.json" "$yaml_path"
    fi
    rm -f "${yaml_path}.json"
    validated_count=$((validated_count + 1))
  done < <(jq -r '.[] | .candidate_id // empty' "$MERGED_OUT")
fi

# --- 최종 요약 (stdout JSON) --------------------------------------------------

jq -nc \
  --arg sid "$SESSION_ID" \
  --arg dir "$CANDIDATES_DIR" \
  --arg trigger "$TRIGGER" \
  --argjson raw "$raw_count" \
  --argjson merged "$merged_count" \
  --argjson validated "$validated_count" \
  --argjson failed "$fail_count" \
  '{
    session_id: $sid,
    trigger_source: $trigger,
    candidates_dir: $dir,
    raw_count: $raw,
    merged_count: $merged,
    validated_count: $validated,
    analyzer_failures: $failed
  }'

printf '[compound] pipeline done — raw=%d merged=%d validated=%d failed=%d\n' \
  "$raw_count" "$merged_count" "$validated_count" "$fail_count" >&2

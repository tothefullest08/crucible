#!/usr/bin/env bash
# schema-adapter.sh — JSONL schema adapter (v3.1 §4.2.1 구현)
#
# 입력 (stdin): JSONL 라인 (1개 또는 stream)
# 출력 (stdout): 정규화된 JSON (라인당 1개)
# 종료 코드:
#   0 → 성공 (skip 포함)
#   1 → JSON 파싱 불가 라인 발생 (처리 계속, 카운트만 누적)
#   2 → 치명적 런타임 에러 (jq 없음 / bash 버전 부족)
#
# v3.1 §4.2.1 매핑표:
#   (file-history-snapshot, v0) → parse_fhs_v0           → {kind:"fhs", path, sha, ts}
#   (user-prompt,          v0) → parse_user_prompt_v0    → {kind:"prompt", text, ts, session_id}
#   (assistant-turn,       v0) → parse_assistant_turn_v0 → {kind:"turn", text, tool_calls, ts}
#   그 외                        → skip_with_log          → stderr "skipped: <type>@<ver>"
#
# 보안 (§4.3):
#   - set -euo pipefail
#   - 유저 입력은 --arg / stdin 만 사용 (jq filter 문자열 보간 금지)
#   - eval 금지
#   - 변수는 모두 쌍따옴표

set -euo pipefail

# --- 런타임 선행 검증 ---------------------------------------------------------

if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
  echo "Error: bash >= 4.0 required (macOS 기본은 3.2). 설치: brew install bash" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. 설치: brew install jq (또는 apt install jq)" >&2
  exit 2
fi

# --- 어댑터 함수 ---------------------------------------------------------------
#
# 각 함수는 $1 로 JSONL 라인 1개를 받아 정규화된 JSON 한 줄을 stdout으로 출력.
# 공통 출력 계약: {kind: string, ts: ISO8601|null, ...}
#
# NOTE: 연관 배열(ADAPTERS) 기반 간접 호출이라 정적 분석기가 SC2329(Unused) 로
# 오인할 수 있음. 각 함수 위에 disable 지시어를 개별로 둔다.

# shellcheck disable=SC2329
parse_fhs_v0() {
  local line="$1"
  jq -c '{
    kind: "fhs",
    path: (.path // .filePath // null),
    sha: (.sha // .hash // null),
    ts: (.timestamp // .ts // null)
  }' <<<"$line"
}

# shellcheck disable=SC2329
parse_user_prompt_v0() {
  local line="$1"
  jq -c '{
    kind: "prompt",
    text: (.prompt // .text // .message.content // null),
    ts: (.timestamp // .ts // null),
    session_id: (.session_id // .sessionId // null)
  }' <<<"$line"
}

# shellcheck disable=SC2329
parse_assistant_turn_v0() {
  local line="$1"
  jq -c '{
    kind: "turn",
    text: ([.message.content[]? | select(.type == "text") | .text] | join("\n")),
    tool_calls: [.message.content[]? | select(.type == "tool_use") | {name: .name, id: .id}],
    ts: (.timestamp // .ts // null)
  }' <<<"$line"
}

skip_with_log() {
  local type="$1" ver="$2"
  printf 'skipped: %s@%s\n' "$type" "$ver" >&2
  # stdout은 빈 줄로 유지 (호출 측이 길이 0으로 판단)
}

# --- dispatch 매핑 ------------------------------------------------------------

declare -A ADAPTERS
ADAPTERS["file-history-snapshot@v0"]="parse_fhs_v0"
ADAPTERS["user-prompt@v0"]="parse_user_prompt_v0"
ADAPTERS["assistant-turn@v0"]="parse_assistant_turn_v0"

# --- 메인 루프 ----------------------------------------------------------------

parse_error_count=0
skipped_count=0

while IFS= read -r line || [[ -n "$line" ]]; do
  # 빈 라인 skip
  [[ -z "$line" ]] && continue

  # JSON 유효성 검사 (jq 에러 시 카운트만 누적 · 계속 진행)
  if ! jq -e . >/dev/null 2>&1 <<<"$line"; then
    printf 'schema-adapter: invalid JSON line (parse error)\n' >&2
    parse_error_count=$((parse_error_count + 1))
    continue
  fi

  # type / schema_version 추출 (--arg 대신 stdin + // 기본값)
  type_str="$(jq -r '.type // "unknown"' <<<"$line")"
  ver_str="$(jq -r '.schema_version // "v0"' <<<"$line")"

  # 슬러그 화이트리스트 (§4.3 P0-8: 변수 보간 경로 오염 방지)
  if [[ ! "$type_str" =~ ^[a-zA-Z0-9_.-]+$ ]] || [[ ! "$ver_str" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    printf 'schema-adapter: invalid slug (type=%q ver=%q) — skipping\n' "$type_str" "$ver_str" >&2
    skipped_count=$((skipped_count + 1))
    continue
  fi

  key="${type_str}@${ver_str}"
  fn="${ADAPTERS[$key]:-}"

  if [[ -z "$fn" ]]; then
    skip_with_log "$type_str" "$ver_str"
    skipped_count=$((skipped_count + 1))
    # 100줄마다 누적 카운터 emit (§4.2.1 정식 사양)
    if (( skipped_count % 100 == 0 )); then
      printf 'skipped_count:%d\n' "$skipped_count" >&2
    fi
    continue
  fi

  # 어댑터 실행 (실패 시 stderr만 남기고 해당 라인 skip)
  if ! "$fn" "$line"; then
    printf 'schema-adapter: adapter %s failed on line\n' "$fn" >&2
    parse_error_count=$((parse_error_count + 1))
    continue
  fi
done

# 최종 요약 (stderr · 집계 용도)
if (( skipped_count > 0 )) || (( parse_error_count > 0 )); then
  printf 'schema-adapter: done (skipped=%d parse_errors=%d)\n' \
    "$skipped_count" "$parse_error_count" >&2
fi

# v3.1 §4.2.1: JSON 파싱 불가 라인이 1개라도 있으면 exit 1 (처리는 계속했음)
if (( parse_error_count > 0 )); then
  exit 1
fi

exit 0

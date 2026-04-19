#!/usr/bin/env bash
# extract-session.sh — Claude Code 세션 JSONL 파서 (v3.1 §4.2 Primary tier)
#
# p4cn history-insight(Python) → bash+jq 재작성 (v3 §4.1 P0-1 제약).
# schema-adapter.sh 를 호출해 정규화.
#
# 사용법:
#   scripts/extract-session.sh [<cwd_or_jsonl>]
#
# 인자:
#   $1 (선택)
#     • 디렉터리 경로(프로젝트 CWD, 기본: $PWD)
#       → ~/.claude/projects/ 슬러그 인코딩 규칙(/→-)으로 변환 후
#         해당 디렉터리의 *.jsonl 전체를 병합 처리.
#     • *.jsonl 파일 경로
#       → 해당 파일만 단독 처리 (테스트/단일 세션 용도).
#
# 출력 (stdout):
#   정규화된 턴 리스트 JSON 배열.
#   원소 구조: {turn_index, role, content, timestamp, type, schema_version}
#
# 에러 처리 (v3.1 §4.2):
#   • 손상 JSONL 라인  → skip + stderr 로그 (처리 계속)
#   • unknown type     → skip + stderr 로그 (처리 계속)
#   • 파일 없음         → exit 1 + 명확한 메시지
#   • jq 미설치         → exit 2 + 설치 가이드
#
# 보안 (§4.3):
#   • set -euo pipefail
#   • 모든 변수 "$var"
#   • eval 금지
#   • 경로 슬러그 화이트리스트 [a-zA-Z0-9_/.-]
#   • jq filter 문자열 보간 금지 (--arg / stdin 사용)

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

# --- 경로 해석 ---------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER="${SCRIPT_DIR}/schema-adapter.sh"

if [[ ! -x "$ADAPTER" ]]; then
  echo "Error: schema-adapter.sh not found or not executable: $ADAPTER" >&2
  exit 2
fi

INPUT="${1:-$PWD}"

# 슬러그 화이트리스트 검증 (§4.3 P0-8)
if [[ ! "$INPUT" =~ ^[a-zA-Z0-9_./~-]+$ ]]; then
  echo "Error: invalid path characters in \$1 (allowed: [a-zA-Z0-9_./~-]): $INPUT" >&2
  exit 1
fi

# `~` 확장 (env 기반 · eval 금지)
if [[ "$INPUT" == "~"* ]]; then
  INPUT="${HOME}${INPUT:1}"
fi

# --- JSONL 파일 수집 ----------------------------------------------------------
#
# 전략:
#   1) INPUT이 *.jsonl 파일 → 단일 파일 모드 (테스트)
#   2) INPUT이 디렉터리      → 그 디렉터리의 *.jsonl 병합
#   3) INPUT이 CWD (그 외)   → 슬러그 인코딩 → ~/.claude/projects/<enc>/*.jsonl

declare -a SESSION_FILES=()

encode_cwd() {
  # /Users/ethan/Desktop/personal/harness → -Users-ethan-Desktop-personal-harness
  local cwd="$1"
  # 쌍따옴표 보간 + sed (eval 금지)
  printf '%s' "$cwd" | sed 's|/|-|g'
}

if [[ -f "$INPUT" && "$INPUT" == *.jsonl ]]; then
  SESSION_FILES+=("$INPUT")
elif [[ -d "$INPUT" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && SESSION_FILES+=("$f")
  done < <(find "$INPUT" -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null | LC_ALL=C sort)
else
  # CWD 취급 → 슬러그 인코딩
  encoded="$(encode_cwd "$INPUT")"
  projects_dir="${HOME}/.claude/projects/${encoded}"
  if [[ ! -d "$projects_dir" ]]; then
    echo "Error: no Claude Code projects dir at: $projects_dir" >&2
    echo "       (derived from: $INPUT)" >&2
    exit 1
  fi
  while IFS= read -r f; do
    [[ -n "$f" ]] && SESSION_FILES+=("$f")
  done < <(find "$projects_dir" -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null | LC_ALL=C sort)
fi

if [[ ${#SESSION_FILES[@]} -eq 0 ]]; then
  echo "Error: no *.jsonl files found for: $INPUT" >&2
  exit 1
fi

# --- 라인 처리 & 정규화 턴 리스트 빌드 ----------------------------------------
#
# 각 라인:
#   1) JSON 유효성 검증 — 실패 시 stderr + skip
#   2) schema-adapter.sh 로 정규화 (stdin 1 라인 → stdout 1 라인)
#   3) 빈 결과(스킵)면 다음 라인으로
#   4) 정규화 결과를 content, 원본 type/timestamp/schema_version 추출 → 레코드 조립
#
# schema_version 분포 집계 (stderr 로그)는 adapter 가 담당.

turn_index=0
corrupted_count=0
unknown_count=0

TMP_JSONL="$(mktemp -t extract-session.XXXXXX)"
trap 'rm -f "$TMP_JSONL"' EXIT

for f in "${SESSION_FILES[@]}"; do
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    # 1) JSON 유효성
    if ! jq -e . >/dev/null 2>&1 <<<"$line"; then
      printf 'extract-session: corrupted JSONL line in %s — skipping\n' "$f" >&2
      corrupted_count=$((corrupted_count + 1))
      continue
    fi

    # 2) 어댑터 호출
    if ! normalized="$(printf '%s\n' "$line" | "$ADAPTER")"; then
      # adapter가 exit 1 (parse error 있음) 이어도 이 라인 결과 자체는 stdout에 있을 수 있음
      # 안전을 위해 빈 결과 취급
      normalized=""
    fi
    # 끝 개행 제거
    normalized="${normalized%$'\n'}"

    if [[ -z "$normalized" ]]; then
      unknown_count=$((unknown_count + 1))
      continue
    fi

    # 3) 원본에서 메타데이터 추출
    role="$(jq -r '.type // "unknown"' <<<"$line")"
    timestamp="$(jq -r '.timestamp // .ts // "unknown"' <<<"$line")"
    schema_version="$(jq -r '.schema_version // "v0"' <<<"$line")"

    # 4) 레코드 조립 (jq -n + --argjson / --arg — 문자열 보간 금지)
    jq -nc \
      --argjson idx "$turn_index" \
      --arg role "$role" \
      --arg ts "$timestamp" \
      --arg type "$role" \
      --arg sv "$schema_version" \
      --argjson content "$normalized" \
      '{
        turn_index: $idx,
        role: $role,
        content: $content,
        timestamp: $ts,
        type: $type,
        schema_version: $sv
      }' >> "$TMP_JSONL"

    turn_index=$((turn_index + 1))
  done < "$f"
done

# --- 최종 출력 (JSON 배열) ----------------------------------------------------

if [[ ! -s "$TMP_JSONL" ]]; then
  printf '[]\n'
else
  jq -s '.' < "$TMP_JSONL"
fi

# 요약 (stderr)
printf 'extract-session: done — turns=%d corrupted=%d unknown_or_skipped=%d files=%d\n' \
  "$turn_index" "$corrupted_count" "$unknown_count" "${#SESSION_FILES[@]}" >&2

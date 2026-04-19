#!/usr/bin/env bash
# gap-analyzer.sh — /plan Phase 4 gap 추출 스텁 (T-W3-04)
#
# hoyeon gap-analyzer 에이전트 개념을 정적 휴리스틱으로 포팅 (MVP).
# LLM 기반 심화 분석은 W4 이후 연동 (포팅 자산 #15).
#
# 사용법:
#   scripts/gap-analyzer.sh <requirements.md>
#
# 출력 (stdout):
#   JSON 리스트: [{"gap_id":"...","section":"...","reason":"..."}, ...]
#   gap 0개 시: []
#
# 휴리스틱:
#   G1  Scope 섹션에 "Excluded" 누락
#   G2  Success Criteria 섹션에 측정 가능 수치 부재
#   G3  frontmatter decisions 배열이 비어있음
#   G4  Constraints 섹션에 "TBD"/"미정"/"나중에" 포함
#
# 보안 (v3.1 §4.3):
#   • set -euo pipefail
#   • 모든 변수 "$var"
#   • eval 금지
#   • jq filter 문자열 보간 없이 --arg 사용

set -euo pipefail

# --- 인자 검증 ---------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <requirements.md>" >&2
  exit 1
fi

REQ_PATH="$1"

if [[ ! -f "$REQ_PATH" ]]; then
  echo "Error: file not found: $REQ_PATH" >&2
  exit 1
fi

if [[ ! -r "$REQ_PATH" ]]; then
  echo "Error: cannot read: $REQ_PATH" >&2
  exit 1
fi

# --- 의존성 체크 --------------------------------------------------------------

for tool in jq awk yq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: $tool is required. Install via brew." >&2
    exit 2
  fi
done

# --- 본문·frontmatter 추출 ----------------------------------------------------

# frontmatter (--- ... --- 사이)만 따로 추출. yq 로 decisions 길이 측정.
FM_TMP="$(mktemp)"
trap 'rm -f "$FM_TMP"' EXIT

awk '
  BEGIN { in_fm = 0; fm_done = 0 }
  /^---$/ {
    if (fm_done == 0 && in_fm == 0) { in_fm = 1; next }
    if (in_fm == 1) { in_fm = 0; fm_done = 1; next }
  }
  in_fm == 1 { print }
' "$REQ_PATH" > "$FM_TMP"

# frontmatter 부재 시 빈 YAML로 처리
if [[ ! -s "$FM_TMP" ]]; then
  DECISIONS_LEN=0
else
  # yq e 실패 시 0으로 fallback (malformed frontmatter)
  DECISIONS_LEN="$(yq e '.decisions | length // 0' "$FM_TMP" 2>/dev/null || echo 0)"
  if [[ ! "$DECISIONS_LEN" =~ ^[0-9]+$ ]]; then
    DECISIONS_LEN=0
  fi
fi

# 본문에서 섹션별 내용 추출 (## Heading 기준)
SECTION_SCOPE="$(awk '
  /^## / { capture = 0 }
  /^## +Scope/ { capture = 1; next }
  capture == 1 { print }
' "$REQ_PATH")"

SECTION_SUCCESS="$(awk '
  /^## / { capture = 0 }
  /^## +Success Criteria/ { capture = 1; next }
  capture == 1 { print }
' "$REQ_PATH")"

SECTION_CONSTRAINTS="$(awk '
  /^## / { capture = 0 }
  /^## +Constraints/ { capture = 1; next }
  capture == 1 { print }
' "$REQ_PATH")"

# --- gap 판정 -----------------------------------------------------------------

# jq에 누적해서 append. --arg 로 안전하게 바인딩.
GAPS_JSON='[]'

append_gap() {
  local gap_id="$1"
  local section="$2"
  local reason="$3"
  GAPS_JSON="$(jq -n \
    --argjson acc "$GAPS_JSON" \
    --arg gap_id "$gap_id" \
    --arg section "$section" \
    --arg reason "$reason" \
    '$acc + [{gap_id: $gap_id, section: $section, reason: $reason}]')"
}

# G1: Scope Excluded 누락
if ! printf '%s\n' "$SECTION_SCOPE" | grep -qiE '(^|\s)Excluded'; then
  append_gap "G1" "Scope" "Excluded 하위 항목이 명시되지 않음 — 범위 경계 불분명"
fi

# G2: Success Criteria 측정 불가 (숫자 · % · < · > · >= · <= 부재)
if [[ -n "$SECTION_SUCCESS" ]]; then
  if ! printf '%s\n' "$SECTION_SUCCESS" | grep -qE '[0-9]+(\.[0-9]+)?%?|<|>|<=|>=|≤|≥'; then
    append_gap "G2" "Success Criteria" "측정 가능한 수치 기준이 없음 (숫자·부등호 부재)"
  fi
else
  append_gap "G2" "Success Criteria" "섹션 자체가 존재하지 않음"
fi

# G3: decisions 비어있음
if [[ "$DECISIONS_LEN" -eq 0 ]]; then
  append_gap "G3" "frontmatter.decisions" "decisions 배열이 비어있음 — /brainstorm 결정 누락"
fi

# G4: Constraints TBD/미정/나중에
if printf '%s\n' "$SECTION_CONSTRAINTS" | grep -qiE 'TBD|미정|나중에|as needed|적당히'; then
  append_gap "G4" "Constraints" "미해결 플레이스홀더(TBD/미정/나중에 등) 포함"
fi

# --- 출력 ---------------------------------------------------------------------

printf '%s\n' "$GAPS_JSON"

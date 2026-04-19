#!/usr/bin/env bash
# ambiguity-gate.sh — /plan Phase 1 모호도 게이트 (T-W3-05, 포팅 자산 #20)
#
# ouroboros ambiguity_score 개념을 bash 휴리스틱으로 포팅. 0.2 임계.
# lower = clearer (ouroboros seed-authoring 규칙 준수).
#
# 사용법:
#   scripts/ambiguity-gate.sh <requirements.md>
#
# 출력 (stdout):
#   {"score": 0.XX, "verdict": "pass"|"reject", "reason": "..."}
#
# 휴리스틱 (MVP 스텁):
#   base  = (vague_keyword_count / max(paragraph_count, 1))
#   +0.2  if frontmatter.decisions 길이 == 0
#   +0.1  if Scope Included/Excluded 중 한쪽만 존재
#   score = clamp(base, 0.0, 1.0)
#   verdict = (score < 0.2) ? pass : reject
#
# 보안 (v3.1 §4.3):
#   • set -euo pipefail
#   • 모든 변수 "$var"
#   • eval 금지
#   • jq filter --arg 바인딩만 사용

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

# --- 의존성 ------------------------------------------------------------------

for tool in jq awk yq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: $tool is required." >&2
    exit 2
  fi
done

# --- frontmatter + body 분리 -------------------------------------------------

FM_TMP="$(mktemp)"
BODY_TMP="$(mktemp)"
trap 'rm -f "$FM_TMP" "$BODY_TMP"' EXIT

awk '
  BEGIN { in_fm = 0; fm_done = 0 }
  /^---$/ {
    if (fm_done == 0 && in_fm == 0) { in_fm = 1; next }
    if (in_fm == 1) { in_fm = 0; fm_done = 1; next }
  }
  in_fm == 1 { print > "/dev/stderr" }
  fm_done == 1 || in_fm == 0 { print }
' "$REQ_PATH" 2>"$FM_TMP" >"$BODY_TMP"

# frontmatter 부재 시 DECISIONS_LEN=0 로 처리
if [[ ! -s "$FM_TMP" ]]; then
  DECISIONS_LEN=0
else
  DECISIONS_LEN="$(yq e '.decisions | length // 0' "$FM_TMP" 2>/dev/null || echo 0)"
  if [[ ! "$DECISIONS_LEN" =~ ^[0-9]+$ ]]; then
    DECISIONS_LEN=0
  fi
fi

# --- 모호 키워드 카운트 -------------------------------------------------------
# 본문에서 다음 키워드 등장 횟수 (대소문자 무시):
#   미정 · TBD · 나중에 · 모호 · as needed · 적당히 · 잘 되게 · 알맞게
VAGUE_COUNT="$(grep -ciE '미정|TBD|나중에|모호|as needed|적당히|잘 되게|알맞게' "$BODY_TMP" || true)"
if [[ ! "$VAGUE_COUNT" =~ ^[0-9]+$ ]]; then
  VAGUE_COUNT=0
fi

# --- 문단 수 (빈 줄 구분) -----------------------------------------------------
# paragraph = 연속 non-empty 라인 블록
PARA_COUNT="$(awk '
  BEGIN { in_para = 0; n = 0 }
  /^[[:space:]]*$/ { if (in_para == 1) { n++; in_para = 0 } }
  /[^[:space:]]/ { in_para = 1 }
  END { if (in_para == 1) { n++ } ; print n }
' "$BODY_TMP")"

if [[ "$PARA_COUNT" -lt 1 ]]; then
  PARA_COUNT=1
fi

# --- Scope Included/Excluded 존재 여부 ---------------------------------------

SECTION_SCOPE="$(awk '
  /^## / { capture = 0 }
  /^## +Scope/ { capture = 1; next }
  capture == 1 { print }
' "$BODY_TMP")"

HAS_INCLUDED=0
HAS_EXCLUDED=0
if printf '%s\n' "$SECTION_SCOPE" | grep -qiE '(^|[[:space:]])Included'; then
  HAS_INCLUDED=1
fi
if printf '%s\n' "$SECTION_SCOPE" | grep -qiE '(^|[[:space:]])Excluded'; then
  HAS_EXCLUDED=1
fi

# --- 점수 계산 ----------------------------------------------------------------
# bash 는 실수 연산이 없으니 awk/bc 대신 jq 로 처리.
SCORE_JSON="$(jq -n \
  --argjson vague "$VAGUE_COUNT" \
  --argjson paras "$PARA_COUNT" \
  --argjson dec "$DECISIONS_LEN" \
  --argjson inc "$HAS_INCLUDED" \
  --argjson exc "$HAS_EXCLUDED" \
  '
  ($vague / $paras) as $base
  | (if $dec == 0 then 0.2 else 0 end) as $nodec
  | (if ($inc + $exc) == 1 then 0.1 else 0 end) as $halfscope
  | ($base + $nodec + $halfscope) as $raw
  | (if $raw < 0 then 0 elif $raw > 1 then 1 else $raw end) as $clamped
  | {
      score: ($clamped * 100 | round / 100),
      vague_count: $vague,
      paragraph_count: $paras,
      decisions_len: $dec,
      scope_half: (($inc + $exc) == 1)
    }
  ')"

SCORE="$(printf '%s\n' "$SCORE_JSON" | jq -r '.score')"

# verdict
VERDICT="pass"
REASON="score < 0.2 — 모호도 임계 통과"
if awk -v s="$SCORE" 'BEGIN { exit !(s >= 0.2) }'; then
  VERDICT="reject"
  REASON="score >= 0.2 — 요구사항 모호. /brainstorm 재실행 권고"
fi

# --- 출력 ---------------------------------------------------------------------

jq -n \
  --argjson score "$SCORE" \
  --arg verdict "$VERDICT" \
  --arg reason "$REASON" \
  --argjson detail "$SCORE_JSON" \
  '{score: $score, verdict: $verdict, reason: $reason, detail: $detail}'

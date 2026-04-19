#!/usr/bin/env bash
# scripts/lib/overlap-dims.sh — T-W5-05 · 포팅 자산 #18 · v3.3 §3.4 Step 5
#
# 5-dim overlap scoring helper. sourced by scripts/overlap-score.sh.
# Python 금지 (§4.1). bash + awk + jq 만 사용.
#
# 제공 함수:
#   normalize_text  <stdin>                  → 토큰 스트림 (lowercase, 영숫자만, 공백구분)
#   jaccard_score   <text_a> <text_b>        → stdout 에 0.00~1.00 출력 (float)
#   files_overlap   <csv_a>   <csv_b>        → stdout 에 0.00~1.00 (파일명 단위 Jaccard)
#   band_from_matches <N>                    → "High"|"Moderate"|"Low"
#
# 보안 (§4.3 P0-8):
#   • set -eu (pipefail 은 caller 에 위임)
#   • 모든 변수 "$var"
#   • eval 금지

# --- 토큰 정규화 --------------------------------------------------------------

normalize_text() {
  # stdin → lowercase, 영숫자만 남기고 나머지는 공백, 중복 공백 압축
  tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9' ' ' \
    | tr -s ' ' \
    | sed 's/^ //;s/ $//'
}

# --- Jaccard score (text) -----------------------------------------------------

jaccard_score() {
  local a="$1"
  local b="$2"

  # 빈 입력 안전 처리
  if [[ -z "$a" && -z "$b" ]]; then
    printf '1.00\n'
    return 0
  fi
  if [[ -z "$a" || -z "$b" ]]; then
    printf '0.00\n'
    return 0
  fi

  local tokens_a tokens_b
  tokens_a="$(printf '%s' "$a" | normalize_text)"
  tokens_b="$(printf '%s' "$b" | normalize_text)"

  # stopwords: 영어·한국어 조사·범용 2글자 이하
  awk -v A="$tokens_a" -v B="$tokens_b" '
    BEGIN {
      split("the a an of in on at to for and or is are was were be been being this that these those it its i you we he she they with as by from", sw, " ")
      for (i in sw) STOP[sw[i]] = 1

      nA = split(A, xa, " ")
      for (i = 1; i <= nA; i++) {
        t = xa[i]
        if (length(t) <= 2) continue
        if (t in STOP) continue
        SA[t] = 1
      }
      nB = split(B, xb, " ")
      for (i = 1; i <= nB; i++) {
        t = xb[i]
        if (length(t) <= 2) continue
        if (t in STOP) continue
        SB[t] = 1
      }
      inter = 0
      for (k in SA) if (k in SB) inter++
      union = 0
      for (k in SA) union++
      for (k in SB) if (!(k in SA)) union++
      if (union == 0) { printf("0.00\n"); exit }
      printf("%.2f\n", inter / union)
    }
  '
}

# --- Files overlap (paths) ----------------------------------------------------

files_overlap() {
  local csv_a="$1"
  local csv_b="$2"

  if [[ -z "$csv_a" && -z "$csv_b" ]]; then
    printf '1.00\n'
    return 0
  fi
  if [[ -z "$csv_a" || -z "$csv_b" ]]; then
    printf '0.00\n'
    return 0
  fi

  awk -v A="$csv_a" -v B="$csv_b" '
    BEGIN {
      nA = split(A, xa, ",")
      for (i = 1; i <= nA; i++) {
        gsub(/^[ \t]+|[ \t]+$/, "", xa[i])
        if (length(xa[i]) > 0) SA[xa[i]] = 1
      }
      nB = split(B, xb, ",")
      for (i = 1; i <= nB; i++) {
        gsub(/^[ \t]+|[ \t]+$/, "", xb[i])
        if (length(xb[i]) > 0) SB[xb[i]] = 1
      }
      inter = 0
      for (k in SA) if (k in SB) inter++
      union = 0
      for (k in SA) union++
      for (k in SB) if (!(k in SA)) union++
      if (union == 0) { printf("0.00\n"); exit }
      printf("%.2f\n", inter / union)
    }
  '
}

# --- Band 분류 ----------------------------------------------------------------
#
# v3.3 §3.4 Step 5 + ce-compound SKILL.md:
#   • 4-5 dims match → High
#   • 2-3 dims match → Moderate
#   • 0-1 dims match → Low

band_from_matches() {
  local n="$1"
  if [[ "$n" -ge 4 ]]; then
    printf 'High\n'
  elif [[ "$n" -ge 2 ]]; then
    printf 'Moderate\n'
  else
    printf 'Low\n'
  fi
}

#!/usr/bin/env bash
# scripts/ku-2-run.sh — T-W7.5-03 · v3.3 §8.1 · AC-4
#
# KU-2: description 한·영 병기 A/B 정확도. 한·영 각 20 발화(총 40) 대상.
#   - English-only variant: skill description 에서 한국어 제거한 키워드로 매칭
#   - Bilingual (현재) variant: skill description 원문 그대로 키워드로 매칭
#   - 정확도 차이 |bilingual_ko - english_only_en| ≤ 5%p → PASS (양방향 기준 P1-3)
#
# 입력: __tests__/fixtures/ku-2-bilingual/*.json (40 샘플)
#       skills/{brainstorm,plan,verify,compound}/SKILL.md (description read-only)
# 출력: .claude/state/ku-results/ku-2.json
#
# 규칙 기반 매칭 (LLM judge 대체 — MVP §8.1):
#   - 각 발화 → 4개 스킬 각각의 키워드 집합과 substring match
#   - 최다 매칭 스킬을 예측. tie-break: alphabetical (brainstorm < compound < plan < verify)
#
# 제약: bash + jq + grep. Python 금지.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly FIXTURE_DIR="$ROOT/__tests__/fixtures/ku-2-bilingual"
readonly OUT="$ROOT/.claude/state/ku-results/ku-2.json"

DATA_SOURCE="${KU_DATA_SOURCE:-synthetic}"

mkdir -p "$(dirname "$OUT")"

# --- Extract description keyword bundles per skill (bilingual = current) ---
# We hand-curate keyword sets derived from current SKILL.md descriptions;
# this avoids brittle regex extraction and keeps the matcher deterministic.

# Keyword sets: PIPE-delimited phrases (phrases stay intact; whitespace inside is literal).
# Bilingual (한·영 mixed — current description)
kw_brainstorm_bi="brainstorm|브레인스토밍|clarify|vague|요구사항|ambiguity|scope|아이디어|뭘 만들지|think through|what should we build|spec this out|spec 정리"
kw_plan_bi="plan|계획|implementation plan|구현|break this down|태스크 분해|how should we build|plan this"
kw_verify_bi="verify|검증|qa-judge|ralph|산출물|재시도|promote|retry|reject|score this"
kw_compound_bi="compound|컴파운딩|session wrap|학습 저장|승격|promotion gate|memory promotion|pattern_repeat|correction|save learning"

# English-only (Korean tokens removed)
kw_brainstorm_en="brainstorm|clarify|vague|ambiguity|scope|think through|what should we build|spec this out"
kw_plan_en="plan|implementation plan|break this down|how should we build|plan this"
kw_verify_en="verify|qa-judge|ralph|promote|retry|reject|score this"
kw_compound_en="compound|session wrap|promotion gate|memory promotion|pattern_repeat|correction|save learning"

count_matches() {
  local utt="$1" kwset="$2"
  local utt_lc
  utt_lc="$(printf '%s' "$utt" | tr '[:upper:]' '[:lower:]')"
  local n=0
  local IFS='|'
  local kw
  # shellcheck disable=SC2086
  for kw in $kwset; do
    [[ -z "$kw" ]] && continue
    if [[ "${utt_lc}" == *"${kw}"* ]]; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}

# Predict skill given an utterance and a variant (bi|en)
predict_skill() {
  local utt="$1" variant="$2"
  local kb kp kv kc
  if [[ "$variant" == "bi" ]]; then
    kb="$kw_brainstorm_bi"; kp="$kw_plan_bi"; kv="$kw_verify_bi"; kc="$kw_compound_bi"
  else
    kb="$kw_brainstorm_en"; kp="$kw_plan_en"; kv="$kw_verify_en"; kc="$kw_compound_en"
  fi
  local nb np nv nc
  nb="$(count_matches "$utt" "$kb")"
  np="$(count_matches "$utt" "$kp")"
  nv="$(count_matches "$utt" "$kv")"
  nc="$(count_matches "$utt" "$kc")"

  # Pick max. Tie-break: alphabetical.
  local best="none" max=0
  # evaluate in alphabetical order so tie-break is automatic (first wins on strict >)
  for pair in "brainstorm:$nb" "compound:$nc" "plan:$np" "verify:$nv"; do
    local name="${pair%%:*}"
    local count="${pair##*:}"
    if [[ "$count" -gt "$max" ]]; then
      max="$count"; best="$name"
    fi
  done
  echo "$best"
}

# --- Measurement ---
bi_ko_correct=0; bi_ko_total=0
en_en_correct=0; en_en_total=0
per_sample_json="[]"

shopt -s nullglob
for f in "$FIXTURE_DIR"/*.json; do
  sid="$(jq -r '.sample_id' "$f")"
  lang="$(jq -r '.lang' "$f")"
  expected="$(jq -r '.expected_skill' "$f")"
  utt="$(jq -r '.utterance' "$f")"

  if [[ "$lang" == "ko" ]]; then
    predicted="$(predict_skill "$utt" "bi")"
    bi_ko_total=$((bi_ko_total + 1))
    [[ "$predicted" == "$expected" ]] && bi_ko_correct=$((bi_ko_correct + 1))
    variant="bilingual_ko"
  else
    predicted="$(predict_skill "$utt" "en")"
    en_en_total=$((en_en_total + 1))
    [[ "$predicted" == "$expected" ]] && en_en_correct=$((en_en_correct + 1))
    variant="english_only_en"
  fi

  per_sample_json="$(
    jq --arg sid "$sid" --arg exp "$expected" --arg pred "$predicted" --arg v "$variant" --arg utt "$utt" \
       '. + [{sample_id:$sid, variant:$v, expected:$exp, predicted:$pred, correct:($exp==$pred), utterance:$utt}]' \
       <<<"$per_sample_json"
  )"
done

bi_acc="$(awk -v c="$bi_ko_correct" -v t="$bi_ko_total" 'BEGIN { if (t>0) printf "%.2f", c/t; else print "0" }')"
en_acc="$(awk -v c="$en_en_correct" -v t="$en_en_total" 'BEGIN { if (t>0) printf "%.2f", c/t; else print "0" }')"
delta="$(awk -v a="$bi_acc" -v b="$en_acc" 'BEGIN { d=a-b; if (d<0) d=-d; printf "%.2f", d }')"

status="$(awk -v d="$delta" 'BEGIN { if (d+0 <= 0.05) print "GREEN"; else print "blocked_w8" }')"

jq -n \
  --arg ku "KU-2" --arg ac "AC-4" \
  --arg status "$status" --arg ds "$DATA_SOURCE" \
  --argjson bi_acc "$bi_acc" --argjson en_acc "$en_acc" --argjson delta "$delta" \
  --argjson bi_total "$bi_ko_total" --argjson en_total "$en_en_total" \
  --argjson bi_correct "$bi_ko_correct" --argjson en_correct "$en_en_correct" \
  --argjson per "$per_sample_json" \
  '{
    ku_id:$ku, ac:$ac, status:$status, data_source:$ds,
    samples:($bi_total + $en_total),
    bilingual: { lang:"ko", total:$bi_total, correct:$bi_correct, accuracy:$bi_acc },
    english_only: { lang:"en", total:$en_total, correct:$en_correct, accuracy:$en_acc },
    bilingual_accuracy:$bi_acc,
    english_only_accuracy:$en_acc,
    delta_abs:$delta,
    threshold:0.05,
    per_sample:$per
  }' > "$OUT"

echo "wrote: $OUT" >&2
jq '{status, bilingual_accuracy, english_only_accuracy, delta_abs}' "$OUT"

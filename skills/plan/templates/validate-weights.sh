#!/usr/bin/env bash
# validate-weights.sh — plan.md frontmatter의 evaluation_principles[].weight 합이 1.0 ± 0.01 인지 assertion.
#
# Usage: bash validate-weights.sh <plan.md>
#   - yq (-f extract) 로 frontmatter .evaluation_principles[].weight 추출
#   - awk 로 합산 (bash 산술은 부동소수 미지원)
#   - 합이 1.0 ± 0.01 → exit 0 + stdout "OK sum=<값>"
#   - 벗어나면 exit 1 + stderr "INVALID WEIGHTS: sum=<값>, expected 1.0 ± 0.01"
#
# 제약 (final-spec §4.3 · 🚨 P0-8):
#   - 모든 변수는 "$var" 쌍따옴표 보간
#   - eval 금지
#   - shellcheck 통과
#   - bash + yq + awk 만 사용 (Python/Node 금지)

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    printf 'INVALID WEIGHTS: expected exactly 1 argument (plan.md path), got %d\n' "$#" >&2
    exit 1
fi

plan_path="$1"

if [[ ! -f "${plan_path}" ]]; then
    printf 'INVALID WEIGHTS: file not found: %s\n' "${plan_path}" >&2
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    printf 'INVALID WEIGHTS: yq not installed\n' >&2
    exit 1
fi

# yq -f extract 로 Markdown frontmatter 에서 weight 목록만 추출.
weights="$(yq -f extract '.evaluation_principles[].weight' "${plan_path}" 2>/dev/null || true)"

if [[ -z "${weights}" ]]; then
    printf 'INVALID WEIGHTS: evaluation_principles missing or empty in %s\n' "${plan_path}" >&2
    exit 1
fi

# awk 로 합산 + 1.0 ± 0.01 범위 판정.
sum="$(printf '%s\n' "${weights}" | awk '{s+=$1} END {printf "%.4f", s}')"
verdict="$(awk -v s="${sum}" 'BEGIN { if (s+0 >= 0.99 && s+0 <= 1.01) print "ok"; else print "bad" }')"

if [[ "${verdict}" != "ok" ]]; then
    printf 'INVALID WEIGHTS: sum=%s, expected 1.0 ± 0.01\n' "${sum}" >&2
    exit 1
fi

printf 'OK sum=%s\n' "${sum}"
exit 0

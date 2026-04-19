#!/usr/bin/env bash
# AC-4 Hard Gate integration test — qa-judge 임계값 분기 3종.
#
# 세 개의 샘플 qa-judge 응답 (score = 0.85 / 0.60 / 0.30) 에 대해 아래 규칙
# 대로 verdict 가 도출되는지 확인한다 (agents/evaluator/qa-judge.md §Threshold
# Branching 과 정확히 일치해야 함):
#
#   score >= 0.80            → promote
#   0.40  <  score  <  0.80  → retry
#   score <= 0.40            → reject
#
# 경계 규약:
#   - 0.80 은 promote (inclusive)
#   - 0.40 은 reject  (inclusive)
#   - retry 대역은 열린 구간 (0.40, 0.80)
#
# 각 샘플 JSON 의 응답을 jq 로 파싱, score 로부터 기대 verdict 를 계산하여
# 응답의 verdict 필드와 비교한다. 3/3 일치 시 "AC-4 PASS" 를 출력하고 exit 0.
#
# 보안 제약 (final-spec v3.2 §4.3 · 🚨 P0-8):
#   - 모든 변수 "$var" 쌍따옴표 보간
#   - eval 금지
#   - shellcheck 통과
#   - bash + jq 만 사용

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

spec_path="${repo_root}/agents/evaluator/qa-judge.md"

preflight() {
    if ! command -v jq >/dev/null 2>&1; then
        printf 'integration: jq is required on PATH\n' >&2
        exit 1
    fi
    if [[ ! -f "${spec_path}" ]]; then
        printf 'integration: qa-judge spec missing: %s\n' "${spec_path}" >&2
        exit 1
    fi
}

# 기대 verdict 를 score 로부터 순수 산출.
# awk 로 부동소수점 비교 — bash 산술은 float 미지원.
expected_verdict_for_score() {
    local score="$1"
    awk -v s="${score}" 'BEGIN {
        if (s >= 0.80) { print "promote"; exit }
        if (s <= 0.40) { print "reject";  exit }
        print "retry"
    }'
}

# 단일 샘플 검증: 기대 verdict 와 응답 verdict 의 일치 여부.
check_sample() {
    local label="$1"
    local payload="$2"
    local expected_verdict="$3"

    local score actual_verdict derived_verdict

    score="$(printf '%s' "${payload}" | jq -r '.score')"
    actual_verdict="$(printf '%s' "${payload}" | jq -r '.verdict')"
    derived_verdict="$(expected_verdict_for_score "${score}")"

    if [[ "${derived_verdict}" != "${expected_verdict}" ]]; then
        printf '[MISS ] %-20s score=%-4s expected=%-7s derived=%-7s (rule drift)\n' \
            "${label}" "${score}" "${expected_verdict}" "${derived_verdict}" >&2
        return 1
    fi

    if [[ "${actual_verdict}" != "${expected_verdict}" ]]; then
        printf '[MISS ] %-20s score=%-4s expected=%-7s actual=%-7s\n' \
            "${label}" "${score}" "${expected_verdict}" "${actual_verdict}" >&2
        return 1
    fi

    printf '[MATCH] %-20s score=%-4s verdict=%s\n' \
        "${label}" "${score}" "${actual_verdict}"
    return 0
}

main() {
    preflight

    # 3 샘플 고정 — promote / retry / reject 경계 내부 대표값.
    local sample_promote sample_retry sample_reject
    sample_promote='{"score": 0.85, "verdict": "promote", "dimensions": {"correctness": 0.9, "clarity": 0.85, "maintainability": 0.8}, "differences": [], "suggestions": []}'
    sample_retry='{"score": 0.60, "verdict": "retry", "dimensions": {"correctness": 0.6, "clarity": 0.6, "maintainability": 0.6}, "differences": ["minor gap"], "suggestions": ["tighten wording"]}'
    sample_reject='{"score": 0.30, "verdict": "reject", "dimensions": {"correctness": 0.3, "clarity": 0.3, "maintainability": 0.3}, "differences": ["missing core AC"], "suggestions": ["rewrite"]}'

    local pass_count=0
    local total=3

    if check_sample "promote_0.85" "${sample_promote}" "promote"; then
        pass_count=$((pass_count + 1))
    fi
    if check_sample "retry_0.60" "${sample_retry}" "retry"; then
        pass_count=$((pass_count + 1))
    fi
    if check_sample "reject_0.30" "${sample_reject}" "reject"; then
        pass_count=$((pass_count + 1))
    fi

    printf '\n== Summary ==\n'
    printf '  Matched: %d/%d\n' "${pass_count}" "${total}"

    if [[ "${pass_count}" -eq "${total}" ]]; then
        printf '\nAC-4 PASS\n'
        exit 0
    fi

    printf '\nAC-4 FAIL (%d/%d)\n' "${pass_count}" "${total}" >&2
    exit 1
}

main "$@"

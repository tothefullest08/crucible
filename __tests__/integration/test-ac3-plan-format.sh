#!/usr/bin/env bash
# AC-3 Hard Gate integration test — /plan 하이브리드 포맷(Markdown + YAML
# frontmatter) 스키마 검증.
#
# 각 fixture (__tests__/fixtures/plan-ac3/plan-*.md) 에 대해 7개 체크를 순차
# 수행하고, 결과(PASS/FAIL)를 frontmatter `test_expected` 필드와 비교한다.
#
# 7개 체크 (v3.1 final-spec §10 AC-3):
#   C-1 YAML frontmatter 파싱 가능          (yq -f extract)
#   C-2 필수 필드 6개 존재                   (goal·constraints·AC
#                                             ·evaluation_principles
#                                             ·exit_conditions·parent_seed_id)
#   C-3 exit_conditions.{success,failure,timeout} 모두 non-null
#   C-4 evaluation_principles weight 합 = 1.0 ± 0.01
#                                             (validate-weights.sh 호출)
#   C-5 frontmatter slug 화이트리스트 통과    (output-slug-hook.sh 호출 +
#                                             정규식 ^[a-zA-Z0-9_-]+$)
#   C-6 본문에 Phase 1: ~ Phase 5: 모두 등장
#   C-7 본문 라인 수 > 100
#
# Exit 0 = AC-3 PASS (3/3 기대 매칭), 1 = AC-3 FAIL.
#
# 보안 제약 (final-spec v3.1 §4.3 · 🚨 P0-8):
#   - 모든 변수 "$var" 쌍따옴표 보간
#   - eval 금지
#   - shellcheck 통과
#   - bash + jq + yq 만 사용

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

fixtures_dir="${repo_root}/__tests__/fixtures/plan-ac3"
validate_weights="${repo_root}/skills/plan/templates/validate-weights.sh"
slug_hook="${repo_root}/skills/plan/templates/output-slug-hook.sh"

required_fields=(
    goal
    constraints
    AC
    evaluation_principles
    exit_conditions
    parent_seed_id
)

slug_regex='^[a-zA-Z0-9_-]+$'
phase_prefixes=(
    "Phase 1:"
    "Phase 2:"
    "Phase 3:"
    "Phase 4:"
    "Phase 5:"
)

min_body_lines=100

# 사전 조건: 필수 도구 · 경로 확인.
preflight() {
    if ! command -v yq >/dev/null 2>&1; then
        printf 'integration: yq is required on PATH\n' >&2
        exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        printf 'integration: jq is required on PATH\n' >&2
        exit 1
    fi
    if [[ ! -d "${fixtures_dir}" ]]; then
        printf 'integration: fixtures dir missing: %s\n' "${fixtures_dir}" >&2
        exit 1
    fi
    if [[ ! -x "${validate_weights}" && ! -f "${validate_weights}" ]]; then
        printf 'integration: validate-weights.sh missing: %s\n' \
            "${validate_weights}" >&2
        exit 1
    fi
    if [[ ! -x "${slug_hook}" && ! -f "${slug_hook}" ]]; then
        printf 'integration: output-slug-hook.sh missing: %s\n' \
            "${slug_hook}" >&2
        exit 1
    fi
}

# 7개 체크를 순차 수행하고 actual(PASS|FAIL)만 stdout으로 리턴.
# 첫 실패 체크에서 actual=FAIL 로 조기 리턴 (조기 실패 원칙).
run_checks() {
    local file="$1"

    # C-1 frontmatter 파싱 가능 여부.
    if ! yq -f extract '.' "${file}" >/dev/null 2>&1; then
        printf 'FAIL|C-1'
        return 0
    fi

    # C-2 필수 필드 6개 존재.
    local field
    for field in "${required_fields[@]}"; do
        if ! yq -f extract "has(\"${field}\")" "${file}" 2>/dev/null \
            | grep -qx 'true'; then
            printf 'FAIL|C-2:%s' "${field}"
            return 0
        fi
    done

    # C-3 exit_conditions.{success,failure,timeout} 모두 non-null.
    local ec_field ec_value
    for ec_field in success failure timeout; do
        ec_value="$(yq -f extract ".exit_conditions.${ec_field}" "${file}" \
            2>/dev/null || printf 'null')"
        if [[ -z "${ec_value}" || "${ec_value}" == "null" ]]; then
            printf 'FAIL|C-3:%s' "${ec_field}"
            return 0
        fi
    done

    # C-4 weight 합 = 1.0 ± 0.01.
    if ! bash "${validate_weights}" "${file}" >/dev/null 2>&1; then
        printf 'FAIL|C-4'
        return 0
    fi

    # C-5 slug 화이트리스트 통과 (정규식 + output-slug-hook.sh 재검증).
    local slug
    slug="$(yq -f extract '.slug' "${file}" 2>/dev/null || printf '')"
    if [[ -z "${slug}" || "${slug}" == "null" ]]; then
        printf 'FAIL|C-5:empty'
        return 0
    fi
    if [[ ! "${slug}" =~ ${slug_regex} ]]; then
        printf 'FAIL|C-5:regex'
        return 0
    fi
    if ! bash "${slug_hook}" "${slug}" >/dev/null 2>&1; then
        printf 'FAIL|C-5:hook'
        return 0
    fi

    # C-6 본문에 Phase 1: ~ Phase 5: 모두 등장.
    local phase
    for phase in "${phase_prefixes[@]}"; do
        if ! grep -qF "${phase}" "${file}"; then
            printf 'FAIL|C-6:%s' "${phase}"
            return 0
        fi
    done

    # C-7 본문(frontmatter 이후) 라인 수 > 100.
    # frontmatter 는 '---' 로 감싸진 첫 블록. awk 로 두 번째 '---' 이후를 집계.
    local body_lines
    body_lines="$(awk '
        BEGIN { in_fm = 0; fm_closed = 0; n = 0 }
        /^---[[:space:]]*$/ {
            if (in_fm == 0 && fm_closed == 0) { in_fm = 1; next }
            if (in_fm == 1) { in_fm = 0; fm_closed = 1; next }
        }
        fm_closed == 1 { n++ }
        END { print n }
    ' "${file}")"
    if [[ -z "${body_lines}" ]] \
        || ! [[ "${body_lines}" =~ ^[0-9]+$ ]] \
        || [[ "${body_lines}" -le "${min_body_lines}" ]]; then
        printf 'FAIL|C-7:%s' "${body_lines}"
        return 0
    fi

    printf 'PASS|'
}

main() {
    preflight

    local match=0
    local total=0
    local failures=()

    local fixture
    shopt -s nullglob
    local fixtures=("${fixtures_dir}"/plan-*.md)
    shopt -u nullglob

    if [[ "${#fixtures[@]}" -eq 0 ]]; then
        printf 'integration: no fixtures found in %s\n' "${fixtures_dir}" >&2
        exit 1
    fi

    for fixture in "${fixtures[@]}"; do
        total=$((total + 1))

        local expected
        expected="$(yq -f extract '.test_expected' "${fixture}" 2>/dev/null \
            || printf '')"
        if [[ "${expected}" != "PASS" && "${expected}" != "FAIL" ]]; then
            printf '[SKIP] %-40s missing/invalid test_expected\n' \
                "$(basename "${fixture}")" >&2
            failures+=("$(basename "${fixture}") expected=? actual=skip")
            continue
        fi

        local result actual reason
        result="$(run_checks "${fixture}")"
        actual="${result%%|*}"
        reason="${result#*|}"

        if [[ "${actual}" == "${expected}" ]]; then
            match=$((match + 1))
            printf '[MATCH] %-30s expected=%-4s actual=%-4s reason=%s\n' \
                "$(basename "${fixture}")" "${expected}" "${actual}" \
                "${reason:-ok}"
        else
            failures+=("$(basename "${fixture}") expected=${expected} actual=${actual} reason=${reason}")
            printf '[MISS ] %-30s expected=%-4s actual=%-4s reason=%s\n' \
                "$(basename "${fixture}")" "${expected}" "${actual}" \
                "${reason:-ok}" >&2
        fi
    done

    printf '\n== Summary ==\n'
    printf '  Matched: %d/%d\n' "${match}" "${total}"

    if [[ "${total}" -lt 3 ]]; then
        printf '\nAC-3 FAIL (fixture count < 3)\n' >&2
        exit 1
    fi

    if [[ "${match}" -eq "${total}" && "${total}" -eq 3 ]]; then
        printf '\nAC-3 PASS (3/3)\n'
        exit 0
    fi

    printf '\nAC-3 FAIL (%d/%d)\n' "${match}" "${total}" >&2
    local failure
    for failure in "${failures[@]}"; do
        printf '  - %s\n' "${failure}" >&2
    done
    exit 1
}

main "$@"

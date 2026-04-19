#!/usr/bin/env bash
# output-slug-hook.sh — /plan 산출물 저장 시 파일명 slug 생성 + 화이트리스트 검증.
#
# Usage: bash output-slug-hook.sh <description-or-goal>
#   1. 소문자 변환 + 공백/구분자 → '-' + 비[a-zA-Z0-9_-] 제거 + 최대 64자 cut
#   2. skills/brainstorm/templates/slug-validator.sh 로 화이트리스트 검증 (재사용)
#   3. 유효하면 stdout 에 slug, 무효하면 exit 1 + stderr "INVALID SLUG: <reason>"
#
# 제약 (final-spec §4.3 · 🚨 P0-8):
#   - 모든 변수는 "$var" 쌍따옴표 보간
#   - eval 금지
#   - shellcheck 통과
#   - brainstorm slug-validator.sh 재사용 (수정 금지)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
VALIDATOR="${REPO_ROOT}/skills/brainstorm/templates/slug-validator.sh"

if [[ "$#" -ne 1 ]]; then
    printf 'INVALID SLUG: expected exactly 1 argument (description), got %d\n' "$#" >&2
    exit 1
fi

input="$1"

if [[ -z "${input}" ]]; then
    printf 'INVALID SLUG: empty input\n' >&2
    exit 1
fi

if [[ ! -x "${VALIDATOR}" && ! -f "${VALIDATOR}" ]]; then
    printf 'INVALID SLUG: brainstorm slug-validator.sh not found at %s\n' "${VALIDATOR}" >&2
    exit 1
fi

# Step 0: 보안 pre-check — [a-zA-Z0-9 _-] 외 문자가 있으면 reject.
# 경로 순회 ('.', '/'), 명령 주입 (';', '|', '$', '`'), 유니코드 등을
# sanitize 로 가려두지 않고 즉시 거부하여 공격 표면을 줄인다.
if [[ "${input}" =~ [^a-zA-Z0-9[:space:]_-] ]]; then
    printf 'INVALID SLUG: input contains disallowed character(s) (input=%q)\n' "${input}" >&2
    exit 1
fi

# Step 1: slug 후보 생성.
# - 소문자 변환 (tr [:upper:] [:lower:])
# - 공백/허용 구분자 → '-' 치환
# - 연속 '-' 축약, 양끝 '-' 제거
# - 최대 64자 컷
lowered="$(printf '%s' "${input}" | tr '[:upper:]' '[:lower:]')"
replaced="$(printf '%s' "${lowered}" | LC_ALL=C sed -E 's/[[:space:]]+/-/g')"
squeezed="$(printf '%s' "${replaced}" | sed -E 's/-+/-/g; s/^-+//; s/-+$//')"
candidate="${squeezed:0:64}"

if [[ -z "${candidate}" ]]; then
    printf 'INVALID SLUG: candidate empty after sanitization (input=%q)\n' "${input}" >&2
    exit 1
fi

# Step 2: brainstorm slug-validator.sh 재사용.
if ! bash "${VALIDATOR}" "${candidate}"; then
    printf 'INVALID SLUG: validator rejected candidate=%s (input=%q)\n' "${candidate}" "${input}" >&2
    exit 1
fi

exit 0

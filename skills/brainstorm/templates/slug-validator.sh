#!/usr/bin/env bash
# slug-validator.sh — /brainstorm 출력 파일명 slug 화이트리스트 검증.
#
# Usage: bash slug-validator.sh <candidate-slug>
#   - 화이트리스트: ^[a-zA-Z0-9_-]+$
#   - 길이: 1~64자
#   - 통과 시: exit 0, stdout 에 slug 그대로 출력
#   - 실패 시: exit 1, stderr 에 "INVALID SLUG: <reason>" 출력
#
# 제약 (final-spec §4.3 · 🚨 P0-8):
#   - 모든 변수는 "$var" 쌍따옴표 보간
#   - eval 금지
#   - shellcheck 통과

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    printf 'INVALID SLUG: expected exactly 1 argument, got %d\n' "$#" >&2
    exit 1
fi

candidate="$1"

if [[ -z "${candidate}" ]]; then
    printf 'INVALID SLUG: empty string\n' >&2
    exit 1
fi

len="${#candidate}"
if (( len < 1 || len > 64 )); then
    printf 'INVALID SLUG: length %d out of range (1..64)\n' "${len}" >&2
    exit 1
fi

if [[ ! "${candidate}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    printf 'INVALID SLUG: characters outside whitelist [a-zA-Z0-9_-]\n' >&2
    exit 1
fi

printf '%s\n' "${candidate}"
exit 0

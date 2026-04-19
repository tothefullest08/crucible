#!/usr/bin/env bash
# slug-smoke.sh — T-W2-08 slug 화이트리스트 injection smoke test.
#
# T-W2-04의 slug-validator.sh 에 대해 5종 injection payload 가 전부 reject 되는지,
# 그리고 valid slug 1건이 accept 되는지 확인한다.
#
# Exit: 0 on success (5 reject + 1 accept), non-zero otherwise.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

validator="${repo_root}/skills/brainstorm/templates/slug-validator.sh"
fixtures_dir="${script_dir}/fixtures/slug-injection"

if [[ ! -f "${validator}" ]]; then
    printf 'FAIL: slug-validator.sh not found at %s\n' "${validator}" >&2
    exit 1
fi
if [[ ! -d "${fixtures_dir}" ]]; then
    printf 'FAIL: fixtures dir not found at %s\n' "${fixtures_dir}" >&2
    exit 1
fi

reject_count=0
for payload_file in "${fixtures_dir}"/*.txt; do
    [[ -e "${payload_file}" ]] || continue
    payload="$(cat "${payload_file}")"
    if bash "${validator}" "${payload}" >/dev/null 2>&1; then
        printf 'FAIL: %s PASSED slug-validator (should have been rejected)\n' \
            "${payload_file}" >&2
        exit 1
    fi
    reject_count=$((reject_count + 1))
done

if (( reject_count != 5 )); then
    printf 'FAIL: expected 5 injection payloads, found %d\n' "${reject_count}" >&2
    exit 1
fi

if ! bash "${validator}" "valid_slug-123" >/dev/null 2>&1; then
    printf 'FAIL: valid_slug-123 rejected (should pass)\n' >&2
    exit 1
fi

printf 'slug-smoke PASS: %d/%d injection rejected + 1/1 valid accepted\n' \
    "${reject_count}" "${reject_count}"
exit 0

#!/usr/bin/env bash
# drift-monitor.sh — bash+jq port of ouroboros drift-monitor.py
#
# Fires as PostToolUse (matcher "", Write|Edit tool class) — §4.3.6 순서 2번.
# Detects an active harness/ouroboros session whose JSON state file was touched
# within the last hour, and emits an advisory. Otherwise emits "Success".
#
# Logic parity with references/ouroboros/scripts/drift-monitor.py:
#   - scan ~/.ouroboros/data/ for files named interview_*.json (skip .lock)
#   - require newest mtime within the past 3600 seconds
#   - stdout: "Ouroboros session active (<name>). Use /ouroboros:status to check drift."
#   - otherwise: "Success"
#   - exit code is always 0 (advisory hook — never blocks the PostToolUse chain).
#
# Constraints (v3 §4.1, v3.2 §4.3):
#   - bash + jq + yq only (no Python).
#   - all vars quoted, no `eval`, shellcheck clean.

set -euo pipefail

SESSION_TTL_SECONDS=3600
SESSION_DIR="${HARNESS_DRIFT_SESSION_DIR:-${HOME}/.ouroboros/data}"

emit_success() {
  printf '%s\n' "Success"
}

emit_advisory() {
  local session_file="$1"
  printf '%s\n' "Ouroboros session active (${session_file}). Use /ouroboros:status to check drift."
}

# Exit early if no session dir — parity with the Python `if not ouroboros_dir.exists()` branch.
if [[ ! -d "${SESSION_DIR}" ]]; then
  emit_success
  exit 0
fi

# Gather candidate session files. Any error in globbing falls through to "Success".
newest_file=""
newest_mtime=0
now_epoch="$(date +%s)"

while IFS= read -r -d '' candidate; do
  name="$(basename "${candidate}")"

  case "${name}" in
    interview_*.json) : ;;
    *) continue ;;
  esac

  # Skip lock sidecars (.json.lock). `case` above already excludes non-.json,
  # but defensively re-check to match the Python `.lock` suffix filter.
  case "${name}" in
    *.lock) continue ;;
  esac

  # Defensive: validate JSON well-formedness with jq. Malformed files are ignored
  # — this is stricter than the Python original, which never parses, but stays
  # within "advisory-only" semantics because ignoring a malformed file still
  # yields the same advisory-or-Success decision on the remaining candidates.
  if ! jq -e . <"${candidate}" >/dev/null 2>&1; then
    continue
  fi

  # Portable mtime in epoch seconds (macOS BSD stat first, then GNU stat fallback).
  if mtime="$(stat -f %m "${candidate}" 2>/dev/null)"; then
    :
  elif mtime="$(stat -c %Y "${candidate}" 2>/dev/null)"; then
    :
  else
    continue
  fi

  if [[ "${mtime}" -gt "${newest_mtime}" ]]; then
    newest_mtime="${mtime}"
    newest_file="${name}"
  fi
done < <(find "${SESSION_DIR}" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)

if [[ -z "${newest_file}" ]]; then
  emit_success
  exit 0
fi

age=$(( now_epoch - newest_mtime ))
if [[ "${age}" -ge "${SESSION_TTL_SECONDS}" ]]; then
  emit_success
  exit 0
fi

emit_advisory "${newest_file}"
exit 0

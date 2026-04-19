#!/usr/bin/env bash
# Fixture: must FAIL the "no eval" rule.

set -euo pipefail

cmd="printf hello"
eval "${cmd}"

#!/usr/bin/env bash
# Fixture: must FAIL the "quoted variable expansion" rule.
# The linter should detect the bare $var usage on the echo line.

set -euo pipefail

greeting="hello"
echo $greeting

#!/usr/bin/env bash
# Deterministic L1 gate for [code]-tagged (and configured [eval]) tasks: runs
# typecheck + lint + test (+ optional format check) in one call. Output is
# captured and only printed when a check FAILS — a passing run costs a
# handful of tokens no matter how chatty the underlying tool is. Toggle
# individual checks in claude-workflow/gates/code-check.config; never edit
# this script just to turn a check on/off.
#
# CUSTOMIZE: replace the REPLACE_ME_* command strings near the bottom with
# this project's actual commands, based on the detected ecosystem, e.g.:
#   Node:   npm run type-check | npm run lint | npm test | npx prettier --check .
#   Python: mypy . | ruff check . (or flake8) | pytest | black --check .
#   Go:     go vet ./... | golangci-lint run | go test ./... | gofmt -l .
# The a11y/visual-regression lines are frontend-only — delete them for a
# backend-only project. Everything else in this file is generic — do not
# need to touch it.
set -uo pipefail

PROJECT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$PROJECT_DIR"

CONFIG_FILE="claude-workflow/gates/code-check.config"

# Defaults if code-check.config is missing or doesn't set a var
RUN_TYPECHECK=true
RUN_LINT=true
RUN_TEST=true
RUN_FORMAT=false
# Frontend/UI projects only — leave false and delete the two run_check lines
# below for backend-only projects (Python/NestJS APIs, etc). See the CUSTOMIZE
# note below before enabling either.
RUN_A11Y=false
RUN_VISUAL_REGRESSION=false
MAX_OUTPUT_LINES=80

# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

FAILED=0

run_check() {
  local name="$1" cmd="$2" output status
  output=$(eval "$cmd" 2>&1)
  status=$?
  if [ "$status" -eq 0 ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    echo "$output" | tail -n "$MAX_OUTPUT_LINES"
    FAILED=1
  fi
}

[ "$RUN_TYPECHECK" = true ] && run_check "typecheck" "REPLACE_ME_TYPECHECK_COMMAND"
[ "$RUN_LINT" = true ] && run_check "lint" "REPLACE_ME_LINT_COMMAND"
[ "$RUN_TEST" = true ] && run_check "test" "REPLACE_ME_TEST_COMMAND"
[ "$RUN_FORMAT" = true ] && run_check "format" "REPLACE_ME_FORMAT_COMMAND"
# Frontend/UI projects only. Delete these two lines entirely for backend-only
# projects. Do NOT wire up a command here from a guess — actually install the
# tooling (e.g. eslint-plugin-jsx-a11y, or Playwright + a committed baseline)
# and run the exact command once yourself to confirm it works before trusting
# it in the loop. Leave both toggles false in code-check.config until then.
[ "$RUN_A11Y" = true ] && run_check "a11y" "REPLACE_ME_A11Y_COMMAND"
[ "$RUN_VISUAL_REGRESSION" = true ] && run_check "visual-regression" "REPLACE_ME_VISUAL_REGRESSION_COMMAND"

if [ "$FAILED" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "SOME CHECKS FAILED — see output above"
  exit 1
fi

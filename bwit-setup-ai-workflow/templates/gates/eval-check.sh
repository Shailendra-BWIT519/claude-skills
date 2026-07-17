#!/usr/bin/env bash
# Deterministic L1 gate for [eval]-tagged tasks: runs the metric commands
# listed in claude-workflow/gates/eval.config and compares each result
# against its threshold. Only reached by run-plan.sh when eval.config has
# at least one real metric line — an empty/comment-only config means the
# task falls back to the human-gated path instead of calling this script.
#
# Exit codes: 0 = all metrics passed, 1 = at least one metric failed,
# 2 = no metric lines configured (should not normally be reached — run-plan.sh
# checks this itself before calling this script — but fail loud rather than
# silently exit 0 if it ever is).
set -uo pipefail

PROJECT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$PROJECT_DIR"

CONFIG_FILE="claude-workflow/gates/eval.config"
METRIC_LINES=$(grep -vE '^[[:space:]]*(#|$)' "$CONFIG_FILE" 2>/dev/null || true)

if [ -z "$METRIC_LINES" ]; then
  echo "NOT CONFIGURED: $CONFIG_FILE has no metric lines — this task should have been routed to the human-gated eval-judgment path, not eval-check.sh."
  exit 2
fi

FAILED=0

compare() {
  local value="$1" comparator="$2" threshold="$3"
  awk -v a="$value" -v b="$threshold" -v op="$comparator" '
    BEGIN {
      if (op == ">=") exit !(a >= b);
      if (op == "<=") exit !(a <= b);
      if (op == ">")  exit !(a > b);
      if (op == "<")  exit !(a < b);
      if (op == "==") exit !(a == b);
      exit 1;
    }'
}

while IFS='|' read -r name cmd comparator threshold; do
  value=$(eval "$cmd" 2>&1 | tail -n 1 | tr -d '[:space:]')
  if ! [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
    echo "FAIL: $name — command did not print a number (got: '$value')"
    FAILED=1
    continue
  fi
  if compare "$value" "$comparator" "$threshold"; then
    echo "PASS: $name ($value $comparator $threshold)"
  else
    echo "FAIL: $name ($value $comparator $threshold not satisfied)"
    FAILED=1
  fi
done <<< "$METRIC_LINES"

if [ "$FAILED" -eq 0 ]; then
  echo "ALL METRICS PASSED"
  exit 0
else
  echo "SOME METRICS FAILED — see output above"
  exit 1
fi

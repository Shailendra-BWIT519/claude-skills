#!/usr/bin/env bash
# Deterministic sign-off for a task paused by run-plan.sh's human-gated
# path ([design]/[structural]/[eval-judgment]/unconfigured [eval]). Flips
# the PLAN.md line from "- [~] ..." to "- [x] ...", logs the approval, and
# deletes AWAITING_APPROVAL.md so run-plan.sh can continue.
#
# This is plain bash on purpose — approving a checkbox is not a judgment
# task, so it doesn't get a claude -p session (files cheap, agents
# expensive). Rejection has no script: edit/revert the commit, reset the
# PLAN.md line back to "- [ ] ...", delete AWAITING_APPROVAL.md by hand,
# then re-run run-plan.sh — see AWAITING_APPROVAL.md itself for the exact
# steps, they travel with the pause.
set -uo pipefail

PROJECT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$PROJECT_DIR"

WORKFLOW_DIR="claude-workflow"
PLAN_FILE="$WORKFLOW_DIR/PLAN.md"
AWAITING_FILE="$WORKFLOW_DIR/AWAITING_APPROVAL.md"
AUDIT_LOG="$WORKFLOW_DIR/AUDIT_LOG.jsonl"

log() { echo "[approve] $*"; }

if [ ! -f "$AWAITING_FILE" ]; then
  log "ERROR: $AWAITING_FILE not found — nothing is awaiting approval."
  exit 1
fi

# AWAITING_APPROVAL.md records the exact PLAN.md task-line suffix (gate tag
# + task text, no checkbox) on a line of its own after "## PLAN.md line".
TASK_LINE=$(awk '/^## PLAN\.md line$/{getline; print; exit}' "$AWAITING_FILE")
GATE=$(awk '/^## Gate$/{getline; print; exit}' "$AWAITING_FILE")
SHA=$(awk '/^## Commit$/{getline; print; exit}' "$AWAITING_FILE")

if [ -z "$TASK_LINE" ]; then
  log "ERROR: could not read the task line out of $AWAITING_FILE — resolve by hand."
  exit 1
fi

if ! grep -qF -- "- [~] $TASK_LINE" "$PLAN_FILE"; then
  log "ERROR: no matching '- [~] ...' line in $PLAN_FILE for:"
  log "  $TASK_LINE"
  log "It may have already been approved, or $PLAN_FILE was hand-edited. Resolve by hand."
  exit 1
fi

# Literal-string replace (not sed regex) — task text routinely contains
# backticks/parens/brackets that sed would misinterpret as regex
# metacharacters, silently failing to match (this broke run-plan.sh's own
# "[ ] -> [~]" transition the same way; fixed there too).
node -e '
  const fs = require("fs");
  const [file, taskLine] = process.argv.slice(1);
  const oldLine = "- [~] " + taskLine;
  const newLine = "- [x] " + taskLine;
  const content = fs.readFileSync(file, "utf8");
  const lines = content.split("\n");
  const idx = lines.indexOf(oldLine);
  if (idx === -1) {
    process.stderr.write("approve.sh: no exact match for line: " + oldLine + "\n");
    process.exit(1);
  }
  lines[idx] = newLine;
  fs.writeFileSync(file, lines.join("\n"));
' -- "$PLAN_FILE" "$TASK_LINE"
if [ $? -ne 0 ]; then
  log "ERROR: could not flip $PLAN_FILE checkbox to '- [x] ...' — resolve by hand."
  exit 1
fi

APPROVER=$(git config user.email 2>/dev/null || echo "unknown")
node -e '
  const [task,gate,sha,approver] = process.argv.slice(1);
  process.stdout.write(JSON.stringify({
    ts: new Date().toISOString(), task, gate, code_model: null,
    review_model: null, outcome: "approved", sha: sha || null,
    reason: "approved by " + approver
  }) + "\n");
' -- "$TASK_LINE" "$GATE" "$SHA" "$APPROVER" >> "$AUDIT_LOG"

rm -f "$AWAITING_FILE"

log "Approved: $TASK_LINE"
log "Re-run: bash claude-workflow/run-plan.sh"

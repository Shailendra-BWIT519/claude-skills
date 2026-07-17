#!/usr/bin/env bash
# Execution loop: works through claude-workflow/PLAN.md one task at a time,
# each in a fresh `claude -p` session, with an L2 diff review after every
# task and an L3 adversarial review once the whole plan is checked off.
# Run from anywhere; it cd's to the repo root itself. Usage:
#   bash claude-workflow/run-plan.sh
#
# Per-run override example:
#   REVIEW_MODEL_OVERRIDE="claude-sonnet-5" bash claude-workflow/run-plan.sh
#
# Per-task model override: run classify-models.sh first. It writes
# claude-workflow/MODEL_PLAN.md with a proposed code/review model per task
# (cheapest model that can plausibly do the job) for you to review and edit.
# If MODEL_PLAN.md exists, its per-task choices win over CODE_MODEL/
# REVIEW_MODEL below; delete it to fall back to the static defaults. L3
# always uses FEATURE_REVIEW_MODEL — it isn't classified per-task since it's
# one holistic end-of-run review.
set -uo pipefail

# --- Model policy (the only place model choice should live) ---
CODE_MODEL="claude-sonnet-5"              # task implementation (default)
REVIEW_MODEL="claude-haiku-4-5-20251001"  # L2: per-task diff review (default)
FEATURE_REVIEW_MODEL="claude-sonnet-5"    # L3: feature-level review
# Critical feature (auth/payments)? Override just this one:
# FEATURE_REVIEW_MODEL="claude-opus-4-8"

REVIEW_MODEL="${REVIEW_MODEL_OVERRIDE:-$REVIEW_MODEL}"

# This script lives in claude-workflow/, but must operate from the repo root
# (git commands, npm test, file paths in prompts all assume root).
PROJECT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$PROJECT_DIR"

WORKFLOW_DIR="claude-workflow"
PLAN_FILE="$WORKFLOW_DIR/PLAN.md"
BLOCKED_FILE="$WORKFLOW_DIR/BLOCKED.md"
REVIEW_FILE="$WORKFLOW_DIR/REVIEW.md"
MODEL_PLAN_FILE="$WORKFLOW_DIR/MODEL_PLAN.md"

log() { echo "[run-plan] $*"; }

# Looks up a per-task model choice from MODEL_PLAN.md (written by
# classify-models.sh and reviewed by a human). Falls back to $3 if the file
# doesn't exist or has no matching block for this exact task text.
get_task_model() {
  local task="$1" field="$2" default="$3"
  if [ -f "$MODEL_PLAN_FILE" ]; then
    local val
    val=$(awk -v t="## Task: $task" '
      $0==t {found=1; next}
      /^## Task:/ {found=0}
      found {print}
    ' "$MODEL_PLAN_FILE" | grep -F -- "- ${field}:" | head -1 | sed "s/^- ${field}: *//")
    if [ -n "$val" ]; then
      echo "$val"
      return
    fi
  fi
  echo "$default"
}

# --- Safety checks ---
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  log "ERROR: on '$BRANCH'. Create/checkout a feature branch first."
  exit 1
fi

if [ -f "$BLOCKED_FILE" ]; then
  log "ERROR: $BLOCKED_FILE exists. Resolve it (and delete it) before running."
  exit 1
fi

if [ ! -f "$PLAN_FILE" ]; then
  log "ERROR: $PLAN_FILE not found. Run /sync in an interactive session first."
  exit 1
fi

run_task() {
  local task="$1" model="$2"
  claude -p "Read $PLAN_FILE and CLAUDE.md first.

Complete ONLY this one task, strictly in scope, with NO unrelated refactoring:

$task

Mimic existing codebase patterns (structure, naming, error handling, test
style). Run \`bash $WORKFLOW_DIR/check.sh\` to verify your work — it's the
single L1 gate (typecheck+lint+test, config toggles in
$WORKFLOW_DIR/check.config) — do not run individual npx/npm commands
separately, that burns far more tokens for the same signal. If it exits 0
(ALL CHECKS PASSED): mark this task [x] in $PLAN_FILE and create one git
commit with a clear conventional-commit message. If it still fails after 3
attempts: write the problem, what you tried, and check.sh's error output to
$BLOCKED_FILE — do NOT commit broken code. If the task is ambiguous or
impossible: write why to $BLOCKED_FILE. Do not guess." \
    --model "$model" \
    --permission-mode acceptEdits
}

run_l2_review() {
  local model="$1" diff
  diff=$(git diff HEAD~1 2>/dev/null)
  if [ -z "$diff" ]; then
    log "L2: no diff to review (no commit made), skipping."
    return 0
  fi
  claude -p "Review ONLY this diff. Check for bugs, security issues, missing
edge cases, and scope creep. If you find issues, write them to $REVIEW_FILE
with file:line references. If it's clean, respond with just: CLEAN

Diff:
$diff" \
    --model "$model" \
    --permission-mode acceptEdits
}

run_l3_review() {
  local diff
  diff=$(git diff main...HEAD 2>/dev/null)
  claude -p "You did NOT write this code. You are a skeptical senior reviewer.
Assume it has at least 2 problems — find them. Focus on: failure paths,
breaking inputs, design coherence across tasks, duplicated logic, and
integration gaps.

Full diff:
$diff" \
    --model "$FEATURE_REVIEW_MODEL" \
    --permission-mode acceptEdits
}

# --- Main loop ---
if [ -f "$MODEL_PLAN_FILE" ]; then
  log "$MODEL_PLAN_FILE found — using its per-task model choices where present."
fi

while grep -qE '^- \[ \]' "$PLAN_FILE"; do
  TASK_LINE=$(grep -E '^- \[ \]' "$PLAN_FILE" | head -1)
  TASK_TEXT="${TASK_LINE#- [ ] }"

  TASK_CODE_MODEL=$(get_task_model "$TASK_TEXT" "code_model" "$CODE_MODEL")
  TASK_REVIEW_MODEL=$(get_task_model "$TASK_TEXT" "review_model" "$REVIEW_MODEL")

  log "Task: $TASK_TEXT"
  log "  code: $TASK_CODE_MODEL | review: $TASK_REVIEW_MODEL"
  run_task "$TASK_TEXT" "$TASK_CODE_MODEL"

  if [ -f "$BLOCKED_FILE" ]; then
    log "STOP: $BLOCKED_FILE created. Human needed."
    exit 1
  fi

  NEW_TASK_LINE=$(grep -E '^- \[ \]' "$PLAN_FILE" | head -1 || true)
  if [ "$NEW_TASK_LINE" = "$TASK_LINE" ]; then
    log "STOP: task not ticked and not blocked (infinite-loop guard)."
    exit 1
  fi

  log "L2 review ($TASK_REVIEW_MODEL)..."
  run_l2_review "$TASK_REVIEW_MODEL"

  if [ -f "$REVIEW_FILE" ]; then
    log "L2 found issues — fixing before continuing..."
    claude -p "Read $REVIEW_FILE and fix the issues it raises. Add a
follow-up git commit, then delete $REVIEW_FILE." \
      --model "$TASK_CODE_MODEL" \
      --permission-mode acceptEdits
    rm -f "$REVIEW_FILE"
  fi
done

log "All PLAN.md tasks complete. Running L3 feature review ($FEATURE_REVIEW_MODEL)..."
run_l3_review

log "Done. L4 (human review of 'git diff main...HEAD') is next — that step is not automated."

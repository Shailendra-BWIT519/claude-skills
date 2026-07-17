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

# --- Timeouts (seconds) ---
# Every `claude -p` call runs headless with no one to answer a permission
# prompt it can't resolve from the pre-approved allowlist. Without a bound,
# a stuck call (permission wait, network stall, anything) hangs forever with
# near-zero CPU usage and no error — this happened for real during testing.
TASK_TIMEOUT=1200   # task implementation + L2-fix sessions: 20 min
REVIEW_TIMEOUT=600  # L2/L3 review sessions: 10 min

# Runs `claude -p` under a timeout; returns 124 on timeout (GNU coreutils
# `timeout` convention), otherwise claude's own exit code.
run_claude() {
  local timeout_s="$1"
  shift
  # -k 10: if SIGTERM doesn't kill a truly stuck process (e.g. blocked in a
  # syscall), send SIGKILL 10s later so the script always regains control.
  timeout -k 10 "$timeout_s" claude "$@"
}

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
  run_claude "$TASK_TIMEOUT" -p "Read $PLAN_FILE and CLAUDE.md first.

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
impossible: write why to $BLOCKED_FILE. Do not guess. If \`git commit\`
itself requires an approval you cannot obtain in this headless session,
that is a failure — write it to $BLOCKED_FILE exactly like a failing test,
do not mark the task done or claim success without an actual commit." \
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
  run_claude "$REVIEW_TIMEOUT" -p "Review ONLY this diff. Check for bugs, security issues, missing
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
  run_claude "$REVIEW_TIMEOUT" -p "You did NOT write this code. You are a skeptical senior reviewer.
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
  TASK_TEXT="${TASK_LINE#"- [ ] "}"

  TASK_CODE_MODEL=$(get_task_model "$TASK_TEXT" "code_model" "$CODE_MODEL")
  TASK_REVIEW_MODEL=$(get_task_model "$TASK_TEXT" "review_model" "$REVIEW_MODEL")

  log "Task: $TASK_TEXT"
  log "  code: $TASK_CODE_MODEL | review: $TASK_REVIEW_MODEL"
  BEFORE_HEAD=$(git rev-parse HEAD)
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

  # Safety net: PLAN.md isn't git-tracked, so ticking the checkbox alone
  # doesn't prove a commit happened. If HEAD didn't move, the session likely
  # hit a permission wall on `git commit` itself and silently gave up —
  # without this check the loop would proceed to L2 review, which would
  # end up reviewing the PREVIOUS task's already-committed diff instead of
  # this task's (uncommitted, possibly invisible) changes.
  AFTER_HEAD=$(git rev-parse HEAD)
  if [ "$BEFORE_HEAD" = "$AFTER_HEAD" ]; then
    log "STOP: $PLAN_FILE task was ticked but no new commit was created."
    cat > "$BLOCKED_FILE" <<EOF
# BLOCKED.md (auto-generated safety check by run-plan.sh)

## Task
$TASK_TEXT

## Problem
The task session marked this task \`[x]\` in $PLAN_FILE (or otherwise
reported success) but \`git HEAD\` did not move — no commit was actually
created. This usually means \`git commit\` itself required an approval that
could not be obtained in this headless session, and the session gave up
without reporting it as a failure.

## What to do
1. Run \`git status\` — the intended changes are likely sitting uncommitted
   in the working tree.
2. If they look correct: commit them yourself, then re-run.
3. If they look wrong: revert and investigate.

Delete this file once resolved, then re-run.
EOF
    exit 1
  fi

  log "L2 review ($TASK_REVIEW_MODEL)..."
  if ! run_l2_review "$TASK_REVIEW_MODEL"; then
    log "STOP: L2 review did not complete (timed out or failed) — a review"
    log "  that didn't run is not the same as a clean review. Not safe to"
    log "  proceed past this task without one."
    exit 1
  fi

  if [ -f "$REVIEW_FILE" ]; then
    log "L2 found issues — fixing before continuing..."
    BEFORE_FIX_HEAD=$(git rev-parse HEAD)
    run_claude "$TASK_TIMEOUT" -p "Read $REVIEW_FILE and fix the issues it raises. Add a
follow-up git commit, then delete $REVIEW_FILE. If a fix requires editing a
permission-gated file (e.g. .claude/settings.json) and you cannot get that
approval in this headless session, do NOT delete $REVIEW_FILE — leave it in
place with a note explaining exactly what's blocked and why, so a human
sees it." \
      --model "$TASK_CODE_MODEL" \
      --permission-mode acceptEdits

    # Only trust that the fix actually happened if BOTH: the session itself
    # deleted REVIEW.md (its own signal that it's done), AND a new commit
    # exists. Blindly rm -f'ing REVIEW.md here — regardless of whether the
    # fix succeeded — was the previous bug: a fix blocked by a permission
    # wall would silently vanish and the loop would carry on as if nothing
    # was wrong.
    AFTER_FIX_HEAD=$(git rev-parse HEAD)
    if [ -f "$REVIEW_FILE" ] || [ "$BEFORE_FIX_HEAD" = "$AFTER_FIX_HEAD" ]; then
      log "STOP: L2 fix did not complete ($REVIEW_FILE still present and/or no new commit). Human needed."
      exit 1
    fi
  fi
done

log "All PLAN.md tasks complete. Running L3 feature review ($FEATURE_REVIEW_MODEL)..."
if ! run_l3_review; then
  log "ERROR: L3 review did not complete (timed out or failed) — no"
  log "  feature-level review was produced. Do not treat this run as"
  log "  finished; re-run the L3 step manually, or investigate."
  exit 1
fi

log "Done. L4 (human review of 'git diff main...HEAD') is next — that step is not automated."

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
#
# --- Gate types (tagged on each PLAN.md task, see claude-workflow/gates/) ---
# [code]           deterministic: claude-workflow/gates/code-check.sh
# [eval]           deterministic IF gates/eval.config has real thresholds,
#                  else falls back to the human-gated path below
# [design]         human-gated: self-check against gates/design-checklist.md,
#                  then mandatory sign-off via claude-workflow/approve.sh
# [eval-judgment]  human-gated: self-check against gates/eval-judgment-checklist.md
# [structural]     human-gated: self-check against gates/structural-checklist.md
#                  — also the default for any untagged/unrecognized task
#
# Human-gated tasks still commit (so the work is git-tracked for review) but
# the loop pauses — claude-workflow/AWAITING_APPROVAL.md is written and the
# script exits 0 (an expected pause, not a failure). Run `approve.sh`, then
# re-run this script to continue. Every outcome (committed / blocked /
# awaiting_approval / approved) is appended to claude-workflow/AUDIT_LOG.jsonl
# by this script only — task/review sessions never write to it.
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
GATES_DIR="$WORKFLOW_DIR/gates"
PLAN_FILE="$WORKFLOW_DIR/PLAN.md"
BLOCKED_FILE="$WORKFLOW_DIR/BLOCKED.md"
REVIEW_FILE="$WORKFLOW_DIR/REVIEW.md"
MODEL_PLAN_FILE="$WORKFLOW_DIR/MODEL_PLAN.md"
AWAITING_FILE="$WORKFLOW_DIR/AWAITING_APPROVAL.md"
AUDIT_LOG="$WORKFLOW_DIR/AUDIT_LOG.jsonl"

log() { echo "[run-plan] $*"; }

# Looks up a per-task model choice from MODEL_PLAN.md (written by
# classify-models.sh and reviewed by a human). Falls back to $3 if the file
# doesn't exist or has no matching block for this exact task text. The
# lookup key is the RAW task text including its gate tag, matching what
# classify-models.sh writes as "## Task:" headers.
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

# --- Gate dispatch (the only place gate semantics live) ---

parse_gate_tag() {
  local tag
  tag=$(echo "$1" | grep -oE '^\[[a-z-]+\]' | tr -d '[]')
  case "$tag" in
    code|design|eval|eval-judgment|structural) echo "$tag" ;;
    *) echo "structural" ;;   # untagged/unrecognized -> strictest default, fail safe
  esac
}

strip_gate_tag() {
  echo "$1" | sed -E 's/^\[[a-z-]+\] //'
}

is_blocked_line() {
  echo "$1" | grep -qE '^- \[ \] (\[[a-z-]+\] )?\[blocked\]'
}

gate_is_human_required() {
  case "$1" in
    code) return 1 ;;
    eval)
      local metric_lines
      metric_lines=$(grep -vE '^[[:space:]]*(#|$)' "$GATES_DIR/eval.config" 2>/dev/null || true)
      [ -n "$metric_lines" ] && return 1
      return 0   # unconfigured eval -> fail safe to human gate, never silently pass
      ;;
    design|eval-judgment|structural) return 0 ;;
    *) return 0 ;;
  esac
}

gate_check_script() {   # only called when gate_is_human_required = false
  case "$1" in
    code) echo "$GATES_DIR/code-check.sh" ;;
    eval) echo "$GATES_DIR/eval-check.sh" ;;
  esac
}

gate_checklist_file() {   # only called when gate_is_human_required = true
  local file
  case "$1" in
    design) file="$GATES_DIR/design-checklist.md" ;;
    eval-judgment) file="$GATES_DIR/eval-judgment-checklist.md" ;;
    eval) file="$GATES_DIR/eval-judgment-checklist.md" ;;   # unconfigured eval falls back here
    *) file="$GATES_DIR/structural-checklist.md" ;;
  esac
  [ -f "$file" ] && echo "$file" || echo ""
}

# Append-only, called ONLY from this script — never from a claude -p task or
# review session — which is what makes the audit trail tamper-resistant.
audit_log() {
  local task="$1" gate="$2" code_model="$3" review_model="$4" outcome="$5" sha="$6" reason="$7"
  node -e '
    const [task,gate,code_model,review_model,outcome,sha,reason] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({
      ts: new Date().toISOString(), task, gate, code_model: code_model || null,
      review_model: review_model || null, outcome, sha: sha || null,
      reason: reason || null
    }) + "\n");
  ' -- "$task" "$gate" "$code_model" "$review_model" "$outcome" "$sha" "$reason" >> "$AUDIT_LOG"
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

if [ -f "$AWAITING_FILE" ]; then
  log "ERROR: $AWAITING_FILE exists — a human-gated task is awaiting sign-off."
  log "  Approve: bash claude-workflow/approve.sh"
  log "  Reject: revert/edit the commit, reset its PLAN.md line to '- [ ] ...', delete $AWAITING_FILE."
  exit 1
fi

if [ ! -f "$PLAN_FILE" ]; then
  log "ERROR: $PLAN_FILE not found. Run /sync in an interactive session first."
  exit 1
fi

run_task() {
  local task_text_raw="$1" task_text="$2" gate="$3" model="$4"
  local body

  if gate_is_human_required "$gate"; then
    local checklist_file checklist_content
    checklist_file=$(gate_checklist_file "$gate")
    if [ -n "$checklist_file" ]; then
      checklist_content=$(cat "$checklist_file")
    else
      checklist_content="(No project-specific checklist configured for gate '$gate' — self-check against claude-workflow/REQUIREMENTS.md and general judgment instead.)"
    fi
    body="Read $PLAN_FILE and CLAUDE.md first.

Complete ONLY this one task, strictly in scope, with NO unrelated refactoring:

$task_text

Mimic existing codebase patterns (structure, naming, error handling, test
style). This task's gate is '$gate' — a HUMAN must sign off before it counts
as done, so there is no automated pass/fail here. Self-check your work
against this checklist and note the results in your commit message:

---
$checklist_content
---

If the self-check is satisfied: create one git commit with a clear
conventional-commit message (include a brief checklist summary in the body).
Do NOT edit the checkbox for this task in $PLAN_FILE — leave the line
exactly as '- [ ] $task_text_raw'; this script updates its status itself
after this session ends. If the task is genuinely incomplete after 3
attempts, or is ambiguous/impossible: write the problem to $BLOCKED_FILE —
do NOT commit partial or guessed work. If \`git commit\` itself requires an
approval you cannot obtain in this headless session, that is a failure —
write it to $BLOCKED_FILE exactly like a failing check, do not claim
success without an actual commit."
  else
    local check_script
    check_script=$(gate_check_script "$gate")
    body="Read $PLAN_FILE and CLAUDE.md first.

Complete ONLY this one task, strictly in scope, with NO unrelated refactoring:

$task_text

Mimic existing codebase patterns (structure, naming, error handling, test
style). Run \`bash $check_script\` to verify your work — it's the single L1
gate for this task's gate type ('$gate'), config toggles alongside it in
$GATES_DIR — do not run individual npx/npm commands separately, that burns
far more tokens for the same signal. If it exits 0 (ALL CHECKS PASSED /
ALL METRICS PASSED): change '- [ ] $task_text_raw' to '- [x] $task_text_raw'
in $PLAN_FILE and create one git commit with a clear conventional-commit
message. If it still fails after 3 attempts: write the problem, what you
tried, and the check's error output to $BLOCKED_FILE — do NOT commit broken
code. If the task is ambiguous or impossible: write why to $BLOCKED_FILE. Do
not guess. If \`git commit\` itself requires an approval you cannot obtain
in this headless session, that is a failure — write it to $BLOCKED_FILE
exactly like a failing check, do not mark the task done or claim success
without an actual commit."
  fi

  run_claude "$TASK_TIMEOUT" -p "$body" \
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
edge cases, scope creep, and — for non-code changes — inconsistency with the
requirement it's meant to satisfy. If you find issues, write them to
$REVIEW_FILE with file:line references. If it's clean, respond with just: CLEAN

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
  # Pick the first unchecked, non-[blocked] task line.
  TASK_LINE=""
  while IFS= read -r candidate; do
    if is_blocked_line "$candidate"; then
      continue
    fi
    TASK_LINE="$candidate"
    break
  done < <(grep -E '^- \[ \]' "$PLAN_FILE")

  if [ -z "$TASK_LINE" ]; then
    log "STOP: every remaining unchecked task is [blocked]. Resolve $WORKFLOW_DIR/QUESTIONS.md, then re-run."
    exit 1
  fi

  # Quoted pattern: unquoted "[ ]" here would be parsed as a glob bracket
  # class (matching one space) rather than literal brackets, so "- [ ] "
  # would silently fail to strip at all — quoting forces a literal match.
  TASK_TEXT_RAW="${TASK_LINE#'- [ ] '}"
  GATE=$(parse_gate_tag "$TASK_TEXT_RAW")
  TASK_TEXT=$(strip_gate_tag "$TASK_TEXT_RAW")

  TASK_CODE_MODEL=$(get_task_model "$TASK_TEXT_RAW" "code_model" "$CODE_MODEL")
  TASK_REVIEW_MODEL=$(get_task_model "$TASK_TEXT_RAW" "review_model" "$REVIEW_MODEL")

  log "Task: $TASK_TEXT"
  log "  gate: $GATE | code: $TASK_CODE_MODEL | review: $TASK_REVIEW_MODEL"
  BEFORE_HEAD=$(git rev-parse HEAD)
  run_task "$TASK_TEXT_RAW" "$TASK_TEXT" "$GATE" "$TASK_CODE_MODEL"

  if [ -f "$BLOCKED_FILE" ]; then
    log "STOP: $BLOCKED_FILE created. Human needed."
    audit_log "$TASK_TEXT_RAW" "$GATE" "$TASK_CODE_MODEL" "$TASK_REVIEW_MODEL" "blocked" "" "see $BLOCKED_FILE"
    exit 1
  fi

  # Safety net: PLAN.md isn't git-tracked, so a claimed success (or a
  # silent timeout) alone doesn't prove a commit happened. If HEAD didn't
  # move, the session likely hit a permission wall on `git commit` itself,
  # timed out, and silently gave up — without this check the loop would
  # proceed to L2 review, which would end up reviewing the PREVIOUS task's
  # already-committed diff instead of this task's (uncommitted, possibly
  # invisible) changes.
  AFTER_HEAD=$(git rev-parse HEAD)
  if [ "$BEFORE_HEAD" = "$AFTER_HEAD" ]; then
    log "STOP: $PLAN_FILE task was attempted but no new commit was created."
    cat > "$BLOCKED_FILE" <<EOF
# BLOCKED.md (auto-generated safety check by run-plan.sh)

## Task
$TASK_TEXT

## Problem
The task session did not produce a new commit — \`git HEAD\` did not move.
This usually means \`git commit\` itself required an approval that could
not be obtained in this headless session (or the session timed out after
${TASK_TIMEOUT}s), and it gave up without reporting it as a failure.

## What to do
1. Run \`git status\` — the intended changes are likely sitting uncommitted
   in the working tree.
2. If they look correct: commit them yourself, then re-run.
3. If they look wrong: revert and investigate.

Delete this file once resolved, then re-run.
EOF
    audit_log "$TASK_TEXT_RAW" "$GATE" "$TASK_CODE_MODEL" "$TASK_REVIEW_MODEL" "blocked" "" "no commit created"
    exit 1
  fi

  # For deterministic gates, the task session itself is responsible for
  # ticking the checkbox — verify it actually did (infinite-loop guard).
  # Human-gated tasks are deliberately left unticked by the session (this
  # script owns that transition, see below), so this check only applies to
  # the deterministic path.
  if ! gate_is_human_required "$GATE"; then
    if grep -qF -- "- [ ] $TASK_TEXT_RAW" "$PLAN_FILE"; then
      log "STOP: task committed but $PLAN_FILE line was never ticked (infinite-loop guard)."
      audit_log "$TASK_TEXT_RAW" "$GATE" "$TASK_CODE_MODEL" "$TASK_REVIEW_MODEL" "blocked" "$AFTER_HEAD" "checkbox not ticked after commit"
      exit 1
    fi
  fi

  log "L2 review ($TASK_REVIEW_MODEL)..."
  if ! run_l2_review "$TASK_REVIEW_MODEL"; then
    log "STOP: L2 review did not complete (timed out or failed) — a review"
    log "  that didn't run is not the same as a clean review. Not safe to"
    log "  proceed past this task without one."
    audit_log "$TASK_TEXT_RAW" "$GATE" "$TASK_CODE_MODEL" "$TASK_REVIEW_MODEL" "blocked" "$AFTER_HEAD" "L2 review did not complete"
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
    # fix succeeded — was a previous bug: a fix blocked by a permission
    # wall would silently vanish and the loop would carry on as if nothing
    # was wrong.
    AFTER_FIX_HEAD=$(git rev-parse HEAD)
    if [ -f "$REVIEW_FILE" ] || [ "$BEFORE_FIX_HEAD" = "$AFTER_FIX_HEAD" ]; then
      log "STOP: L2 fix did not complete ($REVIEW_FILE still present and/or no new commit). Human needed."
      audit_log "$TASK_TEXT_RAW" "$GATE" "$TASK_CODE_MODEL" "$TASK_REVIEW_MODEL" "blocked" "$AFTER_FIX_HEAD" "L2 fix did not complete"
      exit 1
    fi
  fi

  if gate_is_human_required "$GATE"; then
    SHA=$(git rev-parse HEAD)
    ESCAPED_TASK_TEXT_RAW=$(printf '%s\n' "$TASK_TEXT_RAW" | sed 's/[&/\]/\\&/g')
    sed -i "s/^- \[ \] ${ESCAPED_TASK_TEXT_RAW}\$/- [~] ${ESCAPED_TASK_TEXT_RAW}/" "$PLAN_FILE"

    cat > "$AWAITING_FILE" <<EOF
# AWAITING_APPROVAL.md (written by run-plan.sh — expected pause, not a failure)

## Task
$TASK_TEXT

## Gate
$GATE — human sign-off is mandatory for this gate type, regardless of how
clean the self-check or L2 review looked. See run-plan.sh's own log output
above for the L2 verdict on this commit.

## PLAN.md line
$TASK_TEXT_RAW

## Commit
$SHA

## To resume
- Approve: bash claude-workflow/approve.sh
- Reject: revert or edit commit $SHA, reset the PLAN.md line above back to
  "- [ ] $TASK_TEXT_RAW", delete this file, then re-run run-plan.sh.
EOF
    audit_log "$TASK_TEXT_RAW" "$GATE" "$TASK_CODE_MODEL" "$TASK_REVIEW_MODEL" "awaiting_approval" "$SHA" "human sign-off required for gate type $GATE"
    log "PAUSED: awaiting human approval for a $GATE task. See $AWAITING_FILE."
    exit 0
  fi

  audit_log "$TASK_TEXT_RAW" "$GATE" "$TASK_CODE_MODEL" "$TASK_REVIEW_MODEL" "committed" "$(git rev-parse HEAD)" ""
done

log "All PLAN.md tasks complete. Running L3 feature review ($FEATURE_REVIEW_MODEL)..."
if ! run_l3_review; then
  log "ERROR: L3 review did not complete (timed out or failed) — no"
  log "  feature-level review was produced. Do not treat this run as"
  log "  finished; re-run the L3 step manually, or investigate."
  exit 1
fi

log "Done. L4 (human review of 'git diff main...HEAD') is next — that step is not automated."

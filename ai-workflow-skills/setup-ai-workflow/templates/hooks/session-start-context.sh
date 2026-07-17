#!/usr/bin/env bash
# Loads durable state back into context at the start of every session:
# branch/diff status, pending claude-workflow/PLAN.md tasks, any pending
# HANDOFF.md, claude-workflow/BLOCKED.md, an awaiting-approval pause, and a
# tail of the audit log.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
STATUS=$(git status --short 2>/dev/null | head -15)

CTX="## Session context"$'\n'"Branch: $BRANCH"

if [ -n "$STATUS" ]; then
  CTX+=$'\n\n'"Uncommitted changes:"$'\n'"$STATUS"
fi

if [ -f "$PROJECT_DIR/claude-workflow/PLAN.md" ]; then
  PENDING=$(grep -E '^[[:space:]]*-[[:space:]]*\[ \]' "$PROJECT_DIR/claude-workflow/PLAN.md" | head -10)
  if [ -n "$PENDING" ]; then
    CTX+=$'\n\n'"Pending claude-workflow/PLAN.md tasks:"$'\n'"$PENDING"
  fi
fi

if [ -f "$PROJECT_DIR/.claude/HANDOFF.md" ]; then
  CTX+=$'\n\n'"--- .claude/HANDOFF.md (left by a previous heavy session) ---"$'\n'"$(cat "$PROJECT_DIR/.claude/HANDOFF.md")"
fi

if [ -f "$PROJECT_DIR/claude-workflow/BLOCKED.md" ]; then
  CTX+=$'\n\n'"WARNING: claude-workflow/BLOCKED.md exists — resolve before running the automated loop."$'\n'"$(cat "$PROJECT_DIR/claude-workflow/BLOCKED.md")"
fi

if [ -f "$PROJECT_DIR/claude-workflow/AWAITING_APPROVAL.md" ]; then
  CTX+=$'\n\n'"PAUSED: claude-workflow/AWAITING_APPROVAL.md exists — a human-gated task needs sign-off (bash claude-workflow/approve.sh) before the loop can continue."$'\n'"$(cat "$PROJECT_DIR/claude-workflow/AWAITING_APPROVAL.md")"
fi

AUDIT_LOG="$PROJECT_DIR/claude-workflow/AUDIT_LOG.jsonl"
if [ -f "$AUDIT_LOG" ]; then
  AUDIT_TAIL=$(tail -n 5 "$AUDIT_LOG" | node -e '
    let d="";
    process.stdin.on("data",c=>d+=c);
    process.stdin.on("end",()=>{
      const lines = d.split("\n").filter(Boolean).map(l => {
        try {
          const e = JSON.parse(l);
          return `${e.ts}  ${e.outcome.padEnd(17)} [${e.gate}]  ${e.task}`;
        } catch(err) { return null; }
      }).filter(Boolean);
      console.log(lines.join("\n"));
    });
  ')
  if [ -n "$AUDIT_TAIL" ]; then
    CTX+=$'\n\n'"Recent claude-workflow/AUDIT_LOG.jsonl entries:"$'\n'"$AUDIT_TAIL"
  fi
fi

node -e '
const ctx = process.argv[1];
process.stdout.write(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ctx
  }
}));
' "$CTX"

exit 0

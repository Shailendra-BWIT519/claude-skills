#!/usr/bin/env bash
# Loads durable state back into context at the start of every session:
# branch/diff status, pending claude-workflow/PLAN.md tasks, any pending
# HANDOFF.md, claude-workflow/BLOCKED.md.
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

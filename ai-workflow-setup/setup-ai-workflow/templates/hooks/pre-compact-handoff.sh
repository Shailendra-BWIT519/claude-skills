#!/usr/bin/env bash
# Auto-compact safety net: backs up the transcript and dumps enough state to
# .claude/HANDOFF.md that a fresh session can pick the work back up.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

INPUT=$(cat)
TRANSCRIPT_PATH=$(node -e '
let d="";
process.stdin.on("data",c=>d+=c);
process.stdin.on("end",()=>{
  try { console.log(JSON.parse(d).transcript_path || ""); } catch(e) { console.log(""); }
});
' <<< "$INPUT")

BACKUP_DIR="$PROJECT_DIR/.claude/backups"
mkdir -p "$BACKUP_DIR"

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  STAMP=$(date +%Y%m%d-%H%M%S)
  cp "$TRANSCRIPT_PATH" "$BACKUP_DIR/transcript-$STAMP.jsonl" 2>/dev/null || true
  # keep only the last 5 backups
  ls -1t "$BACKUP_DIR"/transcript-*.jsonl 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null || true
fi

HANDOFF="$PROJECT_DIR/.claude/HANDOFF.md"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
STATUS=$(git status --short 2>/dev/null)
COMMITS=$(git log -5 --oneline 2>/dev/null)

{
  echo "# Auto-generated handoff (pre-compact safety net)"
  echo ""
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Branch: $BRANCH"
  echo ""
  echo "## Uncommitted changes (= in-progress work)"
  if [ -n "$STATUS" ]; then
    echo '```'
    echo "$STATUS"
    echo '```'
  else
    echo "(clean)"
  fi
  echo ""
  echo "## Last 5 commits"
  echo '```'
  echo "$COMMITS"
  echo '```'
  echo ""
  echo "## claude-workflow/PLAN.md task status"
  if [ -f "$PROJECT_DIR/claude-workflow/PLAN.md" ]; then
    # [ xX~] — must include ~ (awaiting-approval), or those tasks silently
    # vanish from this dump the moment run-plan.sh pauses on one.
    grep -E '^[[:space:]]*-[[:space:]]*\[[ xX~]\]' "$PROJECT_DIR/claude-workflow/PLAN.md" || echo "(no tasks found)"
  else
    echo "(no claude-workflow/PLAN.md)"
  fi
  echo ""
  echo "## Human-gated pause"
  if [ -f "$PROJECT_DIR/claude-workflow/AWAITING_APPROVAL.md" ]; then
    echo "AWAITING_APPROVAL.md exists — run \`bash claude-workflow/approve.sh\` (or reject per its instructions) before resuming run-plan.sh."
  else
    echo "(none)"
  fi
} > "$HANDOFF"

exit 0

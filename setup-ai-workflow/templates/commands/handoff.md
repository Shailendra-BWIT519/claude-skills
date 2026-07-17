Write .claude/HANDOFF.md (overwrite, under 60 lines) with these sections:

## Task
One line: what and why.

## Done
Verified-complete items, with file paths.

## In progress
What's half-finished, in which file, and the next concrete step.

## Edge cases & gotchas
Things that don't show up in the code or claude-workflow/PLAN.md: decisions
made, weird behaviors discovered, failed approaches not to retry.

## Verify
Exact test/build commands to confirm the work.

Then update the claude-workflow/PLAN.md checkboxes to match reality, and say
"Handoff ready — /clear now."

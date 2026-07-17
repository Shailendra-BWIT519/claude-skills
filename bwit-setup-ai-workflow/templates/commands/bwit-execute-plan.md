Run `bash claude-workflow/run-plan.sh` and report back what happened.

- If it completed a task and continued: say which task, which gate, and
  that it auto-committed.
- If it paused (`claude-workflow/AWAITING_APPROVAL.md` was written): show
  the task, the gate, and the commit SHA. Show the actual `git show <sha>`
  diff so the user can decide — do not just describe it. Tell them their
  options: `/bwit-approve-plan` or `/bwit-reject-plan`.
- If it wrote `claude-workflow/BLOCKED.md`: show its contents in full —
  this needs the user's judgment, not another automatic retry.
- If it wrote `claude-workflow/L3_SKIPPED.md`: mention it exists and
  summarize why in one line — this is not a failure.
- If every task is already `[x]` and there's nothing to run: say so plainly
  instead of running it anyway.

Do not run `claude-workflow/approve.sh` yourself from this command, even if
the diff looks obviously fine — that decision belongs to `/bwit-approve-plan`,
invoked explicitly by the user.

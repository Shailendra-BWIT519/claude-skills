Reject the task currently paused in `claude-workflow/AWAITING_APPROVAL.md`.
There is no deterministic script for this (unlike approve.sh) — rejecting
has too many legitimate shapes to script safely, so this is a judgment task.

If `claude-workflow/AWAITING_APPROVAL.md` does not exist, say so and stop —
there is nothing to reject right now.

1. Read the task text, gate, and commit SHA from
   `claude-workflow/AWAITING_APPROVAL.md`.
2. Show the user the actual diff (`git show <sha>`) so they're deciding
   from the real change, not a description of it.
3. Ask the user which they want:
   - **Revert entirely** — `git revert <sha>` (safe, keeps history, undoes
     everything from this task).
   - **Fix specific issues and re-commit** — edit the flagged files
     yourself, then amend or add a follow-up commit (only amend if this
     commit hasn't been pushed anywhere).
   - **Abandon without touching git** — the user will handle the commit
     themselves; you only reset the plan state (step 4-5 below).
4. Reset the `claude-workflow/PLAN.md` line for this task from
   `- [~] ...` back to `- [ ] ...` — use the Edit tool with the exact
   literal line text (not a regex/sed substitution: task text routinely
   contains backticks, brackets, and parens that break naive regex
   matching — this exact bug was found and fixed in run-plan.sh/approve.sh
   this session).
5. Delete `claude-workflow/AWAITING_APPROVAL.md`.
6. Tell the user to run `/bwit-execute-plan` to retry the task from scratch.

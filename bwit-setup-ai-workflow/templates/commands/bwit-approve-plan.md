Run `bash claude-workflow/approve.sh`.

Before running it, if `claude-workflow/AWAITING_APPROVAL.md` exists, briefly
remind the user which task and commit they're approving (task text + SHA
from that file) — don't run it blind even though they invoked this command
explicitly.

If `claude-workflow/AWAITING_APPROVAL.md` does not exist, say so and stop —
there is nothing to approve right now.

After it runs successfully, tell the user to run `/bwit-execute-plan` next to
continue the loop.

Read claude-workflow/REQUIREMENTS.md. Compare with claude-workflow/PLAN.md
(if it exists).

- For new/changed requirements, add tasks to claude-workflow/PLAN.md.
- Keep each task small (roughly 30-45 minutes of work in a fresh session),
  and include the paths of the EXISTING files it will modify.
- Do not touch already-completed `[x]` tasks (claude-workflow/PLAN.md is
  append-only).
- If a requirement is ambiguous, do NOT guess — write the question to
  claude-workflow/QUESTIONS.md and mark the task `[blocked]` in
  claude-workflow/PLAN.md.
- This is an existing codebase: find how similar features are already
  implemented and mimic that pattern — structure, naming, error handling,
  test style. Do not introduce new libraries or patterns unless
  claude-workflow/REQUIREMENTS.md explicitly asks for them.
- Only update CLAUDE.md (project root) when a new PERMANENT convention has
  been established — not for task-specific notes.

## Gate tagging (required on every task line)

Every task line must start with a gate tag right after the checkbox:
`- [ ] [gate-type] task text (existing/file/paths.ext)`. If the task is
also ambiguous per the rule above, `[blocked]` goes second, after the gate
tag: `- [ ] [gate-type] [blocked] task text`.

Pick the gate type by what the task actually verifies:
- `[code]` — has a deterministic test/lint/typecheck path
  (claude-workflow/gates/code-check.sh).
- `[eval]` — verified by a measurable metric/threshold
  (claude-workflow/gates/eval.config). Only use this if the metric is
  already configured there, or you are also adding the metric line as
  part of this sync (never invent a threshold yourself — leave it for a
  human to fill in and tag the task `[eval-judgment]` in the meantime).
- `[eval-judgment]` — qualitative assessment of model/prompt behavior with
  no clean number (tone, coherence, safety judgment calls).
- `[design]` — visual/UX/design-system work with no automated test.
- `[structural]` — architecture, requirements, specs, docs, or anything
  that doesn't clearly fit the above. This is also the safe default: if
  you can't tell which gate applies, use `[structural]`, never guess a
  more permissive one.

Only use a gate tag whose corresponding file exists under
claude-workflow/gates/ in this project (e.g. don't tag something
`[design]` if gates/design-checklist.md was never scaffolded here — fall
back to `[structural]` and note in the task text that the domain isn't
configured yet).

`[code]` and configured `[eval]` tasks auto-commit and continue when their
check passes. Every other gate type still commits its work but then pauses
the loop for mandatory human sign-off (claude-workflow/AWAITING_APPROVAL.md)
— that's expected, not a sign something is wrong.

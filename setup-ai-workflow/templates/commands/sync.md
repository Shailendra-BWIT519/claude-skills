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

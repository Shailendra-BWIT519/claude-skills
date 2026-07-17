# claude-skills

Personal Claude Code skills (`~/.claude/skills/` on this machine). Each
subfolder is one skill — a `SKILL.md` plus any template files it needs.
Claude Code reads skills from this exact path per user account, so cloning
this repo to `~/.claude/skills/` on a new machine makes every skill here
available in every project, with no per-project setup.

## Skills

- **setup-ai-workflow** — the shared engine. Scaffolds a solo-dev AI
  pipeline (task-loop execution via `run-plan.sh`, layered review, session
  hooks, a token-cheap `check.sh` verification gate) into any project, any
  language. Invoke with `/setup-ai-workflow` for auto-detection, or use one
  of the language-specific wrappers below for an explicit, no-detection
  invocation. All wrappers point at this skill's `templates/` — there is
  only one copy of `run-plan.sh`/`classify-models.sh`/hooks/commands; fixing
  a bug here fixes it for every wrapper.

- **ai-workflow-setup-react** — `/ai-workflow-setup-react`. React/Next.js
  frontend: pre-filled `check.sh` (tsc/eslint/jest-or-vitest/prettier),
  a11y + visual-regression toggles offered, design-scope-boundary note added.

- **ai-workflow-setup-node** — `/ai-workflow-setup-node`. Generic Node.js
  backend (Express/Fastify/plain — not NestJS). No UI-related toggles.

- **ai-workflow-setup-nest** — `/ai-workflow-setup-nest`. NestJS backend,
  pre-filled to match Nest CLI's default scaffolded scripts.

- **ai-workflow-setup-python** — `/ai-workflow-setup-python`. Django/Flask/
  FastAPI/plain — pre-filled with mypy/ruff/pytest/black, each conditional
  on actually being configured in the project. **Never run against a real
  Python project yet** — treat its defaults as starting guesses, not proven.

- **ai-workflow-setup-dotnet** — `/ai-workflow-setup-dotnet`. .NET Core/C#
  — pre-filled with `dotnet build`/`format`/`test`. **Never run against a
  real .NET project yet** — same caveat as Python.

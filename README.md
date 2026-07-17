# claude-skills

Personal Claude Code skills (`~/.claude/skills/` on this machine). Claude
Code reads skills from this exact path per user account, so cloning this
repo to `~/.claude/skills/` on a new machine makes every skill here
available in every project, with no per-project setup.

All the AI-workflow skills live grouped under `ai-workflow-skills/` — not
to be confused with `ai-workflow-skills/setup-ai-workflow/`, the shared
engine skill nested inside it (the near-identical names are intentional:
one is the grouping folder, the other is the actual skill you invoke):

```
ai-workflow-skills/
├── setup-ai-workflow/          ← shared engine, invoke: /setup-ai-workflow
├── ai-workflow-setup-react/    ← invoke: /ai-workflow-setup-react
├── ai-workflow-setup-node/     ← invoke: /ai-workflow-setup-node
├── ai-workflow-setup-nest/     ← invoke: /ai-workflow-setup-nest
├── ai-workflow-setup-python/   ← invoke: /ai-workflow-setup-python
└── ai-workflow-setup-dotnet/   ← invoke: /ai-workflow-setup-dotnet
```

Each subfolder is one skill — a `SKILL.md` plus any template files it needs.

## Skills

- **setup-ai-workflow** — the shared engine. Scaffolds a solo-dev AI
  pipeline (task-loop execution via `run-plan.sh`, layered review, session
  hooks, an append-only audit trail) into any project, any domain: code (any
  language, via a token-cheap `gates/code-check.sh` gate), design work,
  prompt-engineering/eval-driven AI work, and architecture/requirements
  work — each gated by its own verification method, with non-code work
  requiring mandatory human sign-off (`approve.sh`) before it counts as
  done. Invoke with `/setup-ai-workflow` for auto-detection, or use one of
  the language-specific wrappers below for an explicit, no-detection
  invocation on the code side. All wrappers point at this skill's
  `templates/` — there is only one copy of `run-plan.sh`/
  `classify-models.sh`/hooks/commands/gates; fixing a bug here fixes it for
  every wrapper.

- **ai-workflow-setup-react** — `/ai-workflow-setup-react`. React/Next.js
  frontend: pre-filled `gates/code-check.sh` (tsc/eslint/jest-or-vitest/
  prettier), a11y + visual-regression toggles offered.

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

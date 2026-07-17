# claude-skills

Personal Claude Code skills (`~/.claude/skills/` on this machine). Claude
Code reads skills from this exact path per user account, so cloning this
repo to `~/.claude/skills/` on a new machine makes every skill here
available in every project, with no per-project setup.

**All skills must be immediate subfolders of `~/.claude/skills/` — Claude
Code does not discover skills nested any deeper than that.** This was tried
once (grouped under an `ai-workflow-skills/` folder) and confirmed broken —
`/bwit-ai-workflow-setup-react` returned "No matching commands" until it was
reverted back to flat. Do not re-nest these.

```
~/.claude/skills/
├── bwit-setup-ai-workflow/          ← shared engine, invoke: /bwit-setup-ai-workflow
├── bwit-ai-workflow-setup-react/    ← invoke: /bwit-ai-workflow-setup-react
├── bwit-ai-workflow-setup-node/     ← invoke: /bwit-ai-workflow-setup-node
├── bwit-ai-workflow-setup-nest/     ← invoke: /bwit-ai-workflow-setup-nest
├── bwit-ai-workflow-setup-python/   ← invoke: /bwit-ai-workflow-setup-python
└── bwit-ai-workflow-setup-dotnet/   ← invoke: /bwit-ai-workflow-setup-dotnet
```

Each folder is one skill — a `SKILL.md` plus any template files it needs.
All 6 carry a `bwit-` prefix so they read as org tooling, not Claude-native
built-ins, in the slash-command list.

## Skills

- **bwit-setup-ai-workflow** — the shared engine. Scaffolds a solo-dev AI
  pipeline (task-loop execution via `run-plan.sh`, layered review, session
  hooks, an append-only audit trail) into any project, any domain: code (any
  language, via a token-cheap `gates/code-check.sh` gate), design work,
  prompt-engineering/eval-driven AI work, and architecture/requirements
  work — each gated by its own verification method, with non-code work
  requiring mandatory human sign-off (`approve.sh`) before it counts as
  done. Invoke with `/bwit-setup-ai-workflow` for auto-detection, or use one
  of the language-specific wrappers below for an explicit, no-detection
  invocation on the code side. All wrappers point at this skill's
  `templates/` — there is only one copy of `run-plan.sh`/
  `classify-models.sh`/hooks/commands/gates; fixing a bug here fixes it for
  every wrapper.

- **bwit-ai-workflow-setup-react** — `/bwit-ai-workflow-setup-react`.
  React/Next.js frontend: pre-filled `gates/code-check.sh` (tsc/eslint/
  jest-or-vitest/prettier), a11y + visual-regression toggles offered.

- **bwit-ai-workflow-setup-node** — `/bwit-ai-workflow-setup-node`. Generic
  Node.js backend (Express/Fastify/plain — not NestJS). No UI-related
  toggles.

- **bwit-ai-workflow-setup-nest** — `/bwit-ai-workflow-setup-nest`. NestJS
  backend, pre-filled to match Nest CLI's default scaffolded scripts.

- **bwit-ai-workflow-setup-python** — `/bwit-ai-workflow-setup-python`.
  Django/Flask/FastAPI/plain — pre-filled with mypy/ruff/pytest/black, each
  conditional on actually being configured in the project. **Never run
  against a real Python project yet** — treat its defaults as starting
  guesses, not proven.

- **bwit-ai-workflow-setup-dotnet** — `/bwit-ai-workflow-setup-dotnet`.
  .NET Core/C# — pre-filled with `dotnet build`/`format`/`test`. **Never
  run against a real .NET project yet** — same caveat as Python.

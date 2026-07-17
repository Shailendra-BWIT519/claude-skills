---
name: ai-workflow-setup-node
description: Scaffold the solo-dev AI pipeline for a generic Node.js backend project (Express, Fastify, plain Node, etc — not NestJS, not a React/Next.js frontend) — pre-filled gates/code-check.sh (typecheck/lint/test/format) and .claudeignore. Thin wrapper around the setup-ai-workflow skill's shared engine (run-plan.sh, classify-models.sh, hooks, commands, gates) — same pipeline, Node-specific defaults so onboarding skips code-language detection. Use when the user wants this workflow set up in a Node.js backend project.
---

# AI Workflow Setup — Node.js (generic backend)

Thin wrapper. The actual engine (`run-plan.sh`, `classify-models.sh`, hooks,
slash commands, `gates/` skeletons) lives in exactly one place:
`~/.claude/skills/setup-ai-workflow/`. Read that skill's `SKILL.md` and
follow its Steps 1-8 exactly, with these Node-specific overrides to Step 5's
**code domain** detection only — the shared skill's design and AI/eval
domain detection in Step 5 still applies independently and unmodified (a
Node backend can still have a `[design]`/`[eval]` surface, e.g. an admin UI
or a prompt-serving endpoint):

- **Skip code-language detection** — this is Node.js, confirmed by the user
  invoking this command. If `package.json` shows `@nestjs/core` as a
  dependency, this is actually NestJS — tell the user and suggest
  `/ai-workflow-setup-nest` instead rather than proceeding generically.

- **`gates/code-check.sh` starting commands** — fill in, then ALWAYS
  actually run `bash claude-workflow/gates/code-check.sh` once and fix
  anything wrong before trusting it:
  - typecheck: `npx tsc --noEmit` if TypeScript (a `tsconfig.json` exists),
    otherwise skip typecheck entirely (`RUN_TYPECHECK=false` in
    `gates/code-check.config`, delete the line in `gates/code-check.sh`) —
    plain JS has nothing to typecheck.
  - lint: `npm run lint` if present, else `npx eslint .`
  - test: check `package.json` for the actual runner — Jest, Vitest, Mocha,
    Node's built-in `node --test` — don't assume Jest by default.
  - format: `npx prettier --check .` if Prettier is configured.

- **`.claudeignore`**: `node_modules/`, `dist/`/`build/` (compiled output,
  check for a `tsconfig.json` `outDir`), `coverage/`, lockfiles.

- **a11y/visual-regression toggles are NOT relevant** — delete both
  `run_check` lines from `gates/code-check.sh` entirely rather than leaving
  them off; this is a backend project with no rendered UI.

Everything else — copy list, `.claude/settings.json` merge, `PLAN.md`
seeding, the `.gitignore` tracked-vs-ignored question, final report — follow
`setup-ai-workflow`'s `SKILL.md` unchanged.

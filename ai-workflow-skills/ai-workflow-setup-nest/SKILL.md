---
name: ai-workflow-setup-nest
description: Scaffold the solo-dev AI pipeline for a NestJS backend project specifically — pre-filled check.sh (typecheck/lint/test/format) matching Nest CLI conventions, and .claudeignore. Thin wrapper around the setup-ai-workflow skill's shared engine (run-plan.sh, classify-models.sh, hooks, commands) — same pipeline, NestJS-specific defaults so onboarding skips language detection. Use when the user wants this workflow set up in a NestJS project.
---

# AI Workflow Setup — NestJS

Thin wrapper. The actual engine (`run-plan.sh`, `classify-models.sh`, hooks,
slash commands, `check.sh` skeleton) lives in exactly one place:
`~/.claude/skills/ai-workflow-skills/setup-ai-workflow/`. Read that skill's `SKILL.md` and
follow its Steps 1-8 exactly, with these NestJS-specific overrides to Step 5:

- **Skip language detection** — this is NestJS, confirmed by the user
  invoking this command (verify `@nestjs/core` is actually in
  `package.json` before proceeding; if not, this isn't a Nest project).

- **`check.sh` starting commands** — Nest CLI scaffolds these scripts by
  default (`nest new`), so they usually already exist as-is in
  `package.json`. Confirm, then ALWAYS actually run
  `bash claude-workflow/check.sh` once and fix anything wrong before
  trusting it:
  - typecheck: `npm run build` (runs `nest build`, which type-checks via
    `tsc`) — or `npx tsc --noEmit` directly if a separate check is
    preferred over a full build.
  - lint: `npm run lint` (Nest's default ESLint setup).
  - test: `npm run test` (unit tests, Jest — Nest's default). Note Nest
    projects commonly also have `npm run test:e2e` — that's a separate,
    slower suite; don't fold it into the default `test` check unless the
    user wants e2e tests gating every task (usually too slow for L1).
  - format: `npm run format` if present (Nest scaffolds this as
    `prettier --write`) — for `check.sh`'s read-only check use
    `npx prettier --check .` instead of the `--write` variant.

- **`.claudeignore`**: `node_modules/`, `dist/`, `coverage/`, lockfiles.

- **a11y/visual-regression toggles are NOT relevant** — delete both
  `run_check` lines from `check.sh` entirely; NestJS is API-only, no
  rendered UI.

- **Skip the "Scope boundary" CLAUDE.md note** — no design/UX surface here.

Everything else — copy list, `.claude/settings.json` merge, `PLAN.md`
seeding, the `.gitignore` tracked-vs-ignored question, final report — follow
`setup-ai-workflow`'s `SKILL.md` unchanged.

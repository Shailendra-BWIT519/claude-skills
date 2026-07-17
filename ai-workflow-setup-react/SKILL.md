---
name: ai-workflow-setup-react
description: Scaffold the solo-dev AI pipeline for a React or Next.js frontend project specifically — pre-filled gates/code-check.sh (typecheck/lint/test/format), .claudeignore, and a11y/visual-regression toggle guidance. Thin wrapper around the setup-ai-workflow skill's shared engine (run-plan.sh, classify-models.sh, hooks, commands, gates) — same pipeline, React-specific defaults so onboarding skips code-language detection. Use when the user wants this workflow set up in a React or Next.js project.
---

# AI Workflow Setup — React / Next.js

Thin wrapper. The actual engine (`run-plan.sh`, `classify-models.sh`, hooks,
slash commands, `gates/` skeletons) lives in exactly one place:
`~/.claude/skills/setup-ai-workflow/`. Read that skill's `SKILL.md` and
follow its Steps 1-8 exactly, with these React/Next.js-specific overrides
to Step 5's **code domain** detection only — the shared skill's design and
AI/eval domain detection in Step 5 still applies independently and
unmodified (a React project can also have a `[design]`/`[eval]` surface):

- **Skip code-language detection** — this is React/Next.js, confirmed by
  the user invoking this command. Still check `package.json` to tell
  Next.js apart from plain CRA/Vite React (different build/dev commands),
  and detect the test runner in use — Jest (`jest.config.*`) vs Vitest
  (`vitest.config.*`) — since the `test` command differs.

- **`gates/code-check.sh` starting commands** — fill in, then ALWAYS
  actually run `bash claude-workflow/gates/code-check.sh` once and fix
  anything wrong before trusting it (per the shared skill's existing rule
  — a guessed command is not a verified one):
  - typecheck: `npx tsc --noEmit` (or `npm run type-check` if that script
    already exists in `package.json`)
  - lint: `npm run lint` if present, else `npx eslint .`
  - test: `npm test` (Jest) or `npx vitest run` (Vitest) — check which is
    actually configured, don't assume
  - format: `npx prettier --check .`

- **`.claudeignore`**: `node_modules/`, `.next/` (Next.js) or `dist/`/`build/`
  (CRA/Vite), `coverage/`, lockfiles, `*.tsbuildinfo`.

- **a11y/visual-regression toggles ARE relevant here** (frontend/UI
  project) — mention them during onboarding per the shared skill's Step 5,
  but leave both off in `gates/code-check.config` until the user explicitly
  asks for that tooling and it's actually installed and verified.

Everything else — copy list, `.claude/settings.json` merge, `PLAN.md`
seeding, the `.gitignore` tracked-vs-ignored question, final report — follow
`setup-ai-workflow`'s `SKILL.md` unchanged. In particular: don't skip its
design/AI-eval domain detection just because this is a code-focused
wrapper — a React project with a `/design` directory or a `tokens.json`
still gets `gates/design-checklist.md` scaffolded exactly as the shared
skill's Step 5 describes.

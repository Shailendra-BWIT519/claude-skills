---
name: setup-ai-workflow
description: Scaffold the solo-dev AI pipeline (PLAN.md task loop, run-plan.sh execution engine, L2/L3 review layers, session hooks, /sync and /handoff commands) into the current project. Language-agnostic — works for Node, Python, Go, or any codebase. Use when the user asks to set up this Claude Code automation/workflow system in a new or different project, or references "the solo-dev AI pipeline" / "run-plan.sh setup" / "Din 1 setup".
---

# Setup AI Workflow

Scaffolds the solo-dev AI pipeline described in `templates/SETUP-PLAN.md` into
whatever project the user is currently in. The execution engine
(`run-plan.sh`, `classify-models.sh`, both hooks, both slash commands) is
language-agnostic and gets copied byte-for-byte — it has no Node/Python/Go
coupling anywhere; `run-plan.sh` doesn't even know what "run the tests" means,
it delegates that entirely to whatever the project's own `CLAUDE.md` says.

`CLAUDE.md` and `.claudeignore` are deliberately NOT templated here — their
content depends on reading the actual codebase, so they get generated fresh
per project in the onboarding step below, not copied. `claude-workflow/check.sh`
is a middle case: its skeleton (config-driven toggles, capture-output-and-
only-print-on-failure) is generic and copied, but its four actual
typecheck/lint/test/format commands are ecosystem-specific and must be
filled in during onboarding — it's the single command everything else in
this pipeline calls to verify work, instead of running `npx`/`npm run`/
`pytest`/etc. individually, which burns far more tokens for the same signal.

## Steps

1. **Check existing state first.** Look for `.claude/settings.json`,
   `.claude/hooks/`, `.claude/commands/`, and a `claude-workflow/` directory
   in the current project root. If any target file already exists, do NOT
   overwrite it silently — tell the user what already exists and ask before
   touching it (it may be customized).

2. **Copy the generic template files** from this skill's `templates/`
   directory into the project, using `cp`/`Copy-Item` (never retype file
   contents from memory — copy the bytes):
   - `templates/hooks/session-start-context.sh` → `.claude/hooks/`
   - `templates/hooks/pre-compact-handoff.sh` → `.claude/hooks/`
   - `templates/commands/sync.md` → `.claude/commands/`
   - `templates/commands/handoff.md` → `.claude/commands/`
   - `templates/run-plan.sh` → `claude-workflow/run-plan.sh`
   - `templates/classify-models.sh` → `claude-workflow/classify-models.sh`
   - `templates/SETUP-PLAN.md` → `claude-workflow/SETUP-PLAN.md`
   - `templates/check.config` → `claude-workflow/check.config`
   - `templates/check.sh.template` → `claude-workflow/check.sh` (this one
     needs customizing — see step 5)

3. **Merge model + hooks config into `.claude/settings.json`.**
   `templates/settings-snippet.json` has the exact `model` and `hooks` keys
   to add. If `.claude/settings.json` already exists, MERGE these two keys
   in — preserve every existing key (especially `permissions`), never
   overwrite the file wholesale. If it doesn't exist, create it from the
   snippet as-is.

4. **`.claudeignore`.** Create one at the project root once step 5 has
   identified the language/ecosystem — see step 5's ignore-pattern guidance.
   Do not copy a template for this; its content is project-specific.

5. **Run project-specific onboarding — this cannot be templated, always do
   it fresh:**
   - Detect the language/ecosystem: `package.json` → Node, `pyproject.toml`
     / `requirements.txt` / `Pipfile` → Python, `go.mod` → Go, `Gemfile` →
     Ruby, etc.
   - Explore the codebase with a subagent (Explore or general-purpose type)
     — ask it for build/test/lint commands, path aliases, non-obvious
     conventions, gotchas, and any "never touch X" warnings. This is the
     same brief you'd use to write any CLAUDE.md.
   - Write a lean `CLAUDE.md` at the project root, max ~80 lines — only
     what can't be inferred by reading the code on demand. Never mention
     model choice in it (that lives only in `run-plan.sh`).
   - Write `.claudeignore` with ecosystem-appropriate patterns — e.g.
     `node_modules/`, `.next/` for Node; `__pycache__/`, `venv/`, `*.pyc`,
     `.venv/` for Python; `vendor/` for Go — plus lockfiles and build output.
   - **Customize `claude-workflow/check.sh`**: replace its four core
     `REPLACE_ME_*` command strings with this project's real
     typecheck/lint/test/format commands (see the comment at the top of the
     file for per-ecosystem examples). This becomes the single L1 gate —
     `run-plan.sh`'s prompts already call `bash claude-workflow/check.sh`
     generically, so nothing else needs editing once these four lines are
     filled in. Do not leave any `REPLACE_ME_*` placeholder in place.
   - **Frontend/UI project?** Two more optional `REPLACE_ME_*` lines exist
     for `RUN_A11Y`/`RUN_VISUAL_REGRESSION` — leave both `false` in
     `check.config` (the default) unless the user explicitly asks for
     accessibility or visual-regression checking. If they do, the actual
     tooling (`eslint-plugin-jsx-a11y`, Playwright + a committed baseline,
     etc.) has to be installed and the exact command verified by actually
     running it once — do not wire up a guessed command and trust it.
     Backend-only project (Python/NestJS API, etc.)? Delete both
     `run_check` lines from `check.sh` entirely rather than leaving them
     permanently off.
   - Actually RUN `bash claude-workflow/check.sh` and report what passes and
     what fails — do not assume any command works just because a script
     exists. This project's own onboarding found a `npm test` that was
     declared but silently broken (missing deps entirely absent from
     `package.json`), and separately a broken `lint` (missing eslint
     plugin) that only `check.sh`'s actual run surfaced.
   - **If the project has a meaningful frontend/UI surface**, add a `##
     Scope boundary` note to the generated `CLAUDE.md`: pure design/UX work
     (Figma exports, mockups, visual direction — non-code deliverables) is a
     poor fit for this pipeline, since `check.sh` and L2/L3 diff-review only
     work because code is machine-checkable — a design artifact has no
     equivalent gate. Implementing a design INTO code is unaffected. Skip
     this note for backend-only projects where it wouldn't apply.

6. **Seed 2-3 boring smoke-test tasks** into `claude-workflow/PLAN.md` —
   mechanical, low-risk fixes discovered during onboarding (stale config,
   a missing `.env.example`, a cleanup item) whose only job is to prove the
   `run-plan.sh` loop mechanics work before real feature work starts. Do
   NOT run `run-plan.sh` yourself — that supervised first run is the human's
   call, and it makes real commits.

7. **`.gitignore`.** If the project has a `.gitignore`, ask the user whether
   `.claude/` and `claude-workflow/` should be tracked (team-shared workflow)
   or ignored (solo/personal — the default in the project this skill was
   extracted from). Don't assume; the answer differs by team.

8. **Report back**: what was created, what was skipped because it already
   existed, and this reminder — workspace trust must be accepted once
   (`claude`, no `-p`, run interactively in the new project directory) before
   headless `run-plan.sh` runs will honor `.claude/settings.json`'s
   permissions instead of ignoring them.

Do not implement any real features as part of this skill run — setup only,
exactly like the original Din 1 scope.

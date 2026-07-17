---
name: bwit-setup-ai-workflow
description: Scaffold the solo-dev AI pipeline (PLAN.md task loop, run-plan.sh execution engine, per-domain gates for code/design/eval/structural work, mandatory human sign-off on non-code tasks, an append-only audit trail, session hooks, /bwit-sync-requirements, /bwit-handoff, /bwit-execute-plan, /bwit-approve-plan, and /bwit-reject-plan commands) into the current project. Domain-agnostic — works for backend/frontend code in any language, pure design work, prompt-engineering/eval-driven AI work, and architecture/requirements-only work, including projects that mix several of these. Use when the user asks to set up this Claude Code automation/workflow system in a new or different project, or references "the solo-dev AI pipeline" / "run-plan.sh setup" / "Din 1 setup" / "enterprise-grade workflow".
---

# Setup AI Workflow

Scaffolds the solo-dev AI pipeline described in `templates/SETUP-PLAN.md` into
whatever project the user is currently in. The execution engine
(`run-plan.sh`, `approve.sh`, `classify-models.sh`, both hooks, both slash
commands, the `gates/` scripts) is domain-agnostic and gets copied
byte-for-byte — it has no Node/Python/Go coupling anywhere, and no
code-only assumption either; `run-plan.sh` doesn't know what "run the
tests" means, it delegates that entirely to whichever gate a task is
tagged with (see below), and non-code gates route to mandatory human
sign-off instead of a test command.

`CLAUDE.md` and `.claudeignore` are deliberately NOT templated here — their
content depends on reading the actual codebase, so they get generated fresh
per project in the onboarding step below, not copied. `claude-workflow/gates/`
is a middle case: the skeleton of each gate file (config-driven toggles,
capture-output-and-only-print-on-failure for `code-check.sh`/`eval-check.sh`;
the checklist structure for `design-checklist.md`/`structural-checklist.md`/
`eval-judgment-checklist.md`) is generic and copied, but its actual content
— the four typecheck/lint/test/format commands, real eval metric
thresholds, project-specific checklist items — is project-specific and must
be filled in during onboarding.

Five thin wrapper skills (`bwit-ai-workflow-setup-node`/`-react`/`-python`/
`-dotnet`/`-nest`) exist for common stacks — they skip language detection
and pre-fill `gates/code-check.sh`'s commands, then defer everything else to
this skill's Steps 1-8 unchanged. If the user invokes one of those, follow
its overrides for the code-detection parts of Step 5 below; everything else
here still applies as written.

## Gate types (the core concept this skill scaffolds)

Every task in `claude-workflow/PLAN.md` carries a gate tag —
`[code]`, `[eval]`, `[eval-judgment]`, `[design]`, or `[structural]` — which
`run-plan.sh` uses to decide how the task gets verified:

- **`[code]`** — deterministic: `gates/code-check.sh` (typecheck/lint/
  test/format, plus optional a11y/visual-regression toggles for frontend
  projects). Passes → auto-commit and continue, same as before.
- **`[eval]`** — deterministic ONLY if `gates/eval.config` has a real,
  human-supplied metric threshold for it (accuracy, latency, cost, etc.);
  otherwise falls back to human-gated, same as `[eval-judgment]`.
- **`[design]` / `[eval-judgment]` / `[structural]`** — no deterministic
  check exists for these. The task session self-checks against the
  matching `gates/*-checklist.md`, commits its work (so it's git-tracked
  for review — the only way work survives between fresh sessions), and
  the loop PAUSES: `claude-workflow/AWAITING_APPROVAL.md` is written and
  `run-plan.sh` exits 0 (an expected pause, not a failure). A human runs
  `bash claude-workflow/approve.sh` to sign off and resume. `[structural]`
  is also the strict default for any untagged or unrecognized task — when
  in doubt, the pipeline always falls back to requiring a human, never to
  auto-passing.

This is what replaces the old approach of disclaiming design/UX work as
out of scope for this pipeline — it's now a first-class gate type with its
own (human-required) verification path, not a documented limitation.

Every task outcome (`committed` / `blocked` / `awaiting_approval` /
`approved`) is appended to `claude-workflow/AUDIT_LOG.jsonl` by
`run-plan.sh`/`approve.sh` themselves — never by a task or review session,
so the trail can't be silently skipped. Full mechanics, including exact
file formats, are in `templates/SETUP-PLAN.md` §5.5.

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
   - `templates/commands/bwit-sync-requirements.md` → `.claude/commands/`
   - `templates/commands/bwit-handoff.md` → `.claude/commands/`
   - `templates/commands/bwit-execute-plan.md` → `.claude/commands/` (runs
     run-plan.sh and reports back — committed/paused/blocked/L3-skipped)
   - `templates/commands/bwit-approve-plan.md` → `.claude/commands/` (runs
     approve.sh, reminding the user what they're signing off on first)
   - `templates/commands/bwit-reject-plan.md` → `.claude/commands/` (no
     deterministic script backs this one — it's a judgment task: show the
     diff, ask revert vs. fix-and-recommit vs. abandon, reset the PLAN.md
     checkbox, delete AWAITING_APPROVAL.md)
   - `templates/run-plan.sh` → `claude-workflow/run-plan.sh`
   - `templates/approve.sh` → `claude-workflow/approve.sh`
   - `templates/classify-models.sh` → `claude-workflow/classify-models.sh`
   - `templates/SETUP-PLAN.md` → `claude-workflow/SETUP-PLAN.md`
   - `templates/gates/structural-checklist.md` → `claude-workflow/gates/`
     (always copied — every project gets the strict fallback gate, even a
     pure backend repo, since any task can end up untagged/ambiguous)
   - The rest of `templates/gates/*` are copied CONDITIONALLY, per the
     domain detection in step 5 below — do not scaffold a domain's gate
     file into a project that doesn't have that domain.

3. **Merge model + hooks config into `.claude/settings.json`.**
   `templates/settings-snippet.json` has the exact `model` and `hooks` keys
   to add. If `.claude/settings.json` already exists, MERGE these two keys
   in — preserve every existing key (especially `permissions`), never
   overwrite the file wholesale. If it doesn't exist, create it from the
   snippet as-is.

   **Ask the developer which branch they merge into — never guess.**
   `run-plan.sh`'s `BASE_BRANCH` (used for the base-branch safety check and
   L3's whole-branch review diff) ships as the placeholder
   `REPLACE_ME_BASE_BRANCH`. Run `git branch --list` (and `git remote show
   origin | grep "HEAD branch"` if useful context), show the developer the
   actual branch list, and ask them directly which one they merge feature
   work into. Do NOT assume "main" or auto-detect the GitHub default branch
   — a project's real merge target can differ from its default branch (this
   happened for real: a project whose GitHub default was "main" actually
   merged into "dev", and a hardcoded/guessed "main" produced a diff
   comparing against 7 months and 2000+ unrelated commits of divergence).
   Replace `REPLACE_ME_BASE_BRANCH` in `claude-workflow/run-plan.sh` with
   their exact answer once copied.

4. **`.claudeignore`.** Create one at the project root once step 5 has
   identified the language/ecosystem — see step 5's ignore-pattern guidance.
   Do not copy a template for this; its content is project-specific.

5. **Run project-specific onboarding — this cannot be templated, always do
   it fresh. Detect EVERY domain present (a project can be more than one —
   most real ones are), and only scaffold the gates for domains actually
   found:**

   - **Code domain** — `package.json` → Node, `pyproject.toml` /
     `requirements.txt` / `Pipfile` → Python, `go.mod` → Go, `Gemfile` →
     Ruby, etc. If found: copy `templates/gates/code-check.sh` and
     `code-check.config` → `claude-workflow/gates/`, then **customize
     `code-check.sh`**: replace its four `REPLACE_ME_*` command strings
     with this project's real typecheck/lint/test/format commands (see the
     comment at the top of the file for per-ecosystem examples). Do not
     leave any `REPLACE_ME_*` placeholder in place.
     - **Frontend/UI project?** Two more optional `REPLACE_ME_*` lines
       exist for `RUN_A11Y`/`RUN_VISUAL_REGRESSION` — leave both `false`
       in `code-check.config` (the default) unless the user explicitly
       asks for accessibility or visual-regression checking. If they do,
       the actual tooling (`eslint-plugin-jsx-a11y`, Playwright + a
       committed baseline, etc.) has to be installed and the exact
       command verified by actually running it once — do not wire up a
       guessed command and trust it. Backend-only project? Delete both
       `run_check` lines from `code-check.sh` entirely rather than
       leaving them permanently off.
     - Actually RUN `bash claude-workflow/gates/code-check.sh` and report
       what passes and what fails — do not assume any command works just
       because a script exists. (Past onboarding runs have found an
       `npm test` that was declared but silently broken from missing
       deps, and a broken `lint` from a missing eslint plugin — only the
       actual run surfaces these.)

   - **Design domain** — design-token files (e.g. `tokens.json`,
     `tailwind.config.*`), `.storybook/`, `components.json`, `*.fig`
     references, a `/design` or `/assets/design` directory. If found: copy
     `templates/gates/design-checklist.md` → `claude-workflow/gates/`, then
     customize its token-source/component-library reference line to point
     at what was actually found in this project.

   - **AI/eval domain** — `prompts/`, `evals/`/`eval/`, an eval-harness
     config (e.g. promptfoo-style YAML), `*.ipynb`, model-config files. If
     found: copy `templates/gates/eval-check.sh`, `eval.config`, and
     `eval-judgment-checklist.md` → `claude-workflow/gates/`. For
     `eval.config`: **ask the human directly for real metric names and
     thresholds — never invent plausible-sounding numbers.** If they don't
     have thresholds yet, that's fine — leave `eval.config` with only its
     header comment (zero metric lines); every `[eval]` task then correctly
     falls back to the human-gated path until real numbers exist. Do not
     guess a threshold to make the file look "complete."

   - **Structural gate** — always scaffolded (step 2, unconditional); it's
     also the universal fallback for anything unclassified.

6. **Seed 2-3 boring smoke-test tasks** into `claude-workflow/PLAN.md`,
   each correctly gate-tagged (see `templates/commands/bwit-sync-requirements.md`'s tagging
   rules) — mechanical, low-risk fixes discovered during onboarding (stale
   config, a missing `.env.example`, a cleanup item). If more than one
   domain was detected, include at least one task per detected domain so
   the human's first supervised run exercises both the auto-commit path
   (`[code]`/configured `[eval]`) and the pause-for-approval path
   (`[design]`/`[structural]`/`[eval-judgment]`) at least once. Do NOT run
   `run-plan.sh` yourself — that supervised first run is the human's call,
   and it makes real commits.

7. **`.gitignore`.** If the project has a `.gitignore`, ask the user whether
   `.claude/` and `claude-workflow/` should be tracked (team-shared workflow)
   or ignored (solo/personal — the default in the project this skill was
   extracted from). Don't assume; the answer differs by team. **If ignoring
   `claude-workflow/`**, the audit trail must still survive regardless —
   add exactly these two lines, not a vague "add an exception":
   ```
   claude-workflow/*
   !claude-workflow/AUDIT_LOG.jsonl
   ```

8. **Report back**: which domains were detected and which gates were
   scaffolded (and which were skipped, and why), what already existed and
   was left untouched, and this reminder — workspace trust must be accepted
   once (`claude`, no `-p`, run interactively in the new project directory)
   before headless `run-plan.sh` runs will honor `.claude/settings.json`'s
   permissions instead of ignoring them.

Do not implement any real features as part of this skill run — setup only,
exactly like the original Din 1 scope.

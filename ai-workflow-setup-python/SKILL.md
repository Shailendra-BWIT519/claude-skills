---
name: ai-workflow-setup-python
description: Scaffold the solo-dev AI pipeline for a Python project specifically (Django, Flask, FastAPI, or plain) — pre-filled check.sh (mypy/ruff/pytest/black) and .claudeignore. Thin wrapper around the setup-ai-workflow skill's shared engine (run-plan.sh, classify-models.sh, hooks, commands) — same pipeline, Python-specific defaults so onboarding skips language detection. Use when the user wants this workflow set up in a Python project.
---

# AI Workflow Setup — Python

Thin wrapper. The actual engine (`run-plan.sh`, `classify-models.sh`, hooks,
slash commands, `check.sh` skeleton) lives in exactly one place:
`~/.claude/skills/setup-ai-workflow/`. Read that skill's `SKILL.md` and
follow its Steps 1-8 exactly, with these Python-specific overrides to
Step 5 — **this is the least-tested language for this pipeline (never run
against a real Python project as of this writing), so be extra rigorous
about actually verifying every command rather than trusting these
defaults:**

- **Skip language detection** — this is Python, confirmed by the user
  invoking this command. Still check for `pyproject.toml` vs
  `requirements.txt`/`Pipfile` to know the package manager (`poetry`/`pip`/
  `pipenv`), and detect the framework (Django/Flask/FastAPI/plain) since it
  affects test conventions (e.g. Django's `manage.py test` vs plain
  `pytest`).

- **`check.sh` starting commands** — fill in ONLY if the tool is actually
  configured in the project (check for `mypy.ini`/`[tool.mypy]`,
  `ruff.toml`/`[tool.ruff]`, `[tool.black]`, etc. — do not assume every
  Python project has all four set up). ALWAYS actually run
  `bash claude-workflow/check.sh` once and fix anything wrong before
  trusting it:
  - typecheck: `mypy .` — if no mypy config exists anywhere, set
    `RUN_TYPECHECK=false` in `check.config` rather than adding a check that
    will just fail on an unconfigured/untyped codebase.
  - lint: `ruff check .` (modern default) — fall back to `flake8` if
    `ruff` isn't what the project uses.
  - test: `pytest` (or `python -m pytest`) — Django projects may use
    `python manage.py test` instead; check `manage.py`'s presence.
  - format: `black --check .`

- **`.claudeignore`**: `__pycache__/`, `*.pyc`, `.venv/`/`venv/`,
  `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `*.egg-info/`,
  `dist/`/`build/` (packaging output).

- **a11y/visual-regression toggles are NOT relevant** for a typical
  backend Python project — delete both `run_check` lines from `check.sh`
  entirely. (Exception: a Django project serving server-rendered templates
  could arguably want a11y checking on those templates — ask the user
  rather than assuming either way.)

- **Skip the "Scope boundary" CLAUDE.md note** unless the project has a
  real templated-UI surface (e.g. Django templates) — most Python backends
  don't need it.

Everything else — copy list, `.claude/settings.json` merge, `PLAN.md`
seeding, the `.gitignore` tracked-vs-ignored question, final report — follow
`setup-ai-workflow`'s `SKILL.md` unchanged.

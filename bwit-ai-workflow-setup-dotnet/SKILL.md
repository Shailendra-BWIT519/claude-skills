---
name: bwit-ai-workflow-setup-dotnet
description: Scaffold the solo-dev AI pipeline for a .NET Core / C# project specifically — pre-filled check.sh (dotnet build/format/test) and .claudeignore. Thin wrapper around the bwit-setup-ai-workflow skill's shared engine (run-plan.sh, classify-models.sh, hooks, commands) — same pipeline, .NET-specific defaults so onboarding skips language detection. Use when the user wants this workflow set up in a .NET/C# project.
---

# AI Workflow Setup — .NET Core

Thin wrapper. The actual engine (`run-plan.sh`, `classify-models.sh`, hooks,
slash commands, `check.sh` skeleton) lives in exactly one place:
`~/.claude/skills/bwit-setup-ai-workflow/`. Read that skill's `SKILL.md` and
follow its Steps 1-8 exactly, with these .NET-specific overrides to Step 5 —
**this is the least-tested language for this pipeline (never run against a
real .NET project as of this writing), so be extra rigorous about actually
verifying every command rather than trusting these defaults:**

- **Skip language detection** — this is .NET, confirmed by the user
  invoking this command. Find the actual `.sln`/`.csproj` file(s) — commands
  below may need `--project <path>` or need to run from the solution root,
  and a repo with multiple projects may need per-project scoping.

- **`check.sh` starting commands** — .NET doesn't cleanly separate
  "typecheck" from "build" the way TS/Python do (compilation IS the type
  check). ALWAYS actually run `bash claude-workflow/check.sh` once and fix
  anything wrong before trusting it:
  - typecheck: `dotnet build --no-restore` (or without `--no-restore` if
    packages aren't already restored) — compiling *is* the type-check here.
  - lint: `dotnet format --verify-no-changes --verbosity normal` (checks
    style/analyzer rules without modifying files) — if the project has
    Roslyn analyzers configured as build warnings, consider treating
    analyzer warnings as part of this check too.
  - test: `dotnet test`
  - format: often redundant with lint here since `dotnet format` covers
    both style and formatting — set `RUN_FORMAT=false` and rely on the
    `lint` check alone unless the project specifically separates the two.

- **`.claudeignore`**: `bin/`, `obj/`, `.vs/`, `*.user`, `packages/` (older
  non-SDK-style projects), `TestResults/`.

- **a11y/visual-regression toggles**: relevant only if this is a Blazor or
  ASP.NET Core MVC/Razor project with real rendered UI — ask the user
  rather than assuming; delete both `run_check` lines for a pure Web
  API/backend project.

- **Skip the "Scope boundary" CLAUDE.md note** for API-only projects; keep
  it for Blazor/Razor UI projects.

Everything else — copy list, `.claude/settings.json` merge, `PLAN.md`
seeding, the `.gitignore` tracked-vs-ignored question, final report — follow
`bwit-setup-ai-workflow`'s `SKILL.md` unchanged.

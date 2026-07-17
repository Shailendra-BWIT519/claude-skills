# Structural self-check checklist (customize during onboarding)

Before committing a [structural]-tagged task — architecture, requirements,
specs, ADRs, or anything untagged/unclassified (this is the strictest,
default gate) — self-check against every item below and note the results
in the commit message.

- [ ] Complete against claude-workflow/REQUIREMENTS.md — nothing the
      requirement asked for was left implicit or unresolved.
- [ ] No unresolved `[NEEDS DECISION]`/TBD markers left in the artifact
      itself; genuine open questions went to claude-workflow/QUESTIONS.md
      instead of being guessed at.
- [ ] Terminology is consistent with CLAUDE.md and existing docs (no new
      synonym introduced for an existing concept without a stated reason).
- [ ] Does not silently contradict an existing decision recorded elsewhere
      in the project (docs, ADRs, CLAUDE.md) — if it intentionally
      supersedes one, that's called out explicitly, not left implicit.
- [ ] Blast radius is understood: what else in the project depends on or
      references this, and does this change break any of it.

**This checklist does not auto-pass the task.** A human must review and
run `bash claude-workflow/approve.sh` regardless of checklist results —
structural/foundational work always needs sign-off, since mistakes here
propagate into everything built on top of it.

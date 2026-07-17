# Design self-check checklist (customize during onboarding)

Before committing a [design]-tagged task, self-check against every item
below and note the results in the commit message (one line per item is
enough: what you checked, what you found).

- [ ] Matches the requirement/spec this task cites — nothing requested is
      missing, nothing out of scope was added.
- [ ] Uses existing design tokens/components (colors, spacing, typography)
      instead of ad hoc one-off values — CUSTOMIZE: list this project's
      token source (e.g. `tokens.json`, `tailwind.config`, a Figma library)
      during onboarding so this item is checkable, not vague.
- [ ] Consistent with how similar screens/components already look and
      behave elsewhere in this project.
- [ ] Accessibility, where applicable: text/background contrast, tap/click
      target size, focus states, alt text.
- [ ] Responsive/adapts correctly across the breakpoints this project
      supports, if relevant to this task.
- [ ] File/asset naming and organization follows this project's existing
      convention.

**This checklist does not auto-pass the task.** A human must review and
run `bash claude-workflow/approve.sh` regardless of checklist results —
self-checking against this list is required before commit, but it is not
a substitute for sign-off.

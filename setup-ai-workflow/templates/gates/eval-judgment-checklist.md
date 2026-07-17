# Eval-judgment self-check checklist (customize during onboarding)

For [eval-judgment]-tagged tasks — qualitative assessment of model/prompt
behavior that can't be reduced to a single number in
claude-workflow/gates/eval.config (tone, coherence, instruction-following
on ambiguous cases, safety/refusal judgment calls). Also used whenever an
[eval] task falls back here because eval.config has no configured metric
for it yet.

- [ ] Sampled outputs actually reviewed (not just skimmed) — note how many
      and how they were selected (random sample, worst-case search, etc).
- [ ] Compared against this project's stated voice/tone/safety guidelines,
      if any exist — CUSTOMIZE: link them here during onboarding.
- [ ] Regressions checked: any behavior that was previously acceptable and
      is now worse, not just whether the new behavior is good in isolation.
- [ ] Failure modes noted even if not fixed in this task — write them to
      claude-workflow/QUESTIONS.md or a follow-up PLAN.md task rather than
      letting them go unrecorded.
- [ ] Non-determinism accounted for: if results vary run-to-run, that's
      stated explicitly rather than treating one sample as ground truth.

**This checklist does not auto-pass the task.** A human must review and
run `bash claude-workflow/approve.sh` regardless of checklist results —
qualitative model behavior is judgment work and is never auto-approved.

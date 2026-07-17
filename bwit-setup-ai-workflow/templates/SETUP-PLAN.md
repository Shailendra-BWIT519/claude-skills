# SETUP-PLAN.md — Solo Dev AI Pipeline
> Ye file ek complete workflow system describe karti hai. Claude Code isko padh ke
> setup implement karega. **Philosophy:** Files sasti, agents mehenge ·
> Deterministic > LLM · Compression > retrieval · Planning > runtime fixes ·
> Judgment human ka, execution Claude ka.

---

## 0. Kickoff prompt (Claude Code me yahi paste karo)

```

Read SETUP-PLAN.md — it describes a complete workflow system.

Implement its setup (Section 9, Din 1 items first):

1. .claudeignore for this project

2. .claude/settings.json with the model default and both hooks

3. .claude/hooks/ — pre-compact-handoff.sh and session-start-context.sh

4. .claude/commands/ — handoff.md and sync-requirements.md

5. run-plan.sh with the model config variables at top

6. Since this is an existing codebase: explore it (use subagents),

   then write a lean CLAUDE.md (max 80 lines, only what cannot be

   inferred from reading the code), and verify the test command

   actually runs.

Do NOT start implementing any features yet — setup only.

Show me each file before finalizing.

```

---

## 1. Project structure (target state)

```

project/

├── REQUIREMENTS.md        ← SIRF HUMAN likhta hai (source of truth)

├── PLAN.md                ← Claude banata hai (/bwit-sync-requirements se), append-only,
│                              har task [gate-type]-tagged (§5.5)

├── CLAUDE.md              ← Claude banata hai, human monthly prune (60-100 lines)

├── QUESTIONS.md           ← Claude: ambiguous requirements yahan (guess nahi)

├── BLOCKED.md             ← Claude: atka task yahan (loop stopper — failure)

├── AWAITING_APPROVAL.md   ← run-plan.sh: human-gated task yahan (loop
│                              pauser — NOT a failure, see §5.5)

├── AUDIT_LOG.jsonl        ← run-plan.sh (only): append-only, every task's
│                              outcome — committed/blocked/awaiting_approval/approved

├── REVIEW.md              ← Reviewer: issues yahan (loop stopper)

├── .claudeignore          ← node_modules, dist, build, locks, generated files

├── run-plan.sh            ← execution engine (headless loop)

├── approve.sh             ← deterministic sign-off for a paused human-gated task

├── gates/                 ← per-gate-type verification (§5.5): code-check.sh,
│                              eval-check.sh + eval.config, design-checklist.md,
│                              structural-checklist.md, eval-judgment-checklist.md

└── .claude/

    ├── settings.json      ← default model + 2 hooks

    ├── commands/

    │   ├── handoff.md     ← manual escape hatch

    │   └── sync-requirements.md        ← requirements → plan generator (also tags gates)

    └── hooks/

        ├── pre-compact-handoff.sh    ← heavy session → auto state dump

        └── session-start-context.sh  ← nayi session → auto context load

```

---

## 2. Model config

**run-plan.sh ke top par (yahi asli model policy hai):**

```bash

CODE_MODEL="claude-sonnet-4-6"            # task implementation

REVIEW_MODEL="claude-haiku-4-5"           # L2: per-task diff review

FEATURE_REVIEW_MODEL="claude-sonnet-4-6"  # L3: feature-level review

# Critical feature (auth/payments)? Sirf ye badlo:

# FEATURE_REVIEW_MODEL="claude-opus-4-8"

```

**.claude/settings.json me:** `"model": "claude-sonnet-4-6"` (interactive default)

**Rules:**

- CLAUDE.md me model ka zikr NAHI (wo har turn tokens khaata hai, kaam kuch nahi)

- Per-run override: `REVIEW_MODEL_OVERRIDE="claude-sonnet-4-6" ./run-plan.sh`

---

## 3. Hooks (automation)

### PreCompact hook (matcher: "auto")

Session heavy hone par, auto-compact se theek pehle chalta hai:

- Transcript backup `.claude/backups/` me (sirf last 5 rakhna, purane delete)

- `.claude/HANDOFF.md` auto-generate: current branch, `git status --short`

  (uncommitted = in-progress kaam), last 5 commits, PLAN.md ka task status

- Ye "planning fail ho gayi" wala safety net hai

### SessionStart hook

Har nayi session (startup/resume/clear) par — stdout Claude ko context milta hai:

- Branch + uncommitted changes (max 15 lines)

- PLAN.md ke pending `- [ ]` tasks (max 10)

- `.claude/HANDOFF.md` agar exist kare (pichli heavy session se)

- `BLOCKED.md` warning agar exist kare

### CLAUDE.md me compaction rules (4 lines)

```

## Compaction rules

When compacting, always preserve: current task and its remaining

steps, full list of modified files, test commands, and any

discovered gotchas/decisions.

```

---

## 4. Slash commands

### /bwit-sync-requirements (.claude/commands/bwit-sync-requirements.md)

```

Read REQUIREMENTS.md. Compare with PLAN.md (if it exists).

- Naye/badle requirements ke liye tasks add karo PLAN.md me

- Har task chhota ho (ek fresh session me 30-45 min layak),

  modify hone wali EXISTING files ke paths ke saath

- Completed [x] tasks ko mat chhedo (append-only)

- Ambiguous requirement → guess MAT karo → QUESTIONS.md me

  sawaal likho, task ko [blocked] mark karo

- This is an existing codebase: find how similar features are

  already implemented and mimic that pattern — structure, naming,

  error handling, test style. NO new libraries/patterns unless

  REQUIREMENTS.md explicitly asks.

- CLAUDE.md sirf tab update karo jab naya PERMANENT convention

  aaya ho.

```

### /bwit-handoff (.claude/commands/bwit-handoff.md)

```

Write .claude/HANDOFF.md (overwrite, under 60 lines) with sections:

## Task — one line, kya aur kyun

## Done — verified complete cheezein (file paths ke saath)

## In progress — kya aadha hai, kis file me, agla concrete step

## Edge cases & gotchas — jo code/plan me NAHI dikhta: decisions,

   weird behaviors, failed approaches jo dobara try nahi karne

## Verify — exact test/build commands

Phir PLAN.md checkboxes update karo, aur bolo "Handoff ready — /clear now."

```

---

## 5. Execution loop (run-plan.sh)

```

Safety checks pehle:

  - main/master branch par ho → EXIT (feature branch banao)

  - BLOCKED.md exist karti hai → EXIT (pehle resolve karo)

  - PLAN.md nahi hai → EXIT

Jab tak PLAN.md me "- [ ]" tasks hain:

  1. Pehla unchecked task utha

  2. FRESH session: claude -p (model: $CODE_MODEL) with rules:

     - Read PLAN.md and CLAUDE.md first

     - Complete ONLY this one task, strict scope, NO unrelated

       refactoring

     - Mimic existing codebase patterns

     - Tests pass → mark [x] in PLAN.md + git commit (clear

       conventional message)

     - Tests fail 3x → write problem + attempts + error output

       to BLOCKED.md, do NOT commit broken code

     - Task ambiguous/impossible → BLOCKED.md, no guessing

  3. BLOCKED.md bani → LOOP STOP (human needed)

  4. Task na tick hua na blocked → LOOP STOP (infinite-loop guard)

  5. L2 review — FRESH session, $REVIEW_MODEL, input SIRF

     git diff HEAD~1:

     "Review ONLY this diff. Check: bugs, security, missing edge

      cases, scope creep. Issues → REVIEW.md with file:line refs.

      Clean → say CLEAN."

  6. REVIEW.md bani → fix session, phir aage

Saare tasks done → L3 review — $FEATURE_REVIEW_MODEL, full

git diff main...HEAD, adversarial prompt:

  "You did NOT write this code. You are a skeptical senior

   reviewer. Assume it has at least 2 problems — find them.

   Focus: failure paths, breaking inputs, design coherence across

   tasks, duplicated logic, integration gaps."

```

**Sessions ke beech memory = PLAN.md + git commits + BLOCKED.md.**

Handoff file sirf emergency (hook khud sambhalta hai). Vector DB nahi chahiye.

---

## 5.5 Gate types & human-gated pause

Not every task has a test suite. Design work, prompt/eval judgment calls,
and architecture/requirements work don't have a deterministic pass/fail —
forcing them through the same "tests pass → auto-commit → continue" path
as code would mean silently trusting a self-report with no real check
behind it. So every PLAN.md task line carries a gate tag, and run-plan.sh
dispatches to the matching mechanism in `gates/`:

```

- [ ] [code]           → gates/code-check.sh (typecheck/lint/test/format)

- [ ] [eval]            → gates/eval-check.sh, IF gates/eval.config has a
                          real metric threshold for it — else falls back
                          to the human-gated path below (never guesses a
                          threshold, never silently auto-passes)

- [ ] [design]          → gates/design-checklist.md (self-check, then
                          mandatory human sign-off)

- [ ] [eval-judgment]   → gates/eval-judgment-checklist.md (same)

- [ ] [structural]      → gates/structural-checklist.md (same) — also the
                          default for any untagged/unrecognized task,
                          i.e. the strictest gate wins when in doubt

```

`[code]` and configured `[eval]` tasks behave exactly like the original
loop: check passes → commit → continue automatically.

Every other gate type still COMMITS its work (a fresh `claude -p` session
has no memory beyond what's on disk/in git, so committing is the only way
the work survives to be reviewed) but then the loop PAUSES:
`AWAITING_APPROVAL.md` is written (task, gate, commit SHA, resume/reject
instructions) and run-plan.sh exits 0 — a deliberate, expected pause, not
a failure like BLOCKED.md's exit 1. Resume with `bash approve.sh` (flips
the PLAN.md checkbox from `[~]` to `[x]`, deletes the pause file, logs the
approval) then re-run run-plan.sh. Rejecting is manual: revert/edit the
commit, reset the checkbox to `[ ]`, delete the pause file.

Every outcome — committed, blocked, awaiting_approval, approved — gets one
line appended to `AUDIT_LOG.jsonl`, written ONLY by run-plan.sh/approve.sh
themselves (never by a task or review session), so the trail can't be
silently skipped or gamed by a session that wants to look done.

---

## 6. Review pipeline (4 layers)

| Layer | Kaun | Kab | Cost |

|---|---|---|---|

| L1 | tests + lint + typecheck | har task, commit se pehle | free |

| L2 | Haiku, diff-only, fresh session | har task | ~nil |

| L3 | Sonnet fresh + adversarial prompt | feature end | ek call |

| L4 | **HUMAN** — `git diff main...HEAD` | feature end | 10 min |

L4 kabhi automate nahi hoga — "kya ye wahi hai jo mujhe chahiye tha" sirf

human bata sakta hai. Agar L3 consistently koi cheez miss kare → pehle

poochho kya wo lint rule/test ban sakti hai (L1) — deterministic hamesha jeet-ta hai.

**Important:** the per-task human-gated pause (§5.5, `AWAITING_APPROVAL.md`)
is NOT L4. It's a per-task sign-off on individual `[design]`/`[structural]`/
`[eval-judgment]`/unconfigured-`[eval]` commits as they happen. L4 — the
full-feature `git diff main...HEAD` review — still happens unconditionally
at the end, regardless of how many individual tasks were already
human-approved along the way. Conflating the two is an easy mistake:
approving every task's pause is not the same as reviewing the feature as a
whole.

---

## 7. Daily workflow (human ka kaam)

```

1. REQUIREMENTS.md update — TESTABLE likho

   ("3 galat attempts → 15 min lock", not "login achha ho")

2. /bwit-sync-requirements

3. PLAN.md + QUESTIONS.md review (30 sec) — questions ho to jawab

   REQUIREMENTS.md me daal ke dobara /bwit-sync-requirements

4. ./run-plan.sh   (pehli 2-3 runs SUPERVISED, feature branch par)

5. Loop ruke (BLOCKED/REVIEW) → 2 min: padho, fix/guide karo,

   file delete, dobara chalao

6. Feature end → L4: 10-min diff review → merge

```

### Interactive kaam ke rules (jab loop nahi chal raha)

```

Naya task, session fresh   → /clear kaafi

Same kaam, session heavy   → kuch mat karo (auto-compact sambhalega)

Naya task, session heavy   → /bwit-handoff + /clear

Exploratory/debugging      → end me /bwit-handoff (findings durable karo)

```

### Bug-fix lane (features se alag)

```

Interactive session me investigate karo

  → chhota fix → wahi session me fix + test + commit

  → bada fix → findings REQUIREMENTS.md me → /bwit-sync-requirements → loop

  → investigation adhuri → /bwit-handoff (yahi handoff ka asli use-case hai)

```

---

## 8. Existing codebase ke special rules

1. **One-time onboarding:** subagents se codebase explore karwao (unka

   file-reading alag context me jaata hai), phir lean CLAUDE.md (max 80

   lines — SIRF jo code padh ke infer nahi ho sakta: build/test commands,

   non-obvious conventions, gotchas, "never touch X"). Test command

   chala ke verify karo.

2. **Mimic existing patterns** — har plan/task prompt me (Section 4/5 me

   already baked hai).

3. **Tests kam hain?** → pehli REQUIREMENTS.md entry: "critical paths ke

   liye tests likho." Tests hi L1 gate hain; unke bina loop ka matlab nahi.

---

## 9. Setup order

```

Din 1: .claudeignore + settings.json + hooks + commands + run-plan.sh

       + onboarding (CLAUDE.md via subagents, test command verify)

       + PLAN.md me 2-3 chhote BORING tasks manually

       + run-plan.sh SUPERVISED chalao (system test karo, task nahi)

Din 2+: REQUIREMENTS.md flow shuru, L2/L3 reviews on

Monthly: CLAUDE.md prune (jo Claude bina bole sahi karta hai, wo line

         delete), /usage se token check

```

---

## 10. Kya NAHI karna (conscious rejections — inhe wapas mat lao)

- ❌ Multi-agent roles (architect/dev/QA agents) — 3-5x tokens, fragile handoffs

- ❌ Vector DB / session context storage — compression se solved, retrieval galat tool

- ❌ Runtime "session heavy" detection logic — planning granularity se solved

- ❌ Har jagah bada model — Haiku default review, escalation path defined

- ❌ Complex model-routing configs — 3 bash variables kaafi hain

- ❌ L4 (human review) automation — judgment automate nahi hota

- ❌ CLAUDE.md me task lists, model policy, ya code se infer hone wali info

- ❌ RBAC / multi-user approval roles — solo maintainer approves everything,
  `approve.sh` doesn't need to know who "should" be allowed to run it

- ❌ External audit database — a git-tracked `AUDIT_LOG.jsonl` file is the
  audit log; `tail`/`grep`/`jq` on it is enough tooling

- ❌ Auto-approval inferred from checklist completeness — sign-off is
  never inferred from how clean a self-check looks, only explicit

- ❌ LLM-driven approval flow — `approve.sh` is deterministic bash, not a
  `claude -p` session (flipping a checkbox needs zero judgment)

- ❌ Dashboard/TUI for reviewing pauses or the audit log — markdown +
  JSONL + shell one-liners are enough for a solo maintainer

---

## Ek line me

Human requirements likhta hai aur final diff padhta hai; beech ka sab —

planning, coding, testing, review, session management — fresh sessions,

git, aur 3 markdown files ke through automatic chalta hai, minimum tokens me.
 
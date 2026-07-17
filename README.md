# claude-skills

Personal Claude Code skills (`~/.claude/skills/` on this machine). Each
subfolder is one skill — a `SKILL.md` plus any template files it needs.
Claude Code reads skills from this exact path per user account, so cloning
this repo to `~/.claude/skills/` on a new machine makes every skill here
available in every project, with no per-project setup.

## Skills

- **setup-ai-workflow** — scaffolds a solo-dev AI pipeline (task-loop
  execution via `run-plan.sh`, layered review, session hooks, a token-cheap
  `check.sh` verification gate) into any project, any language. Invoke with
  `/setup-ai-workflow` inside a project, or describe it in natural language.

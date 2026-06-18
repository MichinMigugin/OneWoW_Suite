<!-- Do NOT run Claude's /init in this repo: it rewrites this file and will clobber the @AGENTS.md import below. -->
@AGENTS.md

## Claude-specific

- **Skills:** `.claude/skills/` contains discovery stubs only. When a skill
  activates, read the canonical file under `.cursor/skills/<name>/SKILL.md` and
  follow that — not the stub body.
- **Invoke manually:** `/onewow-database-api`, `/onewow-locale-workflow`, etc.
- **Conditional activation:** stubs with `paths:` frontmatter auto-load when you
  touch matching files; the rest activate from their `description`.
- **Regenerate generated files:** run `python bin/sync_agent_context.py` after
  changing any `.cursor/rules/`, `.cursor/skills/`, or `.cursor/agent-context.yaml`.
  This file (`CLAUDE.md`) is hand-written and is never touched by the generator.

---
name: onewow-wiki
description: Use when editing the GitHub wiki (wiki/**), syncing player docs after feature/README changes, or deciding whether a Docs or addon README change needs a wiki update. Decide include vs skip, then follow OneWoW-Wiki.mdc for dialect.
---

# OneWoW Player Wiki

Curated player docs live in `wiki/` and sync one-way to the GitHub Wiki via
`.github/workflows/publish-wiki.yml`. Engineering Docs (`OneWoW/Docs/`,
`ADDON/Docs/`) remain the source of truth — this wiki is not a second copy.

Format and mechanical conventions live in `.cursor/rules/OneWoW-Wiki.mdc`
(auto-attached when `wiki/**` files are open). Load this skill when deciding
whether a suite change belongs on the wiki, or when drafting/updating pages.

## Include vs skip

| Change | Wiki? |
|---|---|
| Player-visible feature, tab, slash, install/setup, or search syntax players type | **Yes** — update or add the matching `wiki/` page |
| Addon `README.md` player sections that a wiki page Sources | **Yes** — keep the wiki page in sync |
| New load unit in the public catalog | **Yes** — root `README.md` + `ADDON/README.md` + wiki feature page + `_Sidebar.md` |
| Engineering-only Docs (architecture internals, DB schema, API surface) | **No** wiki body — at most a link from `wiki/Developers.md` |
| Agent rules/skills, renames with identical player meaning, AccountSync / non-player tools | **No** |

Wiki-only edits are **not** CurseForge changelog material — leave `CHANGELOG.md`
alone (see `onewow-changelog`).

If yes → edit `wiki/`, keep **Related → Sources** accurate, do not paste engineering
depth from Docs. If no → leave `wiki/` alone.

## Writing

- Players, not developers: what to do in-game, not file/API maps.
- Dialect: `OneWoW-Wiki.mdc`.
- After adding this skill or changing `.cursor/agent-context.yaml`, run
  `python bin/sync_agent_context.py` (manual; not a pre-commit hook).

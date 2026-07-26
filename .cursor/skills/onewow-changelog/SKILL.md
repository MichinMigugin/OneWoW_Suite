---
name: onewow-changelog
description: Use when shipping player-felt OneWoW suite changes — visible UI/behavior or experiential wins (performance, snappiness, reliability) — or when editing root CHANGELOG.md / CurseForge release notes. Decide include vs skip, then follow OneWoW-Changelog.mdc for dialect.
---

# OneWoW Changelog

Root `CHANGELOG.md` is the CurseForge release note. Format and skeleton live in
`.cursor/rules/OneWoW-Changelog.mdc` (auto-attached when that file is open). Load
this skill when deciding whether a suite change belongs there, or when drafting
bullets.

## Include vs skip

| Change | Changelog? |
|---|---|
| Visible UI, behavior, settings, or strings | **Yes** |
| Experiential: faster open/close, less hitching, more reliable flows (e.g. bank opens ~25% faster) | **Yes** |
| Player-facing bugfix (UI may look the same) | **Yes** |
| Rename, comment/doc-only, formatting, agent rules/skills, dead-code with identical behavior | **No** |

If yes → add a short player-facing bullet under the matching suite-wide `##` or
per-addon `#` section in `CHANGELOG.md`. If no → leave the file alone.

## Writing

- Players, not developers: “Bank opens faster”, not “optimized BankFrame prefetch”.
- No changelog noise in Lua comments — this file is the release record.
- Dialect/skeleton: `OneWoW-Changelog.mdc` (CurseForge-safe markdown only).

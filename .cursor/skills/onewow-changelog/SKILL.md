---
name: onewow-changelog
description: Use when shipping player-felt OneWoW suite changes — visible UI/behavior or experiential wins (performance, snappiness, reliability) — or when editing root CHANGELOG.md / CurseForge release notes. Decide include vs skip, then follow OneWoW-Changelog.mdc for dialect. Owns the release-notes pipeline (CHANGELOG → wiki Release-Notes Current / per-version archives → What’s New reassessment).
---

# OneWoW Changelog

Root `CHANGELOG.md` is the CurseForge release note and the **source of truth** for
in-progress release notes. Format and skeleton live in
`.cursor/rules/OneWoW-Changelog.mdc` (auto-attached when that file is open). Load
this skill when deciding whether a suite change belongs there, or when drafting
bullets.

## Include vs skip

| Change | Changelog? |
|---|---|
| Visible UI, behavior, settings, or strings | **Yes** |
| Experiential: faster open/close, less hitching, more reliable flows (e.g. bank opens ~25% faster) | **Yes** |
| Player-facing bug fix (UI may look the same) | **Yes** |
| Rename, comment/doc-only, formatting, agent rules/skills, dead-code with identical behavior | **No** |
| GitHub wiki / `wiki/**` / player-doc sync only (no in-game change) | **No** — use `onewow-wiki` instead |

If no → leave `CHANGELOG.md` alone (and do not touch the downstream mirrors below).

If yes → add a short player-facing bullet under the matching suite-wide `##` or
per-addon `#` section in `CHANGELOG.md`, then run the **downstream pipeline**.

## Downstream pipeline (same change)

Changelog owns the decision; other skills/rules own the format:

1. **`CHANGELOG.md`** — write the bullet(s) here first (`OneWoW-Changelog.mdc`).
2. **Wiki release notes** — mirror into `wiki/Release-Notes.md` → `## Current`
   on the index (always CHANGELOG → wiki; never wiki-first). At release, archive
   to `Release-Notes-<TOCVersion>.md` and add an index summary link. Load
   `onewow-wiki` / `OneWoW-Wiki.mdc` for demotion, chrome, and archive steps.
3. **What’s New** — reassess `OneWoW/Core/WhatsNewData.lua` against the full
   current CHANGELOG. Update only when the highlight set or wording should
   change (see `OneWoW-Changelog.mdc` § What’s New). Locale key add/change →
   `onewow-locale-workflow` (all 11 locales).

Feature wiki pages (install, slash, search syntax, new load units) remain a
**separate** `onewow-wiki` include/skip — not part of this pipeline.

## Writing

- Players, not developers: “Bank opens faster”, not “optimized BankFrame prefetch”.
- No changelog noise in Lua comments — this file is the release record.
- Dialect/skeleton: `OneWoW-Changelog.mdc` (CurseForge-safe markdown only).

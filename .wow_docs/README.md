# `.wow_docs` — curated WoW UI reference

This directory holds a **small, hand-picked** slice of Blizzard client UI material from the [Gethe `wow-ui-source` repository](https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns) (`live` branch, `Interface/AddOns`).

The copies here map to **areas OneWoW_Suite addons actually touch**—for example tooltips, items, bags/bank/containers, cursors, colors, and shared constants—rather than the full AddOns tree.

## Why it exists

The full `wow-ui-source` tree is large. Agents following [`.cursor/skills/wow-api-specialist/SKILL.md`](../.cursor/skills/wow-api-specialist/SKILL.md) are directed to use **this folder first** so they can answer FrameXML, implementation, and API-adjacent questions from a focused local set instead of searching or paging through the entire upstream repo.

Treat these files as **reference mirrors** of upstream; for the canonical path and history, use the GitHub link above.

---
name: wow-api-specialist
description: Use this skill when writing or debugging WoW addon code requiring specific API functions, FrameXML constants, or Event handling.
---

# WoW API Specialist Skill

## Context
You have access to curated Blizzard implementation docs at `_OneWoW_Offline\Docs\`.
You have access to indexed docs for `warcraft.wiki.gg` via `@WoW API`.
You have access to indexed docs for `https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_APIDocumentationGenerated` via `@Blizzard API`
Ensure compatibility with WoW API v12.0+.

## Instructions
When checking API/game information, use only the sources below unless explicit permission is provided for others.
Prioritize modern `C_` namespaces (e.g., `C_Timer`, `C_Item`). Functions marked protected/restricted cannot be used.

1. `_OneWoW_Offline\Docs\`: curated set of WoW API documents. Use this first.
2. `@WoW API`: use as authoritative for API behavior, signatures, and events.
3. `@Blizzard API`: Blizzard generated API docs (constants, enums, C_ namespaces). Use when wiki is incomplete or silent.
4. `https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns`: Blizzard client UI / FrameXML. Use when previous sources are exhausted or as validation of how APIs are used in-game.
5. `https://warcraft.wiki.gg/wiki/Lua_functions`: Lua functions in WoW (what's available/removed).
6. `https://www.lua.org/manual/5.1/`: Lua 5.1 manual.
7. `wowhead.com`: use for general game information.
8. `google.com`: use as a search engine to reach allowed sources.

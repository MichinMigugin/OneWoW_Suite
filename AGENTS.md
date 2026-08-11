# OneWoW Suite — Agent Instructions

Cross-tool entry point for AI coding agents (Codex, Claude Code, Gemini CLI, and
others that read `AGENTS.md`). Cursor does **not** need this file — it loads
`.cursor/rules/` and `.cursor/skills/` natively.

## Project

OneWoW Suite is a World of Warcraft **Retail 12.0+** Lua addon suite: a
multi-load-unit monorepo of cooperating addons (`OneWoW_Bags`, `OneWoW_Catalog`,
`OneWoW_AltTracker`, `OneWoW_QoL`, …) orchestrated by the core hub in
[`OneWoW/`](OneWoW/). The shared UI/DB toolkit is published as the global
`OneWoW_GUI`.

## Canonical sources (do not hand-edit generated files)

| Authoritative (edit these) | Generated (do not edit) |
| --- | --- |
| `.cursor/rules/*.mdc` | the rules tables in this file (between markers) |
| `.cursor/skills/*/SKILL.md` | `.agents/skills/*/SKILL.md` (Codex stubs) |
| `.cursor/agent-context.yaml` (manifest) | `.claude/skills/*/SKILL.md` (Claude stubs) |

The skill stubs and the marker-delimited tables below are produced by
[`bin/sync_agent_context.py`](bin/sync_agent_context.py). Edit the canonical
source and re-run the generator; never edit generated output by hand.

## Non-negotiables (always apply)

These mirror the Cursor `alwaysApply: true` rules. Other tools have no
equivalent of always-apply, so the essentials are inlined here (not just linked).

### Embedded libraries are off-limits

**Do not edit, refactor, or modify files in embedded `Libs/` folders.** They are
vendored third-party libraries (LibStub, Ace3, etc.) embedded as-is. Changes
break compatibility and diverge from upstream. If a task needs different Lib
behavior, implement it in addon code, or note that the Lib must be updated
manually. Full rule: [`.cursor/rules/OneWoW-Embedded-Libs-OffLimits.mdc`](.cursor/rules/OneWoW-Embedded-Libs-OffLimits.mdc).

### Fix quality — no patches

Prefer root-cause, architecturally-sound fixes over symptom patches. Reuse
existing suite patterns (funnels, BootStore, lifecycle, `OneWoW_GUI`,
Restriction). **Stop and discuss** before implementing when the proper fix is
larger than reported or expansive (shared components, other load units, new
cross-unit contracts / APIs). No shipped `TODO`/`FIXME` temporaries or defensive
guards that paper over broken invariants. Full rule:
[`.cursor/rules/OneWoW-Fix-Quality.mdc`](.cursor/rules/OneWoW-Fix-Quality.mdc).

### WoW addon essentials (digest)

Condensed from [`.cursor/rules/WoW-Lua-Addon-Development.mdc`](.cursor/rules/WoW-Lua-Addon-Development.mdc)
— read the full rule for depth.

- **Target Retail 12.0+ only.** No Classic/multi-version compat. Every `C_*`
  namespace, `Enum.*` table, and modern Blizzard global is guaranteed present at
  load — do **not** write existence guards for them (see `No-Defensive-Guards`).
- **Prefer `C_*` namespace APIs.** Many legacy globals were removed in 12.0
  (`GetSpellInfo`→`C_Spell`, `GetItemInfo`→`C_Item`, `UnitBuff`/`UnitDebuff`→
  `C_UnitAuras`, `GetContainerItemInfo`→`C_Container`). Use `Enum.*` constants,
  never hardcoded magic numbers.
- **Secret values (12.0+).** Combat/instanced data may be opaque secrets: you can
  pass them to display APIs but cannot branch on them, concatenate them, or call
  `tonumber()` on them from addon (tainted) code.
- **Taint:** all addon code is tainted. Never overwrite Blizzard globals — use
  `hooksecurefunc`. Gate secure-frame changes behind
  `not OneWoW.Restriction.IsAddonRestricted()` (broad, incl. Map) or
  `IsProtectedActionBlocked()` (protected actions valid inside an instanced map out
  of combat, excl. Map) — never call `InCombatLockdown` / `C_RestrictedActions.*`
  directly (use `OneWoW.Restriction.IsInCombat()` for combat-only UX/perf gates, and
  `RunWhenUnrestricted` to defer). Enforced by the `restriction-funnel` hook.
- **Timers:** prefer `C_Timer.After` / `C_Timer.NewTicker` over `OnUpdate`.
- **Menus:** use `MenuUtil` (12.0+), not the deprecated `UIDropDownMenu`.
- **Tooltips:** the 10.0.2 rewrite removed `OnTooltipSetItem`/`OnTooltipSetSpell`
  and hidden scanning — use `TooltipDataProcessor` / `C_TooltipInfo`.
- **`OneWoW_GUI`** is a `RequiredDep` global for every suite unit; take a local
  handle `local OneWoW_GUI = OneWoW_GUI` near the top of each file and call it
  directly (no `if OneWoW_GUI then` guards).
- **WoW table globals:** prefer `tinsert`/`tremove`/`sort`/`wipe` over `table.*`.
- **File encoding:** LF line endings only (`.gitattributes` + pre-commit enforce
  it). Never emit CRLF.

## Rules — read the matching rule when editing these paths

These mirror the glob-scoped Cursor rules. Open the listed `.cursor/rules/*.mdc`
file before editing files that match its glob(s).

<!-- BEGIN GENERATED: rules-globs -->
| Glob(s) | Rule(s) |
| --- | --- |
| `**/*.lua` | `No-Defensive-Guards.mdc`, `OneWoW-Code-Comments.mdc`, `OneWoW-Lua-Conventions.mdc` |
| `**/Locales/**/*.lua` | `OneWoW-Locale-Workflow.mdc` |
| `CHANGELOG.md` | `OneWoW-Changelog.mdc` |
| `OneWoW*/**/*.lua`, `OneWoW/**/*.lua`, `OneWoW*/**/*.toc` | `OneWoW-Suite-Architecture.mdc` |
| `OneWoW_QoL/Modules/external/**/*.lua` | `OneWoW-QoL-Modules.mdc` |
| `wiki/**` | `OneWoW-Wiki.mdc` |
<!-- END GENERATED: rules-globs -->

## Skills — load the matching specialist before related work

Each skill below is a stub for discovery; the authoritative instructions live in
the canonical file. When a skill is relevant, read its `.cursor/skills/<name>/SKILL.md`
in full and follow it.

<!-- BEGIN GENERATED: skills -->
| Skill | Use when | Canonical file |
| --- | --- | --- |
| `onewow-changelog` | Use when shipping player-felt OneWoW suite changes — visible UI/behavior or experiential wins (performance, snappiness, reliability) — or when editing root CHANGELOG.md / CurseForge release notes. Decide include vs skip, then follow OneWoW-Changelog.mdc for dialect. Owns the release-notes pipeline (CHANGELOG → wiki Release-Notes Current / per-version archives → What’s New reassessment). | `.cursor/skills/onewow-changelog/SKILL.md` |
| `onewow-database-api` | Use this skill when authoring or reviewing OneWoW addon code that touches SavedVariables, defaults, init bridges, or scope resolution — anything calling OneWoW_GUI.DB or accessing Addon.db.* paths. | `.cursor/skills/onewow-database-api/SKILL.md` |
| `onewow-db2` | Use when reasoning about client DB2 game-data tables — Journal/EJ membership, instance flags, MapDifficulty, Difficulty, DungeonEncounter, or other extracts under .wow_db2 — validating ATT vs Retail listing, regenerating Generated Lua, or deciding CSV vs FrameXML vs ATT Data/. Not for C_* APIs, FrameXML, or GlobalStrings (use wow-api-specialist / onewow-locale-workflow). | `.cursor/skills/onewow-db2/SKILL.md` |
| `onewow-dev-setup` | Use when the user asks to set up their OneWoW development environment, configure the Cursor/VS Code dual-root workspace, create the _OneWoW_Offline dropzone, install Lua/Python/Markdown extensions (including Ketho WoW API), or install pre-commit tooling for OneWoW Suite. | `.cursor/skills/onewow-dev-setup/SKILL.md` |
| `onewow-gui-ui` | Use this skill when authoring or reviewing OneWoW addon UI code — anything calling CreateFrame, building widgets, applying theme colors, sizing windows, or producing user-facing strings. Covers the OneWoW_GUI-First component policy, theme API, and constants/localization rules. | `.cursor/skills/onewow-gui-ui/SKILL.md` |
| `onewow-locale-workflow` | Use when adding, changing, or removing user-facing strings or locale keys in any OneWoW addon — UI labels, errors, tooltips, new L["KEY"] entries, or edits under Locales/*.lua. Covers Blizzard globals vs shared vs scoped keys, all 11 locales, and locale_keydiff / locale_verify. | `.cursor/skills/onewow-locale-workflow/SKILL.md` |
| `onewow-qol-modules` | Use this skill when creating, scaffolding, or reviewing a OneWoW_QoL feature module — anything about the external module hub, module.lua/Define, the ModuleRegistry, Current() capture, per-module locale scopes, toggles, or the OnEnable/OnDisable/OnToggle lifecycle. Especially for "add a new QoL module" prompts where no module file is open yet. | `.cursor/skills/onewow-qol-modules/SKILL.md` |
| `onewow-suite-architecture` | Use when authoring or reviewing OneWoW suite load units — lifecycle hooks, BootStore, BringUp/EnsureLoaded, enable/opt-out, ModuleManifest, hub tab order, OptionalDeps, or cross-unit integration. | `.cursor/skills/onewow-suite-architecture/SKILL.md` |
| `onewow-wiki` | Use when editing the GitHub wiki (wiki/**), syncing player docs after feature/README changes, mirroring CHANGELOG into wiki/Release-Notes.md ## Current (index) or archiving to Release-Notes-<TOCVersion>.md, or deciding whether a Docs or addon README change needs a wiki update. Decide include vs skip, then follow OneWoW-Wiki.mdc for dialect. | `.cursor/skills/onewow-wiki/SKILL.md` |
| `wow-api-specialist` | Use this skill when writing or debugging WoW addon code requiring specific TOC references, Lua functions and syntax, API functions, FrameXML constants, or Event handling. | `.cursor/skills/wow-api-specialist/SKILL.md` |
| `wow-frame-script-pitfalls` | Use this skill when authoring or reviewing WoW addon code that writes frame scripts, event handlers, or widget callbacks — anything calling SetScript, HookScript, SetBackdrop, ClearAllPoints, SetFontObject, or building popups/dropdowns. Covers closure ordering, stale upvalues, button event ordering, SetScript vs HookScript, backdrop color reset, anchor override, FontString local-override staleness, and the popup-dismiss OnUpdate hybrid pattern. | `.cursor/skills/wow-frame-script-pitfalls/SKILL.md` |
| `wow-tooltip-system` | Use this skill when authoring or reviewing WoW addon code that creates, hooks, or scans tooltips — anything calling GameTooltip, TooltipDataProcessor, C_TooltipInfo, or walking tooltipData.lines. | `.cursor/skills/wow-tooltip-system/SKILL.md` |
<!-- END GENERATED: skills -->

## Repo workflow

- **LF only** — enforced by [`.gitattributes`](.gitattributes) and the
  `mixed-line-ending` pre-commit hook. Never commit CRLF.
- **Pre-commit:** `python -m pre_commit install`, then
  `python -m pre_commit run --all-files` before pushing.
- **Locale changes:** run `python bin/locale_keydiff.py` and
  `python bin/locale_verify.py`; follow [`OneWoW/Docs/LOCALES.md`](OneWoW/Docs/LOCALES.md)
  (11 locales, key parity, Blizzard-global / shared / scoped routing).
- **Changelog:** after player-felt suite changes (visible UI/behavior **or**
  experiential wins like speed/snappiness/reliability), update root
  [`CHANGELOG.md`](CHANGELOG.md) per [`OneWoW-Changelog.mdc`](.cursor/rules/OneWoW-Changelog.mdc),
  then mirror into [`wiki/Release-Notes.md`](wiki/Release-Notes.md) `## Current` and
  reassess What’s New (`OneWoW/Core/WhatsNewData.lua`, up to 7 highlights). Skip pure
  internals with no felt difference. Load `onewow-changelog` when deciding.
- **After changing any `.cursor/rules/*.mdc`, `.cursor/skills/`, or
  `.cursor/agent-context.yaml`:** run `python bin/sync_agent_context.py` to
  regenerate the stubs and the tables above (manual; there is no pre-commit hook).
- **Never edit `Libs/`** (embedded third-party — see above).
- **Architecture references:** [`OneWoW/Docs/ARCHITECTURE.md`](OneWoW/Docs/ARCHITECTURE.md),
  [`OneWoW/Docs/DATABASE.md`](OneWoW/Docs/DATABASE.md).

## Tool coverage

- **Cursor** — uses `.cursor/rules/` and `.cursor/skills/` directly; this file is
  not needed there.
- **Codex** — reads this file and discovers `.agents/skills/`.
- **Claude Code** — reads [`CLAUDE.md`](CLAUDE.md), which imports this file via
  `@AGENTS.md`, and discovers `.claude/skills/`.
- **Gemini CLI** — also reads `AGENTS.md` (configurable via `.gemini/settings.json`).
- **GitHub Copilot** — **not** covered here; it would need
  `.github/copilot-instructions.md` (known, out-of-scope gap).

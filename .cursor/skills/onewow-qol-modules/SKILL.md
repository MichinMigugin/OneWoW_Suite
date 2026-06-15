---
name: onewow-qol-modules
description: Use this skill when creating, scaffolding, or reviewing a OneWoW_QoL feature module — anything about the external module hub, module.lua/Define, the ModuleRegistry, Current() capture, per-module locale scopes, toggles, or the OnEnable/OnDisable/OnToggle lifecycle. Especially for "add a new QoL module" prompts where no module file is open yet.
---

# OneWoW QoL External Modules Skill

A OneWoW_QoL module is a self-contained folder under
`OneWoW_QoL/Modules/external/<id>/`. The hub handles registration, the Features
UI, toggles, saved state, and language switching — the folder declares metadata
and logic only.

**Authoritative guide: `OneWoW_QoL/DEVELOPERS.md`** — folder layout, full
module/toggle field tables, lifecycle callbacks, categories, SavedVariables,
common mistakes. Read it for anything beyond the scaffold below. A path-scoped
Cursor rule (`OneWoW-QoL-Modules.mdc`) auto-attaches the same rules when editing
files under `Modules/external/`; this skill covers the cold-start case where you
are creating a module and no file is open yet.

## Minimal module scaffold

A working module needs `module.lua` (metadata, loads first), one code file, and
at least one locale file. `autodelete` is the reference module to copy.

```lua
-- Modules/external/yourmodule/module.lua   (loads FIRST; metadata only)
local ADDON_NAME, ns = ...
ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",        -- the ONLY place the id appears; match folder name
    title       = "YOURMODULE_TITLE",  -- locale KEY, not English text
    category    = "UTILITY",           -- AUTOMATION|INTERFACE|SOCIAL|COMBAT|ECONOMY|UTILITY
    description = "YOURMODULE_DESC",    -- locale KEY
    version     = "1.0",
    toggles = {
        { id = "myToggle", label = "YOURMODULE_TOGGLE", description = "YOURMODULE_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
})
```

```lua
-- Modules/external/yourmodule/yourmodule.lua   (logic)
local _, ns = ...
local M, L = ns.ModuleRegistry:Current()   -- load-time only; capture once
if not M then return end

function M:OnEnable()  end                  -- register events, create frames, hook
function M:OnDisable() end                  -- reverse everything OnEnable did
function M:OnToggle(toggleId, value) end    -- react to a flipped named toggle
```

```lua
-- Modules/external/yourmodule/Locales/enUS.lua
local _, ns = ...
local M = ns.ModuleRegistry:Current()
OneWoW.Locale:Register(M._scope, "enUS", {
    YOURMODULE_TITLE        = "My Module",
    YOURMODULE_DESC         = "What it does, in plain language.",
    YOURMODULE_TOGGLE       = "My Toggle",
    YOURMODULE_TOGGLE_DESC  = "What the toggle does.",
})
```

Then add the files to the `EXTERNAL MODULES` block of `OneWoW_QoL.toc`, **`module.lua`
first**, then locales, then code files.

## The rules that cause bugs when missed

1. **`module.lua` loads first** — it is the single home of the module `id` and the
   thing every other file's `Current()` depends on. No `data.lua`; `Define` registers.
2. **`Current()` is load-time only** — `local M, L = ns.ModuleRegistry:Current()` at
   the top of each file, captured into a local. Never call it at runtime. Use
   `local _, L = ...` for a strings-only file; skip the call if a file needs neither.
3. **Cross-module access via `ns.ModuleRegistry:GetById("id")`** — never an
   `ns.YourModule` global (those were removed). In-module, use the `Current()` local.
4. **Locale scope is `M._scope`** (`ADDON_NAME .. "." .. id`). Store locale KEYS in
   `title`/`description`/toggle `label`; the Features UI resolves them from your scope.
5. **No `L[key] or "fallback"`** — a miss resolves to the key name (visible by design).
   Genuinely optional text → `OneWoW.Locale:GetOptional(scope, key)`.
   (Suite Locale contract: `OneWoW/Docs/ARCHITECTURE.md` §6.)

## Reading state at runtime

- Toggle value: `ns.ModuleRegistry:GetToggleValue("yourmodule", "myToggle")`
- Enabled check (guard direct event handlers): `ns.ModuleRegistry:IsEnabled("yourmodule")`
- Your saved data: `_G.OneWoW_QoL.db.global.modules["yourmodule"]` — only after init
  (inside `OnEnable` or later), never at file load.

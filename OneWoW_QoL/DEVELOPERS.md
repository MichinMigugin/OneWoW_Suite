# OneWoW QoL - Module Developer Guide

OneWoW QoL is a drop-in module hub for World of Warcraft quality-of-life features. You create a self-contained folder, add your files to the TOC, and the addon handles registration, the UI, toggles, saved settings, and language switching automatically.

**See also:** [OneWoW/Docs/ARCHITECTURE.md](../OneWoW/Docs/ARCHITECTURE.md) (suite lifecycle, ModuleRegistry) · [OneWoW/Docs/LOCALES.md](../OneWoW/Docs/LOCALES.md) (locale scopes, QoL module scope `OneWoW_QoL.<id>`) · [CONTRIBUTING.md](../CONTRIBUTING.md)

---

## Folder Structure

Your module lives entirely inside its own folder:

```
OneWoW_QoL/
  Modules/
    external/
      yourmodule/
        module.lua        (required - metadata + registration; loads FIRST)
        Locales/
          enUS.lua        (optional - English strings)
          koKR.lua        (optional - Korean strings)
        yourmodule.lua    (required - lifecycle functions and logic)
        logic.lua         (optional - additional logic files, as many as you need)
        ui.lua            (optional - split UI code into its own file if you prefer)
```

There is no file count limit. A simple module needs `module.lua`, one locale file, and one code file. A complex module may have a dozen code files. Keep everything inside your folder and list it all in the TOC. The one hard rule is that **`module.lua` loads first** - it defines your module and its locale scope, which every other file relies on.

Use the `autodelete` module as a working reference.

Per-module catalog (all 36 external modules): [MODULES.md](MODULES.md). Add a `README.md` in your module folder only when behavior needs more than the in-game description (see `questitembar`). For larger designs (data models, match rules, migration), prefer **`Docs/Modules/<id>.md`** and link it from the MODULES.md entry — see [Docs/Modules/cursorenhancer.md](Docs/Modules/cursorenhancer.md).

---

## How It Works

- `module.lua` calls `ns.ModuleRegistry:Define(ADDON_NAME, { ... })` with your metadata. This is the single home of your module `id`. `Define` registers the module, derives its locale scope (`ADDON_NAME .. "." .. id`, e.g. `OneWoW_QoL.yourmodule`), and caches a read-only locale view.
- Every other file in your module grabs the module and its locale view at load with `local M, L = ns.ModuleRegistry:Current()` and captures them into file-locals.
- Locale files register their strings into your scope with `OneWoW.Locale:Register(M._scope, locale, { ... })`.
- The hub renders the UI, manages toggles and saved state, and switches language automatically.

> **`Current()` is load-time only.** It returns "the module currently loading." Call it once at the top of each file and capture the result into a local. Never call it at runtime - by then a different module may be the one loading.

---

## Step 1 - module.lua (metadata, loads first)

```lua
local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",   -- the ONLY place the id appears
    title       = "MY_MODULE_TITLE",
    category    = "AUTOMATION",
    description = "MY_MODULE_DESC",
    version     = "1.0",

    -- Optional contact info (shown in the Details dialog)
    author  = "Your Name",
    contact = "your@email.com",
    link    = "https://yoursite.com",

    -- Toggles the user can flip on/off in the UI
    toggles = {
        { id = "myToggle", label = "MY_TOGGLE_LABEL", description = "MY_TOGGLE_DESC", default = true },
    },

    defaultEnabled = true,
})
```

`module.lua` holds metadata only - no logic, no frames. Runtime state and methods live in your code files.

---

## Step 2 - yourmodule.lua (logic)

Grab your module table and locale view at the top, then attach lifecycle functions:

```lua
local _, ns = ...
local YourModule, L = ns.ModuleRegistry:Current()
if not YourModule then return end

function YourModule:OnEnable()
end

function YourModule:OnDisable()
end

function YourModule:OnToggle(toggleId, value)
end
```

Split logic across as many files as you like - each starts the same way:

```lua
local _, ns = ...
local YourModule, L = ns.ModuleRegistry:Current()
```

If a file only needs strings (not the module table), use `local _, L = ns.ModuleRegistry:Current()`. If it needs neither, it does not need to call `Current()` at all.

---

## Step 3 - Add Your Files to the TOC

Open `OneWoW_QoL.toc`, find the `EXTERNAL MODULES` section, and list your files. **`module.lua` first**, then locale files, then your code files:

```
Modules\external\yourmodule\module.lua
Modules\external\yourmodule\Locales\enUS.lua
Modules\external\yourmodule\Locales\koKR.lua
Modules\external\yourmodule\yourmodule.lua
Modules\external\yourmodule\ui.lua
```

`module.lua` must come before everything else so `Current()` returns your module while your other files load. There is no `data.lua` - `Define` handles registration.

If you are not supporting Korean, skip the `koKR.lua` line.

---

## Module Table Fields

### Required

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier. Lowercase, no spaces. Must be unique across all loaded modules. Should match your folder name. |
| `title` | string | A locale key (e.g. `"MY_MODULE_TITLE"`). Displayed as the module name. |
| `category` | string | One of the six valid categories below. |
| `description` | string | A locale key. Shown in the detail panel. |

### Recommended

| Field | Type | Description |
|---|---|---|
| `version` | string | Version string shown in the Details dialog (e.g. `"1.0"`). |
| `toggles` | table | Array of toggle definitions. See Toggle Fields below. |
| `defaultEnabled` | boolean | Whether the module is on by default. |

### Optional Contact Info

| Field | Type | Description |
|---|---|---|
| `author` | string | Your name. Shown as plain text in the Details dialog. |
| `contact` | string | Email/Discord. Shown as a copyable text box. |
| `link` | string | Website URL. Shown as a copyable text box. |

If none of `author`, `contact`, or `link` are set, the `Details` button does not appear.

---

## Toggle Fields

Each entry in the `toggles` array is a table:

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique within this module. Used to read/save the value. |
| `label` | string | A locale key. Shown as the toggle name. |
| `description` | string | A locale key. Shown below the toggle row. Optional but recommended. |
| `default` | boolean | Value used when the player has never changed this toggle. |

Toggles render automatically in the detail panel with On/Off buttons. Read the current value with `ns.ModuleRegistry:GetToggleValue(moduleId, toggleId)`. When the master enable is off, sub-toggles gray out.

---

## Lifecycle Callbacks

Define these on your module table (the one returned by `Current()`), using colon syntax so `self` is your module.

### `OnEnable()`

Called when the addon loads with this module enabled, or when the user clicks Enable. Register events, create frames, hook functions here.

```lua
function YourModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_YourModule")
    end
    self._frame:RegisterEvent("SOME_EVENT")
    self._frame:SetScript("OnEvent", function(frame, event, ...)
        -- handle event
    end)
end
```

### `OnDisable()`

Called when the user clicks Disable. Reverse everything from `OnEnable` - unregister events, hide frames, remove hooks.

### `OnToggle(toggleId, value)`

Called when the user flips one of your named toggles. `toggleId` is the `id` string; `value` is `true`/`false`.

```lua
function YourModule:OnToggle(toggleId, value)
    if toggleId == "myToggle" then
        -- react to the change
    end
end
```

---

## Categories

| Key | Display Name | Use for |
|---|---|---|
| `AUTOMATION` | Automation | Anything that acts automatically without player input |
| `INTERFACE` | Interface | UI changes, popup modifications, frame tweaks |
| `SOCIAL` | Social | Chat, guild, friend, or communication features |
| `COMBAT` | Combat | Combat actions, targeting, cooldowns |
| `ECONOMY` | Economy | Gold, auction house, vendor, crafting |
| `UTILITY` | Utility | Everything else |

Invalid categories default to `UTILITY`.

---

## Locale System

All UI text goes through the OneWoW Locale service. You store key names; locale files map keys to display strings, registered into your module's own scope.

### Locales/enUS.lua

```lua
local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_MODULE_TITLE"] = "My Module Name",
    ["MY_MODULE_DESC"]  = "What this module does, in plain language.",
    ["MY_TOGGLE_LABEL"] = "My Toggle Name",
    ["MY_TOGGLE_DESC"]  = "What this toggle does.",
})
```

### Locales/koKR.lua

```lua
local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "koKR", {
    ["MY_MODULE_TITLE"] = "...",
    ["MY_MODULE_DESC"]  = "...",
})
```

Your scope (`M._scope`) is `ADDON_NAME .. "." .. id`, e.g. `OneWoW_QoL.yourmodule`. The service folds English first, then the active language on top, so any koKR key you omit falls back to English. A missing key resolves to the **key name itself** (so missing strings are visible, never `nil`) - do not write `L[key] or "fallback"`.

### Using strings at runtime

```lua
local title = L["MY_MODULE_TITLE"]
```

`L` is the locale view you captured from `Current()`. The Features UI also resolves `title`/`description`/toggle labels from your scope automatically, so for those you only store the key.

---

## Referencing Another Module

Never reach into another module through a global. Look it up by id through the registry:

```lua
local mb = ns.ModuleRegistry:GetById("minimapbuttons")
if mb and mb.ApplyMinimapShapeToLibDBIcons then
    mb:ApplyMinimapShapeToLibDBIcons()
end
```

There is no `ns.YourModule` global - the registry is the single source of truth. (Within your own module's files, use the local you captured from `Current()`.)

---

## Reading Toggle Values

Always read through the registry so you get the current saved state:

```lua
local on = ns.ModuleRegistry:GetToggleValue("yourmodule", "myToggle")
if on then
    -- toggle is on
end
```

---

## SavedVariables

`OneWoW_QoL_DB` is initialized by `Core/Database.lua` via the `OneWoW_GUI.DB` API. Your module's enable state and toggle values are managed automatically under:

```
OneWoW_QoL_DB.global.modules.yourmodule
```

For your own saved data, use `ns.db` (only after init — e.g. inside `OnEnable`, never at file load). Every module file already has `local ADDON_NAME, ns = ...`:

```lua
local bucket = ns.ModuleRegistry:GetModuleBucket("yourmodule")
-- bucket.enabled and bucket.toggles are registry-managed; add custom keys on bucket
```

---

## Checking Enable State in Your Own Handlers

If your module registers events directly, guard the handler:

```lua
function YourModule:OnEnable()
    self._frame:SetScript("OnEvent", function(frame, event, ...)
        if not ns.ModuleRegistry:IsEnabled("yourmodule") then return end
        -- your logic
    end)
end
```

---

## Complete Working Example

`autodelete` in `Modules/external/autodelete/` is a complete module split across files:

- `module.lua` - metadata + `Define`
- `autodelete.lua` - `local AutoDeleteModule = ns.ModuleRegistry:Current()`, lifecycle functions
- `logic.lua` - more logic; also opens with `local AutoDeleteModule = ns.ModuleRegistry:Current()`
- `Locales/enUS.lua` + `koKR.lua` - strings registered into the module's scope

It demonstrates metadata in `module.lua`, logic captured via `Current()`, locale registration into the module scope, two toggles with descriptions, contact fields, and event setup/cleanup in `OnEnable`/`OnDisable`.

---

## Common Mistakes

**`module.lua` not first** - if it does not load before your other files, `Current()` returns the wrong module (or nil) and your files bail at the `if not M then return end` guard. Keep `module.lua` at the top of your TOC block.

**Calling `Current()` at runtime** - capture it into a file-local at load. At runtime it points at whatever module loaded last.

**Referencing `ns.YourModule`** - that global no longer exists. Within your module use the local from `Current()`; for another module use `ns.ModuleRegistry:GetById("id")`.

**Duplicate module id** - if two modules share an `id`, the second registration is ignored. Keep ids unique (match the folder name).

**Hardcoded strings** - store locale keys, not English text, in `title`/`description`/`label`/`description`. And do not write `L[key] or "fallback"` - a missing key already resolves to its own name.

**Not cleaning up in `OnDisable`** - reverse anything you set up in `OnEnable`.

**Accessing `ns.db` at file load** - it is not ready until after `ADDON_LOADED`. Use it inside `OnEnable` or later.

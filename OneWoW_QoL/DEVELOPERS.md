# OneWoW QoL - Module Developer Guide

OneWoW QoL is a drop-in module hub for World of Warcraft quality-of-life features. You create a self-contained folder, add your files to the TOC, and the addon handles registration, the UI, toggles, saved settings, and language switching automatically.

---

## Folder Structure

Your module lives entirely inside its own folder:

```
OneWoW_QoL/
  Modules/
    external/
      yourmodule/
        Locales/
          enUS.lua        (optional - English strings)
          koKR.lua        (optional - Korean strings)
        yourmodule.lua    (required - module table and lifecycle functions)
        logic.lua         (optional - additional logic files, as many as you need)
        ui.lua            (optional - split UI code into its own file if you prefer)
        data.lua          (required - registration call, must load last)
```

There is no file count limit. A simple module may need only two files. A complex module may need ten or twenty. Keep all files inside your module folder and list them all in the TOC. The only hard rules are that locale files load first and `data.lua` loads last.

Use the `autodelete` module as a working reference for everything described here.

---

## Step 1 - Add Your Files to the TOC

Open `OneWoW_QoL.toc` and find the `EXTERNAL MODULES` section near the bottom. List all of your files in load order - locale files first, then all your logic files in whatever order makes sense, then `data.lua` last:

```
Modules\external\yourmodule\Locales\enUS.lua
Modules\external\yourmodule\Locales\koKR.lua
Modules\external\yourmodule\yourmodule.lua
Modules\external\yourmodule\ui.lua
Modules\external\yourmodule\someotherfile.lua
Modules\external\yourmodule\data.lua
```

You can have as many files as your module needs. There is no limit. Split logic across files however works best for your code. The only ordering requirements are: locale files must load before any file that uses locale strings, and `data.lua` must be last because it calls `Register()`, which requires your module table to already exist.

If you are not supporting Korean, you can skip the `koKR.lua` line.

---

## Step 2 - Define Your Module Table (yourmodule.lua)

Your module is a Lua table that holds its metadata and lifecycle functions. The table must be defined in one file and exported to the namespace so your other files and `data.lua` can reference it. Your actual logic, UI, and helper code can live in as many additional files as you want.

```lua
local addonName, ns = ...

local YourModule = {
    id          = "yourmodule",
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
        {
            id          = "myToggle",
            label       = "MY_TOGGLE_LABEL",
            description = "MY_TOGGLE_DESC",
            default     = true,
        },
    },
}

-- Called when the module is enabled (or when the addon first loads if it is enabled)
function YourModule:OnEnable()
end

-- Called when the user disables the module
function YourModule:OnDisable()
end

-- Called when the user flips one of your toggles
-- toggleId is the id string, value is true/false
function YourModule:OnToggle(toggleId, value)
end

-- Export to the shared namespace so data.lua can find it
ns.YourModule = YourModule
```

---

## Step 3 - Register Your Module (data.lua)

`data.lua` is one line:

```lua
local addonName, ns = ...

ns.ModuleRegistry:Register(ns.YourModule)
```

That is all. The registry validates the category, assigns a fallback of `UTILITY` if the category is unknown, and handles everything else.

---

## Module Table Fields

### Required

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier. Use lowercase letters and no spaces. Must be unique across all loaded modules. |
| `title` | string | A locale key (e.g. `"MY_MODULE_TITLE"`). Displayed as the module name in the list and detail panel. |
| `category` | string | One of the six valid categories listed below. |
| `description` | string | A locale key. Shown in the detail panel below the divider. |

### Recommended

| Field | Type | Description |
|---|---|---|
| `version` | string | Version string shown in the Details dialog (e.g. `"1.0"`). |
| `toggles` | table | Array of toggle definitions. See the Toggle Fields section below. |

### Optional Contact Info

| Field | Type | Description |
|---|---|---|
| `author` | string | Your name. Shown as plain text in the Details dialog. |
| `contact` | string | Email address or Discord. Shown as a copyable text box in the Details dialog. |
| `link` | string | Website URL. Shown as a copyable text box in the Details dialog. |

If none of `author`, `contact`, or `link` are set, the `Details` button does not appear in the UI.

---

## Toggle Fields

Each entry in the `toggles` array is a table with these fields:

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique within this module. Used to read and save the value. |
| `label` | string | A locale key. Shown as the toggle name. |
| `description` | string | A locale key. Shown below the toggle row in small muted text. Optional but recommended. |
| `default` | boolean | The value used when the player has never changed this toggle. |

Toggles are automatically rendered in the detail panel. The user sees On/Off buttons for each one. You read the current value in your code using `ns.ModuleRegistry:GetToggleValue(moduleId, toggleId)`.

When the master enable/disable toggle is turned off, all sub-toggles are visually grayed out and non-interactive. They become active again when the module is re-enabled.

---

## Lifecycle Callbacks

These three functions are called automatically by the registry. Define them on your module table using the colon syntax so `self` refers to your module.

### `OnEnable()`

Called when:
- The addon loads and this module is enabled (default state)
- The user clicks Enable in the UI

This is where you register events, create frames, hook functions, or start any background logic.

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

Called when the user clicks Disable in the UI. Clean up everything you started in `OnEnable`. Unregister events, hide frames, remove hooks.

```lua
function YourModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
        self._frame:SetScript("OnEvent", nil)
    end
end
```

### `OnToggle(toggleId, value)`

Called when the user flips one of your named toggles. `toggleId` is the `id` string from your toggles array. `value` is `true` (On) or `false` (Off).

```lua
function YourModule:OnToggle(toggleId, value)
    if toggleId == "myToggle" then
        if value then
            -- user turned it on
        else
            -- user turned it off
        end
    end
end
```

---

## Categories

Choose the category that best fits your feature:

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

All text shown in the UI must go through the locale system. You do not hardcode English strings directly into your module table or UI code. Instead you store a key name, and the locale file maps keys to display strings.

### How it works

The addon maintains `ns.L_enUS` as a shared table. Every locale file adds its keys to this table. When the addon starts, `ns.ApplyLanguage()` copies `ns.L_enUS` into `ns.L`, which is the active language table used at runtime.

Because this copy happens after all files load, your module's locale file just needs to add its keys to `ns.L_enUS` and they will be available automatically.

### Locales/enUS.lua

```lua
local addonName, ns = ...
local L_enUS = ns.L_enUS

L_enUS["MY_MODULE_TITLE"]  = "My Module Name"
L_enUS["MY_MODULE_DESC"]   = "What this module does, in plain language."
L_enUS["MY_TOGGLE_LABEL"]  = "My Toggle Name"
L_enUS["MY_TOGGLE_DESC"]   = "What this toggle does when on or off."
```

### Locales/koKR.lua

```lua
local addonName, ns = ...

if GetLocale() ~= "koKR" then return end

local L_enUS = ns.L_enUS
L_enUS["MY_MODULE_TITLE"]  = "Korean translation here"
L_enUS["MY_MODULE_DESC"]   = "Korean translation here"
L_enUS["MY_TOGGLE_LABEL"]  = "Korean translation here"
L_enUS["MY_TOGGLE_DESC"]   = "Korean translation here"
```

Korean overrides write back into `ns.L_enUS` before `ApplyLanguage()` runs, so the final `ns.L` reflects the correct language.

### Using strings at runtime

```lua
-- In your module code, read the active language string like this:
local title = ns.L["MY_MODULE_TITLE"]

-- Or let the UI do it automatically - title, description, toggle label,
-- and toggle description fields are all resolved via ns.L automatically
-- by the detail panel renderer. You only need to store the key string.
```

---

## Reading Toggle Values in Your Code

You should always read toggle values through the registry rather than caching them, so you always get the current saved state:

```lua
local skipTyping = ns.ModuleRegistry:GetToggleValue("yourmodule", "myToggle")
if skipTyping then
    -- toggle is on
end
```

---

## SavedVariables

The addon uses AceDB. Your module's data is automatically available under:

```
OneWoW_QoL_DB.global.modules.yourmodule
```

The registry handles enable/disable state and toggle values in this space automatically. You do not need to read or write there directly unless you want to store additional per-module data.

If you need your own saved data, access the AceDB global table:

```lua
local addon = _G.OneWoW_QoL
local db = addon.db.global.modules["yourmodule"]
-- db.enabled and db.toggles are managed by the registry
-- you can add your own keys here
```

---

## Checking Enable State in Your Own Event Handlers

If your module registers events directly, guard the handler by checking the registry:

```lua
function YourModule:OnEnable()
    self._frame:SetScript("OnEvent", function(frame, event, ...)
        if not ns.ModuleRegistry:IsEnabled("yourmodule") then return end
        -- your logic here
    end)
end
```

---

## Complete Working Example

The `autodelete` module in `Modules/external/autodelete/` is a complete working module that you can copy as a starting point. It uses three Lua files to show how a split looks in practice:

- `autodelete.lua` - module table definition and namespace export only
- `logic.lua` - all lifecycle functions (`OnEnable`, `OnDisable`, `OnToggle`) and the event handler; opens with `local M = ns.AutoDeleteModule` to attach functions to the already-exported table
- `data.lua` - registration call, loads last

It demonstrates:

- Module table definition separated from implementation
- How `logic.lua` references the module via `ns.AutoDeleteModule` after it has been exported
- Locale files for English and Korean
- Two toggles, each with a description
- Author, contact, and link fields
- `OnEnable` registering a WoW event
- `OnDisable` cleaning up
- `OnToggle` reacting to user changes
- Reading toggle values at runtime

---

## Common Mistakes

**Wrong load order in TOC** - `data.lua` must be last. If it loads before `yourmodule.lua`, `ns.YourModule` will be nil and registration will silently fail.

**Duplicate module id** - If two modules share the same `id`, the second one is silently ignored by the registry. Keep ids unique.

**Hardcoded strings** - Do not put English text directly into `title`, `description`, `label`, or `description` fields. Always use a locale key string. The UI reads `ns.L[yourkey]` and falls back to the raw string if the key is missing, but that means your text will not translate.

**Not cleaning up in OnDisable** - If you register events or create hooks in `OnEnable`, you must reverse them in `OnDisable`. Otherwise the module keeps running even when the user disables it.

**Accessing AceDB before PLAYER_LOGIN** - The `addon.db` table is not available until after `PLAYER_LOGIN`. The registry's `OnEnable` callback is called after initialization, so accessing `addon.db` inside `OnEnable` is safe. Do not access it at file load time (module table definition time).

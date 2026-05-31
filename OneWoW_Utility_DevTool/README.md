# OneWoW - Utility: DevTool

**Developer tools for World of Warcraft addon development.** Inspect frames, debug events, monitor performance, browse globals and enums, browse textures and fonts, edit Lua snippets, and explore the game's UI structure. Part of the OneWoW Suite.

---

## Requirements

- **World of Warcraft Retail** with an interface version supported by the addon TOC (currently **120001** and **120005**; Midnight-era retail)
- **OneWoW_GUI** (required dependency)
- **!BugGrabber** (optional) — if present, DevTool can mirror captured Lua errors into the Errors tab

---

## Installation

1. Ensure **OneWoW_GUI** is installed in your AddOns folder
2. Extract the `OneWoW_Utility_DevTool` folder to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart World of Warcraft or type `/reload` in-game
4. Open the addon with `/dt` or `/1wdt`

---

## Slash Commands

| Command    | Description              |
|------------|--------------------------|
| `/dt`      | Toggle DevTool window    |
| `/devtool` | Toggle DevTool window    |
| `/devtools`| Toggle DevTool window    |
| `/1wdt`    | Toggle DevTool window    |

The addon also registers in the **Addon Compartment** (game menu) for quick access.

---

## Features

Tabs appear in this order: **Frame**, **Events**, **Errors**, **Monitor**, **Globals**, **Textures**, **Fonts**, **Sounds**, **Colors**, **Layout**, **Editor**, **Settings**. The main window is **resizable**; size and position are restored between sessions. The window **closes automatically when you enter combat** (`PLAYER_REGEN_DISABLED`).

### Frame Tab

Inspect and examine game UI frames in detail:

- **Frame Picker** — Click "Pick Frame" to visually select frames in the game world. Use **ENTER/Click** to select, **TAB** to cycle through frames under the cursor, **ESC** to cancel
- **Frame Tree** — Browse the complete frame hierarchy (parent-child structure)
- **Frame Search** — Find frames by name
- **Frame Details** — View properties: name, type, size, position, anchors, strata, level, scripts, events, and type-specific data (Texture, FontString, Button, EditBox, etc.)
- **Copy All** — Copy hierarchy or details to clipboard for use in code

Handles **secret values** (12.0+ restriction system) safely — combat-related data is masked when it cannot be read.

### Events Tab

Monitor game events in real time:

- **Start/Stop** — Begin or end event monitoring
- **Pause/Unpause** — Freeze the event log without stopping
- **Select Events** — Choose which events to monitor (common events, custom list, or all)
- **Import Events** — Import event lists from text
- **Firehose** — Monitor all events (high volume)
- **Filter** — Filter displayed events by name
- **Event arguments** — Named parameters for known events (see [warcraft.wiki.gg/wiki/Events](https://warcraft.wiki.gg/wiki/Events))

### Errors Tab (Lua / error logger)

Track and debug addon errors:

- **Error list** — Session errors with timestamps
- **Stack traces** — Full error details and stack traces
- **Copy Error** — Copy selected error to clipboard
- **Play Alert** — Optional sound on new errors
- **!BugGrabber** — When the standalone !BugGrabber addon is loaded, DevTool subscribes to its capture pipeline and shows the same errors here (with an in-tab notice). Disable !BugGrabber if you only want DevTool's own capture.

### Textures Tab

Browse atlas and texture data shipped with DevTool for the current client flavor:

- **By sheet / By atlas** — Switch between listing texture sheets and individual atlas names
- **Search** — Filter the list
- **Preview** — Zoom and pan sheet views; pick cells on multi-atlas sheets
- **Bookmarks** — Favorite atlases (stored in SavedVariables)
- **Copy helpers** — Copy atlas/texture names, snippets, and coordinates for paste into addon code

Atlas catalog files are selected by game type via the addon TOC (e.g. mainline vs mainline-test); ensure your installed DevTool build matches how you launch the game.

### Fonts Tab

Explore **FrameXML font objects** and how they render:

- **Searchable list** — Virtualized list of font object names
- **Live preview** — Sample text with adjustable preview background color (saved when changed)
- **Widget size presets** — Preview fonts in common UI control heights
- **Bookmarks** — Mark favorite font objects
- **Copy helpers** — Copy names and usage-oriented snippets

### Colors Tab

Utilities for working with colors:

- **Custom Color Picker** — RGB sliders (0–255) with preview
- **Color code** — Copy hex color codes for use in code
- **Class Colors** — Browse and copy `RAID_CLASS_COLORS` values
- **Common Colors** — Quick access to common hex colors

### Layout Tab

Layout and alignment aids:

- **Grid Overlay** — Toggle a configurable grid over the screen
- **Grid Size** — Adjust grid spacing (10–200 px)
- **Opacity** — Adjust grid line opacity
- **Center Lines** — Toggle horizontal and vertical center lines

### Monitor Tab

Real-time addon performance monitoring:

- **Memory** — Per-addon memory usage (kB)
- **CPU** — Per-addon cumulative script CPU (requires `scriptProfile` CVar; toggling triggers UI reload). Distinct from AddOn profiler metrics below.
- **C_AddOnProfiler** — Optional columns from `C_AddOnProfiler.GetAddOnMetric` / `Enum.AddOnProfilerMetric` (session average, recent 60-tick average, peak, tick counts over ms thresholds, weighted spike score). Does not require `scriptProfile`. Values reset on UI reload, not on Monitor Reset. See [warcraft.wiki.gg — System: AddOnProfiler](https://warcraft.wiki.gg/wiki/Category:API_systems/AddOnProfiler) and Blizzard `AddOnProfilerDocumentation.lua` / `AddOnProfilerConstantsDocumentation.lua` in [wow-ui-source](https://github.com/Gethe/wow-ui-source).
- **Views** — Balanced, Memory dig, CPU spikes (adds profiler peak / >50ms / spike score when the engine profiler is available; default sort follows script CPU or spike score), Minimal, and **Engine profiler** (full threshold grid). Encounter-average metric is intentionally not shown (boss-encounter scoped).
- **Play/Pause** — Continuous or manual updates
- **Show on Load** — Option to open Monitor tab automatically on login
- **Filter** — Filter addons by name
- **Pinned addon** — Optional focus window for a single addon (memory, optional script CPU, optional AddOn profiler summary; position and reopen behavior are saved)

### Globals Tab

Browse and inspect the Lua global environment, `Enum` tables, and addon data tables:

- **Category filter** — Switch between All, Globals, Enum, and Addon Data to narrow the root list
- **Search** — Filter root entries by name, reference, type, or addon owner
- **Noisy roots** — Toggle inclusion of normally hidden globals (C_* namespaces, widget frames, mixin-style tables)
- **Bookmarks** — Favorite root entries for quick access; filter the list to bookmarks only
- **Refresh** — Rebuild the index to pick up globals created since the last scan
- **Value tree** — Expandable tree view of the selected entry's contents with lazy child loading, circular reference detection, and depth limits
- **Tree search** — Filter the value tree to matching keys, values, or references; matching subtrees auto-expand
- **Navigation** — Up (parent node) and Home (back to root) buttons; Expand All / Collapse All for the tree
- **Copy helpers** — Copy the Lua reference path or the serialized value of the selected root or tree node to clipboard; right-click any tree node to copy its reference
- **Secret values** — Secret values and secret tables (12.0+ restriction system) are safely masked throughout

The left pane (root list) is resizable and its width is persisted between sessions.

### Editor Tab

In-game **Lua snippet workspace** for experiments and small scripts:

- **Snippets** — Create, rename, duplicate, save, and delete snippets; organize with categories
- **Syntax coloring** — WoW-oriented Lua highlighting and periodic syntax checks
- **Find / replace** — Plain-text find with optional replace
- **Undo / redo** — Per-snippet history (keyboard shortcuts shown in the tab tooltip)
- **Run** — Executes the current snippet with `loadstring` in the normal addon environment; `print` output goes to the output panel below the editor
- **Autosave** — Optional interval (minutes) for saving the active snippet

**Security note:** Run executes arbitrary Lua with the same power as other addon code. Only run snippets you understand. This is a developer tool, not a sandbox.

### Settings Tab

- **Theme** — Color theme selection (applies instantly)
- **Language** — UI language (English, Korean, Spanish, French, Russian, German)
- **Minimap** — Show/hide minimap button, icon theme (Horde/Alliance/Neutral)

---

## Localization

| Locale | Language |
|--------|----------|
| enUS   | English  |
| deDE   | German   |
| esES   | Spanish  |
| frFR   | French   |
| koKR   | Korean   |
| ruRU   | Russian  |

---

## Who Should Use This

- **Addon developers** — Debug and develop addons with frame inspection, snippets, and error logging
- **UI modders** — Inspect the game's UI structure and reference textures, fonts, and colors
- **Troubleshooters** — Diagnose addon conflicts and errors
- **Testers** — Monitor events and performance during QA

---

## Technical Notes

- **Secret values** — Frame properties that return secret values (e.g., in instanced content) are safely masked
- **SavedVariables** — `OneWoW_UtilityDevTool_DB` stores window position, theme, language, minimap, monitor (including pinned addon), error logger settings, globals browser bookmarks and pane width, texture bookmarks and list column width, font preview background and bookmarks, editor snippets and layout options, and related UI preferences
- **Clipboard** — Copy actions use the embedded **LibCopyPaste** library where applicable
- **Embedded libraries** — LibStub, LibCopyPaste (vendored under `Libs/`; do not modify vendored libs when contributing)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for translation and code contribution guidelines.

---

## Support

- **Website:** https://wow2.xyz/
- **Report issues:** Through Discord community or website

---

**Authors:** OneWoW Dev Team (ricky, kellewic)  
**Part of the OneWoW Suite**

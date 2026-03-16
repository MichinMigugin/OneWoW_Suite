# OneWoW - Utility: DevTool

**Developer tools for World of Warcraft addon development.** Inspect frames, debug events, monitor performance, and explore the game's UI structure. Part of the OneWoW Suite.

---

## Requirements

- **World of Warcraft Retail 12.0+** (Midnight)
- **OneWoW_GUI** (required dependency)

---

## Installation

1. Ensure **OneWoW_GUI** is installed in your AddOns folder
2. Extract the `OneWoW_Utility_DevTool` folder to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart World of Warcraft or type `/reload` in-game
4. Open the addon with `/dt` or `/1wdt`

---

## Slash Commands

| Command   | Description              |
|-----------|--------------------------|
| `/dt`     | Toggle DevTool window    |
| `/devtool`| Toggle DevTool window    |
| `/devtools`| Toggle DevTool window   |
| `/1wdt`   | Toggle DevTool window    |

The addon also registers in the **Addon Compartment** (game menu) for quick access.

---

## Features

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

### Lua Tab (Error Logger)

Track and debug addon errors:

- **Error list** — Session errors with timestamps
- **Stack traces** — Full error details and stack traces
- **Copy Error** — Copy selected error to clipboard
- **Play Alert** — Optional sound on new errors

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
- **CPU** — Per-addon CPU usage (requires `scriptProfile` CVar; triggers UI reload)
- **Play/Pause** — Continuous or manual updates
- **Show on Load** — Option to open Monitor tab automatically on login
- **Filter** — Filter addons by name

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

- **Addon developers** — Debug and develop addons with frame inspection and error logging
- **UI modders** — Inspect and understand the game's UI structure
- **Troubleshooters** — Diagnose addon conflicts and errors
- **Testers** — Monitor events and performance during QA

---

## Technical Notes

- **Secret values** — Frame properties that return secret values (e.g., in instanced content) are safely masked
- **SavedVariables** — `OneWoW_UtilityDevTool_DB` stores position, theme, language, minimap, monitor, and error settings
- **Textures tab** — Currently disabled in the UI

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for translation and code contribution guidelines.

---

## Support

- **Website:** https://wow2.xyz/
- **Report issues:** Through Discord community or website

---

**Author:** MichinMuggin / Ricky  
**Part of the OneWoW Suite**

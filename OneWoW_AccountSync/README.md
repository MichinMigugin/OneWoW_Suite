# OneWoW Account Sync

Keep OneWoW addon data in sync across multiple WoW Battle.net accounts.

Built with [Go](https://go.dev/) + [Fyne](https://fyne.io/) for cross-platform support (Windows & macOS).

## What It Does

WoW stores addon SavedVariables per Battle.net account (`WTF/Account/<NAME>/SavedVariables/`). If you run multiple Battle.net accounts, each has its own separate copy of character data, settings, and tracking information. This tool synchronises those files so every account sees the same data.

## Sync Modes

**Merge** — Deep-merges Lua tables across all selected accounts. Character data from Account A is combined with character data from Account B, and the merged result is written to both. The "primary" account's scalar values (settings, preferences) win on conflict.

**Copy** — Copies SavedVariables from the primary account to all other selected accounts. Simple overwrite; best for settings-only addons.

## Safety

- Automatic backups before every sync (stored in `~/.onewow_sync/backups/`)
- Backups can be restored from the Restore dialog
- Old backups are automatically pruned (keeps the 20 most recent)
- Warns if WoW is running (syncing while WoW is open can cause data loss)

## Download

Grab the latest `OneWoW_AccountSync.exe` (Windows) or `OneWoW_AccountSync.app` (macOS) from the Releases page. No installation needed — just run it.

## Building From Source

Requires [Go 1.21+](https://go.dev/dl/) and a C compiler (GCC/MinGW on Windows, Xcode CLI tools on macOS).

```bash
# Windows
go build -ldflags="-H windowsgui" -o OneWoW_AccountSync.exe .

# macOS
go build -o OneWoW_AccountSync .
```

### Cross-platform builds with fyne-cross (via Docker)

```bash
go install github.com/fyne-io/fyne-cross@latest
fyne-cross windows -icon icon.png
fyne-cross darwin -icon icon.png
```

## Usage

1. Launch the app — it auto-detects your WoW installation
2. Select a game version (`_retail_`, `_classic_`, etc.)
3. Check the accounts you want to sync
4. Pick a primary account (its settings take precedence)
5. Check which SavedVariables files to include
6. Choose Merge or Copy mode
7. Click **Sync Now**

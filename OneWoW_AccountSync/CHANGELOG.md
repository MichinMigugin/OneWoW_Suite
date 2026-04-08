# Changelog — OneWoW Account Sync

All notable changes to this application are documented here. The **Discord announcement** block below uses the OneWoW dev-log format (copy-paste as-is).

---

## [B6.2604.0900] — 2026-04-09

### Added

- **Desktop app** (Go + Fyne) for **Windows** and **macOS**: sync WoW SavedVariables across multiple Battle.net accounts on the same machine.
- **Global Local WoW bar**: one install path + **game version** (`_retail_`, `_classic_`, etc.) shared by **Account Sync**, **Remote Source** (local target), **Utilities**, and **Characters**.
- **Account Sync**: multi-account selection, primary account, per-file checkboxes, **Smart Merge** (per-addon strategies in code) vs **Copy** (primary overwrites targets), filters (**Suggested OneWoW merges** / **All OneWoW** / **All addons**), backups before writes, backup/restore browser, WoW-running warning.
- **Remote Source**: second path for another WoW root, UNC share, direct **SavedVariables** folder, or **HTTPS URL** to a `.lua` file; remote **version** + **account** when the source is a full install; merge into chosen **local** account.
- **Utilities**: submit **CatalogData** SavedVariables (Vendors, Quests, Tradeskills) via HTTPS multipart upload to configured endpoint for community static data (optional).
- **Characters**: load **OneWoW_AltTracker_Character** roster from disk; detail panel; placeholder for future **wow2.xyz** upload.
- **Lua pipeline**: parse/serialize SavedVariables with ordered tables; merge strategies for character maps, accounting transactions (concat + dedupe + stats), primary-wins settings, etc.
- **Branding**: embedded icon; Windows `.syso` icon resource where applicable; **Classic Gold**–style Fyne theme aligned with OneWoW GUI.

### Notes

- Third-party antivirus may block Go build output; users may need to exclude the project folder or build with AV relaxed.
- **wow2.xyz** catalog submit and character APIs are placeholders until the live endpoints accept traffic.

---

## Discord announcement (copy-paste)

```
🟢 OneWoW Account Sync · B6.2604.0900

✨ What It Is
✓ Desktop app for Windows and Mac that syncs your WoW addon SavedVariables across multiple Battle.net accounts on the same PC
✓ Picks up Retail, Classic, and other official game folders WoW uses (like _retail_ and _classic_)

📂 Local WoW (One Place for Everyone)
✓ Set your WoW install and game version once at the top—every tab uses the same local setup

🔄 Account Sync
✓ Choose accounts, pick SavedVariables files, and sync with Smart Merge (safe, per-addon logic) or plain Copy from a primary account
✓ Starts with OneWoW-suggested merges; you can show all OneWoW files or every addon if you accept the risk
✓ Backups before changes, plus backup and restore tools
✓ Warns you if WoW is running so you do not lose data on logout

🌐 Remote Source
✓ Merge from another WoW folder, a network share, a SavedVariables folder, or a direct link to a .lua file
✓ For a full remote install, choose remote game version and account, then merge into the local account you pick

🛠 OneWoW Utilities
✓ Optionally upload CatalogData files (vendors, quests, tradeskills) to help the community—only those files, over HTTPS

👤 Characters
✓ Browse your Alt Tracker character data from disk
✓ More detailed web views via wow2.xyz—coming soon

🎨 Look & Feel
✓ OneWoW shield icon and Classic Gold styling to match the in-game addon suite
```

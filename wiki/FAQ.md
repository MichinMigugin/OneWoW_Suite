Common questions about installing and using OneWoW. More entries will land here as they come up in community support.

## Install and folders

### Do I need every `OneWoW_*` folder?

No. Install **OneWoW** (required) plus the optional features you want. See [Install](Install).

### Catalog or AltTracker looks empty

Those features need their companion data folders (`OneWoW_CatalogData_*` / `OneWoW_AltTracker_*`) present and enabled. Enable the parent feature in **Manage Features**; companions load with it. See [Catalog](Catalog) and [AltTracker](AltTracker).

### Where do I get the package?

CurseForge or the Discord community bot zip — same layout either way. Site: [https://onewow.net/](https://onewow.net/).

## Manage Features

### I disabled a module but it still feels “there”

Disabling in **Manage Features** **unloads** the addon — it is not just hidden. If something still appears, confirm the folder is not force-enabled only in the character-select AddOns list, then `/reload`.

### Can I use Shopping List without AltTracker?

Yes. Enable Shopping List in Manage Features; Storage can load for alt/bank scanning even when the AltTracker hub is off. See [Shopping List](Shopping-List).

## Search and keywords

### Why don’t localized `#` keywords from another addon work?

OneWoW keywords are **English-only** (`#epic`, `#armor`, …). Import foreign category dialects through Bags **Import from…** so they convert. See [Search syntax](Bags-Search-Syntax).

### Slash commands do nothing

The feature must be **installed and enabled**. Open [Slash commands](Slash-Commands) for the list, then check Manage Features.

## Conflicts and help

### Bags vs default bags / other bag addons

Enable only one primary bag UI you intend to use, or expect overlapping keybinds and frames. OneWoW Bags opens with `/1wbags` (see [Bags](Bags)).

### Where do I get help?

[https://onewow.net/support/](https://onewow.net/support/) lists every channel: this site's docs, email, Discord, CurseForge comments, and GitHub issues. Pick one. Prefer those over editing the GitHub wiki UI.

## Related

* [Install](Install)
* [Getting started](Getting-Started)
* [Slash commands](Slash-Commands)

### Sources

* [README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/README.md)
* [OneWoW/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/README.md)
* Feature READMEs linked from each wiki feature page

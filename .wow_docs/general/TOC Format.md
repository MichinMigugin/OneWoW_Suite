# TOC format

`.toc` files contain information about the addon (e.g. addon name, addon description, addon saved variables). They also specify the loading order for the addon's `.lua` and `.xml` files. A `.toc` file is mandatory for an addon. The filename of the `.toc` file must match the folder it's inside, otherwise the `.toc` file won't load.

## Rules

The `.toc` file and folder name must match. For example `..\Interface\AddOns\MyAddon\MyAddon.toc`

The `.toc` file can optionally have the following elements:

- Metadata as `## Directive: Value`
- Comments as `# this is a comment`
- A list of files as `myFile.xml` or `subfolder\myFile.lua`

Whitespace before `#` will be interpreted as the start of a filename. However, the client trims whitespace around metadata values (after the colon).

Backslashes `\` are recommended instead of forward slashes for paths to prevent issues with `<[Include](https://warcraft.wiki.gg/wiki/XML/Include "XML/Include")>` tags.

Example `.toc` file:

```
## Interface: 120000
## Title: MyAddon
## Notes: Short description
## Author: YourName
## Version: 1.0.0
## SavedVariables: MyAddonDB
## Dependencies: SomeRequiredAddon
## OptionalDeps: Ace3
## Group: OneWoW

# Load order matters — libraries first, then core, then modules
libs\LibStub\LibStub.lua
libs\AceAddon-3.0\AceAddon-3.0.lua
libs\AceDB-3.0\AceDB-3.0.lua

Core.lua
Modules\SomeModule.lua
```

## File loading order

The `.toc` file includes a list of files to be loaded. The files are loaded in order, from top to bottom.

Not every file in your addon must appear in the `.toc` file. This is because `.xml` files can load files using `<[Script](https://warcraft.wiki.gg/wiki/XML/Script "XML/Script") file="AnotherFile.lua" />` or `<[Include](https://warcraft.wiki.gg/wiki/XML/Include "XML/Include") file="alsoLoadThis.xml" />`. Also, functions such as `[Texture:SetTexture](https://warcraft.wiki.gg/wiki/API_Texture_SetTexture "API Texture SetTexture")()` and `[PlaySoundFile](https://warcraft.wiki.gg/wiki/API_PlaySoundFile "API PlaySoundFile")()` can specify image files and sound files contained within the addon folder and subfolders.

## Interface version

"Interface" is the WoW version the addon was made for. WoW uses this number to tell if an addon is out of date.

If an addon has an older interface version than the user's current WoW client version, the addon is classified as out of date. If you don't specify an Interface version, WoW will always treat the addon as out of date.

If the game version is 10.2.7, then the interface version is 100207:

```
## Interface: 100207
```

For addons that support multiple client flavors with one TOC file, multiple interface versions can be specified delimited by commas:

```
## Interface: 120005, 50503, 38001, 20505, 11508
```

### Determining the interface version

```
select(4, GetBuildInfo())
```

## Game types

| Value                   | Game type     | Interface |
| ----------------------- | ------------- | --------- |
| `mainline` (default)    | Mainline      | 120005    |
| `mainline-test`, `test` | Mainline Test | 120007    |
| `mainline-beta`, `beta` | Mainline Beta | 120001    |
| `midnight`              | Midnight      | 120005    |
| `midnight-test`         | Midnight Test | 120007    |
| `midnight-beta`         | Midnight Beta | 120001    |
## CDNs & directories

|CDN value|Directory value|Name|Interface|
|---|---|---|---|
|`wow`|`_retail_`|Retail|120005|
|`wowt`|`_ptr_`|Retail PTR|120005|
|`wowxptr`|`_xptr_`|Retail PTR 2|120007|
|`wow_beta`|`_beta_`|Retail Beta|120001|
## Per-line conditional directives

TOC files support the use of conditional directives for metadata directive and file reference lines. Conditions take the form [Directive value...]. The following conditions are supported:

|Condition|Description|Client version|
|---|---|---|
|[AllowLoad ...]|Restricts the metadata or file to in-game or glue screen environments. Functionally inoperable for addons, as only Blizzard code works in the glue screen environment.||
|[AllowLoadGameType ...]|Restricts the metadata or file to specific game types. Multiple game types are supported, delimited by commas, with the same values used by the AllowLoadGameType directive.|Added for files in 11.1.5. Added for metadata in 12.0.7.|
|[AllowLoadTextLocale ...]|Restricts a metadata or file to specific client text locales. Multiple locale names are supported, delimited by commas, using the same four letter locale names as returned by [GetLocale](https://warcraft.wiki.gg/wiki/API_GetLocale "API GetLocale"), eg. "enUS" and "frFR".|Added for files in 11.2.0.61787. Added for metadata in 12.0.7.|

Conditions can appear anywhere in a file reference line, but for reasons of compatibility should generally only ever be used at the end of a line as follows.

```
## Interface: 120005
## Title: My Cool Addon

# This will only be loaded on Mainline.
MainlineOnly.lua [AllowLoadGameType mainline]

# This will only be loaded in Vanilla or TBC.
VanillaOrTBC.lua [AllowLoadGameType vanilla, tbc]

# This will only be loaded under English or French client locales.
EnglishOrFrenchOnly [AllowLoadTextLocale enUS, frFR]
```

## Per-file variables

TOC files support the use of variable expansions within file references. Variables of the form `[Variable]` can be used within file references. The following variables are currently supported by the client.

|Variable|Description|Client version|
|---|---|---|
|[Family]|Expands out to either Mainline or Classic based upon the current active game type.|Added in 11.1.5|
|[Game]|Expands out to either Standard, Vanilla, TBC, Wrath, Cata, Mists, WoWLabs, or WoWHack based upon the current active game type.|Added in 11.1.5|
|[TextLocale]|Expands out to either enUS, deDE, frFR, etc. based upon the configured text locale of the game client.|Added in 11.2.0.61787|
```
## Interface: 120005
## Title: My Cool Addon

# This will load "Mainline\File.lua" or "Classic\File.lua"
# as appropriate for the current client.
[Family]\File.lua

# This will load "Standard\File.lua", "Mists\File.lua", "Cata\File.lua", ...
# as appropriate for the current client.
[Game]\File.lua

# This will load "Localization\enUS.lua", "Localization\frFR.lua", ...
# as appropriate for the current client text locale.
Localization\[TextLocale].lua
```

## Client-specific TOC files

Addons can ship multiple `.toc` files with different filename suffixes tailored for individual clients. The WoW client first searches for the special file names as shown below, and if none are found, uses `AddonName.toc`. Note that comma-delimited interface versions or per-file conditional loading directives should be preferred over the use of client-specific TOC files where possible.

| Game Type  |                                                                                                                                                   | Suffix                   |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `standard` | [Midnight](https://warcraft.wiki.gg/wiki/Midnight "Midnight") excluding [Plunderstorm](https://warcraft.wiki.gg/wiki/Plunderstorm "Plunderstorm") | `AddonName_Standard.toc` |
| `mists`    | [Mists of Pandaria Classic](https://warcraft.wiki.gg/wiki/Mists_of_Pandaria_Classic "Mists of Pandaria Classic")                                  | `AddonName_Mists.toc`    |
| `cata`     | [Cataclysm Classic](https://warcraft.wiki.gg/wiki/Cataclysm_Classic "Cataclysm Classic")                                                          | `AddonName_Cata.toc`     |
- Clients also recognize legacy suffixes `-WOTLKC` and `-BCC`.
- The `_Mainline` and `_Classic` suffixes have a lower priority than other suffixes that target specific expasions/modes. For example, having both a `_Cata.toc` and `_Classic.toc` file will result in the former being used on Cataclysm Classic clients, and the latter in all other Classic clients.

## AddOns list formatting

The following directives change how an AddOn appears in the AddOns list. Both may be colored using UI escape sequences (e.g. `|c########|r`), or [localized](https://warcraft.wiki.gg/wiki/Localization "Localization") by appending a hyphen and the locale code (e.g.`Title-enGB`). Later entries overwrite earlier ones, so the non-localized fallback should go first.

### Title

Name displayed in the AddOns list.

```
## Title: Waiting for Godot
## Title-frFR: En attendant Godot
```

### Notes

Tooltip displayed in the AddOns list.

```
## Notes: This word is |cFFFF0000red|r
```

### Category

Category name displayed in the AddOns list, displayed as a collapsible header entry.

It is **strongly recommended** that you stick to the translated category names found on the [Addon Categories](https://warcraft.wiki.gg/wiki/Addon_Categories "Addon Categories") page. This will ensure that your addon is consistently located with other addons in the same category across all locales.

```
## Category: This is a test
## Category-deDE: Dies ist ein Test
```

### Group

Addon used for grouping entries together in the AddOns list.

- The Group value must be the name of the main addon.
- Grouped addons are displayed in the addon list as indented sub-lists. These lists cannot be collapsed, unlike Categories.
    - Nested groups are not supported by the addon list.
- If no Group has been manually specified, the client will attempt to automatically deduce membership of a group.
    - Installed addons will be scanned to locate pairs of addons where the base name of one addon is a complete prefix of another, and where any form of dependency relation exists between the two in either direction.

```
## Group: FooAuras
```

### IconTexture

Path to a texture file to be shown as the icon for this addon in the addon list. Optional.

```
## IconTexture: Interface\Icons\TEMP
```

### IconAtlas

Name of a texture atlas to be shown as the icon for this addon in the addon list. Optional, and has a lower priority than IconTexture if both are set.

```
## IconAtlas: TaskPOI-Icon
```

## Addon compartment integration

The following directives will control the registration of the addon into the [Addon compartment](https://warcraft.wiki.gg/wiki/Addon_compartment "Addon compartment") dropdown accessible from the minimap.

### AddonCompartmentFunc

Name of a global function to be executed when the dropdown list button for this addon has been clicked. This field is required to have the addon be shown in the Addon Compartment list.

```
## AddonCompartmentFunc: MyAddon_OnAddonCompartmentClick
```

### AddonCompartmentFuncOnEnter

Name of a global function to be executed when this dropdown list button for this addon has been highlighted. Optional.

```
## AddonCompartmentFuncOnEnter: MyAddon_OnAddonCompartmentEnter
```

### AddonCompartmentFuncOnLeave

Name of a global function to be executed when this dropdown list button for this addon is no longer highlighted. Optional.

```
## AddonCompartmentFuncOnLeave: MyAddon_OnAddonCompartmentLeave
```

## Loading conditions

The following directives control when an AddOn loads, and any dependencies that must or may load first.

### LoadOnDemand

`1` to delay loading until [LoadAddOn](https://warcraft.wiki.gg/wiki/API_LoadAddOn "API LoadAddOn")().

```
## LoadOnDemand: 1
```

### Dependencies

AddOns that must load first. Aliases include `RequiredDeps` and any word beginning with `Dep`.

```
## Dependencies: someAddOn, someOtherAddOn
```

### OptionalDeps

AddOns that should load first if available.

```
## OptionalDeps: someAddOn, someOtherAddOn
```

### LoadWith

AddOns that, once loaded, trigger this one to load. Implies _LoadOnDemand_.

```
## LoadWith: someAddOn, someOtherAddOn
```

### LoadManagers

AddOns that, if present, trigger this one to behave as _LoadOnDemand_. See [AddonLoader](https://warcraft.wiki.gg/wiki/AddonLoader "AddonLoader") for an example.

```
## LoadManagers: someAddOn, someOtherAddOn
```

### AllowLoadGameType

Restricts loading this addon to specific client flavors. Multiple values may be supplied, delimited by commas. Note that game modes may be restricted to disallow loading of insecure addons.

| Game Type      |                                                                                                                                                                                                                                                                       |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `standard`     | [Midnight](https://warcraft.wiki.gg/wiki/Midnight "Midnight") excluding [Plunderstorm](https://warcraft.wiki.gg/wiki/Plunderstorm "Plunderstorm")                                                                                                                     |
| `mists`        | [Mists of Pandaria Classic](https://warcraft.wiki.gg/wiki/Mists_of_Pandaria_Classic "Mists of Pandaria Classic")                                                                                                                                                      |
| `cata`         | [Cataclysm Classic](https://warcraft.wiki.gg/wiki/Cataclysm_Classic "Cataclysm Classic")                                                                                                                                                                              |
| `wrath`        | [Wrath of the Lich King Classic](https://warcraft.wiki.gg/wiki/Wrath_of_the_Lich_King_Classic "Wrath of the Lich King Classic") and [Titan Reforged](https://warcraft.wiki.gg/wiki/Titan_Reforged "Titan Reforged")                                                   |
| `tbc`          | Burning Crusade [Classic](https://warcraft.wiki.gg/wiki/Burning_Crusade_Classic "Burning Crusade Classic") and [Classic Anniversary Edition](https://warcraft.wiki.gg/wiki/Burning_Crusade_Classic_Anniversary_Edition "Burning Crusade Classic Anniversary Edition") |
| `vanilla`      | [World of Warcraft Classic](https://warcraft.wiki.gg/wiki/World_of_Warcraft_Classic "World of Warcraft Classic")                                                                                                                                                      |
| `plunderstorm` | [Plunderstorm](https://warcraft.wiki.gg/wiki/Plunderstorm "Plunderstorm")                                                                                                                                                                                             |
| `wowhack`      | Unknown                                                                                                                                                                                                                                                               |
| `mainline`     | [Midnight](https://warcraft.wiki.gg/wiki/Midnight "Midnight") including [Plunderstorm](https://warcraft.wiki.gg/wiki/Plunderstorm "Plunderstorm") and the unknown mode                                                                                                |
| `classic`      | All [Classic](https://warcraft.wiki.gg/wiki/Classic "Classic") expansions                                                                                                                                                                                             |
### OnlyBetaAndPTR

`1` if an addon should only be loadable in Beta or PTR clients.

```
## OnlyBetaAndPTR: 1
```

### DefaultState

`disabled` to require the user to explicitly enable the AddOn in the AddOns list.

```
## DefaultState: disabled
```

## Saved variables

An addon may need to save settings and data between game sessions - that is, some information may need to persist through a user log out. To enable this, the addons may specify a number of variables to be saved to disk when the player's character logs out of the game, and restored when the character logs back in. Variables that are saved and restored by the client are called SavedVariables.

**Summary:** to save a global variable `FOOBAR`, add `##SavedVariables: FOOBAR` or `##SavedVariablesPerCharacter: FOOBAR` to an addon's .toc file.

To tell the WoW client that you want a variable to persist through log out, you need to add it to your addon's .toc file. There are two directives you may add to your .toc file, both should be followed by a colon and a comma-delimited list of variable names in the global environment (for most addons, this means variables that haven't been defined using the **local** keyword) that the addon wants to persist.

`##SavedVariables` - variables listed after this directive are saved on a per-account basis: if any of the characters on that account logs in, those variables will be restored. This may be more useful for global addon settings, or addons that implement profiles one can freely switch between.

`##SavedVariablesPerCharacter` - variables listed after this directive are saved on a per-character basis: a separate copy of the variable is stored and restored for each character. This may be more useful for simple per-character options or history data.

The variables saved by those directives are not immediately available when your addon loads; instead, they're loaded at a later point. The client fires events to let addons know that their saved variables were loaded.

1. WoW FrameXML code is loaded and executed.
2. Addon code is loaded and executed.
3. Saved variables for one addon a time are loaded and executed, then [ADDON_LOADED](https://warcraft.wiki.gg/wiki/ADDON_LOADED "ADDON LOADED") event is fired for that addon.
4. [PLAYER_LOGIN](https://warcraft.wiki.gg/wiki/PLAYER_LOGIN "PLAYER LOGIN") fires once all non-load-on-demand addons have been loaded and the player is completely logged into the game.

Addons should generally use `ADDON_LOADED` to initialize their saved variables; the first argument of the event is the name of the addon for which it is being fired.

The client automatically writes the values of the the variables you list in your .toc file to disk when you log out, disconnect, quit the game, or reload your user interface (`/reload`).

If an addon needs to make last-minute changes before the variables are saved, use the [PLAYER_LOGOUT](https://warcraft.wiki.gg/wiki/PLAYER_LOGOUT "PLAYER LOGOUT") event: it fires just before the character logs out, and is the last event before your saved variables are written to disk.

To illustrate the concepts, let's consider a simple addon, HaveWeMet, shown below. The greets your characters when you log on: if it's seen you log into that character before, it outputs "Hello again, `<Character Name>`", and it if has not, it outputs "Hi; what is your name?" to the chat frame. When its slash command, **/hwm**, is used, it tells the player how many characters it has met before.

There are two pieces of information that need to persist between sessions: the number of characters the addon has met, and whether it has met any particular character. To save the count, a global variable, `HaveWeMetCount` is used (and saved on a per-account basis through `#SavedVariables`); while `HaveWeMetLastSeen` is saved per-character and used to determine whether the addon has seen _this_ character before. When the addon is loaded for the first time, the `HaveWeMetCount` variable will be `nil` after [ADDON_LOADED](https://warcraft.wiki.gg/wiki/ADDON_LOADED "ADDON LOADED") (assuming no other addon overwrites the global); similarly, when a character previously unknown to the addon is encountered, `HaveWeMetLastSeen` will be `nil`.

**HaveWeMet\HaveWeMet.toc**

```
## Interface: 120005
## Title: Have We Met?
## SavedVariables: HaveWeMetCount
## SavedVariablesPerCharacter: HaveWeMetLastSeen
HaveWeMet.lua
```

**HaveWeMet\HaveWeMet.lua**

```
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "HaveWeMet" then
        -- Our saved variables, if they exist, have been loaded at this point.
        if HaveWeMetCount == nil then
            -- This is the first time this addon is loaded; set SVs to default values
            HaveWeMetCount = 0
        end

        if HaveWeMetLastSeen == nil then
            -- Haven't yet seen this character, so increment the number of characters met
            HaveWeMetCount = HaveWeMetCount + 1
            print("Hi; what is your name?")
        else
            local name, elapsed = UnitName("player"), time() - HaveWeMetLastSeen
            print("Hello again, " .. name .. "; you've been gone for " .. SecondsToTime(elapsed))
        end

    elseif event == "PLAYER_LOGOUT" then
            -- Save the time at which the character logs out
            HaveWeMetLastSeen = time()
    end
end)

SLASH_HAVEWEMET1 = "/hwm"
function SlashCmdList.HAVEWEMET(msg)
    print("HaveWeMet has met " .. HaveWeMetCount .. " of your characters.")
end
```

There are a few common issues beginners may experience:

**Saved variables are loaded after the addon code is executed** - they cannot be accessed immediately, and will overwrite any "defaults" the addon may place in the global environment during its loading process.

**Only some variable types may be saved** - strings, booleans, numbers and tables are the only variable types that will be saved (functions, userdata and coroutines will not). Circular references in tables may not be preserved.

**Saving tables** - tables are a _great_ way to avoid having to use a large number of names in the global namespace. However, they may be more difficult to initialize to default values when your addon is updated and you add or remove a key. Multiple saved variables that reference the same table will each create a separate (but identical) instance of the table, and as such will no longer point to the same table when they are loaded again.

**Variables are saved and loaded in the _global_ environment** - if you want to save a local value, you have to first read it from the global environment (`_G` table) on ADDON_LOADED, then return it into the global environment before the player logs out.

Saved variables are stored on a per-account basis in three file classes:

- `WTF\Account\ACCOUNTNAME\SavedVariables.lua` - Blizzard's saved variables.
- `WTF\Account\ACCOUNTNAME\SavedVariables\AddOnName.lua` - Per-account settings for each individual AddOn.
- `WTF\Account\ACCOUNTNAME\RealmName\CharacterName\SavedVariables\AddOnName.lua` - Per-character settings for each individual AddOn.

Deleting or renaming the WTF folder will reset the settings of all of your addons.

### LoadSavedVariablesFirst

`1` if SavedVariables file(s) should be loaded before all script files for this addon.

### SavedVariables

Variables saved in `WTF/[account]/SavedVariables`.

```
## SavedVariables: MyAddOnNameFoo, MyAddOnNameBar
```

### SavedVariablesPerCharacter

Variables saved in `WTF/[account]/[server]/[character]/SavedVariables`.

```
## SavedVariablesPerCharacter: MyAddOnNameAnotherVariable
```

## Informational

The following metadata may be accessed using [GetAddOnMetadata](https://warcraft.wiki.gg/wiki/API_GetAddOnMetadata "API GetAddOnMetadata")():

- **Author**: The AddOn author's name, displayed
- **Version**: The AddOn version. Some automatic updating tools may prefer that this string begins with a numeric version number.
- **`X-_____`**: Any custom metadata prefixed by "X-", such as "X-Date", "X-Website" or "X-Feedback"

## Uncategorized

### AllowAddOnTableAccess

`1` to allow the retrieval of the [namespace table](https://warcraft.wiki.gg/wiki/Using_the_AddOn_namespace "Using the AddOn namespace") of this addon via [C_AddOns.GetAddOnLocalTable](https://warcraft.wiki.gg/wiki/API_C_AddOns.GetAddOnLocalTable "API C AddOns.GetAddOnLocalTable").

```
## AllowAddOnTableAccess: 1
```

## Restricted

The following tags are inaccessible to third-party AddOns.

### AllowLoad

Restricts loading this addon to either the [GlueXML](https://warcraft.wiki.gg/wiki/API_IsOnGlueScreen "API IsOnGlueScreen") or [FrameXML](https://warcraft.wiki.gg/wiki/FrameXML "FrameXML") environments.

|Value|Environment|
|---|---|
|`Both`|Allow this addon to load without restriction in all environments.|
|`Game`|Only load this addon in the FrameXML environment.|
|`Glue`|Only load this addon in the GlueXML environment.|
### EscalateErrorDuringLoad

Boolean directive that appears to have no effect in public clients.

### LoadFirst

`1` if a secure addon is not permitted to be disabled and should be loaded before any other addons without this flag.

### SavedVariablesMachine

List of global variable names to be persisted across all accounts on the same machine.

### UseSecureEnvironment

`1` if all files present in an addon should be loaded into a private function environment.

## Details

- WoW reads up to the first 1024 characters of each line only. Additional characters are ignored and do not cause an error.
- Newly created/added files and even complete addons are detected when doing a `/reload` after the game has started.

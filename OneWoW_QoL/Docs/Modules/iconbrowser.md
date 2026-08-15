# Icon Browser

Module id: `iconbrowser` · Folder: `Modules/external/iconbrowser/`

Replaces Blizzard’s icon picker on macro, bank tab, guild bank tab, equipment-set, and transmog-outfit popups with a searchable grid and category filters. On by default.

OneWoW Bags bank tabs use a cloned settings menu (`OneWoW_BankTabSettingsMenu`). Right-click a bank tab to open it — the same IconSelector template hook covers that menu. Guild-bank tabs still open stock `GuildBankPopupFrame`.

## Catalog

Icon names and category bits come from **LibRPMedia-1.2** (Unlicense, Meorawr), vendored under `Libs/LibRPMedia/` (Mainline data only). Do not edit those files.

## Conflict

If the standalone **IconBrowser** addon is loaded, this module does not inject. Disable that addon to use the OneWoW picker.

## Public API

Other addons (and suite units) can embed the same widget:

```lua
if OneWoW_QoL_API then
    local browser = OneWoW_QoL_API.CreateIconBrowser(parent, {
        onSelect = function(fileID, info) end,
        width = 480,
        height = 320,
        stride = 9,
    })
    browser:Show()
end
```

`CreateIconBrowser` is available whenever QoL is loaded, even if the module toggle is off. The toggle only controls injection into Blizzard popups.

local ADDON_NAME, ns = ...

local OneWoW = OneWoW

-- Manage Features unit. Classic through Dragonflight shards live in this addon.
-- File-load import is the contract: TOC lists this after the shards.
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
})

OneWoW:WithAddon("OneWoW_CatalogData_Quests", function()
    OneWoW_CatalogData_Quests_API.ImportQuestData(ns.ExternalQuestDB)
end)

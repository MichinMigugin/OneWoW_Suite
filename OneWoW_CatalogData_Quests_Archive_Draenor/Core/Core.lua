local _, ns = ...

local OneWoW = OneWoW

-- Import this era after its QuestDB shards. Era packs are not ModuleManifest
-- units, so BootStore OnAddonLoaded would never run; file-load import is the
-- contract (TOC lists this after the shards).
OneWoW:WithAddon("OneWoW_CatalogData_Quests", function()
    OneWoW_CatalogData_Quests_API.ImportQuestData(ns.ExternalQuestDB)
end)

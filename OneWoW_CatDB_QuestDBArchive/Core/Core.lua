local ADDON_NAME, ns = ...

local OneWoW = OneWoW

-- Classic through Dragonflight shards live here. File-load import is the
-- contract: TOC lists this after the shards; Current's EnsureArchiveThen
-- WithAddon-loads this pack, then this merges into Current.
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_QuestDBArchive_DB",
})

OneWoW:WithAddon("OneWoW_CatDB_QuestDBCurrent", function()
    OneWoW_CatDB_QuestDBCurrent_API.ImportQuestData(ns.ExternalQuestDB)
end)

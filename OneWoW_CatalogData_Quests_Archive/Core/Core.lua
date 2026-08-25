local ADDON_NAME, ns = ...

local OneWoW = OneWoW

-- Manage Features unit. Classic through Dragonflight shards live in era packs
-- loaded by QuestData:EnsureArchiveLoaded (one era per click, not all at once).
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
})

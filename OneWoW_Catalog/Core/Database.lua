-- OneWoW Addon File
-- OneWoW_Catalog/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    language          = nil,
    theme             = "green",
    lastTab           = "journal",
    mainFrameSize     = nil,
    mainFramePosition = nil,
    minimap           = { hide = false, minimapPos = 220, theme = "horde" },
    favorites         = {
        journal    = {},
        quests     = {},
        vendors    = {},
        itemSearch = {},
    },
}

function ns:InitializeDatabase()
    if not _G.OneWoW_Catalog_DB then _G.OneWoW_Catalog_DB = {} end
    DB:MergeMissing(_G.OneWoW_Catalog_DB, ns.DatabaseDefaults)
    ns.addon.db = { global = _G.OneWoW_Catalog_DB }
end

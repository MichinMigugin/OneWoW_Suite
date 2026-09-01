local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    global = {
        settings = {
            enabled = true,
        },
        completion = {},
    },
}

function ns:InitializeDatabase()
    if not OneWoW_CatDB_QuestDBCurrent_DB then OneWoW_CatDB_QuestDBCurrent_DB = {} end

    ns.db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_CatDB_QuestDBCurrent_DB",
        defaults = ns.DatabaseDefaults,
    })
end

function ns:GetSettings()
    return ns.db.global.settings
end

function ns:GetDB()
    return ns.db.global
end

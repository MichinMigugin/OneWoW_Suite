local ADDON_NAME, Addon = ...

function Addon:InitializeDatabase()
    local defaults = {
        position = {},
        recentFrames = {},
        textureBookmarks = {},
        theme = "green",
        language = GetLocale(),
        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "horde",
        },
        monitor = {
            showOnLoad = false,
            sortOrder = 2,
            continuousUpdate = false,
        },
        errorDB = {
            session = 0,
            errors = {},
            playSound = false,
        },
    }

    if not OneWoW_UtilityDevTool_DB then
        OneWoW_UtilityDevTool_DB = defaults
    else
        for key, value in pairs(defaults) do
            if OneWoW_UtilityDevTool_DB[key] == nil then
                OneWoW_UtilityDevTool_DB[key] = value
            end
        end
    end

    self.db = OneWoW_UtilityDevTool_DB
end

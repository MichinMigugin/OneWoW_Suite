local ADDON_NAME, Addon = ...

function Addon:InitializeDatabase()
    local defaults = {
        position = {},
        recentFrames = {},
        textureBookmarks = {},
        --- Saved width of the texture browser list column (nil = use default from Constants).
        textureBrowserLeftPaneWidth = nil,
        fontBrowserPreviewBg = nil,  -- nil = use FONT_BROWSER_PREVIEW_BG; else {r,g,b,a}
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
            pinnedAddon = nil,
            pinnedReopenOnReload = false,
            pinnedPosition = {},
        },
        errorDB = {
            session = 0,
            errors = {},
            playSound = false,
            clearOnReload = false,
            keepLastSessions = 10,
            maxErrors = 100,
            soundChoice = "off",
            copyFormat = "plain",
        },
        editor = {
            snippets = {},
            categories = { "Uncategorized" },
            indentSize = 3,
            fontSize = 12,
            autoSaveInterval = nil,
            outputHeight = nil,
            leftPaneWidth = nil,
            lastOpenSnippet = nil,
            untitledCounter = 1,
            categoryCollapsed = {},
        },
    }

    local function mergeSubTable(dbSub, defaultSub)
        for k, v in pairs(defaultSub) do
            if dbSub[k] == nil then
                dbSub[k] = v
            end
        end
    end

    if not OneWoW_UtilityDevTool_DB then
        OneWoW_UtilityDevTool_DB = defaults
    else
        for key, value in pairs(defaults) do
            if OneWoW_UtilityDevTool_DB[key] == nil then
                OneWoW_UtilityDevTool_DB[key] = value
            elseif type(value) == "table" and type(OneWoW_UtilityDevTool_DB[key]) == "table"
                   and (key == "errorDB" or key == "editor" or key == "monitor") then
                mergeSubTable(OneWoW_UtilityDevTool_DB[key], value)
            end
        end
    end

    self.db = OneWoW_UtilityDevTool_DB
end

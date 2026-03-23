local ADDON_NAME, Addon = ...

local GetLocale = GetLocale
local type = type
local pairs = pairs
local ipairs = ipairs
local tinsert = tinsert

local function getEditorLanguage(db)
    local hub = _G.OneWoW
    local lang
    if hub and hub.db and hub.db.global then
        lang = hub.db.global.language
    end
    if not lang then
        lang = db and db.language or GetLocale()
    end
    if lang == "esMX" then
        lang = "esES"
    end
    return lang or "enUS"
end

local function getLocalizedDefaultCategory(language)
    local locales = Addon.Locales or {}
    local localeData = locales[language] or locales["enUS"] or {}
    return localeData["EDITOR_CATEGORY_DEFAULT"] or "Uncategorized"
end

local function getDefaultCategoryAliases()
    local aliases = { ["Uncategorized"] = true }
    local locales = Addon.Locales or {}
    for _, localeData in pairs(locales) do
        local defaultCategory = localeData and localeData["EDITOR_CATEGORY_DEFAULT"]
        if defaultCategory and defaultCategory ~= "" then
            aliases[defaultCategory] = true
        end
    end
    return aliases
end

local function normalizeEditorDB(db)
    local editor = db.editor
    if type(editor) ~= "table" then return end

    local currentDefault = getLocalizedDefaultCategory(getEditorLanguage(db))
    local aliases = getDefaultCategoryAliases()
    local normalizedCategories = { currentDefault }
    local seenCategories = { [currentDefault] = true }

    editor.defaultCategory = currentDefault
    editor.categories = type(editor.categories) == "table" and editor.categories or {}
    editor.snippets = type(editor.snippets) == "table" and editor.snippets or {}
    editor.categoryCollapsed = type(editor.categoryCollapsed) == "table" and editor.categoryCollapsed or {}

    for _, category in ipairs(editor.categories) do
        local normalized = aliases[category] and currentDefault or category
        if normalized and normalized ~= "" and not seenCategories[normalized] then
            seenCategories[normalized] = true
            tinsert(normalizedCategories, normalized)
        end
    end

    for _, snippet in pairs(editor.snippets) do
        local category = snippet and snippet.category
        if not category or category == "" or aliases[category] then
            category = currentDefault
        end
        snippet.category = category
        if not seenCategories[category] then
            seenCategories[category] = true
            tinsert(normalizedCategories, category)
        end
    end

    local normalizedCollapsed = {}
    for category, collapsed in pairs(editor.categoryCollapsed) do
        local normalized = aliases[category] and currentDefault or category
        if normalizedCollapsed[normalized] == nil then
            normalizedCollapsed[normalized] = collapsed
        end
    end

    editor.categories = normalizedCategories
    editor.categoryCollapsed = normalizedCollapsed
end

function Addon:NormalizeEditorDatabase()
    if self.db then
        normalizeEditorDB(self.db)
    end
end

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
            defaultCategory = nil,
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
    self:NormalizeEditorDatabase()
end

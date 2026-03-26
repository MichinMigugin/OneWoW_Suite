local ADDON_NAME, Addon = ...

local GetLocale = GetLocale
local type = type
local pairs = pairs
local ipairs = ipairs
local tinsert = tinsert
local tremove = tremove
local sort = sort
local CopyTable = CopyTable

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

function Addon:GetPinnedMonitorEntriesInOrder(arr)
    if type(arr) ~= "table" then return {} end
    local keys = {}
    for k in pairs(arr) do
        if type(k) == "number" then tinsert(keys, k) end
    end
    sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        local e = arr[k]
        if type(e) == "table" then tinsert(out, e) end
    end
    if #out == 0 then
        for _, e in pairs(arr) do
            if type(e) == "table" then tinsert(out, e) end
        end
    end
    return out
end

local function migrateMonitorPinned(mon)
    if type(mon) ~= "table" then return end
    if type(mon.pinnedMonitors) ~= "table" then
        mon.pinnedMonitors = {}
    end
    if #Addon:GetPinnedMonitorEntriesInOrder(mon.pinnedMonitors) == 0 and type(mon.pinnedAddon) == "string" and mon.pinnedAddon ~= "" then
        local pos = mon.pinnedPosition
        if type(pos) ~= "table" then pos = {} end
        tinsert(mon.pinnedMonitors, {
            addon = mon.pinnedAddon,
            reopenOnReload = mon.pinnedReopenOnReload and true or false,
            position = CopyTable(pos),
        })
    end
    local arr = Addon:GetPinnedMonitorEntriesInOrder(mon.pinnedMonitors)
    local seen = {}
    local out = {}
    for _, e in ipairs(arr) do
        if type(e) == "table" and type(e.addon) == "string" and e.addon ~= "" and not seen[e.addon] and e.reopenOnReload then
            seen[e.addon] = true
            if type(e.position) ~= "table" then e.position = {} end
            tinsert(out, e)
        end
    end
    mon.pinnedMonitors = out
end

function Addon:InitializeDatabase()
    local tabDefaults = {}
    if self.UI and self.UI.GetTabSettingsDefaults then
        tabDefaults = self.UI:GetTabSettingsDefaults()
    end

    local defaults = {
        position = {},
        recentFrames = {},
        textureBookmarks = {},
        --- Saved width of the texture browser list column (nil = use default from Constants).
        textureBrowserLeftPaneWidth = nil,
        globalsBrowserLeftPaneWidth = nil,
        globalsBookmarks = {},
        globalsIncludeNoisyRoots = false,
        soundBrowserLeftPaneWidth = nil,
        soundBrowserChannel = "SFX",
        soundBookmarks = {},
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
            viewPreset = "balanced",
            continuousUpdate = false,
            pinnedMonitors = {},
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
            soundChoice = "devtools_error",
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
        tabs = tabDefaults,
    }

    local function mergeSubTable(dbSub, defaultSub)
        for k, v in pairs(defaultSub) do
            if dbSub[k] == nil then
                dbSub[k] = v
            end
        end
    end

    local function mergeTabSettings(dbTabs, defaultTabs)
        for key, value in pairs(defaultTabs) do
            if dbTabs[key] == nil then
                dbTabs[key] = value
            elseif type(value) == "table" and type(dbTabs[key]) == "table" then
                mergeSubTable(dbTabs[key], value)
            end
        end
        if dbTabs.settings == nil then
            dbTabs.settings = { enabled = true }
        end
        dbTabs.settings.enabled = true
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
            elseif key == "tabs" and type(value) == "table" and type(OneWoW_UtilityDevTool_DB[key]) == "table" then
                mergeTabSettings(OneWoW_UtilityDevTool_DB[key], value)
            end
        end
    end

    self.db = OneWoW_UtilityDevTool_DB
    if type(self.db.tabs) ~= "table" then
        self.db.tabs = tabDefaults
    end
    mergeTabSettings(self.db.tabs, tabDefaults)
    if type(self.db.monitor) == "table" then
        migrateMonitorPinned(self.db.monitor)
    end
    self:NormalizeEditorDatabase()
end

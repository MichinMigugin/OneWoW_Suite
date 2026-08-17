local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

local GetLocale = GetLocale
local type = type
local pairs, ipairs, next = pairs, ipairs, next
local sort, tinsert, wipe = sort, tinsert, wipe
local CopyTable = CopyTable

local function getEditorLanguage()
    local lang = OneWoW_GUI:GetSetting("language")
    if not lang then lang = GetLocale() end
    if lang == "esMX" then lang = "esES" end
    return lang or "enUS"
end

local function getLocalizedDefaultCategory(language)
    local locales = ns.Locales or {}
    local localeData = locales[language] or locales["enUS"] or {}
    return localeData["EDITOR_CATEGORY_DEFAULT"]
end

local function getDefaultCategoryAliases()
    local aliases = { ["Uncategorized"] = true }
    local locales = ns.Locales or {}
    for _, localeData in pairs(locales) do
        local defaultCategory = localeData and localeData["EDITOR_CATEGORY_DEFAULT"]
        if defaultCategory and defaultCategory ~= "" then
            aliases[defaultCategory] = true
        end
    end
    return aliases
end

local function normalizeEditorDB(global)
    local editor = global.editor
    if type(editor) ~= "table" then return end

    local currentDefault = getLocalizedDefaultCategory(getEditorLanguage())
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

function ns:NormalizeEditorDatabase()
    normalizeEditorDB(self.db.global)
end

function ns:GetPinnedMonitorEntriesInOrder(arr)
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

local function bridgeLegacyMonitorPinned(d)
    local mon = d.global and d.global.monitor
    if type(mon) ~= "table" then return end
    if type(mon.pinnedMonitors) ~= "table" then
        mon.pinnedMonitors = {}
    end
    if #ns:GetPinnedMonitorEntriesInOrder(mon.pinnedMonitors) == 0 and type(mon.pinnedAddon) == "string" and mon.pinnedAddon ~= "" then
        local pos = mon.pinnedPosition
        if type(pos) ~= "table" then pos = {} end
        tinsert(mon.pinnedMonitors, {
            addon = mon.pinnedAddon,
            reopenOnReload = mon.pinnedReopenOnReload and true or false,
            position = CopyTable(pos),
        })
    end
    local arr = ns:GetPinnedMonitorEntriesInOrder(mon.pinnedMonitors)
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
    mon.pinnedAddon = nil
    mon.pinnedReopenOnReload = nil
    mon.pinnedPosition = nil
end

function ns:InitializeDatabase()
    local sv = OneWoW_UtilityDevTool_DB
    if sv and not sv.global and next(sv) ~= nil then
        local oldData = {}
        for k, v in pairs(sv) do oldData[k] = v end
        wipe(sv)
        sv.global = oldData
    end

    local tabDefaults = {}
    if self.UI and self.UI.GetTabSettingsDefaults then
        tabDefaults = self.UI:GetTabSettingsDefaults()
    end

    local defaults = {
        global = {
            position = {},
            recentFrames = {},
            textureBookmarks = {},
            textureBrowserLeftPaneWidth = nil,
            globalsBrowserLeftPaneWidth = nil,
            globalsBookmarks = {},
            globalsIncludeNoisyRoots = false,
            soundBrowserLeftPaneWidth = nil,
            soundBrowserChannel = "SFX",
            soundBookmarks = {},
            fontBookmarks = {},
            fontBrowserPreviewBg = nil,
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
                devMode = false,
                devModeFlash = true,
                devModePosition = {},
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
            deferTextureBrowserData = false,
            deferSoundBrowserData = false,
            installNoticeAcknowledged = false,
            tabs = tabDefaults,
        },
    }

    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_UtilityDevTool_DB",
        defaults = defaults,
    })
    ns.db = db

    local g = db.global
    if type(g.tabs) ~= "table" then
        g.tabs = tabDefaults
    end
    DB:MergeMissing(g.tabs, tabDefaults)
    if g.tabs.settings == nil then
        g.tabs.settings = { enabled = true }
    end
    g.tabs.settings.enabled = true

    -- One-time: legacy single pinned monitor -> pinnedMonitors array.
    if g._migrationVersion and g._migrationVersion >= 1 then
        g._monitorPinnedMigrated = true
    end
    if not g._monitorPinnedMigrated then
        bridgeLegacyMonitorPinned(db)
        g._monitorPinnedMigrated = true
    end

    self:NormalizeEditorDatabase()
end

--- Return the addon database handle after initialization.
---@return table db
function ns:GetDB()
    return ns.db
end

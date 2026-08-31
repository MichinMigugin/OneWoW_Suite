-- ============================================================================
-- Search CoreEntries
-- ============================================================================
-- Hub tabs, Settings row-2, overlay presets, and standalone windows that are
-- not produced by RegisterModule / Define. Display crumbs resolve live so a
-- language change does not freeze English paths.
-- ============================================================================

local _, ns = ...

local reg = ns.SearchRegistry

local function Label(key)
    return function()
        return ns.L[key]
    end
end

local Shared = Label

-- ---- Home + core Settings tabs ----

reg:Register({
    id = "hub:home",
    title = Label("HOME_TAB"),
    tags = { "home", "start" },
    path = { Label("HOME_TAB") },
    nav = { module = "home" },
})

local coreTabs = {
    {
        id = "settings:settings",
        title = function() return DISPLAY end,
        tags = { "display", "settings", "theme", "language", "font", "minimap" },
        subtab = "settings",
    },
    {
        id = "settings:rolesandalts",
        title = Label("ROLES_ALTS_SUBTAB"),
        tags = { "roles", "alts", "characters" },
        subtab = "rolesandalts",
    },
    {
        id = "settings:searchshortcuts",
        title = Label("SEARCH_SHORTCUTS_SUBTAB"),
        tags = { "search shortcuts", "saved search", "aliases" },
        subtab = "searchshortcuts",
    },
    {
        id = "settings:profiles",
        title = Label("PROFILES_SUBTAB"),
        tags = { "profiles", "backup" },
        subtab = "profiles",
    },
    {
        id = "settings:managefeatures",
        title = Label("MANAGE_FEATURES_SUBTAB"),
        tags = { "manage features", "enable", "disable", "load", "opt out" },
        subtab = "managefeatures",
    },
}

for i = 1, #coreTabs do
    local t = coreTabs[i]
    reg:Register({
        id = t.id,
        title = t.title,
        tags = t.tags,
        path = { function() return SETTINGS end, t.title },
        nav = { module = "settings", subtab = t.subtab },
    })
end

-- ---- Display page rows (language / theme / font / minimap / money) ----

local displayRows = {
    {
        id = "settings:language",
        title = Shared("LANGUAGE_SELECTION"),
        description = Shared("LANGUAGE_DESC"),
        tags = { "language", "locale", "translation" },
    },
    {
        id = "settings:theme",
        title = Shared("THEME_SECTION"),
        description = Shared("THEME_DESC"),
        tags = { "theme", "color", "appearance" },
    },
    {
        id = "settings:font",
        title = Shared("FONT_SECTION"),
        description = Shared("FONT_DESC"),
        tags = { "font", "typeface", "size" },
    },
    {
        id = "settings:minimap",
        title = Shared("MINIMAP_SECTION"),
        description = Shared("MINIMAP_SECTION_DESC"),
        tags = { "minimap", "minimap button", "ldb" },
    },
    {
        id = "settings:money",
        title = Shared("VALUE_DISPLAY_SECTION"),
        description = Shared("VALUE_DISPLAY_DESC"),
        tags = { "gold", "money", "copper", "silver", "comma", "separator", "thousands" },
    },
}

for i = 1, #displayRows do
    local row = displayRows[i]
    reg:Register({
        id = row.id,
        title = row.title,
        description = row.description,
        tags = row.tags,
        path = { function() return SETTINGS end, function() return DISPLAY end, row.title },
        nav = { module = "settings", subtab = "settings" },
    })
end

reg:RegisterOverlayPresets()

-- ---- Standalone windows (searchable even before the LoD unit loads) ----

local standalones = {
    {
        id = "standalone:bags",
        title = Label("MODULE_BAGS"),
        tags = { "bags", "inventory", "backpack" },
        addonKey = "OneWoW_Bags",
        addonName = "OneWoW_Bags",
        apiName = "OneWoW_Bags_API",
    },
    {
        id = "standalone:mail",
        title = function() return MAIL_LABEL end,
        tags = { "mail", "mailbox", "post" },
        addonKey = "OneWoW_Mail",
        addonName = "OneWoW_Mail",
        apiName = "OneWoW_Mail_API",
    },
    {
        id = "standalone:directdeposit",
        title = Label("MODULE_DIRECTDEPOSIT"),
        tags = { "direct deposit", "warband bank", "gold" },
        addonKey = "OneWoW_DirectDeposit",
        addonName = "OneWoW_DirectDeposit",
        apiName = "OneWoW_DirectDeposit_API",
    },
    {
        id = "standalone:shoppinglist",
        title = Label("MODULE_SHOPPINGLIST"),
        tags = { "shopping list", "reagents", "crafting list" },
        addonKey = "OneWoW_ShoppingList",
        addonName = "OneWoW_ShoppingList",
        apiName = "OneWoW_ShoppingList_API",
    },
}

local function MakeOpen(addonName, apiName)
    return function()
        ns:BringUp(addonName)
        _G[apiName].Show()
    end
end

for i = 1, #standalones do
    local s = standalones[i]
    reg:Register({
        id = s.id,
        title = s.title,
        tags = s.tags,
        addonKey = s.addonKey,
        path = { s.title },
        nav = { open = MakeOpen(s.addonName, s.apiName) },
    })
end

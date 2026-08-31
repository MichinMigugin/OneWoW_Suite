local _, ns = ...

local Search = OneWoW.Search

local function ShowSettings()
    if not ns.Settings:IsShown() then
        ns.Settings:Toggle()
    end
end

local settingsNav = { open = ShowSettings }

local function PathFor(leaf, titleKey)
    return {
        function() return ns.L["ADDON_TITLE"] end,
        function() return SETTINGS end,
        function() return ns.L[leaf] end,
        function() return ns.L[titleKey] end,
    }
end

Search:Register({
    id = "bags:settings",
    title = function() return SETTINGS end,
    tags = { "bags settings", "options" },
    addonKey = "OneWoW_Bags",
    scope = "OneWoW_Bags",
    path = {
        function() return ns.L["ADDON_TITLE"] end,
        function() return SETTINGS end,
    },
    nav = settingsNav,
})

local rows = {
    {
        id = "bags:enable",
        title = "SETTING_ENABLE_BAGS",
        description = "DESC_ENABLE_BAGS",
        tags = { "enable bags", "replace bags" },
        leaf = "TAB_GENERAL",
    },
    {
        id = "bags:junk-cat",
        title = "SETTING_ENABLE_JUNK_CAT",
        description = "DESC_ENABLE_JUNK_CAT",
        tags = { "junk", "grey", "gray", "vendor" },
        leaf = "TAB_GENERAL",
    },
    {
        id = "bags:unusable-overlay",
        title = "SETTING_UNUSABLE_OVERLAY",
        description = "DESC_UNUSABLE_OVERLAY",
        tags = { "overlay", "red", "unusable" },
        leaf = "TAB_BAGS",
    },
    {
        id = "bags:dim-junk",
        title = "SETTING_DIM_JUNK",
        description = "DESC_DIM_JUNK",
        tags = { "junk", "grey", "gray", "dim" },
        leaf = "TAB_BAGS",
    },
    {
        id = "bags:auto-open",
        title = "SETTING_AUTO_OPEN",
        description = "DESC_AUTO_OPEN",
        tags = { "auto open", "vendor", "merchant" },
        leaf = "TAB_BAGS",
    },
}

for i = 1, #rows do
    local row = rows[i]
    Search:Register({
        id = row.id,
        title = row.title,
        description = row.description,
        scope = "OneWoW_Bags",
        tags = row.tags,
        addonKey = "OneWoW_Bags",
        path = PathFor(row.leaf, row.title),
        nav = settingsNav,
    })
end

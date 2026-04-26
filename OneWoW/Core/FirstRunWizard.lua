-- OneWoW/Core/FirstRunWizard.lua
-- First-login feature picker + a reusable "Manage Features" panel that the
-- Settings tab exposes. Lets the user truly unload any feature addon they
-- don't want (not just hide its UI) via DisableAddOn / EnableAddOn + a
-- ReloadUI prompt. Shared/dependency datastores auto-follow: if no consumer
-- is enabled we offer to disable that datastore too; if any consumer is
-- enabled we keep it enabled.

local ADDON_NAME, OneWoW = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW.FirstRun = OneWoW.FirstRun or {}
local FirstRun = OneWoW.FirstRun

-- Authoritative feature catalog. Each entry:
--   addonName   - the WoW addon folder / TOC name (what DisableAddOn sees)
--   label       - human-readable
--   summary     - short description
--   group       - "feature" | "standalone" | "utility" - grouping in the UI
--   datastores  - list of sibling data addons this feature needs loaded
-- Datastores are "pulled in" if any checked feature needs them.
FirstRun.CATALOG = {
    { addonName = "OneWoW_AltTracker",    label = "AltTracker",          group = "feature",
      summary = "Cross-character dashboard: progress, gold, professions, bank, auctions, lockouts.",
      datastores = { "OneWoW_AltTracker_Storage", "OneWoW_AltTracker_Character",
                     "OneWoW_AltTracker_Collections", "OneWoW_AltTracker_Endgame",
                     "OneWoW_AltTracker_Accounting", "OneWoW_AltTracker_Professions",
                     "OneWoW_AltTracker_Auctions" } },
    { addonName = "OneWoW_Catalog",       label = "Catalog",             group = "feature",
      summary = "Browseable journal / vendors / tradeskills / quests / item search.",
      datastores = { "OneWoW_CatalogData_Journal", "OneWoW_CatalogData_Quests",
                     "OneWoW_CatalogData_Vendors", "OneWoW_CatalogData_Tradeskills" } },
    { addonName = "OneWoW_Notes",         label = "Notes",               group = "feature",
      summary = "Note-taking for characters, players, NPCs, zones, items.",
      datastores = {} },
    { addonName = "OneWoW_Trackers",      label = "Trackers",            group = "feature",
      summary = "User-defined tracker lists, guides, dailies, weeklies, todos.",
      datastores = {} },
    { addonName = "OneWoW_QoL",           label = "Quality of Life",     group = "feature",
      summary = "Feature pack: autoloot, autorepair, coords, mounts, panels, and many toggles.",
      datastores = {} },

    { addonName = "OneWoW_Bags",          label = "Bags",                group = "standalone",
      summary = "Unified bags / bank / guild bank UI with categories, sorting, imports.",
      datastores = { "OneWoW_AltTracker_Storage", "OneWoW_AltTracker_Character" } },
    { addonName = "OneWoW_ShoppingList",  label = "Shopping List",       group = "standalone",
      summary = "Shopping / crafting material lists with profession + alt-inventory awareness.",
      datastores = { "OneWoW_AltTracker_Storage", "OneWoW_AltTracker_Professions" } },
    { addonName = "OneWoW_DirectDeposit", label = "Direct Deposit",      group = "standalone",
      summary = "Automates gold / item moves between character and Warband Bank.",
      datastores = {} },

    { addonName = "OneWoW_Utility_DevTool", label = "DevTool (developers)", group = "utility",
      summary = "Frame inspection, event monitor, error export, globals / atlas browsers.",
      datastores = {} },
}

local DATASTORE_ADDONS = {
    "OneWoW_AltTracker_Storage",    "OneWoW_AltTracker_Character",
    "OneWoW_AltTracker_Collections", "OneWoW_AltTracker_Endgame",
    "OneWoW_AltTracker_Accounting", "OneWoW_AltTracker_Professions",
    "OneWoW_AltTracker_Auctions",
    "OneWoW_CatalogData_Journal",   "OneWoW_CatalogData_Quests",
    "OneWoW_CatalogData_Vendors",   "OneWoW_CatalogData_Tradeskills",
}

local function IsLoaded(addonName)
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local state = C_AddOns.GetAddOnEnableState(addonName, UnitName("player"))
        return state and state > 0
    end
    return false
end

local function SetEnabled(addonName, wantEnabled)
    if wantEnabled then
        if C_AddOns and C_AddOns.EnableAddOn then
            C_AddOns.EnableAddOn(addonName, UnitName("player"))
        end
    else
        if C_AddOns and C_AddOns.DisableAddOn then
            C_AddOns.DisableAddOn(addonName, UnitName("player"))
        end
    end
end

-- For each datastore, decide whether it should be enabled based on which
-- consumer features the user kept checked.
local function ComputeDatastoreState(selections)
    local wanted = {}
    for _, ds in ipairs(DATASTORE_ADDONS) do wanted[ds] = false end
    for _, entry in ipairs(FirstRun.CATALOG) do
        if selections[entry.addonName] then
            for _, ds in ipairs(entry.datastores) do
                wanted[ds] = true
            end
        end
    end
    return wanted
end

function FirstRun:GetCurrentSelections()
    local selections = {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        selections[entry.addonName] = IsLoaded(entry.addonName)
    end
    return selections
end

function FirstRun:Apply(selections)
    for _, entry in ipairs(FirstRun.CATALOG) do
        SetEnabled(entry.addonName, selections[entry.addonName] and true or false)
    end
    local datastoreState = ComputeDatastoreState(selections)
    for _, ds in ipairs(DATASTORE_ADDONS) do
        SetEnabled(ds, datastoreState[ds] and true or false)
    end

    if _G.OneWoW_DB then
        _G.OneWoW_DB.wizardShown = true
    end

    StaticPopupDialogs["ONEWOW_MANAGE_FEATURES_RELOAD"] = {
        text = "Feature selection saved. Reload UI to apply?",
        button1 = "Reload now",
        button2 = "Later",
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("ONEWOW_MANAGE_FEATURES_RELOAD")
end

-- Apply a "recommended set": every feature except utility entries.
function FirstRun:ApplyRecommended()
    local sel = {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        sel[entry.addonName] = (entry.group ~= "utility")
    end
    self:Apply(sel)
end

-- Build the Manage Features panel into `parent` (a Frame). This is reused by
-- both the first-run popup and the Settings > Manage Features sub-tab.
--
-- All themed widgets go through OneWoW_GUI helpers so the panel matches the
-- rest of the addon's UI standards: no raw SetBackdrop, no UICheckButtonTemplate.
function FirstRun:BuildPanel(parent)
    local L = OneWoW.L or {}

    local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_ManageFeaturesScroll" })
    content:SetHeight(900)

    local headerBg = OneWoW_GUI:CreateFrame(content, {
        bgColor     = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    headerBg:SetPoint("TOPLEFT",  content, "TOPLEFT",  10,  -10)
    headerBg:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -10)
    headerBg:SetHeight(80)

    local headerTitle = OneWoW_GUI:CreateFS(headerBg, 16)
    headerTitle:SetPoint("TOPLEFT", headerBg, "TOPLEFT", 15, -12)
    headerTitle:SetText(L["MANAGE_FEATURES_TITLE"] or "Manage Features")
    headerTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local headerDesc = OneWoW_GUI:CreateFS(headerBg, 11)
    headerDesc:SetPoint("TOPLEFT",  headerBg, "TOPLEFT",  15, -36)
    headerDesc:SetPoint("TOPRIGHT", headerBg, "TOPRIGHT", -15, -36)
    headerDesc:SetJustifyH("LEFT")
    headerDesc:SetWordWrap(true)
    headerDesc:SetText(L["MANAGE_FEATURES_DESC"] or
        "Uncheck any feature you don't use. Its addon (and any exclusively-owned datastore addons) will be fully unloaded \226\128\148 no RAM, no CPU, no SavedVariables written. Shared datastores (e.g. Storage / Character) stay enabled as long as any enabled feature depends on them.")
    headerDesc:SetHeight(44)
    headerDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    -- Invisible layout container for the two action buttons; no backdrop, no
    -- theme, nothing to standardize - purely positional.
    local actionBar = CreateFrame("Frame", nil, content)
    actionBar:SetPoint("TOPLEFT",  headerBg, "BOTTOMLEFT",  0, -8)
    actionBar:SetPoint("TOPRIGHT", headerBg, "BOTTOMRIGHT", 0, -8)
    actionBar:SetHeight(32)

    local recommendedBtn = OneWoW_GUI:CreateButton(actionBar, { text = "Use recommended", width = 160, height = 26 })
    recommendedBtn:SetPoint("LEFT", actionBar, "LEFT", 0, 0)

    local applyBtn = OneWoW_GUI:CreateButton(actionBar, { text = "Apply & Reload", width = 160, height = 26 })
    applyBtn:SetPoint("RIGHT", actionBar, "RIGHT", 0, 0)

    -- Invisible layout container for the group bands + feature rows.
    local listContainer = CreateFrame("Frame", nil, content)
    listContainer:SetPoint("TOPLEFT",  actionBar, "BOTTOMLEFT",  0, -8)
    listContainer:SetPoint("TOPRIGHT", actionBar, "BOTTOMRIGHT", 0, -8)
    listContainer:SetHeight(600)

    local selections = FirstRun:GetCurrentSelections()
    local checkboxes = {}
    local rowY = 0

    local groupLabels = { feature = "Features", standalone = "Standalones", utility = "Utilities" }
    local groupOrder  = { "feature", "standalone", "utility" }

    for _, group in ipairs(groupOrder) do
        local groupHeader = OneWoW_GUI:CreateSectionHeader(listContainer, {
            title   = groupLabels[group],
            yOffset = -rowY,
        })
        rowY = -groupHeader.bottomY + 6

        for _, entry in ipairs(FirstRun.CATALOG) do
            if entry.group == group then
                local row = OneWoW_GUI:CreateFrame(listContainer, {
                    bgColor     = "BG_SECONDARY",
                    borderColor = "BORDER_SUBTLE",
                })
                row:SetHeight(44)
                row:SetPoint("TOPLEFT",  listContainer, "TOPLEFT",   0, -rowY)
                row:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT",  0, -rowY)

                local cb = OneWoW_GUI:CreateCheckbox(row, {
                    label   = "",
                    checked = selections[entry.addonName],
                    onClick = function(self)
                        selections[entry.addonName] = self:GetChecked() and true or false
                    end,
                })
                cb:SetPoint("LEFT", row, "LEFT", 10, 0)
                checkboxes[entry.addonName] = cb

                local label = OneWoW_GUI:CreateFS(row, 13)
                label:SetPoint("LEFT", cb, "RIGHT", 8, 6)
                label:SetText(entry.label)
                label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

                local summary = OneWoW_GUI:CreateFS(row, 11)
                summary:SetPoint("LEFT",  cb, "RIGHT", 8, -10)
                summary:SetPoint("RIGHT", row, "RIGHT", -10, -10)
                summary:SetJustifyH("LEFT")
                summary:SetText(entry.summary)
                summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

                rowY = rowY + 48
            end
        end
        rowY = rowY + 10
    end

    listContainer:SetHeight(math.max(1, rowY))
    content:SetHeight(120 + rowY + 40)

    recommendedBtn:SetScript("OnClick", function()
        for _, entry in ipairs(FirstRun.CATALOG) do
            local want = (entry.group ~= "utility")
            selections[entry.addonName] = want
            if checkboxes[entry.addonName] then
                checkboxes[entry.addonName]:SetChecked(want)
            end
        end
    end)

    applyBtn:SetScript("OnClick", function()
        FirstRun:Apply(selections)
    end)
end

function FirstRun:ShouldShowWizard()
    return _G.OneWoW_DB and not _G.OneWoW_DB.wizardShown
end

-- First-run popup: a themed dialog that wraps BuildPanel. Triggered from
-- OneWoW's PLAYER_LOGIN init sequence when wizardShown is false.
function FirstRun:ShowWizard()
    if FirstRun._activeDialog and FirstRun._activeDialog:IsShown() then
        FirstRun._activeDialog:Raise()
        return
    end

    local result = OneWoW_GUI:CreateDialog({
        name      = "OneWoW_FirstRunWizard",
        title     = (OneWoW.L and OneWoW.L["WIZARD_TITLE"]) or "Welcome to OneWoW",
        width     = 760,
        height    = 620,
        showBrand = true,
        buttons   = nil,
    })
    local dialog = result.frame
    FirstRun._activeDialog = dialog

    FirstRun:BuildPanel(result.contentFrame)

    dialog:SetFrameStrata("DIALOG")
    dialog:Show()
    dialog:Raise()
end

-- Slash command to re-open the wizard anytime.
_G.SLASH_ONEWOW_WIZARD1 = "/ow-wizard"
SlashCmdList["ONEWOW_WIZARD"] = function()
    FirstRun:ShowWizard()
end

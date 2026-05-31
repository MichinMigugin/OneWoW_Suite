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
--   labelKey    - localized display name key
--   summaryKey  - localized short description key
--   group       - "feature" | "standalone" | "utility" - grouping in the UI
--   iconTexture - card icon texture path
--   datastores  - list of sibling data addons this feature needs loaded
-- Datastores are "pulled in" if any checked feature needs them.
FirstRun.CATALOG = {
    { addonName = "OneWoW_AltTracker", labelKey = "WIZARD_FEATURE_ALTTRACKER", summaryKey = "WIZARD_FEATURE_ALTTRACKER_DESC", group = "feature",
      iconTexture = "Interface\\Icons\\Achievement_Guild_ClassyDwarf",
      datastores = { "OneWoW_AltTracker_Storage", "OneWoW_AltTracker_Character",
                     "OneWoW_AltTracker_Collections", "OneWoW_AltTracker_Endgame",
                     "OneWoW_AltTracker_Accounting", "OneWoW_AltTracker_Professions",
                     "OneWoW_AltTracker_Auctions" } },
    { addonName = "OneWoW_Catalog", labelKey = "WIZARD_FEATURE_CATALOG", summaryKey = "WIZARD_FEATURE_CATALOG_DESC", group = "feature",
      iconTexture = "Interface\\Icons\\INV_Misc_Book_11",
      datastores = { "OneWoW_CatalogData_Journal", "OneWoW_CatalogData_Quests",
                     "OneWoW_CatalogData_Vendors", "OneWoW_CatalogData_Tradeskills" } },
    { addonName = "OneWoW_Notes", labelKey = "WIZARD_FEATURE_NOTES", summaryKey = "WIZARD_FEATURE_NOTES_DESC", group = "feature",
      iconTexture = "Interface\\Icons\\INV_Inscription_Scroll",
      datastores = {} },
    { addonName = "OneWoW_Trackers", labelKey = "WIZARD_FEATURE_TRACKERS", summaryKey = "WIZARD_FEATURE_TRACKERS_DESC", group = "feature",
      iconTexture = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
      datastores = {} },
    { addonName = "OneWoW_QoL", labelKey = "WIZARD_FEATURE_QOL", summaryKey = "WIZARD_FEATURE_QOL_DESC", group = "feature",
      iconTexture = "Interface\\Icons\\INV_Gizmo_RocketBoot_01",
      datastores = {} },

    { addonName = "OneWoW_Bags", labelKey = "WIZARD_FEATURE_BAGS", summaryKey = "WIZARD_FEATURE_BAGS_DESC", group = "standalone",
      iconTexture = "Interface\\Icons\\INV_Misc_Bag_08",
      datastores = { "OneWoW_AltTracker_Storage", "OneWoW_AltTracker_Character" } },
    { addonName = "OneWoW_ShoppingList", labelKey = "WIZARD_FEATURE_SHOPPINGLIST", summaryKey = "WIZARD_FEATURE_SHOPPINGLIST_DESC", group = "standalone",
      iconTexture = "Interface\\Icons\\INV_Misc_Coin_01",
      datastores = { "OneWoW_AltTracker_Storage", "OneWoW_AltTracker_Professions" } },
    { addonName = "OneWoW_DirectDeposit", labelKey = "WIZARD_FEATURE_DIRECTDEPOSIT", summaryKey = "WIZARD_FEATURE_DIRECTDEPOSIT_DESC", group = "standalone",
      iconTexture = "Interface\\Icons\\INV_Misc_Coin_02",
      datastores = {} },

    { addonName = "OneWoW_Utility_DevTool", labelKey = "WIZARD_FEATURE_DEVTOOL", summaryKey = "WIZARD_FEATURE_DEVTOOL_DESC", group = "utility",
      iconTexture = "Interface\\Icons\\INV_Gizmo_02",
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
    local L = OneWoW.L or {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        SetEnabled(entry.addonName, selections[entry.addonName] and true or false)
    end
    local datastoreState = ComputeDatastoreState(selections)
    for _, ds in ipairs(DATASTORE_ADDONS) do
        SetEnabled(ds, datastoreState[ds] and true or false)
    end

    -- wizardShown is owned by the "Do not show again" checkbox in BuildPanel,
    -- which writes to the DB on toggle. Apply intentionally does not touch it.

    StaticPopupDialogs["ONEWOW_MANAGE_FEATURES_RELOAD"] = {
        text = L["WIZARD_RELOAD_TEXT"],
        button1 = L["WIZARD_RELOAD_NOW"],
        button2 = L["WIZARD_RELOAD_LATER"],
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
    local C = OneWoW_GUI.Constants.GUI

    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_ManageFeaturesScroll" })
    content:SetHeight(1)

    local selections = FirstRun:GetCurrentSelections()
    local originalSelections = {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        originalSelections[entry.addonName] = selections[entry.addonName] and true or false
    end

    local function CountSelected()
        local count = 0
        for _, entry in ipairs(FirstRun.CATALOG) do
            if selections[entry.addonName] then
                count = count + 1
            end
        end
        return count
    end

    local function CountWantedDatastores()
        local count = 0
        local datastoreState = ComputeDatastoreState(selections)
        for _, ds in ipairs(DATASTORE_ADDONS) do
            if datastoreState[ds] then
                count = count + 1
            end
        end
        return count
    end

    local function HasChanges()
        for _, entry in ipairs(FirstRun.CATALOG) do
            local addonName = entry.addonName
            if (selections[addonName] and true or false) ~= originalSelections[addonName] then
                return true
            end
        end
        return false
    end

    local hero = OneWoW_GUI:CreateHeroPanel(content, {
        title = L["WIZARD_HERO_TITLE"],
        subtitle = L["WIZARD_HERO_SUBTITLE"],
        description = L["WIZARD_HERO_DESC"],
        calloutText = L["WIZARD_HERO_CALLOUT"],
        iconTexture = OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme")),
        yOffset = -10,
    })

    local summary = OneWoW_GUI:CreateSummaryStrip(content, {
        yOffset = hero.bottomY - 8,
        items = {
            { label = L["WIZARD_SUMMARY_SELECTED"] },
            { label = L["WIZARD_SUMMARY_DATA"] },
            { label = L["WIZARD_SUMMARY_RELOAD"] },
        },
    })

    local actionBar = OneWoW_GUI:CreateActionBar(content, {
        yOffset  = summary.bottomY - 8,
        insetX   = 12,
        gap      = OneWoW_GUI:GetSpacing("MD"),
        rowHeight = C.ACTION_BAR_HEIGHT,
    })

    local presetItems = {
        { text = L["WIZARD_PRESET_RECOMMENDED"], value = "recommended" },
        { text = L["WIZARD_PRESET_MINIMAL"],     value = "minimal" },
        { text = L["WIZARD_PRESET_MANUAL"],      value = "manual", isActive = true },
    }
    local presetGap = OneWoW_GUI:GetSpacing("XS")
    local presetHeight = 26
    local presetButtons = {}

    local function ApplyPresetVisual(btn)
        if btn.isActive then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    local maxBtnWidth = 0
    for i, item in ipairs(presetItems) do
        local btn = OneWoW_GUI:CreateFitTextButton(actionBar.left, {
            text     = item.text,
            height   = presetHeight,
            minWidth = 80,
        })
        btn.itemValue = item.value
        btn.isActive  = item.isActive or false
        ApplyPresetVisual(btn)
        btn:HookScript("OnEnter", function(self)
            if not self.isActive then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            end
        end)
        btn:HookScript("OnLeave", function(self) ApplyPresetVisual(self) end)
        local w = btn:GetWidth() or 0
        if w > maxBtnWidth then maxBtnWidth = w end
        presetButtons[i] = btn
    end

    local prevBtn
    for _, btn in ipairs(presetButtons) do
        btn:SetWidth(maxBtnWidth)
        if prevBtn then
            btn:SetPoint("LEFT", prevBtn, "RIGHT", presetGap, 0)
        else
            btn:SetPoint("TOPLEFT", actionBar.left, "TOPLEFT", 0, 0)
        end
        prevBtn = btn
    end
    local clusterWidth = (#presetButtons * maxBtnWidth) + ((#presetButtons - 1) * presetGap)

    function presetButtons.SetActiveByValue(value)
        for _, btn in ipairs(presetButtons) do
            btn.isActive = (btn.itemValue == value)
            ApplyPresetVisual(btn)
        end
    end

    actionBar.left:SetWidth(clusterWidth)
    actionBar.left:SetHeight(presetHeight)

    local applyBtn = OneWoW_GUI:CreateFitTextButton(actionBar.right, {
        text = L["WIZARD_APPLY_RELOAD"],
        height = 26,
        minWidth = 130,
    })
    applyBtn:SetPoint("TOPRIGHT", actionBar.right, "TOPRIGHT", 0, 0)
    actionBar.right:SetWidth(applyBtn:GetWidth())
    actionBar:Refresh()

    local initialDontShow = (_G.OneWoW_DB and _G.OneWoW_DB.wizardShown ~= false) and true or false
    if _G.OneWoW_DB then
        _G.OneWoW_DB.wizardShown = initialDontShow
    end
    local dontShowRow = OneWoW_GUI:CreateLayoutFrame(content, { height = C.CHECKBOX_SIZE or 24 })
    local dontShowCB = OneWoW_GUI:CreateCheckbox(dontShowRow, {
        label   = L["WIZARD_DONT_SHOW_AGAIN"],
        checked = initialDontShow,
        onClick = function(myself)
            if _G.OneWoW_DB then
                _G.OneWoW_DB.wizardShown = myself:GetChecked() and true or false
            end
        end,
    })
    dontShowCB:SetPoint("LEFT", dontShowRow, "LEFT", 0, 0)

    local listContainer = OneWoW_GUI:CreateLayoutFrame(content, {})
    listContainer:SetHeight(1)

    local groupLabels = {
        feature = L["WIZARD_GROUP_FEATURES"],
        standalone = L["WIZARD_GROUP_STANDALONE"],
        utility = L["WIZARD_GROUP_UTILITY"],
    }
    local groupOrder  = { "feature", "standalone", "utility" }

    local cards = {}

    local function RefreshSummary()
        summary:SetItemValue(1, format(L["WIZARD_SUMMARY_SELECTED_FORMAT"], CountSelected(), #FirstRun.CATALOG))
        summary:SetItemValue(2, format(L["WIZARD_SUMMARY_DATA_FORMAT"], CountWantedDatastores()))
        summary:SetItemValue(3, HasChanges() and L["WIZARD_SUMMARY_PENDING"] or L["WIZARD_SUMMARY_READY"])
    end

    local function ApplyPreset(preset)
        for _, entry in ipairs(FirstRun.CATALOG) do
            local want = false
            if preset == "recommended" then
                want = (entry.group ~= "utility")
            elseif preset == "minimal" then
                want = false
            else
                want = selections[entry.addonName] and true or false
            end
            selections[entry.addonName] = want
            if cards[entry.addonName] then
                cards[entry.addonName]:SetChecked(want, true)
            end
        end
        RefreshSummary()
    end

    local listItems = {}
    local extraGapForHeader = OneWoW_GUI:GetSpacing("MD")
    local headerIndices = {}
    for _, group in ipairs(groupOrder) do
        local groupHeader = OneWoW_GUI:CreateSectionHeader(listContainer, {
            title   = groupLabels[group],
            yOffset = 0,
        })
        groupHeader:ClearAllPoints()
        table.insert(listItems, groupHeader)
        headerIndices[#listItems] = true

        for _, entry in ipairs(FirstRun.CATALOG) do
            if entry.group == group then
                local card = OneWoW_GUI:CreateSelectableCard(listContainer, {
                    title = L[entry.labelKey],
                    summary = L[entry.summaryKey],
                    iconTexture = entry.iconTexture,
                    checked = selections[entry.addonName],
                    onToggle = function(_, checked)
                        selections[entry.addonName] = checked and true or false
                        presetButtons.SetActiveByValue("manual")
                        RefreshSummary()
                    end,
                })
                card:ClearAllPoints()
                cards[entry.addonName] = card
                table.insert(listItems, card)
            end
        end
    end

    local stackGaps = {}
    for i = 1, #listItems do
        if headerIndices[i + 1] then
            stackGaps[i] = extraGapForHeader
        else
            stackGaps[i] = OneWoW_GUI:GetSpacing("XS")
        end
    end

    OneWoW_GUI:StackVertically(listContainer, listItems, {
        gap = OneWoW_GUI:GetSpacing("XS"),
        gaps = stackGaps,
        topPadding = 0,
        sidePadding = 0,
        autoHeight = true,
    })

    local mainStackGap = OneWoW_GUI:GetSpacing("SM")
    local mainStackGaps = {
        [1] = mainStackGap,
        [2] = mainStackGap,
        [3] = OneWoW_GUI:GetSpacing("XS"),
        [4] = OneWoW_GUI:GetSpacing("MD"),
    }
    OneWoW_GUI:StackVertically(content, {
        hero,
        summary,
        actionBar,
        dontShowRow,
        listContainer,
    }, {
        gap = mainStackGap,
        gaps = mainStackGaps,
        topPadding = 10,
        sidePadding = OneWoW_GUI:GetSpacing("MD"),
        autoHeight = true,
    })

    presetButtons[1]:SetScript("OnClick", function()
        presetButtons.SetActiveByValue("recommended")
        ApplyPreset("recommended")
    end)
    presetButtons[2]:SetScript("OnClick", function()
        presetButtons.SetActiveByValue("minimal")
        ApplyPreset("minimal")
    end)
    presetButtons[3]:SetScript("OnClick", function()
        presetButtons.SetActiveByValue("manual")
    end)

    applyBtn:SetScript("OnClick", function()
        FirstRun:Apply(selections)
    end)

    RefreshSummary()
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

    local C = OneWoW_GUI.Constants.GUI
    local result = OneWoW_GUI:CreateDialog({
        name      = "OneWoW_FirstRunWizard",
        title     = OneWoW.L["WIZARD_TITLE"],
        width     = C.WIZARD_DIALOG_WIDTH,
        height    = C.WIZARD_DIALOG_HEIGHT,
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

-- OneWoW/Core/FirstRunWizard.lua
-- First-login feature picker + a reusable "Manage Features" panel that the
-- Settings tab exposes. Two ways to turn features off/on:
--   * Apply (soft) - writes OneWoW's opt-out layer only; the addon stays
--     Blizzard-enabled (so the built-in list shows it with a "Load Addon"
--     button) while OneWoW skips loading it. Reload-free: a per-row Load Addon
--     button (or re-checking + Apply) loads it back this session.
--   * Apply & Reload (hard) - writes Blizzard's Enable/DisableAddOn flags and
--     reloads (the only way to truly evict a loaded addon, or to re-enable a
--     Blizzard-disabled one).
-- Shared/dependency datastores auto-follow their parent through the orchestrator
-- (soft) or the consumer graph below (hard).

local _, OneWoW = ...

local OneWoW_GUI = OneWoW_GUI

local C_AddOns = C_AddOns
local UnitName = UnitName

OneWoW.FirstRun = OneWoW.FirstRun or {}
local FirstRun = OneWoW.FirstRun

-- Authoritative feature catalog. Each entry:
--   addonName      - the WoW addon folder / TOC name (what DisableAddOn sees)
--   labelKey       - localized display name key
--   summaryKey     - localized short description key
--   group          - "feature" | "standalone" | "utility" - grouping in the UI
--   iconTexture    - card icon texture path (fallback when iconAtlas is absent)
--   iconAtlas      - optional atlas name; takes precedence over iconTexture
--   iconTextCoords - coordinates for cropping or transforming the texture
--   datastores     - list of sibling data addons this feature needs loaded
-- Datastores are "pulled in" if any checked feature needs them.
FirstRun.CATALOG = {
    -- Core features
    {
        addonName   = "OneWoW_AltTracker",
        labelKey    = "WIZARD_FEATURE_ALTTRACKER",
        summaryKey  = "WIZARD_FEATURE_ALTTRACKER_DESC",
        group       = "feature",
        iconTexture = "Interface\\Icons\\Achievement_Guild_ClassyDwarf",
        iconAtlas   = "plunderstorm-glues-queueselector-trio",
        iconTexCoords = {0.27, 0.74, 0.27, 0.70},
        datastores  = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_AltTracker_Character",
            "OneWoW_AltTracker_Collections",
            "OneWoW_AltTracker_Endgame",
            "OneWoW_AltTracker_Accounting",
            "OneWoW_AltTracker_Professions",
            "OneWoW_AltTracker_Auctions",
        },
    },
    {
        addonName   = "OneWoW_Catalog",
        labelKey    = "WIZARD_FEATURE_CATALOG",
        summaryKey  = "WIZARD_FEATURE_CATALOG_DESC",
        group       = "feature",
        iconTexture = "Interface\\Icons\\INV_Misc_Book_11",
        datastores  = {
            "OneWoW_CatalogData_Journal",
            "OneWoW_CatalogData_Quests",
            "OneWoW_CatalogData_Vendors",
            "OneWoW_CatalogData_Tradeskills",
        },
    },
    {
        addonName   = "OneWoW_Notes",
        labelKey    = "WIZARD_FEATURE_NOTES",
        summaryKey  = "WIZARD_FEATURE_NOTES_DESC",
        group       = "feature",
        iconTexture = "Interface\\Icons\\INV_Inscription_Scroll",
        datastores  = {},
    },
    {
        addonName   = "OneWoW_Trackers",
        labelKey    = "WIZARD_FEATURE_TRACKERS",
        summaryKey  = "WIZARD_FEATURE_TRACKERS_DESC",
        group       = "feature",
        iconTexture = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
        datastores  = {},
    },
    {
        addonName   = "OneWoW_QoL",
        labelKey    = "WIZARD_FEATURE_QOL",
        summaryKey  = "WIZARD_FEATURE_QOL_DESC",
        group       = "feature",
        iconTexture = "Interface\\Icons\\INV_Gizmo_RocketBoot_01",
        datastores  = {},
    },

    -- Standalone addons
    {
        addonName   = "OneWoW_Bags",
        labelKey    = "WIZARD_FEATURE_BAGS",
        summaryKey  = "WIZARD_FEATURE_BAGS_DESC",
        group       = "standalone",
        iconTexture = "Interface\\Icons\\INV_Misc_Bag_08",
        datastores  = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_AltTracker_Character",
        },
    },
    {
        addonName   = "OneWoW_ShoppingList",
        labelKey    = "WIZARD_FEATURE_SHOPPINGLIST",
        summaryKey  = "WIZARD_FEATURE_SHOPPINGLIST_DESC",
        group       = "standalone",
        iconTexture = "Interface\\Icons\\INV_Misc_Coin_01",
        datastores  = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_CatalogData_Tradeskills",
        },
    },
    {
        addonName   = "OneWoW_DirectDeposit",
        labelKey    = "WIZARD_FEATURE_DIRECTDEPOSIT",
        summaryKey  = "WIZARD_FEATURE_DIRECTDEPOSIT_DESC",
        group       = "standalone",
        iconTexture = "Interface\\Icons\\INV_Misc_Coin_02",
        datastores  = {},
    },

    -- Utilities
    {
        addonName   = "OneWoW_Utility_DevTool",
        labelKey    = "WIZARD_FEATURE_DEVTOOL",
        summaryKey  = "WIZARD_FEATURE_DEVTOOL_DESC",
        group       = "utility",
        iconTexture = "Interface\\Icons\\INV_Gizmo_02",
        datastores  = {},
    },
}

local DATASTORE_ADDONS = {
    "OneWoW_AltTracker_Storage",    "OneWoW_AltTracker_Character",
    "OneWoW_AltTracker_Collections", "OneWoW_AltTracker_Endgame",
    "OneWoW_AltTracker_Accounting", "OneWoW_AltTracker_Professions",
    "OneWoW_AltTracker_Auctions",
    "OneWoW_CatalogData_Journal",   "OneWoW_CatalogData_Quests",
    "OneWoW_CatalogData_Vendors",   "OneWoW_CatalogData_Tradeskills",
}

-- Loads a feature module and its manifest data stores now, so a reload-free enable
-- arms this session. OneWoW:BringUp loads the whole set (OnAddonLoaded each) before
-- a single OnPlayerLogin pass and a mid-session entering-world catch-up, matching
-- the cold-start orchestrator's ordering.
local function LoadFeatureNow(addonName)
    OneWoW:BringUp(addonName)
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

function FirstRun:GetCurrentSelections(perCharacter)
    local selections = {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        selections[entry.addonName] = OneWoW:IsFeatureWanted(entry.addonName, perCharacter)
    end
    return selections
end

-- Apply the staged selections in `perCharacter` scope.
--
-- `hard == false` (soft, the "Apply" button): writes only OneWoW's opt-out layer,
-- never Blizzard's flag. Unchecked features are opted out (they drop next reload;
-- a loaded one stays this session since WoW can't evict it). Checked features are
-- opted in and, if Blizzard-enabled but not loaded, loaded on the fly + their
-- stores, so the enable arms reload-free. Never reloads.
--
-- `hard == true` (the "Apply & Reload" button): writes Blizzard's enable flags
-- (the only way to truly unload, or to re-enable a Blizzard-disabled unit) and
-- clears the soft opt-out (Blizzard becomes authoritative for these), then prompts
-- a reload. Returns true when a reload was prompted.
function FirstRun:Apply(selections, perCharacter, hard)
    local L = OneWoW.L or {}

    if hard then
        -- Full desired state: features plus the datastores their consumers pull in.
        local datastoreState = ComputeDatastoreState(selections)
        local desired = {}
        for _, entry in ipairs(FirstRun.CATALOG) do
            desired[entry.addonName] = selections[entry.addonName] and true or false
        end
        for _, ds in ipairs(DATASTORE_ADDONS) do
            desired[ds] = datastoreState[ds] and true or false
        end
        for name, want in pairs(desired) do
            OneWoW:SetAddonEnabled(name, want, perCharacter)
            OneWoW:SetFeatureOptOut(name, false, perCharacter)
        end

        StaticPopupDialogs["ONEWOW_MANAGE_FEATURES_RELOAD"] = {
            text = L["WIZARD_RELOAD_TEXT"],
            button1 = L["WIZARD_RELOAD_NOW"],
            button2 = LATER,
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("ONEWOW_MANAGE_FEATURES_RELOAD")
        return true
    end

    -- Soft path: opt-out is per feature; data stores follow their parent through
    -- the orchestrator, so they are not opted out individually here.
    for _, entry in ipairs(FirstRun.CATALOG) do
        local want = selections[entry.addonName] and true or false
        OneWoW:SetFeatureOptOut(entry.addonName, not want, perCharacter)
    end

    -- wizardShown is owned by the "Do not show again" checkbox in BuildPanel,
    -- which writes to the DB on toggle. Apply intentionally does not touch it.

    -- Load any wanted, Blizzard-enabled, not-yet-loaded feature now (reload-free).
    for _, entry in ipairs(FirstRun.CATALOG) do
        local name = entry.addonName
        if selections[name] and OneWoW:IsAddonEnabled(name, perCharacter)
            and not C_AddOns.IsAddOnLoaded(name) then
            LoadFeatureNow(name)
        end
    end
    return false
end

-- Apply a "recommended set": every feature except utility entries. Account-wide,
-- soft (reload-free).
function FirstRun:ApplyRecommended()
    local sel = {}
    for _, entry in ipairs(FirstRun.CATALOG) do
        sel[entry.addonName] = (entry.group ~= "utility")
    end
    self:Apply(sel, false, false)
end

-- Build the Manage Features panel into `parent` (a Frame). This is reused by
-- both the first-run popup and the Settings > Manage Features sub-tab.
--
-- All themed widgets go through OneWoW_GUI helpers so the panel matches the
-- rest of the addon's UI standards: no raw SetBackdrop, no UICheckButtonTemplate.
function FirstRun:BuildPanel(parent, opts)
    local L = OneWoW.L or {}
    local C = OneWoW_GUI.Constants.GUI

    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_ManageFeaturesScroll" })
    content:SetHeight(1)

    -- Scope of every read/write in this panel. First-run defaults to account-wide
    -- (initial setup intent); the Settings sub-tab defaults to the current
    -- character (mirrors Blizzard's addon list). Owned here, read by Apply.
    local perCharacter = not (opts and opts.defaultScope == "all")
    local function ScopeText(pc)
        return pc and UnitName("player") or L["MANAGE_SCOPE_ALL"]
    end

    local selections = FirstRun:GetCurrentSelections(perCharacter)
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
        { text = RECOMMENDED, value = "recommended" },
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
        btn:HookScript("OnEnter", function(myself)
            if not myself.isActive then
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            end
        end)
        btn:HookScript("OnLeave", function(myself) ApplyPresetVisual(myself) end)
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

    -- Two commit buttons: soft "Apply" (reload-free; writes only OneWoW's opt-out)
    -- and hard "Apply & Reload" (writes Blizzard flags + reload). Soft Apply greys
    -- out when the only way to satisfy the edit is a reload (re-enabling a
    -- Blizzard-disabled unit), which the soft path cannot do.
    local btnGap = OneWoW_GUI:GetSpacing("XS")

    local hardApplyBtn = OneWoW_GUI:CreateFitTextButton(actionBar.right, {
        text = L["WIZARD_APPLY_RELOAD"],
        height = 26,
        minWidth = 130,
    })
    hardApplyBtn:SetPoint("TOPRIGHT", actionBar.right, "TOPRIGHT", 0, 0)
    hardApplyBtn._enabled = false
    hardApplyBtn._hasChanges = false
    hardApplyBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        local key
        if myself._enabled then
            key = "WIZARD_APPLY_RELOAD_TOOLTIP"
        elseif myself._hasChanges then
            key = "WIZARD_APPLY_RELOAD_SOFT_ONLY_TOOLTIP"
        else
            key = "WIZARD_APPLY_NO_CHANGES_TOOLTIP"
        end
        GameTooltip:SetText(L[key], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    hardApplyBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local softApplyBtn = OneWoW_GUI:CreateFitTextButton(actionBar.right, {
        text = APPLY,
        height = 26,
        minWidth = 80,
    })
    softApplyBtn:SetPoint("TOPRIGHT", hardApplyBtn, "TOPLEFT", -btnGap, 0)
    softApplyBtn._enabled = false
    softApplyBtn._blocked = false
    softApplyBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        local key
        if not myself._enabled and not myself._blocked then
            key = "WIZARD_APPLY_NO_CHANGES_TOOLTIP"
        elseif not myself._enabled then
            key = "WIZARD_APPLY_BLOCKED_TOOLTIP"
        else
            key = "WIZARD_APPLY_TOOLTIP"
        end
        GameTooltip:SetText(L[key], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    softApplyBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local function SetHardApplyEnabled(enabled)
        hardApplyBtn._enabled = enabled and true or false
        hardApplyBtn:SetAlpha(enabled and 1 or 0.4)
    end

    -- Greys/un-greys the soft Apply button and gates its click.
    local function SetSoftApplyEnabled(enabled, blocked)
        softApplyBtn._enabled = enabled and true or false
        softApplyBtn._blocked = blocked and true or false
        softApplyBtn:SetAlpha(enabled and 1 or 0.4)
    end

    actionBar.right:SetWidth(hardApplyBtn:GetWidth() + btnGap + softApplyBtn:GetWidth())
    actionBar:Refresh()

    -- One row: "Do not show again" on the left, the scope selector on the right
    -- (across from the checkbox). The scope menu is attached later (after the
    -- refresh helpers it drives are defined).
    local initialDontShow = OneWoW.db.global.wizardShown ~= false
    OneWoW.db.global.wizardShown = initialDontShow
    local dontShowRow = OneWoW_GUI:CreateLayoutFrame(content, { height = 28 })
    local dontShowCB = OneWoW_GUI:CreateCheckbox(dontShowRow, {
        label   = L["WIZARD_DONT_SHOW_AGAIN"],
        checked = initialDontShow,
        onClick = function(myself)
            OneWoW.db.global.wizardShown = myself:GetChecked() and true or false
        end,
    })
    dontShowCB:SetPoint("LEFT", dontShowRow, "LEFT", 0, 0)

    local scopeDD, scopeDDText = OneWoW_GUI:CreateDropdown(dontShowRow, {
        width = 180,
        height = 24,
        text = ScopeText(perCharacter),
    })
    scopeDD:SetPoint("RIGHT", dontShowRow, "RIGHT", 0, 0)

    local scopeLabel = dontShowRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(scopeLabel, OneWoW_GUI:GetFont(), 12)
    scopeLabel:SetText(L["MANAGE_SCOPE_LABEL"])
    scopeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    scopeLabel:SetPoint("RIGHT", scopeDD, "LEFT", -8, 0)

    local listContainer = OneWoW_GUI:CreateLayoutFrame(content, {})
    listContainer:SetHeight(1)

    local groupLabels = {
        feature = L["WIZARD_GROUP_FEATURES"],
        standalone = L["HOME_STANDALONE_ADDONS"],
        utility = L["HOME_UTILITIES"],
    }
    local groupOrder  = { "feature", "standalone", "utility" }

    local cards = {}
    -- Assigned after the cards exist; forward-declared so the card onToggle and
    -- preset closures can capture them.
    local RefreshRow, RefreshAllRows, RefreshActions

    local function RefreshSummary()
        summary:SetItemValue(1, format(L["WIZARD_SUMMARY_SELECTED_FORMAT"], CountSelected(), #FirstRun.CATALOG))
        summary:SetItemValue(2, format(L["WIZARD_SUMMARY_DATA_FORMAT"], CountWantedDatastores()))
        summary:SetItemValue(3, HasChanges() and L["WIZARD_SUMMARY_PENDING"] or READY)
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
        RefreshAllRows()
        RefreshActions()
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
                local addon = entry.addonName
                local card = OneWoW_GUI:CreateSelectableCard(listContainer, {
                    title = L[entry.labelKey],
                    summary = L[entry.summaryKey],
                    iconTexture = entry.iconTexture,
                    iconAtlas = entry.iconAtlas,
                    iconSize = entry.iconSize,
                    iconTexCoords = entry.iconTexCoords,
                    checked = selections[addon],
                    onToggle = function(_, checked)
                        selections[addon] = checked and true or false
                        presetButtons.SetActiveByValue("manual")
                        RefreshRow(addon)
                        RefreshActions()
                        RefreshSummary()
                    end,
                })
                card:ClearAllPoints()

                -- Blizzard-style per-row "Load Addon" button. Shown only when the
                -- card is checked + Blizzard-enabled + not yet loaded (RefreshRow).
                -- Clicking loads it reload-free and commits the opt-in for scope.
                local loadBtn = OneWoW_GUI:CreateFitTextButton(card, {
                    text = L["WIZARD_LOAD_ADDON"],
                    height = 20,
                    minWidth = 60,
                    paddingX = 14,
                })
                loadBtn:SetPoint("RIGHT", card.checkbox, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
                loadBtn:Hide()
                loadBtn:HookScript("OnEnter", function(myself)
                    GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                    GameTooltip:SetText(L["WIZARD_LOAD_ADDON_TOOLTIP"], nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end)
                loadBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
                loadBtn:SetScript("OnClick", function()
                    OneWoW:SetFeatureOptOut(addon, false, perCharacter)
                    LoadFeatureNow(addon)
                    originalSelections[addon] = true
                    RefreshRow(addon)
                    RefreshActions()
                    RefreshSummary()
                end)
                card.loadBtn = loadBtn

                cards[addon] = card
                table.insert(listItems, card)
            end
        end
    end

    -- Per-row Load Addon button: checked + Blizzard-enabled + (not loaded or soft-opted-out).
    RefreshRow = function(addonName)
        local card = cards[addonName]
        if not card or not card.loadBtn then return end
        local show = card._checked
            and OneWoW:IsAddonEnabled(addonName, perCharacter)
            and (
                not C_AddOns.IsAddOnLoaded(addonName)
                or OneWoW:IsFeatureOptedOutInScope(addonName, perCharacter)
            )
        card.loadBtn:SetShown(show)
    end

    RefreshAllRows = function()
        for _, entry in ipairs(FirstRun.CATALOG) do
            RefreshRow(entry.addonName)
        end
    end

    -- Commit buttons: soft Apply for opt-out toggles; Apply & Reload when a pending
    -- change needs a Blizzard flag write (hard disable or re-enable). Soft re-enable
    -- alone greys out Apply & Reload; Blizzard-disabled re-enable greys out Apply.
    RefreshActions = function()
        local hasChanges = HasChanges()
        local needsHardApply = false
        local softApplyBlocked = false
        if hasChanges then
            for _, entry in ipairs(FirstRun.CATALOG) do
                local name = entry.addonName
                local want = selections[name] and true or false
                local was = originalSelections[name] and true or false
                if want == was then
                    -- skip unchanged rows
                else
                    local blizz = OneWoW:IsAddonEnabled(name, perCharacter)
                    if want and not blizz then
                        needsHardApply = true
                        softApplyBlocked = true
                    elseif not want and blizz then
                        needsHardApply = true
                    end
                end
            end
        end
        hardApplyBtn._hasChanges = hasChanges
        SetHardApplyEnabled(needsHardApply)
        SetSoftApplyEnabled(hasChanges and not softApplyBlocked, softApplyBlocked)
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
        [1] = mainStackGap,                 -- hero -> summary
        [2] = mainStackGap,                 -- summary -> actionBar
        [3] = OneWoW_GUI:GetSpacing("XS"),  -- actionBar -> dontShowRow
        [4] = OneWoW_GUI:GetSpacing("MD"),  -- dontShowRow -> listContainer
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

    -- Rebase the "original" baseline so HasChanges() reports clean.
    local function RebaseOriginal()
        for _, entry in ipairs(FirstRun.CATALOG) do
            originalSelections[entry.addonName] = selections[entry.addonName] and true or false
        end
    end

    -- Re-read the live enable state for `pc` into the staged selections and push
    -- it onto the cards (each scope can have different per-addon flags).
    local function LoadSelectionsForScope(pc)
        local fresh = FirstRun:GetCurrentSelections(pc)
        for _, entry in ipairs(FirstRun.CATALOG) do
            local want = fresh[entry.addonName] and true or false
            selections[entry.addonName] = want
            if cards[entry.addonName] then
                cards[entry.addonName]:SetChecked(want, true)
            end
        end
        presetButtons.SetActiveByValue("manual")
        RefreshAllRows()
    end

    -- Commit a scope change. keepChanges = carry the staged checkbox intent into
    -- the new scope (rebase baseline to the new scope's live state); otherwise
    -- discard staged edits and reload the new scope's actual state.
    local function SwitchScope(newPC, keepChanges)
        perCharacter = newPC
        if keepChanges then
            RebaseOriginal()
        else
            LoadSelectionsForScope(newPC)
            RebaseOriginal()
        end
        scopeDDText:SetText(ScopeText(newPC))
        RefreshAllRows()
        RefreshActions()
        RefreshSummary()
    end

    local pendingScopePC
    StaticPopupDialogs["ONEWOW_MANAGE_SCOPE_SWITCH"] = {
        text = L["MANAGE_SCOPE_SWITCH_TEXT"],
        button1 = L["KEEP"],
        button2 = L["DISCARD"],
        OnAccept = function()
            if pendingScopePC ~= nil then SwitchScope(pendingScopePC, true) end
            pendingScopePC = nil
        end,
        OnCancel = function()
            if pendingScopePC ~= nil then SwitchScope(pendingScopePC, false) end
            pendingScopePC = nil
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }

    OneWoW_GUI:AttachFilterMenu(scopeDD, {
        searchable = false,
        getActiveValue = function() return perCharacter and "char" or "all" end,
        buildItems = function()
            return {
                { value = "all",  text = L["MANAGE_SCOPE_ALL"] },
                { value = "char", text = UnitName("player") },
            }
        end,
        onSelect = function(value)
            local newPC = (value == "char")
            if newPC == perCharacter then return end
            if HasChanges() then
                pendingScopePC = newPC
                StaticPopup_Show("ONEWOW_MANAGE_SCOPE_SWITCH")
            else
                SwitchScope(newPC, false)
            end
        end,
    })

    softApplyBtn:SetScript("OnClick", function()
        if not softApplyBtn._enabled then return end
        FirstRun:Apply(selections, perCharacter, false)
        RebaseOriginal()
        RefreshAllRows()
        RefreshActions()
        RefreshSummary()
    end)

    hardApplyBtn:SetScript("OnClick", function()
        if not hardApplyBtn._enabled then return end
        FirstRun:Apply(selections, perCharacter, true)
    end)

    RefreshAllRows()
    RefreshActions()
    RefreshSummary()
end

function FirstRun:ShouldShowWizard()
    return not OneWoW.db.global.wizardShown
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

    FirstRun:BuildPanel(result.contentFrame, { defaultScope = "all" })

    dialog:SetFrameStrata("DIALOG")
    dialog:Show()
    dialog:Raise()
end

-- Slash command to re-open the wizard anytime.
SLASH_ONEWOW_WIZARD1 = "/ow-wizard"
SlashCmdList["ONEWOW_WIZARD"] = function()
    FirstRun:ShowWizard()
end

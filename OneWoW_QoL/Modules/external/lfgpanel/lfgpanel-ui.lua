-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/lfgpanel/lfgpanel-ui.lua
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local LFGPanel = ns.LFGPanel
local state = ns.LFGState
local GetFilterResults = ns.LFGGetFilterResults

local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER

ns.LFGPanelUI = {}
local LFGPanelUI = ns.LFGPanelUI

local LOCKOUT_HEIGHT = 40
local HEADER_HEIGHT = 30

local function GetFactionTheme()
    return (OneWoW_GUI and OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"
end

local function ApplyFont(fontString, size, flags)
    local fontPath = OneWoW_GUI:GetFont()
    if fontPath then
        fontString:SetFont(fontPath, size, flags or "")
    end
end

function LFGPanelUI:CreateDialog()
    if state.dialog then return state.dialog end
    if not PVEFrame then return nil end

    local L = ns.L

    local panel = OneWoW_GUI:CreateFrame(
        "OneWoW_QoL_LFGDialog", PVEFrame, 300, 500, BACKDROP_INNER
    )
    panel:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 3, 0)
    panel:SetFrameStrata("FULLSCREEN")
    panel:EnableMouse(true)
    panel:Hide()

    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local titleBar = OneWoW_GUI:CreateTitleBar(panel, {
        title = L["LFGPANEL_DIALOG_TITLE"],
        showBrand = true,
        factionTheme = GetFactionTheme(),
        onClose = function()
            LFGPanel:SetManuallyHidden(true)
        end,
    })

    local controlBar = OneWoW_GUI:CreateFilterBar(panel, {
        height = 60,
        anchorBelow = titleBar,
        offset = -1,
    })

    local filterLabel = controlBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", controlBar, "TOPLEFT", 8, -8)
    filterLabel:SetText(L["LFGPANEL_FILTER_DIFFICULTY"])
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    ApplyFont(filterLabel, 10)

    local filterDropdown, dropText = OneWoW_GUI:CreateDropdown(controlBar, {
        height = 22,
        text = L["LFGPANEL_DIFFICULTY_ALL"],
    })
    filterDropdown:SetPoint("LEFT", filterLabel, "RIGHT", 6, 0)
    filterDropdown:SetPoint("RIGHT", controlBar, "RIGHT", -8, 0)

    local function buildDifficultyItems()
        local items = {}
        table.insert(items, { type = "item", text = L["LFGPANEL_DIFFICULTY_ALL"], value = "all" })
        for _, opt in ipairs(ns.LFGDifficultyOptions) do
            table.insert(items, { type = "item", text = L[opt.label], value = opt.key })
        end
        return items
    end

    OneWoW_GUI:AttachFilterMenu(filterDropdown, {
        searchable = false,
        menuHeight = 200,
        maxVisible = 10,
        getActiveValue = function()
            if state.filterActive and state.filterDifficultyId then
                return state.filterDifficultyId
            end
            return "all"
        end,
        buildItems = buildDifficultyItems,
        onSelect = function(value, text)
            if value == "all" then
                LFGPanel:ClearFilter()
                dropText:SetText(L["LFGPANEL_DIFFICULTY_ALL"])
            else
                LFGPanel:SetFilter(value)
                dropText:SetText(text)
            end
            self:UpdateDisplay()
            LFGPanel:FilterSearchResults()
        end,
    })

    local filterCB = OneWoW_GUI:CreateCheckbox(controlBar, { name = "OneWoW_QoL_LFGFilterCB", label = L["LFGPANEL_OPT_FILTER_LFG"] })
    filterCB:SetPoint("TOPLEFT", controlBar, "TOPLEFT", 6, -32)
    filterCB:SetChecked(GetFilterResults())
    if filterCB.label then ApplyFont(filterCB.label, 11) end
    filterCB:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        ns.ModuleRegistry:SetToggleValue("lfgpanel", "filter_results", checked)
        if not checked then
            if LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsVisible() then
                if _G.LFGListSearchPanel_UpdateResultList then
                    LFGListSearchPanel_UpdateResultList(LFGListFrame.SearchPanel)
                end
            end
        else
            LFGPanel:FilterSearchResults()
        end
    end)
    filterCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["LFGPANEL_TT_FILTER_LFG"], 1, 0.82, 0)
        GameTooltip:AddLine(L["LFGPANEL_TT_FILTER_LFG_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    filterCB:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", controlBar, "BOTTOMLEFT", 0, -4)
    scrollContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 38)

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(scrollContainer, { name = "OneWoW_QoL_LFGScroll" })
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 0)

    local refreshBtn = OneWoW_GUI:CreateFitTextButton(panel, {
        text = L["LFGPANEL_REFRESH"],
        height = 22,
        minWidth = 80,
        padding = 16,
    })
    refreshBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
    refreshBtn:SetScript("OnClick", function()
        RequestRaidInfo()
        C_Timer.After(0.5, function()
            self:UpdateDisplay()
        end)
    end)
    refreshBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetText(L["LFGPANEL_TT_REFRESH"], 1, 0.82, 0)
        GameTooltip:AddLine(L["LFGPANEL_TT_REFRESH_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    panel.titleBar = titleBar
    panel.controlBar = controlBar
    panel.filterDropdown = filterDropdown
    panel.filterCB = filterCB
    panel.scrollFrame = scrollFrame
    panel.scrollContent = scrollContent
    panel.lockoutFrames = {}

    panel:SetScript("OnShow", function()
        self:SyncDialogHeight()
        if titleBar.brandIcon then titleBar.brandIcon:SetTexture(OneWoW_GUI:GetBrandIcon(GetFactionTheme())) end
        filterCB:SetChecked(GetFilterResults())
        RequestRaidInfo()
        C_Timer.After(0.3, function()
            self:UpdateDisplay()
        end)
    end)

    state.dialog = panel
    return panel
end

function LFGPanelUI:SyncDialogHeight()
    if not state.dialog or not PVEFrame then return end
    state.dialog:SetHeight(PVEFrame:GetHeight())
end

function LFGPanelUI:CreateToggleButton()
    if state.toggleButton then return state.toggleButton end
    if not PVEFrame then return nil end

    local L = ns.L

    local btn = OneWoW_GUI:CreateFitTextButton(PVEFrame, {
        text = "L",
        height = 28,
        minWidth = 28,
        padding = 0,
    })
    btn:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 5, -28)
    btn:SetFrameLevel(PVEFrame:GetFrameLevel() + 10)
    btn:Hide()

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetAtlas("UI-HUD-MicroMenu-StreamDeck-Up")

    if btn.text then btn.text:SetText("") end

    btn:SetScript("OnClick", function()
        LFGPanel:SetManuallyHidden(false)
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["LFGPANEL_TT_TOGGLE"], 1, 0.82, 0)
        GameTooltip:AddLine(L["LFGPANEL_TT_TOGGLE_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    state.toggleButton = btn
    return btn
end

function LFGPanelUI:CreateLockoutRow(parent, lockout, yOffset)
    local L = ns.L

    local topRow = OneWoW_GUI:CreateListRowBasic(parent, {
        height = LOCKOUT_HEIGHT,
        label = lockout.name,
    })
    topRow:ClearAllPoints()
    topRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    topRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    topRow:Disable()

    local dR, dG, dB = LFGPanel:GetDifficultyColor(lockout.difficultyId)
    topRow.label:ClearAllPoints()
    topRow.label:SetPoint("TOPLEFT", topRow, "TOPLEFT", 10, -5)
    topRow.label:SetPoint("TOPRIGHT", topRow, "TOPRIGHT", -60, -5)
    topRow.label:SetJustifyH("LEFT")
    topRow.label:SetWordWrap(false)
    topRow.label:SetTextColor(dR, dG, dB, 1)
    ApplyFont(topRow.label, 12)

    if lockout.isRaid and lockout.numEncounters > 0 then
        topRow.progressText = topRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        topRow.progressText:SetPoint("TOPRIGHT", topRow, "TOPRIGHT", -10, -5)
        topRow.progressText:SetText(string.format(L["LFGPANEL_PROGRESS"], lockout.encounterProgress, lockout.numEncounters))
        topRow.progressText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        ApplyFont(topRow.progressText, 10)
    end

    topRow.difficultyText = topRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    topRow.difficultyText:SetPoint("BOTTOMLEFT", topRow, "BOTTOMLEFT", 10, 5)
    topRow.difficultyText:SetText(LFGPanel:GetDifficultyLabel(lockout.difficultyId))
    topRow.difficultyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    ApplyFont(topRow.difficultyText, 10)

    topRow.timeText = topRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    topRow.timeText:SetPoint("BOTTOMRIGHT", topRow, "BOTTOMRIGHT", -10, 5)
    topRow.timeText:SetText(LFGPanel:FormatTimeRemaining(lockout.timeLeft))
    local acR, acG, acB = OneWoW_GUI:GetThemeColor("TEXT_ACCENT")
    topRow.timeText:SetTextColor(acR, acG, acB, 1)
    ApplyFont(topRow.timeText, 10)

    if lockout.extended then
        topRow.extendedIcon = topRow:CreateTexture(nil, "OVERLAY")
        topRow.extendedIcon:SetSize(14, 14)
        topRow.extendedIcon:SetAtlas("UI-HUD-MicroMenu-Highlightalert")
        topRow.extendedIcon:SetPoint("LEFT", topRow.difficultyText, "RIGHT", 2, 0)
    end

    local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_SECONDARY")
    topRow:EnableMouse(true)
    topRow:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(lockout.name, dR, dG, dB)
        GameTooltip:AddLine(string.format(L["LFGPANEL_TT_LOCKOUT_DIFFICULTY"],
            LFGPanel:GetDifficultyLabel(lockout.difficultyId)), 1, 1, 1)
        if lockout.isRaid and lockout.numEncounters > 0 then
            GameTooltip:AddLine(string.format(L["LFGPANEL_TT_LOCKOUT_PROGRESS"],
                lockout.encounterProgress, lockout.numEncounters), 1, 1, 1)
            for ei = 1, lockout.numEncounters do
                local bossName, _, isKilled = GetSavedInstanceEncounterInfo(lockout.index, ei)
                if bossName then
                    if isKilled then
                        GameTooltip:AddLine("  " .. bossName, 0.5, 0.5, 0.5)
                    else
                        GameTooltip:AddLine("  " .. bossName, 0.0, 1.0, 0.0)
                    end
                end
            end
        end
        GameTooltip:AddLine(string.format(L["LFGPANEL_TT_LOCKOUT_TIME"],
            LFGPanel:FormatTimeRemaining(lockout.timeLeft)), acR, acG, acB)
        if lockout.extended then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["LFGPANEL_TT_EXTENDED"], 1, 0.82, 0)
            GameTooltip:AddLine(L["LFGPANEL_TT_EXTENDED_DESC"], 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    topRow:SetScript("OnLeave", function(self)
        self:SetBackdropColor(bgR, bgG, bgB)
        GameTooltip:Hide()
    end)

    return topRow
end

function LFGPanelUI:UpdateDisplay()
    if not state.dialog or not state.dialog:IsShown() then return end

    local L = ns.L
    local scrollContent = state.dialog.scrollContent
    if not scrollContent then return end

    for _, frame in ipairs(state.dialog.lockoutFrames) do
        frame:Hide()
        frame:SetParent(nil)
    end
    wipe(state.dialog.lockoutFrames)

    if scrollContent.emptyText then
        scrollContent.emptyText:Hide()
    end

    local lockouts = LFGPanel:GetCurrentLockouts()

    if #lockouts == 0 then
        if not scrollContent.emptyText then
            scrollContent.emptyText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            scrollContent.emptyText:SetPoint("TOP", scrollContent, "TOP", 0, -20)
            ApplyFont(scrollContent.emptyText, 12)
        end
        if state.filterActive then
            scrollContent.emptyText:SetText(L["LFGPANEL_NO_LOCKOUTS_FILTERED"])
        else
            scrollContent.emptyText:SetText(L["LFGPANEL_NO_LOCKOUTS"])
        end
        scrollContent.emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        scrollContent.emptyText:Show()
        scrollContent:SetHeight(100)
        return
    end

    local raids = {}
    local dungeons = {}

    for _, lockout in ipairs(lockouts) do
        if lockout.isRaid then
            table.insert(raids, lockout)
        else
            table.insert(dungeons, lockout)
        end
    end

    local yOffset = -5

    if #raids > 0 then
        local header = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = L["LFGPANEL_CATEGORY_RAIDS"], yOffset = yOffset })
        table.insert(state.dialog.lockoutFrames, header)
        yOffset = yOffset - (HEADER_HEIGHT + 4)

        for _, lockout in ipairs(raids) do
            local row = self:CreateLockoutRow(scrollContent, lockout, yOffset)
            table.insert(state.dialog.lockoutFrames, row)
            yOffset = yOffset - (LOCKOUT_HEIGHT + 3)
        end

        yOffset = yOffset - 6
    end

    if #dungeons > 0 then
        local header = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = L["LFGPANEL_CATEGORY_DUNGEONS"], yOffset = yOffset })
        table.insert(state.dialog.lockoutFrames, header)
        yOffset = yOffset - (HEADER_HEIGHT + 4)

        for _, lockout in ipairs(dungeons) do
            local row = self:CreateLockoutRow(scrollContent, lockout, yOffset)
            table.insert(state.dialog.lockoutFrames, row)
            yOffset = yOffset - (LOCKOUT_HEIGHT + 3)
        end
    end

    scrollContent:SetHeight(math.abs(yOffset) + 10)
end

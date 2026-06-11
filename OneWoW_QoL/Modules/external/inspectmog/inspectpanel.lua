-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/inspectmog/inspectpanel.lua
--
-- GUI-First side panel for the Inspect Gear module. Built from OneWoW_GUI
-- components (frame, title bar, scroll frame, list rows, fit-text button) and
-- anchored to the right edge of Blizzard's Inspect frame.
local addonName, ns = ...

local OneWoW_GUI = OneWoW_GUI

local C = OneWoW_GUI.Constants

local ROW_HEIGHT = 34
local PANEL_WIDTH = 280
local FALLBACK_ICON = 134400 -- "inv_misc_questionmark" file ID

ns.InspectMogUI = {}
local UI = ns.InspectMogUI

local function ApplyFont(fontString, size)
    local fontPath = OneWoW_GUI:GetFont()
    if fontPath then
        fontString:SetFont(fontPath, size, "")
    end
end

-- Result code -> locale key for the status line.
local STATUS_KEY = {
    [ns.InspectMog.Result.SAVED]         = "INSPECTMOG_STATUS_NOTE_SAVED",
    [ns.InspectMog.Result.UPDATED]       = "INSPECTMOG_STATUS_NOTE_UPDATED",
    [ns.InspectMog.Result.ITEM_ADDED]    = "INSPECTMOG_STATUS_ITEM_ADDED",
    [ns.InspectMog.Result.NOTES_MISSING] = "INSPECTMOG_STATUS_NOTES_MISSING",
    [ns.InspectMog.Result.NO_DATA]       = "INSPECTMOG_STATUS_NO_DATA",
}

function UI:SetStatus(ok, resultCode, arg)
    if not self.panel then
        return
    end
    local key = STATUS_KEY[resultCode]
    if not key then
        self.panel.status:SetText("")
        return
    end

    self.panel.status:SetText(string.format(ns.L[key], arg or ""))
    if ok then
        self.panel.status:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        self.panel.status:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    end

    self._statusToken = (self._statusToken or 0) + 1
    local token = self._statusToken
    C_Timer.After(4, function()
        if self.panel and self._statusToken == token then
            self.panel.status:SetText("")
        end
    end)
end

function UI:OnRowClick(row)
    local data = row.data
    if not data or not data.itemLink then
        return
    end

    if IsControlKeyDown() then
        local ok, result, label = ns.InspectMog:AddItemToNotes(data, self.playerName)
        self:SetStatus(ok, result, label)
    elseif IsShiftKeyDown() then
        ChatEdit_InsertLink(data.itemLink)
    else
        DressUpItemLink(data.itemLink)
    end
end

function UI:OnAddToPlayerNote()
    local ok, result, name = ns.InspectMog:SaveSnapshotToPlayerNote(self.snapshot)
    self:SetStatus(ok, result, name)
end

function UI:GetPanel()
    if self.panel then
        return self.panel
    end
    if not InspectFrame then
        return nil
    end

    local L = ns.L

    local panel = OneWoW_GUI:CreateFrame(InspectFrame, {
        name = "OneWoW_QoL_InspectMogPanel",
        width = PANEL_WIDTH,
        height = 400,
        backdrop = C.BACKDROP_INNER,
    })
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", InspectFrame, "TOPRIGHT", 4, 0)
    panel:SetPoint("BOTTOMLEFT", InspectFrame, "BOTTOMRIGHT", 4, 0)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    panel:SetFrameStrata(InspectFrame:GetFrameStrata())
    panel:SetFrameLevel(InspectFrame:GetFrameLevel() + 5)

    local titleBar = OneWoW_GUI:CreateTitleBar(panel, {
        title = L["INSPECTMOG_TITLE"],
        showBrand = true,
        onClose = function()
            UI:Hide()
        end,
    })
    panel.titleBar = titleBar

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -4)
    subtitle:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -10, -4)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)
    subtitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    ApplyFont(subtitle, 11)
    panel.subtitle = subtitle

    local addBtn = OneWoW_GUI:CreateFitTextButton(panel, {
        text = L["INSPECTMOG_ADD_NOTE"],
        height = 22,
        minWidth = 120,
        padding = 16,
    })
    addBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
    addBtn:SetScript("OnClick", function()
        UI:OnAddToPlayerNote()
    end)
    addBtn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["INSPECTMOG_TT_ADD_NOTE_TITLE"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:AddLine(L["INSPECTMOG_TT_ADD_NOTE_DESC"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    addBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    panel.addBtn = addBtn

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOMLEFT", addBtn, "TOPLEFT", 0, 4)
    status:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
    status:SetJustifyH("CENTER")
    status:SetWordWrap(true)
    ApplyFont(status, 10)
    panel.status = status

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
    scrollContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 60)

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(scrollContainer, {
        name = "OneWoW_QoL_InspectMogScroll",
    })
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 0)
    panel.scrollContent = scrollContent
    panel.rows = {}

    panel:Hide()
    self.panel = panel
    return panel
end

function UI:GetRow(index)
    local panel = self.panel
    local row = panel.rows[index]
    if row then
        return row
    end

    row = OneWoW_GUI:CreateListRowBasic(panel.scrollContent, { height = ROW_HEIGHT })
    row:RegisterForClicks("AnyUp")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 8, ROW_HEIGHT - 8)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

    row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.slot:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -2)
    row.slot:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.slot:SetJustifyH("LEFT")
    row.slot:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    ApplyFont(row.slot, 9)

    row.label:ClearAllPoints()
    row.label:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 2)
    row.label:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    ApplyFont(row.label, 11)

    local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_SECONDARY")
    row:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        local data = myself.data
        if not data or not data.itemLink then
            return
        end
        local L = ns.L
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(data.itemLink)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["INSPECTMOG_TT_PREVIEW"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:AddLine(L["INSPECTMOG_TT_CHAT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:AddLine(L["INSPECTMOG_TT_NOTES"], OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(myself)
        myself:SetBackdropColor(bgR, bgG, bgB)
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(myself)
        UI:OnRowClick(myself)
    end)

    panel.rows[index] = row
    return row
end

function UI:Refresh()
    if not self.panel or not self.panel:IsShown() then
        return
    end

    local L = ns.L
    local unit = ns.InspectMog:GetUnit()
    local snapshot = unit and ns.InspectMog:BuildSnapshot(unit) or nil
    self.snapshot = snapshot
    self.playerName = snapshot and snapshot.name or nil

    if not snapshot or #snapshot.rows == 0 then
        self.panel.subtitle:SetText(L["INSPECTMOG_EMPTY"])
        for _, row in ipairs(self.panel.rows) do
            row:Hide()
        end
        self.panel.scrollContent:SetHeight(60)
        return
    end

    self.panel.subtitle:SetText(snapshot.name or "")

    local yOffset = -2
    for i, data in ipairs(snapshot.rows) do
        local row = self:GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.panel.scrollContent, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", self.panel.scrollContent, "TOPRIGHT", 0, yOffset)
        row.data = data
        row.slot:SetText(data.slotName)
        row.label:SetText(data.itemLink)
        row.icon:SetTexture(data.texture or FALLBACK_ICON)
        row:Show()
        yOffset = yOffset - (ROW_HEIGHT + 2)
    end

    for i = #snapshot.rows + 1, #self.panel.rows do
        self.panel.rows[i]:Hide()
    end

    self.panel.scrollContent:SetHeight(math.max(60, #snapshot.rows * (ROW_HEIGHT + 2) + 4))
end

function UI:Show()
    local panel = self:GetPanel()
    if not panel then
        return
    end
    panel:Show()
    self:Refresh()
end

function UI:Hide()
    if self.panel then
        self.panel:Hide()
    end
end

function UI:IsShown()
    return self.panel ~= nil and self.panel:IsShown()
end

local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = ns.L
local Helpers = ns.ProfPanelHelpers
local ProfPanelUI = {}
ns.ProfPanelUI = ProfPanelUI

local PANEL_WIDTH = 340
local PANEL_HEIGHT = 650
local ROW_HEIGHT_COLLAPSED = 48
local ROW_HEIGHT_EXPANDED = 110
local ROW_GAP = 4
local ALTS_HEIGHT = 100
local BAR_HEIGHT = 12
local DETAIL_HEIGHT = 50

local function PositionPanel(panel)
    local profFrame = ProfessionsFrame or TradeSkillFrame
    if profFrame and profFrame:IsVisible() then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", profFrame, "TOPRIGHT", 5, 0)
    else
        panel:ClearAllPoints()
        panel:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    end
end

function ProfPanelUI:CreatePanel()
    local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
    local borderR, borderG, borderB = OneWoW_GUI:GetThemeColor("BORDER_DEFAULT")

    local panel = CreateFrame("Frame", "OneWoW_QoL_ProfessionStatsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    panel:SetBackdropColor(bgR, bgG, bgB, 0.95)
    panel:SetBackdropBorderColor(borderR, borderG, borderB, 1)
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("MEDIUM")

    PositionPanel(panel)

    local titleBar = OneWoW_GUI:CreateTitleBar(panel, L["PROFPANEL_STATS_TITLE"], {
        height = 28,
        showBrand = true,
        factionTheme = "neutral",
        onClose = function()
            if ns.ProfPanelModule then
                ns.ProfPanelModule._panel.manuallyHidden = true
                ns.ProfPanelModule._panel:Hide()
                ns.ProfPanelModule:UpdateToggleButton()
            end
        end,
    })
    panel.titleBar = titleBar

    local accentR, accentG, accentB = OneWoW_GUI:GetThemeColor("TEXT_ACCENT")
    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", titleBar, "BOTTOM", 0, -4)
    subtitle:SetTextColor(accentR, accentG, accentB, 1)
    panel.subtitle = subtitle

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -52)
    scrollContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, ALTS_HEIGHT + 12)
    scrollContainer:SetClipsChildren(true)
    panel.scrollContainer = scrollContainer

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame("OneWoW_QoL_ProfPanel_Scroll", scrollContainer)
    scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 8, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -8, 0)
    OneWoW_GUI:StyleScrollBar(scrollFrame, { container = scrollContainer, offset = -4 })
    panel.scrollFrame = scrollFrame
    panel.scrollChild = scrollChild

    local altsBgR, altsBgG, altsBgB = OneWoW_GUI:GetThemeColor("BG_SECONDARY")
    local altsBorderR, altsBorderG, altsBorderB = OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")

    local altsFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    altsFrame:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 6)
    altsFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    altsFrame:SetHeight(ALTS_HEIGHT)
    altsFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    altsFrame:SetBackdropColor(altsBgR, altsBgG, altsBgB, 0.8)
    altsFrame:SetBackdropBorderColor(altsBorderR, altsBorderG, altsBorderB, 1)
    altsFrame:SetClipsChildren(true)
    panel.altsFrame = altsFrame

    local altsTitle = altsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    altsTitle:SetPoint("TOPLEFT", altsFrame, "TOPLEFT", 8, -8)
    altsTitle:SetText(L["PROFPANEL_OTHER_ALTS"])
    altsTitle:SetTextColor(accentR, accentG, accentB, 1)
    altsFrame.title = altsTitle

    local mutedR, mutedG, mutedB = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
    local altsText = altsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    altsText:SetPoint("TOPLEFT", altsTitle, "BOTTOMLEFT", 0, -4)
    altsText:SetPoint("BOTTOMRIGHT", altsFrame, "BOTTOMRIGHT", -8, 8)
    altsText:SetJustifyH("LEFT")
    altsText:SetJustifyV("TOP")
    altsText:SetText(L["PROFPANEL_NO_ALT_DATA"])
    altsText:SetTextColor(mutedR, mutedG, mutedB, 1)
    altsFrame.text = altsText

    panel.manuallyHidden = false
    panel._rows = {}
    panel:Hide()
    return panel
end

function ProfPanelUI:CreateExpansionRow(parent, expansion, index)
    local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_TERTIARY")
    local hoverR, hoverG, hoverB = OneWoW_GUI:GetThemeColor("BG_HOVER")
    local textR, textG, textB = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT_COLLAPSED)
    row.isExpanded = false
    row.expansion = expansion
    row.index = index

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(bgR, bgG, bgB, 0.6)
    row.bg = bg

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(hoverR, hoverG, hoverB, 0.8)
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(bgR, bgG, bgB, 0.6)
    end)
    row:SetScript("OnClick", function(self)
        self.isExpanded = not self.isExpanded
        ProfPanelUI:ToggleExpansion(self)
    end)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -6)
    nameText:SetText(expansion.name or "Unknown")
    nameText:SetTextColor(textR, textG, textB, 1)
    row.nameText = nameText

    local countR, countG, countB = Helpers.GetRecipeCountColor(expansion.learned, expansion.total)
    local recipeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recipeText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -6)
    row.recipeText = recipeText

    if expansion.firstCraft > 0 then
        local fcText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fcText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -6)
        fcText:SetText(string.format("FC:|cffff8800%d|r", expansion.firstCraft))
        row.fcText = fcText

        recipeText:ClearAllPoints()
        recipeText:SetPoint("RIGHT", fcText, "LEFT", -8, 0)
    end

    recipeText:SetText(string.format("|cff%02x%02x%02x%d/%d|r", countR * 255, countG * 255, countB * 255, expansion.learned, expansion.total))

    if expansion.maxSkill > 0 then
        local bar = OneWoW_GUI:CreateProgressBar(row, {
            min = 0,
            max = expansion.maxSkill,
            value = expansion.currentSkill,
            height = BAR_HEIGHT,
        })
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 6)
        bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 6)
        row.progressBar = bar
        row.skillText = bar._text
    end

    row.detailsFrame = nil
    return row
end

function ProfPanelUI:CreateDetailsFrame(row)
    local expansion = row.expansion
    local detailsBgR, detailsBgG, detailsBgB = OneWoW_GUI:GetThemeColor("BG_SECONDARY")
    local mutedR, mutedG, mutedB = OneWoW_GUI:GetThemeColor("TEXT_MUTED")

    local details = CreateFrame("Frame", nil, row)
    details:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -26)
    details:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -26)
    details:SetHeight(DETAIL_HEIGHT)

    local bg = details:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(details)
    bg:SetColorTexture(detailsBgR, detailsBgG, detailsBgB, 0.7)

    local missing = expansion.total - expansion.learned
    local valOffset = 70

    local totalLabel = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalLabel:SetPoint("TOPLEFT", details, "TOPLEFT", 10, -8)
    totalLabel:SetText("Total:")
    totalLabel:SetTextColor(mutedR, mutedG, mutedB, 1)

    local totalVal = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalVal:SetPoint("LEFT", totalLabel, "LEFT", valOffset, 0)
    totalVal:SetText(tostring(expansion.total))
    totalVal:SetTextColor(0.7, 0.7, 0.9, 1)

    local knownLabel = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    knownLabel:SetPoint("TOPLEFT", details, "TOP", 0, -8)
    knownLabel:SetText("Known:")
    knownLabel:SetTextColor(mutedR, mutedG, mutedB, 1)

    local knownVal = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    knownVal:SetPoint("LEFT", knownLabel, "LEFT", valOffset, 0)
    knownVal:SetText(tostring(expansion.learned))
    knownVal:SetTextColor(0.4, 1, 0.4, 1)

    local missingLabel = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    missingLabel:SetPoint("TOPLEFT", totalLabel, "BOTTOMLEFT", 0, -4)
    missingLabel:SetText("Missing:")
    missingLabel:SetTextColor(mutedR, mutedG, mutedB, 1)

    local missingVal = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    missingVal:SetPoint("LEFT", missingLabel, "LEFT", valOffset, 0)
    missingVal:SetText(tostring(missing))
    missingVal:SetTextColor(1, 0.5, 0.5, 1)

    local fcLabel = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fcLabel:SetPoint("TOPLEFT", knownLabel, "BOTTOMLEFT", 0, -4)
    fcLabel:SetText("First Craft:")
    fcLabel:SetTextColor(mutedR, mutedG, mutedB, 1)

    local fcVal = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fcVal:SetPoint("LEFT", fcLabel, "LEFT", valOffset, 0)
    fcVal:SetText(tostring(expansion.firstCraft))
    if expansion.firstCraft > 0 then
        fcVal:SetTextColor(1, 0.8, 0.2, 1)
    else
        fcVal:SetTextColor(mutedR, mutedG, mutedB, 1)
    end

    return details
end

function ProfPanelUI:ToggleExpansion(row)
    if row.isExpanded then
        if not row.detailsFrame then
            row.detailsFrame = self:CreateDetailsFrame(row)
        end
        row.detailsFrame:Show()
        row:SetHeight(ROW_HEIGHT_EXPANDED)
    else
        if row.detailsFrame then
            row.detailsFrame:Hide()
        end
        row:SetHeight(ROW_HEIGHT_COLLAPSED)
    end
    self:LayoutRows(row:GetParent())
end

function ProfPanelUI:LayoutRows(scrollChild)
    local yOffset = 0
    local rows = scrollChild._rows or {}
    for _, row in ipairs(rows) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
            yOffset = yOffset + row:GetHeight() + ROW_GAP
        end
    end
    scrollChild:SetHeight(math.max(yOffset, 1))
end

function ProfPanelUI:UpdatePanel(panel, profName, expansionData, altData, hasMore, totalAlts)
    PositionPanel(panel)
    panel.subtitle:SetText(profName)

    local scrollChild = panel.scrollChild

    if scrollChild._rows then
        for _, row in ipairs(scrollChild._rows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    scrollChild._rows = {}

    if not expansionData or #expansionData == 0 then
        local mutedR, mutedG, mutedB = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
        local noData = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noData:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -10)
        noData:SetText(L["PROFPANEL_NO_EXPANSION_DATA"])
        noData:SetTextColor(mutedR, mutedG, mutedB, 1)
        scrollChild:SetHeight(60)
        return
    end

    for i, expansion in ipairs(expansionData) do
        local row = self:CreateExpansionRow(scrollChild, expansion, i)
        table.insert(scrollChild._rows, row)
    end

    self:LayoutRows(scrollChild)
    self:UpdateAlts(panel, altData, hasMore, totalAlts)
end

function ProfPanelUI:UpdateAlts(panel, altData, hasMore, totalAlts)
    local altsFrame = panel.altsFrame
    if not altsFrame then return end

    if altsFrame._altElements then
        for _, elem in ipairs(altsFrame._altElements) do
            elem:Hide()
            elem:SetParent(nil)
        end
    end
    altsFrame._altElements = {}

    local mutedR, mutedG, mutedB = OneWoW_GUI:GetThemeColor("TEXT_MUTED")

    if not altData or #altData == 0 then
        altsFrame.text:SetText(L["PROFPANEL_NO_ALT_DATA"])
        altsFrame.text:SetTextColor(mutedR, mutedG, mutedB, 1)
        altsFrame.text:Show()
        return
    end

    altsFrame.text:Hide()

    local startY = -26
    local rowH = 18
    local leftX = 8
    local rightX = (PANEL_WIDTH - 12) / 2 + 4
    local maxPerCol = 3

    for i, alt in ipairs(altData) do
        local col = (i <= maxPerCol) and 0 or 1
        local rowIdx = (i <= maxPerCol) and (i - 1) or (i - maxPerCol - 1)
        local xPos = (col == 0) and leftX or rightX
        local yPos = startY - rowIdx * rowH

        local frame = self:CreateAltEntry(altsFrame, alt, xPos, yPos)
        table.insert(altsFrame._altElements, frame)
    end

    if hasMore then
        local usedRows = math.max(math.min(#altData, maxPerCol), #altData > maxPerCol and (#altData - maxPerCol) or 0)
        local moreY = startY - usedRows * rowH - 2
        local moreFrame = CreateFrame("Frame", nil, altsFrame)
        moreFrame:SetSize(PANEL_WIDTH - 24, 14)
        moreFrame:SetPoint("TOPLEFT", altsFrame, "TOPLEFT", leftX, moreY)
        local fs = moreFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints()
        fs:SetText(string.format("... and %d more", totalAlts - #altData))
        fs:SetTextColor(mutedR, mutedG, mutedB, 1)
        fs:SetJustifyH("LEFT")
        table.insert(altsFrame._altElements, moreFrame)
    end
end

function ProfPanelUI:CreateAltEntry(parent, alt, xOffset, yOffset)
    local mutedR, mutedG, mutedB = OneWoW_GUI:GetThemeColor("TEXT_MUTED")

    local frame = CreateFrame("Button", nil, parent)
    frame:SetHeight(16)
    frame:SetWidth((PANEL_WIDTH - 24) / 2)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

    local classColor = "|cffffffff"
    if alt.class then
        local color = C_ClassColor.GetClassColor(alt.class)
        if color then
            classColor = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
        end
    end

    local skillStr = ""
    if alt.skillLevel and alt.maxSkill and alt.maxSkill > 0 then
        skillStr = string.format(" |cff%02x%02x%02x%d/%d|r", mutedR * 255, mutedG * 255, mutedB * 255, alt.skillLevel, alt.maxSkill)
    elseif alt.skillLevel and alt.skillLevel > 0 then
        skillStr = string.format(" |cff%02x%02x%02x%d|r", mutedR * 255, mutedG * 255, mutedB * 255, alt.skillLevel)
    end

    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", frame, "LEFT", 0, 0)
    fs:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(classColor .. alt.name .. "|r" .. skillStr)

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(alt.name .. " - " .. (alt.realm or ""), 1, 1, 1)
        if alt.skillLevel and alt.maxSkill then
            GameTooltip:AddLine(string.format("Skill: %d/%d", alt.skillLevel, alt.maxSkill), 0.8, 0.8, 0.8)
        end
        if alt.lastScan and alt.lastScan > 0 then
            GameTooltip:AddLine(string.format(L["PROFPANEL_LAST_SCANNED"], Helpers.FormatTimeSince(time() - alt.lastScan)), 0.6, 0.6, 0.6)
        elseif alt.lastUpdate and alt.lastUpdate > 0 then
            GameTooltip:AddLine(string.format(L["PROFPANEL_LAST_SCANNED"], Helpers.FormatTimeSince(time() - alt.lastUpdate)), 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    return frame
end

-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/professionspanel/professionspanel.lua
local addonName, ns = ...

local ProfPanelModule = {
    id          = "professionspanel",
    title       = "PROFPANEL_TITLE",
    category    = "INTERFACE",
    description = "PROFPANEL_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {
        { id = "auto_show", label = "PROFPANEL_AUTO_SHOW", default = true },
    },
    defaultEnabled = true,
    _panel           = nil,
    _toggleButton    = nil,
    _eventFrame      = nil,
    _currentProf     = nil,
    _pendingOpen     = false,
}

local L = ns.L

local function GetRecipeCountColor(learned, total)
    if total == 0 then return "888888" end
    local percent = learned / total
    if percent >= 1.0 then
        return "00ff00"
    elseif percent >= 0.75 then
        return "88ff00"
    elseif percent >= 0.5 then
        return "ffff00"
    elseif percent >= 0.25 then
        return "ff8800"
    else
        return "ff0000"
    end
end

local function FormatTimeSince(seconds)
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        return mins .. " minute" .. (mins ~= 1 and "s" or "") .. " ago"
    elseif seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        return hours .. " hour" .. (hours ~= 1 and "s" or "") .. " ago"
    else
        local days = math.floor(seconds / 86400)
        return days .. " day" .. (days ~= 1 and "s" or "") .. " ago"
    end
end

local function CreateProgressBar(parent, current, max)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetMinMaxValues(0, max)
    bar:SetValue(current)

    local percent = max > 0 and (current / max) or 0
    if percent >= 1.0 then
        bar:SetStatusBarColor(0.2, 0.8, 0.2)
    elseif percent >= 0.5 then
        bar:SetStatusBarColor(0.8, 0.8, 0.2)
    else
        bar:SetStatusBarColor(0.8, 0.2, 0.2)
    end

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)

    return bar
end

local function CreateDetailButton(parent, label, value, xOffset, yOffset, expansion, filterType, color)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(125, 18)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    button.bg = bg

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    button.highlight = highlight

    local labelText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("LEFT", button, "LEFT", 6, 0)
    labelText:SetText(label .. ":")
    labelText:SetTextColor(0.8, 0.8, 0.8, 1)

    local valueText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    valueText:SetText(value)
    valueText:SetTextColor(color[1], color[2], color[3], 1)

    button.labelText = labelText
    button.valueText = valueText

    button:SetScript("OnEnter", function(self)
        self.valueText:SetTextColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["PROFPANEL_RECIPES_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(label .. " recipes for " .. expansion.name, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.valueText:SetTextColor(color[1], color[2], color[3], 1)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self)
    end)

    return button
end

local function CreateExpansionDetails(row)
    local expansion = row.expansion
    local detailsFrame = CreateFrame("Frame", nil, row)
    detailsFrame:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -32)
    detailsFrame:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -32)
    detailsFrame:SetHeight(52)

    local bg = detailsFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(detailsFrame)
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.7)

    local totalCount = expansion.totalRecipes or expansion.recipeCount or 0
    local learnedCount = expansion.learnedRecipes or expansion.learnedCount or 0
    local unlearned = totalCount - learnedCount

    CreateDetailButton(detailsFrame, "Total",   totalCount,   8,  -8,  expansion, "total",      {0.7, 0.7, 0.9})
    CreateDetailButton(detailsFrame, "Known",   learnedCount, (detailsFrame:GetWidth() or 270) / 2 + 4, -8, expansion, "known", {0.4, 1, 0.4})
    CreateDetailButton(detailsFrame, "Missing", unlearned,    8,  -30, expansion, "missing",    {1, 0.5, 0.5})

    if expansion.firstCraftPending and expansion.firstCraftPending > 0 then
        CreateDetailButton(detailsFrame, "First Craft", expansion.firstCraftPending, (detailsFrame:GetWidth() or 270) / 2 + 4, -30, expansion, "firstcraft", {1, 0.8, 0.2})
    end

    return detailsFrame
end

local ProfPanelUI = {}

function ProfPanelUI:ToggleExpansionDetails(row)
    if row.isExpanded then
        if not row.detailsFrame then
            row.detailsFrame = CreateExpansionDetails(row)
        end
        row.detailsFrame:Show()
        row:SetHeight(110)
    else
        if row.detailsFrame then
            row.detailsFrame:Hide()
        end
        row:SetHeight(40)
    end
    self:RefreshExpansionList(row:GetParent())
end

function ProfPanelUI:RefreshExpansionList(scrollChild)
    local totalHeight = 10
    local rows = {scrollChild:GetChildren()}
    for i, child in ipairs(rows) do
        if child.expansion then
            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -totalHeight)
            child:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -totalHeight)
            totalHeight = totalHeight + child:GetHeight() + 5
        end
    end
    scrollChild:SetHeight(totalHeight)
end

function ProfPanelUI:CreateExpansionRow(parent, expansion, yOffset)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(40)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    row.isExpanded = false
    row.expansion = expansion

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.4)

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.isExpanded then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(expansion.name or "Unknown", 1, 0.82, 0)
            GameTooltip:AddLine(L["PROFPANEL_EXPAND_HINT"], 0.5, 0.8, 1, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self)
        self.isExpanded = not self.isExpanded
        ProfPanelUI:ToggleExpansionDetails(self)
    end)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -6)
    nameText:SetText(expansion.name or "Unknown")
    nameText:SetTextColor(1, 1, 1, 1)

    local learnedCount = expansion.learnedRecipes or expansion.learnedCount or 0
    local totalCount   = expansion.totalRecipes  or expansion.recipeCount  or 0
    local recipeColor  = GetRecipeCountColor(learnedCount, totalCount)
    local recipeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recipeText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -45, -6)
    recipeText:SetText(string.format("|cff%s%d/%d|r", recipeColor, learnedCount, totalCount))

    if expansion.firstCraftPending and expansion.firstCraftPending > 0 then
        local fcText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fcText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -6)
        fcText:SetText(string.format("FC:|cffff8800%d|r", expansion.firstCraftPending))
    end

    if expansion.maxSkill > 0 then
        local progressBar = CreateProgressBar(row, expansion.currentSkill, expansion.maxSkill)
        progressBar:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  8, 6)
        progressBar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 6)
        progressBar:SetHeight(12)

        local skillText = progressBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        skillText:SetPoint("CENTER", progressBar, "CENTER", 0, 0)
        skillText:SetText(string.format("%d/%d", expansion.currentSkill or 0, expansion.maxSkill or 0))
        skillText:SetTextColor(1, 1, 1, 1)
        skillText:SetShadowOffset(1, -1)
        skillText:SetShadowColor(0, 0, 0, 1)
    end

    return row
end

function ProfPanelUI:UpdateExpansionList(panel, expansionData)
    local scrollChild = panel.scrollChild

    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    if #expansionData == 0 then
        local noDataText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noDataText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -10)
        noDataText:SetText(L["PROFPANEL_NO_EXPANSION_DATA"])
        noDataText:SetTextColor(0.7, 0.7, 0.7, 1)
        scrollChild:SetHeight(60)
        return
    end

    local yOffset = -5
    local rowHeight = 45

    for _, expansion in ipairs(expansionData) do
        local row = self:CreateExpansionRow(scrollChild, expansion, yOffset)
        yOffset = yOffset - rowHeight
    end

    scrollChild:SetHeight(math.abs(yOffset) + 10)
end

function ProfPanelUI:UpdateOtherAlts(panel, otherAlts)
    local altsFrame = panel.altsFrame
    if not altsFrame then return end

    if #otherAlts == 0 then
        altsFrame.text:SetText(L["PROFPANEL_NO_ALT_DATA"])
        altsFrame.text:Show()
        return
    end

    altsFrame.text:Hide()

    local xOffset = 8
    local yOffset = -28
    local maxWidth = altsFrame:GetWidth() - 16

    for i, alt in ipairs(otherAlts) do
        local button = CreateFrame("Button", nil, altsFrame)
        button:SetSize(1, 16)
        button:SetNormalFontObject("GameFontNormalSmall")
        button:SetHighlightFontObject("GameFontHighlightSmall")

        local classColor = "|cffffffff"
        if alt.class then
            local color = C_ClassColor.GetClassColor(alt.class)
            if color then
                classColor = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
            end
        end

        button:SetText(classColor .. alt.name .. "|r")

        local textWidth = button:GetFontString():GetStringWidth()
        button:SetWidth(textWidth + 4)

        if xOffset + textWidth > maxWidth then
            xOffset = 8
            yOffset = yOffset - 18
        end

        button:SetPoint("TOPLEFT", altsFrame, "TOPLEFT", xOffset, yOffset)
        xOffset = xOffset + textWidth + 12

        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(alt.name .. " - " .. (alt.realm or "Unknown"), 1, 1, 1)
            GameTooltip:AddLine(" ", 1, 1, 1)

            if alt.expansionData and #alt.expansionData > 0 then
                GameTooltip:AddLine(L["PROFPANEL_EXPANSION_SKILLS"], 1, 0.82, 0)
                for _, expansion in ipairs(alt.expansionData) do
                    GameTooltip:AddLine(string.format("%s: %d/%d",
                        expansion.name,
                        expansion.currentSkill or 0,
                        expansion.maxSkill or 0), 0.8, 0.8, 0.8)
                end
            elseif alt.professionData then
                GameTooltip:AddLine(L["PROFPANEL_OVERALL_SKILL"], 1, 0.82, 0)
                GameTooltip:AddLine(string.format("%d/%d",
                    alt.professionData.currentSkill or 0,
                    alt.professionData.maxSkill or 0), 0.8, 0.8, 0.8)
            else
                GameTooltip:AddLine(L["PROFPANEL_NO_DATA"], 0.7, 0.7, 0.7)
            end

            if alt.lastScan and alt.lastScan > 0 then
                local timeText = FormatTimeSince(time() - alt.lastScan)
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine(string.format(L["PROFPANEL_LAST_SCANNED"], timeText), 0.6, 0.6, 0.6)
            end

            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
end

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

local function CreatePanel()
    local panel = CreateFrame("Frame", "OneWoW_QoL_ProfessionStatsPanel", UIParent, "BasicFrameTemplate")
    panel:SetSize(340, 650)
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    PositionPanel(panel)

    panel.TitleText:SetText(L["PROFPANEL_STATS_TITLE"])

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", panel, "TOP", 0, -30)
    subtitle:SetText("")
    subtitle:SetTextColor(0.8, 0.8, 0.8, 1)
    panel.subtitle = subtitle

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     panel, "TOPLEFT",     5,   -55)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 120)
    panel.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild

    local altsFrame = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
    altsFrame:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  5, 5)
    altsFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 5)
    altsFrame:SetHeight(100)
    panel.altsFrame = altsFrame

    local altsTitle = altsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    altsTitle:SetPoint("TOPLEFT", altsFrame, "TOPLEFT", 8, -8)
    altsTitle:SetText(L["PROFPANEL_OTHER_ALTS"])
    altsTitle:SetTextColor(1, 0.82, 0, 1)

    local altsText = altsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    altsText:SetPoint("TOPLEFT",     altsTitle, "BOTTOMLEFT",  0,  -5)
    altsText:SetPoint("BOTTOMRIGHT", altsFrame, "BOTTOMRIGHT", -8,  8)
    altsText:SetJustifyH("LEFT")
    altsText:SetJustifyV("TOP")
    altsText:SetText(L["PROFPANEL_NO_ALT_DATA"])
    altsText:SetTextColor(0.7, 0.7, 0.7, 1)
    altsFrame.text = altsText

    panel.manuallyHidden = false
    panel:Hide()
    return panel
end

local function CountRecipesInCategory(categoryID)
    local total = 0
    local allRecipes = C_TradeSkillUI.GetAllRecipeIDs()
    if not allRecipes then return total end

    local function belongsToExpansion(recipeCatID)
        local catID = recipeCatID
        for i = 1, 10 do
            if catID == categoryID then return true end
            local catInfo = C_TradeSkillUI.GetCategoryInfo(catID)
            if catInfo and catInfo.parentCategoryID then
                catID = catInfo.parentCategoryID
            else
                break
            end
        end
        return false
    end

    for _, recipeID in ipairs(allRecipes) do
        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if recipeInfo and recipeInfo.categoryID and belongsToExpansion(recipeInfo.categoryID) then
            total = total + 1
        end
    end
    return total
end

local function CountLearnedAndFirstCraftInCategory(categoryID)
    local learned = 0
    local firstCraft = 0
    local allRecipes = C_TradeSkillUI.GetAllRecipeIDs()
    if not allRecipes then return learned, firstCraft end

    local function belongsToExpansion(recipeCatID)
        local catID = recipeCatID
        for i = 1, 10 do
            if catID == categoryID then return true end
            local catInfo = C_TradeSkillUI.GetCategoryInfo(catID)
            if catInfo and catInfo.parentCategoryID then
                catID = catInfo.parentCategoryID
            else
                break
            end
        end
        return false
    end

    for _, recipeID in ipairs(allRecipes) do
        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if recipeInfo and recipeInfo.categoryID and belongsToExpansion(recipeInfo.categoryID) then
            if recipeInfo.learned then
                learned = learned + 1
                if recipeInfo.firstCraft == true then
                    firstCraft = firstCraft + 1
                end
            end
        end
    end
    return learned, firstCraft
end

local function ParseExpansionCategories()
    local expansions = {}
    if not C_TradeSkillUI or not C_TradeSkillUI.IsTradeSkillReady() then return expansions end

    local categories = {C_TradeSkillUI.GetCategories()}
    if not categories or #categories == 0 then return expansions end

    for _, categoryID in ipairs(categories) do
        local categoryInfo = C_TradeSkillUI.GetCategoryInfo(categoryID)
        local isExpansion = false
        if categoryInfo and categoryInfo.name then
            if categoryInfo.type == "header" or categoryInfo.type == "subheader" then
                if categoryInfo.hasProgressBar and (categoryInfo.skillLineMaxLevel or 0) > 0 then
                    isExpansion = true
                end
            end
        end

        if isExpansion then
            local totalRecipes = CountRecipesInCategory(categoryID)
            local learnedRecipes, firstCraftPending = CountLearnedAndFirstCraftInCategory(categoryID)
            table.insert(expansions, {
                name             = categoryInfo.name,
                currentSkill     = categoryInfo.skillLineCurrentLevel or 0,
                maxSkill         = categoryInfo.skillLineMaxLevel or 0,
                totalRecipes     = totalRecipes,
                learnedRecipes   = learnedRecipes,
                firstCraftPending = firstCraftPending,
                categoryID       = categoryID,
                hasProgressBar   = categoryInfo.hasProgressBar,
            })
        end
    end
    return expansions
end

function ProfPanelModule:GetCharacterKey()
    local name  = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then return nil end
    return name .. "-" .. realm
end

function ProfPanelModule:UpdatePanelData()
    if not self._panel or not self._currentProf then return end

    local expansionData = ParseExpansionCategories()

    if ProfPanelUI then
        self._panel.subtitle:SetText(self._currentProf)
        PositionPanel(self._panel)
        ProfPanelUI:UpdateExpansionList(self._panel, expansionData)
        ProfPanelUI:UpdateOtherAlts(self._panel, {})
    end
end

function ProfPanelModule:UpdateToggleButton()
    if not self._toggleButton or not self._toggleButton.icon then return end
    if self._panel and self._panel:IsShown() then
        self._toggleButton.icon:SetVertexColor(1, 0.82, 0, 1)
    else
        self._toggleButton.icon:SetVertexColor(1, 1, 1, 1)
    end
end

function ProfPanelModule:CreateToggleButton()
    if self._toggleButton then return end

    local profFrame = ProfessionsFrame or TradeSkillFrame
    if not profFrame then return end

    local btn = CreateFrame("Button", "OneWoW_QoL_ProfessionToggleButton", profFrame)
    btn:SetSize(28, 28)
    btn:SetPoint("TOPRIGHT", profFrame, "TOPRIGHT", 32, -30)
    btn:SetFrameLevel(profFrame:GetFrameLevel() + 10)

    local glow = btn:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(42, 42)
    glow:SetPoint("CENTER")
    glow:SetAtlas("QuestLog-Tab-side-Glow-Select")
    glow:SetAlpha(0.8)
    btn.glow = glow

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("newplayertutorial-icon-mouse-leftbutton")
    btn.icon = icon

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    highlight:SetBlendMode("ADD")

    btn:SetScript("OnClick", function()
        ProfPanelModule:TogglePanel()
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["PROFPANEL_TOGGLE_TIP"], 1, 0.82, 0)
        if ProfPanelModule._panel and ProfPanelModule._panel:IsShown() then
            GameTooltip:AddLine(L["PROFPANEL_HIDE_TIP"], 1, 1, 1, true)
        else
            GameTooltip:AddLine(L["PROFPANEL_SHOW_TIP"], 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    btn:Hide()
    self._toggleButton = btn
end

function ProfPanelModule:TogglePanel()
    if not self._panel then
        self._panel = CreatePanel()
    end

    if self._panel:IsShown() then
        self._panel.manuallyHidden = true
        self._panel:Hide()
    else
        self._panel.manuallyHidden = false
        self:UpdatePanelData()
        self._panel:Show()
    end

    self:UpdateToggleButton()
end

function ProfPanelModule:OnProfessionWindowOpened()
    C_Timer.After(0.1, function()
        if not ns.ModuleRegistry:GetToggleValue("professionspanel", "auto_show") then return end

        if not self._toggleButton then
            self:CreateToggleButton()
        end
        if self._toggleButton then
            self._toggleButton:Show()
            self:UpdateToggleButton()
        end

        if C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady() then
            local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
            if professionInfo and professionInfo.professionName then
                self._currentProf = professionInfo.professionName

                if not self._panel then
                    self._panel = CreatePanel()
                end

                if not self._panel.manuallyHidden then
                    self:UpdatePanelData()
                    self._panel:Show()
                end
                self:UpdateToggleButton()
            end
        end
    end)
end

function ProfPanelModule:OnProfessionWindowClosed()
    if self._toggleButton then
        self._toggleButton:Hide()
    end
    if self._panel then
        self._panel:Hide()
    end
    self._currentProf = nil
    self._pendingOpen = false
end

function ProfPanelModule:OnProfessionDataUpdated()
    if self._panel and self._panel:IsShown() then
        self:UpdatePanelData()
    end
end

function ProfPanelModule:OnEnable()
    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_ProfPanelEvents")
        self._eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
        self._eventFrame:RegisterEvent("TRADE_SKILL_CLOSE")
        self._eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
        self._eventFrame:SetScript("OnEvent", function(frame, event)
            if event == "TRADE_SKILL_SHOW" then
                ProfPanelModule:OnProfessionWindowOpened()
            elseif event == "TRADE_SKILL_CLOSE" then
                ProfPanelModule:OnProfessionWindowClosed()
            elseif event == "TRADE_SKILL_LIST_UPDATE" then
                ProfPanelModule:OnProfessionDataUpdated()
            end
        end)
    end
end

function ProfPanelModule:OnDisable()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
    if self._toggleButton then
        self._toggleButton:Hide()
    end
    if self._panel then
        self._panel:Hide()
    end
end

function ProfPanelModule:OnToggle(toggleId, value)
    if toggleId == "auto_show" and not value then
        if self._panel then
            self._panel:Hide()
        end
        if self._toggleButton then
            self._toggleButton:Hide()
        end
    end
end

ns.ProfPanelModule = ProfPanelModule

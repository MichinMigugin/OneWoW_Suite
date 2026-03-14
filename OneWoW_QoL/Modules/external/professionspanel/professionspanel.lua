local addonName, ns = ...

local ProfPanelModule = {
    id          = "professionspanel",
    title       = "PROFPANEL_TITLE",
    category    = "INTERFACE",
    description = "PROFPANEL_DESC",
    version     = "2.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {
        { id = "auto_show", label = "PROFPANEL_AUTO_SHOW", default = true },
    },
    preview        = true,
    defaultEnabled = true,
    _panel           = nil,
    _toggleButton    = nil,
    _eventFrame      = nil,
    _currentProf     = nil,
    _cachedData      = nil,
    _lastScanTime    = 0,
    _scanThrottle    = 2,
}

local L = ns.L

local EXPANSION_KEYWORDS = {
    { pattern = "Midnight",         order = 12 },
    { pattern = "Khaz Algar",       order = 11 },
    { pattern = "War Within",       order = 11 },
    { pattern = "Dragon",           order = 10 },
    { pattern = "Shadowlands",      order = 9 },
    { pattern = "Kul Tiran",        order = 8 },
    { pattern = "Zandalari",        order = 8 },
    { pattern = "Battle",           order = 8 },
    { pattern = "Legion",           order = 7 },
    { pattern = "Draenor",          order = 6 },
    { pattern = "Pandaria",         order = 5 },
    { pattern = "Cataclysm",       order = 4 },
    { pattern = "Northrend",        order = 3 },
    { pattern = "Lich King",        order = 3 },
    { pattern = "Outland",          order = 2 },
    { pattern = "Burning Crusade",  order = 2 },
    { pattern = "Classic",          order = 1 },
}

local function GetExpansionOrder(name)
    if not name then return 0 end
    for _, entry in ipairs(EXPANSION_KEYWORDS) do
        if name:find(entry.pattern) then
            return entry.order
        end
    end
    return 0
end

local function GetRecipeCountColor(learned, total)
    if total == 0 then return 0.53, 0.53, 0.53 end
    local pct = learned / total
    if pct >= 1.0 then return 0, 1, 0
    elseif pct >= 0.75 then return 0.53, 1, 0
    elseif pct >= 0.5 then return 1, 1, 0
    elseif pct >= 0.25 then return 1, 0.53, 0
    else return 1, 0, 0 end
end

local function GetProgressColor(current, max)
    if max == 0 then return 0.35, 0.35, 0.35 end
    local pct = current / max
    if pct >= 1.0 then return 0.15, 0.55, 0.15
    elseif pct >= 0.5 then return 0.55, 0.55, 0.15
    else return 0.55, 0.15, 0.15 end
end

local function FormatTimeSince(seconds)
    if seconds < 60 then return "just now"
    elseif seconds < 3600 then
        local m = math.floor(seconds / 60)
        return m .. (m == 1 and " minute" or " minutes") .. " ago"
    elseif seconds < 86400 then
        local h = math.floor(seconds / 3600)
        return h .. (h == 1 and " hour" or " hours") .. " ago"
    else
        local d = math.floor(seconds / 86400)
        return d .. (d == 1 and " day" or " days") .. " ago"
    end
end

function ProfPanelModule:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then return nil end
    return name .. "-" .. realm
end

function ProfPanelModule:ScanExpansionData()
    local expansions = {}
    if not C_TradeSkillUI or not C_TradeSkillUI.IsTradeSkillReady() then return expansions end

    local categories = { C_TradeSkillUI.GetCategories() }
    if not categories or #categories == 0 then return expansions end

    local expansionCategories = {}
    for _, categoryID in ipairs(categories) do
        local catInfo = C_TradeSkillUI.GetCategoryInfo(categoryID)
        if catInfo and catInfo.name and catInfo.hasProgressBar and (catInfo.skillLineMaxLevel or 0) > 0 then
            expansionCategories[categoryID] = {
                name         = catInfo.name,
                currentSkill = catInfo.skillLineCurrentLevel or 0,
                maxSkill     = catInfo.skillLineMaxLevel or 0,
                categoryID   = categoryID,
                total        = 0,
                learned      = 0,
                firstCraft   = 0,
            }
        end
    end

    local function findExpansionCat(recipeCatID)
        local catID = recipeCatID
        for _ = 1, 10 do
            if expansionCategories[catID] then return catID end
            local catInfo = C_TradeSkillUI.GetCategoryInfo(catID)
            if catInfo and catInfo.parentCategoryID then
                catID = catInfo.parentCategoryID
            else
                break
            end
        end
        return nil
    end

    local allRecipes = C_TradeSkillUI.GetAllRecipeIDs()
    if not allRecipes then return expansions end

    local catCache = {}
    for _, recipeID in ipairs(allRecipes) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if info and info.categoryID then
            local expCatID = catCache[info.categoryID]
            if expCatID == nil then
                expCatID = findExpansionCat(info.categoryID) or false
                catCache[info.categoryID] = expCatID
            end

            if expCatID and expansionCategories[expCatID] then
                local exp = expansionCategories[expCatID]
                exp.total = exp.total + 1
                if info.learned then
                    exp.learned = exp.learned + 1
                    if info.firstCraft == true then
                        exp.firstCraft = exp.firstCraft + 1
                    end
                end
            end
        end
    end

    local ordered = {}
    for _, exp in pairs(expansionCategories) do
        exp.sortOrder = GetExpansionOrder(exp.name)
        table.insert(ordered, exp)
    end

    table.sort(ordered, function(a, b) return a.sortOrder > b.sortOrder end)

    return ordered
end

function ProfPanelModule:GetOtherAlts()
    local alts = {}
    local currentChar = self:GetCharacterKey()
    local currentProf = self._currentProf
    if not currentChar or not currentProf then return alts end

    local atDB = _G.OneWoW_AltTracker_Professions_DB
    if atDB and atDB.characters then
        for charKey, charData in pairs(atDB.characters) do
            if charKey ~= currentChar and charData.professions then
                for _, profData in pairs(charData.professions) do
                    if profData.name == currentProf then
                        local name, realm = strsplit("-", charKey)
                        table.insert(alts, {
                            name       = name or charKey,
                            realm      = realm or "",
                            class      = charData.class,
                            skillLevel = profData.skillLevel or profData.currentSkill or 0,
                            maxSkill   = profData.maxSkillLevel or profData.maxSkill or 0,
                            lastUpdate = profData.lastUpdate or 0,
                        })
                    end
                end
            end
        end
    end

    local catDB = _G.OneWoW_CatalogData_Tradeskills_DB
    if catDB and catDB.scanCache then
        for charKey, professions in pairs(catDB.scanCache) do
            if charKey ~= currentChar and professions[currentProf] then
                local already = false
                for _, a in ipairs(alts) do
                    if (a.name .. "-" .. a.realm) == charKey then
                        already = true
                        if professions[currentProf].skillLevel then
                            a.skillLevel = math.max(a.skillLevel or 0, professions[currentProf].skillLevel)
                        end
                        if professions[currentProf].maxSkillLevel then
                            a.maxSkill = math.max(a.maxSkill or 0, professions[currentProf].maxSkillLevel)
                        end
                        a.lastScan = professions[currentProf].lastScan
                        break
                    end
                end
                if not already then
                    local name, realm = strsplit("-", charKey)
                    table.insert(alts, {
                        name       = name or charKey,
                        realm      = realm or "",
                        class      = nil,
                        skillLevel = professions[currentProf].skillLevel or 0,
                        maxSkill   = professions[currentProf].maxSkillLevel or 0,
                        lastScan   = professions[currentProf].lastScan or 0,
                    })
                end
            end
        end
    end

    table.sort(alts, function(a, b) return (a.skillLevel or 0) > (b.skillLevel or 0) end)

    local maxAlts = 6
    local hasMore = #alts > maxAlts
    local trimmed = {}
    for i = 1, math.min(#alts, maxAlts) do
        trimmed[i] = alts[i]
    end

    return trimmed, hasMore, #alts
end

function ProfPanelModule:DoScan()
    local now = GetTime()
    if self._cachedData and (now - self._lastScanTime) < self._scanThrottle then
        return self._cachedData
    end

    self._cachedData = self:ScanExpansionData()
    self._lastScanTime = now
    return self._cachedData
end

function ProfPanelModule:UpdatePanelData()
    if not self._panel or not self._currentProf then return end

    local expansionData = self:DoScan()
    local altData, hasMore, totalAlts = self:GetOtherAlts()

    if ns.ProfPanelUI then
        ns.ProfPanelUI:UpdatePanel(self._panel, self._currentProf, expansionData, altData, hasMore, totalAlts)
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
        if ns.ProfPanelUI then
            self._panel = ns.ProfPanelUI:CreatePanel()
        end
    end
    if not self._panel then return end

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
                self._cachedData = nil
                self._lastScanTime = 0

                if not self._panel and ns.ProfPanelUI then
                    self._panel = ns.ProfPanelUI:CreatePanel()
                end

                if self._panel and not self._panel.manuallyHidden then
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
    self._cachedData = nil
    self._lastScanTime = 0
end

function ProfPanelModule:OnProfessionDataUpdated()
    if self._panel and self._panel:IsShown() then
        self:UpdatePanelData()
    end
end

function ProfPanelModule:RebuildPanel()
    if not self._panel then return end
    local wasShown = self._panel:IsShown()
    self._panel:Hide()
    self._panel:SetParent(nil)
    self._panel = nil

    if wasShown and self._currentProf and ns.ProfPanelUI then
        self._panel = ns.ProfPanelUI:CreatePanel()
        self._cachedData = nil
        self._lastScanTime = 0
        self:UpdatePanelData()
        self._panel:Show()
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

    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    if OneWoW_GUI then
        local function onSettingsChanged()
            ProfPanelModule:RebuildPanel()
        end
        OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, onSettingsChanged)
        OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, onSettingsChanged)
        OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, onSettingsChanged)
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
ns.ProfPanelHelpers = {
    GetRecipeCountColor = GetRecipeCountColor,
    GetProgressColor    = GetProgressColor,
    FormatTimeSince     = FormatTimeSince,
}

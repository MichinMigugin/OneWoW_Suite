-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/afkpanel/afkpanel.lua
local addonName, ns = ...

local AFKPanelModule = {
    id          = "afkpanel",
    title       = "AFKPANEL_TITLE",
    category    = "INTERFACE",
    description = "AFKPANEL_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {
        { id = "camera_spin",     label = "AFKPANEL_CAMERA_SPIN", default = true },
        { id = "show_daily",      label = "AFKPANEL_SHOW_DAILY",  default = true  },
        { id = "show_weekly",     label = "AFKPANEL_SHOW_WEEKLY", default = true  },
    },
    defaultEnabled = true,
    isAFK       = false,
    _initialized = false,
    _eventFrame  = nil,
    _afkFrame    = nil,
    _model       = nil,
    _infoPanel   = nil,
    _alertsPanel = nil,
    _dailyPanel  = nil,
    _weeklyPanel = nil,
    _timer       = nil,
    _animTimer   = nil,
    _startTime   = nil,
}

local L = ns.L

local CAMERA_SPEED = 0.035

local backdrop = {
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 16,
    edgeSize = 16,
    insets   = {left = 4, right = 4, top = 4, bottom = 4},
}

local ignoreKeys = {
    LALT   = true,
    LSHIFT = true,
    RSHIFT = true,
}

local printKeys = {
    PRINTSCREEN = true,
}
if IsMacClient() then
    printKeys[_G.KEY_PRINTSCREEN_MAC or "PRINT"] = true
end

-- ============================================================
-- Data Collection
-- ============================================================

local function GetCharacterInfo()
    local name    = UnitName("player")
    local realm   = GetRealmName()
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local guild, _, guildRank = GetGuildInfo("player")

    local _, itemLevelEquipped = GetAverageItemLevel()
    local itemLevel = math.floor(itemLevelEquipped or 0)

    local mplusRating = 0
    if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
        mplusRating = C_ChallengeMode.GetOverallDungeonScore() or 0
    end

    return {
        name            = name,
        realm           = realm,
        class           = class,
        faction         = faction,
        guild           = guild,
        guildRank       = guildRank,
        itemLevel       = itemLevel,
        mythicPlusRating = mplusRating,
        money           = GetMoney(),
    }
end

local function GetNotesByType(noteType)
    local notes = {}
    local notesAddon = _G.OneWoW_Notes
    if not notesAddon then return notes end
    local notesData = notesAddon.NotesData
    if not notesData or not notesData.GetAllNotes then return notes end

    local allNotes = notesData:GetAllNotes()
    if not allNotes then return notes end

    for noteID, note in pairs(allNotes) do
        if type(note) == "table" and note.noteType == noteType and note.todos and #note.todos > 0 then
            local incompleteTodos = {}
            for _, todo in ipairs(note.todos) do
                if not todo.completed then
                    table.insert(incompleteTodos, todo.text)
                end
            end
            if #incompleteTodos > 0 then
                table.insert(notes, {
                    title = note.title,
                    id    = note.id,
                    tasks = incompleteTodos,
                })
            end
        end
    end
    return notes
end

local function CollectDisplayData()
    return {
        character    = GetCharacterInfo(),
        mailCount    = 0,
        auctionCount = 0,
        needsAttention = false,
        dailyNotes   = GetNotesByType("daily"),
        weeklyNotes  = GetNotesByType("weekly"),
    }
end

-- ============================================================
-- UI Display
-- ============================================================

local function CreateTopBar(parent)
    local screenWidth = GetScreenWidth() * UIParent:GetEffectiveScale()

    local topBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    topBar:SetPoint("TOP", parent, "TOP", 0, 0)
    topBar:SetWidth(screenWidth)
    topBar:SetHeight(60)
    topBar:SetFrameLevel(2)
    topBar:SetBackdrop(backdrop)
    topBar:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    topBar:SetBackdropBorderColor(0.8, 0.6, 0.2, 1)

    local topText = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    topText:SetPoint("CENTER", topBar, "CENTER", 0, 0)
    topText:SetText(L["AFKPANEL_MODE_TITLE"])
    topText:SetTextColor(1, 0.82, 0, 1)

    return topBar
end

local function CreateCharacterInfoPanel(parent)
    local screenWidth = GetScreenWidth() * UIParent:GetEffectiveScale()
    local panelWidth  = math.max(350, math.min(450, screenWidth * 0.3))

    local infoPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    infoPanel:SetSize(panelWidth, 180)
    infoPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -20)
    infoPanel:SetBackdrop(backdrop)
    infoPanel:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
    infoPanel:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)

    local headerText = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("TOP", infoPanel, "TOP", 0, -12)
    headerText:SetText(L["AFKPANEL_CHARACTER_INFO"])
    headerText:SetTextColor(1, 0.82, 0, 1)

    local factionIcon = infoPanel:CreateTexture(nil, "ARTWORK")
    factionIcon:SetSize(48, 48)
    factionIcon:SetPoint("TOPLEFT", infoPanel, "TOPLEFT", 15, -45)
    infoPanel.factionIcon = factionIcon

    local nameText = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("LEFT", factionIcon, "RIGHT", 12, 8)
    nameText:SetTextColor(1, 1, 1, 1)
    infoPanel.nameText = nameText

    local guildText = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildText:SetPoint("LEFT", factionIcon, "RIGHT", 12, -10)
    guildText:SetTextColor(0.7, 0.7, 0.7, 1)
    infoPanel.guildText = guildText

    local iLevelText = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iLevelText:SetPoint("TOPLEFT", factionIcon, "BOTTOMLEFT", 0, -12)
    iLevelText:SetTextColor(1, 1, 1, 1)
    infoPanel.iLevelText = iLevelText

    local mplusText = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mplusText:SetPoint("TOPLEFT", iLevelText, "BOTTOMLEFT", 0, -6)
    mplusText:SetTextColor(1, 1, 1, 1)
    infoPanel.mplusText = mplusText

    local goldText = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldText:SetPoint("TOPLEFT", mplusText, "BOTTOMLEFT", 0, -6)
    goldText:SetTextColor(1, 1, 1, 1)
    infoPanel.goldText = goldText

    local timerText = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timerText:SetPoint("TOPRIGHT", infoPanel, "TOPRIGHT", -15, -45)
    timerText:SetText("AFK: 00:00")
    timerText:SetTextColor(1, 0.82, 0, 1)
    infoPanel.timerText = timerText

    return infoPanel
end

local function CreateAlertsPanel(parent, infoPanel)
    local panelWidth = infoPanel:GetWidth()

    local alertsPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    alertsPanel:SetSize(panelWidth, 140)
    alertsPanel:SetPoint("TOPLEFT", infoPanel, "BOTTOMLEFT", 0, -10)
    alertsPanel:SetBackdrop(backdrop)
    alertsPanel:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
    alertsPanel:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)

    local headerText = alertsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("TOP", alertsPanel, "TOP", 0, -12)
    headerText:SetText(L["AFKPANEL_ALERTS"])
    headerText:SetTextColor(1, 0.82, 0, 1)

    local noAlertsText = alertsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noAlertsText:SetPoint("CENTER", alertsPanel, "CENTER", 0, -5)
    noAlertsText:SetText(L["AFKPANEL_NO_ALERTS"])
    noAlertsText:SetTextColor(0.5, 0.5, 0.5, 1)
    alertsPanel.noAlertsText = noAlertsText

    alertsPanel.alertTexts = {}
    alertsPanel.alertIcons = {}
    for i = 1, 3 do
        local icon = alertsPanel:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("TOPLEFT", alertsPanel, "TOPLEFT", 15, -40 - (i-1) * 35)
        icon:Hide()
        alertsPanel.alertIcons[i] = icon

        local text = alertsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", icon, "RIGHT", 12, 0)
        text:SetTextColor(1, 1, 1, 1)
        text:Hide()
        alertsPanel.alertTexts[i] = text
    end

    return alertsPanel
end

local function CreateNotesPanel(parent, headerKey, anchorPoint, anchorRelative, anchorRelativePoint, anchorX, anchorY)
    local screenWidth = GetScreenWidth() * UIParent:GetEffectiveScale()
    local panelWidth  = math.max(400, math.min(550, screenWidth * 0.35))

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(panelWidth, 180)
    panel:SetPoint(anchorPoint, anchorRelative, anchorRelativePoint, anchorX, anchorY)
    panel:SetBackdrop(backdrop)
    panel:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
    panel:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)

    local headerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerText:SetPoint("TOP", panel, "TOP", 0, -12)
    headerText:SetText(L[headerKey])
    headerText:SetTextColor(1, 0.82, 0, 1)
    panel.headerText = headerText

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     panel, "TOPLEFT",     10,  -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)
    panel.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild

    panel.contentTexts = {}

    return panel
end

local function UpdateCharacterInfo(infoPanel, data)
    if not data or not data.character then return end
    local char = data.character

    if char.faction == "Horde" then
        infoPanel.factionIcon:SetTexture("Interface\\Timer\\Horde-Logo")
    elseif char.faction == "Alliance" then
        infoPanel.factionIcon:SetTexture("Interface\\Timer\\Alliance-Logo")
    else
        infoPanel.factionIcon:SetTexture("Interface\\Timer\\Panda-Logo")
    end

    local classColor = RAID_CLASS_COLORS[char.class] or {r = 1, g = 1, b = 1}
    infoPanel.nameText:SetFormattedText("%s-%s", char.name, char.realm)
    infoPanel.nameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)

    if char.guild and char.guildRank then
        infoPanel.guildText:SetFormattedText("<%s> - %s", char.guild, char.guildRank)
    elseif char.guild then
        infoPanel.guildText:SetFormattedText("<%s>", char.guild)
    else
        infoPanel.guildText:SetText(L["AFKPANEL_NO_GUILD"])
    end

    infoPanel.iLevelText:SetFormattedText("iLevel: %d", char.itemLevel)
    infoPanel.mplusText:SetFormattedText("M+ Score: %d", char.mythicPlusRating)

    local gold   = math.floor(char.money / 10000)
    local silver = math.floor((char.money % 10000) / 100)
    local copper = char.money % 100
    infoPanel.goldText:SetFormattedText(
        "Gold: %s|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t %s|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t %s|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t",
        BreakUpLargeNumbers(gold), silver, copper)
end

local function UpdateAlerts(alertsPanel, data)
    local alertIndex = 1

    if data.mailCount and data.mailCount > 0 then
        alertsPanel.alertIcons[alertIndex]:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
        alertsPanel.alertTexts[alertIndex]:SetText(string.format("%d Unread Mail", data.mailCount))
        alertsPanel.alertIcons[alertIndex]:Show()
        alertsPanel.alertTexts[alertIndex]:Show()
        alertIndex = alertIndex + 1
    end

    if data.auctionCount and data.auctionCount > 0 then
        alertsPanel.alertIcons[alertIndex]:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        alertsPanel.alertTexts[alertIndex]:SetText(string.format("%d Auction Alerts", data.auctionCount))
        alertsPanel.alertIcons[alertIndex]:Show()
        alertsPanel.alertTexts[alertIndex]:Show()
        alertIndex = alertIndex + 1
    end

    if data.needsAttention then
        alertsPanel.alertIcons[alertIndex]:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
        alertsPanel.alertTexts[alertIndex]:SetText("Character Needs Attention")
        alertsPanel.alertIcons[alertIndex]:Show()
        alertsPanel.alertTexts[alertIndex]:Show()
        alertIndex = alertIndex + 1
    end

    for i = alertIndex, 3 do
        alertsPanel.alertIcons[i]:Hide()
        alertsPanel.alertTexts[i]:Hide()
    end

    if alertIndex == 1 then
        alertsPanel.noAlertsText:Show()
    else
        alertsPanel.noAlertsText:Hide()
    end
end

local function GetOrCreateFontString(panel, index, fontObject)
    if panel.contentTexts[index] then
        local fs = panel.contentTexts[index]
        fs:ClearAllPoints()
        fs:Show()
        return fs
    end
    local fs = panel.scrollChild:CreateFontString(nil, "OVERLAY", fontObject)
    panel.contentTexts[index] = fs
    return fs
end

local function UpdateNotesPanel(panel, notesData)
    for _, text in pairs(panel.contentTexts) do
        text:Hide()
    end

    local yOffset = -5
    local fsIndex = 1

    if not notesData or #notesData == 0 then
        local emptyText = GetOrCreateFontString(panel, fsIndex, "GameFontNormalSmall")
        emptyText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 10, yOffset)
        emptyText:SetText(L["AFKPANEL_NO_NOTES"])
        emptyText:SetTextColor(0.5, 0.5, 0.5, 1)
        emptyText:SetJustifyH("LEFT")
        emptyText:SetWidth(480)
        panel.scrollChild:SetHeight(30)
        return
    end

    for _, noteData in ipairs(notesData) do
        local titleText = GetOrCreateFontString(panel, fsIndex, "GameFontNormal")
        fsIndex = fsIndex + 1
        titleText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 10, yOffset)
        titleText:SetText(noteData.title)
        titleText:SetTextColor(1, 0.82, 0, 1)
        titleText:SetJustifyH("LEFT")
        titleText:SetWidth(480)
        yOffset = yOffset - 20

        if noteData.tasks then
            for _, task in ipairs(noteData.tasks) do
                local taskText = GetOrCreateFontString(panel, fsIndex, "GameFontNormalSmall")
                fsIndex = fsIndex + 1
                taskText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 25, yOffset)
                taskText:SetText("  - " .. task)
                taskText:SetTextColor(0.9, 0.9, 0.9, 1)
                taskText:SetJustifyH("LEFT")
                taskText:SetWidth(465)
                yOffset = yOffset - 18
            end
        end

        yOffset = yOffset - 10
    end

    panel.scrollChild:SetHeight(math.abs(yOffset) + 10)
end

local function UpdateTimer(timerText, startTime)
    local elapsed = GetTime() - startTime
    local minutes = math.floor(elapsed / 60)
    local seconds = math.floor(elapsed % 60)
    timerText:SetFormattedText("AFK: %02d:%02d", minutes, seconds)
end

-- ============================================================
-- Module Core
-- ============================================================

function AFKPanelModule:SetupFrames()
    if self._afkFrame then return end

    local screenWidth  = GetScreenWidth()  * UIParent:GetEffectiveScale()
    local screenHeight = GetScreenHeight() * UIParent:GetEffectiveScale()

    local afkFrame = CreateFrame("Frame", "OneWoW_QoL_AFKFrame")
    afkFrame:SetFrameLevel(1)
    afkFrame:SetScale(UIParent:GetEffectiveScale())
    afkFrame:SetAllPoints(UIParent)
    afkFrame:EnableKeyboard(true)
    afkFrame:SetScript("OnKeyDown", function(frame, key)
        AFKPanelModule:OnKeyDown(key)
    end)
    afkFrame:Hide()
    self._afkFrame = afkFrame

    CreateTopBar(afkFrame)

    local bottomPanel = CreateFrame("Frame", nil, afkFrame, "BackdropTemplate")
    bottomPanel:SetFrameLevel(0)
    bottomPanel:SetPoint("BOTTOM", afkFrame, "BOTTOM", 0, 0)
    bottomPanel:SetWidth(screenWidth)
    bottomPanel:SetHeight(370)
    bottomPanel:SetBackdrop(backdrop)
    bottomPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    bottomPanel:SetBackdropBorderColor(0.8, 0.6, 0.2, 1)
    self._bottomPanel = bottomPanel

    local modelHolder = CreateFrame("Frame", nil, afkFrame)
    modelHolder:SetSize(500, 500)
    modelHolder:SetPoint("CENTER", afkFrame, "CENTER", 0, 50)

    local model = CreateFrame("PlayerModel", "OneWoW_QoL_AFKPlayerModel", modelHolder)
    model:SetPoint("CENTER", modelHolder, "CENTER")
    model:SetSize(screenWidth * 2, screenHeight * 2)
    model:SetCamDistanceScale(3.0)
    model:SetFacing(6)
    self._model = model

    self._infoPanel   = CreateCharacterInfoPanel(bottomPanel)
    self._alertsPanel = CreateAlertsPanel(bottomPanel, self._infoPanel)
    self._dailyPanel  = CreateNotesPanel(bottomPanel, "AFKPANEL_DAILY_NOTES",
        "TOPRIGHT", bottomPanel, "TOPRIGHT", -20, -20)
    self._weeklyPanel = CreateNotesPanel(bottomPanel, "AFKPANEL_WEEKLY_NOTES",
        "TOPRIGHT", self._dailyPanel, "BOTTOMRIGHT", 0, -10)
    self._weeklyPanel:SetHeight(140)
end

function AFKPanelModule:CameraSpin(status)
    if status and ns.ModuleRegistry:GetToggleValue("afkpanel", "camera_spin") then
        MoveViewLeftStart(CAMERA_SPEED)
    else
        MoveViewLeftStop()
    end
end

function AFKPanelModule:SetAFK(status)
    if status then
        self:CameraSpin(true)
        CloseAllWindows()

        self._afkFrame:Show()
        UIParent:Hide()

        local displayData = CollectDisplayData()

        UpdateCharacterInfo(self._infoPanel, displayData)
        UpdateAlerts(self._alertsPanel, displayData)

        local showDaily  = ns.ModuleRegistry:GetToggleValue("afkpanel", "show_daily")
        local showWeekly = ns.ModuleRegistry:GetToggleValue("afkpanel", "show_weekly")

        if showDaily then
            UpdateNotesPanel(self._dailyPanel, displayData.dailyNotes or {})
            self._dailyPanel:Show()
        else
            self._dailyPanel:Hide()
        end

        if showWeekly then
            UpdateNotesPanel(self._weeklyPanel, displayData.weeklyNotes or {})
            self._weeklyPanel:Show()
        else
            self._weeklyPanel:Hide()
        end

        local model = self._model
        model.curAnimation = "wave"
        model.startTime    = GetTime()
        model.duration     = 2.3
        model.isIdle       = nil
        model.idleDuration = 40
        model:SetUnit("player")
        model:SetAnimation(67)
        model:SetScript("OnUpdate", function(self)
            AFKPanelModule:Model_OnUpdate(self)
        end)

        self._startTime = GetTime()
        self._timer = C_Timer.NewTicker(1, function()
            UpdateTimer(self._infoPanel.timerText, self._startTime)
        end)

        self.isAFK = true

    elseif self.isAFK then
        UIParent:Show()
        self._afkFrame:Hide()

        self:CameraSpin(false)

        if self._model then
            self._model:SetScript("OnUpdate", nil)
        end

        if self._timer then
            self._timer:Cancel()
            self._timer = nil
        end
        if self._animTimer then
            self._animTimer:Cancel()
            self._animTimer = nil
        end

        self._infoPanel.timerText:SetText("AFK: 00:00")
        self.isAFK = false
    end
end

function AFKPanelModule:OnKeyDown(key)
    if ignoreKeys[key] then return end

    if printKeys[key] then
        Screenshot()
    elseif self.isAFK then
        self:SetAFK(false)
        C_Timer.After(60, function()
            if AFKPanelModule._eventFrame then
                AFKPanelModule:CheckAFK()
            end
        end)
    end
end

function AFKPanelModule:CheckAFK()
    if InCombatLockdown() then return end
    if CinematicFrame and CinematicFrame:IsShown() then return end
    if MovieFrame and MovieFrame:IsShown() then return end
    if UnitCastingInfo("player") then return end
    local isPetBattle = C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
    self:SetAFK(UnitIsAFK("player") and not isPetBattle)
end

function AFKPanelModule:LoopAnimations()
    local model = self._model
    if not model then return end
    if model.curAnimation == "wave" then
        model:SetAnimation(69)
        model.curAnimation = "dance"
        model.startTime    = GetTime()
        model.duration     = 300
        model.isIdle       = false
        model.idleDuration = 120
    end
end

function AFKPanelModule:Model_OnUpdate(model)
    if not model.isIdle then
        local timePassed = GetTime() - model.startTime
        if timePassed > model.duration then
            model:SetAnimation(0)
            model.isIdle = true

            self._animTimer = C_Timer.After(model.idleDuration, function()
                AFKPanelModule:LoopAnimations()
            end)
        end
    end
end

function AFKPanelModule:OnEnable()
    self:SetupFrames()

    self._origAutoClearAFK = GetCVar("autoClearAFK")
    SetCVar("autoClearAFK", 1)

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_AFKPanelEvents")
        self._eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self._eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
        self._eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
        self._eventFrame:SetScript("OnEvent", function(frame, event, arg1)
            AFKPanelModule:OnEvent(event, arg1)
        end)
    end
end

function AFKPanelModule:OnEvent(event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        self._eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return
    elseif event == "UPDATE_BATTLEFIELD_STATUS" or event == "PLAYER_REGEN_DISABLED" or event == "LFG_PROPOSAL_SHOW" then
        if event ~= "UPDATE_BATTLEFIELD_STATUS" or (GetBattlefieldStatus(arg1) == "confirm") then
            self:SetAFK(false)
        end
        if event == "PLAYER_REGEN_DISABLED" then
            self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end

    if event == "PLAYER_FLAGS_CHANGED" and arg1 ~= "player" then return end
    if InCombatLockdown() then return end
    if CinematicFrame and CinematicFrame:IsShown() then return end
    if MovieFrame and MovieFrame:IsShown() then return end

    if UnitCastingInfo("player") then
        C_Timer.After(30, function()
            AFKPanelModule:OnEvent("PLAYER_FLAGS_CHANGED", "player")
        end)
        return
    end

    local isPetBattle = C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
    self:SetAFK(UnitIsAFK("player") and not isPetBattle)
end

function AFKPanelModule:OnDisable()
    if self.isAFK then
        self:SetAFK(false)
    end
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
    if self._origAutoClearAFK then
        SetCVar("autoClearAFK", self._origAutoClearAFK)
    end
end

function AFKPanelModule:OnToggle(toggleId, value)
    if toggleId == "camera_spin" then
        if self.isAFK then
            self:CameraSpin(value)
        end
    end
end

ns.AFKPanelModule = AFKPanelModule

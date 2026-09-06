local _, ns = ...

-- Metadata table lives in module.lua (loaded first); grab it + this module's locale
-- view here. Capture into file-locals at load -- never read Current() at runtime.
local AFKPanelModule, L = ns.ModuleRegistry:Current()
if not AFKPanelModule then return end

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local math = math

local CAMERA_SPEED = 0.035
local CARD_WIDTH = 360
local DOCK_PAD = 16
local CARD_GAP = 8
local ALERTS_H = 120
local HERE_H = 120
local NOTES_H = 160

-- Intentional cinematic palette; not tied to suite theme.
local PALETTE = {
    BAR_DARK_BG     = { 0.05, 0.05, 0.05, 0.95 },
    BAR_GOLD_BORDER = { 0.8, 0.6, 0.2, 1 },
}

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
    printKeys[KEY_PRINTSCREEN_MAC or "PRINT"] = true
end

local function CreateTopBar(parent)
    local topBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    topBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    topBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    topBar:SetHeight(60)
    topBar:SetFrameLevel(2)
    topBar:SetBackdrop(backdrop)
    topBar:SetBackdropColor(unpack(PALETTE.BAR_DARK_BG))
    topBar:SetBackdropBorderColor(unpack(PALETTE.BAR_GOLD_BORDER))

    local topText = OneWoW_GUI:CreateFS(topBar, 18)
    topText:SetPoint("CENTER", topBar, "CENTER", 0, 0)
    topText:SetText(L["AFKPANEL_MODE_TITLE"])
    topText:SetTextColor(unpack(PALETTE.BAR_GOLD_BORDER))

    return topBar
end

local function NotesEnabled()
    return OneWoW:IsAddonEnabled("OneWoW_Notes")
end

function AFKPanelModule:SetupFrames()
    if self._afkFrame then
        return
    end

    local afkFrame = CreateFrame("Frame", "OneWoW_QoL_AFKFrame")
    afkFrame:SetFrameLevel(1)
    afkFrame:SetScale(UIParent:GetEffectiveScale())
    afkFrame:SetAllPoints(UIParent)
    afkFrame:EnableKeyboard(true)
    afkFrame:SetScript("OnKeyDown", function(_, key)
        AFKPanelModule:OnKeyDown(key)
    end)
    afkFrame:Hide()
    self._afkFrame = afkFrame

    CreateTopBar(afkFrame)

    local bottomPanel = CreateFrame("Frame", nil, afkFrame, "BackdropTemplate")
    bottomPanel:SetFrameLevel(2)
    bottomPanel:SetPoint("BOTTOMLEFT", afkFrame, "BOTTOMLEFT", 0, 0)
    bottomPanel:SetPoint("BOTTOMRIGHT", afkFrame, "BOTTOMRIGHT", 0, 0)
    bottomPanel:SetHeight(ALERTS_H + 2 * DOCK_PAD)
    bottomPanel:SetBackdrop(backdrop)
    bottomPanel:SetBackdropColor(unpack(PALETTE.BAR_DARK_BG))
    bottomPanel:SetBackdropBorderColor(unpack(PALETTE.BAR_GOLD_BORDER))
    self._bottomPanel = bottomPanel
    OneWoW_GUI:RegisterFontRoot(bottomPanel)

    local modelHolder = CreateFrame("Frame", nil, afkFrame)
    modelHolder:SetSize(500, 500)
    modelHolder:SetPoint("CENTER", afkFrame, "CENTER", 0, 50)

    local model = CreateFrame("PlayerModel", "OneWoW_QoL_AFKPlayerModel", modelHolder)
    model:SetPoint("CENTER", modelHolder, "CENTER")
    model:SetSize(UIParent:GetWidth() * 2, UIParent:GetHeight() * 2)
    model:SetCamDistanceScale(3.0)
    model:SetFacing(6)
    self._model = model

    self._infoPanel = OneWoW.StatusCards:CreateYou(bottomPanel, {
        name = "OneWoWAFKYou",
        width = CARD_WIDTH,
        interactive = false,
        mail = true,
        durability = true,
        vault = true,
        cache = true,
        endeavors = true,
        timer = true,
    })
    self._infoPanel:SetPoint("BOTTOMLEFT", bottomPanel, "BOTTOMLEFT", DOCK_PAD, DOCK_PAD)

    self._alertsPanel = OneWoW.StatusCards:CreateAlerts(bottomPanel, {
        name = "OneWoWAFKAlerts",
        width = CARD_WIDTH,
        keepVisible = true,
        fixedHeight = ALERTS_H,
        height = ALERTS_H,
    })
    self._herePanel = OneWoW.StatusCards:CreateHere(bottomPanel, {
        name = "OneWoWAFKHere",
        width = CARD_WIDTH,
        interactive = false,
        collections = false,
        zoneNotes = false,
        fixedHeight = HERE_H,
    })
    self._notesPanel = OneWoW.StatusCards:CreateTaskList(bottomPanel, {
        name = "OneWoWAFKNotes",
        width = CARD_WIDTH,
        height = NOTES_H,
        header = "",
        fixedHeight = NOTES_H,
    })
    self:LayoutDock()
end

function AFKPanelModule:CameraSpin(status)
    if status and ns.ModuleRegistry:GetToggleValue("afkpanel", "camera_spin") then
        MoveViewLeftStart(CAMERA_SPEED)
    else
        MoveViewLeftStop()
    end
end

function AFKPanelModule:LayoutDock()
    local parent = self._bottomPanel
    local rightH = self._herePanel:GetHeight()
    if self._notesPanel:IsShown() then
        rightH = rightH + CARD_GAP + self._notesPanel:GetHeight()
    end
    parent:SetHeight(math.max(
        self._infoPanel:GetHeight(),
        self._alertsPanel:GetHeight(),
        rightH
    ) + 2 * DOCK_PAD)

    self._infoPanel:ClearAllPoints()
    self._infoPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", DOCK_PAD, DOCK_PAD)

    self._alertsPanel:ClearAllPoints()
    self._alertsPanel:SetPoint("BOTTOM", parent, "BOTTOM", 0, DOCK_PAD)

    local rightBottom = parent
    local rightRel = "BOTTOMRIGHT"
    local rightX, rightY = -DOCK_PAD, DOCK_PAD
    if self._notesPanel:IsShown() then
        self._notesPanel:ClearAllPoints()
        self._notesPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -DOCK_PAD, DOCK_PAD)
        rightBottom = self._notesPanel
        rightRel = "TOPRIGHT"
        rightX, rightY = 0, CARD_GAP
    end

    self._herePanel:ClearAllPoints()
    self._herePanel:SetPoint("BOTTOMRIGHT", rightBottom, rightRel, rightX, rightY)
end

function AFKPanelModule:RefreshCards()
    OneWoW.StatusCards:RefreshYou(self._infoPanel, OneWoW.StatusCards:CollectYou({
        vault = true,
        cache = true,
        endeavors = true,
        requestEndeavors = true,
    }))
    OneWoW.StatusCards:SetYouTimer(self._infoPanel, 0)

    OneWoW.StatusCards:RefreshAlerts(self._alertsPanel, OneWoW.StatusCards:CollectAlerts())
    OneWoW.StatusCards:RefreshHere(self._herePanel, OneWoW.StatusCards:CollectHere())

    local notesOn = NotesEnabled()
    local showDaily = notesOn and ns.ModuleRegistry:GetToggleValue("afkpanel", "show_daily")
    local showWeekly = notesOn and ns.ModuleRegistry:GetToggleValue("afkpanel", "show_weekly")
    if notesOn then
        OneWoW:BringUp("OneWoW_Notes")
    end
    local api = OneWoW_Notes_API
    local groups = {}
    if showDaily then
        groups[#groups + 1] = {
            header = L["AFKPANEL_DAILY_NOTES"],
            notes = (api and api.GetIncompleteJournalNotes) and api.GetIncompleteJournalNotes("daily") or {},
        }
    end
    if showWeekly then
        groups[#groups + 1] = {
            header = L["AFKPANEL_WEEKLY_NOTES"],
            notes = (api and api.GetIncompleteJournalNotes) and api.GetIncompleteJournalNotes("weekly") or {},
        }
    end
    if notesOn then
        if #groups > 0 then
            OneWoW.StatusCards:RefreshGroupedTaskList(self._notesPanel, groups)
        else
            OneWoW.StatusCards:RefreshTaskList(self._notesPanel, {})
        end
        self._notesPanel:Show()
    else
        self._notesPanel:Hide()
    end

    self:LayoutDock()
end

function AFKPanelModule:SetAFK(status)
    if status then
        self:CameraSpin(true)
        CloseAllWindows()

        self._afkFrame:Show()
        OneWoW.UIParent:Hide()
        self:RefreshCards()

        local model = self._model
        model.curAnimation = "wave"
        model.startTime    = GetTime()
        model.duration     = 2.3
        model.isIdle       = nil
        model.idleDuration = 40
        model:SetUnit("player")
        model:SetAnimation(67)
        model:SetScript("OnUpdate", function(myself)
            AFKPanelModule:Model_OnUpdate(myself)
        end)

        self._startTime = GetTime()
        self._timer = C_Timer.NewTicker(1, function()
            OneWoW.StatusCards:SetYouTimer(self._infoPanel, GetTime() - self._startTime)
        end)

        self.isAFK = true

    elseif self.isAFK then
        OneWoW.UIParent:Restore()
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

        OneWoW.StatusCards:SetYouTimer(self._infoPanel, 0)
        self.isAFK = false
    end
end

function AFKPanelModule:OnKeyDown(key)
    if ignoreKeys[key] then
        return
    end

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
    if OneWoW.Restriction.IsInCombat() then
        return
    end
    if CinematicFrame and CinematicFrame:IsShown() then
        return
    end
    if MovieFrame and MovieFrame:IsShown() then
        return
    end
    if UnitCastingInfo("player") then
        return
    end
    C_Timer.After(0, function()
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" or instanceType == "arena" then
            return
        end
        local isPetBattle = C_PetBattles.IsInBattle()
        self:SetAFK(UnitIsAFK("player") and not isPetBattle)
    end)
end

function AFKPanelModule:LoopAnimations()
    local model = self._model
    if not model then
        return
    end
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
        self._eventFrame:SetScript("OnEvent", function(_, event, arg1)
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

    if event == "PLAYER_FLAGS_CHANGED" and arg1 ~= "player" then
        return
    end
    if OneWoW.Restriction.IsInCombat() then
        return
    end
    if CinematicFrame and CinematicFrame:IsShown() then
        return
    end
    if MovieFrame and MovieFrame:IsShown() then
        return
    end

    if UnitCastingInfo("player") then
        C_Timer.After(30, function()
            AFKPanelModule:OnEvent("PLAYER_FLAGS_CHANGED", "player")
        end)
        return
    end

    C_Timer.After(0, function()
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" or instanceType == "arena" then
            return
        end
        local isPetBattle = C_PetBattles.IsInBattle()
        self:SetAFK(UnitIsAFK("player") and not isPetBattle)
    end)
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
    elseif self.isAFK and (toggleId == "show_daily" or toggleId == "show_weekly") then
        self:RefreshCards()
    end
end

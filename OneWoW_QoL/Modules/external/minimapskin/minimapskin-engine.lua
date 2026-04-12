local addonName, ns = ...
local M = ns.MinimapSkinModule

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

-- ─── Constants ──────────────────────────────────────────────────────────────

local ROUND_MASK  = "Textures\\MinimapMask"
local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local MINIMAP     = Minimap

-- ─── State ──────────────────────────────────────────────────────────────────

local hiddenFrame
local borderFrame
local zoneFrame, zoneFontStr
local clockFrame, clockFontStr
local clickOverlay
local eventFrame
local skinTooltip
local autoZoomSeq, autoZoomCur = 0, 0
local savedParents = {}
local clockRunning = false

-- ─── Settings ───────────────────────────────────────────────────────────────

local function GetSettings()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return {} end
    local mods = addon.db.global.modules
    if not mods.minimapskin then mods.minimapskin = {} end
    local s = mods.minimapskin
    if s.scale           == nil then s.scale           = 1.0        end
    if s.borderSize      == nil then s.borderSize      = 3          end
    if s.useThemeColor   == nil then s.useThemeColor   = true       end
    if s.autoZoomDelay   == nil then s.autoZoomDelay   = 10         end
    if s.combatFadeAlpha == nil then s.combatFadeAlpha = 0.3        end
    if s.clickRight      == nil then s.clickRight      = "calendar" end
    if s.clickMiddle     == nil then s.clickMiddle     = "tracking" end
    if s.clickBtn4       == nil then s.clickBtn4       = "none"     end
    if s.clickBtn5       == nil then s.clickBtn5       = "none"     end
    if s.showZoomBtns    == nil then s.showZoomBtns    = false      end
    if s.showCompartment == nil then s.showCompartment = false      end
    if s.unclampMinimap  == nil then s.unclampMinimap  = false      end
    if s.zoneFont        == nil then s.zoneFont        = "global"   end
    if s.zoneFontSize    == nil then s.zoneFontSize    = 12         end
    if s.clockFont       == nil then s.clockFont       = "global"   end
    if s.clockFontSize   == nil then s.clockFontSize   = 12         end
    return s
end

M.GetSettings = GetSettings

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("minimapskin", id)
end

local function ResolveFontPath(key)
    if not OneWoW_GUI then return nil end
    if not key or key == "global" then
        return OneWoW_GUI:GetFont()
    end
    return OneWoW_GUI:GetFontByKey(key)
end

-- ─── Hidden Frame ───────────────────────────────────────────────────────────

local function GetHiddenFrame()
    if not hiddenFrame then
        hiddenFrame = CreateFrame("Frame", "OneWoW_QoL_MmSkinHidden")
        hiddenFrame:Hide()
    end
    return hiddenFrame
end

-- ─── Element Show / Hide ────────────────────────────────────────────────────

local function HideElement(frame)
    if not frame then return end
    if not savedParents[frame] then
        savedParents[frame] = frame:GetParent()
    end
    frame:SetParent(GetHiddenFrame())
end

local function RestoreElement(frame)
    if not frame then return end
    local orig = savedParents[frame]
    if orig then
        frame:SetParent(orig)
        savedParents[frame] = nil
    end
end

-- ─── Tooltip ────────────────────────────────────────────────────────────────

local function GetTooltip()
    if not skinTooltip then
        skinTooltip = CreateFrame("GameTooltip", "OneWoW_QoL_MmSkinTooltip", UIParent, "GameTooltipTemplate")
    end
    return skinTooltip
end

-- ─── Layout suppression (only used by DetachMinimap) ────────────────────────

local function SuppressLayout()
    if not M._layoutSuppressed then
        M._layoutSuppressed = true
        M._origLayout = Minimap.Layout
    end
    Minimap.Layout = function() end
end

local function RestoreLayout()
    if M._layoutSuppressed then
        Minimap.Layout = M._origLayout
        M._layoutSuppressed = false
        M._origLayout = nil
    end
end

-- ─── Shape ──────────────────────────────────────────────────────────────────

local function ApplyShape()
    if not MINIMAP then return end
    local isSquare = GetToggle("squareShape")
    local mask = isSquare and SQUARE_MASK or ROUND_MASK

    MINIMAP:SetMaskTexture(mask)

    if isSquare then
        if MinimapCompassTexture then MinimapCompassTexture:Hide() end

        pcall(function()
            MINIMAP:SetArchBlobRingScalar(0)
            MINIMAP:SetArchBlobRingAlpha(0)
            MINIMAP:SetQuestBlobRingScalar(0)
            MINIMAP:SetQuestBlobRingAlpha(0)
        end)

        _G.GetMinimapShape = function() return "SQUARE" end
    else
        if MinimapCompassTexture then MinimapCompassTexture:Show() end

        _G.GetMinimapShape = nil
    end

    if HybridMinimap then
        pcall(function()
            HybridMinimap.MapCanvas:SetUseMaskTexture(false)
            HybridMinimap.CircleMask:SetTexture(mask)
            HybridMinimap.MapCanvas:SetUseMaskTexture(true)
        end)
    end
end

-- ─── Border ─────────────────────────────────────────────────────────────────

local function GetBorderColor()
    local s = GetSettings()

    if GetToggle("classBorder") then
        local _, class = UnitClass("player")
        local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b, 1 end
    end

    if s.useThemeColor and OneWoW_GUI then
        return OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
    end

    if s.borderColor then
        return s.borderColor[1] or 0, s.borderColor[2] or 0, s.borderColor[3] or 0, s.borderColor[4] or 1
    end

    return 0, 0, 0, 1
end

local function CreateBorder()
    if borderFrame then return end
    borderFrame = CreateFrame("Frame", nil, MINIMAP, BackdropTemplateMixin and "BackdropTemplate" or nil)
    borderFrame:SetFrameStrata("BACKGROUND")
    borderFrame:SetFrameLevel(1)
    borderFrame:SetFixedFrameStrata(true)
    borderFrame:SetFixedFrameLevel(true)
end

local function UpdateBorder()
    if not GetToggle("showBorder") or not GetToggle("squareShape") then
        if borderFrame then borderFrame:Hide() end
        return
    end

    CreateBorder()

    local s = GetSettings()
    local bw = s.borderSize

    borderFrame:ClearAllPoints()
    borderFrame:SetPoint("TOPLEFT", MINIMAP, "TOPLEFT", -bw, bw)
    borderFrame:SetPoint("BOTTOMRIGHT", MINIMAP, "BOTTOMRIGHT", bw, -bw)
    borderFrame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = bw,
    })

    local r, g, b, a = GetBorderColor()
    borderFrame:SetBackdropBorderColor(r, g, b, a)
    borderFrame:Show()
end

M.RefreshBorder = UpdateBorder

-- ─── Zone Text ──────────────────────────────────────────────────────────────

local PVP_COLORS = {
    sanctuary = { 0.41, 0.80, 0.94 },
    arena     = { 1.00, 0.10, 0.10 },
    friendly  = { 0.10, 1.00, 0.10 },
    hostile   = { 1.00, 0.10, 0.10 },
    contested = { 1.00, 0.70, 0.00 },
    combat    = { 1.00, 0.10, 0.10 },
}

local function UpdateZoneDisplay()
    if not zoneFontStr then return end
    zoneFontStr:SetText(GetMinimapZoneText())

    local pvpType = (C_PvP and C_PvP.GetZonePVPInfo or GetZonePVPInfo)()
    local c = PVP_COLORS[pvpType]
    if c then
        zoneFontStr:SetTextColor(c[1], c[2], c[3])
    elseif OneWoW_GUI then
        zoneFontStr:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        zoneFontStr:SetTextColor(1, 0.82, 0)
    end
end

local function ApplyZoneFont()
    if not zoneFontStr then return end
    local s = GetSettings()
    local fontPath = ResolveFontPath(s.zoneFont)
    if OneWoW_GUI and fontPath then
        OneWoW_GUI:SafeSetFont(zoneFontStr, fontPath, s.zoneFontSize, "OUTLINE")
    elseif OneWoW_GUI then
        OneWoW_GUI:SafeSetFont(zoneFontStr, OneWoW_GUI:GetFont(), s.zoneFontSize, "OUTLINE")
    else
        zoneFontStr:SetFontObject(GameFontNormalSmall)
    end
    if zoneFrame then
        zoneFrame:SetHeight(s.zoneFontSize + 4)
        zoneFrame:SetWidth(math.max(MINIMAP:GetWidth() + 40, zoneFontStr:GetStringWidth() + 20))
    end
end

M.RefreshZoneFont = ApplyZoneFont

local function CreateZoneText()
    if zoneFrame then return end
    zoneFrame = CreateFrame("Button", nil, MINIMAP)
    zoneFrame:SetHeight(14)
    zoneFrame:EnableMouse(true)

    zoneFontStr = zoneFrame:CreateFontString(nil, "OVERLAY")
    zoneFontStr:SetAllPoints(zoneFrame)
    zoneFontStr:SetJustifyH("CENTER")

    ApplyZoneFont()

    zoneFrame:SetScript("OnEnter", function(self)
        local tt = GetTooltip()
        tt:SetOwner(self, "ANCHOR_LEFT")
        local pvpType, _, factionName = (C_PvP and C_PvP.GetZonePVPInfo or GetZonePVPInfo)()
        local zoneName = GetZoneText()
        local subzone  = GetSubZoneText()
        tt:AddLine(zoneName, 1, 1, 1)
        if subzone ~= zoneName and subzone ~= "" then
            local col = PVP_COLORS[pvpType] or { 1, 0.82, 0 }
            tt:AddLine(subzone, col[1], col[2], col[3])
        end
        if pvpType == "sanctuary" then
            tt:AddLine(SANCTUARY_TERRITORY, 0.41, 0.8, 0.94)
        elseif pvpType == "arena" then
            tt:AddLine(FREE_FOR_ALL_TERRITORY, 1, 0.1, 0.1)
        elseif pvpType == "friendly" and factionName and factionName ~= "" then
            tt:AddLine(FACTION_CONTROLLED_TERRITORY:format(factionName), 0.1, 1, 0.1)
        elseif pvpType == "hostile" and factionName and factionName ~= "" then
            tt:AddLine(FACTION_CONTROLLED_TERRITORY:format(factionName), 1, 0.1, 0.1)
        elseif pvpType == "contested" then
            tt:AddLine(CONTESTED_TERRITORY, 1, 0.7, 0)
        end
        tt:Show()
    end)
    zoneFrame:SetScript("OnLeave", function() GetTooltip():Hide() end)
end

local function ShowZoneText()
    if not GetToggle("showZoneText") then
        if zoneFrame then zoneFrame:Hide() end
        if MinimapCluster then
            if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:SetAlpha(1) end
            if MinimapCluster.BorderTop     then MinimapCluster.BorderTop:SetAlpha(1)     end
        end
        return
    end

    CreateZoneText()
    ApplyZoneFont()
    zoneFrame:ClearAllPoints()
    zoneFrame:SetPoint("BOTTOM", MINIMAP, "TOP", 0, 4)
    zoneFrame:Show()

    if MinimapCluster then
        if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:SetAlpha(0) end
        if MinimapCluster.BorderTop     then MinimapCluster.BorderTop:SetAlpha(0)     end
    end

    UpdateZoneDisplay()
end

-- ─── Clock ──────────────────────────────────────────────────────────────────

local function UpdateClockDisplay()
    if not clockFontStr then return end
    local hour, minute
    if GetCVarBool("timeMgrUseLocalTime") then
        hour, minute = tonumber(date("%H")), tonumber(date("%M"))
    else
        hour, minute = GetGameTime()
    end

    if GetCVarBool("timeMgrUseMilitaryTime") then
        clockFontStr:SetFormattedText(TIMEMANAGER_TICKER_24HOUR, hour, minute)
    else
        if hour == 0 then
            hour = 12
        elseif hour > 12 then
            hour = hour - 12
        end
        clockFontStr:SetFormattedText(TIMEMANAGER_TICKER_12HOUR, hour, minute)
    end
end

local function StartClockUpdates()
    if clockRunning then return end
    clockRunning = true
    local prevMin = -1
    local function warmup()
        if not clockRunning or not clockFrame then return end
        local _, minute
        if GetCVarBool("timeMgrUseLocalTime") then
            minute = tonumber(date("%M"))
        else
            _, minute = GetGameTime()
        end
        UpdateClockDisplay()
        if prevMin == -1 then
            prevMin = minute
            C_Timer.After(0.1, warmup)
        elseif minute ~= prevMin then
            local function longTick()
                if not clockRunning or not clockFrame then return end
                UpdateClockDisplay()
                C_Timer.After(60, longTick)
            end
            longTick()
        else
            C_Timer.After(0.1, warmup)
        end
    end
    warmup()
end

local function StopClockUpdates()
    clockRunning = false
end

local CALENDAR_MONTHS

local function ApplyClockFont()
    if not clockFontStr then return end
    local s = GetSettings()
    local fontPath = ResolveFontPath(s.clockFont)
    if OneWoW_GUI and fontPath then
        OneWoW_GUI:SafeSetFont(clockFontStr, fontPath, s.clockFontSize, "OUTLINE")
        clockFontStr:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    elseif OneWoW_GUI then
        OneWoW_GUI:SafeSetFont(clockFontStr, OneWoW_GUI:GetFont(), s.clockFontSize, "OUTLINE")
        clockFontStr:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        clockFontStr:SetFontObject(GameFontNormalSmall)
    end
    if clockFrame then
        clockFrame:SetHeight(s.clockFontSize + 4)
        clockFontStr:SetText("99:99")
        clockFrame:SetWidth(clockFontStr:GetUnboundedStringWidth() + 20)
        UpdateClockDisplay()
    end
end

M.RefreshClockFont = ApplyClockFont

local function CreateClock()
    if clockFrame then return end
    clockFrame = CreateFrame("Button", nil, MINIMAP)
    clockFrame:SetHeight(14)
    clockFrame:EnableMouse(true)
    clockFrame:RegisterForClicks("AnyUp")

    clockFontStr = clockFrame:CreateFontString(nil, "OVERLAY")
    clockFontStr:SetAllPoints(clockFrame)
    clockFontStr:SetJustifyH("CENTER")

    ApplyClockFont()

    clockFontStr:SetText("99:99")
    clockFrame:SetWidth(clockFontStr:GetUnboundedStringWidth() + 10)

    clockFrame:SetScript("OnEnter", function(self)
        if not CALENDAR_MONTHS then
            CALENDAR_MONTHS = {
                MONTH_JANUARY, MONTH_FEBRUARY, MONTH_MARCH, MONTH_APRIL,
                MONTH_MAY, MONTH_JUNE, MONTH_JULY, MONTH_AUGUST,
                MONTH_SEPTEMBER, MONTH_OCTOBER, MONTH_NOVEMBER, MONTH_DECEMBER,
            }
        end
        local wR, wG, wB = HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b
        local nR, nG, nB = NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
        local dt = date("*t")
        local dateStr = string.format("%d %s %d", dt.day, CALENDAR_MONTHS[dt.month], dt.year)

        local tt = GetTooltip()
        tt:SetOwner(self, "ANCHOR_LEFT")
        tt:AddLine(TIMEMANAGER_TOOLTIP_TITLE, wR, wG, wB)
        tt:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME, GameTime_GetGameTime(true), nR, nG, nB, wR, wG, wB)
        tt:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME, GameTime_GetLocalTime(true), nR, nG, nB, wR, wG, wB)
        tt:AddLine(" ")
        tt:AddLine(dateStr, wR, wG, wB)
        tt:AddLine(" ")
        tt:AddLine(RESET, wR, wG, wB)
        tt:AddDoubleLine(
            STAT_FORMAT:format(DAILY),
            SecondsToTime(C_DateAndTime.GetSecondsUntilDailyReset()),
            nR, nG, nB, wR, wG, wB)
        tt:AddDoubleLine(
            STAT_FORMAT:format(WEEKLY),
            SecondsToTime(C_DateAndTime.GetSecondsUntilWeeklyReset()),
            nR, nG, nB, wR, wG, wB)
        tt:AddLine(" ")
        tt:AddLine(ns.L["MMSKIN_CLOCK_TT_TOGGLE"] or GAMETIME_TOOLTIP_TOGGLE_CLOCK, 0.5, 0.5, 0.6)
        tt:Show()
    end)
    clockFrame:SetScript("OnLeave", function() GetTooltip():Hide() end)
    clockFrame:SetScript("OnClick", function()
        if TimeManagerFrame then
            TimeManagerFrame:SetShown(not TimeManagerFrame:IsShown())
        end
    end)
end

local function ShowClock()
    if not GetToggle("showClock") then
        if clockFrame then clockFrame:Hide() end
        StopClockUpdates()
        if TimeManagerClockButton then TimeManagerClockButton:SetAlpha(1) end
        return
    end

    CreateClock()
    ApplyClockFont()
    clockFrame:ClearAllPoints()
    clockFrame:SetPoint("TOP", MINIMAP, "BOTTOM", 0, -4)
    clockFrame:Show()

    if TimeManagerClockButton then TimeManagerClockButton:SetAlpha(0) end

    UpdateClockDisplay()
    StartClockUpdates()
end

-- ─── Click Bindings ─────────────────────────────────────────────────────────

local CLICK_ACTIONS = {
    calendar = function()
        if not InCombatLockdown() and GameTimeFrame then
            GameTimeFrame:Click()
        end
    end,
    tracking = function()
        local tb = MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button
        if tb and tb.OpenMenu then tb:OpenMenu() end
    end,
    missions = function()
        if ExpansionLandingPageMinimapButton then
            ExpansionLandingPageMinimapButton:Click()
        end
    end,
    map = function()
        if not InCombatLockdown() then ToggleWorldMap() end
    end,
}

local function CreateClickOverlay()
    if clickOverlay then return end
    clickOverlay = CreateFrame("Frame", nil, MINIMAP)
    clickOverlay:SetAllPoints(MINIMAP)
    clickOverlay:EnableMouse(true)
    clickOverlay:SetPassThroughButtons("LeftButton")
    clickOverlay:SetPropagateMouseMotion(true)

    clickOverlay:SetScript("OnMouseUp", function(self, btn)
        if not GetToggle("clickActions") then return end
        local s = GetSettings()

        local actionKey
        if     btn == "RightButton"  then actionKey = s.clickRight
        elseif btn == "MiddleButton" then actionKey = s.clickMiddle
        elseif btn == "Button4"      then actionKey = s.clickBtn4
        elseif btn == "Button5"      then actionKey = s.clickBtn5
        end

        if not actionKey or actionKey == "none" or not CLICK_ACTIONS[actionKey] then return end

        if not GetToggle("squareShape") then
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            x, y = x / scale, y / scale
            local cx, cy = self:GetCenter()
            if math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) > (self:GetWidth() / 2) then
                return
            end
        end

        CLICK_ACTIONS[actionKey]()
    end)
end

local function ShowClickOverlay()
    if not GetToggle("clickActions") then
        if clickOverlay then clickOverlay:Hide() end
        return
    end
    CreateClickOverlay()
    clickOverlay:Show()
end

-- ─── Mouse Wheel Zoom ───────────────────────────────────────────────────────

local function ApplyMouseWheelZoom()
    if not MINIMAP then return end
    if GetToggle("mouseWheelZoom") then
        MINIMAP:EnableMouseWheel(true)
        MINIMAP:SetScript("OnMouseWheel", function(_, d)
            if d > 0 then
                Minimap.ZoomIn:Click()
            elseif d < 0 then
                Minimap.ZoomOut:Click()
            end
        end)
    else
        MINIMAP:EnableMouseWheel(false)
        MINIMAP:SetScript("OnMouseWheel", nil)
    end
end

-- ─── Auto Zoom Out ──────────────────────────────────────────────────────────

local function AutoZoomTick()
    autoZoomCur = autoZoomCur + 1
    if autoZoomSeq == autoZoomCur then
        MINIMAP:SetZoom(0)
        if Minimap.ZoomIn  then Minimap.ZoomIn:Enable()  end
        if Minimap.ZoomOut then Minimap.ZoomOut:Disable() end
        autoZoomSeq, autoZoomCur = 0, 0
    end
end

local function TriggerAutoZoom()
    if not GetToggle("autoZoomOut") then return end
    autoZoomSeq = autoZoomSeq + 1
    C_Timer.After(GetSettings().autoZoomDelay, AutoZoomTick)
end

local function SetupAutoZoom()
    if not Minimap.ZoomIn or not Minimap.ZoomOut then return end
    TriggerAutoZoom()
    if not M._autoZoomHooked then
        M._autoZoomHooked = true
        Minimap.ZoomIn:HookScript("OnClick", TriggerAutoZoom)
        Minimap.ZoomOut:HookScript("OnClick", TriggerAutoZoom)
    end
end

-- ─── Zoom Button Visibility ─────────────────────────────────────────────────

local function ApplyZoomButtons()
    local s = GetSettings()
    if not Minimap.ZoomIn or not Minimap.ZoomOut then return end

    if s.showZoomBtns then
        RestoreElement(Minimap.ZoomIn)
        RestoreElement(Minimap.ZoomOut)
        Minimap.ZoomIn.IsMouseOver  = function() return true end
        Minimap.ZoomOut.IsMouseOver = function() return true end
        Minimap.ZoomIn:Show()
        Minimap.ZoomOut:Show()
    else
        HideElement(Minimap.ZoomIn)
        HideElement(Minimap.ZoomOut)
    end
end

-- ─── Scale ──────────────────────────────────────────────────────────────────

local function ApplyScale()
    if not MINIMAP then return end
    MINIMAP:SetScale(GetSettings().scale)
end

M.RefreshScale = ApplyScale

-- ─── Element Visibility ─────────────────────────────────────────────────────

local function ApplyElementVisibility()
    local mailFrame  = MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame
    local craftFrame = MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.CraftingOrderFrame
    local diffFrame  = MinimapCluster and MinimapCluster.InstanceDifficulty

    if mailFrame then
        if GetToggle("showMail") then RestoreElement(mailFrame) else HideElement(mailFrame) end
    end
    if craftFrame then
        if GetToggle("showCraftingOrder") then RestoreElement(craftFrame) else HideElement(craftFrame) end
    end
    if diffFrame then
        if GetToggle("showDifficulty") then RestoreElement(diffFrame) else HideElement(diffFrame) end
    end
    if ExpansionLandingPageMinimapButton then
        if GetToggle("showMissions") then RestoreElement(ExpansionLandingPageMinimapButton) else HideElement(ExpansionLandingPageMinimapButton) end
    end

    local s = GetSettings()
    if AddonCompartmentFrame then
        if s.showCompartment then RestoreElement(AddonCompartmentFrame) else HideElement(AddonCompartmentFrame) end
    end

    ApplyZoomButtons()
end

M.RefreshElements = ApplyElementVisibility

-- ─── Hide Addon Icons (LibDBIcon ShowOnEnter) ───────────────────────────────

local function ApplyHideAddonIcons()
    local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
    if not ldbi then return end

    local hide = GetToggle("hideAddonIcons")
    local list = ldbi:GetButtonList()
    if list then
        for _, bname in ipairs(list) do
            ldbi:ShowOnEnter(bname, hide)
        end
    end

    if hide and not M._addonIconCB then
        M._addonIconCB = true
        ldbi.RegisterCallback(M, "LibDBIcon_IconCreated", function(_, _, buttonName)
            if GetToggle("hideAddonIcons") then
                ldbi:ShowOnEnter(buttonName, true)
            end
        end)
    end
end

-- ─── Detach / Attach Minimap ────────────────────────────────────────────────

local function DetachMinimap()
    if M._detached then return end
    M._detached = true

    if not M._origMinimapParent then
        M._origMinimapParent = MINIMAP:GetParent()
    end

    MINIMAP:SetFixedFrameStrata(true)
    MINIMAP:SetFixedFrameLevel(true)
    MINIMAP:SetFrameStrata("LOW")
    MINIMAP:SetFrameLevel(2)
    MINIMAP:SetParent(UIParent)

    if MinimapCluster then
        MinimapCluster:EnableMouse(false)
    end

    SuppressLayout()

    MINIMAP:SetMovable(true)
    MINIMAP:SetClampedToScreen(not GetSettings().unclampMinimap)
    MINIMAP:RegisterForDrag("LeftButton")

    MINIMAP:SetScript("OnDragStart", function(self)
        if not GetToggle("lockPosition") then
            self:StartMoving()
        end
    end)
    MINIMAP:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local s = GetSettings()
        local p, _, rp, x, y = self:GetPoint()
        s.position = { p, rp, x, y }
    end)

    local s = GetSettings()
    MINIMAP:ClearAllPoints()
    if s.position then
        MINIMAP:SetPoint(s.position[1], UIParent, s.position[2], s.position[3], s.position[4])
    else
        MINIMAP:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    end
end

local function AttachMinimap()
    if not M._detached then return end
    M._detached = false

    MINIMAP:SetScript("OnDragStart", nil)
    MINIMAP:SetScript("OnDragStop", nil)
    MINIMAP:SetMovable(false)
    MINIMAP:SetClampedToScreen(false)

    RestoreLayout()

    if M._origMinimapParent then
        MINIMAP:SetParent(M._origMinimapParent)
        MINIMAP:ClearAllPoints()
        MINIMAP:SetPoint("CENTER", M._origMinimapParent, "CENTER", 0, 0)
    end

    MINIMAP:SetFixedFrameStrata(false)
    MINIMAP:SetFixedFrameLevel(false)

    if MinimapCluster then
        MinimapCluster:EnableMouse(true)
    end
end

-- ─── Unclamp ───────────────────────────────────────────────────────────────

local function ApplyUnclamp()
    local unclamped = GetSettings().unclampMinimap
    if M._detached then
        MINIMAP:SetClampedToScreen(not unclamped)
    end
    if MinimapCluster then
        MinimapCluster:SetClampedToScreen(not unclamped)
    end
end

M.RefreshUnclamp = ApplyUnclamp

-- ─── Combat Fade ────────────────────────────────────────────────────────────

local function ApplyCombatFadeState(inCombat)
    if not MINIMAP then return end
    if not GetToggle("combatFade") then
        MINIMAP:SetAlpha(1)
        return
    end
    MINIMAP:SetAlpha(inCombat and GetSettings().combatFadeAlpha or 1)
end

-- ─── Events ─────────────────────────────────────────────────────────────────

local function RegisterEvents()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame", "OneWoW_QoL_MmSkinEvents")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
    eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
    eventFrame:RegisterEvent("ADDON_LOADED")

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if not ns.ModuleRegistry:IsEnabled("minimapskin") then return end

        if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
            if zoneFrame and zoneFrame:IsShown() then UpdateZoneDisplay() end
        elseif event == "PLAYER_REGEN_DISABLED" then
            ApplyCombatFadeState(true)
        elseif event == "PLAYER_REGEN_ENABLED" then
            ApplyCombatFadeState(false)
        elseif event == "PET_BATTLE_OPENING_START" then
            if GetToggle("petBattleHide") then MINIMAP:Hide() end
        elseif event == "PET_BATTLE_CLOSE" then
            if GetToggle("petBattleHide") then MINIMAP:Show() end
        elseif event == "ADDON_LOADED" and arg1 == "Blizzard_HybridMinimap" then
            ApplyShape()
        end
    end)
end

local function UnregisterEvents()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
end

-- ─── Theme ──────────────────────────────────────────────────────────────────

function M:ApplyTheme()
    UpdateBorder()
    if zoneFontStr then
        ApplyZoneFont()
        UpdateZoneDisplay()
    end
    if clockFontStr then
        ApplyClockFont()
    end
end

-- ─── Lifecycle ──────────────────────────────────────────────────────────────

function M:OnEnable()
    if not MINIMAP then return end

    ApplyShape()
    UpdateBorder()
    ApplyScale()

    if GetToggle("unlockMinimap") then
        DetachMinimap()
    end
    ApplyUnclamp()

    ApplyElementVisibility()
    ApplyHideAddonIcons()
    ApplyMouseWheelZoom()
    SetupAutoZoom()
    ShowClickOverlay()
    ApplyCombatFadeState(InCombatLockdown())
    RegisterEvents()

    C_Timer.After(0, function()
        if not ns.ModuleRegistry:IsEnabled("minimapskin") then return end
        ShowZoneText()
        ShowClock()
    end)

    if OneWoW_GUI and OneWoW_GUI.RegisterSettingsCallback then
        OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function()
            M:ApplyTheme()
        end)
        OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function()
            M:ApplyTheme()
        end)
    end
end

function M:OnDisable()
    if not MINIMAP then return end

    AttachMinimap()

    if MinimapCluster then
        MinimapCluster:SetClampedToScreen(true)
    end

    MINIMAP:SetMaskTexture(ROUND_MASK)
    _G.GetMinimapShape = nil

    if MinimapCompassTexture then MinimapCompassTexture:Show() end

    RestoreLayout()

    if HybridMinimap then
        pcall(function()
            HybridMinimap.MapCanvas:SetUseMaskTexture(false)
            HybridMinimap.CircleMask:SetTexture(ROUND_MASK)
            HybridMinimap.MapCanvas:SetUseMaskTexture(true)
        end)
    end

    if borderFrame then borderFrame:Hide() end

    MINIMAP:SetScale(1)

    if zoneFrame then zoneFrame:Hide() end
    if MinimapCluster then
        if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:SetAlpha(1) end
        if MinimapCluster.BorderTop     then MinimapCluster.BorderTop:SetAlpha(1)     end
    end

    if clockFrame then clockFrame:Hide() end
    StopClockUpdates()
    if TimeManagerClockButton then TimeManagerClockButton:SetAlpha(1) end

    if clickOverlay then clickOverlay:Hide() end

    MINIMAP:EnableMouseWheel(false)
    MINIMAP:SetScript("OnMouseWheel", nil)

    for frame in pairs(savedParents) do
        RestoreElement(frame)
    end

    local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
    if ldbi then
        local list = ldbi:GetButtonList()
        if list then
            for _, bname in ipairs(list) do
                ldbi:ShowOnEnter(bname, false)
            end
        end
    end

    MINIMAP:SetAlpha(1)

    if not MINIMAP:IsShown() then MINIMAP:Show() end

    UnregisterEvents()
end

function M:OnToggle(toggleId, value)
    if toggleId == "squareShape" then
        ApplyShape()
        UpdateBorder()
    elseif toggleId == "showBorder" or toggleId == "classBorder" then
        UpdateBorder()
    elseif toggleId == "unlockMinimap" then
        if value then
            DetachMinimap()
        else
            AttachMinimap()
        end
    elseif toggleId == "lockPosition" then
        -- nothing to apply; drag handler reads the toggle live
    elseif toggleId == "showZoneText" then
        ShowZoneText()
    elseif toggleId == "showClock" then
        ShowClock()
    elseif toggleId == "mouseWheelZoom" then
        ApplyMouseWheelZoom()
    elseif toggleId == "clickActions" then
        ShowClickOverlay()
    elseif toggleId == "showMail" or toggleId == "showCraftingOrder"
        or toggleId == "showDifficulty" or toggleId == "showMissions" then
        ApplyElementVisibility()
    elseif toggleId == "hideAddonIcons" then
        ApplyHideAddonIcons()
    elseif toggleId == "combatFade" then
        ApplyCombatFadeState(InCombatLockdown())
    elseif toggleId == "petBattleHide" then
        if not value and not MINIMAP:IsShown() then MINIMAP:Show() end
    end

    if self._refreshCustomDetail then self._refreshCustomDetail() end
end

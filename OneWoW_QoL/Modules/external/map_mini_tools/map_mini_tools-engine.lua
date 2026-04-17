local addonName, ns = ...
local M = ns.MapMiniToolsModule

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

-- ─── Constants ──────────────────────────────────────────────────────────────

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local MINIMAP     = Minimap
local MINIMAP_CLUSTER = MinimapCluster

-- ─── State ──────────────────────────────────────────────────────────────────

local hiddenFrame
local borderFrame
local zoneFrame, zoneFontStr
local clockFrame, clockFontStr
local clickOverlay
local eventFrame
local skinTooltip
local autoZoomSeq, autoZoomCur = 0, 0
local savedParents    = {}   -- show/hide toggling (element visibility)
local iconMoveParents = {}   -- { frame = { parent, points[] } } saved before detach
local clockRunning = false
local debugOverlays   = {}   -- colored debug overlay frames, indexed by ICON_FRAMES position
local debugActive     = false
local applyingIconAnchors = false -- re-entrancy guard for SetPoint bursts
local minimapLayoutHooked = false

-- ─── Settings ───────────────────────────────────────────────────────────────

local function GetSettings()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return {} end
    local mods = addon.db.global.modules
    if not mods.map_mini_tools then mods.map_mini_tools = {} end
    local s = mods.map_mini_tools
    if s.scale           == nil then s.scale           = 1.0        end
    if s.minimapAlpha    == nil then s.minimapAlpha    = 1.0        end
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
    -- iconPositions[id] = { cx =, cy = } offsets from Minimap CENTER/CENTER; set while Debug Icons is on
    if not s.iconPositions then s.iconPositions = {} end
    -- zoneTextPos / clockPos = { point, relName, relPoint, x, y } relName: Minimap | MinimapCluster | UIParent
    return s
end

M.GetSettings = GetSettings

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("map_mini_tools", id)
end

local function IsPlumberLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Plumber")
end

M.IsPlumberLoaded = IsPlumberLoaded

--- Plumber adds its own expansion minimap control; hiding Blizzard's avoids a duplicate when our "show missions" reparents the stock button.
local function ShouldHideBlizzardExpansionForPlumber()
    return IsPlumberLoaded() and GetToggle("hideBlizzardExpansionWhenPlumber")
end

local function EnsureExpansionPlumberHook()
    local b = ExpansionLandingPageMinimapButton
    if not b or M._plumberExpansionHook then return end
    M._plumberExpansionHook = true
    b:HookScript("OnShow", function(self)
        if ns.ModuleRegistry:IsEnabled("map_mini_tools") and ShouldHideBlizzardExpansionForPlumber() then
            self:Hide()
        end
    end)
end

--- After debug overlay or visibility changes, Blizzard tooltip can call SetText(nil) unless the button state is refreshed.
local function RefreshExpansionMinimapButtonTooltipState()
    local b = ExpansionLandingPageMinimapButton
    if not b or not b.RefreshButton then return end
    pcall(function() b:RefreshButton(true) end)
end

local function ResolveFontPath(key)
    if not OneWoW_GUI then return nil end
    if not key or key == "global" then
        return OneWoW_GUI:GetFont()
    end
    if key == "wow_default" then
        return select(1, GameFontNormalSmall:GetFont())
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

-- ─── Element Show / Hide (visibility toggles) ───────────────────────────────

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

-- ─── Layout suppression (only DetachMinimap) ────────────────────────────────

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

-- ─── Strata ─────────────────────────────────────────────────────────────────

local function ApplyMinimapStrata()
    MINIMAP:SetFrameStrata("LOW")
    MINIMAP:SetFrameLevel(2)
    MINIMAP:SetFixedFrameStrata(true)
    MINIMAP:SetFixedFrameLevel(true)
end

local function RestoreMinimapStrata()
    MINIMAP:SetFixedFrameStrata(false)
    MINIMAP:SetFixedFrameLevel(false)
end

-- ─── Shape ──────────────────────────────────────────────────────────────────

-- Once SetMaskTexture is called on the Minimap frame there is no API to undo it.
-- BasicMinimap solves this by shipping its own circle texture file.
-- Leatrix_Plus solves this by requiring a UI reload.
-- We take the Leatrix_Plus approach: going back to round requires a reload.

StaticPopupDialogs["ONEWOW_MMSKIN_RELOAD"] = {
    text = "Changing minimap shape requires a UI reload.\nReload now?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = ReloadUI,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function NotifyLibDBIconShapeChanged()
    if ns.MinimapButtonsModule and ns.MinimapButtonsModule.ApplyMinimapShapeToLibDBIcons then
        ns.MinimapButtonsModule:ApplyMinimapShapeToLibDBIcons()
    else
        local lib = LibStub and LibStub("LibDBIcon-1.0", true)
        if lib and lib.SetButtonRadius and lib.GetButtonList and lib.Show then
            local shape = "ROUND"
            if _G.GetMinimapShape then
                shape = GetMinimapShape() or "ROUND"
            end
            if type(shape) == "string" and strupper(shape) == "SQUARE" then
                lib:SetButtonRadius(0.165)
            else
                lib:SetButtonRadius(1)
            end
            for _, n in ipairs(lib:GetButtonList()) do
                pcall(lib.Show, lib, n)
            end
        end
    end
end

local function ApplySquareMask()
    if not MINIMAP then return end

    MINIMAP:SetMaskTexture(SQUARE_MASK)
    if MinimapCompassTexture then MinimapCompassTexture:Hide() end

    pcall(function()
        MINIMAP:SetArchBlobRingScalar(0)
        MINIMAP:SetArchBlobRingAlpha(0)
        MINIMAP:SetQuestBlobRingScalar(0)
        MINIMAP:SetQuestBlobRingAlpha(0)
    end)

    _G.GetMinimapShape = function() return "SQUARE" end

    if HybridMinimap and HybridMinimap.CircleMask then
        pcall(function()
            HybridMinimap.MapCanvas:SetUseMaskTexture(false)
            HybridMinimap.CircleMask:SetTexture(SQUARE_MASK)
            HybridMinimap.MapCanvas:SetUseMaskTexture(true)
        end)
    end

    NotifyLibDBIconShapeChanged()
end

local function ApplyShape()
    if not MINIMAP then return end
    if GetToggle("squareShape") then
        ApplySquareMask()
    end
    -- Round mode is the Blizzard default — never touch masks when round.
    -- If the user toggled square OFF, OnToggle prompts a reload.
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
    borderFrame:SetPoint("TOPLEFT",     MINIMAP, "TOPLEFT",     -bw,  bw)
    borderFrame:SetPoint("BOTTOMRIGHT", MINIMAP, "BOTTOMRIGHT",  bw, -bw)
    borderFrame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = bw,
    })

    local r, g, b, a = GetBorderColor()
    borderFrame:SetBackdropBorderColor(r, g, b, a)
    borderFrame:Show()
end

M.RefreshBorder = UpdateBorder

-- ─── Opacity ─────────────────────────────────────────────────────────────────

local function ApplyMinimapAlpha()
    if not MINIMAP then return end
    MINIMAP:SetAlpha(GetSettings().minimapAlpha)
end

M.RefreshAlpha = ApplyMinimapAlpha

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

-- Top-anchored text so changing font size does not shift the label vertically on the minimap edge.
local function LayoutZoneFontString()
    if not zoneFontStr or not zoneFrame then return end
    zoneFontStr:ClearAllPoints()
    zoneFontStr:SetPoint("TOP", zoneFrame, "TOP", 0, -2)
    zoneFontStr:SetPoint("LEFT", zoneFrame, "LEFT", 6, 0)
    zoneFontStr:SetPoint("RIGHT", zoneFrame, "RIGHT", -6, 0)
    zoneFontStr:SetJustifyH("CENTER")
    zoneFontStr:SetJustifyV("TOP")
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
    LayoutZoneFontString()
    UpdateZoneDisplay()
    if zoneFrame then
        local s2 = GetSettings()
        local textH = zoneFontStr:GetStringHeight()
        zoneFrame:SetHeight(math.max(textH + 6, s2.zoneFontSize + 4))
        zoneFrame:SetWidth(math.max(MINIMAP:GetWidth() + 40, zoneFontStr:GetStringWidth() + 16))
    end
end

M.RefreshZoneFont = ApplyZoneFont

local function ResolveLayoutRelative(relName)
    if relName == "Minimap" and MINIMAP then return MINIMAP end
    if relName == "MinimapCluster" and MinimapCluster then return MinimapCluster end
    return UIParent
end

local function ApplySavedFramePos(frame, key)
    local sdb = GetSettings()[key]
    if not sdb or type(sdb) ~= "table" or #sdb < 5 then return false end
    local rel = ResolveLayoutRelative(sdb[2])
    if not rel then return false end
    frame:ClearAllPoints()
    frame:SetPoint(sdb[1], rel, sdb[3], sdb[4], sdb[5])
    return true
end

local function SaveFrameLayoutPos(frame, key)
    local p, rel, rp, x, y = frame:GetPoint(1)
    if not p then return end
    local relName = "UIParent"
    if rel == MINIMAP then
        relName = "Minimap"
    elseif rel == MinimapCluster then
        relName = "MinimapCluster"
    elseif rel == UIParent then
        relName = "UIParent"
    end
    GetSettings()[key] = { p, relName, rp, x, y }
end

local function HookZoneClockDragScripts()
    if zoneFrame and not zoneFrame._oneWoWDragHooked then
        zoneFrame._oneWoWDragHooked = true
        zoneFrame:SetScript("OnMouseDown", function(self, button)
            if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then return end
            if not GetToggle("zoneClockDraggable") or button ~= "LeftButton" then return end
            if not IsShiftKeyDown() then return end
            if self:IsMovable() then
                self._oneWoWDragging = true
                self:StartMoving()
            end
        end)
        zoneFrame:SetScript("OnMouseUp", function(self)
            if self._oneWoWDragging then
                self:StopMovingOrSizing()
                self._oneWoWDragging = nil
                SaveFrameLayoutPos(self, "zoneTextPos")
            end
        end)
        zoneFrame:SetScript("OnHide", function(self)
            if self._oneWoWDragging then
                self:StopMovingOrSizing()
                self._oneWoWDragging = nil
            end
        end)
    end

    if clockFrame and not clockFrame._oneWoWDragHooked then
        clockFrame._oneWoWDragHooked = true
        clockFrame:SetScript("OnMouseDown", function(self, button)
            if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then return end
            if not GetToggle("zoneClockDraggable") or button ~= "LeftButton" then return end
            if not IsShiftKeyDown() then return end
            if self:IsMovable() then
                self._oneWoWDragging = true
                self:StartMoving()
            end
        end)
        clockFrame:SetScript("OnMouseUp", function(self, button)
            if self._oneWoWDragging then
                self:StopMovingOrSizing()
                self._oneWoWDragging = nil
                SaveFrameLayoutPos(self, "clockPos")
                return
            end
            if button == "LeftButton" and not InCombatLockdown() and TimeManagerFrame then
                TimeManagerFrame:SetShown(not TimeManagerFrame:IsShown())
            end
        end)
        clockFrame:SetScript("OnHide", function(self)
            if self._oneWoWDragging then
                self:StopMovingOrSizing()
                self._oneWoWDragging = nil
            end
        end)
    end
end

local function ApplyZoneTextLayout()
    if not zoneFrame then return end
    if GetToggle("zoneClockDraggable") then
        zoneFrame:SetParent(UIParent)
        -- Match the minimap stack so zone text stays above the minimap but not above unrelated UI.
        zoneFrame:SetFrameStrata(MINIMAP:GetFrameStrata() or "LOW")
        zoneFrame:SetFrameLevel((MINIMAP:GetFrameLevel() or 2) + 5)
        zoneFrame:SetMovable(true)
        zoneFrame:SetClampedToScreen(true)
        if not ApplySavedFramePos(zoneFrame, "zoneTextPos") then
            zoneFrame:ClearAllPoints()
            if GetToggle("zoneClockInside") then
                zoneFrame:SetPoint("TOP", MINIMAP, "TOP", 0, -6)
            else
                zoneFrame:SetPoint("BOTTOM", MINIMAP, "TOP", 0, 4)
            end
        end
        HookZoneClockDragScripts()
    else
        zoneFrame:SetParent(MINIMAP)
        zoneFrame:SetMovable(false)
        zoneFrame:SetClampedToScreen(false)
        zoneFrame:ClearAllPoints()
        if GetToggle("zoneClockInside") then
            zoneFrame:SetFrameStrata("HIGH")
            zoneFrame:SetFrameLevel((MINIMAP:GetFrameLevel() or 2) + 25)
            zoneFrame:SetPoint("TOP", MINIMAP, "TOP", 0, -6)
        else
            zoneFrame:SetPoint("BOTTOM", MINIMAP, "TOP", 0, 4)
        end
        HookZoneClockDragScripts()
    end
end

local function ApplyClockLayout()
    if not clockFrame then return end
    if GetToggle("zoneClockDraggable") then
        clockFrame:SetParent(UIParent)
        clockFrame:SetFrameStrata(MINIMAP:GetFrameStrata() or "LOW")
        clockFrame:SetFrameLevel((MINIMAP:GetFrameLevel() or 2) + 5)
        clockFrame:SetMovable(true)
        clockFrame:SetClampedToScreen(true)
        if not ApplySavedFramePos(clockFrame, "clockPos") then
            clockFrame:ClearAllPoints()
            if GetToggle("zoneClockInside") then
                clockFrame:SetPoint("BOTTOM", MINIMAP, "BOTTOM", 0, 6)
            else
                clockFrame:SetPoint("TOP", MINIMAP, "BOTTOM", 0, -4)
            end
        end
        HookZoneClockDragScripts()
    else
        clockFrame:SetParent(MINIMAP)
        clockFrame:SetMovable(false)
        clockFrame:SetClampedToScreen(false)
        clockFrame:ClearAllPoints()
        if GetToggle("zoneClockInside") then
            clockFrame:SetFrameStrata("HIGH")
            clockFrame:SetFrameLevel((MINIMAP:GetFrameLevel() or 2) + 25)
            clockFrame:SetPoint("BOTTOM", MINIMAP, "BOTTOM", 0, 6)
        else
            clockFrame:SetPoint("TOP", MINIMAP, "BOTTOM", 0, -4)
        end
        HookZoneClockDragScripts()
    end
end

local function CreateZoneText()
    if zoneFrame then return end
    zoneFrame = CreateFrame("Button", nil, MINIMAP)
    zoneFrame:SetHeight(14)
    zoneFrame:EnableMouse(true)

    zoneFontStr = zoneFrame:CreateFontString(nil, "OVERLAY")
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
    ApplyZoneTextLayout()
    zoneFrame:Show()

    if MinimapCluster then
        if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:SetAlpha(0) end
        if MinimapCluster.BorderTop     then MinimapCluster.BorderTop:SetAlpha(0)     end
    end

    UpdateZoneDisplay()
end

-- ─── Clock ──────────────────────────────────────────────────────────────────

-- Single CENTER anchor: never stretch the font string between LEFT/RIGHT (that forces truncation / "22:...").
local function LayoutClockFontString()
    if not clockFontStr or not clockFrame then return end
    clockFontStr:ClearAllPoints()
    clockFontStr:SetPoint("CENTER", clockFrame, "CENTER", 0, 0)
    clockFontStr:SetJustifyH("CENTER")
    clockFontStr:SetJustifyV("MIDDLE")
    clockFontStr:SetWordWrap(false)
end

local function FitClockFrameToText()
    if not clockFrame or not clockFontStr then return end
    local s2 = GetSettings()
    -- Unbounded width avoids measuring while the string is still squeezed by a narrow parent.
    local uw = clockFontStr.GetUnboundedStringWidth and clockFontStr:GetUnboundedStringWidth()
        or clockFontStr:GetStringWidth()
    local textH = clockFontStr:GetStringHeight()
    -- ~2× measured width + padding: 12h + AM/PM, locales, outline, and UI scale cannot clip.
    clockFrame:SetHeight(math.max(textH + 8, (s2.clockFontSize or 12) + 6))
    clockFrame:SetWidth(math.max(uw * 2 + 32, 144))
end

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
    FitClockFrameToText()
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
    LayoutClockFontString()
    if clockFrame then
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
    clockFontStr:SetJustifyH("CENTER")

    ApplyClockFont()

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
    -- Click / Shift-drag handled in HookZoneClockDragScripts (OnMouseUp)
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
    ApplyClockLayout()
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
        if Minimap.ZoomIn  then Minimap.ZoomIn:Enable()   end
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
    local sc = GetSettings().scale
    if M._detached then
        if MINIMAP_CLUSTER then MINIMAP_CLUSTER:SetScale(1) end
        MINIMAP:SetScale(sc)
    else
        MINIMAP:SetScale(1)
        if MINIMAP_CLUSTER then MINIMAP_CLUSTER:SetScale(sc) end
    end
end

M.RefreshScale = ApplyScale

-- ─── Element Visibility ─────────────────────────────────────────────────────
-- When detached, "visible" icons live on MINIMAP so they move with it.
-- When attached, "visible" icons live on their original parent.

local function GetShowParent(frame)
    if M._detached then
        return MINIMAP
    end
    -- iconMoveParents[frame] = { parent, points[] } — saved during detach
    local moveSaved = iconMoveParents[frame]
    if moveSaved then return moveSaved.parent end
    -- savedParents[frame] = original parent saved by HideElement
    -- Must use this when restoring a frame that was hidden, otherwise
    -- frame:GetParent() returns GetHiddenFrame() and the icon stays invisible.
    if savedParents[frame] then return savedParents[frame] end
    return frame:GetParent()
end

local function ApplyElementVisibility()
    local mailFrame  = MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame
    local craftFrame = MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.CraftingOrderFrame
    local diffFrame  = MinimapCluster and MinimapCluster.InstanceDifficulty

    if mailFrame then
        if GetToggle("showMail") then
            mailFrame:SetParent(GetShowParent(mailFrame))
            savedParents[mailFrame] = nil
        else
            HideElement(mailFrame)
        end
    end
    if craftFrame then
        if GetToggle("showCraftingOrder") then
            craftFrame:SetParent(GetShowParent(craftFrame))
            savedParents[craftFrame] = nil
        else
            HideElement(craftFrame)
        end
    end
    if diffFrame then
        if GetToggle("showDifficulty") then
            diffFrame:SetParent(GetShowParent(diffFrame))
            savedParents[diffFrame] = nil
        else
            HideElement(diffFrame)
        end
    end

    local trackingCluster = MinimapCluster and MinimapCluster.Tracking
    if trackingCluster then
        if GetToggle("showTracking") then
            trackingCluster:SetParent(GetShowParent(trackingCluster))
            savedParents[trackingCluster] = nil
            trackingCluster:Show()
        else
            HideElement(trackingCluster)
        end
    end

    if ExpansionLandingPageMinimapButton then
        local showBlizzardExpansion = GetToggle("showMissions") and not ShouldHideBlizzardExpansionForPlumber()
        if showBlizzardExpansion then
            EnsureExpansionPlumberHook()
            ExpansionLandingPageMinimapButton:SetParent(GetShowParent(ExpansionLandingPageMinimapButton))
            savedParents[ExpansionLandingPageMinimapButton] = nil
            ExpansionLandingPageMinimapButton:Show()
        else
            HideElement(ExpansionLandingPageMinimapButton)
        end
    end

    local s = GetSettings()
    if AddonCompartmentFrame then
        if s.showCompartment then
            AddonCompartmentFrame:SetParent(GetShowParent(AddonCompartmentFrame))
            savedParents[AddonCompartmentFrame] = nil
        else
            HideElement(AddonCompartmentFrame)
        end
    end

    ApplyZoomButtons()
    if M.RefreshAddonCompartmentLayout then
        M.RefreshAddonCompartmentLayout()
    end
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

-- ─── Icon Reparent (detach / attach) ────────────────────────────────────────
-- Each entry carries a getter, a display name for debug, and the anchor offset
-- to use when reparented to MINIMAP. Positions are relative to the MINIMAP frame
-- itself so they work for both circle and square shapes. Tune via Debug Icons.

local ICON_FRAMES = {
    { id = "mail",       name = "Mail",        color = {1, 0.82, 0,   0.7},
      getter  = function() return MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame end,
      anchor  = { "TOPRIGHT",    "TOPRIGHT",    -2,   2 } },
    { id = "crafting",   name = "Crafting",    color = {1, 0.45, 0,   0.7},
      getter  = function() return MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.CraftingOrderFrame end,
      anchor  = { "TOPRIGHT",    "TOPRIGHT",   -28,   2 } },
    { id = "difficulty", name = "Difficulty",  color = {1, 0.2,  0.2, 0.7},
      getter  = function() return MinimapCluster and MinimapCluster.InstanceDifficulty end,
      anchor  = { "TOPLEFT",     "TOPLEFT",      2,   2 } },
    { id = "missions",   name = "Missions",    color = {0.6, 0.2, 1,  0.7},
      getter  = function() return ExpansionLandingPageMinimapButton end,
      anchor  = { "BOTTOMRIGHT", "BOTTOMRIGHT", -2,  -2 } },
    { id = "compartment", name = "Compartment", color = {0, 0.8,  1,   0.7},
      getter  = function() return AddonCompartmentFrame end,
      anchor  = { "TOPLEFT",     "TOPLEFT",      2, -24 } },
    { id = "gametime",   name = "GameTime",    color = {0.2, 1,  0.2, 0.7},
      getter  = function() return GameTimeFrame end,
      anchor  = { "BOTTOMLEFT",  "BOTTOMLEFT",   2,  -2 } },
    -- Whole cluster frame (reparenting only .Button left an empty Tracking ring on MinimapCluster).
    { id = "tracking",   name = "Tracking",    color = {0.2, 0.5, 1,  0.7},
      getter  = function() return MinimapCluster and MinimapCluster.Tracking end,
      anchor  = { "BOTTOM",      "BOTTOM",       0,  -8 } },
}

local function FrameCenterOffsetFromMinimapCenter(f)
    if not f or not MINIMAP then return 0, 0 end
    local mw, mh = MINIMAP:GetSize()
    local fw, fh = f:GetSize()
    local left, bottom = f:GetLeft(), f:GetBottom()
    if not left or not bottom then return 0, 0 end
    return left + fw / 2 - mw / 2, bottom + fh / 2 - mh / 2
end

local function ClampIconCenterOffset(cx, cy, f)
    if not f or not MINIMAP then return cx, cy end
    local mw, mh = MINIMAP:GetSize()
    local fw, fh = f:GetSize()
    local margin = 2
    local maxX = math.max(0, mw / 2 - fw / 2 - margin)
    local maxY = math.max(0, mh / 2 - fh / 2 - margin)
    cx = math.max(-maxX, math.min(maxX, cx))
    cy = math.max(-maxY, math.min(maxY, cy))
    return cx, cy
end

local function ApplyIconAnchorToMinimap(f, def)
    if not f or not MINIMAP or not def then return end
    applyingIconAnchors = true
    f:SetParent(MINIMAP)
    f:ClearAllPoints()
    local pos = GetSettings().iconPositions[def.id]
    if pos and pos.cx ~= nil and pos.cy ~= nil then
        f:SetPoint("CENTER", MINIMAP, "CENTER", pos.cx, pos.cy)
    else
        local a = def.anchor
        f:SetPoint(a[1], MINIMAP, a[2], a[3], a[4])
    end
    applyingIconAnchors = false
end

-- Blizzard Minimap:Layout() repositions children; StartMoving also fights that — use saved anchors next frame.
local function ReapplySavedMinimapIconAnchors()
    if applyingIconAnchors or not MINIMAP then return end
    if not (debugActive or M._detached) then return end
    local s = GetSettings()
    if not s.iconPositions then return end
    applyingIconAnchors = true
    for _, def in ipairs(ICON_FRAMES) do
        local pos = s.iconPositions[def.id]
        if pos and pos.cx ~= nil and pos.cy ~= nil then
            local f = def.getter()
            if f and f:GetParent() == MINIMAP then
                f:ClearAllPoints()
                f:SetPoint("CENTER", MINIMAP, "CENTER", pos.cx, pos.cy)
            end
        end
    end
    applyingIconAnchors = false
end

local function EnsureMinimapLayoutHooks()
    if minimapLayoutHooked or not MINIMAP then return end
    if not MINIMAP.Layout then return end
    minimapLayoutHooked = true
    hooksecurefunc(MINIMAP, "Layout", function()
        if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then return end
        C_Timer.After(0, ReapplySavedMinimapIconAnchors)
    end)
    if MinimapCluster and MinimapCluster.Layout then
        hooksecurefunc(MinimapCluster, "Layout", function()
            if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then return end
            C_Timer.After(0, ReapplySavedMinimapIconAnchors)
        end)
    end
end

local function FinishDebugIconDrag(ov)
    if not ov or not ov._oneWoWDragging then return end
    local d = ov._oneWoWIconDrag
    if not d then
        ov._oneWoWDragging = false
        ov:SetScript("OnUpdate", nil)
        return
    end
    ov._oneWoWDragging = false
    ov._oneWoWIconDrag = nil
    ov:SetScript("OnUpdate", nil)
    local f = d.f
    local def = d.def
    if not f or not def or f:GetParent() ~= MINIMAP then return end
    local cx, cy = ClampIconCenterOffset(d.icx, d.icy, f)
    applyingIconAnchors = true
    f:ClearAllPoints()
    f:SetPoint("CENTER", MINIMAP, "CENTER", cx, cy)
    applyingIconAnchors = false
    local s = GetSettings()
    s.iconPositions[def.id] = { cx = cx, cy = cy }
    ReapplySavedMinimapIconAnchors()
    C_Timer.After(0, ReapplySavedMinimapIconAnchors)
end

local function DebugIconDragUpdate(self, elapsed)
    local d = self._oneWoWIconDrag
    if not d or not self._oneWoWDragging then return end
    if not debugActive or not IsMouseButtonDown("LeftButton") then
        FinishDebugIconDrag(self)
        return
    end
    local mx, my = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    local dx = (mx - d.lastX) / scale
    local dy = (my - d.lastY) / scale
    d.lastX, d.lastY = mx, my
    d.icx = d.icx + dx
    d.icy = d.icy + dy
    local cx, cy = ClampIconCenterOffset(d.icx, d.icy, d.f)
    d.icx, d.icy = cx, cy
    applyingIconAnchors = true
    d.f:ClearAllPoints()
    d.f:SetPoint("CENTER", MINIMAP, "CENTER", cx, cy)
    applyingIconAnchors = false
end

local function SetupDebugIconDrag(ov, f, def)
    if not ov or ov._oneWoWIconDragSetup then return end
    ov._oneWoWIconDragSetup = true
    ov:EnableMouse(true)
    ov:SetScript("OnMouseDown", function(self, button)
        if not debugActive or button ~= "LeftButton" then return end
        local parent = self:GetParent()
        if not parent or parent:GetParent() ~= MINIMAP then return end
        local mx, my = GetCursorPosition()
        local icx, icy = FrameCenterOffsetFromMinimapCenter(parent)
        self._oneWoWDragging = true
        self._oneWoWIconDrag = { f = parent, def = def, lastX = mx, lastY = my, icx = icx, icy = icy }
        self:SetScript("OnUpdate", DebugIconDragUpdate)
    end)
    ov:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        FinishDebugIconDrag(self)
    end)
end

local function SaveIconPoints(f)
    local data = { parent = f:GetParent(), points = {} }
    for i = 1, f:GetNumPoints() do
        local p, rel, rp, x, y = f:GetPoint(i)
        data.points[i] = { p, rel, rp, x, y }
    end
    iconMoveParents[f] = data
end

local function ReparentIconsToMinimap()
    for _, def in ipairs(ICON_FRAMES) do
        local f = def.getter()
        if f and f:GetParent() ~= GetHiddenFrame() then
            if not iconMoveParents[f] then
                SaveIconPoints(f)
            end
            ApplyIconAnchorToMinimap(f, def)
        end
    end
end

local function RestoreIconParents()
    for _, def in ipairs(ICON_FRAMES) do
        local f = def.getter()
        if f and iconMoveParents[f] then
            local saved = iconMoveParents[f]
            f:SetParent(saved.parent)
            f:ClearAllPoints()
            for _, pt in ipairs(saved.points) do
                -- pt[2] may be nil if the original anchor was relative to parent
                if pt[2] then
                    f:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
                else
                    f:SetPoint(pt[1], saved.parent, pt[3], pt[4], pt[5])
                end
            end
            iconMoveParents[f] = nil
        end
    end
end

-- ─── Debug Icon Overlays ─────────────────────────────────────────────────────

local function HideDebugOverlays()
    debugActive = false
    for _, ov in pairs(debugOverlays) do
        if ov then ov:Hide() end
    end
    -- Re-anchor Blizzard icons on the cluster when not using a detached minimap.
    if not M._detached then
        RestoreIconParents()
    end
    ApplyElementVisibility()
    RefreshExpansionMinimapButtonTooltipState()
end

local function ShowDebugOverlays()
    debugActive = true
    for i, def in ipairs(ICON_FRAMES) do
        local f = def.getter()
        if f then
            if f:GetParent() ~= MINIMAP then
                if f:GetParent() ~= GetHiddenFrame() and not iconMoveParents[f] then
                    SaveIconPoints(f)
                end
                f:SetParent(MINIMAP)
            end
            ApplyIconAnchorToMinimap(f, def)
            f:Show()

            -- Build or reuse the overlay
            local ov = debugOverlays[i]
            if not ov then
                ov = CreateFrame("Frame", nil, f)
                ov:SetFrameStrata("TOOLTIP")
                ov:SetFrameLevel(100)

                local bg = ov:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                local c = def.color
                bg:SetColorTexture(c[1], c[2], c[3], c[4])

                local lbl = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                lbl:SetAllPoints()
                lbl:SetText(def.name)
                lbl:SetTextColor(0, 0, 0)
                lbl:SetJustifyH("CENTER")
                lbl:SetJustifyV("MIDDLE")

                debugOverlays[i] = ov
            end
            ov:SetParent(f)
            ov:SetAllPoints(f)
            ov:Show()
            SetupDebugIconDrag(ov, f, def)
        end
    end
    RefreshExpansionMinimapButtonTooltipState()
end

function M.DebugIconsToggle()
    if debugActive then
        HideDebugOverlays()
    else
        ShowDebugOverlays()
    end
    M._debugActive = debugActive
end

-- ─── Detach / Attach Minimap ────────────────────────────────────────────────

local function DetachMinimap()
    if M._detached then return end
    M._detached = true

    if not M._origMinimapParent then
        M._origMinimapParent = MINIMAP:GetParent()
    end

    MINIMAP:SetParent(UIParent)
    ApplyMinimapStrata()

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

    ReparentIconsToMinimap()
    ApplyScale()
end

local function AttachMinimap()
    if not M._detached then return end
    M._detached = false

    RestoreIconParents()

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

-- ─── Unclamp ─────────────────────────────────────────────────────────────────

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

-- ─── Addon compartment (square layout, Leatrix-style) ─────────────────────

local compartmentSquareSaved = nil -- { strata, parent, points = { {p1..p5}, ... } }
local compartmentSquareActive = false

local function SnapshotAddonCompartment()
    local f = AddonCompartmentFrame
    if not f or compartmentSquareSaved then return end
    local pts = {}
    for i = 1, f:GetNumPoints() do
        local p1, p2, p3, p4, p5 = f:GetPoint(i)
        pts[i] = { p1, p2, p3, p4, p5 }
    end
    compartmentSquareSaved = {
        strata = f:GetFrameStrata(),
        parent = f:GetParent(),
        points = pts,
    }
end

local function RestoreAddonCompartmentSnapshot()
    local f = AddonCompartmentFrame
    if not f or not compartmentSquareSaved then return end
    local s = compartmentSquareSaved
    f:SetFrameStrata(s.strata or "MEDIUM")
    f:SetParent(s.parent)
    f:ClearAllPoints()
    for i = 1, #s.points do
        local t = s.points[i]
        if t then
            pcall(function()
                f:SetPoint(t[1], t[2], t[3], t[4], t[5])
            end)
        end
    end
    compartmentSquareActive = false
end

local function ApplyAddonCompartmentSquareLayout()
    local f = AddonCompartmentFrame
    if not f or not MINIMAP then return end
    if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then return end

    local want = GetToggle("squareShape") and GetSettings().showCompartment
    if not want or f:GetParent() == GetHiddenFrame() then
        if compartmentSquareActive then
            RestoreAddonCompartmentSnapshot()
        end
        return
    end

    if not compartmentSquareSaved then
        SnapshotAddonCompartment()
    end
    f:SetFrameStrata("MEDIUM")
    f:ClearAllPoints()
    local sdb = GetSettings().iconPositions
    if sdb and sdb.compartment and sdb.compartment.cx ~= nil and sdb.compartment.cy ~= nil then
        f:SetPoint("CENTER", MINIMAP, "CENTER", sdb.compartment.cx, sdb.compartment.cy)
    else
        f:SetPoint("TOPRIGHT", MINIMAP, "TOPRIGHT", -2, -2)
    end
    compartmentSquareActive = true
end

M.RefreshAddonCompartmentLayout = ApplyAddonCompartmentSquareLayout

-- ─── Hide minimap world map button ───────────────────────────────────────────

local function ApplyWorldMapButtonVisibility()
    local b = MiniMapWorldMapButton
    if not b then return end
    if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then
        b:Show()
        return
    end
    if GetToggle("hideWorldMapButton") then
        b:Hide()
    else
        b:Show()
    end
end

local function EnsureWorldMapButtonHook()
    local b = MiniMapWorldMapButton
    if not b or M._worldMapBtnHooked then return end
    M._worldMapBtnHooked = true
    b:HookScript("OnShow", function(self)
        if ns.ModuleRegistry:IsEnabled("map_mini_tools") and GetToggle("hideWorldMapButton") then
            self:Hide()
        end
    end)
end

M.RefreshWorldMapButton = ApplyWorldMapButtonVisibility

-- ─── Combat Fade ────────────────────────────────────────────────────────────

local function ApplyCombatFadeState(inCombat)
    if not MINIMAP then return end
    local base = GetSettings().minimapAlpha
    if not GetToggle("combatFade") then
        MINIMAP:SetAlpha(base)
        return
    end
    MINIMAP:SetAlpha(inCombat and (base * GetSettings().combatFadeAlpha) or base)
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
        if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then return end

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
        elseif event == "ADDON_LOADED" then
            if arg1 == "Blizzard_HybridMinimap" then
                if GetToggle("squareShape") then
                    ApplySquareMask()
                else
                    NotifyLibDBIconShapeChanged()
                end
            elseif arg1 == "Plumber" then
                EnsureExpansionPlumberHook()
                ApplyElementVisibility()
            end
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
        if zoneFrame then ApplyZoneTextLayout() end
    end
    if clockFontStr then
        ApplyClockFont()
        if clockFrame then ApplyClockLayout() end
    end
end

-- ─── Lifecycle ──────────────────────────────────────────────────────────────

function M:OnEnable()
    if not MINIMAP then return end

    EnsureMinimapLayoutHooks()

    ApplyMinimapStrata()
    ApplyShape()
    UpdateBorder()
    ApplyScale()
    ApplyMinimapAlpha()

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
        if not ns.ModuleRegistry:IsEnabled("map_mini_tools") then return end
        ShowZoneText()
        ShowClock()
        ApplyAddonCompartmentSquareLayout()
    end)

    EnsureWorldMapButtonHook()
    ApplyWorldMapButtonVisibility()

    EnsureExpansionPlumberHook()

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

    if compartmentSquareActive then
        RestoreAddonCompartmentSnapshot()
    end
    compartmentSquareSaved = nil

    if MiniMapWorldMapButton then
        MiniMapWorldMapButton:Show()
    end

    AttachMinimap()

    if MinimapCluster then
        MinimapCluster:SetClampedToScreen(true)
    end

    -- If square mask was applied, a reload is needed to restore Blizzard default
    if GetToggle("squareShape") then
        StaticPopup_Show("ONEWOW_MMSKIN_RELOAD")
    end

    RestoreLayout()
    RestoreMinimapStrata()

    if borderFrame then borderFrame:Hide() end

    MINIMAP:SetScale(1)
    if MinimapCluster then MinimapCluster:SetScale(1) end
    MINIMAP:SetAlpha(1)

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

    -- Restore all visibility-toggled elements
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

    if not MINIMAP:IsShown() then MINIMAP:Show() end

    -- Clean up any active debug overlays
    if debugActive then
        debugActive = false
        M._debugActive = false
        for _, ov in pairs(debugOverlays) do
            if ov then ov:Hide() end
        end
    end

    UnregisterEvents()
end

function M:OnToggle(toggleId, value)
    if toggleId == "squareShape" then
        if value then
            ApplySquareMask()
        else
            StaticPopup_Show("ONEWOW_MMSKIN_RELOAD")
        end
        UpdateBorder()
        ApplyAddonCompartmentSquareLayout()
    elseif toggleId == "showBorder" or toggleId == "classBorder" then
        UpdateBorder()
    elseif toggleId == "unlockMinimap" then
        if value then
            DetachMinimap()
        else
            AttachMinimap()
        end
        ApplyScale()
        ApplyElementVisibility()
    elseif toggleId == "lockPosition" then
        -- drag handler reads toggle live
    elseif toggleId == "showZoneText" then
        ShowZoneText()
    elseif toggleId == "showClock" then
        ShowClock()
    elseif toggleId == "zoneClockInside" or toggleId == "zoneClockDraggable" then
        ShowZoneText()
        ShowClock()
    elseif toggleId == "mouseWheelZoom" then
        ApplyMouseWheelZoom()
    elseif toggleId == "clickActions" then
        ShowClickOverlay()
    elseif toggleId == "showMail" or toggleId == "showCraftingOrder"
        or toggleId == "showDifficulty" or toggleId == "showTracking"
        or toggleId == "showMissions" or toggleId == "hideBlizzardExpansionWhenPlumber" then
        ApplyElementVisibility()
    elseif toggleId == "hideAddonIcons" then
        ApplyHideAddonIcons()
    elseif toggleId == "combatFade" then
        ApplyCombatFadeState(InCombatLockdown())
    elseif toggleId == "petBattleHide" then
        if not value and not MINIMAP:IsShown() then MINIMAP:Show() end
    elseif toggleId == "hideWorldMapButton" then
        ApplyWorldMapButtonVisibility()
    end

    if self._refreshCustomDetail then self._refreshCustomDetail() end
end

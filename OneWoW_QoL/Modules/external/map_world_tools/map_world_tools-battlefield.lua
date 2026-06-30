local _, ns = ...

local MapWorldToolsModule = ns.ModuleRegistry:Current()
local M = MapWorldToolsModule

local centerTime = -1
local dragHitFrame
local battleDriver
local centerTicker
local lastCanvasScale
local wasPanning

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("map_world_tools", id)
end

local function GetS()
    return M.GetSettings()
end

local function NeedsBattlefieldFeatures()
    if not ns.ModuleRegistry:IsEnabled("map_world_tools") then
        return false
    end
    return GetToggle("enhanceBattleMap") or GetToggle("unlockBattlefield")
end

function M.RefreshBattlefieldEnhance() end

local function EnsureBattleDriver()
    if battleDriver then
        return battleDriver
    end
    battleDriver = CreateFrame("Frame", "OneWoW_QoL_BattleMapDriver", UIParent)
    battleDriver:Hide()
    return battleDriver
end

local function RefreshOpacity()
    local s = GetS()
    if BattlefieldMapOptions then
        BattlefieldMapOptions.opacity = 1 - (s.battleMapOpacity or 1)
    end
    if BattlefieldMapFrame and BattlefieldMapFrame.RefreshAlpha then
        BattlefieldMapFrame:RefreshAlpha()
    end
end

local function RefreshPinSizes()
    if not BattlefieldMapFrame or not BattlefieldMapFrame.groupMembersDataProvider then return end
    local s = GetS()
    local g = BattlefieldMapFrame.groupMembersDataProvider
    local pin = g.pin
    if pin and pin.SetAppearanceField then
        pin:SetAppearanceField("party", "sublevel", 0)
        pin:SetAppearanceField("raid", "sublevel", 0)
    end
    local gsz = s.battleGroupIconSize or 8
    local psz = s.battlePlayerArrowSize or 12
    g:SetUnitPinSize("party", gsz)
    g:SetUnitPinSize("raid", gsz)
    g:SetUnitPinSize("player", psz)
    if pin and pin.SynchronizePinSizes then
        pin:SynchronizePinSizes()
    end
end

local function CenterOnPlayer()
    if not BattlefieldMapFrame or not BattlefieldMapFrame:IsShown() then
        return
    end
    local sc = BattlefieldMapFrame.ScrollContainer
    if not sc or sc:IsPanning() then
        return
    end
    if IsShiftKeyDown() then
        centerTime = -2000
        return
    end
    local position = C_Map.GetPlayerMapPosition(BattlefieldMapFrame.mapID, "player")
    if not position or not position.x then
        return
    end
    local x, y = position.x, position.y
    local minX, maxX, minY, maxY = sc:CalculateScrollExtentsAtScale(sc:GetCanvasScale())
    local cx = math.max(math.min(x, maxX), minX)
    local cy = math.max(math.min(y, maxY), minY)
    sc:SetPanTarget(cx, cy)
    centerTime = 0
end

local function StopCenterTicker()
    if centerTicker then
        centerTicker:Cancel()
        centerTicker = nil
    end
    centerTime = -1
    lastCanvasScale = nil
    wasPanning = false
end

local function CenterTickerTick()
    if not GetToggle("enhanceBattleMap") or not GetToggle("battleCenterOnPlayer") then
        return
    end
    if not BattlefieldMapFrame or not BattlefieldMapFrame:IsShown() then
        return
    end
    local sc = BattlefieldMapFrame.ScrollContainer
    if not sc then
        return
    end

    local panning = sc:IsPanning()
    if wasPanning and not panning and GetToggle("battleCenterOnPlayer") then
        centerTime = IsShiftKeyDown() and -2000 or 1.7
    end
    wasPanning = panning

    local scale = sc:GetCanvasScale()
    if lastCanvasScale and scale ~= lastCanvasScale and GetToggle("battleCenterOnPlayer") then
        centerTime = IsShiftKeyDown() and -2000 or 1.7
    end
    lastCanvasScale = scale

    if centerTime > 2 or centerTime == -1 then
        CenterOnPlayer()
    elseif centerTime >= 0 then
        centerTime = centerTime + 0.1
    end
end

local function StartCentering()
    StopCenterTicker()
    if GetToggle("battleCenterOnPlayer") and GetToggle("enhanceBattleMap") then
        centerTicker = C_Timer.NewTicker(0.1, CenterTickerTick)
    end
end

local function OnBattleDragStop()
    if not BattlefieldMapFrame then
        return
    end
    BattlefieldMapFrame:StopMovingOrSizing()
    local s = GetS()
    s.battleMapA, _, s.battleMapR, s.battleMapX, s.battleMapY = BattlefieldMapFrame:GetPoint()
    BattlefieldMapFrame:SetMovable(true)
    BattlefieldMapFrame:ClearAllPoints()
    BattlefieldMapFrame:SetPoint(s.battleMapA, UIParent, s.battleMapR, s.battleMapX, s.battleMapY)
end

function M.ApplyBattlefieldFramePosition()
    if not BattlefieldMapFrame then
        return
    end
    local s = GetS()
    BattlefieldMapFrame:ClearAllPoints()
    BattlefieldMapFrame:SetPoint(s.battleMapA or "BOTTOMRIGHT", UIParent, s.battleMapR or "BOTTOMRIGHT", s.battleMapX or -47, s.battleMapY or 83)
end

local function SyncDragHitOverlay()
    if not dragHitFrame or not BattlefieldMapFrame or not BattlefieldMapFrame.ScrollContainer then
        return
    end
    if GetToggle("unlockBattlefield") and NeedsBattlefieldFeatures()
        and BattlefieldMapFrame:IsShown() then
        dragHitFrame:SetPoint("TOPLEFT", BattlefieldMapFrame.ScrollContainer, "TOPLEFT")
        dragHitFrame:SetPoint("BOTTOMRIGHT", BattlefieldMapFrame.ScrollContainer, "BOTTOMRIGHT")
        dragHitFrame:Show()
    else
        dragHitFrame:Hide()
    end
end

local function EnsureDragHitOverlay()
    if dragHitFrame then
        SyncDragHitOverlay()
        return
    end
    if not BattlefieldMapFrame or not BattlefieldMapFrame.ScrollContainer then
        return
    end
    --- Parent UIParent and anchor to the scroll area so map pins stay untainted.
    dragHitFrame = CreateFrame("Frame", "OneWoW_QoL_BattleMapDragHit", UIParent)
    dragHitFrame:SetFrameStrata("HIGH")
    dragHitFrame:SetHitRectInsets(-15, -15, -15, -15)
    dragHitFrame:SetAlpha(0)
    dragHitFrame:EnableMouse(true)
    dragHitFrame:RegisterForDrag("LeftButton")
    dragHitFrame:SetScript("OnMouseDown", function()
        if not GetToggle("unlockBattlefield") or OneWoW.Restriction.IsProtectedActionBlocked() then
            return
        end
        if BattlefieldMapFrame then
            BattlefieldMapFrame:StartMoving()
        end
    end)
    dragHitFrame:SetScript("OnMouseUp", OnBattleDragStop)
    SyncDragHitOverlay()
end

local function ApplyBattlefieldMovableState()
    if not BattlefieldMapFrame then
        return
    end
    if GetToggle("unlockBattlefield") and NeedsBattlefieldFeatures() then
        BattlefieldMapFrame:SetMovable(true)
        BattlefieldMapFrame:SetUserPlaced(true)
        BattlefieldMapFrame:SetDontSavePosition(true)
        BattlefieldMapFrame:SetClampedToScreen(true)
        M.ApplyBattlefieldFramePosition()
    end
end

local function DoBattleInstall()
    if not BattlefieldMapFrame or M._battleInstalled then
        return
    end
    M._battleInstalled = true

    if BattlefieldMapOptions then
        BattlefieldMapOptions.showPlayers = true
    end

    if BattlefieldMapTab and not M._battleTabHooked then
        M._battleTabHooked = true
        hooksecurefunc(BattlefieldMapTab, "Show", function()
            BattlefieldMapTab:Hide()
        end)
        BattlefieldMapTab:SetFrameStrata(BattlefieldMapFrame:GetFrameStrata())
    end

    if not M._battleShowHooked then
        M._battleShowHooked = true
        hooksecurefunc(BattlefieldMapFrame, "Show", function()
            if GetToggle("battleCenterOnPlayer") and GetToggle("enhanceBattleMap") then
                centerTime = -1
            end
            SyncDragHitOverlay()
        end)
    end

    if not M._battleHideHooked then
        M._battleHideHooked = true
        hooksecurefunc(BattlefieldMapFrame, "Hide", SyncDragHitOverlay)
    end

    EnsureBattleDriver()
    EnsureDragHitOverlay()
    ApplyBattlefieldMovableState()

    M._syncBattleDragHit = SyncDragHitOverlay

    M.RefreshBattlefieldEnhance = function()
        if not NeedsBattlefieldFeatures() then
            StopCenterTicker()
            if dragHitFrame then
                dragHitFrame:Hide()
            end
            return
        end
        if not GetToggle("enhanceBattleMap") then
            StopCenterTicker()
        else
            if BattlefieldMapOptions then
                BattlefieldMapOptions.showPlayers = true
            end
            RefreshOpacity()
            RefreshPinSizes()
            StartCentering()
        end
        ApplyBattlefieldMovableState()
        if M._syncBattleDragHit then
            M._syncBattleDragHit()
        end
    end
end

function M.TeardownBattlefieldEnhance()
    StopCenterTicker()
    if dragHitFrame then
        dragHitFrame:Hide()
    end
end

function M.InstallBattlefieldEnhance()
    if not NeedsBattlefieldFeatures() then
        return
    end

    OneWoW:EnsureLoaded("Blizzard_BattlefieldMap")

    if not BattlefieldMapFrame then
        if EventUtil and EventUtil.ContinueOnAddOnLoaded and not M._battleLoadPending then
            M._battleLoadPending = true
            EventUtil.ContinueOnAddOnLoaded("Blizzard_BattlefieldMap", function()
                M._battleLoadPending = nil
                M.InstallBattlefieldEnhance()
            end)
        end
        return
    end

    DoBattleInstall()
    M.RefreshBattlefieldEnhance()
end

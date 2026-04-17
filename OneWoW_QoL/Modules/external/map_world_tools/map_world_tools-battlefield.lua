local addonName, ns = ...
local M = ns.MapWorldToolsModule

local centerFrame
local centerTime = -1
local dragHitFrame

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("map_world_tools", id)
end

local function GetS()
    return M.GetSettings()
end

function M.RefreshBattlefieldEnhance() end

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

local function StopCentering()
    if centerFrame then
        centerFrame:SetScript("OnUpdate", nil)
    end
    centerTime = -1
end

local function CenterUpdate(_, elapsed)
    if not GetToggle("enhanceBattleMap") or not GetToggle("battleCenterOnPlayer") then return end
    if not BattlefieldMapFrame or not BattlefieldMapFrame:IsShown() then return end
    if centerTime > 2 or centerTime == -1 then
        if BattlefieldMapFrame.ScrollContainer:IsPanning() then return end
        if IsShiftKeyDown() then centerTime = -2000 return end
        local position = C_Map.GetPlayerMapPosition(BattlefieldMapFrame.mapID, "player")
        if position then
            local x, y = position.x, position.y
            if x then
                local sc = BattlefieldMapFrame.ScrollContainer
                local minX, maxX, minY, maxY = sc:CalculateScrollExtentsAtScale(sc:GetCanvasScale())
                local cx = math.max(math.min(x, maxX), minX)
                local cy = math.max(math.min(y, maxY), minY)
                sc:SetPanTarget(cx, cy)
            end
            centerTime = 0
        end
    end
    centerTime = centerTime + elapsed
end

local function StartCentering()
    if not centerFrame then return end
    centerTime = -1
    if GetToggle("battleCenterOnPlayer") and GetToggle("enhanceBattleMap") then
        centerFrame:SetScript("OnUpdate", CenterUpdate)
    else
        StopCentering()
    end
end

local function OnBattleDragStop()
    if not BattlefieldMapFrame then return end
    BattlefieldMapFrame:StopMovingOrSizing()
    local s = GetS()
    s.battleMapA, _, s.battleMapR, s.battleMapX, s.battleMapY = BattlefieldMapFrame:GetPoint()
    BattlefieldMapFrame:SetMovable(true)
    BattlefieldMapFrame:ClearAllPoints()
    BattlefieldMapFrame:SetPoint(s.battleMapA, UIParent, s.battleMapR, s.battleMapX, s.battleMapY)
end

function M.ApplyBattlefieldFramePosition()
    if not BattlefieldMapFrame then return end
    local s = GetS()
    BattlefieldMapFrame:ClearAllPoints()
    BattlefieldMapFrame:SetPoint(s.battleMapA or "BOTTOMRIGHT", UIParent, s.battleMapR or "BOTTOMRIGHT", s.battleMapX or -47, s.battleMapY or 83)
end

local function DoBattleInstall()
    if not BattlefieldMapFrame then return end

    BattlefieldMapOptions.showPlayers = true

    if BattlefieldMapTab then
        hooksecurefunc(BattlefieldMapTab, "Show", function()
            BattlefieldMapTab:Hide()
        end)
        BattlefieldMapTab:SetFrameStrata(BattlefieldMapFrame:GetFrameStrata())
    end

    BattlefieldMapFrame:SetMovable(true)
    BattlefieldMapFrame:SetUserPlaced(true)
    BattlefieldMapFrame:SetDontSavePosition(true)
    BattlefieldMapFrame:SetClampedToScreen(true)
    M.ApplyBattlefieldFramePosition()

    dragHitFrame = CreateFrame("Frame", nil, BattlefieldMapFrame.ScrollContainer)
    dragHitFrame:SetPoint("TOPLEFT", 0, 0)
    dragHitFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    dragHitFrame:SetFrameLevel(BattlefieldMapFrame:GetFrameLevel() - 1)
    dragHitFrame:SetHitRectInsets(-15, -15, -15, -15)
    dragHitFrame:SetAlpha(0)
    dragHitFrame:EnableMouse(true)
    dragHitFrame:RegisterForDrag("LeftButton")
    dragHitFrame:SetScript("OnMouseDown", function()
        if GetToggle("unlockBattlefield") then
            BattlefieldMapFrame:StartMoving()
        end
    end)
    dragHitFrame:SetScript("OnMouseUp", OnBattleDragStop)

    centerFrame = CreateFrame("FRAME", nil, BattlefieldMapFrame)
    BattlefieldMapFrame.ScrollContainer:HookScript("OnMouseUp", function()
        if GetToggle("battleCenterOnPlayer") then
            if IsShiftKeyDown() then centerTime = -2000 else centerTime = 1.7 end
        end
    end)
    BattlefieldMapFrame:HookScript("OnShow", function()
        if GetToggle("battleCenterOnPlayer") then centerTime = -1 end
    end)
    BattlefieldMapFrame.ScrollContainer:HookScript("OnMouseWheel", function()
        if GetToggle("battleCenterOnPlayer") then
            if IsShiftKeyDown() then centerTime = -2000 else centerTime = 1.7 end
        end
    end)

    local function SyncDragHit()
        if dragHitFrame then
            if GetToggle("unlockBattlefield") then dragHitFrame:Show() else dragHitFrame:Hide() end
        end
    end
    SyncDragHit()
    M._syncBattleDragHit = SyncDragHit

    M.RefreshBattlefieldEnhance = function()
        if not GetToggle("enhanceBattleMap") or not ns.ModuleRegistry:IsEnabled("map_world_tools") then return end
        if BattlefieldMapOptions then BattlefieldMapOptions.showPlayers = true end
        RefreshOpacity()
        RefreshPinSizes()
        StartCentering()
        if M._syncBattleDragHit then M._syncBattleDragHit() end
        M.ApplyBattlefieldFramePosition()
    end
end

function M.InstallBattlefieldEnhance()
    if M._battleInstalled then return end

    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_BattlefieldMap")
    elseif UIParentLoadAddOn then
        UIParentLoadAddOn("Blizzard_BattlefieldMap")
    end

    if not BattlefieldMapFrame then
        if EventUtil and EventUtil.ContinueOnAddOnLoaded then
            EventUtil.ContinueOnAddOnLoaded("Blizzard_BattlefieldMap", function()
                if not M._battleInstalled then
                    M.InstallBattlefieldEnhance()
                end
            end)
        end
        return
    end

    M._battleInstalled = true
    DoBattleInstall()
end

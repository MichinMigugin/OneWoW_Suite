local addonName, ns = ...
local M = ns.MapWorldToolsModule

local canvasOverlay
local hooksInstalled
local coordsParent
local coordsUpdateFrame
local poiHooked
local comfortHooks

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("map_world_tools", id)
end

local function GetSettings()
    local addon = _G.OneWoW_QoL
    local mods = addon.db.global.modules
    if not mods.map_world_tools then mods.map_world_tools = {} end
    local s = mods.map_world_tools

    if s.fogTintR == nil then s.fogTintR = 255 end
    if s.fogTintG == nil then s.fogTintG = 255 end
    if s.fogTintB == nil then s.fogTintB = 255 end

    if s.unexploredTintR == nil then s.unexploredTintR = s.fogTintR end
    if s.unexploredTintG == nil then s.unexploredTintG = s.fogTintG end
    if s.unexploredTintB == nil then s.unexploredTintB = s.fogTintB end
    if s.unexploredTintA == nil then s.unexploredTintA = 1 end

    if s.canvasR == nil then s.canvasR = 0 end
    if s.canvasG == nil then s.canvasG = 0 end
    if s.canvasB == nil then s.canvasB = 0 end
    if s.canvasA == nil then s.canvasA = 0.15 end
    if s.mapFrameAlpha == nil then s.mapFrameAlpha = 1 end

    if s.battleMapOpacity == nil then s.battleMapOpacity = 1 end
    if s.battleGroupIconSize == nil then s.battleGroupIconSize = 8 end
    if s.battlePlayerArrowSize == nil then s.battlePlayerArrowSize = 12 end
    if s.battleMapA == nil then s.battleMapA = "BOTTOMRIGHT" end
    if s.battleMapR == nil then s.battleMapR = "BOTTOMRIGHT" end
    if s.battleMapX == nil then s.battleMapX = -47 end
    if s.battleMapY == nil then s.battleMapY = 83 end

    return s
end

M.GetSettings = GetSettings

local function SafeRefreshWorldMap()
    local f = WorldMapFrame
    if not f or not f.mapID then return end
    local sc = f.ScrollContainer
    if not sc or not sc.zoomLevels then return end
    if f.RefreshAll then
        f:RefreshAll()
    elseif f.RefreshAllDataProviders then
        f:RefreshAllDataProviders()
    end
end

M.SafeRefreshWorldMap = SafeRefreshWorldMap

local function ForEachTextureInFrame(frame, fn)
    if not frame then return end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            fn(region)
        end
    end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        ForEachTextureInFrame(child, fn)
    end
end

local function ApplyFogPin(pin)
    if not pin then return end
    local removeFog = GetToggle("removeBattleFog")
    local tintOn = GetToggle("fogTint")
    local s = GetSettings()

    --- Fog uses FogOfWarFrame (native); there are often no Lua Texture children to recurse.
    if removeFog then
        pin:SetAlpha(0)
        return
    end

    pin:SetAlpha(1)

    local r, g, b = 1, 1, 1
    if tintOn then
        r = s.fogTintR / 255
        g = s.fogTintG / 255
        b = s.fogTintB / 255
    end

    if pin.SetVertexColor then
        pcall(function()
            pin:SetVertexColor(r, g, b)
        end)
    end

    ForEachTextureInFrame(pin, function(tex)
        tex:SetVertexColor(r, g, b)
    end)
end

local function InstallFogHooks()
    if hooksInstalled then return end
    if not FogOfWarDataProviderMixin then return end

    hooksecurefunc(FogOfWarDataProviderMixin, "RefreshAllData", function(self)
        if not self.pin then return end
        if not ns.ModuleRegistry:IsEnabled("map_world_tools") then
            local p = self.pin
            p:SetAlpha(1)
            if p.SetVertexColor then pcall(p.SetVertexColor, p, 1, 1, 1) end
            ForEachTextureInFrame(p, function(tex)
                tex:SetVertexColor(1, 1, 1)
            end)
            return
        end
        ApplyFogPin(self.pin)
    end)

    if FogOfWarPinMixin and FogOfWarPinMixin.OnMapChanged then
        hooksecurefunc(FogOfWarPinMixin, "OnMapChanged", function(self)
            if not self then return end
            if not ns.ModuleRegistry:IsEnabled("map_world_tools") then
                self:SetAlpha(1)
                if self.SetVertexColor then pcall(self.SetVertexColor, self, 1, 1, 1) end
                ForEachTextureInFrame(self, function(tex)
                    tex:SetVertexColor(1, 1, 1)
                end)
                return
            end
            ApplyFogPin(self)
        end)
    end

    hooksInstalled = true
end

local function AfterFogMixinReady()
    InstallFogHooks()
    SafeRefreshWorldMap()
end

local function EnsureCanvasOverlay()
    if canvasOverlay or not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    local sc = WorldMapFrame.ScrollContainer
    canvasOverlay = CreateFrame("Frame", "OneWoW_QoL_MapWorldCanvasTint", sc)
    canvasOverlay:SetAllPoints()
    canvasOverlay:SetFrameStrata("HIGH")
    canvasOverlay:SetFrameLevel(8000)
    canvasOverlay:EnableMouse(false)
    local tex = canvasOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetAllPoints()
    canvasOverlay.tintTex = tex
end

function M.RefreshFogAppearance()
    SafeRefreshWorldMap()
    if M.RefreshExploreAppearance then
        M.RefreshExploreAppearance()
    end
end

function M.RefreshMapFrameAlpha()
    local f = WorldMapFrame
    if not f then return end
    if not ns.ModuleRegistry:IsEnabled("map_world_tools") then
        f:SetAlpha(1)
        return
    end
    local s = GetSettings()
    if GetToggle("useMapFrameAlpha") then
        local a = s.mapFrameAlpha
        if a == nil then a = 1 end
        if a < 0.1 then a = 0.1 end
        if a > 1 then a = 1 end
        f:SetAlpha(a)
    else
        f:SetAlpha(1)
    end
end

function M.RefreshCanvasOverlay()
    if not ns.ModuleRegistry:IsEnabled("map_world_tools") then return end
    EnsureCanvasOverlay()
    if not canvasOverlay or not canvasOverlay.tintTex then return end

    local s = GetSettings()
    if GetToggle("canvasTint") then
        canvasOverlay:Show()
        canvasOverlay.tintTex:SetColorTexture(
            s.canvasR / 255,
            s.canvasG / 255,
            s.canvasB / 255,
            s.canvasA
        )
    else
        canvasOverlay:Hide()
    end
end

local function ApplyBlackoutMode()
    if not WorldMapFrame or not WorldMapFrame.BlackoutFrame then return end
    local bf = WorldMapFrame.BlackoutFrame
    if GetToggle("clearBlackout") and ns.ModuleRegistry:IsEnabled("map_world_tools") then
        bf:SetAlpha(0)
        bf:EnableMouse(false)
    else
        bf:SetAlpha(1)
        bf:EnableMouse(true)
    end
end

local function ApplyMapFadeCVar()
    if M._savedMapFade == nil then
        M._savedMapFade = GetCVar("mapFade")
    end
    if not ns.ModuleRegistry:IsEnabled("map_world_tools") then return end
    if GetToggle("noMapFade") then
        SetCVar("mapFade", "0")
    else
        SetCVar("mapFade", M._savedMapFade or "1")
    end
end

local function InstallComfortHooks()
    if comfortHooks then return end
    comfortHooks = true
    hooksecurefunc(C_ChatInfo, "PerformEmote", function(emote)
        if emote == "READ" and WorldMapFrame and WorldMapFrame:IsShown() then
            if GetToggle("noMapEmote") and ns.ModuleRegistry:IsEnabled("map_world_tools") then
                C_ChatInfo.CancelEmote()
            end
        end
    end)
end

local function ApplyMapCleanup()
    if not WorldMapFrame or M._mapCleanupRan then return end
    M._mapCleanupRan = true
    if GetToggle("hideMapTutorial") and WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.Tutorial then
        WorldMapFrame.BorderFrame.Tutorial:HookScript("OnShow", WorldMapFrame.BorderFrame.Tutorial.Hide)
        SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_WORLD_MAP_FRAME, true)
    end
    if GetToggle("hideFilterReset") then
        local hidden = CreateFrame("FRAME")
        hidden:Hide()
        for _, v in pairs({ WorldMapFrame:GetChildren() }) do
            if v.ResetButton then
                v.ResetButton:SetParent(hidden)
            end
            if v.FilterCounter then
                v.FilterCounter:HookScript("OnShow", function() v.FilterCounter:Hide() end)
                if v.FilterCounterBanner then
                    v.FilterCounterBanner:HookScript("OnShow", function() v.FilterCounterBanner:Hide() end)
                end
            end
        end
    end
end

local function InstallPoiHook()
    if poiHooked then return end
    poiHooked = true
    if not BaseMapPoiPinMixin or not BaseMapPoiPinMixin.OnAcquired then return end
    hooksecurefunc(BaseMapPoiPinMixin, "OnAcquired", function(self)
        if not GetToggle("hideContinentPoi") or not ns.ModuleRegistry:IsEnabled("map_world_tools") then return end
        local wmapID = WorldMapFrame and WorldMapFrame.mapID
        if not wmapID then return end
        local minfo = C_Map.GetMapInfo(wmapID)
        local mType = minfo and minfo.mapType
        if not mType or (mType ~= 1 and mType ~= 2) then return end
        if self.Texture and self.Texture:GetTexture() == 136441 then
            local a, b, c, d, e, f, g, h = self.Texture:GetTexCoord()
            if a == 0.35546875 and b == 0.001953125 and c == 0.35546875 and d == 0.03515625 and e == 0.421875 and f == 0.001953125 and g == 0.421875 and h == 0.03515625 then
                self:Hide()
            elseif a == 0.28515625 and b == 0.107421875 and c == 0.28515625 and d == 0.140625 and e == 0.3515625 and f == 0.107421875 and g == 0.3515625 and h == 0.140625 then
                self:Hide()
            elseif a == 0.42578125 and b == 0.107421875 and c == 0.42578125 and d == 0.140625 and e == 0.4921875 and f == 0.107421875 and g == 0.4921875 and h == 0.140625 then
                self:Hide()
            end
        end
    end)
end

local function ApplyCoordFontStrings(cCursor, cPlayer)
    local s = GetSettings()
    local sz = GetToggle("coordsLargeFont") and 16 or 12
    local font, _, f = cCursor.x:GetFont()
    cCursor.x:SetFont(font, sz, f)
    cPlayer.x:SetFont(font, sz, f)
    if GetToggle("coordsBackground") then
        cCursor:GetParent().t:Show()
    else
        cCursor:GetParent().t:Hide()
    end
end

local function EnsureCoordOverlay()
    if coordsParent or not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    local sc = WorldMapFrame.ScrollContainer
    local cFrame = CreateFrame("FRAME", "OneWoW_QoL_MapCoordsBar", sc)
    cFrame:SetSize(WorldMapFrame:GetWidth() or 1000, 17)
    cFrame:SetPoint("BOTTOMLEFT", 17, 0)
    cFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    cFrame.t = cFrame:CreateTexture(nil, "BACKGROUND")
    cFrame.t:SetAllPoints()
    cFrame.t:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    cFrame.t:SetVertexColor(0, 0, 0, 0.5)

    local cCursor = CreateFrame("Frame", nil, sc)
    cCursor:SetSize(200, 16)
    cCursor:SetParent(cFrame)
    cCursor:SetPoint("BOTTOMLEFT", 152, 1)
    cCursor.x = cCursor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cCursor.x:SetJustifyH("LEFT")
    cCursor.x:SetAllPoints()

    local cPlayer = CreateFrame("Frame", nil, sc)
    cPlayer:SetSize(200, 16)
    cPlayer:SetParent(cFrame)
    cPlayer:SetPoint("BOTTOMRIGHT", -132, 1)
    cPlayer.x = cPlayer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cPlayer.x:SetJustifyH("LEFT")
    cPlayer.x:SetAllPoints()

    coordsUpdateFrame = cPlayer
    local cPlayerTime = -1
    cPlayer:SetScript("OnUpdate", function(_, elapsed)
        if not GetToggle("showCoords") or not ns.ModuleRegistry:IsEnabled("map_world_tools") then return end
        if cPlayerTime > 0.1 or cPlayerTime == -1 then
            local x, y = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
            if x and y and x > 0 and y > 0 and MouseIsOver(WorldMapFrame.ScrollContainer) then
                cCursor.x:SetFormattedText("%s: %.1f, %.1f", ns.L and ns.L["MAPWORLD_CURSOR"] or "Cursor",
                    (math.floor(x * 1000 + 0.5)) / 10, (math.floor(y * 1000 + 0.5)) / 10)
            else
                cCursor.x:SetFormattedText("%s:", ns.L and ns.L["MAPWORLD_CURSOR"] or "Cursor")
            end
        end
        if cPlayerTime > 0.2 or cPlayerTime == -1 then
            local mapID = C_Map.GetBestMapForUnit("player")
            if not mapID then
                cPlayer.x:SetFormattedText("%s:", ns.L and ns.L["MAPWORLD_PLAYER"] or "Player")
            else
                local position = C_Map.GetPlayerMapPosition(mapID, "player")
                if position and position.x ~= 0 and position.y ~= 0 then
                    cPlayer.x:SetFormattedText("%s: %.1f, %.1f", ns.L and ns.L["MAPWORLD_PLAYER"] or "Player",
                        position.x * 100, position.y * 100)
                else
                    cPlayer.x:SetFormattedText("%s: %.1f, %.1f", ns.L and ns.L["MAPWORLD_PLAYER"] or "Player", 0, 0)
                end
            end
            cPlayerTime = 0
        end
        cPlayerTime = cPlayerTime + elapsed
    end)

    coordsParent = cFrame
    cFrame._cCursor = cCursor
    cFrame._cPlayer = cPlayer
    ApplyCoordFontStrings(cCursor, cPlayer)
end

function M.RefreshCoordsVisibility()
    EnsureCoordOverlay()
    if not coordsParent then return end
    if GetToggle("showCoords") and ns.ModuleRegistry:IsEnabled("map_world_tools") then
        coordsParent:Show()
    else
        coordsParent:Hide()
    end
    if coordsParent._cCursor and coordsParent._cPlayer then
        ApplyCoordFontStrings(coordsParent._cCursor, coordsParent._cPlayer)
    end
end

local function OnWorldMapAddonLoaded()
    InstallFogHooks()
    InstallComfortHooks()
    InstallPoiHook()
    if M.InstallExploreReveal then
        M.InstallExploreReveal()
    end
    if M.InstallBattlefieldEnhance then
        M.InstallBattlefieldEnhance()
    end

    SafeRefreshWorldMap()
    ApplyBlackoutMode()
    ApplyMapFadeCVar()
    ApplyMapCleanup()

    EnsureCoordOverlay()
    M.RefreshCoordsVisibility()

    if not M._mapWorldOnShowHooked and WorldMapFrame and WorldMapFrame.HookScript then
        M._mapWorldOnShowHooked = true
        WorldMapFrame:HookScript("OnShow", function()
            M.RefreshCanvasOverlay()
            M.RefreshMapFrameAlpha()
            ApplyBlackoutMode()
            M.RefreshCoordsVisibility()
        end)
    end

    M.RefreshCanvasOverlay()
    M.RefreshMapFrameAlpha()

    if M.RefreshBattlefieldEnhance then
        M.RefreshBattlefieldEnhance()
    end

    if Menu and Menu.ModifyMenu and GetToggle("tintMenuShortcut") then
        pcall(function()
            Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(_, rootDescription)
                rootDescription:CreateDivider()
                rootDescription:CreateTitle(ns.L and ns.L["MAPWORLD_TITLE"] or "Map Tools")
                local btn = MenuUtil.CreateCheckbox(
                    ns.L and ns.L["MAPWORLD_TINT_UNEXPLORED"] or "Tint unexplored",
                    function() return GetToggle("tintUnexplored") end,
                    function()
                        local on = GetToggle("tintUnexplored")
                        ns.ModuleRegistry:SetToggleValue("map_world_tools", "tintUnexplored", not on)
                        if M.RefreshExploreTint then M.RefreshExploreTint() end
                        M.RefreshFogAppearance()
                    end
                )
                rootDescription:Insert(btn)
            end)
        end)
    end
end

local function RegisterWorldMapLoader()
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", OnWorldMapAddonLoaded)
        EventUtil.ContinueOnAddOnLoaded("Blizzard_SharedMapDataProviders", AfterFogMixinReady)
    else
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(_, _, name)
            if name == "Blizzard_WorldMap" then
                OnWorldMapAddonLoaded()
            elseif name == "Blizzard_SharedMapDataProviders" then
                AfterFogMixinReady()
            end
        end)
    end
end

function M:OnEnable()
    RegisterWorldMapLoader()
    if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_WorldMap") then
        OnWorldMapAddonLoaded()
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_SharedMapDataProviders") then
        AfterFogMixinReady()
    end
    ApplyMapFadeCVar()
end

function M:OnDisable()
    if canvasOverlay then canvasOverlay:Hide() end
    if WorldMapFrame then
        WorldMapFrame:SetAlpha(1)
        if WorldMapFrame.BlackoutFrame then
            WorldMapFrame.BlackoutFrame:SetAlpha(1)
            WorldMapFrame.BlackoutFrame:EnableMouse(true)
        end
    end
    if M._savedMapFade ~= nil then
        SetCVar("mapFade", M._savedMapFade)
    end
    if coordsParent then coordsParent:Hide() end
    SafeRefreshWorldMap()
end

function M:OnToggle(toggleId, value)
    if toggleId == "removeBattleFog" or toggleId == "fogTint" or toggleId == "revealMap"
        or toggleId == "tintUnexplored" then
        M.RefreshFogAppearance()
        if M.RefreshExploreTint then M.RefreshExploreTint() end
    elseif toggleId == "canvasTint" then
        M.RefreshCanvasOverlay()
    elseif toggleId == "useMapFrameAlpha" then
        M.RefreshMapFrameAlpha()
    elseif toggleId == "clearBlackout" then
        ApplyBlackoutMode()
    elseif toggleId == "noMapFade" then
        ApplyMapFadeCVar()
    elseif toggleId == "showCoords" or toggleId == "coordsLargeFont" or toggleId == "coordsBackground" then
        M.RefreshCoordsVisibility()
    elseif toggleId == "enhanceBattleMap" or toggleId == "unlockBattlefield"
        or toggleId == "battleCenterOnPlayer" then
        if M.RefreshBattlefieldEnhance then M.RefreshBattlefieldEnhance() end
    elseif toggleId == "hideContinentPoi" then
        SafeRefreshWorldMap()
    end
    if self._refreshCustomDetail then self._refreshCustomDetail() end
end

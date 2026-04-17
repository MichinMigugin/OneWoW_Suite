local addonName, ns = ...
local M = ns.MapWorldToolsModule

local canvasOverlay
local hooksInstalled

local function GetSettings()
    local addon = _G.OneWoW_QoL
    local mods = addon.db.global.modules
    if not mods.map_world_tools then mods.map_world_tools = {} end
    local s = mods.map_world_tools
    if s.fogTintR == nil then s.fogTintR = 255 end
    if s.fogTintG == nil then s.fogTintG = 255 end
    if s.fogTintB == nil then s.fogTintB = 255 end
    if s.canvasR == nil then s.canvasR = 0 end
    if s.canvasG == nil then s.canvasG = 0 end
    if s.canvasB == nil then s.canvasB = 0 end
    if s.canvasA == nil then s.canvasA = 0.15 end
    if s.mapFrameAlpha == nil then s.mapFrameAlpha = 1 end
    return s
end

M.GetSettings = GetSettings

local function SafeRefreshWorldMap()
    local f = WorldMapFrame
    if not f then return end
    if f.RefreshAll then
        f:RefreshAll()
    elseif f.RefreshAllDataProviders then
        f:RefreshAllDataProviders()
    end
end

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("map_world_tools", id)
end

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
            self.pin:SetAlpha(1)
            ForEachTextureInFrame(self.pin, function(tex)
                tex:SetVertexColor(1, 1, 1)
            end)
            return
        end
        ApplyFogPin(self.pin)
    end)

    hooksInstalled = true
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

local function OnWorldMapAddOnLoaded()
    InstallFogHooks()
    SafeRefreshWorldMap()
    if not M._mapWorldOnShowHooked and WorldMapFrame and WorldMapFrame.HookScript then
        M._mapWorldOnShowHooked = true
        WorldMapFrame:HookScript("OnShow", function()
            M.RefreshCanvasOverlay()
            M.RefreshMapFrameAlpha()
        end)
    end
    M.RefreshCanvasOverlay()
    M.RefreshMapFrameAlpha()
end

local function RegisterWorldMapLoader()
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", OnWorldMapAddOnLoaded)
    else
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(_, _, name)
            if name == "Blizzard_WorldMap" then
                OnWorldMapAddOnLoaded()
                f:UnregisterAllEvents()
            end
        end)
    end
end

function M:OnEnable()
    RegisterWorldMapLoader()
    if C_AddOns.IsAddOnLoaded("Blizzard_WorldMap") then
        OnWorldMapAddOnLoaded()
    end
end

function M:OnDisable()
    if canvasOverlay then
        canvasOverlay:Hide()
    end
    if WorldMapFrame then
        WorldMapFrame:SetAlpha(1)
    end
    SafeRefreshWorldMap()
end

function M:OnToggle(toggleId, value)
    if toggleId == "removeBattleFog" or toggleId == "fogTint" then
        SafeRefreshWorldMap()
    elseif toggleId == "canvasTint" then
        M.RefreshCanvasOverlay()
    elseif toggleId == "useMapFrameAlpha" then
        M.RefreshMapFrameAlpha()
    end
    if self._refreshCustomDetail then self._refreshCustomDetail() end
end

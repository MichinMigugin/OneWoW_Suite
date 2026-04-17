local addonName, ns = ...
local M = ns.MapWorldToolsModule

--- Map exploration overlays: show undiscovered art from ns.MapWorldRevealData and optional tint.
--- Logic follows Blizzard MapExploration chunk layout; implementation is OneWoW-original.

local worldOverlayTex = {}
local bfOverlayTex = {}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("map_world_tools", id)
end

local function GetSettings()
    return M.GetSettings()
end

local function TexturePool_ResetVertexColor(pool, texture)
    texture:SetVertexColor(1, 1, 1, 1)
    return TexturePool_HideAndClearAnchors(pool, texture)
end

--- Faction-specific garrison tile patches (fileDataIDs to strip from comma list).
local function PatchRevealForFaction()
    local d = ns.MapWorldRevealData
    if type(d) ~= "table" then return end
    local fac = UnitFactionGroup("player")
    if fac == "Alliance" and d[556] and d[556]["223:279:194:0"] then
        d[556]["223:279:194:0"] = (d[556]["223:279:194:0"]):gsub("1037663", "")
    elseif fac == "Horde" and d[542] and d[542]["267:257:336:327"] then
        d[542]["267:257:336:327"] = (d[542]["267:257:336:327"]):gsub("1003342", "")
    end
end

local function UnexploredTintRGBA()
    local s = GetSettings()
    local r = (s.unexploredTintR or s.fogTintR or 255) / 255
    local g = (s.unexploredTintG or s.fogTintG or 255) / 255
    local b = (s.unexploredTintB or s.fogTintB or 255) / 255
    local a = s.unexploredTintA
    if a == nil then a = 1 end
    return r, g, b, a
end

function M.RefreshExploreTint()
    if not GetToggle("tintUnexplored") then return end
    local r, g, b, a = UnexploredTintRGBA()
    for i = 1, #worldOverlayTex do
        worldOverlayTex[i]:SetVertexColor(r, g, b, a)
    end
    for i = 1, #bfOverlayTex do
        bfOverlayTex[i]:SetVertexColor(r, g, b, a)
    end
end

local function Trim(s)
    if not s then return "" end
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function AppendMissingExplorationOverlays(pin, mapID, artTable, outList, fullUpdate)
    if not artTable then return end

    local TileExists = {}
    local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID)
    if explored then
        for _, info in ipairs(explored) do
            local key = info.textureWidth .. ":" .. info.textureHeight .. ":" .. info.offsetX .. ":" .. info.offsetY
            TileExists[key] = true
        end
    end

    pin.layerIndex = pin:GetMap():GetCanvasContainer():GetCurrentLayerIndex()
    local layers = C_Map.GetMapArtLayers(mapID)
    local layerInfo = layers and layers[pin.layerIndex]
    if not layerInfo then return end
    local TILE_SIZE_WIDTH = layerInfo.tileWidth
    local TILE_SIZE_HEIGHT = layerInfo.tileHeight

    local mapType = 0
    local mi = C_Map.GetMapInfo(mapID)
    if mi and mi.mapType then mapType = mi.mapType end

    local tintOn = GetToggle("tintUnexplored")
    local tr, tg, tb, ta = UnexploredTintRGBA()
    local zoneMap = (Enum.UIMapType and Enum.UIMapType.Zone and mapType == Enum.UIMapType.Zone) or mapType == 3

    for rectKey, filesStr in pairs(artTable) do
        if not TileExists[rectKey] then
            local sw, sh, offsetX, offsetY = strsplit(":", rectKey)
            local width = tonumber(sw)
            local height = tonumber(sh)
            offsetX = tonumber(offsetX) or 0
            offsetY = tonumber(offsetY) or 0
            if width and height then

            local fileDataIDs = { strsplit(",", filesStr) }
            for i = 1, #fileDataIDs do
                fileDataIDs[i] = Trim(fileDataIDs[i])
            end

            local numTexturesWide = math.ceil(width / TILE_SIZE_WIDTH)
            local numTexturesTall = math.ceil(height / TILE_SIZE_HEIGHT)
            local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight

            for j = 1, numTexturesTall do
                if j < numTexturesTall then
                    texturePixelHeight = TILE_SIZE_HEIGHT
                    textureFileHeight = TILE_SIZE_HEIGHT
                else
                    texturePixelHeight = math.fmod(height, TILE_SIZE_HEIGHT)
                    if texturePixelHeight == 0 then
                        texturePixelHeight = TILE_SIZE_HEIGHT
                    end
                    textureFileHeight = 16
                    while textureFileHeight < texturePixelHeight do
                        textureFileHeight = textureFileHeight * 2
                    end
                end
                for k = 1, numTexturesWide do
                    local texture = pin.overlayTexturePool:Acquire()
                    tinsert(outList, texture)

                    if k < numTexturesWide then
                        texturePixelWidth = TILE_SIZE_WIDTH
                        textureFileWidth = TILE_SIZE_WIDTH
                    else
                        texturePixelWidth = math.fmod(width, TILE_SIZE_WIDTH)
                        if texturePixelWidth == 0 then
                            texturePixelWidth = TILE_SIZE_WIDTH
                        end
                        textureFileWidth = 16
                        while textureFileWidth < texturePixelWidth do
                            textureFileWidth = textureFileWidth * 2
                        end
                    end

                    texture:SetSize(texturePixelWidth, texturePixelHeight)
                    texture:SetTexCoord(0, texturePixelWidth / textureFileWidth, 0, texturePixelHeight / textureFileHeight)
                    texture:SetPoint("TOPLEFT", offsetX + (TILE_SIZE_WIDTH * (k - 1)), -(offsetY + (TILE_SIZE_HEIGHT * (j - 1))))
                    local idNum = tonumber(fileDataIDs[((j - 1) * numTexturesWide) + k])
                    if idNum then
                        texture:SetTexture(idNum, nil, nil, "TRILINEAR")
                    end
                    texture:SetDrawLayer("ARTWORK", -1)
                    texture:Show()
                    if fullUpdate and pin.textureLoadGroup and pin.textureLoadGroup.AddTexture then
                        pin.textureLoadGroup:AddTexture(texture)
                    end
                    if tintOn and zoneMap then
                        texture:SetVertexColor(tr, tg, tb, ta)
                    else
                        texture:SetVertexColor(1, 1, 1, 1)
                    end
                end
            end
            end
        end
    end
end

local function ClearOverlayList(list)
    for _, tex in ipairs(list) do
        if tex and tex.SetVertexColor then
            tex:SetVertexColor(1, 1, 1, 1)
        end
    end
    wipe(list)
end

local function WorldExplorationPostRefresh(pin, fullUpdate)
    if not ns.ModuleRegistry:IsEnabled("map_world_tools") then return end
    if not GetToggle("revealMap") then
        ClearOverlayList(worldOverlayTex)
        return
    end

    ClearOverlayList(worldOverlayTex)

    local mapID = WorldMapFrame and WorldMapFrame.mapID
    if not mapID then return end
    local artID = C_Map.GetMapArtID(mapID)
    if not artID then return end
    local db = ns.MapWorldRevealData
    local zone = db and db[artID]
    if not zone then return end

    AppendMissingExplorationOverlays(pin, mapID, zone, worldOverlayTex, fullUpdate)
end

local function BattlefieldExplorationPostRefresh(pin, fullUpdate)
    if not ns.ModuleRegistry:IsEnabled("map_world_tools") then return end
    if not GetToggle("revealMap") then
        ClearOverlayList(bfOverlayTex)
        return
    end

    ClearOverlayList(bfOverlayTex)

    local mapID = BattlefieldMapFrame and BattlefieldMapFrame.mapID
    if not mapID then return end
    local artID = C_Map.GetMapArtID(mapID)
    if not artID then return end
    local db = ns.MapWorldRevealData
    local zone = db and db[artID]
    if not zone then return end

    AppendMissingExplorationOverlays(pin, mapID, zone, bfOverlayTex, fullUpdate)
end

--- Hook each MapExploration *pin instance* (Leatrix_Maps pattern). Securing the mixin table often does
--- nothing on retail because pins may not invoke MapExplorationPinMixin.RefreshOverlays through that table.

local function HookOneExplorationPin(pin)
    if not pin or not pin.RefreshOverlays or pin._onewowExplorationHooked then return end
    pin._onewowExplorationHooked = true
    if pin.overlayTexturePool then
        pin.overlayTexturePool.resetterFunc = TexturePool_ResetVertexColor
    end
    hooksecurefunc(pin, "RefreshOverlays", function(self, fullUpdate)
        if not self or not self.GetMap then return end
        local map = self:GetMap()
        if map == WorldMapFrame then
            WorldExplorationPostRefresh(self, fullUpdate)
        elseif BattlefieldMapFrame and map == BattlefieldMapFrame then
            BattlefieldExplorationPostRefresh(self, fullUpdate)
        end
    end)
end

local function HookExplorationPinsOnCanvas(frame)
    if not frame or not frame.EnumeratePinsByTemplate then return end
    for pin in frame:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
        HookOneExplorationPin(pin)
    end
end

local function HookAllExplorationPinInstances()
    HookExplorationPinsOnCanvas(WorldMapFrame)
    HookExplorationPinsOnCanvas(BattlefieldMapFrame)
end

local exploreHooksInstalled = false
local wmExploreOnShowHooked = false
local bfExploreOnShowHooked = false

local function RegisterBfExplorationOnShow()
    if bfExploreOnShowHooked or not BattlefieldMapFrame or not BattlefieldMapFrame.HookScript then return end
    bfExploreOnShowHooked = true
    BattlefieldMapFrame:HookScript("OnShow", function()
        HookExplorationPinsOnCanvas(BattlefieldMapFrame)
    end)
end

local function InstallExplorationHooks()
    if exploreHooksInstalled then
        HookAllExplorationPinInstances()
        return
    end
    exploreHooksInstalled = true

    HookAllExplorationPinInstances()

    if WorldMapFrame and WorldMapFrame.HookScript and not wmExploreOnShowHooked then
        wmExploreOnShowHooked = true
        WorldMapFrame:HookScript("OnShow", function()
            HookExplorationPinsOnCanvas(WorldMapFrame)
        end)
    end

    RegisterBfExplorationOnShow()

    --- Pins may not exist until the first frame after the map is shown (Leatrix runs at PLAYER_LOGIN; we also defer one tick).
    C_Timer.After(0, HookAllExplorationPinInstances)

    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_BattlefieldMap", function()
            HookExplorationPinsOnCanvas(BattlefieldMapFrame)
            RegisterBfExplorationOnShow()
        end)
    end
end

function M.InstallExploreReveal()
    if M._exploreRevealInstalled then return end
    PatchRevealForFaction()
    InstallExplorationHooks()
    M._exploreRevealInstalled = true
end

function M.RefreshExploreAppearance()
    if WorldMapFrame and WorldMapFrame.RefreshAll then
        WorldMapFrame:RefreshAll()
    elseif WorldMapFrame and WorldMapFrame.RefreshAllDataProviders then
        WorldMapFrame:RefreshAllDataProviders()
    end
    if BattlefieldMapFrame and BattlefieldMapFrame.RefreshAll then
        BattlefieldMapFrame:RefreshAll()
    end
end

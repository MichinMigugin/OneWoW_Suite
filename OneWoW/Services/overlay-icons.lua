local _, ns = ...

ns.OverlayIcons = {}
local OverlayIcons = ns.OverlayIcons

local iconDisplayNames = {
    ["BLANK"]        = "Blank (No Icon)",
    ["icon-add"]     = "Add Icon",
    ["icon-alert"]   = "Alert Icon",
    ["icon-alliance"]= "Alliance Icon",
    ["icon-compass"] = "Compass Icon",
    ["icon-fav"]     = "Favorite Icon",
    ["icon-flag"]    = "Flag Icon",
    ["icon-gears"]   = "Gears Icon",
    ["icon-horde"]   = "Horde Icon",
    ["icon-minus"]   = "Minus Icon",
    ["icon-mount"]   = "Mount Icon",
    ["icon-pet"]     = "Pet Icon",
    ["icon-pin"]     = "Pin Icon",
    ["icon-recipe"]  = "Recipe Icon",
    ["icon-toy"]     = "Toy Icon",
    ["icon-trash"]   = "Trash Icon",

    ["WhiteCircle-RaidBlips"]               = "Circle",
    ["Gamepad_Shp_Circle_64"]               = "Circle (Outline)",
    ["Gamepad_Shp_Square_64"]               = "Square",
    ["Gamepad_Shp_Triangle_64"]             = "Triangle",
    ["Gamepad_Shp_Cross_64"]                = "Cross",
    ["Rare-Elite-Star"]                     = "Star",
    ["UI-Achievement-Shield-2-Desaturated"] = "Shield",

    ["bags-glow-white"]    = "Glow - White",
    ["bags-glow-purple"]   = "Glow - Purple",
    ["bags-glow-blue"]     = "Glow - Blue",
    ["bags-glow-green"]    = "Glow - Green",
    ["bags-glow-orange"]   = "Glow - Orange",
    ["bags-glow-artifact"] = "Glow - Artifact",
    ["bags-glow-heirloom"] = "Glow - Heirloom",

    ["Solid-Circle"]  = "Solid Circle",
    ["Solid-Square"]  = "Solid Square",
    ["Spinning Orbs"] = "Spinning Orbs",
    ["Glow Pulse"]    = "Glow Pulse",
    ["Portal Spiral"] = "Portal Spiral",
    ["auctionhouse-itemicon-border-color"]    = "Auction House Border - Dynamic",
    ["auctionhouse-itemicon-border-blue"]     = "Auction House Border - Blue",
    ["auctionhouse-itemicon-border-green"]    = "Auction House Border - Green",
    ["auctionhouse-itemicon-border-purple"]   = "Auction House Border - Purple",
    ["auctionhouse-itemicon-border-gray"]     = "Auction House Border - Gray",
    ["auctionhouse-itemicon-border-orange"]   = "Auction House Border - Orange",
    ["auctionhouse-itemicon-border-white"]    = "Auction House Border - White",
    ["auctionhouse-itemicon-border-account"]  = "Auction House Border - Account",
    ["auctionhouse-itemicon-border-artifact"] = "Auction House Border - Artifact",
    ["Artifacts-ItemIconBorder"]        = "Artifact Item Border",
    ["Artifacts-PerkRing-GoldMedal"]    = "Artifact Ring - Gold",
    ["Artifacts-PerkRing-MainProc"]     = "Artifact Ring - Main",
    ["Artifacts-PerkRing-Small"]        = "Artifact Ring - Small",
    ["Artifacts-PerkRing-Highlight"]    = "Artifact Ring - Highlight",
    ["ArtifactsFX-SpinningGlowys"]      = "Artifact FX - Spinning Glow",
    ["ArtifactsFX-StarBurst"]           = "Artifact FX - Starburst",
    ["ArtifactsFX-YellowRing"]          = "Artifact FX - Yellow Ring",
    ["PowerSwirlAnimation-YellowRing"]  = "Power Swirl - Yellow Ring",
    ["PowerSwirlAnimation-BlueRing"]    = "Power Swirl - Blue Ring",
    ["PowerSwirlAnimation-StarBurst"]   = "Power Swirl - Starburst",
    ["PowerSwirlAnimation-WhiteStarBurst"] = "Power Swirl - White Starburst",
    ["PowerSwirlAnimation-SpinningGlowys"] = "Power Swirl - Spinning Glow",

    ["VignetteKill"]               = "Vignette Kill",
    ["VignetteEvent-SuperTracked"] = "Vignette Event",
    ["poi-door-arrow-up"]          = "Arrow Up",
    ["poi-traveldirections-arrow"] = "Travel Arrow",
    ["talents-arrow-line-red"]     = "Red Arrow Line",
    ["bags-junkcoin"]              = "Junk Coin",
    ["bags-newitem"]               = "New Item",
    ["bags-icon-consumables"]      = "Consumables",
    ["bags-icon-equipment"]        = "Equipment",
    ["bags-icon-reagents"]         = "Reagents",
    ["bags-icon-tradegoods"]       = "Trade Goods",
    ["bags-icon-profession-goods"] = "Profession Goods",
    ["bags-icon-scrappable"]       = "Scrappable",
    ["lootroll-icon-transmog"]     = "Loot Roll Transmog",
    ["transmog-icon-tick"]         = "Transmog Tick",
    ["transmog-icon-warning"]      = "Transmog Warning",
    ["transmog-icon-disabled"]     = "Transmog Disabled",
    ["groupfinder-icon-role-large-tank"]   = "Tank Icon",
    ["soulbinds_tree_conduit_icon_protect"]= "Protect Icon",
    ["Bonus-Objective-Star"]               = "Star",
    ["collections-icon-favorites"]         = "Favorites",
    ["worldquest-icon-petbattle"]          = "Pet Battle",
    ["mechagon-projects"]                  = "Mechagon Projects",
    ["map-icon-ignored-blueexclaimation"]  = "Blue Exclamation",
    ["map-icon-ignored-bluequestion"]      = "Blue Question",
    ["UI-QuestPoiImportant-OuterGlow"]     = "Quest Glow",
    ["Quest-Campaign-Available"]           = "Campaign Quest",
    ["Quest-DailyCampaign-Available"]      = "Daily Campaign",
    ["QuestArtifactTurnin"]                = "Artifact Quest",
    ["QuestLegendary"]                     = "Legendary Quest",
    ["questlog-questtypeicon-lock"]        = "Locked Quest",
    ["questlog-questtypeicon-questfailed"] = "Failed Quest",
    ["greatvault-dragonflight-32x32"]      = "Great Vault",
    ["warband-completed-icon"]             = "Warband Complete",
    ["warbands-icon"]                      = "Warband",
    ["Warfronts-BaseMapIcons-Horde-Workshop-Minimap"]    = "Horde Workshop",
    ["Warfronts-BaseMapIcons-Alliance-Workshop-Minimap"] = "Alliance Workshop",
    ["shop-icon-housing-beds-selected"]    = "Housing Bed",
    ["shop-icon-housing-mounts-up"]        = "Housing Mount",
    ["shop-icon-housing-pets-selected"]    = "Housing Pet",
    ["Perks-ShoppingCart"]                 = "Shopping Cart",
    ["ui-achievement-shield-2"]             = "Achievement Shield",
    ["Battlenet-ClientIcon-WoW"]            = "Battle.net WoW",
    ["BfAMission-Icon-HUB"]                 = "BfA Hub",
    ["BfAMission-Icon-Normal"]              = "BfA Mission",
    ["midnight-beta-access"]                = "Midnight Beta",
    ["checkmark-minimal-disabled"]          = "Checkmark Disabled",
    ["AnimCreate_Icon_Template"]            = "AnimCreate Template",
    ["AnimCreate_Icon_Texture"]             = "AnimCreate Texture",
    ["AnimCreate_Icon_Add"]                 = "AnimCreate Add",
    ["AnimCreate_Icon_Mask"]                = "AnimCreate Mask",
}

-- ObjectIconsAtlas minimap-tracking names. Display text comes from
-- MINIMAP_TRACKING_* GlobalStrings (see GetDisplayName).
local iconDisplayGlobals = {
    ["Banker"]              = "MINIMAP_TRACKING_BANKER",
    ["Auctioneer"]          = "MINIMAP_TRACKING_AUCTIONEER",
    ["Mailbox"]             = "MINIMAP_TRACKING_MAILBOX",
    ["Innkeeper"]           = "MINIMAP_TRACKING_INNKEEPER",
    ["FlightMaster"]        = "MINIMAP_TRACKING_FLIGHTMASTER",
    ["Repair"]              = "MINIMAP_TRACKING_REPAIR",
    ["StableMaster"]        = "MINIMAP_TRACKING_STABLEMASTER",
    ["Class"]               = "MINIMAP_TRACKING_TRAINER_CLASS",
    ["Profession"]          = "MINIMAP_TRACKING_TRAINER_PROFESSION",
    ["Food"]                = "MINIMAP_TRACKING_VENDOR_FOOD",
    ["Reagents"]            = "MINIMAP_TRACKING_VENDOR_REAGENT",
    ["Ammunition"]          = "MINIMAP_TRACKING_VENDOR_AMMO",
    ["Poisons"]             = "MINIMAP_TRACKING_VENDOR_POISON",
    ["BattleMaster"]        = "MINIMAP_TRACKING_BATTLEMASTER",
    ["Barbershop-32x32"]    = "MINIMAP_TRACKING_BARBER",
    ["poi-transmogrifier"]  = "MINIMAP_TRACKING_TRANSMOGRIFIER",
    ["WildBattlePet"]       = "MINIMAP_TRACKING_WILD_BATTLE_PET",
}

function OverlayIcons:GetIconList()
    return {
        "BLANK",
        "WhiteCircle-RaidBlips",
        "Gamepad_Shp_Circle_64",
        "Gamepad_Shp_Square_64",
        "Gamepad_Shp_Triangle_64",
        "Gamepad_Shp_Cross_64",
        "Rare-Elite-Star",
        "UI-Achievement-Shield-2-Desaturated",
        "icon-add",
        "icon-alert",
        "icon-alliance",
        "icon-compass",
        "icon-fav",
        "icon-flag",
        "icon-gears",
        "icon-horde",
        "icon-minus",
        "icon-mount",
        "icon-pet",
        "icon-pin",
        "icon-recipe",
        "icon-toy",
        "icon-trash",
        "Banker",
        "Auctioneer",
        "Mailbox",
        "Innkeeper",
        "FlightMaster",
        "Repair",
        "StableMaster",
        "Class",
        "Profession",
        "Food",
        "Reagents",
        "Ammunition",
        "Poisons",
        "BattleMaster",
        "Barbershop-32x32",
        "poi-transmogrifier",
        "WildBattlePet",
        "poi-door-arrow-up",
        "poi-traveldirections-arrow",
        "talents-arrow-line-red",
        "bags-junkcoin",
        "bags-newitem",
        "bags-icon-consumables",
        "bags-icon-equipment",
        "bags-icon-reagents",
        "bags-icon-tradegoods",
        "bags-icon-profession-goods",
        "bags-icon-scrappable",
        "lootroll-icon-transmog",
        "transmog-icon-tick",
        "transmog-icon-warning",
        "transmog-icon-disabled",
        "bags-glow-white",
        "bags-glow-purple",
        "bags-glow-blue",
        "bags-glow-green",
        "bags-glow-orange",
        "bags-glow-artifact",
        "bags-glow-heirloom",
        "auctionhouse-itemicon-border-color",
        "auctionhouse-itemicon-border-blue",
        "auctionhouse-itemicon-border-green",
        "auctionhouse-itemicon-border-purple",
        "auctionhouse-itemicon-border-gray",
        "auctionhouse-itemicon-border-orange",
        "auctionhouse-itemicon-border-white",
        "auctionhouse-itemicon-border-account",
        "auctionhouse-itemicon-border-artifact",
        "Artifacts-ItemIconBorder",
        "Artifacts-PerkRing-GoldMedal",
        "Artifacts-PerkRing-MainProc",
        "Artifacts-PerkRing-Small",
        "Artifacts-PerkRing-Highlight",
        "ArtifactsFX-SpinningGlowys",
        "ArtifactsFX-StarBurst",
        "ArtifactsFX-YellowRing",
        "PowerSwirlAnimation-YellowRing",
        "PowerSwirlAnimation-BlueRing",
        "PowerSwirlAnimation-StarBurst",
        "PowerSwirlAnimation-WhiteStarBurst",
        "PowerSwirlAnimation-SpinningGlowys",
        "groupfinder-icon-role-large-tank",
        "soulbinds_tree_conduit_icon_protect",
        "Bonus-Objective-Star",
        "collections-icon-favorites",
        "worldquest-icon-petbattle",
        "mechagon-projects",
        "VignetteKill",
        "VignetteEvent-SuperTracked",
        "map-icon-ignored-blueexclaimation",
        "map-icon-ignored-bluequestion",
        "UI-QuestPoiImportant-OuterGlow",
        "Quest-Campaign-Available",
        "Quest-DailyCampaign-Available",
        "QuestArtifactTurnin",
        "QuestLegendary",
        "questlog-questtypeicon-lock",
        "questlog-questtypeicon-questfailed",
        "greatvault-dragonflight-32x32",
        "warband-completed-icon",
        "warbands-icon",
        "Warfronts-BaseMapIcons-Horde-Workshop-Minimap",
        "Warfronts-BaseMapIcons-Alliance-Workshop-Minimap",
        "shop-icon-housing-beds-selected",
        "shop-icon-housing-mounts-up",
        "shop-icon-housing-pets-selected",
        "Perks-ShoppingCart",
        "ui-achievement-shield-2",
        "Battlenet-ClientIcon-WoW",
        "BfAMission-Icon-HUB",
        "BfAMission-Icon-Normal",
        "midnight-beta-access",
        "checkmark-minimal-disabled",
        "AnimCreate_Icon_Template",
        "AnimCreate_Icon_Texture",
        "AnimCreate_Icon_Add",
        "AnimCreate_Icon_Mask",
    }
end

function OverlayIcons:GetDisplayName(iconName)
    local globalKey = iconDisplayGlobals[iconName]
    if globalKey then
        local text = _G[globalKey]
        if type(text) == "string" and text ~= "" then
            return text
        end
    end
    return iconDisplayNames[iconName] or iconName
end

function OverlayIcons:IsCustomTexture(iconName)
    return iconName:match("^icon%-") ~= nil
end

function OverlayIcons:GetTexturePath(iconName)
    if iconName:match("^icon%-") then
        return "Interface\\AddOns\\OneWoW\\Media\\" .. iconName .. ".png"
    end
    return nil
end

function OverlayIcons:GetAtlasName(iconName)
    if iconName:match("^icon%-") then
        return nil
    end
    return iconName
end

function OverlayIcons:ApplyToTexture(texture, iconName)
    if not texture or not iconName then return end
    if iconName == "BLANK" then
        texture:SetTexture(nil)
        texture:SetAlpha(0)
        return
    end
    if self:IsCustomTexture(iconName) then
        local path = self:GetTexturePath(iconName)
        if path then texture:SetTexture(path) end
    else
        texture:SetAtlas(iconName, false)
    end
end

-- ============================================================================
-- Icon specs (Overlays 2.0)
-- ============================================================================
-- spec = { kind = "list"|"atlas"|"file", value = string, tint = {r,g,b}|nil }
--   list  — an entry from GetIconList (shipped icon-*.png or curated atlas)
--   atlas — any Blizzard atlas name (validated with C_Texture.GetAtlasInfo)
--   file  — a user file in Interface\AddOns\OneWoW\Media\CustomOverlays\

local CUSTOM_OVERLAYS_DIR = "Interface\\AddOns\\OneWoW\\Media\\CustomOverlays\\"

---@return string
function OverlayIcons:GetCustomOverlaysDir()
    return CUSTOM_OVERLAYS_DIR
end

--- True when the atlas name exists in the client.
---@param atlasName string|nil
---@return boolean
function OverlayIcons:IsValidAtlas(atlasName)
    if type(atlasName) ~= "string" or atlasName == "" then return false end
    return C_Texture.GetAtlasInfo(atlasName) ~= nil
end

--- Full texture path for a user-supplied CustomOverlays file name.
--- Strips any directory components the user may have pasted.
---@param fileName string
---@return string
function OverlayIcons:GetCustomFilePath(fileName)
    local clean = fileName:gsub("[\\/]+", ""):gsub("%s+$", ""):gsub("^%s+", "")
    return CUSTOM_OVERLAYS_DIR .. clean
end

--- Apply an icon spec to a texture. Returns false when the spec renders
--- nothing (BLANK or unresolvable), true otherwise. Always resets vertex
--- color, then applies the spec tint when present.
---@param texture Texture
---@param spec table|nil
---@return boolean visible
function OverlayIcons:ApplyIconSpec(texture, spec)
    if not texture then return false end

    local kind  = spec and spec.kind or "list"
    local value = spec and spec.value

    texture:SetVertexColor(1, 1, 1)

    if not value or value == "BLANK" then
        texture:SetTexture(nil)
        texture:SetAlpha(0)
        return false
    end

    if kind == "atlas" then
        if not self:IsValidAtlas(value) then
            texture:SetTexture(nil)
            texture:SetAlpha(0)
            return false
        end
        texture:SetAtlas(value, false)
    elseif kind == "file" then
        -- SetTexture returns false when the file does not exist; render
        -- nothing rather than a green placeholder square.
        if not texture:SetTexture(self:GetCustomFilePath(value)) then
            texture:SetTexture(nil)
            texture:SetAlpha(0)
            return false
        end
    else
        self:ApplyToTexture(texture, value)
    end

    local tint = spec and spec.tint
    if tint then
        texture:SetVertexColor(tint[1] or 1, tint[2] or 1, tint[3] or 1)
    end
    return true
end

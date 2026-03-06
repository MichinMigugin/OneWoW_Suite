local ADDON_NAME, OneWoW = ...

OneWoW.OverlayIcons = {}
local OverlayIcons = OneWoW.OverlayIcons

local iconDisplayNames = {
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

    ["bags-glow-white"]    = "Glow - White",
    ["bags-glow-purple"]   = "Glow - Purple",
    ["bags-glow-blue"]     = "Glow - Blue",
    ["bags-glow-green"]    = "Glow - Green",
    ["bags-glow-orange"]   = "Glow - Orange",
    ["bags-glow-artifact"] = "Glow - Artifact",
    ["bags-glow-heirloom"] = "Glow - Heirloom",

    ["VignetteKill"]               = "Vignette Kill",
    ["VignetteEvent-SuperTracked"] = "Vignette Event",
    ["poi-door-arrow-up"]          = "Arrow Up",
    ["poi-traveldirections-arrow"] = "Travel Arrow",
    ["talents-arrow-line-red"]     = "Red Arrow Line",
    ["bags-junkcoin"]              = "Junk Coin",
    ["bags-newitem"]               = "New Item",
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
    ["ui-achievement-shield-2"]            = "Achievement Shield",
}

function OverlayIcons:GetIconList()
    return {
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
        "poi-door-arrow-up",
        "poi-traveldirections-arrow",
        "talents-arrow-line-red",
        "bags-junkcoin",
        "bags-newitem",
        "bags-glow-white",
        "bags-glow-purple",
        "bags-glow-blue",
        "bags-glow-green",
        "bags-glow-orange",
        "bags-glow-artifact",
        "bags-glow-heirloom",
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
    }
end

function OverlayIcons:GetDisplayName(iconName)
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
    if self:IsCustomTexture(iconName) then
        local path = self:GetTexturePath(iconName)
        if path then texture:SetTexture(path) end
    else
        texture:SetAtlas(iconName, false)
    end
end

local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local Collectibles = ns.Collectibles

-- ============================================================================
-- EntityResolvers (core kinds)
-- ============================================================================
-- Populates OneWoW_GUI's resolver registry for kinds the base unit can answer
-- without Catalog. Quest and npc register from their data units as they load.
-- ============================================================================

local itemLoader = ns:CreateItemDataLoader({})
itemLoader:Initialize()

local function infoFromDisplay(display)
    if not display then return nil end
    return display.name, display.icon, display.quality, display.link
end

local function collectible(keyPrefix)
    return {
        Resolve = function(id)
            return infoFromDisplay(Collectibles.ResolveDisplay(keyPrefix .. id))
        end,
        RequestAsync = function(id, cb)
            local name, icon, quality, link = infoFromDisplay(Collectibles.ResolveDisplay(keyPrefix .. id))
            cb(id, name and { name = name, icon = icon, quality = quality, link = link } or nil)
        end,
    }
end

local function pack(name, icon, quality, link)
    if not name then return nil end
    return { name = name, icon = icon, quality = quality, link = link }
end

local function sync(resolveFn)
    return {
        Resolve = resolveFn,
        RequestAsync = function(id, cb)
            local name, icon, quality, link = resolveFn(id)
            cb(id, pack(name, icon, quality, link))
        end,
    }
end

local function itemResolve(id)
    local cached = itemLoader:GetCachedItem(id)
    if cached then
        return cached.name, cached.icon, cached.quality, cached.link
    end
    local name, link, quality, icon = itemLoader:ResolveItemData(id)
    return name, icon, quality, link
end

OneWoW_GUI:RegisterEntityResolver("item", {
    Resolve = itemResolve,
    RequestAsync = function(id, cb)
        itemLoader:LoadItemData(id, function(itemID, result)
            cb(itemID, result and result.name and {
                name = result.name,
                icon = result.icon,
                quality = result.quality,
                link = result.link,
            } or nil)
        end)
    end,
})

OneWoW_GUI:RegisterEntityResolver("mount", collectible("mount:"))
OneWoW_GUI:RegisterEntityResolver("pet", collectible("pet:"))
OneWoW_GUI:RegisterEntityResolver("toy", collectible("toy:"))
OneWoW_GUI:RegisterEntityResolver("transmog", collectible("appearance:source:"))

OneWoW_GUI:RegisterEntityResolver("currency", sync(function(id)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if info and info.name and info.name ~= "" then
        return info.name, info.iconFileID
    end
end))

OneWoW_GUI:RegisterEntityResolver("spell", sync(function(id)
    local info = C_Spell.GetSpellInfo(id)
    if info and info.name then
        return info.name, info.iconID, nil, C_Spell.GetSpellLink(id)
    end
end))

OneWoW_GUI:RegisterEntityResolver("achievement", sync(function(id)
    local _, name, _, _, _, _, _, _, _, icon = GetAchievementInfo(id)
    if name then
        return name, icon, nil, GetAchievementLink(id)
    end
end))

OneWoW_GUI:RegisterEntityResolver("faction", sync(function(id)
    local major = C_MajorFactions.GetMajorFactionData(id)
    if major and major.name then
        return major.name
    end
    local data = C_Reputation.GetFactionDataByID(id)
    if data and data.name then
        return data.name
    end
end))

OneWoW_GUI:RegisterEntityResolver("map", sync(function(id)
    local info = C_Map.GetMapInfo(id)
    if info and info.name then
        return info.name
    end
end))

OneWoW_GUI:RegisterEntityResolver("campaign", sync(function(id)
    local info = C_CampaignInfo.GetCampaignInfo(id)
    if info and info.name then
        return info.name
    end
end))

OneWoW_GUI:RegisterEntityResolver("instance", sync(function(id)
    local name, _, _, _, _, _, _, link = EJ_GetInstanceInfo(id)
    if name then
        return name, nil, nil, link
    end
end))

OneWoW_GUI:RegisterEntityResolver("encounter", sync(function(id)
    local name = EJ_GetEncounterInfo(id)
    if name and name ~= "" and not ns.Restriction.IsSecret(name) then
        return name
    end
end))

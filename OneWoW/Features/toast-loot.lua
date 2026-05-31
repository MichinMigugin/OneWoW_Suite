local _, OneWoW = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local PE = OneWoW_GUI.PredicateEngine

local Toasts = OneWoW.Toasts

local TYPE_COLORS = {
    mount  = {1.00, 0.84, 0.00, 1.0},
    pet    = {0.20, 0.80, 0.80, 1.0},
    toy    = {0.70, 0.40, 1.00, 1.0},
    recipe = {1.00, 0.60, 0.20, 1.0},
    tmog   = {1.00, 0.40, 0.60, 1.0},
}

local TITLE_KEYS = {
    mount  = "TOAST_NEW_MOUNT",
    pet    = "TOAST_NEW_PET",
    toy    = "TOAST_NEW_TOY",
    recipe = "TOAST_NEW_RECIPE",
    tmog   = "TOAST_NEW_TMOG",
}

local function GetDB()
    return OneWoW.db and OneWoW.db.global and OneWoW.db.global.toasts
end

local function LootEnabled()
    local db = GetDB()
    return db and db.loot and db.loot.enabled ~= false
end

local function CategoryEnabled(category)
    local db = GetDB()
    return db and db.loot and db.loot[category] ~= false
end

local function GetL(key, fallback)
    return (OneWoW.L and OneWoW.L[key]) or fallback
end

local function FireLootToast(category, itemName, itemTexture, _)
    if not LootEnabled() then return end
    if not CategoryEnabled(category) then return end
    if not itemName or itemName == "" then return end

    Toasts.FireToast({
        toastType = "loot",
        category  = category,
        title     = GetL(TITLE_KEYS[category], category),
        subtitle  = itemName,
        icon      = itemTexture,
        color     = TYPE_COLORS[category],
    })
end

local function OnNewMount(mountID)
    if not LootEnabled() or not CategoryEnabled("mounts") then return end
    if not mountID or mountID <= 0 then return end

    local name, _, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
    if not isCollected then return end
    if not name or not icon then return end

    FireLootToast("mount", name, icon, nil)
end

local function OnNewPet(petGUID)
    if not LootEnabled() or not CategoryEnabled("pets") then return end
    if not petGUID or petGUID == "" then return end

    -- returns: speciesID, customName, level, xp, maxXp, displayID, isFavorite, name, icon, ...
    local speciesID, _, _, _, _, _, _, name, icon = C_PetJournal.GetPetInfoByPetID(petGUID)
    speciesID = tonumber(speciesID)
    if not speciesID or speciesID <= 0 then return end
    if not name or not icon then return end

    FireLootToast("pet", name, icon, nil)
end

local function OnNewToy(itemID)
    if not LootEnabled() or not CategoryEnabled("toys") then return end
    if not itemID or itemID <= 0 then return end

    -- Use C_ToyBox.GetToyInfo for authoritative toy data.
    -- PE:BuildProps relies on hyperlink-based item info, which is frequently
    -- uncached the moment NEW_TOY_ADDED fires (especially for seasonal-vendor
    -- toys like the Children's Week balloons), causing nameRaw to be empty
    -- and the toast to silently no-op.
    local _, name, icon = C_ToyBox.GetToyInfo(itemID)
    if not name or not icon then return end
    if not PlayerHasToy(itemID) then return end

    FireLootToast("toy", name, icon, nil)
end

local bagCache  = {}
local bagReady  = false

local function GetItemCacheKey(info)
    if info.itemGUID and info.itemGUID ~= "" then
        return info.itemGUID
    end
    return "id_" .. info.itemID
end

local function BuildBagCache()
    bagCache = {}
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                bagCache[GetItemCacheKey(info)] = info.itemID
            end
        end
    end
    bagReady = true
end

local function ScanBagsForCollectibles()
    if not bagReady then return end
    if not LootEnabled() then return end

    local tmogsEnabled = CategoryEnabled("tmogs")
    local recipesEnabled = CategoryEnabled("recipes")
    if not tmogsEnabled and not recipesEnabled then return end

    local tmogsCompiled = nil
    local recipeCompiled = nil

    if tmogsEnabled then
        tmogsCompiled = PE:Compile("#transmog&!#knowntransmog")
    end

    if recipesEnabled then
        local dbLoot = GetDB() and GetDB().loot
        local expr = "#recipe&!#alreadyknown"
        if dbLoot and dbLoot.recipesOnlyMyProfessions then
            expr = expr .. "&#myprofs"
        end
        recipeCompiled = PE:Compile(expr)
    end

    local newCache = {}

    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local guid = GetItemCacheKey(info)
                newCache[guid] = info.itemID

                if not bagCache[guid] then
                    local props = PE:BuildProps(info.itemID, bag, slot, info)

                    if props.name and props.icon then
                        if tmogsEnabled and tmogsCompiled then
                            local result = PE:SafeEvaluate(tmogsCompiled, props)

                            if result then
                                FireLootToast("tmog", props.nameRaw, props.icon, nil)
                            end
                        end

                        if recipesEnabled and recipeCompiled then
                            local result = PE:SafeEvaluate(recipeCompiled, props)

                            if result then
                                FireLootToast("recipe", props.nameRaw, props.icon, nil)
                            end
                        end
                    end
                end
            end
        end
    end

    bagCache = newCache
end

-- ============================================================================
-- Blizzard native-alert suppression
-- ============================================================================
-- The Blizzard NewMount/NewPet/NewToy alert systems route through AlertFrame
-- (events registered on AlertFrame are dispatched to the matching subsystem).
-- Unregistering them here cleanly suppresses the native popups while leaving
-- our own lootFrame's handlers intact, so OneWoW's toast can still fire.
local NATIVE_ALERT_EVENTS = { "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED" }

local function ApplyBlizzardSuppression()
    local db = GetDB()
    local should = db and db.loot and db.loot.suppressBlizzardAlerts == true
    for _, ev in ipairs(NATIVE_ALERT_EVENTS) do
        if should then
            AlertFrame:UnregisterEvent(ev)
        else
            AlertFrame:RegisterEvent(ev)
        end
    end
end

Toasts.ApplyBlizzardSuppression = ApplyBlizzardSuppression

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("PLAYER_LOGIN")
lootFrame:RegisterEvent("BAG_UPDATE_DELAYED")
lootFrame:RegisterEvent("NEW_MOUNT_ADDED")
lootFrame:RegisterEvent("NEW_PET_ADDED")
lootFrame:RegisterEvent("NEW_TOY_ADDED")
lootFrame:RegisterEvent("SKILL_LINES_CHANGED")

lootFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3, BuildBagCache)
        ApplyBlizzardSuppression()

    elseif event == "SKILL_LINES_CHANGED" then
        PE:InvalidateKnownProfessions()

    elseif event == "BAG_UPDATE_DELAYED" then
        ScanBagsForCollectibles()

    elseif event == "NEW_MOUNT_ADDED" then
        OnNewMount(tonumber(arg1))

    elseif event == "NEW_PET_ADDED" then
        OnNewPet(arg1)

    elseif event == "NEW_TOY_ADDED" then
        OnNewToy(tonumber(arg1))
    end
end)

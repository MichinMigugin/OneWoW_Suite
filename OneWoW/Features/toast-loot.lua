local ADDON_NAME, OneWoW = ...

local Toasts = OneWoW.Toasts

local TYPE_COLORS = {
    mount  = {1.00, 0.84, 0.00, 1.0},
    pet    = {0.20, 0.80, 0.80, 1.0},
    toy    = {0.70, 0.40, 1.00, 1.0},
    recipe = {1.00, 0.60, 0.20, 1.0},
    tmog   = {1.00, 0.40, 0.60, 1.0},
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

local function FireLootToast(category, itemName, itemTexture, subtitle)
    if not LootEnabled() then return end
    if not CategoryEnabled(category) then return end
    if not itemName or itemName == "" then return end

    local titleKey = {
        mount  = "TOAST_NEW_MOUNT",
        pet    = "TOAST_NEW_PET",
        toy    = "TOAST_NEW_TOY",
        recipe = "TOAST_NEW_RECIPE",
        tmog   = "TOAST_NEW_TMOG",
    }

    Toasts.FireToast({
        toastType = "loot",
        category  = category,
        title     = GetL(titleKey[category], category),
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
    if not PlayerHasToy or not PlayerHasToy(itemID) then return end

    local name = (C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID)) or C_Item.GetItemInfo(itemID)
    local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or select(10, C_Item.GetItemInfo(itemID))
    if not name then return end

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

    local newCache = {}

    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local guid = GetItemCacheKey(info)
                newCache[guid] = info.itemID

                if not bagCache[guid] then
                    local itemID = info.itemID
                    local itemName, _, _, _, _, _, _, _, _, itemTexture,
                          _, classID, subclassID = C_Item.GetItemInfo(itemID)

                    if itemName and itemTexture then
                        if CategoryEnabled("tmogs") and C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog then
                            local hasTransmog = C_TransmogCollection.PlayerHasTransmog(itemID)
                            if hasTransmog == false then
                                local isTransmog = (classID == 4) or (classID == 2)
                                if isTransmog then
                                    FireLootToast("tmog", itemName, itemTexture, nil)
                                end
                            end
                        end

                        if CategoryEnabled("recipes") then
                            local isRecipe = (classID == 9)
                            if isRecipe then
                                local link = info.hyperlink
                                if link then
                                    local spellID = tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
                                    if spellID and not IsSpellKnownOrOverridesKnown(spellID) then
                                        FireLootToast("recipe", itemName, itemTexture, nil)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    bagCache = newCache
end

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("PLAYER_LOGIN")
lootFrame:RegisterEvent("BAG_UPDATE_DELAYED")
lootFrame:RegisterEvent("NEW_MOUNT_ADDED")
lootFrame:RegisterEvent("NEW_PET_ADDED")
lootFrame:RegisterEvent("NEW_TOY_ADDED")

lootFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(3, BuildBagCache)

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

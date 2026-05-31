local addonName, ns = ...

ns.PetsMounts = {}
local Module = ns.PetsMounts

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local petsMounts = {
        pets = { collection = {} },
        mounts = { collection = {} },
    }

    local mountIDs = C_MountJournal.GetMountIDs()
    if mountIDs then
        for _, mountID in ipairs(mountIDs) do
            local name, spellID, icon, isActive, isUsable, sourceType,
                  isFavorite, isFactionSpecific, faction, shouldHideOnChar,
                  isCollected = C_MountJournal.GetMountInfoByID(mountID)

            if isCollected then
                table.insert(petsMounts.mounts.collection, {
                    mountID = mountID,
                    name = name,
                    icon = icon,
                })
            end
        end
    end
    petsMounts.mounts.collected = #petsMounts.mounts.collection
    petsMounts.mounts.total = mountIDs and #mountIDs or 0

    local numPets, numOwned = C_PetJournal.GetNumPets()
    if numPets and numPets > 0 then
        for i = 1, numPets do
            local petID, speciesID, owned, customName, level, favorite,
                  isRevoked, speciesName, icon = C_PetJournal.GetPetInfoByIndex(i)

            if owned and petID then
                table.insert(petsMounts.pets.collection, {
                    petID = petID,
                    speciesID = speciesID,
                    name = speciesName,
                    icon = icon,
                })
            end
        end
    end
    petsMounts.pets.collected = #petsMounts.pets.collection
    petsMounts.pets.total = numPets or 0

    charData.petsMounts = petsMounts
    charData.lastUpdate = time()

    return true
end

local addonName, ns = ...

ns.PersonalBank = {}
local Module = ns.PersonalBank

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local bank = {
        tabs = {}
    }

    local numTabs = C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Character)

    for tabIndex = 1, numTabs do
        local tabData = {
            items = {},
            totalSlots = 98,
            usedSlots = 0,
            freeSlots = 98
        }

        local bankBagID = 5 + tabIndex
        local numSlots = C_Container.GetContainerNumSlots(bankBagID)

        if numSlots and numSlots > 0 then
            tabData.totalSlots = numSlots
            local usedCount = 0

            for slotID = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bankBagID, slotID)

                if itemInfo and itemInfo.itemID then
                    local itemLink = C_Container.GetContainerItemLink(bankBagID, slotID)
                    local itemID = itemInfo.itemID
                    local itemName, _, itemQuality, itemLevel, _, _, _, _, _, itemTexture, sellPrice = GetItemInfo(itemLink or itemID)

                    tabData.items[slotID] = {
                        itemID = itemID,
                        itemLink = itemLink,
                        itemName = itemName,
                        quality = itemInfo.quality or itemQuality,
                        itemLevel = itemLevel,
                        texture = itemTexture,
                        sellPrice = sellPrice or 0,
                        stackCount = itemInfo.stackCount,
                        isLocked = itemInfo.isLocked,
                        isBound = itemInfo.isBound,
                    }
                    usedCount = usedCount + 1
                end
            end

            tabData.usedSlots = usedCount
            tabData.freeSlots = numSlots - usedCount
        end

        bank.tabs[tabIndex] = tabData
    end

    charData.personalBank = bank
    charData.personalBankLastUpdate = time()

    return true
end

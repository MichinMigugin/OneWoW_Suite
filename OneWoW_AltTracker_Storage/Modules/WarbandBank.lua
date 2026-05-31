local addonName, ns = ...

ns.WarbandBank = {}
local Module = ns.WarbandBank

function Module:CollectData(charKey, charData)
    if not charKey then return false end
    if not OneWoW_AltTracker_Storage_DB then return false end

    local warbandBank = {
        tabs = {},
        totalSlots = 0,
        totalFree = 0,
        totalUsed = 0,
    }

    if C_Bank and C_Bank.FetchDepositedMoney then
        warbandBank.money = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
    end

    local numTabs = 0
    pcall(function()
        numTabs = C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Account) or 0
    end)

    local totalSlots = 0
    local totalFree = 0
    local totalUsed = 0

    for tabIndex = 1, 5 do
        local tabData = {
            items = {},
            totalSlots = 98,
            usedSlots = 0,
            freeSlots = 98
        }

        if tabIndex <= numTabs then
            local warbandBagID = 11 + tabIndex
            local numSlots = C_Container.GetContainerNumSlots(warbandBagID)

            if numSlots and numSlots > 0 then
                tabData.totalSlots = numSlots
                local usedCount = 0

                for slotIndex = 1, numSlots do
                    local itemInfo = C_Container.GetContainerItemInfo(warbandBagID, slotIndex)
                    if itemInfo and itemInfo.itemID then
                        local itemLink = C_Container.GetContainerItemLink(warbandBagID, slotIndex)
                        local itemName, _, itemQuality, itemLevel, _, _, _, _, _, itemTexture, sellPrice = C_Item.GetItemInfo(itemLink or itemInfo.itemID)
                        tabData.items[slotIndex] = {
                            itemID = itemInfo.itemID,
                            itemName = itemName,
                            itemLink = itemLink,
                            quality = itemInfo.quality or itemQuality,
                            itemLevel = itemLevel,
                            texture = itemTexture,
                            sellPrice = sellPrice or 0,
                            stackCount = itemInfo.stackCount or 1,
                        }
                        usedCount = usedCount + 1
                    end
                end

                tabData.usedSlots = usedCount
                tabData.freeSlots = numSlots - usedCount
            end
        else
            tabData.totalSlots = 0
            tabData.usedSlots = 0
            tabData.freeSlots = 0
        end

        warbandBank.tabs[tabIndex] = tabData
        totalSlots = totalSlots + tabData.totalSlots
        totalFree = totalFree + tabData.freeSlots
        totalUsed = totalUsed + tabData.usedSlots
    end

    warbandBank.totalSlots = totalSlots
    warbandBank.totalFree = totalFree
    warbandBank.totalUsed = totalUsed
    warbandBank.lastUpdateTime = time()
    warbandBank.lastUpdatedBy = charKey

    _G.OneWoW_AltTracker_Storage_DB.warbandBank = warbandBank

    return true
end

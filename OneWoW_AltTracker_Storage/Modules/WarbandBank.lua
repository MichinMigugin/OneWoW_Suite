local _, ns = ...

ns.WarbandBank = {}
local Module = ns.WarbandBank

-- Account-wide warband bank, tabbed (up to 5): tab N lives in container bag 11+N.
-- Account-scope, so it writes DB.warbandBank (not charData). Slot scanning and the
-- canonical record shape live in ns.ContainerScan; this keeps the tab structure,
-- money, and rolled-up slot totals.
function Module:CollectData(charKey, _)
    if not charKey then return false end

    local warbandBank = {
        tabs = {},
        totalSlots = 0,
        totalFree = 0,
        totalUsed = 0,
    }

    warbandBank.money = C_Bank.FetchDepositedMoney(Enum.BankType.Account)

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
            local slots, usedCount, numSlots = ns.ContainerScan:BagSlots(warbandBagID)

            if numSlots and numSlots > 0 then
                tabData.items = slots
                tabData.totalSlots = numSlots
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

    OneWoW_AltTracker_Storage_DB.warbandBank = warbandBank

    return true
end

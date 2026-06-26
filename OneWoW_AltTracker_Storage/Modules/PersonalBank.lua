local _, ns = ...

ns.PersonalBank = {}
local Module = ns.PersonalBank

-- Character bank, tabbed: tab N lives in container bag 5+N. Slot scanning and the
-- canonical record shape live in ns.ContainerScan; this keeps only the tab
-- structure and per-tab slot accounting.
function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local bank = {
        tabs = {}
    }

    local numTabs = C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Character)

    for tabIndex = 1, numTabs do
        local bankBagID = 5 + tabIndex
        local slots, usedCount, numSlots = ns.ContainerScan:BagSlots(bankBagID)

        local hasSlots = numSlots and numSlots > 0
        bank.tabs[tabIndex] = {
            items = slots,
            totalSlots = hasSlots and numSlots or 98,
            usedSlots = usedCount,
            freeSlots = hasSlots and (numSlots - usedCount) or 98,
        }
    end

    charData.personalBank = bank
    charData.personalBankLastUpdate = time()

    return true
end

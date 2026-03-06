local addonName, ns = ...

ns.Economy = {}
local Module = ns.Economy

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    charData.money = GetMoney()

    local currencies = {}
    local currencyListSize = C_CurrencyInfo.GetCurrencyListSize()

    for i = 1, currencyListSize do
        local currencyInfo = C_CurrencyInfo.GetCurrencyListInfo(i)

        if currencyInfo and not currencyInfo.isHeader then
            local detailedInfo = C_CurrencyInfo.GetCurrencyInfo(currencyInfo.currencyID or currencyInfo.ID)

            if detailedInfo then
                currencies[detailedInfo.currencyID] = {
                    id = detailedInfo.currencyID,
                    name = detailedInfo.name,
                    quantity = detailedInfo.quantity,
                    maxQuantity = detailedInfo.maxQuantity,
                    totalEarned = detailedInfo.totalEarned,
                    maxWeeklyQuantity = detailedInfo.maxWeeklyQuantity,
                    quantityEarnedThisWeek = detailedInfo.quantityEarnedThisWeek,
                    iconFileID = detailedInfo.iconFileID,
                    isAccountWide = detailedInfo.isAccountWide,
                    isAccountTransferSource = detailedInfo.isAccountTransferSource,
                    isAccountTransferDestination = detailedInfo.isAccountTransferDestination,
                }
            end
        end
    end

    charData.currencies = currencies

    return true
end

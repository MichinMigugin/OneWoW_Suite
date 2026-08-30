local _, ns = ...

ns.Economy = {}
local Module = ns.Economy

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    charData.money = GetMoney()
    -- Personal bank deposited gold (0 when the bank has not been opened this
    -- session, or when the character bank holds no gold).
    charData.moneyBank = C_Bank.FetchDepositedMoney(Enum.BankType.Character)

    -- GetCurrencyListInfo only walks rows visible in the currency panel, so a
    -- collapsed header hides every currency under it. Expand collapsed headers
    -- before collecting, then restore the player's collapsed state after.
    local reCollapse = {}
    local i = 1
    while i <= C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and not info.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(i, true)
            reCollapse[info.name] = true
        end
        i = i + 1
    end

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

    -- Restore collapsed headers in reverse so list indices stay valid.
    for j = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
        local info = C_CurrencyInfo.GetCurrencyListInfo(j)
        if info and info.isHeader and info.isHeaderExpanded and reCollapse[info.name] then
            C_CurrencyInfo.ExpandCurrencyList(j, false)
        end
    end

    charData.currencies = currencies

    return true
end

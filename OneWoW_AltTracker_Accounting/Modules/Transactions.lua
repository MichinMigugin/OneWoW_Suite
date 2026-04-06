local addonName, ns = ...

ns.Transactions = {}
local Transactions = ns.Transactions

local COMBINE_WINDOW = 300
local recentClaims = {}

function Transactions:RecordTransaction(txData)
    if not OneWoW_AltTracker_Accounting_DB or not OneWoW_AltTracker_Accounting_DB.transactions then
        return false
    end

    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    txData.character = txData.character or charKey
    txData.timestamp = txData.timestamp or GetServerTime()
    txData.id = ns:GetNextTransactionID()

    local matchingTx = self:FindRecentTransaction(txData)

    if matchingTx then
        matchingTx.amount = matchingTx.amount + txData.amount
        if txData.quantity then
            matchingTx.quantity = (matchingTx.quantity or 0) + txData.quantity
        end
    else
        table.insert(OneWoW_AltTracker_Accounting_DB.transactions, 1, txData)
        ns:TrimTransactions()
    end

    if txData.category ~= "uncategorized" then
        table.insert(recentClaims, {
            amount = txData.amount,
            time = GetTime(),
        })
    end

    ns:InvalidateStatistics()

    if ns.onNewTransaction then
        ns.onNewTransaction()
    end

    return true
end

function Transactions:IsAmountClaimed(amount, withinSeconds)
    withinSeconds = withinSeconds or 1.5
    local now = GetTime()

    for i = #recentClaims, 1, -1 do
        if (now - recentClaims[i].time) > 5 then
            table.remove(recentClaims, i)
        end
    end

    for i, claim in ipairs(recentClaims) do
        if (now - claim.time) <= withinSeconds and
           math.abs(claim.amount - amount) <= 1 then
            table.remove(recentClaims, i)
            return true
        end
    end

    local remaining = amount
    local matched = {}
    for i, claim in ipairs(recentClaims) do
        if (now - claim.time) <= withinSeconds and claim.amount <= remaining + 1 then
            table.insert(matched, i)
            remaining = remaining - claim.amount
            if remaining <= 1 then break end
        end
    end

    if remaining <= 1 and #matched > 0 then
        for i = #matched, 1, -1 do
            table.remove(recentClaims, matched[i])
        end
        return true
    end

    return false
end

function Transactions:FindRecentTransaction(txData)
    local timeMin = txData.timestamp - COMBINE_WINDOW
    local timeMax = txData.timestamp + COMBINE_WINDOW

    for _, tx in ipairs(OneWoW_AltTracker_Accounting_DB.transactions) do
        if tx.character == txData.character and
           tx.type == txData.type and
           tx.category == txData.category and
           tx.source == txData.source and
           tx.timestamp >= timeMin and
           tx.timestamp <= timeMax then

            if txData.item then
                if tx.item == txData.item then
                    return tx
                end
            else
                return tx
            end
        end
    end

    return nil
end

function Transactions:RecordIncome(category, amount, source, item, itemName, quantity, notes)
    return self:RecordTransaction({
        type = "income",
        category = category,
        amount = amount,
        source = source or "Unknown",
        item = item,
        itemName = itemName,
        quantity = quantity,
        notes = notes,
    })
end

function Transactions:RecordExpense(category, amount, source, item, itemName, quantity, notes)
    return self:RecordTransaction({
        type = "expense",
        category = category,
        amount = amount,
        source = source or "Unknown",
        item = item,
        itemName = itemName,
        quantity = quantity,
        notes = notes,
    })
end

function Transactions:DeleteTransaction(txId)
    if not OneWoW_AltTracker_Accounting_DB or not OneWoW_AltTracker_Accounting_DB.transactions then
        return false
    end
    for i, tx in ipairs(OneWoW_AltTracker_Accounting_DB.transactions) do
        if tx.id == txId then
            table.remove(OneWoW_AltTracker_Accounting_DB.transactions, i)
            ns:InvalidateStatistics()
            if ns.onNewTransaction then
                ns.onNewTransaction()
            end
            return true
        end
    end
    return false
end

function Transactions:UpdateTransaction(txId, newData)
    if not OneWoW_AltTracker_Accounting_DB or not OneWoW_AltTracker_Accounting_DB.transactions then
        return false
    end
    for _, tx in ipairs(OneWoW_AltTracker_Accounting_DB.transactions) do
        if tx.id == txId then
            if newData.amount ~= nil then tx.amount = newData.amount end
            if newData.itemName ~= nil then tx.itemName = newData.itemName end
            if newData.category ~= nil then tx.category = newData.category end
            if newData.source ~= nil then tx.source = newData.source end
            if newData.notes ~= nil then tx.notes = newData.notes end
            if newData.quantity ~= nil then tx.quantity = newData.quantity end
            ns:InvalidateStatistics()
            if ns.onNewTransaction then
                ns.onNewTransaction()
            end
            return true
        end
    end
    return false
end

function Transactions:RecordTransfer(category, amount, source, item, itemName, quantity, notes)
    return self:RecordTransaction({
        type = "transfer",
        category = category,
        amount = amount,
        source = source or "Unknown",
        item = item,
        itemName = itemName,
        quantity = quantity,
        notes = notes,
    })
end

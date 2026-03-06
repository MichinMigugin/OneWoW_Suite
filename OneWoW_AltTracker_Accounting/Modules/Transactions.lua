local addonName, ns = ...

ns.Transactions = {}
local Transactions = ns.Transactions

local COMBINE_WINDOW = 300

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

    ns:InvalidateStatistics()

    if ns.onNewTransaction then
        ns.onNewTransaction()
    end

    return true
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

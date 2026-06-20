local _, ns = ...

-- Public, cross-addon surface for the Accounting unit (gold/transaction ledger).
-- ns stays private.
OneWoW_AltTracker_Accounting_API = {}

---@class OneWoWAccountingStats
---@field income number total income (copper) in range
---@field expense number total expense (copper) in range
---@field profit number income - expense
---@field transactionCount number matching transactions
---@field categories table<string, number> per-category net (copper)

---@class OneWoWAccountingUpdateFields
---@field amount number|nil
---@field itemName string|nil
---@field category string|nil
---@field source string|nil
---@field notes string|nil
---@field quantity number|nil

--- Record an income transaction.
---@param category string
---@param amount number copper
---@param source string|nil
---@param item string|nil item link
---@param itemName string|nil
---@param quantity number|nil
---@param notes string|nil
---@return boolean recorded
function OneWoW_AltTracker_Accounting_API.RecordIncome(category, amount, source, item, itemName, quantity, notes)
    return ns.Transactions:RecordIncome(category, amount, source, item, itemName, quantity, notes)
end

--- Record an expense transaction.
---@param category string
---@param amount number copper
---@param source string|nil
---@param item string|nil item link
---@param itemName string|nil
---@param quantity number|nil
---@param notes string|nil
---@return boolean recorded
function OneWoW_AltTracker_Accounting_API.RecordExpense(category, amount, source, item, itemName, quantity, notes)
    return ns.Transactions:RecordExpense(category, amount, source, item, itemName, quantity, notes)
end

--- Update mutable fields of an existing transaction by id.
---@param txId number
---@param fields OneWoWAccountingUpdateFields
---@return boolean updated false if the id was not found
function OneWoW_AltTracker_Accounting_API.UpdateTransaction(txId, fields)
    return ns.Transactions:UpdateTransaction(txId, fields)
end

--- Delete a transaction by id.
---@param txId number
---@return boolean deleted false if the id was not found
function OneWoW_AltTracker_Accounting_API.DeleteTransaction(txId)
    return ns.Transactions:DeleteTransaction(txId)
end

--- Aggregate income/expense statistics over an optional time/character/category
--- filter. Side effect: caches the computed totals into the ledger statistics.
---@param timeStart number|nil epoch seconds (default 0)
---@param timeEnd number|nil epoch seconds (default now + 1 day)
---@param characterFilter string|nil charKey to restrict to
---@param categoryFilter string|nil category to restrict to
---@return OneWoWAccountingStats stats
function OneWoW_AltTracker_Accounting_API.CalculateStatistics(timeStart, timeEnd, characterFilter, categoryFilter)
    return ns:CalculateStatistics(timeStart, timeEnd, characterFilter, categoryFilter)
end

--- Register a listener invoked after any transaction is recorded, updated, or
--- deleted (e.g. to refresh a UI). Passing nil clears the listener.
---@param listener fun()|nil
function OneWoW_AltTracker_Accounting_API.SetTransactionListener(listener)
    ns.onNewTransaction = listener
end

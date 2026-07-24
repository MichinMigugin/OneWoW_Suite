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

--- Claim a gold delta so GoldWatcher will not fall through to uncategorized,
--- without writing a ledger row (IGNORE / safety claim after split invoices).
---@param amount number copper (absolute)
---@return boolean claimed
function OneWoW_AltTracker_Accounting_API.ClaimAmount(amount)
    return ns.Transactions:ClaimAmount(amount)
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

--- Whether the ledger store has finished initializing and is safe to record to.
--- Lets other units gate recording without reaching into the SV global.
---@return boolean ready
function OneWoW_AltTracker_Accounting_API.IsReady()
    return OneWoW_AltTracker_Accounting_DB ~= nil
        and OneWoW_AltTracker_Accounting_DB.transactions ~= nil
end

--- The full transaction ledger (newest-first list). Empty table if the store has
--- not initialized yet, so callers can iterate without a nil guard.
---@return table transactions
function OneWoW_AltTracker_Accounting_API.GetTransactions()
    return OneWoW_AltTracker_Accounting_DB and OneWoW_AltTracker_Accounting_DB.transactions or {}
end

--- Custom reset boundary (epoch seconds) stamped by the last "Reset Data"; 0 if
--- none has been set.
---@return number resetDate
function OneWoW_AltTracker_Accounting_API.GetCustomResetDate()
    local db = OneWoW_AltTracker_Accounting_DB
    return (db and db.settings and db.settings.resetDate) or 0
end

--- Whether guild bank flows are counted as personal income/expense.
---@return boolean
function OneWoW_AltTracker_Accounting_API.GetGuildAsPersonal()
    local db = OneWoW_AltTracker_Accounting_DB
    return db and db.settings and db.settings.guildAsPersonal == true
end

--- Count (or stop counting) guild bank flows as personal income/expense.
---@param enabled boolean
function OneWoW_AltTracker_Accounting_API.SetGuildAsPersonal(enabled)
    local db = OneWoW_AltTracker_Accounting_DB
    if db and db.settings then
        db.settings.guildAsPersonal = enabled and true or false
    end
end

--- Wipe the entire ledger (transactions + cached statistics) and stamp a fresh
--- reset boundary. Fires the transaction listener.
---@return boolean reset false if the store is not loaded
function OneWoW_AltTracker_Accounting_API.ResetAll()
    return ns.Transactions:ResetAll()
end

--- Remove every ledger entry belonging to one character (the "Manage Alts"
--- per-character purge).
---@param charKey string
---@return number removed count of transactions deleted
function OneWoW_AltTracker_Accounting_API.PurgeCharacter(charKey)
    return ns.Transactions:PurgeCharacter(charKey)
end

--- Bucket filtered transactions into income/expense/profit time series.
---@param txs table
---@param timeStart number|nil
---@param timeEnd number|nil
---@return table series
function OneWoW_AltTracker_Accounting_API.BuildFlowSeries(txs, timeStart, timeEnd)
    return ns.Analytics.BuildFlowSeries(txs, timeStart, timeEnd)
end

--- Reconstruct ledger-implied wallet path for sparklines and high/low.
---@param txs table
---@param opts table endBalance, timeStart, timeEnd, characterFilter
---@return table walletSeries
function OneWoW_AltTracker_Accounting_API.BuildWalletSeries(txs, opts)
    return ns.Analytics.BuildWalletSeries(txs, opts)
end

--- Dashboard averages and top category/item rollups.
---@param txs table
---@param timeStart number|nil
---@param timeEnd number|nil
---@return table summary
function OneWoW_AltTracker_Accounting_API.BuildDashboardSummary(txs, timeStart, timeEnd)
    return ns.Analytics.BuildDashboardSummary(txs, timeStart, timeEnd)
end

---@param series number[]
---@return number|nil high
---@return number|nil low
function OneWoW_AltTracker_Accounting_API.SeriesRange(series)
    return ns.Analytics.SeriesRange(series)
end

--- Whether the Financials Dashboard view mode is enabled.
---@return boolean
function OneWoW_AltTracker_Accounting_API.GetFinancialsDashboard()
    local db = OneWoW_AltTracker_Accounting_DB
    return db and db.settings and db.settings.financialsDashboard == true
end

--- Persist Financials Dashboard view mode.
---@param enabled boolean
function OneWoW_AltTracker_Accounting_API.SetFinancialsDashboard(enabled)
    local db = OneWoW_AltTracker_Accounting_DB
    if db and db.settings then
        db.settings.financialsDashboard = enabled and true or false
    end
end

--- Whether the Financials options row (retention / guild / reset) is expanded.
---@return boolean
function OneWoW_AltTracker_Accounting_API.GetFinancialsOptionsOpen()
    local db = OneWoW_AltTracker_Accounting_DB
    return db and db.settings and db.settings.financialsOptionsOpen == true
end

--- Persist Financials options row expanded state.
---@param open boolean
function OneWoW_AltTracker_Accounting_API.SetFinancialsOptionsOpen(open)
    local db = OneWoW_AltTracker_Accounting_DB
    if db and db.settings then
        db.settings.financialsOptionsOpen = open and true or false
    end
end

--- Days of detailed Financials history to keep before daily rollup. 0 = Off.
---@return number days
function OneWoW_AltTracker_Accounting_API.GetDetailRetentionDays()
    local db = OneWoW_AltTracker_Accounting_DB
    local days = db and db.settings and db.settings.detailRetentionDays
    return ns.Compaction.NormalizeRetentionDays(days)
end

--- Set detail retention (0 / 30 / 60 / 90 / 180 / 365) and arm compaction.
---@param days number
function OneWoW_AltTracker_Accounting_API.SetDetailRetentionDays(days)
    local db = OneWoW_AltTracker_Accounting_DB
    if not db or not db.settings then
        return
    end
    local normalized = ns.Compaction.NormalizeRetentionDays(days)
    db.settings.detailRetentionDays = normalized
    if ns.Compaction then
        ns.Compaction:Cancel()
        ns.Compaction:Arm()
    end
end

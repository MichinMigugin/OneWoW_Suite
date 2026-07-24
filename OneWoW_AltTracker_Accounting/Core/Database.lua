local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    transactions = {},
    settings = {
        guildAsPersonal = false,
        financialsDashboard = false,
        -- UI: Financials options row (retention / guild / reset) expanded.
        financialsOptionsOpen = false,
        -- 0 = Off (no daily rollup); else 30/60/90/180/365.
        detailRetentionDays = 0,
        maxRecords = 10000,
        trimToRecords = 8000,
        resetDate = 0,
        lastMoneyByCharacter = {},
    },
    statistics = {
        totalIncome = 0,
        totalExpense = 0,
        netProfit = 0,
        lastCalculated = 0,
    },
}

-- Defaults applied by BootStore (MergeMissing) before this runs, so only the
-- char-key normalizer remains here.
function ns:InitializeDatabase()
    local rewritten = DB:ConsolidateRecordCharacterField(OneWoW_AltTracker_Accounting_DB.transactions, "character")
    if rewritten > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r canonicalized character key on " .. rewritten .. " transaction(s).")
        end)
    end
end

function ns:GetNextTransactionID()
    local maxID = 0
    for _, tx in ipairs(OneWoW_AltTracker_Accounting_DB.transactions) do
        if tx.id and tx.id > maxID then
            maxID = tx.id
        end
    end
    return maxID + 1
end

function ns:TrimTransactions()
    local db = OneWoW_AltTracker_Accounting_DB
    local maxRecords = db.settings.maxRecords
    local trimTo = db.settings.trimToRecords

    if #db.transactions > maxRecords then
        table.sort(db.transactions, function(a, b)
            return (a.timestamp or 0) > (b.timestamp or 0)
        end)

        while #db.transactions > trimTo do
            table.remove(db.transactions)
        end
    end
end

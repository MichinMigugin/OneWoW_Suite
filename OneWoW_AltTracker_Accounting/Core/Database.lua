local _, ns = ...
local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.db = DB:InitSubModule("OneWoW_AltTracker_Accounting_DB")

ns.DatabaseDefaults = {
    transactions = {},
    settings = {
        trackRepairs = true,
        trackVendor = true,
        trackMail = true,
        trackTrade = true,
        trackGuildBank = true,
        trackWarbandBank = true,
        guildAsPersonal = false,
        maxRecords = 10000,
        trimToRecords = 8000,
        resetDate = 0,
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
    local rewritten = DB:ConsolidateRecordCharacterField(ns.db.transactions, "character")
    if rewritten > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r canonicalized character key on " .. rewritten .. " transaction(s).")
        end)
    end
end

function ns:GetNextTransactionID()
    local maxID = 0
    for _, tx in ipairs(ns.db.transactions) do
        if tx.id and tx.id > maxID then
            maxID = tx.id
        end
    end
    return maxID + 1
end

function ns:TrimTransactions()
    local maxRecords = ns.db.settings.maxRecords
    local trimTo = ns.db.settings.trimToRecords

    if #ns.db.transactions > maxRecords then
        table.sort(ns.db.transactions, function(a, b)
            return (a.timestamp or 0) > (b.timestamp or 0)
        end)

        while #ns.db.transactions > trimTo do
            table.remove(ns.db.transactions)
        end
    end
end

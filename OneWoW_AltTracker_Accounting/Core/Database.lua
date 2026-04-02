local addonName, ns = ...
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:InitSubModule("OneWoW_AltTracker_Accounting_DB")

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
    version = 1,
}

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Accounting_DB.transactions then
        OneWoW_AltTracker_Accounting_DB.transactions = {}
    end

    if not OneWoW_AltTracker_Accounting_DB.settings then
        OneWoW_AltTracker_Accounting_DB.settings = ns.DatabaseDefaults.settings
    end

    if OneWoW_AltTracker_Accounting_DB.settings.guildAsPersonal == nil then
        OneWoW_AltTracker_Accounting_DB.settings.guildAsPersonal = false
    end

    if not OneWoW_AltTracker_Accounting_DB.statistics then
        OneWoW_AltTracker_Accounting_DB.statistics = ns.DatabaseDefaults.statistics
    end

    if not OneWoW_AltTracker_Accounting_DB.version then
        OneWoW_AltTracker_Accounting_DB.version = ns.DatabaseDefaults.version
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
    local maxRecords = OneWoW_AltTracker_Accounting_DB.settings.maxRecords or 10000
    local trimTo = OneWoW_AltTracker_Accounting_DB.settings.trimToRecords or 8000

    if #OneWoW_AltTracker_Accounting_DB.transactions > maxRecords then
        table.sort(OneWoW_AltTracker_Accounting_DB.transactions, function(a, b)
            return (a.timestamp or 0) > (b.timestamp or 0)
        end)

        while #OneWoW_AltTracker_Accounting_DB.transactions > trimTo do
            table.remove(OneWoW_AltTracker_Accounting_DB.transactions)
        end
    end
end

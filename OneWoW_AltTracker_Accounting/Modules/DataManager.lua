local addonName, ns = ...

ns.DataManager = {}
local DataManager = ns.DataManager

local initialized = false

function DataManager:Initialize()
    if initialized then return end
    initialized = true

    if ns.AuctionTracker then
        ns.AuctionTracker:Initialize()
    end

    if ns.TransmogTracker then
        ns.TransmogTracker:Initialize()
    end

    if ns.MiscTracker then
        ns.MiscTracker:Initialize()
    end

    if ns.VendorTracker then
        ns.VendorTracker:Initialize()
    end

    if ns.TradeTracker then
        ns.TradeTracker:Initialize()
    end

    if ns.MailSendTracker then
        ns.MailSendTracker:Initialize()
    end

    if ns.BankTracker then
        ns.BankTracker:Initialize()
    end

    if ns.NpcOrderTracker then
        ns.NpcOrderTracker:Initialize()
    end

    if ns.TrainerTracker then
        ns.TrainerTracker:Initialize()
    end

    if ns.GoldWatcher then
        ns.GoldWatcher:Initialize()
    end
end

function DataManager:RegisterEvents()
end

function ns:InvalidateStatistics()
    if not OneWoW_AltTracker_Accounting_DB or not OneWoW_AltTracker_Accounting_DB.statistics then
        return
    end

    OneWoW_AltTracker_Accounting_DB.statistics.lastCalculated = 0
end

function ns:CalculateStatistics(timeStart, timeEnd, characterFilter, categoryFilter)
    local stats = {
        income = 0,
        expense = 0,
        profit = 0,
        transactionCount = 0,
        categories = {},
    }

    if not OneWoW_AltTracker_Accounting_DB or not OneWoW_AltTracker_Accounting_DB.transactions then
        return stats
    end

    timeStart = timeStart or 0
    timeEnd = timeEnd or GetServerTime() + 86400

    for _, tx in ipairs(OneWoW_AltTracker_Accounting_DB.transactions) do
        if tx.timestamp >= timeStart and tx.timestamp <= timeEnd then
            if not characterFilter or tx.character == characterFilter then
                if not categoryFilter or tx.category == categoryFilter then
                    stats.transactionCount = stats.transactionCount + 1

                    if tx.type == "income" then
                        stats.income = stats.income + (tx.amount or 0)
                        if tx.category then
                            stats.categories[tx.category] = (stats.categories[tx.category] or 0) + (tx.amount or 0)
                        end
                    elseif tx.type == "expense" then
                        stats.expense = stats.expense + (tx.amount or 0)
                        if tx.category then
                            stats.categories[tx.category] = (stats.categories[tx.category] or 0) - (tx.amount or 0)
                        end
                    end
                end
            end
        end
    end

    stats.profit = stats.income - stats.expense

    OneWoW_AltTracker_Accounting_DB.statistics.totalIncome = stats.income
    OneWoW_AltTracker_Accounting_DB.statistics.totalExpense = stats.expense
    OneWoW_AltTracker_Accounting_DB.statistics.netProfit = stats.profit
    OneWoW_AltTracker_Accounting_DB.statistics.lastCalculated = GetServerTime()

    return stats
end

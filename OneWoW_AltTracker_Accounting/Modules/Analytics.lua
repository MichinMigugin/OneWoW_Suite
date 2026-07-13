local _, ns = ...

ns.Analytics = {}
local Analytics = ns.Analytics

local floor = math.floor
local max = math.max
local tinsert = tinsert
local sort = sort
local date = date
local time = time

local DAY = 86400

local function dayStart(ts)
    if not ts or ts <= 0 then
        ts = GetServerTime()
    end
    local d = date("*t", ts)
    if not d then
        return ts
    end
    d.hour = 0
    d.min = 0
    d.sec = 0
    return time(d) or ts
end

local function isInternalTransferCategory(category)
    return category == "warband_bank_deposit"
        or category == "warband_bank_withdraw"
        or category == "guild_bank_deposit"
        or category == "guild_bank_withdraw"
end

--- Signed wallet delta for one transaction.
---@param tx table
---@param allCharacters boolean
---@return number delta copper (0 if excluded)
local function walletDelta(tx, allCharacters)
    local amount = tx.amount or 0
    if tx.type == "income" then
        return amount
    elseif tx.type == "expense" then
        return -amount
    elseif tx.type == "transfer" then
        if allCharacters and isInternalTransferCategory(tx.category) then
            return 0
        end
        -- Single-char: deposits/out are expenses to that wallet; withdraws/in are income.
        if tx.category and (tx.category:find("deposit", 1, true) or tx.category:find("_out", 1, true)
            or tx.category == "money_transfer_out") then
            return -amount
        end
        return amount
    end
    return 0
end

local function chooseBucketSeconds(timeStart, timeEnd)
    local span = max(1, timeEnd - timeStart)
    if span <= DAY * 2 then
        return floor(span / 24) -- ~hourly for short ranges, min 1 handled below
    elseif span <= DAY * 14 then
        return DAY
    elseif span <= DAY * 90 then
        return DAY
    else
        return DAY * 7
    end
end

--- Earliest usable sample time for open-ended ranges (timeStart <= 0 / "All").
--- Avoids dayStart(0) / multi-decade bucket math that can nil out on Windows.
local function resolveSeriesStart(txs, timeStart, timeEnd)
    if timeStart and timeStart > 0 then
        return timeStart
    end
    local earliest = timeEnd
    for _, tx in ipairs(txs) do
        local ts = tx.timestamp or 0
        if ts > 0 and ts < earliest then
            earliest = ts
        end
    end
    if earliest >= timeEnd then
        return max(1, timeEnd - DAY)
    end
    return earliest
end

--- Bucket txs into flow series for sparklines.
---@param txs table
---@param timeStart number
---@param timeEnd number
---@return table { income, expense, profit, labels, bucketSeconds }
function Analytics.BuildFlowSeries(txs, timeStart, timeEnd)
    timeStart = timeStart or 0
    timeEnd = timeEnd or GetServerTime()
    if timeEnd < timeStart then
        timeEnd = timeStart
    end

    local seriesStart = resolveSeriesStart(txs, timeStart, timeEnd)
    local bucketSec = chooseBucketSeconds(seriesStart, timeEnd)
    if bucketSec < 3600 then
        bucketSec = 3600
    end

    -- Align first bucket to day start when using daily+ buckets.
    local origin = seriesStart
    if bucketSec >= DAY then
        origin = dayStart(seriesStart)
    end

    local nBuckets = max(1, floor((timeEnd - origin) / bucketSec) + 1)
    -- Cap buckets for spark readability
    if nBuckets > 48 then
        bucketSec = max(bucketSec, floor((timeEnd - origin) / 47))
        if bucketSec < 1 then
            bucketSec = 1
        end
        nBuckets = max(1, floor((timeEnd - origin) / bucketSec) + 1)
        if nBuckets > 48 then
            nBuckets = 48
        end
    end

    local income = {}
    local expense = {}
    local profit = {}
    local labels = {}
    for i = 1, nBuckets do
        income[i] = 0
        expense[i] = 0
        profit[i] = 0
        labels[i] = origin + (i - 1) * bucketSec
    end

    for _, tx in ipairs(txs) do
        local ts = tx.timestamp or 0
        if ts >= timeStart and ts <= timeEnd then
            local idx = floor((ts - origin) / bucketSec) + 1
            if idx < 1 then idx = 1 end
            if idx > nBuckets then idx = nBuckets end
            if tx.type == "income" then
                income[idx] = income[idx] + (tx.amount or 0)
            elseif tx.type == "expense" then
                expense[idx] = expense[idx] + (tx.amount or 0)
            end
        end
    end

    for i = 1, nBuckets do
        profit[i] = income[i] - expense[i]
    end

    return {
        income = income,
        expense = expense,
        profit = profit,
        labels = labels,
        bucketSeconds = bucketSec,
    }
end

--- Reconstruct ledger-implied wallet path + high/low.
---@param txs table already time/char filtered; should include income+expense (+transfers for single char)
---@param opts table endBalance, timeStart, timeEnd, characterFilter
---@return table { points, high, low, startBalance, endBalance }
function Analytics.BuildWalletSeries(txs, opts)
    opts = opts or {}
    local timeStart = opts.timeStart or 0
    local timeEnd = opts.timeEnd or GetServerTime()
    local endBalance = opts.endBalance or 0
    local allCharacters = not opts.characterFilter

    local sorted = {}
    for _, tx in ipairs(txs) do
        local ts = tx.timestamp or 0
        if ts >= timeStart and ts <= timeEnd then
            tinsert(sorted, tx)
        end
    end
    sort(sorted, function(a, b)
        return (a.timestamp or 0) < (b.timestamp or 0)
    end)

    local net = 0
    for _, tx in ipairs(sorted) do
        net = net + walletDelta(tx, allCharacters)
    end

    local startBalance = endBalance - net
    local balance = startBalance
    local high = startBalance
    local low = startBalance
    local points = { startBalance }

    -- Day-bucket balances for spark (last balance of each day)
    local seriesStart = resolveSeriesStart(sorted, timeStart, timeEnd)
    local bucketSec = DAY
    local origin = dayStart(seriesStart)
    local lastBucket = -1

    for _, tx in ipairs(sorted) do
        balance = balance + walletDelta(tx, allCharacters)
        if balance > high then high = balance end
        if balance < low then low = balance end

        local b = floor(((tx.timestamp or seriesStart) - origin) / bucketSec)
        if b ~= lastBucket then
            tinsert(points, balance)
            lastBucket = b
        else
            points[#points] = balance
        end
    end

    if points[#points] ~= endBalance then
        tinsert(points, endBalance)
    end

    return {
        points = points,
        high = high,
        low = low,
        startBalance = startBalance,
        endBalance = endBalance,
    }
end

--- Goblin summary: averages and tops.
---@param txs table
---@param timeStart number
---@param timeEnd number
---@return table
function Analytics.BuildDashboardSummary(txs, timeStart, timeEnd)
    timeStart = timeStart or 0
    timeEnd = timeEnd or GetServerTime()
    local spanDays = max(1, (timeEnd - timeStart) / DAY)

    local totalIncome, totalExpense = 0, 0
    local catIncome, catExpense = {}, {}
    local itemSold, itemBought = {}, {}

    for _, tx in ipairs(txs) do
        local ts = tx.timestamp or 0
        if ts >= timeStart and ts <= timeEnd then
            local amount = tx.amount or 0
            local cat = tx.category or "uncategorized"
            if tx.type == "income" then
                totalIncome = totalIncome + amount
                catIncome[cat] = (catIncome[cat] or 0) + amount
                local key = tx.itemName or tx.item
                if key and key ~= "" then
                    itemSold[key] = (itemSold[key] or 0) + amount
                end
            elseif tx.type == "expense" then
                totalExpense = totalExpense + amount
                catExpense[cat] = (catExpense[cat] or 0) + amount
                local key = tx.itemName or tx.item
                if key and key ~= "" then
                    itemBought[key] = (itemBought[key] or 0) + amount
                end
            end
        end
    end

    local function topEntry(map)
        local bestKey, bestAmt = nil, 0
        for k, v in pairs(map) do
            if v > bestAmt then
                bestAmt = v
                bestKey = k
            end
        end
        if not bestKey then return nil end
        return { key = bestKey, amount = bestAmt }
    end

    return {
        totalIncome = totalIncome,
        totalExpense = totalExpense,
        totalProfit = totalIncome - totalExpense,
        avgIncomePerDay = totalIncome / spanDays,
        avgExpensePerDay = totalExpense / spanDays,
        avgProfitPerDay = (totalIncome - totalExpense) / spanDays,
        spanDays = spanDays,
        topIncomeCategory = topEntry(catIncome),
        topExpenseCategory = topEntry(catExpense),
        topItemSold = topEntry(itemSold),
        topItemBought = topEntry(itemBought),
        sampleCount = #txs,
    }
end

--- Max/min of a numeric series (for flow high/low display).
---@param series number[]
---@return number|nil high
---@return number|nil low
function Analytics.SeriesRange(series)
    if not series or #series == 0 then
        return nil, nil
    end
    local hi, lo = series[1], series[1]
    for i = 2, #series do
        local v = series[i]
        if v > hi then hi = v end
        if v < lo then lo = v end
    end
    return hi, lo
end

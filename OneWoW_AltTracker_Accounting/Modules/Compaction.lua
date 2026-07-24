local _, ns = ...

-- ============================================================================
-- Compaction
-- ============================================================================
-- Opt-in ledger compaction: when detailRetentionDays > 0, detail rows older
-- than the cutoff are merged into daily rollup rows (character + day + type +
-- category). Runs via OneWoW.ChunkedJob during the session — never on logout.
--
-- Rollup inserts mutate db.transactions directly (no RecordIncome claims).
-- ============================================================================

ns.Compaction = {}
local Compaction = ns.Compaction

local date = date
local time = time
local tinsert = tinsert
local wipe = wipe

local DAY = 86400
local ALLOWED_DAYS = {
    [0] = true,
    [30] = true,
    [60] = true,
    [90] = true,
    [180] = true,
    [365] = true,
}

local ROLLUP_SOURCE = "Daily Rollup"
local OWNER_ID = "OneWoW_AltTracker_Accounting.Compaction"

local activeJob = nil
local armPending = false

---@param ts number|nil
---@return number
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

---@param days number|nil
---@return number
function Compaction.NormalizeRetentionDays(days)
    local n = tonumber(days) or 0
    if ALLOWED_DAYS[n] then
        return n
    end
    return 0
end

---@return number
local function getRetentionDays()
    local db = OneWoW_AltTracker_Accounting_DB
    if not db or not db.settings then
        return 0
    end
    return Compaction.NormalizeRetentionDays(db.settings.detailRetentionDays)
end

---@param retentionDays number
---@return number|nil cutoff epoch; nil when Off
local function getCutoff(retentionDays)
    if retentionDays <= 0 then
        return nil
    end
    return dayStart(GetServerTime()) - retentionDays * DAY
end

---@param tx table
---@param cutoff number
---@return boolean
local function isRollCandidate(tx, cutoff)
    if tx.isRollup then
        return false
    end
    local ts = tx.timestamp or 0
    return ts > 0 and ts < cutoff
end

--- Group key for a roll candidate.
---@param tx table
---@return string
---@return number dayTs
local function groupKey(tx)
    local dayTs = dayStart(tx.timestamp)
    local char = tx.character or ""
    local txType = tx.type or "income"
    local category = tx.category or "uncategorized"
    return char .. "\0" .. tostring(dayTs) .. "\0" .. txType .. "\0" .. category, dayTs
end

---@return boolean
function Compaction:NeedsWork()
    local retention = getRetentionDays()
    local cutoff = getCutoff(retention)
    if not cutoff then
        return false
    end
    local db = OneWoW_AltTracker_Accounting_DB
    if not db or not db.transactions then
        return false
    end
    for i = 1, #db.transactions do
        if isRollCandidate(db.transactions[i], cutoff) then
            return true
        end
    end
    return false
end

function Compaction:Cancel()
    armPending = false
    OneWoW.Restriction.CancelWhenUnrestricted(OWNER_ID)
    if activeJob then
        activeJob:Cancel()
        activeJob = nil
    end
end

local function notifyLedgerChanged()
    ns:InvalidateStatistics()
    if ns.onNewTransaction then
        ns.onNewTransaction()
    end
end

local function startJob()
    if activeJob and activeJob:IsActive() then
        return
    end
    activeJob = nil
    armPending = false

    local retention = getRetentionDays()
    local cutoff = getCutoff(retention)
    if not cutoff then
        return
    end
    if not Compaction:NeedsWork() then
        return
    end

    local db = OneWoW_AltTracker_Accounting_DB
    if not db or not db.transactions then
        return
    end

    activeJob = OneWoW.ChunkedJob.Start({
        budgetMs = 8,
        run = function(shouldYield)
            local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
            local txs = db.transactions
            local keep = {}
            local groups = {}
            local groupOrder = {}

            for i = 1, #txs do
                local tx = txs[i]
                if isRollCandidate(tx, cutoff) then
                    local key = groupKey(tx)
                    local g = groups[key]
                    if not g then
                        g = {
                            character = tx.character,
                            type = tx.type,
                            category = tx.category,
                            amount = 0,
                            rolledCount = 0,
                            timestamp = tx.timestamp or cutoff,
                        }
                        groups[key] = g
                        tinsert(groupOrder, key)
                    end
                    g.amount = g.amount + (tx.amount or 0)
                    g.rolledCount = g.rolledCount + 1
                    local ts = tx.timestamp or 0
                    if ts > 0 and ts < g.timestamp then
                        g.timestamp = ts
                    end
                else
                    tinsert(keep, tx)
                end
                YieldIfNeeded(shouldYield)
            end

            if #groupOrder == 0 then
                return
            end

            local maxID = 0
            for i = 1, #keep do
                local id = keep[i].id
                if id and id > maxID then
                    maxID = id
                end
                YieldIfNeeded(shouldYield)
            end

            local rollups = {}
            for i = 1, #groupOrder do
                local g = groups[groupOrder[i]]
                maxID = maxID + 1
                tinsert(rollups, {
                    id = maxID,
                    isRollup = true,
                    rolledCount = g.rolledCount,
                    timestamp = g.timestamp,
                    character = g.character,
                    type = g.type,
                    category = g.category,
                    amount = g.amount,
                    source = ROLLUP_SOURCE,
                    itemName = ROLLUP_SOURCE,
                })
                YieldIfNeeded(shouldYield)
            end

            OneWoW.ChunkedJob.Sort(rollups, function(a, b)
                return (a.timestamp or 0) > (b.timestamp or 0)
            end, shouldYield)

            -- Newest-first ledger: merge keep + rollups by timestamp desc.
            local rebuilt = {}
            local ki, ri = 1, 1
            while ki <= #keep or ri <= #rollups do
                local kTx = keep[ki]
                local rTx = rollups[ri]
                if kTx and (not rTx or (kTx.timestamp or 0) >= (rTx.timestamp or 0)) then
                    tinsert(rebuilt, kTx)
                    ki = ki + 1
                else
                    tinsert(rebuilt, rTx)
                    ri = ri + 1
                end
                YieldIfNeeded(shouldYield)
            end

            wipe(txs)
            for i = 1, #rebuilt do
                txs[i] = rebuilt[i]
                YieldIfNeeded(shouldYield)
            end
        end,
        onComplete = function()
            activeJob = nil
            notifyLedgerChanged()
            -- Another pass if retention still has work (or setting changed mid-job).
            Compaction:Arm()
        end,
        onCancel = function()
            activeJob = nil
        end,
    })
end

function Compaction:Arm()
    local retention = getRetentionDays()
    if retention <= 0 then
        self:Cancel()
        return
    end

    if activeJob and activeJob:IsActive() then
        return
    end

    if not self:NeedsWork() then
        return
    end

    if OneWoW.Restriction.IsInCombat() then
        if armPending then
            return
        end
        armPending = true
        OneWoW.Restriction.RunWhenUnrestricted("lockdown", OWNER_ID, function()
            armPending = false
            startJob()
        end)
        return
    end

    startJob()
end

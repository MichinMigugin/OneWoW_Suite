local _, ns = ...

-- ============================================================================
-- GuildBankTransfer
-- ============================================================================
-- Bag → guild-bank deposit planner + paced execute queue. Sibling to
-- Inventory (events / IsGuildBankOpen); does not own GUILDBANK* registration.
-- Consumers supply policy (which bag slots); this service plans partial-stack
-- fills vs fallback UseContainerItem and runs one global queue.
--
-- Live guild APIs only — no Storage SV, no Bags private cache poking.
-- RegisterPlaceCallback notifies Bags (Phase 2) before PickupGuildBankItem.
-- ============================================================================

local GuildBankTransfer = {}
ns.GuildBankTransfer = GuildBankTransfer

local Inventory = ns.Inventory
local Restriction = ns.Restriction

local C_Timer = C_Timer
local C_Container = C_Container
local C_Item = C_Item
local ipairs, pairs, type, tonumber = ipairs, pairs, type, tonumber
local min = math.min
local tinsert = tinsert
local GetCursorInfo = GetCursorInfo
local GetNumGuildBankTabs = GetNumGuildBankTabs
local GetGuildBankTabInfo = GetGuildBankTabInfo
local GetGuildBankItemInfo = GetGuildBankItemInfo
local GetGuildBankItemLink = GetGuildBankItemLink
local QueryGuildBankTab = QueryGuildBankTab
local PickupGuildBankItem = PickupGuildBankItem
local GetCurrentGuildBankTab = GetCurrentGuildBankTab
local SetCurrentGuildBankTab = SetCurrentGuildBankTab
local ItemLocation = ItemLocation

local GUILD_BANK_SLOTS_PER_TAB = 98
local DEFAULT_INTERVAL = 0.6
local TAB_QUERY_SETTLE = 0.6

local placeCallbacks = {}

local busy = false
local busyOwnerID = nil
local queueTicker = nil
local queryTimer = nil

local function FirePlaceCallbacks(tabID, slotID, kind)
    for ownerID, fn in pairs(placeCallbacks) do
        ns.Lifecycle.SafeCall("GuildBankTransfer.place:" .. ownerID, fn, tabID, slotID, kind)
    end
end

local function ClearQueue()
    if queueTicker then
        queueTicker:Cancel()
        queueTicker = nil
    end
    busy = false
    busyOwnerID = nil
end

local function GetItemMaxStack(itemID)
    local maxStack = select(8, C_Item.GetItemInfo(itemID))
    if type(maxStack) == "number" and maxStack >= 1 then
        return maxStack
    end
    -- Uncached: treat as stackable so partials are still indexed; ExecuteOp
    -- re-checks live capacity. Default 1 would skip every real partial stack.
    C_Item.RequestLoadItemDataByID(itemID)
    return 9999
end

local function GetGuildBankSlotItemID(tabID, slotID)
    local itemLink = GetGuildBankItemLink(tabID, slotID)
    if not itemLink then return nil end
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID then
        itemID = tonumber(itemLink:match("item:(%d+)"))
    end
    return itemID
end

local function CanDepositOnTab(tabID)
    local _, _, isViewable, canDeposit = GetGuildBankTabInfo(tabID)
    return isViewable ~= false and canDeposit ~= false
end

--- Build itemID → partial stacks with free space (live guild bank only).
local function BuildPartialStackIndex(wantedItemIDs)
    local index = {}
    local numTabs = GetNumGuildBankTabs() or 0

    for tabID = 1, numTabs do
        if CanDepositOnTab(tabID) then
            for slotID = 1, GUILD_BANK_SLOTS_PER_TAB do
                local texture, itemCount, locked = GetGuildBankItemInfo(tabID, slotID)
                if texture and itemCount and itemCount > 0 and not locked then
                    local itemID = GetGuildBankSlotItemID(tabID, slotID)
                    if itemID and (not wantedItemIDs or wantedItemIDs[itemID]) then
                        local maxStack = GetItemMaxStack(itemID)
                        if itemCount < maxStack then
                            if not index[itemID] then
                                index[itemID] = {}
                            end
                            tinsert(index[itemID], {
                                tabID = tabID,
                                slotID = slotID,
                                count = itemCount,
                                maxStack = maxStack,
                            })
                        end
                    end
                end
            end
        end
    end

    return index
end

local function ReserveStackTargets(index, itemID, count)
    local targets = {}
    local stacks = index and index[itemID]
    local remaining = count or 0

    if not stacks or remaining <= 0 then
        return targets, remaining
    end

    for _, stack in ipairs(stacks) do
        local free = (stack.maxStack or 1) - (stack.count or 0)
        if free > 0 then
            local moveCount = min(remaining, free)
            tinsert(targets, {
                tabID = stack.tabID,
                slotID = stack.slotID,
                count = moveCount,
            })
            stack.count = stack.count + moveCount
            remaining = remaining - moveCount
            if remaining <= 0 then
                break
            end
        end
    end

    return targets, remaining
end

--- Collect depositable empty slots (tab/slot order) for overflow after partial fills.
local function BuildEmptySlotList()
    local empties = {}
    local numTabs = GetNumGuildBankTabs() or 0
    for tabID = 1, numTabs do
        if CanDepositOnTab(tabID) then
            for slotID = 1, GUILD_BANK_SLOTS_PER_TAB do
                local texture = GetGuildBankItemInfo(tabID, slotID)
                if not texture then
                    tinsert(empties, { tabID = tabID, slotID = slotID })
                end
            end
        end
    end
    return empties
end

--- Reserve empty slots for remaining count (one op per empty, up to maxStack each).
local function ReserveEmptyTargets(empties, emptyIndex, itemID, count)
    local targets = {}
    local remaining = count or 0
    if remaining <= 0 or not empties then
        return targets, remaining
    end

    local maxStack = GetItemMaxStack(itemID)
    while remaining > 0 and emptyIndex[1] <= #empties do
        local slot = empties[emptyIndex[1]]
        emptyIndex[1] = emptyIndex[1] + 1
        local moveCount = min(remaining, maxStack)
        tinsert(targets, {
            tabID = slot.tabID,
            slotID = slot.slotID,
            count = moveCount,
        })
        remaining = remaining - moveCount
    end

    return targets, remaining
end

local function EnsureGuildTab(tabID)
    if tabID and tabID ~= GetCurrentGuildBankTab() then
        SetCurrentGuildBankTab(tabID)
    end
end

local function PickupBagStackAmount(bagID, slotID, amount, stackCount)
    if amount and stackCount and amount < stackCount then
        C_Container.SplitContainerItem(bagID, slotID, amount)
    else
        C_Container.PickupContainerItem(bagID, slotID)
    end
end

local function CanDepositBagSlot(bagID, slotID, expectedItemID)
    if not Inventory.IsGuildBankOpen() then
        return false
    end
    if Restriction.IsProtectedActionBlocked() then
        return false
    end
    if GetCursorInfo() then
        return false
    end

    local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    if not itemInfo or itemInfo.itemID ~= expectedItemID or itemInfo.isLocked then
        return false
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if not itemLocation or not itemLocation:IsValid() then
        return false
    end

    local ok, bindType = pcall(C_Item.GetItemBindType, itemLocation)
    if ok and (bindType == Enum.ItemBind.OnAcquire or bindType == Enum.ItemBind.Quest) then
        return false
    end

    return true, itemInfo
end

local function ExecuteOp(op)
    if not op or not Inventory.IsGuildBankOpen() then
        return 0
    end
    if Restriction.IsProtectedActionBlocked() then
        return 0
    end

    local ok, itemInfo = CanDepositBagSlot(op.bagID, op.slotID, op.itemID)
    if not ok then
        return 0
    end

    local stackCount = itemInfo.stackCount or 1

    if op.kind == "stack" then
        local texture, targetCount, locked = GetGuildBankItemInfo(op.targetTabID, op.targetSlotID)
        if not texture or locked then
            return 0
        end
        local targetItemID = GetGuildBankSlotItemID(op.targetTabID, op.targetSlotID)
        if targetItemID ~= op.itemID then
            return 0
        end

        local capacity = GetItemMaxStack(op.itemID) - (targetCount or 0)
        local moveCount = min(op.count or stackCount, stackCount, capacity)
        if moveCount <= 0 then
            return 0
        end

        PickupBagStackAmount(op.bagID, op.slotID, moveCount, stackCount)
        if GetCursorInfo() ~= "item" then
            return 0
        end

        FirePlaceCallbacks(op.targetTabID, op.targetSlotID, "stack")
        EnsureGuildTab(op.targetTabID)
        PickupGuildBankItem(op.targetTabID, op.targetSlotID)
        return moveCount
    end

    if op.kind == "empty" then
        local texture, _, locked = GetGuildBankItemInfo(op.targetTabID, op.targetSlotID)
        if texture or locked then
            return 0
        end

        local moveCount = min(op.count or stackCount, stackCount)
        if moveCount <= 0 then
            return 0
        end

        PickupBagStackAmount(op.bagID, op.slotID, moveCount, stackCount)
        if GetCursorInfo() ~= "item" then
            return 0
        end

        FirePlaceCallbacks(op.targetTabID, op.targetSlotID, "empty")
        EnsureGuildTab(op.targetTabID)
        PickupGuildBankItem(op.targetTabID, op.targetSlotID)
        return moveCount
    end

    -- Last-resort fallback when no empty slots were available at plan time.
    C_Container.UseContainerItem(op.bagID, op.slotID)
    return stackCount
end

--- Plan bag→guild deposit ops (partial-stack fills, then fallback for leftovers).
---@param slots table[] { bagID, slotID, itemID, itemName? }
---@return table[] ops
function GuildBankTransfer.PlanDeposits(slots)
    local ops = {}
    if type(slots) ~= "table" or #slots == 0 then
        return ops
    end

    local wantedItemIDs = {}
    for _, slotInfo in ipairs(slots) do
        if slotInfo.itemID then
            wantedItemIDs[slotInfo.itemID] = true
        end
    end

    local index = BuildPartialStackIndex(wantedItemIDs)
    local empties = BuildEmptySlotList()
    local emptyIndex = { 1 }

    for _, slotInfo in ipairs(slots) do
        local itemInfo = C_Container.GetContainerItemInfo(slotInfo.bagID, slotInfo.slotID)
        local stackCount = itemInfo and itemInfo.stackCount or 1
        local targets, remaining = ReserveStackTargets(index, slotInfo.itemID, stackCount)

        for _, target in ipairs(targets) do
            tinsert(ops, {
                kind = "stack",
                bagID = slotInfo.bagID,
                slotID = slotInfo.slotID,
                itemID = slotInfo.itemID,
                itemName = slotInfo.itemName,
                count = target.count,
                targetTabID = target.tabID,
                targetSlotID = target.slotID,
            })
        end

        if remaining and remaining > 0 then
            local emptyTargets
            emptyTargets, remaining = ReserveEmptyTargets(empties, emptyIndex, slotInfo.itemID, remaining)
            for _, target in ipairs(emptyTargets) do
                tinsert(ops, {
                    kind = "empty",
                    bagID = slotInfo.bagID,
                    slotID = slotInfo.slotID,
                    itemID = slotInfo.itemID,
                    itemName = slotInfo.itemName,
                    count = target.count,
                    targetTabID = target.tabID,
                    targetSlotID = target.slotID,
                })
            end
        end

        if remaining and remaining > 0 then
            tinsert(ops, {
                kind = "fallback",
                bagID = slotInfo.bagID,
                slotID = slotInfo.slotID,
                itemID = slotInfo.itemID,
                itemName = slotInfo.itemName,
                count = remaining,
            })
        end
    end

    return ops
end

--- Query viewable depositable tabs (all, when no warm planner source), then invoke onReady.
---@param wantedItemIDs table|nil itemID -> true (reserved for selective query later)
---@param onReady function
function GuildBankTransfer.EnsureTabsQueried(wantedItemIDs, onReady)
    if type(onReady) ~= "function" then
        error("OneWoW.GuildBankTransfer.EnsureTabsQueried: onReady function required", 2)
    end

    if queryTimer then
        queryTimer:Cancel()
        queryTimer = nil
    end

    local numTabs = GetNumGuildBankTabs() or 0
    for tabID = 1, numTabs do
        if CanDepositOnTab(tabID) then
            QueryGuildBankTab(tabID)
        end
    end

    -- wantedItemIDs reserved for selective warm-tab query in a later pass
    local _ = wantedItemIDs

    queryTimer = C_Timer.NewTimer(TAB_QUERY_SETTLE, function()
        queryTimer = nil
        onReady()
    end)
end

--- Enqueue planned ops. Rejects if busy under a different ownerID; same owner Cancel+replace.
---@param ops table[]
---@param opts table|nil { ownerID?, intervalSec?, onProgress?, onOpComplete?, onComplete? }
---@return boolean started
function GuildBankTransfer.Enqueue(ops, opts)
    opts = opts or {}
    local ownerID = opts.ownerID or "anonymous"

    if busy then
        if busyOwnerID == ownerID then
            GuildBankTransfer.Cancel(ownerID)
        else
            return false
        end
    end

    if type(ops) ~= "table" or #ops == 0 then
        return false
    end
    if not Inventory.IsGuildBankOpen() then
        return false
    end

    busy = true
    busyOwnerID = ownerID

    local interval = opts.intervalSec or DEFAULT_INTERVAL
    if type(interval) ~= "number" or interval <= 0 then
        interval = DEFAULT_INTERVAL
    end

    local index = 1
    local total = #ops

    queueTicker = C_Timer.NewTicker(interval, function()
        local op = ops[index]
        if not op then
            ClearQueue()
            if opts.onComplete then
                ns.Lifecycle.SafeCall("GuildBankTransfer.onComplete:" .. ownerID, opts.onComplete)
            end
            return
        end

        if not Inventory.IsGuildBankOpen() then
            ClearQueue()
            if opts.onComplete then
                ns.Lifecycle.SafeCall("GuildBankTransfer.onComplete:" .. ownerID, opts.onComplete)
            end
            return
        end
        if Restriction.IsProtectedActionBlocked() then
            -- Skip this tick; leave op for a later tick when restrictions clear.
            return
        end

        if opts.onProgress then
            ns.Lifecycle.SafeCall("GuildBankTransfer.onProgress:" .. ownerID, opts.onProgress, index, total, op)
        end

        local moved = ExecuteOp(op)
        if opts.onOpComplete then
            ns.Lifecycle.SafeCall("GuildBankTransfer.onOpComplete:" .. ownerID, opts.onOpComplete, op, moved)
        end

        index = index + 1
        if index > total then
            ClearQueue()
            if opts.onComplete then
                ns.Lifecycle.SafeCall("GuildBankTransfer.onComplete:" .. ownerID, opts.onComplete)
            end
        end
    end)
    return true
end

--- Cancel the active queue. If ownerID is set, only cancels when it matches.
---@param ownerID string|nil
---@return boolean cancelled
function GuildBankTransfer.Cancel(ownerID)
    if not busy then
        return false
    end
    if ownerID and busyOwnerID and ownerID ~= busyOwnerID then
        return false
    end
    ClearQueue()
    return true
end

function GuildBankTransfer.IsBusy()
    return busy
end

--- Subscribe before each targeted guild place (PickupGuildBankItem).
---@param ownerID string
---@param fn function fn(tabID, slotID, kind)
function GuildBankTransfer.RegisterPlaceCallback(ownerID, fn)
    if type(ownerID) ~= "string" or type(fn) ~= "function" then
        error("OneWoW.GuildBankTransfer.RegisterPlaceCallback: (ownerID string, fn function) required", 2)
    end
    placeCallbacks[ownerID] = fn
end

function GuildBankTransfer.UnregisterCallback(ownerID)
    if type(ownerID) ~= "string" then return end
    placeCallbacks[ownerID] = nil
    if busyOwnerID == ownerID then
        GuildBankTransfer.Cancel(ownerID)
    end
end

local _, ns = ...

ns.Collect = {}
local Collect = ns.Collect

local running = false
local cancelRequested = false

--- Two free-slot budgets: generic slots (bagFamily 0 — hold anything) and
--- generic + reagent bag (crafting reagents can land in either). Specialty
--- bags with a non-zero family are excluded from both; they can't take
--- arbitrary mail attachments.
---@return number freeGeneric
---@return number freeReagentCapable
local function FreeSlotBudgets()
    local generic = 0
    for bag = 0, NUM_BAG_SLOTS do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if (family or 0) == 0 then
            generic = generic + (free or 0)
        end
    end
    local reagent = 0
    if Enum.BagIndex and Enum.BagIndex.ReagentBag then
        reagent = C_Container.GetContainerNumFreeSlots(Enum.BagIndex.ReagentBag) or 0
    end
    return generic, generic + reagent
end

--- Uncached items (nil GetItemInfo) count as non-reagent: demanding a generic
--- slot they might not need errs toward stopping early, never overflowing.
--- (select(17) because C_Item.IsItemCraftingReagentByID does not exist in 12.x.)
---@param itemID number
---@return boolean
local function IsCraftingReagentItem(itemID)
    return select(17, C_Item.GetItemInfo(itemID)) == true
end

local function KeepFree()
    return (ns.db and ns.db.global.mail.keepFreeSlots) or ns.Constants.DEFAULT_KEEP_FREE
end

local function WaitPending(done)
    local deadline = GetTime() + 10
    local function tick()
        if cancelRequested then
            done(false)
            return
        end
        if C_Mail.IsCommandPending() then
            if GetTime() > deadline then
                done(false)
                return
            end
            C_Timer.After(ns.Constants.COLLECT_POLL, tick)
            return
        end
        C_Timer.After(ns.Constants.COLLECT_SETTLE, function()
            done(true)
        end)
    end
    tick()
end

local function TakeOneMail(index, filter, after)
    local _, _, _, _, money, CODAmount, _, hasItem, _, _, _, _, isGM = GetInboxHeaderInfo(index)
    if isGM or (CODAmount or 0) > 0 then
        after(true)
        return
    end

    -- Slot check against this mail's actual attachments: non-reagents need
    -- generic slots, reagents may also use the reagent bag. Heuristic — one
    -- slot per attachment, ignoring merges into existing partial stacks — so
    -- it errs toward stopping early, never toward overflowing.
    if hasItem then
        local needGeneric, needTotal = 0, 0
        for i = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
            local _, itemID, _, _, _, _, isCurrency = GetInboxItem(index, i)
            -- Currency attachments go to the currency tab, not bags.
            if itemID and not isCurrency then
                needTotal = needTotal + 1
                if not IsCraftingReagentItem(itemID) then
                    needGeneric = needGeneric + 1
                end
            end
        end
        local keepFree = KeepFree()
        local freeGeneric, freeReagentCapable = FreeSlotBudgets()
        if freeGeneric - keepFree < needGeneric or freeReagentCapable - keepFree < needTotal then
            after(false) -- stop: need free slots
            return
        end
    end

    local wantGold = filter == "all" or filter == "gold" or filter == "sold" or filter == "bought"
        or filter == "canceled" or filter == "expired" or filter == "other" or filter == "selected"
    local wantItems = filter ~= "gold"

    -- Mark read so minimap clears.
    GetInboxText(index)

    local function takeItemsThen(done)
        if not wantItems or not hasItem then
            done()
            return
        end
        local attach = ATTACHMENTS_MAX_RECEIVE or 16
        local function nextAttach(i)
            if i < 1 then
                done()
                return
            end
            if GetInboxItemLink(index, i) then
                TakeInboxItem(index, i)
                WaitPending(function()
                    nextAttach(i - 1)
                end)
            else
                nextAttach(i - 1)
            end
        end
        nextAttach(attach)
    end

    if wantGold and (money or 0) > 0 then
        if ns.InTransit then
            ns.InTransit:OnMailTaken(index)
        end
        TakeInboxMoney(index)
        WaitPending(function(ok)
            if not ok then
                after(false)
                return
            end
            if ns.OtherUI then
                ns.OtherUI:AddRake(money)
            end
            takeItemsThen(function()
                after(true)
            end)
        end)
    else
        if ns.InTransit then
            ns.InTransit:OnMailTaken(index)
        end
        takeItemsThen(function()
            after(true)
        end)
    end
end

--- Start a filtered collect pass.
---@param filter string
---@param selected table|nil
---@param onDone fun(ok: boolean)|nil
function Collect:Start(filter, selected, onDone)
    -- Never overlap with an active send: both pipelines move bag items and
    -- fight over item locks (see Engine/AutoRun.lua for the other direction).
    if running or ns.SendQueue:IsRunning() then
        return
    end
    running = true
    cancelRequested = false
    if ns.Inbox and ns.Inbox.SyncActionButtons then
        ns.Inbox:SyncActionButtons()
    end

    local function finish(ok)
        running = false
        if onDone then
            onDone(ok)
        end
        if ns.Inbox and ns.Inbox.SyncActionButtons then
            ns.Inbox:SyncActionButtons()
        end
        if ns.Shell and ns.Shell.RefreshInbox then
            ns.Shell:RefreshInbox()
        end
    end

    local function step()
        if cancelRequested then
            finish(false)
            return
        end

        local num = GetInboxNumItems()
        if num == 0 then
            -- Try refresh past 100.
            if C_Mail.CanCheckInbox and C_Mail.CanCheckInbox() then
                CheckInbox()
                C_Timer.After(1.0, function()
                    if GetInboxNumItems() == 0 then
                        finish(true)
                    else
                        step()
                    end
                end)
                return
            end
            finish(true)
            return
        end

        -- Process high → low so indices stay stable as mails disappear.
        local target
        for i = num, 1, -1 do
            if ns.MailClassify:MatchesFilter(i, filter, selected) then
                local _, _, _, _, _, CODAmount, _, _, _, _, _, _, isGM = GetInboxHeaderInfo(i)
                if not isGM and (CODAmount or 0) == 0 then
                    target = i
                    break
                end
            end
        end

        if not target then
            finish(true)
            return
        end

        TakeOneMail(target, filter, function(ok)
            if not ok then
                finish(false)
                return
            end
            C_Timer.After(ns.Constants.COLLECT_SETTLE, step)
        end)
    end

    step()
end

function Collect:Cancel()
    cancelRequested = true
end

function Collect:IsRunning()
    return running
end

--- Return selected empty non-COD mails.
---@param selected table
---@param onDone fun()|nil
function Collect:ReturnSelected(selected, onDone)
    local indices = {}
    for index, on in pairs(selected or {}) do
        if on then
            tinsert(indices, index)
        end
    end
    sort(indices, function(a, b) return a > b end)

    local i = 1
    local function next()
        if i > #indices then
            if onDone then onDone() end
            if ns.Shell and ns.Shell.RefreshInbox then ns.Shell:RefreshInbox() end
            return
        end
        local index = indices[i]
        i = i + 1
        local _, _, _, _, _, CODAmount, _, _, _, wasReturned, _, canReply = GetInboxHeaderInfo(index)
        if (CODAmount or 0) == 0 and canReply and not wasReturned then
            ReturnInboxItem(index)
            WaitPending(function()
                C_Timer.After(ns.Constants.COLLECT_SETTLE, next)
            end)
        else
            next()
        end
    end
    next()
end

--- Delete selected empty non-COD mails.
---@param selected table
---@param onDone fun()|nil
function Collect:DeleteSelected(selected, onDone)
    local indices = {}
    for index, on in pairs(selected or {}) do
        if on then
            tinsert(indices, index)
        end
    end
    sort(indices, function(a, b) return a > b end)

    local i = 1
    local function next()
        if i > #indices then
            if onDone then onDone() end
            if ns.Shell and ns.Shell.RefreshInbox then ns.Shell:RefreshInbox() end
            return
        end
        local index = indices[i]
        i = i + 1
        local _, _, _, _, money, CODAmount, _, hasItem = GetInboxHeaderInfo(index)
        if (CODAmount or 0) == 0 and (money or 0) == 0 and not hasItem then
            DeleteInboxItem(index)
            WaitPending(function()
                C_Timer.After(ns.Constants.COLLECT_SETTLE, next)
            end)
        else
            next()
        end
    end
    next()
end

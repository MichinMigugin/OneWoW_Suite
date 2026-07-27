local _, ns = ...

ns.Collect = {}
local Collect = ns.Collect

local running = false
local cancelRequested = false

local MT = ns.MailTrace
local function Trace(event, fields)
    if MT.enabled then
        MT:Record("collect", event, fields)
    end
end

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

---@param index number
---@return number
local function CountAttachments(index)
    local n = 0
    local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
    for i = 1, maxAttach do
        if HasInboxItem(index, i) then
            n = n + 1
        end
    end
    return n
end

--- Delete the mail when it has no money and no attachments left.
---@param index number
---@param done fun(ok: boolean)
local function DeleteIfEmpty(index, done)
    local _, _, _, _, money = GetInboxHeaderInfo(index)
    if (money or 0) > 0 or CountAttachments(index) > 0 then
        done(true)
        return
    end
    DeleteInboxItem(index)
    WaitPending(done)
end

--- Take gold and/or attachments from one mail per filter rules.
--- Callback: true = continue (optional loot snapshot), false = abort run,
--- "skip" = ignore this index for the rest of the run.
---@param index number
---@param filter string
---@param after fun(result: boolean|string, loot?: { sender: string|nil, subject: string|nil, gold: number, items: { link: string, count: number }[] })
local function TakeOneMail(index, filter, after)
    local _, _, sender, subject, money, CODAmount, _, hasItem, _, _, _, _, isGM = GetInboxHeaderInfo(index)
    if isGM or (CODAmount or 0) > 0 then
        after("skip")
        return
    end

    -- Gold / Items are exclusive takes; "all" (and AH/selected) take both.
    local wantGold = filter == "all" or filter == "gold"
        or filter == "sold" or filter == "bought" or filter == "canceled"
        or filter == "expired" or filter == "other" or filter == "selected"
    local wantItems = filter ~= "gold"

    money = money or 0
    local attachCount = CountAttachments(index)
    -- Header hasItem can lag behind real attachments (empty shell after loot).
    local canTakeGold = wantGold and money > 0
    local canTakeItems = wantItems and attachCount > 0
    if not canTakeGold and not canTakeItems then
        -- Stale item mail or nothing this filter wants — don't spin on it.
        if (money == 0 and attachCount == 0) or (hasItem and attachCount == 0) then
            -- Empty suite shells still need in-transit cleared (subject may be
            -- gone after DeleteInboxItem, so clear before delete).
            if ns.InTransit then
                ns.InTransit:ClearMatching(nil, subject)
            end
            DeleteIfEmpty(index, function(ok)
                after(ok and "skip" or false)
            end)
            return
        end
        after("skip")
        return
    end

    -- Slot check against this mail's actual attachments: non-reagents need
    -- generic slots, reagents may also use the reagent bag. Heuristic — one
    -- slot per attachment, ignoring merges into existing partial stacks — so
    -- it errs toward stopping early, never toward overflowing.
    if canTakeItems then
        local needGeneric, needTotal = 0, 0
        local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
        for i = 1, maxAttach do
            local _, itemID, _, _, _, _, isCurrency = GetInboxItem(index, i)
            -- Currency attachments go to the currency tab, not bags.
            if itemID and not isCurrency then
                needTotal = needTotal + 1
                if not IsCraftingReagentItem(itemID) then
                    needGeneric = needGeneric + 1
                end
            end
        end
        -- Attachments present but itemIDs not cached yet: demand one generic
        -- slot each so we still gate on keep-free.
        if needTotal == 0 then
            needTotal = attachCount
            needGeneric = attachCount
        end
        local keepFree = KeepFree()
        local freeGeneric, freeReagentCapable = FreeSlotBudgets()
        if freeGeneric - keepFree < needGeneric or freeReagentCapable - keepFree < needTotal then
            after(false) -- stop: need free slots
            return
        end
    end

    -- Snapshot before take — inbox index is unreliable after loot/delete.
    local lootGold = canTakeGold and money or 0
    local lootItems = {}
    if canTakeItems then
        local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
        for i = 1, maxAttach do
            if HasInboxItem(index, i) then
                local _, itemID, _, count, _, _, isCurrency = GetInboxItem(index, i)
                if itemID and not isCurrency then
                    tinsert(lootItems, {
                        link = GetInboxItemLink(index, i) or ("item:" .. itemID),
                        count = count or 1,
                    })
                end
            end
        end
    end
    local loot = {
        sender = sender,
        subject = subject,
        gold = lootGold,
        items = lootItems,
    }

    -- Mark read so minimap clears; also creates body text so empty mail can delete.
    GetInboxText(index)

    local function takeItemsThen(done)
        if not canTakeItems then
            done(true)
            return
        end
        local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
        local function nextAttach(i)
            if i < 1 then
                done(true)
                return
            end
            if HasInboxItem(index, i) then
                Trace("take_item", { index = index, attach = i })
                TakeInboxItem(index, i)
                WaitPending(function(ok)
                    if not ok then
                        done(false)
                        return
                    end
                    nextAttach(i - 1)
                end)
            else
                nextAttach(i - 1)
            end
        end
        nextAttach(maxAttach)
    end

    local function finishMail(ok)
        if not ok then
            after(false)
            return
        end
        -- Subject must be captured before take: after loot/delete the inbox
        -- index is often gone or points at a different mail.
        if ns.InTransit then
            ns.InTransit:ClearMatching(nil, subject)
        end
        DeleteIfEmpty(index, function(deletedOk)
            if deletedOk then
                after(true, loot)
            else
                after(false)
            end
        end)
    end

    -- Money first (Blizzard OpenAll order), then attachments, then delete if empty.
    if canTakeGold then
        Trace("take_money", { index = index })
        TakeInboxMoney(index)
        WaitPending(function(ok)
            if not ok then
                after(false)
                return
            end
            takeItemsThen(finishMail)
        end)
    else
        takeItemsThen(finishMail)
    end
end

-- Inbox headers can arrive after MAIL_SHOW; auto-collect and Open All both
-- need a short grace period before treating "nothing left" as done.
local INBOX_EMPTY_RETRIES = 4
local INBOX_EMPTY_GAP = 0.4

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
    Trace("start", { filter = filter })
    if ns.Inbox and ns.Inbox.SyncActionButtons then
        ns.Inbox:SyncActionButtons()
    end

    local emptyRetriesLeft = INBOX_EMPTY_RETRIES
    local skipped = {} -- [index] = true — no-progress / empty shells this run
    local passGold, passItems, passMails = 0, 0, 0

    local function finish(ok)
        running = false
        Trace("done", {
            ok = ok,
            gold = passGold,
            items = passItems,
            mails = passMails,
        })
        if ok and ns.InTransit then
            ns.InTransit:ClearAllIfInboxEmpty()
        end
        if passMails > 0 then
            local moneyStr = passGold > 0 and OneWoW.Format.FormatGold(passGold) or OneWoW.Format.FormatGold(0)
            ns.RunLog:Add("info", nil, nil, string.format(
                ns.L["LOG_COLLECT_SUMMARY"],
                moneyStr,
                passItems,
                passMails
            ))
        end
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
                        if emptyRetriesLeft > 0 then
                            emptyRetriesLeft = emptyRetriesLeft - 1
                            C_Timer.After(INBOX_EMPTY_GAP, step)
                        else
                            finish(true)
                        end
                    else
                        emptyRetriesLeft = INBOX_EMPTY_RETRIES
                        wipe(skipped)
                        step()
                    end
                end)
                return
            end
            if emptyRetriesLeft > 0 then
                emptyRetriesLeft = emptyRetriesLeft - 1
                C_Timer.After(INBOX_EMPTY_GAP, step)
                return
            end
            finish(true)
            return
        end

        -- Process high → low so indices stay stable as mails disappear.
        local target
        local hadMatch = false
        for i = num, 1, -1 do
            if ns.MailClassify:MatchesFilter(i, filter, selected) then
                local _, _, _, _, _, CODAmount, _, _, _, _, _, _, isGM = GetInboxHeaderInfo(i)
                if not isGM and (CODAmount or 0) == 0 then
                    hadMatch = true
                    if not skipped[i] then
                        target = i
                        break
                    end
                end
            end
        end

        if not target then
            -- Only unusable leftovers (empty shells / wrong filter payload).
            if hadMatch then
                finish(true)
                return
            end
            -- Headers may still be streaming in (common right after MAIL_SHOW).
            if emptyRetriesLeft > 0 then
                emptyRetriesLeft = emptyRetriesLeft - 1
                C_Timer.After(INBOX_EMPTY_GAP, step)
                return
            end
            finish(true)
            return
        end

        emptyRetriesLeft = INBOX_EMPTY_RETRIES
        -- Selected is keyed by inbox index. Clear before TakeOneMail so a
        -- MAIL_INBOX_UPDATE refresh (which can fire on delete before our
        -- callback) does not paint the check on the mail that slides into
        -- this slot. High→low keeps any remaining lower indices valid.
        -- Restore on abort so a bags-full stop leaves the check in place.
        if filter == "selected" and selected then
            selected[target] = nil
        end
        TakeOneMail(target, filter, function(result, loot)
            if result == false then
                if filter == "selected" and selected then
                    selected[target] = true
                end
                finish(false)
                return
            end
            if result == "skip" then
                skipped[target] = true
            else
                if loot and ((loot.gold or 0) > 0 or (loot.items and #loot.items > 0)) then
                    local short, full, itemCount = ns.RunLog.FormatLoot(loot.gold, loot.items)
                    local detail = full
                    if loot.subject and loot.subject ~= "" then
                        detail = loot.subject .. (full ~= "" and ("\n" .. full) or "")
                    end
                    ns.RunLog:Add("info", nil, loot.sender, string.format(ns.L["LOG_COLLECT_MAIL"], short), {
                        detail = detail ~= "" and detail or nil,
                    })
                    passGold = passGold + (loot.gold or 0)
                    passItems = passItems + itemCount
                    passMails = passMails + 1
                end
                -- Deletes shift inbox indices; drop skip marks.
                wipe(skipped)
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
        -- Drop before the inbox shifts so a later refresh doesn't paint the
        -- check on whatever mail slides into this slot.
        if selected then
            selected[index] = nil
        end
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
        if selected then
            selected[index] = nil
        end
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

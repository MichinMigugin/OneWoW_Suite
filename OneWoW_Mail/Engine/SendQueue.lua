local _, ns = ...

ns.SendQueue = {}
local SendQueue = ns.SendQueue

local running = false
local cancelRequested = false

local function ClearCompose()
    ClearSendMail()
end

-- Send acks are tracked by the shared ns.SendResult listener (Engine/SendResult.lua).

-- ============================================================================
-- Attaching
-- ============================================================================

--- Find an empty slot in a generic (bagFamily 0) bag for a split remainder.
---@return number|nil bag
---@return number|nil slot
local function FindEmptyGenericSlot()
    for bag = 0, NUM_BAG_SLOTS do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if (free or 0) > 0 and (family or 0) == 0 then
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                if not C_Container.GetContainerItemInfo(bag, slot) then
                    return bag, slot
                end
            end
        end
    end
    return nil
end

--- Attach a planned bag slot (`loc = { bag, slot, itemID, count }`) to a
--- send-mail slot.
---
--- Full stacks are picked up and attached directly. Partial stacks are NOT
--- attached from a split cursor: on this client, attaching a split-cursor item
--- to mail lands the ENTIRE source stack. Verified manually with the stock
--- Blizzard mail UI (12.x): split to cursor → attach = whole stack; split →
--- set down in a bag slot → pick up → attach = correct amount. So the split
--- goes bag-to-bag first — split onto the cursor, place into an empty bag
--- slot, verify the new stack's count — and only then is that verified stack
--- attached whole. Do not "simplify" this back to cursor-attach.
---
--- Every stage is polled, not assumed: locked source slot → wait
--- (ClearSendMail returns stale attachments and locks slots for a moment);
--- split/pickup → wait for the cursor; place → wait for the new stack; click →
--- wait for HasSendMailItem, and only THEN touch the cursor again (clearing it
--- between click and ack yanks the item back and cancels the attach). The
--- attach is verified by itemID + count; any mismatch fails loudly with a
--- reason code instead of silently mailing a full stack. Failures leave items
--- in bags (worst case: relocated to the scratch slot), never in the mail.
---@param loc table planned slot { bag, slot, itemID, count? }
---@param attachIndex number
---@param onDone fun(ok: boolean, reason?: string)
local function AttachBagSlot(loc, attachIndex, onDone)
    local function fail(reason)
        ClearCursor()
        onDone(false, reason)
    end

    ClearCursor()

    local take

    --- Poll `check` every 50ms until it returns non-nil (passed to `next`) or
    --- ~2s elapse (fail with `timeoutReason`).
    local function waitFor(check, timeoutReason, next)
        local tries = 0
        local function tick()
            if cancelRequested then
                fail("cancelled")
                return
            end
            local result = check()
            if result ~= nil then
                next(result)
                return
            end
            tries = tries + 1
            if tries > 40 then
                fail(timeoutReason)
                return
            end
            C_Timer.After(0.05, tick)
        end
        tick()
    end

    local function cursorHasItem()
        if CursorHasItem() or GetCursorInfo() == "item" then
            return true
        end
        return nil
    end

    -- Stage 4: click the attach slot, confirm what actually landed there.
    local function attachAndVerify(fromBag, fromSlot)
        C_Container.PickupContainerItem(fromBag, fromSlot)
        waitFor(cursorHasItem, "cursor-timeout", function()
            ClickSendMailItemButton(attachIndex)
            waitFor(function()
                if HasSendMailItem(attachIndex) then
                    return true
                end
                return nil
            end, "attach-timeout", function()
                local _, itemID, _, qty = GetSendMailItem(attachIndex)
                ClearCursor()
                if loc.itemID and itemID and itemID ~= loc.itemID then
                    onDone(false, "wrong-item")
                elseif qty and qty ~= take then
                    onDone(false, string.format("qty %d/%d", qty, take))
                else
                    onDone(true)
                end
            end)
        end)
    end

    -- Stage 3 (partial only): split onto the cursor, park in `scratch`, then
    -- verify the parked stack is exactly `take` before attaching it.
    local function splitToScratch(scratchBag, scratchSlot)
        C_Container.SplitContainerItem(loc.bag, loc.slot, take)
        waitFor(cursorHasItem, "split-timeout", function()
            C_Container.PickupContainerItem(scratchBag, scratchSlot)
            waitFor(function()
                local info = C_Container.GetContainerItemInfo(scratchBag, scratchSlot)
                if info and info.itemID and not info.isLocked then
                    return info
                end
                return nil
            end, "place-timeout", function(info)
                if info.itemID ~= loc.itemID then
                    fail("scratch-wrong-item")
                    return
                end
                if (info.stackCount or 1) ~= take then
                    -- SplitContainerItem moved the wrong amount (e.g. the whole
                    -- stack). Items are safe in the scratch slot; don't mail.
                    fail(string.format("split %d/%d", info.stackCount or 1, take))
                    return
                end
                attachAndVerify(scratchBag, scratchSlot)
            end)
        end)
    end

    -- Stage 1: wait out transient locks, re-check identity, compute `take`.
    local lockTries = 0
    local function pickupWhenUnlocked()
        if cancelRequested then
            fail("cancelled")
            return
        end
        local info = C_Container.GetContainerItemInfo(loc.bag, loc.slot)
        if not info or not info.itemID then
            fail("slot-empty")
            return
        end
        -- Bag contents can shift between planning and attaching (previous
        -- jobs, loot, sorting). Never mail whatever sits in the slot now.
        if loc.itemID and info.itemID ~= loc.itemID then
            fail("item-moved")
            return
        end
        if info.isLocked then
            lockTries = lockTries + 1
            if lockTries > 20 then -- 2s
                fail("slot-locked")
                return
            end
            C_Timer.After(0.1, pickupWhenUnlocked)
            return
        end

        local stack = info.stackCount or 1
        take = tonumber(loc.count) or stack
        if take < 1 then
            fail("zero-count")
            return
        end
        if take > stack then
            take = stack
        end

        -- Stage 2: whole stacks attach directly; partials split in bags first.
        if take >= stack then
            attachAndVerify(loc.bag, loc.slot)
            return
        end
        local scratchBag, scratchSlot = FindEmptyGenericSlot()
        if not scratchBag then
            fail("no-free-slot")
            return
        end
        splitToScratch(scratchBag, scratchSlot)
    end

    pickupWhenUnlocked()
end

-- ============================================================================
-- Jobs
-- ============================================================================

--- Send one composed mail (attachments already planned as bag slots).
---@param job table { target, subject, money?, slots = { {bag,slot,count?,link?} } }
---@param onDone fun(ok: boolean, reason?: string, detail?: string)
local function SendJob(job, onDone)
    ns.NativeSend:Activate("sendqueue")
    ClearCompose()

    local sendTo = ns.AddressBook:NormalizeRecipient(job.target)
    if sendTo == "" then
        onDone(false, "target")
        return
    end

    local slots = job.slots or {}
    local maxSlots = ns.Constants.SEND_ATTACH_SLOTS
    local i = 1
    local attachIndex = 1

    local function finishSend()
        if job.money and job.money > 0 then
            SetSendMailMoney(job.money)
        end

        local _, charKey = ns.AddressBook:IsSuiteAlt(job.target)
        ns.SendResult:Listen(function()
            ns.AddressBook:RememberRecipient(sendTo)
            if charKey and ns.InTransit then
                ns.InTransit:RecordSend(charKey, job)
            end
            if ns.Compose and ns.Compose.Refresh then
                ns.Compose:Refresh()
            end
            onDone(true)
        end, function()
            onDone(false, "send")
        end)
        SendMail(sendTo, job.subject or "", "")
    end

    local function attachNext()
        if cancelRequested then
            onDone(false, "cancelled")
            return
        end
        if i > #slots or attachIndex > maxSlots then
            finishSend()
            return
        end
        local loc = slots[i]
        i = i + 1
        AttachBagSlot(loc, attachIndex, function(ok, why)
            if not ok then
                -- Missing attachments would silently mail an incomplete (or
                -- wrong-quantity) shipment; stop instead.
                onDone(false, "attach", (loc.link or "?") .. " [" .. (why or "?") .. "]")
                return
            end
            attachIndex = attachIndex + 1
            C_Timer.After(0.05, attachNext)
        end)
    end

    attachNext()
end

-- ============================================================================
-- Queue
-- ============================================================================

--- Queue jobs and send sequentially. Stops on the first failure.
---@param jobs table
---@param onDone fun(ok: boolean)|nil
function SendQueue:Start(jobs, onDone)
    if running then
        return
    end
    if not jobs or #jobs == 0 then
        if onDone then onDone(true) end
        return
    end

    local L = ns.L
    running = true
    cancelRequested = false

    local i = 1

    local function finish(ok)
        running = false
        ns.SendResult:Cancel()
        ClearCompose()
        ns.NativeSend:Deactivate("sendqueue")
        if onDone then onDone(ok) end
    end

    local function step()
        if cancelRequested then
            finish(false)
            return
        end
        if i > #jobs then
            finish(true)
            return
        end
        local job = jobs[i]
        i = i + 1
        SendJob(job, function(ok, reason, detail)
            if not ok then
                if reason == "attach" then
                    print(L["ADDON_CHAT_PREFIX"] .. " " .. string.format(L["ERR_ATTACH_FAILED"], detail or "?"))
                elseif reason == "send" then
                    print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ERR_SEND_FAILED"])
                end
                finish(false)
                return
            end
            C_Timer.After(0.3, step)
        end)
    end

    step()
end

function SendQueue:Cancel()
    cancelRequested = true
end

function SendQueue:IsRunning()
    return running
end

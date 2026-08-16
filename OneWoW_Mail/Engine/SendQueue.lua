local _, ns = ...

ns.SendQueue = {}
local SendQueue = ns.SendQueue

local running = false
local cancelRequested = false

local MT = ns.MailTrace

local function Trace(event, fields)
    if MT.enabled then
        MT:Record("send", event, fields)
    end
end

local ResolveItemLabel = ns.ItemLabel.ResolveLabel

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
    local stageMark = MT.enabled and MT:Mark() or nil
    local take

    local function fail(reason)
        Trace("fail", {
            reason = reason,
            bag = loc.bag,
            slot = loc.slot,
            itemID = loc.itemID,
            take = take,
            attachIndex = attachIndex,
            _mark = stageMark,
        })
        ClearCursor()
        onDone(false, reason)
    end

    ClearCursor()

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
        Trace("pickup", {
            bag = fromBag,
            slot = fromSlot,
            itemID = loc.itemID,
            take = take,
            attachIndex = attachIndex,
        })
        stageMark = MT.enabled and MT:Mark() or nil
        C_Container.PickupContainerItem(fromBag, fromSlot)
        waitFor(cursorHasItem, "cursor-timeout", function()
            Trace("click", {
                bag = fromBag,
                slot = fromSlot,
                itemID = loc.itemID,
                take = take,
                attachIndex = attachIndex,
            })
            stageMark = MT.enabled and MT:Mark() or nil
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
                    Trace("verify_fail", {
                        reason = "wrong-item",
                        bag = fromBag,
                        slot = fromSlot,
                        itemID = loc.itemID,
                        gotItemID = itemID,
                        take = take,
                        attachIndex = attachIndex,
                        _mark = stageMark,
                    })
                    onDone(false, "wrong-item")
                elseif qty and qty ~= take then
                    local why = string.format("qty %d/%d", qty, take)
                    Trace("verify_fail", {
                        reason = why,
                        bag = fromBag,
                        slot = fromSlot,
                        itemID = loc.itemID,
                        take = take,
                        gotQty = qty,
                        attachIndex = attachIndex,
                        _mark = stageMark,
                    })
                    onDone(false, why)
                else
                    Trace("verify_ok", {
                        bag = fromBag,
                        slot = fromSlot,
                        itemID = loc.itemID,
                        take = take,
                        attachIndex = attachIndex,
                        _mark = stageMark,
                    })
                    onDone(true)
                end
            end)
        end)
    end

    -- Stage 3 (partial only): split onto the cursor, park in `scratch`, then
    -- verify the parked stack is exactly `take` before attaching it.
    local function splitToScratch(scratchBag, scratchSlot)
        Trace("split", {
            bag = loc.bag,
            slot = loc.slot,
            itemID = loc.itemID,
            take = take,
            scratchBag = scratchBag,
            scratchSlot = scratchSlot,
            attachIndex = attachIndex,
        })
        stageMark = MT.enabled and MT:Mark() or nil
        C_Container.SplitContainerItem(loc.bag, loc.slot, take)
        waitFor(cursorHasItem, "split-timeout", function()
            Trace("place", {
                bag = loc.bag,
                slot = loc.slot,
                itemID = loc.itemID,
                take = take,
                scratchBag = scratchBag,
                scratchSlot = scratchSlot,
                attachIndex = attachIndex,
            })
            stageMark = MT.enabled and MT:Mark() or nil
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
    Trace("unlock", {
        bag = loc.bag,
        slot = loc.slot,
        itemID = loc.itemID,
        attachIndex = attachIndex,
    })
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
        Trace("job_fail", { reason = "target", target = job.target, shipmentId = job.shipmentId })
        onDone(false, "target")
        return
    end

    local slots = job.slots or {}
    local maxSlots = ns.Constants.SEND_ATTACH_SLOTS
    local i = 1
    local attachIndex = 1
    local jobMark = MT.enabled and MT:Mark() or nil
    Trace("job_start", {
        target = job.target,
        shipmentId = job.shipmentId,
        slots = #slots,
        money = job.money or 0,
    })

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
            Trace("job_ok", {
                target = job.target,
                shipmentId = job.shipmentId,
                slots = #slots,
                _mark = jobMark,
            })
            onDone(true)
        end, function(sendReason, uiError)
            -- detail is "timeout" | "failed" | Blizzard UI error text
            local detail = sendReason or "failed"
            if detail == "failed" and uiError and uiError ~= "" then
                detail = uiError
            end
            Trace("job_fail", {
                reason = "send",
                detail = detail,
                target = job.target,
                shipmentId = job.shipmentId,
                _mark = jobMark,
            })
            onDone(false, "send", detail)
        end)
        local subject = ns.Compose.ResolveSendSubject(job.subject, job.money or 0)
        job.subject = subject
        SendMail(sendTo, subject, "")
    end

    local function attachNext()
        if cancelRequested then
            Trace("job_fail", {
                reason = "cancelled",
                target = job.target,
                shipmentId = job.shipmentId,
                _mark = jobMark,
            })
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
                Trace("job_fail", {
                    reason = "attach",
                    detail = why or "?",
                    bag = loc.bag,
                    slot = loc.slot,
                    itemID = loc.itemID,
                    attachIndex = attachIndex,
                    target = job.target,
                    shipmentId = job.shipmentId,
                    _mark = jobMark,
                })
                onDone(false, "attach", why or "?", loc.link, loc.itemID)
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

--- Resolve a job's shipment name for log entries (jobs from the evaluator
--- carry shipmentId; ad-hoc jobs may not).
local function JobShipmentName(job)
    if not job.shipmentId then
        return nil
    end
    for _, s in ipairs(ns.db.global.mail.shipments) do
        if s.id == job.shipmentId then
            return s.name or s.id
        end
    end
end

--- Map an attach-stage reason code to a localized detail line.
---@param code string
---@param itemID number|nil
---@param itemLink string|nil
---@return string
local function FormatAttachDetail(code, itemID, itemLink)
    local L = ns.L
    local item = ResolveItemLabel(itemID, itemLink)
    if code == "slot-locked" then
        return string.format(L["LOG_FAIL_ATTACH_LOCKED"], item)
    elseif code == "no-free-slot" then
        return string.format(L["LOG_FAIL_ATTACH_NO_SLOT"], item)
    elseif code == "slot-empty" or code == "item-moved" then
        return string.format(L["LOG_FAIL_ATTACH_MOVED"], item)
    elseif code == "cursor-timeout" or code == "split-timeout" or code == "place-timeout" or code == "attach-timeout" then
        return string.format(L["LOG_FAIL_ATTACH_TIMEOUT"], item, code)
    elseif strfind(code, "^qty ") or strfind(code, "^split ") then
        return string.format(L["LOG_FAIL_ATTACH_QTY"], item, code)
    elseif code == "wrong-item" or code == "scratch-wrong-item" then
        return string.format(L["LOG_FAIL_ATTACH_WRONG"], item)
    else
        return string.format(L["LOG_FAIL_ATTACH_OTHER"], item, code)
    end
end

--- Queue jobs and send sequentially.
---
--- Stop-on-failure (default): the first failed job aborts the whole queue —
--- right for manual sends the user is watching. With
--- `opts.stopOnFailure = false` (auto pipeline) a failed job is logged and the
--- queue continues with the next one; after a server-side send failure (e.g.
--- recipient not found), remaining jobs to the same target are skipped instead
--- of eating an ack timeout each. Failures always route through ns.RunLog
--- (errors mirror to chat there).
---@param jobs table
---@param onDone fun(ok: boolean, summary: table)|nil summary = { sent = n, failed = { { job, reason, detail? } } }
---@param opts { stopOnFailure?: boolean }|nil
function SendQueue:Start(jobs, onDone, opts)
    if running then
        return
    end
    local summary = { sent = 0, failed = {} }
    if not jobs or #jobs == 0 then
        if onDone then onDone(true, summary) end
        return
    end

    local L = ns.L
    running = true
    cancelRequested = false
    local stopOnFailure = not opts or opts.stopOnFailure ~= false
    local failedTargets = {} -- lowercased normalized target -> true after a "send" failure
    local passGold, passItems = 0, 0
    Trace("queue_start", { jobs = #jobs, stopOnFailure = stopOnFailure })

    local i = 1

    local function finish(ok)
        running = false
        ns.SendResult:Cancel()
        ClearCompose()
        ns.NativeSend:Deactivate("sendqueue")
        Trace("queue_done", {
            ok = ok,
            sent = summary.sent,
            failed = #summary.failed,
        })
        if summary.sent > 0 then
            local moneyStr = passGold > 0 and OneWoW.Format.FormatGold(passGold) or OneWoW.Format.FormatGold(0)
            ns.RunLog:Add("info", nil, nil, string.format(
                L["LOG_SEND_SUMMARY"],
                summary.sent,
                moneyStr,
                passItems
            ))
        end
        if onDone then onDone(ok, summary) end
    end

    local function recordSuccess(job)
        local items = {}
        for _, loc in ipairs(job.slots or {}) do
            if loc.link then
                tinsert(items, { link = loc.link, count = loc.count or 1 })
            end
        end
        local gold = job.money or 0
        local short, full, itemCount = ns.RunLog.FormatLoot(gold, items)
        if short == "" then
            short = "-"
        end
        ns.RunLog:Add("info", JobShipmentName(job), job.target, string.format(L["LOG_SEND_OK"], short), {
            detail = full ~= "" and full or nil,
        })
        passGold = passGold + gold
        passItems = passItems + itemCount
        summary.sent = summary.sent + 1
    end

    local function recordFailure(job, reason, detail, itemLink, itemID)
        tinsert(summary.failed, { job = job, reason = reason, detail = detail, itemLink = itemLink, itemID = itemID })
        local message
        local label = ResolveItemLabel(itemID, itemLink)
        local logOpts = { code = detail, detail = nil, itemLink = itemLink }
        if reason == "attach" then
            logOpts.detail = FormatAttachDetail(detail or "?", itemID, itemLink)
            if stopOnFailure then
                message = string.format(L["ERR_ATTACH_FAILED"], label)
            else
                message = string.format(L["LOG_ATTACH_FAILED"], label)
            end
        elseif reason == "send" then
            if detail == "timeout" then
                message = stopOnFailure and L["ERR_SEND_TIMEOUT"] or L["LOG_FAIL_TIMEOUT"]
                logOpts.code = "timeout"
                logOpts.detail = message
            elseif detail == "failed" or not detail or detail == "" then
                message = stopOnFailure and L["ERR_SEND_FAILED"] or L["LOG_FAIL_SERVER"]
                logOpts.code = "failed"
                logOpts.detail = message
            else
                -- Already-localized Blizzard UI_ERROR_MESSAGE (e.g. ERR_MAIL_CANT_SEND_REALM).
                message = detail
                logOpts.code = nil
            end
        elseif reason == "target" then
            message = L["ERR_NO_TARGET"]
            logOpts.code = "target"
            logOpts.detail = message
        else
            message = reason or "?"
            logOpts.detail = message
        end
        ns.RunLog:Add("error", JobShipmentName(job), job.target, message, logOpts)
    end

    local function step()
        if cancelRequested then
            finish(false)
            return
        end
        if i > #jobs then
            finish(#summary.failed == 0)
            return
        end
        local job = jobs[i]
        i = i + 1

        local targetKey = strlower(ns.AddressBook:NormalizeRecipient(job.target or ""))
        if failedTargets[targetKey] then
            tinsert(summary.failed, { job = job, reason = "skipped" })
            ns.RunLog:Add("warn", JobShipmentName(job), job.target, L["LOG_TARGET_SKIPPED"], {
                code = "skipped",
                detail = L["LOG_TARGET_SKIPPED"],
            })
            step()
            return
        end

        SendJob(job, function(ok, reason, detail, itemLink, itemID)
            if ok then
                recordSuccess(job)
                C_Timer.After(0.3, step)
                return
            end
            if reason == "cancelled" then
                finish(false)
                return
            end
            recordFailure(job, reason, detail, itemLink, itemID)
            if reason == "send" then
                failedTargets[targetKey] = true
            end
            if stopOnFailure then
                finish(false)
                return
            end
            ClearCompose()
            C_Timer.After(0.3, step)
        end)
    end

    step()
end

--- True while a cancel has been requested but the current job may still be
--- finishing its in-flight attach/send step.
function SendQueue:Cancel()
    cancelRequested = true
end

function SendQueue:IsRunning()
    return running
end

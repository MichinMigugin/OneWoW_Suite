local _, ns = ...

-- ============================================================================
-- AutoRun
-- ============================================================================
-- Orchestrates per-shipment auto-run when the mailbox opens. Two phases:
--
--   Phase A: sends every `mode == "auto"` shipment immediately (failures are
--   logged and the queue continues — no stop-on-failure).
--   Phase B: runs AFTER phase A completes (its items are physically gone by
--   then, so cross-phase reservation handles itself) and dry-run plans every
--   `mode == "auto_preview"` shipment. The result is held as display-only
--   intent rows on the Activity tab.
--
-- Preview shows intent; Process re-plans. Concrete bag/slot plans go stale
-- the moment anything else touches bags or the inbox, so the held plan is
-- never executed — clicking Process re-plans the same shipment set from live
-- bags and runs that fresh plan.

ns.AutoRun = {}
local AutoRun = ns.AutoRun

local SETTLE_DELAY = 0.5 -- let the mailbox/inbox state settle after MAIL_SHOW
local BUSY_RETRY = 1.0 -- collect and send both move bag items; never overlap

local mailOpen = false
local ranThisVisit = false
local processing = false
local pendingIntents = {} -- { shipmentId, shipmentName, target, itemID, link, quantity }

local function NotifyActivity()
    if ns.ActivityUI then
        ns.ActivityUI:Refresh()
    end
end

local function LogPlanErrors(result)
    for _, err in ipairs(result.errors) do
        ns.RunLog:Add("warn", nil, nil, err)
    end
end

--- Flatten plan entries into display-only intent rows for the Activity tab.
local function CaptureIntents(result)
    wipe(pendingIntents)
    for _, plan in ipairs(result.plans) do
        for _, entry in ipairs(plan.entries or {}) do
            tinsert(pendingIntents, {
                shipmentId = plan.shipment.id,
                shipmentName = plan.shipment.name or plan.shipment.id,
                target = plan.target,
                itemID = entry.itemID,
                link = entry.slots[1] and entry.slots[1].link,
                quantity = entry.quantity,
            })
        end
    end
end

--- Intent rows held for review (grouped by shipment, plan order). Display
--- only — never fed back into the send queue.
function AutoRun:GetPendingIntents()
    return pendingIntents
end

local function PhaseB()
    if not mailOpen then
        return
    end
    local result = ns.ShipmentEvaluator:Preview({ mode = "auto_preview" })
    LogPlanErrors(result)
    CaptureIntents(result)
    if #result.jobs > 0 then
        ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_QUEUED_PREVIEW"], #result.jobs))
    end
    NotifyActivity()
end

local function PhaseA()
    ns.ShipmentEvaluator:Run({ mode = "auto", stopOnFailure = false }, function(_, result, summary)
        LogPlanErrors(result)
        if summary.sent > 0 then
            ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_AUTO_DONE"], summary.sent))
        end
        PhaseB()
    end)
end

local function TryStart()
    if not mailOpen or ranThisVisit then
        return
    end
    -- Collect and SendQueue both manipulate bag slots and fight over item
    -- locks; wait until the pipeline is idle.
    if ns.Collect:IsRunning() or ns.SendQueue:IsRunning() then
        C_Timer.After(BUSY_RETRY, TryStart)
        return
    end
    ranThisVisit = true
    PhaseA()
end

--- Process (user click): discard the held display plans, re-plan the same
--- shipment set from live bags, and send that fresh plan.
function AutoRun:Process()
    if processing or ns.SendQueue:IsRunning() or ns.Collect:IsRunning() then
        return
    end
    if #pendingIntents == 0 then
        return
    end
    processing = true
    wipe(pendingIntents)
    NotifyActivity()
    ns.ShipmentEvaluator:Run({ mode = "auto_preview", stopOnFailure = false }, function(_, result, summary)
        processing = false
        LogPlanErrors(result)
        if summary.sent > 0 then
            ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_PROCESS_DONE"], summary.sent))
        end
        NotifyActivity()
    end)
end

--- Discard (user click): clear the held queue without sending.
function AutoRun:Discard()
    if #pendingIntents == 0 then
        return
    end
    wipe(pendingIntents)
    NotifyActivity()
end

function AutoRun:IsProcessing()
    return processing
end

function AutoRun:Initialize()
    if self._wired then
        return
    end
    self._wired = true

    local f = CreateFrame("Frame")
    f:RegisterEvent("MAIL_SHOW")
    f:RegisterEvent("MAIL_CLOSED")
    f:SetScript("OnEvent", function(_, event)
        if event == "MAIL_SHOW" then
            if mailOpen then
                return -- MAIL_SHOW can refire without an intervening MAIL_CLOSED
            end
            mailOpen = true
            C_Timer.After(SETTLE_DELAY, TryStart)
        else
            mailOpen = false
            ranThisVisit = false
            wipe(pendingIntents)
            NotifyActivity()
        end
    end)
end

local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- ============================================================================
-- AutoRun
-- ============================================================================
-- Orchestrates per-shipment auto-run when the mailbox opens. Two phases:
--
--   Phase A: sends every eligible `mode == "auto"` shipment immediately.
--   Phase B: after A, dry-run plans eligible `mode == "auto_preview"` shipments
--   into display-only Activity intents.
--
-- Frequency:
--   "session" (default) — retry until that shipment succeeds this login/reload;
--     empty plans count as success. Forced close keeps retry state.
--   "visit" — every mailbox open; forced close discards pending (re-plans next).
--
-- Preview shows intent; Process re-plans. Held bag/slot plans are never executed.

ns.AutoRun = {}
local AutoRun = ns.AutoRun

local SETTLE_DELAY = 0.5
local BUSY_RETRY = 1.0

local mailOpen = false
local visitToken = 0
local processing = false
local closing = false
local pendingIntents = {} -- display rows
local sessionDone = {} -- [shipmentId] = true
local activeJobShipmentIds = {} -- ids touched by the in-flight auto/process run
local closeDialog

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

--- Info lines for eligible shipments that planned nothing (session: once when marked done).
local SKIP_MSG = {
    ["restock-met"] = "LOG_SKIP_RESTOCK_MET",
    ["keep-holds"] = "LOG_SKIP_KEEP_HOLDS",
    ["cap-zero"] = "LOG_SKIP_CAP_ZERO",
    ["no-match"] = "LOG_SKIP_NO_MATCH",
    ["nothing"] = "LOG_SKIP_NOTHING",
}

local function LogSkippedPlans(result)
    local L = ns.L
    for _, plan in ipairs(result.plans or {}) do
        if not plan.error and #(plan.jobs or {}) == 0 then
            local reason = plan.skipReason or "nothing"
            local key = SKIP_MSG[reason] or "LOG_SKIP_NOTHING"
            local name = plan.shipment and (plan.shipment.name or plan.shipment.id) or nil
            ns.RunLog:Add("info", name, plan.target, L[key], {
                code = reason,
                detail = plan.skipDetail,
            })
        end
    end
end

local function GetShipment(id)
    for _, s in ipairs(ns.db.global.mail.shipments or {}) do
        if s.id == id then
            return s
        end
    end
end

local function ShipmentFrequency(shipment)
    return shipment.frequency or "session"
end

--- Eligible for auto-run this open: matching mode, and session not yet done.
local function CollectEligibleIds(mode)
    local ids = {}
    for _, shipment in ipairs(ns.db.global.mail.shipments or {}) do
        if (shipment.mode or "manual") == mode then
            local freq = ShipmentFrequency(shipment)
            if freq == "visit" or not sessionDone[shipment.id] then
                ids[shipment.id] = true
            end
        end
    end
    return ids
end

local function MarkSessionResults(result, summary)
    local failedIds = {}
    for _, f in ipairs((summary and summary.failed) or {}) do
        if f.job and f.job.shipmentId then
            failedIds[f.job.shipmentId] = true
        end
    end
    for _, plan in ipairs(result.plans or {}) do
        local id = plan.shipment and plan.shipment.id
        if id then
            local shipment = plan.shipment
            if failedIds[id] then
                sessionDone[id] = nil
            elseif ShipmentFrequency(shipment) == "session" then
                -- Success including empty plan / no jobs.
                sessionDone[id] = true
            end
        end
    end
end

local function MarkActiveIncomplete()
    for id in pairs(activeJobShipmentIds) do
        sessionDone[id] = nil
    end
    wipe(activeJobShipmentIds)
end

local function TrackJobs(jobs)
    wipe(activeJobShipmentIds)
    for _, job in ipairs(jobs or {}) do
        if job.shipmentId then
            activeJobShipmentIds[job.shipmentId] = true
        end
    end
end

local function CaptureIntents(result)
    wipe(pendingIntents)
    for _, plan in ipairs(result.plans) do
        local freq = ShipmentFrequency(plan.shipment)
        for _, entry in ipairs(plan.entries or {}) do
            tinsert(pendingIntents, {
                shipmentId = plan.shipment.id,
                shipmentName = plan.shipment.name or plan.shipment.id,
                target = plan.target,
                itemID = entry.itemID,
                link = entry.slots and entry.slots[1] and entry.slots[1].link,
                quantity = entry.quantity,
                money = entry.money,
                frequency = freq,
            })
        end
    end
end

function AutoRun:GetPendingIntents()
    return pendingIntents
end

function AutoRun:ClearSessionFlags(shipmentId)
    if shipmentId then
        sessionDone[shipmentId] = nil
    end
end

--- Apply forced-close / Exit rules: cancel sends, session keeps retry, visit pending wiped.
function AutoRun:OnMailboxClosing(forced)
    if ns.SendQueue:IsRunning() then
        ns.SendQueue:Cancel()
        MarkActiveIncomplete()
    end

    local hadVisitPending = false
    local hadSessionPending = false
    for _, intent in ipairs(pendingIntents) do
        if intent.frequency == "session" then
            hadSessionPending = true
            sessionDone[intent.shipmentId] = nil -- retry next open
        else
            hadVisitPending = true
        end
    end
    wipe(pendingIntents)

    if forced and (hadVisitPending or hadSessionPending) then
        if hadVisitPending and hadSessionPending then
            ns.RunLog:Add("warn", nil, nil, ns.L["LOG_CLOSE_MIXED"])
        elseif hadSessionPending then
            ns.RunLog:Add("warn", nil, nil, ns.L["LOG_CLOSE_SESSION_RETRY"])
        else
            ns.RunLog:Add("warn", nil, nil, ns.L["LOG_CLOSE_VISIT_DISCARD"])
        end
    end

    NotifyActivity()
end

local function PhaseB(token)
    if not mailOpen or token ~= visitToken then
        return
    end
    local ids = CollectEligibleIds("auto_preview")
    local result = ns.ShipmentEvaluator:Preview({ shipmentIds = ids })
    LogPlanErrors(result)
    LogSkippedPlans(result)
    CaptureIntents(result)
    -- Session shipments with nothing to send (and no plan error) are done.
    for id in pairs(ids) do
        local shipment = GetShipment(id)
        if shipment and ShipmentFrequency(shipment) == "session" then
            local hadWork, planErr = false, false
            for _, plan in ipairs(result.plans) do
                if plan.shipment.id == id then
                    if plan.error then
                        planErr = true
                    end
                    if #(plan.jobs or {}) > 0 then
                        hadWork = true
                    end
                end
            end
            if not hadWork and not planErr then
                sessionDone[id] = true
            end
        end
    end
    if #result.jobs > 0 then
        ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_QUEUED_PREVIEW"], #result.jobs))
    end
    NotifyActivity()
end

local function PhaseA(token)
    local ids = CollectEligibleIds("auto")
    local result = ns.ShipmentEvaluator:Preview({ shipmentIds = ids })
    LogPlanErrors(result)
    LogSkippedPlans(result)
    TrackJobs(result.jobs)
    if #result.jobs == 0 then
        MarkSessionResults(result, { sent = 0, failed = {} })
        wipe(activeJobShipmentIds)
        PhaseB(token)
        return
    end
    ns.SendQueue:Start(result.jobs, function(_, summary)
        if token ~= visitToken then
            return
        end
        MarkSessionResults(result, summary)
        wipe(activeJobShipmentIds)
        if summary.sent > 0 then
            ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_AUTO_DONE"], summary.sent))
        end
        PhaseB(token)
    end, { stopOnFailure = false })
end

--- Inbox auto-collect filter from db toggles (nil = off).
local function ResolveAutoCollectFilter()
    local mail = ns.db.global.mail
    local gold = mail.autoCollectGold
    local items = mail.autoCollectItems
    if gold and items then
        return "all"
    end
    if gold then
        return "gold"
    end
    if items then
        return "items"
    end
    return nil
end

--- Kick Collect once when the mailbox opens; AutoRun waits via TryStart busy-retry.
local function MaybeStartAutoCollect()
    if ns.Collect:IsRunning() or ns.SendQueue:IsRunning() then
        return
    end
    local filter = ResolveAutoCollectFilter()
    if not filter then
        return
    end
    ns.Collect:Start(filter, nil)
end

local function TryStart(token)
    if not mailOpen or token ~= visitToken then
        return
    end
    if ns.Collect:IsRunning() or ns.SendQueue:IsRunning() then
        C_Timer.After(BUSY_RETRY, function()
            TryStart(token)
        end)
        return
    end
    PhaseA(token)
end

function AutoRun:Process(onDone)
    if processing or ns.SendQueue:IsRunning() or ns.Collect:IsRunning() then
        if onDone then onDone(false) end
        return
    end
    if #pendingIntents == 0 then
        if onDone then onDone(true) end
        return
    end
    -- Re-plan the same shipment ids that were held (fresh bags).
    local ids = {}
    for _, intent in ipairs(pendingIntents) do
        ids[intent.shipmentId] = true
    end
    processing = true
    wipe(pendingIntents)
    NotifyActivity()
    local result = ns.ShipmentEvaluator:Preview({ shipmentIds = ids })
    TrackJobs(result.jobs)
    if #result.jobs == 0 then
        processing = false
        MarkSessionResults(result, { sent = 0, failed = {} })
        wipe(activeJobShipmentIds)
        LogPlanErrors(result)
        LogSkippedPlans(result)
        NotifyActivity()
        if onDone then onDone(true) end
        return
    end
    ns.SendQueue:Start(result.jobs, function(_, summary)
        processing = false
        LogPlanErrors(result)
        -- Skips among the held set that re-planned empty (e.g. bags changed).
        LogSkippedPlans(result)
        MarkSessionResults(result, summary)
        wipe(activeJobShipmentIds)
        if summary.sent > 0 then
            ns.RunLog:Add("info", nil, nil, string.format(ns.L["LOG_PROCESS_DONE"], summary.sent))
        end
        NotifyActivity()
        if onDone then onDone(#summary.failed == 0) end
    end, { stopOnFailure = false })
end

function AutoRun:Discard()
    -- Manual discard from Activity: abandon held intents; session shipments
    -- remain eligible (not marked done) so they re-plan next open / Process.
    for _, intent in ipairs(pendingIntents) do
        if intent.frequency == "session" then
            sessionDone[intent.shipmentId] = nil
        end
    end
    wipe(pendingIntents)
    NotifyActivity()
end

function AutoRun:IsProcessing()
    return processing
end

function AutoRun:HasPending()
    return #pendingIntents > 0
end

local function HideCloseDialog()
    if closeDialog and closeDialog.frame then
        closeDialog.frame:Hide()
    end
end

--- Intentional close while pending review: Process / Exit / Go Back.
---@param proceed fun() called to actually close the mailbox
function AutoRun:RequestClose(proceed)
    if closing then
        return
    end
    if not self:HasPending() then
        proceed()
        return
    end

    local L = ns.L
    if not closeDialog then
        closeDialog = OneWoW_GUI:CreateDialog({
            name = "OneWoW_MailPendingClose",
            title = L["CLOSE_PENDING_TITLE"],
            width = 420,
            height = 160,
            escClose = false,
            showBrand = false,
            buttons = {
                {
                    text = L["CLOSE_PENDING_BACK"],
                    onClick = function(frame)
                        frame:Hide()
                    end,
                },
                {
                    text = L["CLOSE_PENDING_EXIT"],
                    onClick = function(frame)
                        frame:Hide()
                        closing = true
                        AutoRun:OnMailboxClosing(false)
                        proceed()
                    end,
                },
                {
                    text = L["BTN_PROCESS"],
                    onClick = function(frame)
                        frame:Hide()
                        closing = true
                        AutoRun:Process(function()
                            closing = false
                            proceed()
                        end)
                    end,
                },
            },
        })
        local msg = OneWoW_GUI:CreateFS(closeDialog.contentFrame, 12)
        msg:SetPoint("TOPLEFT", closeDialog.contentFrame, "TOPLEFT", 16, -16)
        msg:SetPoint("TOPRIGHT", closeDialog.contentFrame, "TOPRIGHT", -16, -16)
        msg:SetJustifyH("LEFT")
        msg:SetWordWrap(true)
        closeDialog.message = msg
    end
    closeDialog.message:SetText(L["CLOSE_PENDING_BODY"])
    closeDialog.frame:Show()
    closeDialog.frame:Raise()
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
            -- Always accept a new visit. Sticky mailOpen used to block reopens
            -- when MAIL_CLOSED was missed (Escape without CloseMail, etc.).
            HideCloseDialog()
            mailOpen = true
            visitToken = visitToken + 1
            local token = visitToken
            C_Timer.After(SETTLE_DELAY, function()
                MaybeStartAutoCollect()
                TryStart(token)
            end)
        else
            mailOpen = false
            visitToken = visitToken + 1 -- invalidate in-flight settle/try
            HideCloseDialog()
            -- Forced path when Shell didn't already run RequestClose/OnMailboxClosing.
            if not closing then
                AutoRun:OnMailboxClosing(true)
            end
            closing = false
        end
    end)
end

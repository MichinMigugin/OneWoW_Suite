local _, ns = ...

ns.ShipmentEvaluator = {}
local ShipmentEvaluator = ns.ShipmentEvaluator

local PE = OneWoW.PredicateEngine

--- Count free-ish mailable quantity for an itemID already matched in bag slots.
local function CountTargetHave(charKey, itemID, sources)
    local API = OneWoW_AltTracker_Storage_API
    if not API or not charKey then
        return 0
    end
    local total = 0
    local function walkContainer(container)
        if not container then return end
        for _, bag in pairs(container) do
            if type(bag) == "table" then
                for _, slot in pairs(bag) do
                    if type(slot) == "table" and slot.itemID == itemID then
                        total = total + (slot.count or slot.quantity or 1)
                    end
                end
            end
        end
    end
    if sources.bags then
        walkContainer(API.GetBags(charKey))
    end
    if sources.bank then
        walkContainer(API.GetPersonalBank(charKey))
    end
    if sources.guild then
        walkContainer(API.GetGuildBank(charKey))
    end
    return total
end

--- Scan bags for mailable (non-soulbound) slots matching a compiled predicate.
---@param pred fun(props: table): boolean
---@param blacklist table
---@param exclusions table
---@return table slots { { bag, slot, itemID, count, link } }
local function ScanMatchingSlots(pred, blacklist, exclusions)
    local out = {}
    local bags = { 0, 1, 2, 3, 4 }
    if Enum.BagIndex and Enum.BagIndex.ReagentBag then
        tinsert(bags, Enum.BagIndex.ReagentBag)
    end

    for _, bag in ipairs(bags) do
        local num = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, num do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                local itemID = info.itemID
                if not blacklist[itemID] and not exclusions[itemID] then
                    local link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot)
                    local props = PE:BuildProps(itemID, bag, slot)
                    if props and not props.isSoulbound and pred(props) then
                        tinsert(out, {
                            bag = bag,
                            slot = slot,
                            itemID = itemID,
                            count = info.stackCount or 1,
                            link = link,
                        })
                    end
                end
            end
        end
    end
    return out
end

--- Always exclude soulbound at compile time so the match field need not include it.
---@param match string|nil
---@return string
local function BuildMatchExpr(match)
    match = strtrim(match or "")
    if match == "" then
        return match
    end
    return "(" .. match .. ") & !#soulbound"
end

--- Build send plan for one shipment (does not send). Shipment selection
--- (explicit id / auto-run mode) is the caller's job — see Preview.
---@param shipment table
---@param reserved table itemID -> already reserved count
---@return table plan { shipment, target, byItem = { [itemID] = { need, slots } }, jobs }
local function PlanShipment(shipment, reserved)
    local plan = {
        shipment = shipment,
        target = shipment.target,
        entries = {}, -- { itemID, quantity, slots }
        jobs = {},
        error = nil,
    }

    if not shipment.target or shipment.target == "" then
        plan.error = "no target"
        return plan
    end

    local pred, err = PE:Compile(BuildMatchExpr(shipment.match))
    if not pred then
        plan.error = err or "bad match"
        return plan
    end

    local blacklist = ns.db.global.mail.blacklistItemIDs or {}
    local exclusions = shipment.exclusions or {}
    local slots = ScanMatchingSlots(pred, blacklist, exclusions)

    -- Group by itemID
    local byItem = {}
    for _, loc in ipairs(slots) do
        local row = byItem[loc.itemID]
        if not row then
            row = { itemID = loc.itemID, total = 0, slots = {} }
            byItem[loc.itemID] = row
        end
        row.total = row.total + loc.count
        tinsert(row.slots, loc)
    end

    local _, charKey = ns.AddressBook:IsSuiteAlt(shipment.target)
    local keepQty = shipment.keepQty or 0
    local restockSources = shipment.restockSources or { bags = true, bank = true, guild = false }

    for itemID, row in pairs(byItem) do
        reserved[itemID] = reserved[itemID] or 0
        local available = row.total - reserved[itemID] - keepQty
        if available < 0 then
            available = 0
        end

        local sendQty = available
        if shipment.maxQtyEnabled then
            local maxQty = shipment.maxQty or 0
            if shipment.restock and charKey then
                local have = CountTargetHave(charKey, itemID, restockSources)
                local need = maxQty - have
                if need < 0 then need = 0 end
                sendQty = math.min(available, need)
            else
                sendQty = math.min(available, maxQty)
            end
        end

        if sendQty > 0 then
            reserved[itemID] = reserved[itemID] + sendQty
            -- Allocate bag slots until sendQty met
            local left = sendQty
            local used = {}
            for _, loc in ipairs(row.slots) do
                if left <= 0 then break end
                local take = math.min(loc.count, left)
                tinsert(used, { bag = loc.bag, slot = loc.slot, count = take, itemID = itemID, link = loc.link })
                left = left - take
            end
            tinsert(plan.entries, { itemID = itemID, quantity = sendQty, slots = used })
        end
    end

    -- Pack into 12-attachment jobs
    local subject = ns.Constants.SUBJECT_PREFIX .. (shipment.name or shipment.id or "shipment")
    local current = { target = shipment.target, subject = subject, slots = {}, shipmentId = shipment.id }
    local function flush()
        if #current.slots > 0 then
            tinsert(plan.jobs, current)
            current = { target = shipment.target, subject = subject, slots = {}, shipmentId = shipment.id }
        end
    end
    local maxSlots = ns.Constants.SEND_ATTACH_SLOTS
    for _, entry in ipairs(plan.entries) do
        for _, loc in ipairs(entry.slots) do
            if #current.slots >= maxSlots then
                flush()
            end
            tinsert(current.slots, loc)
        end
    end
    flush()

    return plan
end

--- Dry-run plan for a selection of shipments. All selected shipments share
--- one `reserved` table, so the same bag items are never allocated twice
--- within a pass.
---@param filter string|{ shipmentId?: string, mode?: string }|nil a string (or shipmentId) selects one shipment regardless of mode; mode selects every shipment with that auto-run mode; nil selects nothing
---@return table { plans = {}, jobs = {}, errors = {} }
function ShipmentEvaluator:Preview(filter)
    if type(filter) == "string" then
        filter = { shipmentId = filter }
    end
    filter = filter or {}

    local function selected(shipment)
        if filter.shipmentId then
            return shipment.id == filter.shipmentId
        end
        if filter.mode then
            return (shipment.mode or "manual") == filter.mode
        end
        return false
    end

    local reserved = {}
    local result = { plans = {}, jobs = {}, errors = {} }

    for _, shipment in ipairs(ns.db.global.mail.shipments or {}) do
        if selected(shipment) then
            local plan = PlanShipment(shipment, reserved)
            tinsert(result.plans, plan)
            if plan.error then
                tinsert(result.errors, (shipment.name or shipment.id) .. ": " .. plan.error)
            end
            for _, job in ipairs(plan.jobs) do
                tinsert(result.jobs, job)
            end
        end
    end
    return result
end

--- Evaluate and send. Preview first if dryRun.
---@param opts { dryRun?: boolean, shipmentId?: string, mode?: string, stopOnFailure?: boolean }
---@param onDone fun(ok: boolean, result: table, summary: table)|nil summary as in SendQueue:Start
function ShipmentEvaluator:Run(opts, onDone)
    opts = opts or {}
    local result = self:Preview({ shipmentId = opts.shipmentId, mode = opts.mode })
    if opts.dryRun or #result.jobs == 0 then
        if onDone then onDone(true, result, { sent = 0, failed = {} }) end
        return result
    end
    ns.SendQueue:Start(result.jobs, function(ok, summary)
        if onDone then onDone(ok, result, summary) end
    end, { stopOnFailure = opts.stopOnFailure })
    return result
end

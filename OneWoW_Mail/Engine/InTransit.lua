local _, ns = ...

ns.InTransit = {}
local InTransit = ns.InTransit

--- Record an outgoing shipment onto the recipient's Storage in-transit list.
---@param charKey string
---@param job table
function InTransit:RecordSend(charKey, job)
    local API = OneWoW_AltTracker_Storage_API
    if not API or not API.AddInTransitShipment or not charKey then
        return
    end

    local items = {}
    for _, loc in ipairs(job.slots or {}) do
        tinsert(items, {
            itemID = loc.itemID,
            count = loc.count or 1,
            itemLink = loc.link,
        })
    end

    API.AddInTransitShipment(charKey, {
        shipmentId = job.shipmentId or "unknown",
        sender = OneWoW_GUI:GetCharacterKey(),
        sentAt = time(),
        subject = job.subject,
        money = job.money or 0,
        items = items,
    })
end

--- Clear in-transit entries that match a collected inbox mail subject.
---
--- Subjects carry the shipment *name*, so renaming a shipment while its mail
--- is in flight orphans the in-transit entry (harmless, but it lingers).
--- Entries already store shipmentId — clear by id instead if the Storage API
--- ever grows that lookup.
---@param charKey string|nil defaults to current character
---@param subject string|nil
function InTransit:ClearMatching(charKey, subject)
    local API = OneWoW_AltTracker_Storage_API
    if not API or not API.ClearInTransitBySubject then
        return
    end
    charKey = charKey or OneWoW_GUI:GetCharacterKey()
    if not charKey then
        return
    end
    if subject and strfind(subject, ns.Constants.SUBJECT_PREFIX, 1, true) == 1 then
        API.ClearInTransitBySubject(charKey, subject)
    end
end

--- Hook collect path: when current character takes mail, clear matching in-transit.
function InTransit:OnMailTaken(index)
    local _, _, _, subject = GetInboxHeaderInfo(index)
    self:ClearMatching(nil, subject)
end

--- Inbox is empty after a collect pass — any leftover in-transit rows are orphans.
function InTransit:ClearAllIfInboxEmpty()
    if GetInboxNumItems() > 0 then
        return
    end
    local API = OneWoW_AltTracker_Storage_API
    if not API or not API.ClearAllInTransit then
        return
    end
    local charKey = OneWoW_GUI:GetCharacterKey()
    if charKey then
        API.ClearAllInTransit(charKey)
    end
end

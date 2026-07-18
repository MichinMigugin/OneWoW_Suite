local _, ns = ...

OneWoW_Mail_API = {}

function OneWoW_Mail_API.Toggle()
    if ns.Shell and ns.Shell.Toggle then
        ns.Shell:Toggle()
    end
end

function OneWoW_Mail_API.Show()
    if ns.Shell and ns.Shell.Show then
        ns.Shell:Show()
    end
end

function OneWoW_Mail_API.Hide()
    if ns.Shell and ns.Shell.Hide then
        ns.Shell:Hide()
    end
end

--- Preview what a shipment would send (dry-run).
---@param filter string|{ shipmentId?: string, mode?: string }|nil id selects one shipment; mode selects all with that auto-run mode; nil selects nothing
---@return table|nil result { plans, jobs, errors }
function OneWoW_Mail_API.PreviewShipment(filter)
    if ns.ShipmentEvaluator then
        return ns.ShipmentEvaluator:Preview(filter)
    end
    return nil
end

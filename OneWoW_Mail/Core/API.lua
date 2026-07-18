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
---@param shipmentId string|nil
---@return table|nil plan
function OneWoW_Mail_API.PreviewShipment(shipmentId)
    if ns.ShipmentEvaluator then
        return ns.ShipmentEvaluator:Preview(shipmentId)
    end
    return nil
end

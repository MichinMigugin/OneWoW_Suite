local _, ns = ...

-- Public, cross-addon read surface for the Trackers hub. ns stays private.
OneWoW_Trackers_API = {}

--- Toggle the Trackers module in the suite hub.
function OneWoW_Trackers_API.Toggle()
    OneWoW.UI:Toggle()
end

--- Show the Trackers module in the suite hub.
function OneWoW_Trackers_API.Show()
    OneWoW.UI:Show("trackers")
end

--- Hide the suite hub window.
function OneWoW_Trackers_API.Hide()
    OneWoW.UI:Hide()
end

--- Current weekly reset region key ("auto" | "us" | "eu" | "asia").
---@return string
function OneWoW_Trackers_API.GetWeeklyResetRegion()
    if ns.TrackerData and ns.TrackerData.GetWeeklyResetRegion then
        return ns.TrackerData:GetWeeklyResetRegion()
    end
    return "auto"
end

--- Localized label for a region key (defaults to the active region).
---@param value string|nil
---@return string
function OneWoW_Trackers_API.GetWeeklyResetRegionLabel(value)
    if ns.TrackerData and ns.TrackerData.GetWeeklyResetRegionLabel then
        return ns.TrackerData:GetWeeklyResetRegionLabel(value)
    end
    return value or "auto"
end

--- Ordered { value, label } list for building a region dropdown.
---@return table[]
function OneWoW_Trackers_API.GetWeeklyResetRegionOptions()
    if ns.TrackerData and ns.TrackerData.GetWeeklyResetRegionOptions then
        return ns.TrackerData:GetWeeklyResetRegionOptions()
    end
    return {}
end

--- Localized title/description for the region picker UI.
---@return string title, string desc
function OneWoW_Trackers_API.GetWeeklyResetUIText()
    if ns.TrackerData and ns.TrackerData.GetWeeklyResetUIText then
        return ns.TrackerData:GetWeeklyResetUIText()
    end
    return "", ""
end

--- Set the weekly reset region and immediately reconcile any pending resets.
---@param value string
function OneWoW_Trackers_API.SetWeeklyResetRegion(value)
    if ns.TrackerData and ns.TrackerData.SetWeeklyResetRegion then
        ns.TrackerData:SetWeeklyResetRegion(value)
    end
end

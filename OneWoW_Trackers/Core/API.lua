local _, ns = ...

-- Public, cross-addon read surface for the Trackers hub. ns stays private.
OneWoW_Trackers_API = {}

--- Toggle the standalone Trackers main window (no-op when hub-hosted).
function OneWoW_Trackers_API.Toggle()
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

--- Show the standalone Trackers main window.
function OneWoW_Trackers_API.Show()
    if ns.UI and ns.UI.Show then
        ns.UI:Show()
    end
end

--- Hide the standalone Trackers main window.
function OneWoW_Trackers_API.Hide()
    if ns.UI and ns.UI.Hide then
        ns.UI:Hide()
    end
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

--- Localized title/description/current-format strings for the region picker UI.
---@return string title, string desc, string currentFmt
function OneWoW_Trackers_API.GetWeeklyResetUIText()
    if ns.TrackerData and ns.TrackerData.GetWeeklyResetUIText then
        return ns.TrackerData:GetWeeklyResetUIText()
    end
    return "", "", "%s"
end

--- Set the weekly reset region and immediately reconcile any pending resets.
---@param value string
function OneWoW_Trackers_API.SetWeeklyResetRegion(value)
    if ns.TrackerData and ns.TrackerData.SetWeeklyResetRegion then
        ns.TrackerData:SetWeeklyResetRegion(value)
    end
end

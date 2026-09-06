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

--- Incomplete steps whose map matches any of `mapIDs`.
---@param mapIDs number[]
---@return table[]
function OneWoW_Trackers_API.GetIncompleteHitsForMap(mapIDs)
    local hits = {}
    local TD = ns.TrackerData
    if not TD or type(mapIDs) ~= "table" then
        return hits
    end

    local mapSet = {}
    for i = 1, #mapIDs do
        local mapID = tonumber(mapIDs[i])
        if mapID then
            mapSet[mapID] = true
        end
    end
    if not next(mapSet) then
        return hits
    end

    local byList = {}
    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        if type(list) == "table" then
            for _, sec in ipairs(list.sections or {}) do
                for _, step in ipairs(sec.steps or {}) do
                    if not TD:IsStepComplete(listID, sec.key, step.key) then
                        local stepMap = tonumber(step.mapID)
                        local match = stepMap and mapSet[stepMap]
                        if not match then
                            local tp = step.trackParams
                            local tpMap = tp and tonumber(tp.mapID)
                            match = tpMap and mapSet[tpMap]
                        end
                        if match then
                            local row = byList[listID]
                            if not row then
                                row = { listID = listID, title = list.title or "", steps = {} }
                                byList[listID] = row
                                hits[#hits + 1] = row
                            end
                            row.steps[#row.steps + 1] = step.label or ""
                        end
                    end
                end
            end
        end
    end
    return hits
end

--- Show Trackers and select `listID` when the tab is ready.
---@param listID string|nil
function OneWoW_Trackers_API.ShowList(listID)
    ns.pendingListSelect = listID
    OneWoW.UI:Show("trackers")
    local tabFrame = OneWoW.UI:GetContentFrame("trackers", "tracker")
    if tabFrame and tabFrame.SelectList and listID then
        tabFrame.SelectList(listID)
        ns.pendingListSelect = nil
    end
end

local _, _ = ...

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

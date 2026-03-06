local addonName, ns = ...

local function SetupActionBarsCompat()
    if _G.OneWoW_AltTracker_Character then
        ns.ActionBarsModule = _G.OneWoW_AltTracker_Character.ActionBars or nil
    else
        ns.ActionBarsModule = nil
        print("|cFFFFD100OneWoW|r AltTracker: Warning - OneWoW_AltTracker_Character addon not loaded. Action Bars functionality will be unavailable.")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "OneWoW_AltTracker_Character" then
        SetupActionBarsCompat()
        self:UnregisterEvent("ADDON_LOADED")
    elseif loadedAddon == addonName then
        C_Timer.After(0.1, function()
            if _G.OneWoW_AltTracker_Character then
                SetupActionBarsCompat()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end)

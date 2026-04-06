local addonName, ns = ...

local function SetupActionBarsCompat()
    if _G.OneWoW_AltTracker_Character then
        ns.ActionBarsModule = _G.OneWoW_AltTracker_Character.ActionBars or nil
    else
        ns.ActionBarsModule = nil
        local L = ns.L
        print((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW - AltTracker:|r") .. " " .. (L and L["MSG_CHAR_ADDON_NOT_LOADED"] or "Character data addon not loaded."))
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

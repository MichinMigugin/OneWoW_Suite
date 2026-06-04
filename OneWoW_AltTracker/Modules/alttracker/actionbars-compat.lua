local _, ns = ...

local function SetupActionBarsCompat()
    if OneWoW_AltTracker_Character then
        ns.ActionBarsModule = OneWoW_AltTracker_Character.ActionBars or nil
    else
        ns.ActionBarsModule = nil
        local L = ns.L
        print((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW - AltTracker:|r") .. " " .. (L and L["MSG_CHAR_ADDON_NOT_LOADED"] or "Character data addon not loaded."))
    end
end

-- The OneWoW_AltTracker_Character store is force-loaded by the core orchestrator
-- before PLAYER_LOGIN, and that force-load eats its ADDON_LOADED event. Resolve
-- the ActionBars module at PLAYER_LOGIN, when the store is guaranteed present.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    SetupActionBarsCompat()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

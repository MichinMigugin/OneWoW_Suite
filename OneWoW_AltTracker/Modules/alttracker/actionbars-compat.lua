local _, ns = ...

function ns.SetupActionBarsCompat()
    if OneWoW_AltTracker_Character then
        ns.ActionBarsModule = OneWoW_AltTracker_Character.ActionBars or nil
    else
        ns.ActionBarsModule = nil
        local L = ns.L
        print((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW - AltTracker:|r") .. " " .. (L and L["MSG_CHAR_ADDON_NOT_LOADED"] or "Character data addon not loaded."))
    end
end

local _, ns = ...

function ns.SetupActionBarsCompat()
    if OneWoW_AltTracker_Character then
        ns.ActionBarsModule = OneWoW_AltTracker_Character.ActionBars or nil
    else
        ns.ActionBarsModule = nil
        local L = ns.L
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["MSG_CHAR_ADDON_NOT_LOADED"])
    end
end

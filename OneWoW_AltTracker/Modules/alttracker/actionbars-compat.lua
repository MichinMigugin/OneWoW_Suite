local _, ns = ...

function ns.SetupActionBarsCompat()
    if OneWoW_AltTracker_Character_API then
        ns.ActionBarsModule = OneWoW_AltTracker_Character_API.GetActionBarsModule()
    else
        ns.ActionBarsModule = nil
        local L = ns.L
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["MSG_CHAR_ADDON_NOT_LOADED"])
    end
end

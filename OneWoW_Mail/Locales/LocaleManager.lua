local _, ns = ...

function ns.ApplyLanguage()
    local lang = OneWoW_GUI:GetSetting("language") or GetLocale()
    OneWoW.Locale:SetLanguage(lang)
end

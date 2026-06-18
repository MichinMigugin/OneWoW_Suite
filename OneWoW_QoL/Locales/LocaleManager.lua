local _, ns = ...

-- Thin shim over the OneWoW Locale service. `ns.ApplyLanguage` is still called by
-- OnInitialize, the OnLanguageChanged settings callback, and the profile-sync method
-- (addon:ApplyLanguage via t-profiles), so it is kept (not deleted) until those legacy callers are removed.
-- SetLanguage refolds every scope in place (core "OneWoW_QoL" + each "QoL.<module>"),
-- pushes BINDING_* globals, and fires OnApply; views are stable (core ns.L set in
-- Locales/enUS.lua, each module captures its own GetTable). esMX->esES inside.
function ns.ApplyLanguage()
    local lang = OneWoW_GUI:GetSetting("language") or GetLocale()
    OneWoW.Locale:SetLanguage(lang)
end

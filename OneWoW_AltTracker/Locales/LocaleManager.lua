local _, ns = ...

-- Thin shim over the OneWoW Locale service. `ns.ApplyLanguage` is still called by
-- OnInitialize, the OnLanguageChanged settings callback, and the profile-sync method
-- (OneWoWAltTracker:ApplyLanguage via t-profiles), so it is kept (not deleted) until
-- those legacy callers are removed. SetLanguage refolds every scope in place, pushes BINDING_* globals, and
-- fires OnApply; ns.L is a stable view (set in Locales/enUS.lua). esMX->esES inside.
function ns.ApplyLanguage()
    local lang = OneWoW_GUI:GetSetting("language") or GetLocale()
    OneWoW.Locale:SetLanguage(lang)
end

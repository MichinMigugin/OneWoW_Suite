local _, ns = ...

-- Thin shim over the OneWoW Locale service. Called from unit lifecycle init,
-- OnLanguageChanged settings callbacks, and ReinitForLanguage. SetLanguage refolds
-- every scope in place, pushes BINDING_* globals, and fires OnApply; ns.L is a
-- stable view (set in Locales/enUS.lua). esMX->esES normalized inside.
function ns.ApplyLanguage()
    local lang = OneWoW_GUI:GetSetting("language") or GetLocale()
    OneWoW.Locale:SetLanguage(lang)
end

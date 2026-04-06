-- OneWoW Addon File
-- OneWoW_Catalog/Locales/LocaleManager.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.L = ns.L or {}
ns.Locales = ns.Locales or {}

function ns.ApplyLanguage()
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    local selectedLang
    if OneWoW_GUI and OneWoW_GUI.GetSetting then
        selectedLang = OneWoW_GUI:GetSetting("language")
    end
    selectedLang = selectedLang or GetLocale()
    if selectedLang == "esMX" then selectedLang = "esES" end
    local localeData = ns.Locales[selectedLang] or ns.Locales["enUS"]
    local fallback = ns.Locales["enUS"]
    for k, v in pairs(fallback) do
        ns.L[k] = localeData[k] or v
    end
end

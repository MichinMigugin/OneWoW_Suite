local _, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.L = ns.L or {}
ns.Locales = ns.Locales or {}

function ns.ApplyLanguage()
    local selectedLang = OneWoW_GUI:GetSetting("language") or GetLocale()
    if selectedLang == "esMX" then selectedLang = "esES" end
    local localeData = ns.Locales[selectedLang] or ns.Locales["enUS"]
    local fallback = ns.Locales["enUS"]
    for k, v in pairs(fallback) do
        ns.L[k] = localeData[k] or v
    end
end

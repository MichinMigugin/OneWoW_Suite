local addonName, ns = ...

ns.Locales = ns.Locales or {}

function ns.ApplyLanguage()
    local selectedLang
    local hub = _G.OneWoW
    if hub and hub.db and hub.db.global then
        selectedLang = hub.db.global.language or GetLocale()
    else
        local addon = _G.OneWoW_AltTracker
        selectedLang = (addon and addon.db and addon.db.global and addon.db.global.language) or GetLocale()
    end
    if selectedLang == "esMX" then selectedLang = "esES" end
    local localeData = ns.Locales[selectedLang] or ns.Locales["enUS"]
    local fallback = ns.Locales["enUS"]
    for k, v in pairs(fallback) do
        ns.L[k] = localeData[k] or v
    end
end

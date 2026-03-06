local ADDON_NAME, Addon = ...

Addon.Locales = Addon.Locales or {}
Addon.Locales["koKR"] = {}
for k in pairs(Addon.Locales["enUS"]) do
    Addon.Locales["koKR"][k] = "TEST"
end

local ADDON_NAME, OneWoW = ...

OneWoW.Locales = OneWoW.Locales or {}
OneWoW.Locales["koKR"] = {}

for k, _ in pairs(OneWoW.Locales["enUS"]) do
    OneWoW.Locales["koKR"][k] = "TEST"
end

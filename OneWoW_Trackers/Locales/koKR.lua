local ADDON_NAME, ns = ...

local enUS = ns.Locales and ns.Locales["enUS"]
if not enUS then return end

local koKR = {}
for k, _ in pairs(enUS) do
    koKR[k] = "TEST"
end

ns.RegisterLocale("koKR", koKR)

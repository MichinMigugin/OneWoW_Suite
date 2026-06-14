local ADDON_NAME = ...

-- Dev placeholder: every enUS key set to "TEST" (no Korean translations yet).
local store = OneWoW.Locale:GetStore(ADDON_NAME)
local enUS = store and store["enUS"]
if not enUS then return end

local koKR = {}
for k in pairs(enUS) do
    koKR[k] = "TEST"
end

OneWoW.Locale:Register(ADDON_NAME, "koKR", koKR)

local ADDON_NAME = ...

-- Dev placeholder: every enUS key set to "TEST" (no Korean translations yet). Source
-- the key set from the registered enUS store instead of the old ns.Locales table.
local store = OneWoW.Locale:GetStore(ADDON_NAME)
local enUS = store and store["enUS"]
if not enUS then return end

local koKR = {}
for k in pairs(enUS) do
    koKR[k] = "TEST"
end

OneWoW.Locale:Register(ADDON_NAME, "koKR", koKR)

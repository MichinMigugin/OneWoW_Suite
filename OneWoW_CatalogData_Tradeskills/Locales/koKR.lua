local ADDON_NAME = ...

-- koKR is a dev placeholder (all keys = "TEST"); sourced from the enUS key set
-- via GetStore so it tracks enUS automatically. Replace with real translations later.
local store = OneWoW.Locale:GetStore(ADDON_NAME)
local enUS = store and store["enUS"]
if not enUS then return end

local koKR = {}
for k in pairs(enUS) do koKR[k] = "TEST" end
OneWoW.Locale:Register(ADDON_NAME, "koKR", koKR)

-- OneWoW Addon File
-- OneWoW_CatalogData_Quests/Core/Core.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.AddonInitialized = false

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            ns:InitializeDatabase()
        end
    elseif event == "PLAYER_LOGIN" then
        ns:OnPlayerLogin()
    end
end)

function ns:OnPlayerLogin()
    self.AddonInitialized = true

    if ns.CompletionTracker then
        ns.CompletionTracker:Initialize()
    end
    if ns.QuestScanner then
        ns.QuestScanner:Initialize()
    end

    local catalog = _G.OneWoW_Catalog
    if catalog and catalog.Catalog then
        catalog.Catalog:RegisterDataAddon("quests", ns)
    end
end

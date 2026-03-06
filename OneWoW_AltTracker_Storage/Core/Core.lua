local addonName, ns = ...
local L = ns.L

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

    if ns.Mail then
        ns.Mail:Initialize()
    end

    if ns.AHScanner then
        ns.AHScanner:Initialize()
    end

    if ns.DataManager then
        ns.DataManager:Initialize()
        ns.DataManager:RegisterEvents()
        ns.DataManager:CollectBags()
    end

    if ns.ItemIndex then
        ns.ItemIndex:Initialize()
    end
end

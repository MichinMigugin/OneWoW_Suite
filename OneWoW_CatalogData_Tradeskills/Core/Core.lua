-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Core/Core.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.AddonInitialized = false

local scanCallbacks = {}

function ns:RegisterScanCallback(fn)
    table.insert(scanCallbacks, fn)
end

function ns:FireScanCallbacks(data)
    for _, fn in ipairs(scanCallbacks) do
        pcall(fn, data)
    end
end

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

    local locale = GetLocale()
    if ns.Locales and ns.Locales[locale] then
        ns.L = ns.Locales[locale]
    end

    if ns.DataLoader then
        ns.DataLoader:Initialize()
    end

    if ns.TradeskillData then
        ns.TradeskillData:Initialize()
    end

    if ns.TradeskillScanner then
        ns.TradeskillScanner:Initialize()
    end

    local catalog = _G.OneWoW_Catalog
    if catalog and catalog.Catalog then
        catalog.Catalog:RegisterDataAddon("tradeskills", ns)
    end
end

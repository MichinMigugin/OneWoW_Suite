local addonName, ns = ...

ns.AddonInitialized = false

local scanCallbacks = {}

function ns:RegisterScanCallback(fn)
    table.insert(scanCallbacks, fn)
end

function ns:FireScanCallbacks(vendorData)
    for _, fn in ipairs(scanCallbacks) do
        pcall(fn, vendorData)
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

    if ns.VendorScanner then
        ns.VendorScanner:Initialize()
    end

    if ns.DataLoader then
        ns.DataLoader:Initialize()
    end

    local catalog = _G.OneWoW_Catalog
    if catalog and catalog.Catalog then
        catalog.Catalog:RegisterDataAddon("vendors", ns)
    end
end

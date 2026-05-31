local addonName, ns = ...

local OneWoW_GUI = LibStub and LibStub("OneWoW_GUI-1.0", true)

ns.addonName = addonName
ns.GUI = OneWoW_GUI
ns.db = nil

local defaults = {
    enabled = true,
    attachSide = "RIGHT",
    hideUnchanged = false,
    showEmptySlots = false,
}

local function CopyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = type(target[key]) == "table" and target[key] or {}
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event ~= "ADDON_LOADED" or loadedAddon ~= addonName then
        return
    end

    OneWoW_InspectMog_DB = OneWoW_InspectMog_DB or {}
    CopyDefaults(OneWoW_InspectMog_DB, defaults)
    ns.db = OneWoW_InspectMog_DB

    if ns.Scanner and ns.Scanner.Initialize then
        ns.Scanner:Initialize()
    end

    if ns.Panel and ns.Panel.Initialize then
        ns.Panel:Initialize()
    end
end)

_G.OneWoW_InspectMog = ns

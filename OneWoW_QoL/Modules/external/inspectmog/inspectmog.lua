-- Inspect Mog: transmog-aware side panel on Blizzard's Inspect frame.
-- Lists equipped items and resolved inspect transmog appearances; integrates
-- with OneWoW Notes for item stamps. UI and scanner live in sibling files.
local _, ns = ...

local InspectMogModule = {
    id             = "inspectmog",
    title          = "INSPECTMOG_TITLE",
    category       = "SOCIAL",
    description    = "INSPECTMOG_DESC",
    version        = "1.1",
    author         = "OneWoW",
    contact        = "https://wow2.xyz/",
    link           = "https://wow2.xyz/",
    preview        = true,
    defaultEnabled = true,
}
ns.InspectMog = InspectMogModule

function InspectMogModule:OnEnable()
    OneWoW:EnsureLoaded("Blizzard_InspectUI")

    if ns.InspectMogScanner and ns.InspectMogScanner.Initialize then
        ns.InspectMogScanner:Initialize()
    end
    if ns.InspectMogUI and ns.InspectMogUI.Initialize then
        ns.InspectMogUI:Initialize()
    end
end

function InspectMogModule:OnDisable()
    if ns.InspectMogUI then
        ns.InspectMogUI:Hide()
    end
    if ns.InspectMogScanner and ns.InspectMogScanner.frame then
        ns.InspectMogScanner.frame:UnregisterAllEvents()
    end
end

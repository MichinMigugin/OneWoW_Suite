-- Inspect Mog: transmog-aware side panel on Blizzard's Inspect frame.
-- Lists equipped items and resolved inspect transmog appearances; integrates
-- with OneWoW Notes for item stamps. UI and scanner live in sibling files.
local _, ns = ...
local InspectMogModule = ns.ModuleRegistry:Current()
if not InspectMogModule then return end

function InspectMogModule:OnEnable()
    -- Lazy: never force-load Blizzard_InspectUI here. Arm() registers a watcher
    -- so wiring only happens once the inspect UI exists (via a real inspect),
    -- at which point INSPECTED_UNIT is a valid token. Force-loading it at login
    -- left InspectPVPFrame handling INSPECT_HONOR_UPDATE with a nil unit.
    ns.InspectMogUI:Arm()
end

function InspectMogModule:OnDisable()
    ns.InspectMogUI:Disarm()
    ns.InspectMogScanner:Shutdown()
end

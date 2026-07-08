local _, ns = ...
local OneWoW = OneWoW

-- Junk/Protected are user overlays (preset entries) in Overlay System 2.0;
-- the tooltip line is gated on an enabled preset entry with showInTooltip on.
local function FindEnabledPresetEntry(presetId)
    local userOverlays = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("overlays", "userOverlays")
    for _, entry in pairs(userOverlays) do
        if type(entry) == "table" and entry.preset == presetId and entry.enabled then
            return entry
        end
    end
    return nil
end

local function ItemStatusProvider(_, context)
    if not context.itemID then return nil end

    local config = OneWoW.TooltipEngine.TOOLTIP_CONFIG
    local L = ns.L
    local lines = {}

    if OneWoW.ItemStatus:IsItemProtected(context.itemID) then
        local protEntry = FindEnabledPresetEntry("protected")
        if protEntry and protEntry.showInTooltip ~= false then
            lines[#lines + 1] = {
                type = "text",
                text = L["ITEMSTATUS_TOOLTIP_PROTECTED"],
                r = config.protectedColor[1],
                g = config.protectedColor[2],
                b = config.protectedColor[3],
            }
        end
    end

    if OneWoW.ItemStatus:IsItemJunk(context.itemID) then
        local junkEntry = FindEnabledPresetEntry("junk")
        if junkEntry and junkEntry.showInTooltip ~= false then
            lines[#lines + 1] = {
                type = "text",
                text = L["ITEMSTATUS_TOOLTIP_JUNK"],
                r = config.junkColor[1],
                g = config.junkColor[2],
                b = config.junkColor[3],
            }
        end
    end

    if #lines > 0 then
        return lines
    end
    return nil
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "itemstatus",
    order = 15,
    featureId = nil,
    tooltipTypes = {"item"},
    callback = ItemStatusProvider,
})

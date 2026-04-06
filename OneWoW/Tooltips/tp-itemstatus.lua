local ADDON_NAME, OneWoW = ...

local function ItemStatusProvider(tooltip, context)
    if not context.itemID then return nil end
    if not OneWoW.ItemStatus then return nil end

    local config = OneWoW.TooltipEngine.TOOLTIP_CONFIG
    local L = OneWoW.L
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local ov = db and db.overlays
    local lines = {}

    if OneWoW.ItemStatus:IsItemProtected(context.itemID) then
        local protCfg = ov and ov.protected
        if protCfg and protCfg.enabled and protCfg.showInTooltip ~= false then
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
        local junkCfg = ov and ov.junk
        if junkCfg and junkCfg.enabled and junkCfg.showInTooltip ~= false then
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

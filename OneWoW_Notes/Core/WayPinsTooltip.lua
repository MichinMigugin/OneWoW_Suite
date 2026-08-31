local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local format, type = string.format, type

-- ============================================================================
-- WayPinsTooltip
-- ============================================================================
-- Builds the OneWay Pin tooltip (title, optional description, coords, and a
-- Catalog hint for journal/vendor/quest sources). Lives here so map math
-- files do not have to own copy.
--
-- WayPinsMap:
--   World pin OnMouseEnter -> ns.WayPinsTooltip.Fill(GameTooltip, data, L["WAYPINS_MAP_TT"])
--   Minimap pin OnEnter    -> ns.WayPinsTooltip.Fill(GameTooltip, pinData)
-- Caller still SetOwner + Show.
-- ============================================================================

local WayPinsTooltip = {}
ns.WayPinsTooltip = WayPinsTooltip

local CATALOG_SOURCES = {
    journal = true,
    vendor  = true,
    quest   = true,
}

local function TrimDescription(text)
    if type(text) ~= "string" then
        return nil
    end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end
    return text
end

--- Fill a GameTooltip for a OneWay Pin. Does not SetOwner or Show.
---@param tooltip GameTooltip
---@param pin table
---@param extraLine string|nil
function WayPinsTooltip.Fill(tooltip, pin, extraLine)
    tooltip:SetText(pin.title or L["WAYPINS_UNTITLED"], 1, 1, 1)

    local desc = TrimDescription(pin.description)
    if desc then
        local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
        tooltip:AddLine(desc, r, g, b, true)
    end

    local mapName = ns.WayPins:MapDisplayName(pin.mapID)
    local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
    tooltip:AddLine(format("%s  %.1f, %.1f", mapName, pin.x or 0, pin.y or 0), r, g, b)

    if pin.source and CATALOG_SOURCES[pin.source] then
        r, g, b = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
        tooltip:AddLine(L["WAYPINS_CATALOG_HINT"], r, g, b, true)
    end

    if pin.packId and ns.WayPinPacks then
        local pack = ns.WayPinPacks:GetPack(pin.packId)
        if pack then
            r, g, b = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
            tooltip:AddLine(format("%s: %s", L["WAYPINS_PACK_BADGE"], pack.name or pin.packId), r, g, b)
        end
    end

    if type(extraLine) == "string" and extraLine ~= "" then
        r, g, b = OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
        tooltip:AddLine(extraLine, r, g, b, true)
    end
end

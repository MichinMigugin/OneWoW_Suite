local _, ns = ...

-- ============================================================================
-- Util
-- ============================================================================
-- Top-level suite helpers on the OneWoW namespace (alongside
-- RegisterLoadComponent / EnsureLoaded), used across load units.
-- ============================================================================

--- Version string from a load unit's TOC metadata.
---@param addonName string
---@return string|nil version "Unknown" if metadata missing; nil if the addon does not exist
function ns:GetAddonVersion(addonName)
    if not C_AddOns.DoesAddOnExist(addonName) then return nil end
    return C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
end

--- Localized expansion name for an expansion ID, from Blizzard's
--- ExpansionUtil. Filters the "Expansion N" placeholder Blizzard returns
--- for unnamed future expansions.
---@param expansionID number
---@return string|nil
function ns:GetExpansionName(expansionID)
    local expansionName

    if expansionID >= 0 and expansionID <= LE_EXPANSION_LEVEL_CURRENT then
        expansionName = GetExpansionName(expansionID)

        if expansionName and expansionName:find("^Expansion ") then
            expansionName = nil
        end
    end

    return expansionName
end

local _, ns = ...

-- ============================================================================
-- FeatureIcons
-- ============================================================================
-- Single write site for suite feature faces (Home, Manage Features, Button
-- Collector enhanced row). Keyed by addon folder name, plus synthetic keys
-- for collector extras that are not load units (`settings`, `portals`).
-- Brand crest for Core stays on OneWoW_GUI:GetBrandIcon — not listed here.
-- ============================================================================

local ICONS = "Interface\\Icons\\"

--- Feature face by load-unit folder name.
--- Entries may set texture and/or atlas (+ optional texCoords).
local FEATURE_ICONS = {
    OneWoW_AltTracker = {
        texture = ICONS .. "achievement_guildperk_everybodysfriend",
    },
    OneWoW_Catalog = {
        texture = ICONS .. "INV_Misc_Book_11",
    },
    OneWoW_Notes = {
        texture = ICONS .. "INV_Inscription_Scroll",
    },
    OneWoW_Trackers = {
        texture = ICONS .. "Ability_Hunter_MarkedForDeath",
    },
    OneWoW_QoL = {
        texture = ICONS .. "INV_Gizmo_RocketBoot_01",
    },
    OneWoW_Bags = {
        texture = ICONS .. "INV_Misc_Bag_08",
    },
    OneWoW_ShoppingList = {
        texture = ICONS .. "INV_Misc_Coin_01",
    },
    OneWoW_DirectDeposit = {
        texture = ICONS .. "achievement_guildperk_mobilebanking",
    },
    OneWoW_Mail = {
        texture = ICONS .. "achievement_guildperk_gmail",
    },
    OneWoW_Utility_DevTool = {
        texture = ICONS .. "INV_Gizmo_02",
    },
    -- Collector extras (not load units).
    settings = {
        texture = ICONS .. "INV_Misc_Gear_01",
    },
    portals = {
        texture = ICONS .. "INV_Misc_Book_09",
    },
}

ns.FeatureIcons = FEATURE_ICONS

--- Resolve the suite feature face for a load unit or collector extra key.
---@param addonName string folder name (e.g. "OneWoW_Mail") or extra key ("settings", "portals")
---@return table|nil info { texture?, atlas?, texCoords? }
function ns:GetFeatureIcon(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return nil
    end
    return FEATURE_ICONS[addonName]
end

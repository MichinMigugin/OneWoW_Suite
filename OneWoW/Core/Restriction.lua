local _, OneWoW = ...

-- ============================================================================
-- Restriction
-- ============================================================================
-- Gates for the Midnight secret-value system and combat/instance addon
-- restrictions. Gate secure-frame mutations and combat-sensitive reads
-- behind these instead of raw InCombatLockdown checks.
-- ============================================================================

local Restriction = {}
OneWoW.Restriction = Restriction

--- True if value must not be used in addon logic or persisted (Midnight
--- secret system). Secret values may only be passed to display APIs.
---@param value any
---@return boolean
function Restriction.IsSecret(value)
    if issecretvalue(value) then
        return true
    end
    if type(value) == "table" and issecrettable(value) then
        return true
    end
    return false
end

--- True while in combat lockdown or while any addon restriction state is
--- active (instanced content restrictions).
---@return boolean
function Restriction.IsAddonRestricted()
    if InCombatLockdown() then return true end

    for _, val in pairs(Enum.AddOnRestrictionType) do
        if C_RestrictedActions.GetAddOnRestrictionState(val) ~= Enum.AddOnRestrictionState.Inactive then
            return true
        end
    end

    return false
end

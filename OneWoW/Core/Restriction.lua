local _, ns = ...

-- ============================================================================
-- Restriction
-- ============================================================================
-- The single funnel for the Midnight secret-value system and combat/instance
-- addon restrictions. Gate secure-frame mutations and combat-sensitive reads
-- behind these instead of raw InCombatLockdown / C_RestrictedActions calls —
-- enforced suite-wide by the `restriction-funnel` pre-commit hook.
--
-- The restriction-type set checked by IsAddonRestricted is listed explicitly
-- (RESTRICTED_ACTION_TYPES below) rather than iterated over
-- Enum.AddOnRestrictionType, so a new type added by a future patch is NOT
-- silently inherited — it must be reviewed and opted in here on purpose.
-- ============================================================================

local Restriction = {}
ns.Restriction = Restriction

-- Restriction types that gate protected actions / secure-frame mutations.
-- Chat (addon comms, not secure-frame related; added 12.0.5) is intentionally
-- excluded — route any future chat-comms gating through a dedicated helper.
local RESTRICTED_ACTION_TYPES = {
    Enum.AddOnRestrictionType.Combat,
    Enum.AddOnRestrictionType.Encounter,
    Enum.AddOnRestrictionType.ChallengeMode,
    Enum.AddOnRestrictionType.PvPMatch,
    Enum.AddOnRestrictionType.Map,
}

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

--- True while in combat lockdown or while any reviewed addon-restriction type
--- (RESTRICTED_ACTION_TYPES) is active or activating. The `~= Inactive` test
--- covers both Active and the transient Activating state. Gate secure-frame
--- mutations and other protected actions behind this.
---@return boolean
function Restriction.IsAddonRestricted()
    if InCombatLockdown() then return true end

    for _, restrictionType in ipairs(RESTRICTED_ACTION_TYPES) do
        if C_RestrictedActions.GetAddOnRestrictionState(restrictionType) ~= Enum.AddOnRestrictionState.Inactive then
            return true
        end
    end

    return false
end

--- True while in combat lockdown only. For combat-only UX/perf gates (fade,
--- deferral, suppression) that are not about secure-frame safety, and for
--- hot paths that want a single cheap check.
---@return boolean
function Restriction.IsInCombat()
    return InCombatLockdown()
end

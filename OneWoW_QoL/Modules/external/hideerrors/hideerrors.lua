-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/hideerrors/hideerrors.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

-- ============================================================================
-- HideErrors
-- ============================================================================
-- Suppresses the most common combat-action red error spam (out-of-resource,
-- out-of-range, target-dead, not-ready, etc.) by replacing
-- UIErrorsFrame.AddMessage with a filtering wrapper. UIErrorsFrame is not a
-- secure frame and AddMessage is not protected, so replacement does not taint.
--
-- Filtered list is built from Blizzard's localized error globals at module
-- enable time, so it matches the player's client language without per-locale
-- maintenance here. Strings containing %s format markers are skipped (those
-- error variants vary at runtime and aren't reliable to match exactly).
-- ============================================================================

local HideErrorsModule = {
    id          = "hideerrors",
    title       = "HIDEERRORS_TITLE",
    category    = "INTERFACE",
    description = "HIDEERRORS_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    defaultEnabled = false,
    _hooked     = false,
    _origAddMessage = nil,
    _filterSet  = nil,
}

local FILTERED_GLOBALS = {
    "ERR_OUT_OF_RAGE",
    "ERR_OUT_OF_ENERGY",
    "ERR_OUT_OF_MANA",
    "ERR_OUT_OF_FOCUS",
    "ERR_OUT_OF_HEALTH",
    "ERR_OUT_OF_RUNES",
    "ERR_OUT_OF_RUNIC_POWER",
    "ERR_OUT_OF_HOLY_POWER",
    "ERR_OUT_OF_SOUL_SHARDS",
    "ERR_OUT_OF_LUNAR_POWER",
    "ERR_OUT_OF_PAIN",
    "ERR_OUT_OF_FURY",
    "ERR_OUT_OF_MAELSTROM",
    "ERR_OUT_OF_INSANITY",
    "ERR_OUT_OF_ESSENCE",
    "ERR_OUT_OF_ARCANE_CHARGES",
    "ERR_OUT_OF_COMBO_POINTS",
    "ERR_OUT_OF_CHI",
    "ERR_OUT_OF_RANGE",
    "ERR_OUT_OF_POWER_DISPLAY",
    "ERR_ABILITY_COOLDOWN",
    "ERR_SPELL_COOLDOWN",
    "ERR_SPELL_OUT_OF_RANGE",
    "ERR_BADATTACKFACING",
    "ERR_BADATTACKPOS",
    "ERR_ATTACK_PREVENTED_BY_MECHANIC_S",
    "ERR_NOEMOTEWHILERUNNING",
    "SPELL_FAILED_SPELL_IN_PROGRESS",
    "SPELL_FAILED_TARGETS_DEAD",
    "SPELL_FAILED_BAD_TARGETS",
    "SPELL_FAILED_BAD_IMPLICIT_TARGETS",
    "SPELL_FAILED_UNIT_NOT_INFRONT",
    "SPELL_FAILED_OUT_OF_RANGE",
    "SPELL_FAILED_LINE_OF_SIGHT",
    "SPELL_FAILED_CASTER_DEAD",
    "SPELL_FAILED_NOT_READY",
    "SPELL_FAILED_NO_COMBO_POINTS",
    "SPELL_FAILED_NOTHING_TO_DISPEL",
    "SPELL_FAILED_NOTHING_TO_STEAL",
    "SPELL_FAILED_MOVING",
}

local function BuildFilterSet()
    local set = {}
    for _, key in ipairs(FILTERED_GLOBALS) do
        local text = _G[key]
        if type(text) == "string" and text ~= "" and not text:find("%%") then
            set[text] = true
        end
    end
    return set
end

function HideErrorsModule:OnEnable()
    if not self._filterSet then
        self._filterSet = BuildFilterSet()
    end

    if self._hooked then return end
    if not UIErrorsFrame or not UIErrorsFrame.AddMessage then return end

    self._origAddMessage = UIErrorsFrame.AddMessage
    local filterSet = self._filterSet
    local orig = self._origAddMessage
    UIErrorsFrame.AddMessage = function(frame, msg, ...)
        if msg and filterSet[msg] and ns.ModuleRegistry:IsEnabled("hideerrors") then
            return
        end
        return orig(frame, msg, ...)
    end
    self._hooked = true
end

function HideErrorsModule:OnDisable()
    -- The wrapper checks IsEnabled() each call, so disabling the module already
    -- pass-through behavior. Leave the wrapper installed so re-enable is instant
    -- and we don't fight other addons that may have hooked AddMessage after us.
end

ns.HideErrorsModule = HideErrorsModule

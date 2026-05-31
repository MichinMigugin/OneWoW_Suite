-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/autosummon/autosummon.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local AutoSummonModule = {
    id          = "autosummon",
    title       = "AUTOSUMMON_TITLE",
    category    = "SOCIAL",
    description = "AUTOSUMMON_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "skip_in_combat", label = "AUTOSUMMON_TOGGLE_SKIP_COMBAT", description = "AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC", default = true },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
}

function AutoSummonModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoSummon")
        self._frame:SetScript("OnEvent", function(_, event, ...)
            if event == "CONFIRM_SUMMON" then
                self:CONFIRM_SUMMON()
            end
        end)
    end
    self._frame:RegisterEvent("CONFIRM_SUMMON")
end

function AutoSummonModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

function AutoSummonModule:CONFIRM_SUMMON()
    if ns.ModuleRegistry:GetToggleValue("autosummon", "skip_in_combat") then
        if UnitAffectingCombat("player") then return end
    end

    ConfirmSummon()
    StaticPopup_Hide("CONFIRM_SUMMON")
end

ns.AutoSummonModule = AutoSummonModule

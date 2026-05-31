-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/autoresurrect/autoresurrect.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local AutoResurrectModule = {
    id          = "autoresurrect",
    title       = "AUTORESURRECT_TITLE",
    category    = "SOCIAL",
    description = "AUTORESURRECT_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "skip_in_instance", label = "AUTORESURRECT_TOGGLE_SKIP_INSTANCE", description = "AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC", default = false },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
}

function AutoResurrectModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoResurrect")
        self._frame:SetScript("OnEvent", function(_, event, ...)
            if event == "RESURRECT_REQUEST" then
                self:RESURRECT_REQUEST(...)
            end
        end)
    end
    self._frame:RegisterEvent("RESURRECT_REQUEST")
end

function AutoResurrectModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

function AutoResurrectModule:RESURRECT_REQUEST()
    -- API rejects rez accept while in combat anyway; bail early to avoid noise.
    if UnitAffectingCombat("player") then return end

    if ns.ModuleRegistry:GetToggleValue("autoresurrect", "skip_in_instance") then
        local inInstance, instanceType = IsInInstance()
        if inInstance and (instanceType == "party" or instanceType == "raid"
            or instanceType == "pvp" or instanceType == "arena") then
            return
        end
    end

    AcceptResurrect()
    StaticPopup_Hide("RESURRECT")
    StaticPopup_Hide("RESURRECT_NO_SICKNESS")
    StaticPopup_Hide("RESURRECT_NO_TIMER")
end

ns.AutoResurrectModule = AutoResurrectModule

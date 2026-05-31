-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/autoreadycheck/autoreadycheck.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local AutoReadyCheckModule = {
    id          = "autoreadycheck",
    title       = "AUTOREADYCHECK_TITLE",
    category    = "SOCIAL",
    description = "AUTOREADYCHECK_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "skip_if_dead", label = "AUTOREADYCHECK_TOGGLE_DEAD", description = "AUTOREADYCHECK_TOGGLE_DEAD_DESC", default = true },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
}

function AutoReadyCheckModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoReadyCheck")
        self._frame:SetScript("OnEvent", function(_, event, ...)
            if event == "READY_CHECK" then
                self:READY_CHECK()
            end
        end)
    end
    self._frame:RegisterEvent("READY_CHECK")
end

function AutoReadyCheckModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

function AutoReadyCheckModule:READY_CHECK()
    if ns.ModuleRegistry:GetToggleValue("autoreadycheck", "skip_if_dead") then
        if UnitIsDeadOrGhost("player") then return end
    end

    ConfirmReadyCheck(true)
    StaticPopup_Hide("READY_CHECK")
    if ReadyCheckFrame then
        ReadyCheckFrame:Hide()
    end
end

ns.AutoReadyCheckModule = AutoReadyCheckModule

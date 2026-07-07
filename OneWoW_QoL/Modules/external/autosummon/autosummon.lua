local _, ns = ...
local AutoSummonModule = ns.ModuleRegistry:Current()
if not AutoSummonModule then return end

function AutoSummonModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoSummon")
        self._frame:SetScript("OnEvent", function(_, event)
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

    C_SummonInfo.ConfirmSummon()
    StaticPopup_Hide("CONFIRM_SUMMON")
end

local _, ns = ...
local AutoReadyCheckModule = ns.ModuleRegistry:Current()
if not AutoReadyCheckModule then return end

function AutoReadyCheckModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoReadyCheck")
        self._frame:SetScript("OnEvent", function(_, event)
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

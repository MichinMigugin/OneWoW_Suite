local _, ns = ...
local DeclineDuelModule = ns.ModuleRegistry:Current()
if not DeclineDuelModule then return end

function DeclineDuelModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_DeclineDuel")
        self._frame:SetScript("OnEvent", function(_, event)
            if event == "DUEL_REQUESTED" then
                self:DUEL_REQUESTED()
            elseif event == "PET_BATTLE_PVP_DUEL_REQUESTED" then
                self:PET_BATTLE_PVP_DUEL_REQUESTED()
            end
        end)
    end
    self._frame:RegisterEvent("DUEL_REQUESTED")
    self._frame:RegisterEvent("PET_BATTLE_PVP_DUEL_REQUESTED")
end

function DeclineDuelModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

function DeclineDuelModule:DUEL_REQUESTED()
    CancelDuel()
    StaticPopup_Hide("DUEL_REQUESTED")
end

function DeclineDuelModule:PET_BATTLE_PVP_DUEL_REQUESTED()
    if not ns.ModuleRegistry:GetToggleValue("declineduel", "pet_duels") then return end
    C_PetBattles.CancelPVPDuel()
    StaticPopup_Hide("PET_BATTLE_PVP_DUEL_REQUESTED")
end

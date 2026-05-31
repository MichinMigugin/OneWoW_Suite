-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/declineduel/declineduel.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local DeclineDuelModule = {
    id          = "declineduel",
    title       = "DECLINEDUEL_TITLE",
    category    = "SOCIAL",
    description = "DECLINEDUEL_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "pet_duels", label = "DECLINEDUEL_TOGGLE_PET", description = "DECLINEDUEL_TOGGLE_PET_DESC", default = true },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
}

function DeclineDuelModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_DeclineDuel")
        self._frame:SetScript("OnEvent", function(_, event, ...)
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

ns.DeclineDuelModule = DeclineDuelModule

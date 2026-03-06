-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/fastloot/fastloot.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local FastLootModule = {
    id          = "fastloot",
    title       = "FASTLOOT_TITLE",
    category    = "AUTOMATION",
    description = "FASTLOOT_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    _frame      = nil,
    _epoch      = 0,
}

function FastLootModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_FastLoot")
        self._frame:SetScript("OnEvent", function(frame, event, ...)
            if event == "LOOT_READY" then
                self:LOOT_READY()
            end
        end)
    end
    self._frame:RegisterEvent("LOOT_READY")
end

function FastLootModule:OnDisable()
    if self._frame then
        self._frame:UnregisterEvent("LOOT_READY")
    end
end

function FastLootModule:LOOT_READY()
    if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
        local now = GetTime()
        if (now - self._epoch) >= 0.3 then
            for i = GetNumLootItems(), 1, -1 do
                LootSlot(i)
            end
            self._epoch = now
        end
    end
end

ns.FastLootModule = FastLootModule

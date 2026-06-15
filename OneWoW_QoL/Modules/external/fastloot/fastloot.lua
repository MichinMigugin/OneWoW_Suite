local _, ns = ...
local FastLootModule = ns.ModuleRegistry:Current()
if not FastLootModule then return end

function FastLootModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_FastLoot")
        self._frame:SetScript("OnEvent", function(_, event)
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

local _, ns = ...

local OneWoW = OneWoW

-- ============================================================================
-- Catalog data-pack loader
-- ============================================================================
-- Catalog packs are lazyStores: login does not parse them. Opening a pack-backed
-- tab is the usual trigger (MainWindow EnsureLoaded). Quest capture still needs
-- the Quests pack when the player talks to an NPC without opening Catalog first.
-- ============================================================================

local QUEST_PACK = "OneWoW_CatalogData_Quests"

local questPackFrame = CreateFrame("Frame")
questPackFrame:SetScript("OnEvent", function(self)
    if OneWoW:EnsureLoaded(QUEST_PACK) then
        self:UnregisterAllEvents()
    end
end)

--- Arm gameplay load triggers for lazy Catalog packs.
--- Registers quest events so the Quests pack loads on first NPC interaction.
function ns.ArmCatalogDataPacks()
    questPackFrame:RegisterEvent("QUEST_DETAIL")
    questPackFrame:RegisterEvent("QUEST_ACCEPTED")
    questPackFrame:RegisterEvent("QUEST_TURNED_IN")
    questPackFrame:RegisterEvent("QUEST_COMPLETE")
end

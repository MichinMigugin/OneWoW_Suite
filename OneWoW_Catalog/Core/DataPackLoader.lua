local _, ns = ...

local OneWoW = OneWoW
local C_Timer = C_Timer

-- ============================================================================
-- Catalog data-pack loader
-- ============================================================================
-- Catalog packs are lazyStores: login does not parse them. Opening a pack-backed
-- tab is the usual trigger (MainWindow EnsureLoaded). Quest capture still needs
-- the Quests pack when the player talks to an NPC without opening Catalog first.
-- Load on the next frame so the quest / reward UI can paint before the pack
-- parse (QuestScanner.Initialize catch-up stores the dialog that triggered it).
-- ============================================================================

local QUEST_PACK = "OneWoW_CatalogData_Quests"

local questPackFrame = CreateFrame("Frame")
local loadQueued = false
questPackFrame:SetScript("OnEvent", function(self)
    if loadQueued then
        return
    end
    loadQueued = true
    C_Timer.After(0, function()
        if OneWoW:EnsureLoaded(QUEST_PACK) then
            self:UnregisterAllEvents()
        else
            loadQueued = false
        end
    end)
end)

--- Arm gameplay load triggers for lazy Catalog packs.
--- Registers quest events so the Quests pack loads on first NPC interaction.
function ns.ArmCatalogDataPacks()
    questPackFrame:RegisterEvent("QUEST_DETAIL")
    questPackFrame:RegisterEvent("QUEST_ACCEPTED")
    questPackFrame:RegisterEvent("QUEST_TURNED_IN")
    questPackFrame:RegisterEvent("QUEST_COMPLETE")
end

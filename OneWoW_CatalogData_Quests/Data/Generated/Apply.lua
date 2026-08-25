local _, ns = ...

-- ============================================================================
-- Apply Generated overlays
-- ============================================================================
-- Hand-written (not emitted by quest_db2_tools.py generate). TOC loads this
-- after the Generated tables and QuestDB shards. Fill holes only: never replace
-- a giver pin that already has map coordinates. Callable again after Archive
-- import so Classic-DF rows pick up the same overlays.
-- Walks loaded quests (not the full overlay tables) so a hot-pack load does not
-- scan every Classic pin. ImportQuestData passes the just-imported ID set.
-- Mirrors bin/lib/wowhead/quest_overlay_bake.py.
-- ============================================================================

local pairs, type = pairs, type

local function FilterRemixRewardList(values)
    if type(values) ~= "table" then
        return values
    end
    local out = {}
    for i = 1, #values do
        local item = values[i]
        local itemID = item
        if type(item) == "table" then
            itemID = item.itemID or item.id
        end
        if not ns.IsRemixRewardItem(itemID) then
            out[#out + 1] = item
        end
    end
    return out
end

local function FilterRemixQuestIDList(values)
    if type(values) ~= "table" then
        return values
    end
    local out = {}
    for i = 1, #values do
        local item = values[i]
        local questID = item
        if type(item) == "table" then
            questID = item.id
        end
        if not ns.IsRemixOnlyQuest(questID) then
            out[#out + 1] = item
        end
    end
    return out
end

local function HasXY(pin)
    return pin and pin.x ~= nil and pin.y ~= nil
end

local function FillList(quest, key, values)
    if key == "rewardItems" then
        values = FilterRemixRewardList(values)
    elseif key == "sourceQuests" or key == "nextQuests" then
        values = FilterRemixQuestIDList(values)
    end
    if type(values) ~= "table" or #values == 0 then
        return
    end
    local existing = quest[key]
    if type(existing) == "table" and #existing > 0 then
        return
    end
    quest[key] = values
end

local function FillStart(quest, overlay)
    local startPin = quest.starts and quest.starts[1]
    if HasXY(startPin) then
        return
    end

    local fill = overlay.overlayStart or overlay.sparseStart
    if not fill then
        return
    end

    quest.starts = quest.starts or {}
    local dst = quest.starts[1]
    if not dst then
        dst = {}
        quest.starts[1] = dst
    end

    for key, value in pairs(fill) do
        if dst[key] == nil then
            dst[key] = value
        end
    end

    if not HasXY(dst) and HasXY(fill) then
        dst.x = fill.x
        dst.y = fill.y
        if fill.mapID and (not dst.mapID or dst.mapID == 0) then
            dst.mapID = fill.mapID
        end
    end

    if not quest.questGiverID and dst.npcID then
        quest.questGiverID = dst.npcID
    end

    if not quest.coords and HasXY(dst) then
        quest.coords = {
            mapID = dst.mapID or quest.mapID,
            x = dst.x,
            y = dst.y,
        }
    end
end

local function ApplyOne(quest, questID)
    if ns.IsRemixOnlyQuest(questID) then
        return
    end
    local overlay = ns.QuestGeneratedPins[questID]
    if overlay then
        if (not quest.mapID or quest.mapID == 0) and overlay.uiMapID then
            quest.mapID = overlay.uiMapID
        end
        FillStart(quest, overlay)
        FillList(quest, "sourceQuests", overlay.sourceQuests)
        FillList(quest, "nextQuests", overlay.nextQuests)
        FillList(quest, "rewardItems", overlay.rewardItems)
    end

    FillList(quest, "questLines", ns.QuestGeneratedLines[questID])
    FillList(quest, "campaigns", ns.QuestGeneratedCampaigns[questID])
    FillList(quest, "db2Objectives", ns.QuestGeneratedObjectives[questID])
end

--- Fill leftover overlay holes on ExternalQuestDB.
--- When `questIDs` is set, only those keys are visited (Archive import).
---@param questIDs table<number, any>|nil
function ns.ApplyGeneratedOverlays(questIDs)
    local db = ns.ExternalQuestDB

    if questIDs then
        for questID in pairs(questIDs) do
            local quest = db[questID]
            if quest then
                ApplyOne(quest, questID)
            end
        end
        return
    end

    for questID, quest in pairs(db) do
        ApplyOne(quest, questID)
    end
end

ns.ApplyGeneratedOverlays()

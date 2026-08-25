local _, ns = ...

-- ===========================================================================
-- RemixOnlyQuests
-- ===========================================================================
-- MoP / Legion Remix quest lines. Not retail. Catalog drops these IDs.
-- Keep in sync with bin/lib/wowhead/remix_quests.py. Timewalking stays.
-- ===========================================================================

ns.RemixOnlyQuestLineID = {
    [5536] = true, -- Timerunning: Mists of Pandaria
    [5899] = true, -- Legion: Infinitely Different
    [5902] = true, -- Infinite Research
    [5959] = true, -- Infinite Epilogues
    [5968] = true, -- Infinite Power Hypothesis
    [5972] = true, -- Last Goodbyes
}

ns.RemixOnlyQuestID = {
    [79432] = true,
    [79433] = true,
    [79434] = true,
    [79435] = true,
    [79437] = true,
    [79438] = true,
    [80380] = true,
    [89404] = true,
    [89405] = true,
    [89406] = true,
    [89407] = true,
    [89408] = true,
    [89409] = true,
    [89411] = true,
    [89412] = true,
    [89413] = true,
    [89414] = true,
    [89415] = true,
    [89416] = true,
    [89417] = true,
    [89418] = true,
    [89464] = true,
    [89465] = true,
    [89466] = true,
    [89467] = true,
    [89468] = true,
    [89469] = true,
    [89476] = true,
    [89516] = true,
    [89517] = true,
    [89518] = true,
    [89519] = true,
    [89520] = true,
    [89521] = true,
    [89522] = true,
    [89523] = true,
    [89524] = true,
    [89525] = true,
    [89526] = true,
    [89527] = true,
    [89528] = true,
    [89529] = true,
    [89530] = true,
    [89531] = true,
    [89532] = true,
    [89533] = true,
    [89534] = true,
    [89535] = true,
    [89536] = true,
    [89537] = true,
    [89538] = true,
    [89539] = true,
    [89540] = true,
    [89541] = true,
    [89542] = true,
    [89543] = true,
    [89544] = true,
    [89545] = true,
    [89546] = true,
    [89547] = true,
    [89548] = true,
    [89549] = true,
    [89550] = true,
    [89551] = true,
    [89552] = true,
    [89553] = true,
    [89554] = true,
    [89555] = true,
    [89556] = true,
    [89557] = true,
    [89558] = true,
    [89590] = true,
    [89591] = true,
    [89592] = true,
    [89593] = true,
    [89594] = true,
    [89595] = true,
    [89596] = true,
    [89597] = true,
    [89598] = true,
    [89599] = true,
    [89600] = true,
    [89601] = true,
    [89602] = true,
    [89603] = true,
    [89604] = true,
    [89605] = true,
    [89606] = true,
    [89607] = true,
    [89622] = true,
    [89644] = true,
    [89665] = true,
    [89676] = true,
    [89677] = true,
    [89678] = true,
    [89679] = true,
    [89680] = true,
    [89681] = true,
    [89682] = true,
    [89683] = true,
    [90096] = true,
    [90097] = true,
    [90098] = true,
    [90099] = true,
    [90100] = true,
    [90101] = true,
    [90102] = true,
    [90103] = true,
    [90108] = true,
    [90109] = true,
    [90110] = true,
    [90111] = true,
    [90112] = true,
    [90113] = true,
    [90114] = true,
    [90659] = true,
    [90901] = true,
    [91437] = true,
    [91438] = true,
    [91439] = true,
    [91440] = true,
    [91441] = true,
    [91443] = true,
    [91444] = true,
    [91445] = true,
    [91446] = true,
    [91447] = true,
    [91448] = true,
    [91449] = true,
    [91522] = true,
    [91612] = true,
    [91639] = true,
    [91721] = true,
    [91722] = true,
    [91727] = true,
    [91728] = true,
    [91729] = true,
    [91730] = true,
    [91757] = true,
    [91847] = true,
    [91848] = true,
    [91849] = true,
    [92430] = true,
    [92563] = true,
}

--- True when this quest exists only for Remix / Timerunning.
---@param questID number|nil
---@return boolean
function ns.IsRemixOnlyQuest(questID)
    return ns.RemixOnlyQuestID[questID] == true
end

--- True when a quest record is Remix-only (ID or quest line).
---@param quest table|nil
---@return boolean
function ns.IsRemixOnlyQuestRecord(quest)
    if not quest then
        return false
    end
    if ns.IsRemixOnlyQuest(quest.id) then
        return true
    end
    local questLines = quest.questLines
    if type(questLines) ~= "table" then
        return false
    end
    for i = 1, #questLines do
        local line = questLines[i]
        local lineID = type(line) == "table" and line.id or line
        if ns.RemixOnlyQuestLineID[lineID] then
            return true
        end
    end
    return false
end

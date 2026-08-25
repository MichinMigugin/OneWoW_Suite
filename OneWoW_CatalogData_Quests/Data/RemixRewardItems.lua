local _, ns = ...

-- ============================================================================
-- RemixRewardItems
-- ============================================================================
-- Remix event caches (MoP / Legion) are not retail quest rewards. Wowhead
-- glued them onto normal quest IDs. Catalog drops them from reward lists.
-- Keep in sync with bin/lib/wowhead/remix_rewards.py. Timewalking caches stay.
-- ============================================================================

ns.RemixRewardItemID = {
    [211279] = true, -- Cache of Infinite Treasure (MoP)
    [211932] = true,
    [223908] = true, -- Minor Bronze Cache
    [223909] = true, -- Lesser Bronze Cache
    [223910] = true, -- Bronze Cache
    [223911] = true, -- Greater Bronze Cache
    [237812] = true, -- Cache of Infinite Treasure (Legion)
    [239224] = true,
    [239303] = true,
    [245553] = true, -- Heroic Cache of Infinite Treasure
    [246789] = true, -- Cache of Infinite Power
    [246796] = true, -- Epic Cache of Infinite Power
    [246812] = true, -- Minor Bronze Cache
    [246813] = true, -- Greater Bronze Cache
    [246814] = true, -- Bronze Cache
    [246815] = true, -- Lesser Bronze Cache
    [248247] = true, -- Cache of Infinite Power
    [251821] = true, -- Cache of Infinite Power
    [254847] = true, -- Minor Bronze Cache
    [254848] = true,
    [254849] = true,
    [254850] = true,
}

--- True when this item is a Remix event cache, not a retail quest reward.
---@param itemID number|nil
---@return boolean
function ns.IsRemixRewardItem(itemID)
    return ns.RemixRewardItemID[itemID] == true
end

local _, ns = ...
local M = ns.ModuleRegistry:Current()
if not M then return end

-- ============================================================================
-- Crafting Orders — reward and weekly game-data
-- ============================================================================
-- Item and currency IDs from the client (knowledge point items, Artisan's
-- Acuity, and "Services Requested" weeklies). Owned by this module; not a
-- paste of another addon.
-- ============================================================================

local KP2 = {
    [228729] = true, [228731] = true, [228727] = true, [228733] = true,
    [228739] = true, [228735] = true, [228725] = true, [228737] = true,
    [246321] = true, [246323] = true, [246325] = true, [246327] = true,
    [246329] = true, [246331] = true, [246333] = true, [246335] = true,
}

local KP1 = {
    [228738] = true, [228730] = true, [228726] = true, [228732] = true,
    [228724] = true, [228734] = true, [228728] = true, [228736] = true,
    [246320] = true, [246322] = true, [246324] = true, [246326] = true,
    [246328] = true, [246330] = true, [246332] = true, [246334] = true,
}

local ACUITY_ITEM = 210814

local ACUITY_CURRENCY = {
    [3256] = true, [3257] = true, [3258] = true, [3259] = true,
    [3261] = true, [3262] = true, [3263] = true, [3266] = true,
}

-- Current expansion first, then the previous expansion's weekly.
local WEEKLY_QUEST = {
    [Enum.Profession.Alchemy] = { 93690, 84133 },
    [Enum.Profession.Blacksmithing] = { 93691, 84127 },
    [Enum.Profession.Engineering] = { 93692, 84128 },
    [Enum.Profession.Inscription] = { 93693, 84129 },
    [Enum.Profession.Jewelcrafting] = { 93694, 84130 },
    [Enum.Profession.Leatherworking] = { 93695, 84131 },
    [Enum.Profession.Tailoring] = { 93696, 84132 },
}

local function ItemIDFromLink(link)
    if not link then return nil end
    local itemID = C_Item.GetItemInfoInstant(link)
    return itemID
end

function M:GetWeeklyQuestIDs(profession)
    return WEEKLY_QUEST[profession]
end

local GOLD_ICON = "Interface\\MoneyFrame\\UI-GoldIcon"

function M:BuildRewardIcons(order, opts)
    opts = opts or {}
    local icons = {}
    local rewards = order and order.npcOrderRewards
    if rewards then
        for i = 1, #rewards do
            local reward = rewards[i]
            local count = reward.count or 1
            if reward.currencyType then
                local info = C_CurrencyInfo.GetCurrencyInfo(reward.currencyType)
                icons[#icons + 1] = {
                    kind = "currency",
                    currencyType = reward.currencyType,
                    count = count,
                    icon = info and info.iconFileID,
                    name = info and info.name,
                }
            else
                local itemID = ItemIDFromLink(reward.itemLink)
                icons[#icons + 1] = {
                    kind = "item",
                    itemID = itemID,
                    itemLink = reward.itemLink,
                    count = count,
                    icon = itemID and C_Item.GetItemIconByID(itemID),
                }
            end
        end
    end
    local gold = opts.gold or (order and order.tipAmount) or 0
    local cut = opts.consortiumCut or (order and order.consortiumCut) or 0
    local received = M:GetGoldReceived(gold, cut)
    if received > 0 then
        icons[#icons + 1] = {
            kind = "gold",
            amount = received,
            commission = gold,
            consortiumCut = cut,
            tipAvg = opts.tipAvg,
            tipMax = opts.tipMax,
            icon = GOLD_ICON,
        }
    end
    return icons
end

function M:ScoreNpcRewards(order)
    local kp, acuity = 0, 0
    local rewards = order.npcOrderRewards
    if rewards then
        for i = 1, #rewards do
            local reward = rewards[i]
            local count = reward.count or 1
            if reward.currencyType and ACUITY_CURRENCY[reward.currencyType] then
                acuity = acuity + count
            else
                local itemID = ItemIDFromLink(reward.itemLink)
                if itemID == ACUITY_ITEM then
                    acuity = acuity + count
                elseif KP2[itemID] then
                    kp = kp + (2 * count)
                elseif KP1[itemID] then
                    kp = kp + count
                end
            end
        end
    end
    return kp, acuity, order.tipAmount or 0
end

function M:IsKnowledgePointItem(itemID)
    return KP1[itemID] == true or KP2[itemID] == true
end

function M:IsAcuityItem(itemID)
    return itemID == ACUITY_ITEM
end

function M:IsAcuityCurrency(currencyType)
    return ACUITY_CURRENCY[currencyType] == true
end

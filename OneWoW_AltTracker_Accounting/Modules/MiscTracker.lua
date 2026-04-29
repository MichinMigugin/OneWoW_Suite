local _, ns = ...

ns.MiscTracker = {}
local Module = ns.MiscTracker

local private = {
    lootOpen = false,
    goldBeforeLoot = 0,
    deathPending = false,
    goldBeforeDeath = 0,
    bmahPending = false,
    goldBeforeBMAH = 0,
    bmahItemName = nil,
    mythicPending = false,
    goldBeforeMythic = 0,
    mythicPendingTime = 0,
}

local MYTHIC_MONEY_WINDOW = 10

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("LOOT_CLOSED")
    frame:RegisterEvent("PLAYER_DEAD")
    frame:RegisterEvent("PLAYER_UNGHOST")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

    if C_BlackMarket then
        frame:RegisterEvent("BLACK_MARKET_BID_RESULT")
        frame:RegisterEvent("BLACK_MARKET_OPEN")
    end

    if C_CraftingOrders then
        frame:RegisterEvent("CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG")
    end

    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "QUEST_TURNED_IN" then
            local questID, xpReward, moneyReward = ...
            if moneyReward and moneyReward > 0 then
                local title = C_QuestLog.GetTitleForQuestID(questID) or "Quest Reward"
                ns.Transactions:RecordIncome("quest_reward", moneyReward, "Quest", tostring(questID), title, nil, nil)
            end

        elseif event == "CHALLENGE_MODE_COMPLETED" then
            private.mythicPending = true
            private.goldBeforeMythic = GetMoney()
            private.mythicPendingTime = GetServerTime()

        elseif event == "LOOT_OPENED" then
            private.lootOpen = true
            private.goldBeforeLoot = GetMoney()

        elseif event == "LOOT_CLOSED" then
            if private.lootOpen then
                local gained = GetMoney() - private.goldBeforeLoot
                if gained > 0 then
                    ns.Transactions:RecordIncome("loot_money", gained, "Loot", nil, "Looted Gold", nil, nil)
                end
            end
            private.lootOpen = false
            private.goldBeforeLoot = 0

        elseif event == "PLAYER_DEAD" then
            private.deathPending = true
            private.goldBeforeDeath = GetMoney()

        elseif event == "PLAYER_UNGHOST" then
            if private.deathPending then
                local cost = private.goldBeforeDeath - GetMoney()
                if cost > 0 then
                    ns.Transactions:RecordExpense("death_cost", cost, "Graveyard", nil, "Death Cost", nil, nil)
                end
            end
            private.deathPending = false
            private.goldBeforeDeath = 0

        elseif event == "BLACK_MARKET_OPEN" then
            private.goldBeforeBMAH = GetMoney()

        elseif event == "BLACK_MARKET_BID_RESULT" then
            local result = ...
            if result == 1 then
                private.bmahPending = true
            end

        elseif event == "CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG" then
            local _, _, playerName, tipAmount = ...
            if tipAmount and tipAmount > 0 then
                ns.Transactions:RecordIncome("crafting_order", tipAmount, playerName or "Customer", nil, "Crafting Order", nil, nil)
            end

        elseif event == "PLAYER_MONEY" then
            if private.mythicPending then
                if (GetServerTime() - private.mythicPendingTime) > MYTHIC_MONEY_WINDOW then
                    private.mythicPending = false
                else
                    local gained = GetMoney() - private.goldBeforeMythic
                    if gained > 0 then
                        ns.Transactions:RecordIncome("mythicplus_reward", gained, "Mythic+", nil, "Mythic+ Completion", nil, nil)
                        private.mythicPending = false
                    end
                end

            elseif private.bmahPending then
                private.bmahPending = false
                local cost = private.goldBeforeBMAH - GetMoney()
                if cost > 0 then
                    ns.Transactions:RecordExpense("bmah_purchase", cost, "Black Market", nil, private.bmahItemName or "BMAH Purchase", nil, nil)
                end
                private.goldBeforeBMAH = 0
                private.bmahItemName = nil
            end
        end
    end)

end

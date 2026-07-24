local _, ns = ...

-- ============================================================================
-- MiscTracker
-- ============================================================================
-- Records miscellaneous gold flows that don't belong to a specialist tracker:
-- quest rewards, looted gold, Mythic+ completion, death costs, BMAH, crafting tips.
--
-- Looted gold:
--   Primary: CHAT_MSG_MONEY (YOU_LOOT_* / LOOT_MONEY_SPLIT_*) — mob / boss loot,
--   including auto-loot where LOOT_OPENED never fires.
--   World money objects (delve end piles, etc.): UI_INFO_MESSAGE with
--   ERR_QUEST_REWARD_MONEY_S ("Received %s.") — skipped when that copper is
--   already claimed (real quest turn-ins record via QUEST_TURNED_IN first).
--   Fallback: LOOT_OPENED → LOOT_CLOSED gold delta, minus any copper already
--   claimed from chat during the same loot window (avoids double-count).
-- ============================================================================

ns.MiscTracker = {}
local Module = ns.MiscTracker

local private = {
    lootOpen = false,
    goldBeforeLoot = 0,
    lootChatCopper = 0,
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

-- Player-only loot money formats. Skip LOOT_MONEY ("%s loots %s") so other
-- party members' loot is not attributed to this character.
-- More-specific formats (guild cut / bonus) must come before the bare
-- YOU_LOOT_MONEY / LOOT_MONEY_SPLIT patterns — those use a greedy (.+) capture
-- that would otherwise swallow the parenthetical and mis-parse copper.
local PLAYER_LOOT_MONEY_FORMATS = {
    YOU_LOOT_MONEY_GUILD,
    YOU_LOOT_MONEY_MOD,
    LOOT_MONEY_SPLIT_GUILD,
    LOOT_MONEY_SPLIT_MOD,
    YOU_LOOT_MONEY,
    LOOT_MONEY_SPLIT,
    ERR_AUTOLOOT_MONEY_S,
}

local MOD_LOOT_FORMATS = {
    [YOU_LOOT_MONEY_MOD] = true,
    [LOOT_MONEY_SPLIT_MOD] = true,
}

local PATTERN_MAGIC = {
    ["^"] = true, ["$"] = true, ["("] = true, [")"] = true, ["%"] = true,
    ["."] = true, ["["] = true, ["]"] = true, ["*"] = true, ["+"] = true,
    ["-"] = true, ["?"] = true,
}

--- Convert a Blizzard GlobalStrings format (`%s` / `%d` / `%1$s`) into a
--- Lua pattern with captures. Built char-by-char to avoid %%-escaping bugs.
---@param fmt string
---@return string
local function FormatToCapturePattern(fmt)
    local out = {}
    local i = 1
    local len = #fmt
    while i <= len do
        local ch = fmt:sub(i, i)
        if ch == "%" and i < len then
            local next1 = fmt:sub(i + 1, i + 1)
            -- Positional: %1$s / %2$d
            if next1:match("%d") and fmt:sub(i + 2, i + 2) == "$" and i + 3 <= len then
                local spec = fmt:sub(i + 3, i + 3)
                if spec == "s" then
                    out[#out + 1] = "(.+)"
                else
                    out[#out + 1] = "([%d,]+)"
                end
                i = i + 4
            elseif next1 == "s" then
                out[#out + 1] = "(.+)"
                i = i + 2
            elseif next1 == "d" then
                out[#out + 1] = "([%d,]+)"
                i = i + 2
            elseif next1 == "%" then
                out[#out + 1] = "%%"
                i = i + 2
            else
                out[#out + 1] = "%" .. next1
                i = i + 2
            end
        elseif PATTERN_MAGIC[ch] then
            out[#out + 1] = "%" .. ch
            i = i + 1
        else
            out[#out + 1] = ch
            i = i + 1
        end
    end
    return table.concat(out)
end

---@param coinText string|nil
---@return number|nil copper
local function ParseCoinText(coinText)
    if not coinText or coinText == "" then
        return nil
    end

    local copper = 0
    local found = false

    local function take(amountStr, perUnit)
        if not amountStr then
            return
        end
        local n = tonumber((amountStr:gsub(",", "")))
        if n then
            copper = copper + n * perUnit
            found = true
        end
    end

    take(coinText:match(FormatToCapturePattern(GOLD_AMOUNT)), COPPER_PER_GOLD)
    take(coinText:match(FormatToCapturePattern(SILVER_AMOUNT)), COPPER_PER_SILVER)
    take(coinText:match(FormatToCapturePattern(COPPER_AMOUNT)), 1)

    return found and copper or nil
end

---@param text string
---@return number|nil copper
local function ParsePlayerLootMoney(text)
    if not text or text == "" then
        return nil
    end

    for i = 1, #PLAYER_LOOT_MONEY_FORMATS do
        local fmt = PLAYER_LOOT_MONEY_FORMATS[i]
        local a, b = text:match(FormatToCapturePattern(fmt))
        if a then
            local amount = ParseCoinText(a)
            if amount and amount > 0 then
                -- MOD forms: second capture is a bonus that also hits the wallet.
                -- GUILD forms: second capture is guild-bank deposit — ignore it.
                if b and MOD_LOOT_FORMATS[fmt] then
                    local bonus = ParseCoinText(b)
                    if bonus then
                        amount = amount + bonus
                    end
                end
                return amount
            end
        end
    end

    return nil
end

local function RecordLootedGold(amount)
    ns.Transactions:RecordIncome("loot_money", amount, "Loot", nil, "Looted Gold", nil, nil)
end

--- Record looted gold unless a specialist already claimed this copper (e.g. quest
--- reward). Returns true when a new loot_money row was written.
---@param amount number|nil
---@return boolean
local function TryRecordLootedGold(amount)
    if not amount or amount <= 0 then
        return false
    end
    if ns.Transactions:HasClaimForAmount(amount) then
        return false
    end
    RecordLootedGold(amount)
    if private.lootOpen then
        private.lootChatCopper = private.lootChatCopper + amount
    end
    return true
end

---@param message string|nil
---@return number|nil copper
local function ParseReceivedMoneyMessage(message)
    if not message or message == "" then
        return nil
    end
    local coinText = message:match(FormatToCapturePattern(ERR_QUEST_REWARD_MONEY_S))
    return ParseCoinText(coinText)
end

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("LOOT_CLOSED")
    frame:RegisterEvent("CHAT_MSG_MONEY")
    frame:RegisterEvent("UI_INFO_MESSAGE")
    frame:RegisterEvent("PLAYER_DEAD")
    frame:RegisterEvent("PLAYER_UNGHOST")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

    frame:RegisterEvent("BLACK_MARKET_BID_RESULT")
    frame:RegisterEvent("BLACK_MARKET_OPEN")
    frame:RegisterEvent("CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "QUEST_TURNED_IN" then
            local questID, _, moneyReward = ...
            if moneyReward and moneyReward > 0 then
                local title = C_QuestLog.GetTitleForQuestID(questID) or "Quest Reward"
                ns.Transactions:RecordIncome("quest_reward", moneyReward, "Quest", tostring(questID), title, nil, nil)
            end

        elseif event == "CHALLENGE_MODE_COMPLETED" then
            private.mythicPending = true
            private.goldBeforeMythic = GetMoney()
            private.mythicPendingTime = GetServerTime()

        elseif event == "CHAT_MSG_MONEY" then
            TryRecordLootedGold(ParsePlayerLootMoney(...))

        elseif event == "UI_INFO_MESSAGE" then
            local errorType, message = ...
            if errorType == LE_GAME_ERR_QUEST_REWARD_MONEY_S then
                TryRecordLootedGold(ParseReceivedMoneyMessage(message))
            end

        elseif event == "LOOT_OPENED" then
            private.lootOpen = true
            private.goldBeforeLoot = GetMoney()
            private.lootChatCopper = 0

        elseif event == "LOOT_CLOSED" then
            if private.lootOpen then
                local gained = GetMoney() - private.goldBeforeLoot
                local remaining = gained - private.lootChatCopper
                if remaining > 1 then
                    RecordLootedGold(remaining)
                end
            end
            private.lootOpen = false
            private.goldBeforeLoot = 0
            private.lootChatCopper = 0

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

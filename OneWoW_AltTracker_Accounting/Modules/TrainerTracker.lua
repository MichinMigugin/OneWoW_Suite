local _, ns = ...

ns.TrainerTracker = {}
local Module = ns.TrainerTracker

local private = {
    goldBefore = 0,
    pendingSkillName = nil,
    pendingSkillTime = 0,
    currentConfirmation = nil,
    currentRecipes = nil,
}

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_SKILL")
    frame:RegisterEvent("PLAYER_MONEY")

    frame:SetScript("OnEvent", function(_, event, ...)
        Module:HandleEvent(event, ...)
    end)

    -- NEW_RECIPE_LEARNED is owned by OneWoW.ProfessionRecipe. Its learned channel
    -- is immediate and un-gated (trainer purchases open the trainer window, not
    -- the trade-skill window, so the ready-gated scan channel never fires here).
    OneWoW.ProfessionRecipe.RegisterLearnedCallback("Accounting_TrainerTracker", function(recipeID)
        Module:OnRecipeLearned(recipeID)
    end)

    C_Timer.After(1, function()
        private.goldBefore = GetMoney()
    end)
end

function Module:OnRecipeLearned(spellID)
    if not spellID then return end
    if private.currentRecipes then
        local spellName = C_Spell.GetSpellName(spellID)
        table.insert(private.currentRecipes, spellName or ("Spell " .. tostring(spellID)))
    end
    if private.currentConfirmation then
        private.currentConfirmation.confirmed = true
    end
end

function Module:HandleEvent(event, ...)
    if event == "CHAT_MSG_SKILL" then
        local msg = ...
        local extracted = msg:match("You have gained the (.+)%.$")
            or msg:match("You have gained the (.+)")
        if extracted then
            private.pendingSkillName = extracted
            private.pendingSkillTime = GetServerTime()
        end

    elseif event == "PLAYER_MONEY" then
        local goldNow = GetMoney()
        local cost = private.goldBefore - goldNow

        private.goldBefore = goldNow

        if cost <= 0 then return end

        local skillName = nil
        if private.pendingSkillName and (GetServerTime() - private.pendingSkillTime) <= 2 then
            skillName = private.pendingSkillName
        end
        private.pendingSkillName = nil
        private.pendingSkillTime = 0

        local myConfirmation = {
            confirmed = (skillName ~= nil),
            name = nil,
        }
        local myRecipes = {}

        private.currentConfirmation = myConfirmation
        private.currentRecipes = myRecipes

        C_Timer.After(0.3, function()
            -- NEW_RECIPE_LEARNED is locale-independent confirmation.
            -- CHAT_MSG_SYSTEM "You have learned/gained" is English-only fallback.
            if #myRecipes > 0 then
                myConfirmation.confirmed = true
            end

            if not myConfirmation.confirmed then return end

            local finalName
            local itemKey

            if skillName then
                -- Tier unlock: CHAT_MSG_SKILL gave us the skill name
                finalName = skillName
                itemKey = skillName
            elseif #myRecipes == 1 then
                -- Single recipe learned: use the spell name as both key and display
                finalName = myRecipes[1]
                itemKey = myRecipes[1]
            elseif #myRecipes > 1 then
                -- Multiple recipes in one purchase (bundle)
                finalName = myRecipes[1]
                itemKey = myRecipes[1]
            elseif myConfirmation.name then
                finalName = myConfirmation.name
                itemKey = myConfirmation.name
            else
                -- Confirmed trainer spend (CHAT_MSG_SYSTEM matched) but no recipe name
                local ts = tostring(GetServerTime())
                finalName = "Loss Detected"
                itemKey = "loss_" .. ts
            end

            local notes = nil
            if #myRecipes > 1 then
                local lines = {"Includes:"}
                for _, name in ipairs(myRecipes) do
                    table.insert(lines, "- " .. name)
                end
                notes = table.concat(lines, "\n")
            end

            ns.Transactions:RecordExpense("trainer_purchase", cost, "Trainer", itemKey, finalName, nil, notes)
        end)
    end
end

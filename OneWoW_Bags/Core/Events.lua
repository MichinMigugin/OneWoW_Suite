local _, OneWoW_Bags = ...

OneWoW_Bags.Events = {}
OneWoW_Bags.Events.dirtyBags = {}

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" then
        local bagID = ...
        OneWoW_Bags.Events.dirtyBags[bagID] = true

    elseif event == "BAG_UPDATE_DELAYED" then
        local dirty = OneWoW_Bags.Events.dirtyBags
        OneWoW_Bags.Events.dirtyBags = {}
        if OneWoW_Bags.SearchEngine then
            OneWoW_Bags.SearchEngine:ClearTooltipCache()
        end
        OneWoW_Bags:ProcessBagUpdate(dirty)

    elseif event == "ITEM_LOCK_CHANGED" then
        local bagID, slotID = ...
        OneWoW_Bags:OnItemLockChanged(bagID, slotID)

    elseif event == "BAG_UPDATE_COOLDOWN" then
        OneWoW_Bags:OnCooldownUpdate()

    elseif event == "PLAYER_LOGIN" then
        OneWoW_Bags:OnPlayerLogin()

    elseif event == "QUEST_ACCEPTED" then
        local dirty = {}
        for i = 0, 5 do
            dirty[i] = true
        end
        OneWoW_Bags:ProcessBagUpdate(dirty)

    elseif event == "QUEST_REMOVED" then
        local dirty = {}
        for i = 0, 5 do
            dirty[i] = true
        end
        OneWoW_Bags:ProcessBagUpdate(dirty)

    elseif event == "BANKFRAME_OPENED" then
        OneWoW_Bags:OnBankOpened()

    elseif event == "BANKFRAME_CLOSED" then
        OneWoW_Bags:OnBankClosed()

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactType = ...
        if interactType == Enum.PlayerInteractionType.GuildBanker then
            OneWoW_Bags:OnGuildBankOpened()
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactType = ...
        if interactType == Enum.PlayerInteractionType.GuildBanker then
            OneWoW_Bags:OnGuildBankClosed()
        end

    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        OneWoW_Bags:OnGuildBankSlotsChanged()

    elseif event == "GUILDBANK_UPDATE_TABS" then
        OneWoW_Bags:OnGuildBankTabsUpdated()

    elseif event == "GUILDBANK_UPDATE_MONEY" then
        if OneWoW_Bags.GuildBankBar then
            OneWoW_Bags.GuildBankBar:UpdateGold()
        end

    elseif event == "GUILDBANK_UPDATE_WITHDRAWMONEY" then
        if OneWoW_Bags.GuildBankBar then
            OneWoW_Bags.GuildBankBar:UpdateWithdrawButton()
        end

    elseif event == "PLAYER_MONEY" then
        if OneWoW_Bags.bankOpen and OneWoW_Bags.BankBar then
            OneWoW_Bags.BankBar:UpdateGold()
        end

    elseif event == "ACCOUNT_MONEY" then
        if OneWoW_Bags.bankOpen and OneWoW_Bags.BankBar then
            OneWoW_Bags.BankBar:UpdateGold()
        end
    end
end)

function OneWoW_Bags.Events:RegisterBagEvents()
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:RegisterEvent("QUEST_REMOVED")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("BANKFRAME_CLOSED")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    eventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    eventFrame:RegisterEvent("GUILDBANK_UPDATE_TABS")
    eventFrame:RegisterEvent("GUILDBANK_UPDATE_MONEY")
    eventFrame:RegisterEvent("GUILDBANK_UPDATE_WITHDRAWMONEY")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:RegisterEvent("ACCOUNT_MONEY")
end

function OneWoW_Bags.Events:UnregisterBagEvents()
    eventFrame:UnregisterEvent("BAG_UPDATE")
    eventFrame:UnregisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
    eventFrame:UnregisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:UnregisterEvent("QUEST_ACCEPTED")
    eventFrame:UnregisterEvent("QUEST_REMOVED")
end

OneWoW_Bags.Events:RegisterBagEvents()

local _, OneWoW_Bags = ...

local BagTypes = OneWoW_Bags.BagTypes

OneWoW_Bags.Events = {}
local Events = OneWoW_Bags.Events

Events.dirtyBags = {}
Events.RuntimeEvents = {
    "PLAYER_LOGIN",
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "ITEM_LOCK_CHANGED",
    "BAG_UPDATE_COOLDOWN",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "MERCHANT_SHOW",
    "MERCHANT_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "GUILDBANKBAGSLOTS_CHANGED",
    "GUILDBANK_ITEM_LOCK_CHANGED",
    "GUILDBANK_UPDATE_TABS",
    "GUILDBANK_UPDATE_MONEY",
    "GUILDBANK_UPDATE_WITHDRAWMONEY",
    "PLAYER_MONEY",
    "ACCOUNT_MONEY",
    "EQUIPMENT_SETS_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED",
    "GET_ITEM_INFO_RECEIVED",
}

local predicateRefreshPending = false

function Events:OnPredicateInvalidation()
    OneWoW_Bags:InvalidateCategorization("props")

    -- when game downloads item data for uncached items, stale visuals can persist - coalesce them until next frame.
    -- similar pattern as BAG_UPDATE -> BAG_UPDATE_DELAYED
    if not predicateRefreshPending then
        predicateRefreshPending = true
        C_Timer.After(0, function()
            predicateRefreshPending = false
            OneWoW_Bags:RequestLayoutRefresh("all")
        end)
    end
end

local function BuildAllBagDirtySet()
    local dirty = {}
    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        dirty[bagID] = true
    end
    return dirty
end

function Events:OnBagUpdate(bagID)
    self.dirtyBags[bagID] = true
end

function Events:OnBagUpdateDelayed()
    local dirty = self.dirtyBags
    self.dirtyBags = {}
    OneWoW_Bags:InvalidateCategorization("props")
    OneWoW_Bags:ProcessBagUpdate(dirty)
end

function Events:OnItemLockChanged(bagID, slotID)
    OneWoW_Bags:OnItemLockChanged(bagID, slotID)
end

function Events:OnCooldownUpdate()
    OneWoW_Bags:OnCooldownUpdate()
end

function Events:OnQuestAccepted()
    OneWoW_Bags:ProcessBagUpdate(BuildAllBagDirtySet())
end

function Events:OnQuestRemoved()
    OneWoW_Bags:ProcessBagUpdate(BuildAllBagDirtySet())
end

function Events:OnBankOpened()
    OneWoW_Bags:OnBankOpened()
end

function Events:OnBankClosed()
    OneWoW_Bags:OnBankClosed()
end

function Events:OnMerchantShow()
    OneWoW_Bags:OnMerchantShow()
end

function Events:OnMerchantClosed()
    OneWoW_Bags:OnMerchantClosed()
end

function Events:OnPlayerInteractionShow(interactType)
    if interactType == Enum.PlayerInteractionType.GuildBanker then
        OneWoW_Bags:OnGuildBankOpened()
    end
end

function Events:OnPlayerInteractionHide(interactType)
    if interactType == Enum.PlayerInteractionType.GuildBanker then
        OneWoW_Bags:OnGuildBankClosed()
    end
end

function Events:OnGuildBankSlotsChanged(...)
    OneWoW_Bags:OnGuildBankSlotsChanged(...)
end

function Events:OnGuildBankItemLockChanged(...)
    OneWoW_Bags:OnGuildBankItemLockChanged(...)
end

function Events:OnGuildBankTabsUpdated()
    OneWoW_Bags:OnGuildBankTabsUpdated()
end

function Events:OnGuildBankMoneyUpdated()
    OneWoW_Bags:OnGuildBankMoneyUpdated()
end

function Events:OnGuildBankWithdrawMoneyUpdated()
    OneWoW_Bags:OnGuildBankWithdrawMoneyUpdated()
end

function Events:OnPlayerMoney()
    OneWoW_Bags:OnPlayerMoney()
end

function Events:OnAccountMoney()
    OneWoW_Bags:OnAccountMoney()
end


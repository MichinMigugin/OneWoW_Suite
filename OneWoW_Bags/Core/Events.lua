local _, OneWoW_Bags = ...

local BagTypes = OneWoW_Bags.BagTypes

OneWoW_Bags.Events = {}
local Events = OneWoW_Bags.Events

Events.dirtyBags = {}
Events.RuntimeEvents = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "ITEM_LOCK_CHANGED",
    "BAG_UPDATE_COOLDOWN",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "BANK_TABS_CHANGED",
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
    "SKILL_LINES_CHANGED",
}

local predicateRefreshPending = false
local pendingItemIDs = nil

-- Fires on infrequent, broad predicate changes (EQUIPMENT_SETS_CHANGED,
-- PLAYER_EQUIPMENT_CHANGED). These affect upgrade/unusable overlays and
-- equipment-set membership across every slot, so a full coalesced visual
-- refresh is appropriate.
function Events:OnPredicateInvalidation()
    OneWoW_Bags:InvalidateCategorization("props")

    if not predicateRefreshPending then
        predicateRefreshPending = true
        C_Timer.After(0, function()
            predicateRefreshPending = false
            local refreshBags = OneWoW_Bags.GUI:IsShown()
            local refreshBankRelated = OneWoW_Bags.bankOpen or OneWoW_Bags.guildBankOpen

            if refreshBags and refreshBankRelated then
                OneWoW_Bags:RequestVisualRefresh("all")
            elseif refreshBankRelated then
                OneWoW_Bags:RequestVisualRefresh("bank_related")
            elseif refreshBags then
                OneWoW_Bags:RequestVisualRefresh("bags")
            end
        end)
    end
end

-- Fires per-item as the client streams item data. Using the broad visual
-- refresh path here rebuilds every slot on every event, causing flashing
-- when the server re-queries items (e.g. failed Warband soulbound inserts).
-- Instead, coalesce itemIDs until next frame and re-render only the slots
-- holding those specific items. UpdateSlotsForItemIDs now emits its own
-- per-set layout refreshes for any set that actually matched, so we no
-- longer issue a blanket "all" refresh here.
--
-- Cache invalidation: surgical per-itemID eviction is also coalesced into
-- the next-frame batch (InvalidateItemIDs). The previous bulk
-- InvalidateCategorization("props") per event was throwing away the
-- identity-tier caches for unrelated items in the same cold-streaming
-- window; with the batched surgical eviction, only the items whose data
-- actually arrived get re-resolved.
function Events:OnItemInfoReceived(itemID)
    if not itemID then return end
    local Profile = OneWoW_Bags.Profile

    if not pendingItemIDs then
        pendingItemIDs = {}
        C_Timer.After(0, function()
            local ids = pendingItemIDs
            pendingItemIDs = nil
            if Profile then
                local n = 0
                for _ in pairs(ids) do n = n + 1 end
                -- Marker name encodes the batch size so the dump shows the
                -- distribution of flush sizes naturally (one row per size).
                local sizeKey = "Events:OnItemInfoReceived.flush.size=" .. tostring(n)
                Profile:Start(sizeKey)
                Profile:Stop(sizeKey)
            end
            OneWoW_Bags:InvalidateItemIDs(ids)
            OneWoW_Bags:UpdateSlotsForItemIDs(ids)
        end)
    end

    if Profile then
        if pendingItemIDs[itemID] then
            Profile:Start("Events:OnItemInfoReceived.duplicateInBatch")
            Profile:Stop("Events:OnItemInfoReceived.duplicateInBatch")
        else
            Profile:Start("Events:OnItemInfoReceived.newInBatch")
            Profile:Stop("Events:OnItemInfoReceived.newInBatch")
        end
    end
    pendingItemIDs[itemID] = true
end

local function BuildAllBagDirtySet()
    local dirty = {}
    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        dirty[bagID] = true
    end
    return dirty
end

function Events:OnPlayerEnteringWorld(isLogin)
    if isLogin then return end

    local addon = OneWoW_Bags
    local function refreshVisible(reason)
        if addon.GUI and addon.GUI.IsShown and addon.GUI:IsShown()
            and addon.BagSet and addon.BagSet.isBuilt then
            addon:RequestLayoutRefresh("bags", reason)
        end
        if addon.bankOpen and addon.BankGUI and addon.BankGUI.IsShown and addon.BankGUI:IsShown()
            and addon.BankSet and addon.BankSet.isBuilt then
            addon:RequestLayoutRefresh("bank", reason)
        end
        if addon.guildBankOpen and addon.GuildBankGUI and addon.GuildBankGUI.IsShown and addon.GuildBankGUI:IsShown()
            and addon.GuildBankSet and addon.GuildBankSet.isBuilt then
            addon:RequestLayoutRefresh("guild", reason)
        end
    end

    refreshVisible("entering_world")
    C_Timer.After(0.1, function()
        refreshVisible("entering_world_delayed")
    end)
end

function Events:OnBagUpdate(bagID)
    self.dirtyBags[bagID] = true
end

function Events:OnBagUpdateDelayed()
    local Profile = OneWoW_Bags.Profile
    if Profile then Profile:Start("Events:OnBagUpdateDelayed") end
    local dirty = self.dirtyBags
    self.dirtyBags = {}
    OneWoW_Bags:InvalidateCategorization("props")
    OneWoW_Bags:ProcessBagUpdate(dirty)
    if Profile then Profile:Stop("Events:OnBagUpdateDelayed") end
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

function Events:OnBankTabsChanged(bankType)
    OneWoW_Bags:OnBankTabsChanged(bankType)
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

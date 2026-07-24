local _, ns = ...

local format = string.format
local ipairs = ipairs
local GetTime = GetTime
local C_Timer = C_Timer
local BagTypes = OneWoW.Inventory.BagTypes
local C_Container = C_Container

ns.Events = {}
local Events = ns.Events

Events.RuntimeEvents = {
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    -- BAG_* / BANKFRAME_* / ITEM_LOCK / BAG_CONTAINER / BANK_TABS and
    -- GUILDBANK* route through OneWoW.Inventory; see ns:RegisterRuntimeEvents.
    "PLAYER_MONEY",
    "ACCOUNT_MONEY",
    "EQUIPMENT_SETS_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED",
    "GET_ITEM_INFO_RECEIVED",
    "SKILL_LINES_CHANGED",
    "PLAYER_LEVEL_UP",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
}

local predicateRefreshPending = false
local pendingItemIDs = nil
local itemInfoFlushArmed = false
local itemInfoFirstEnqueue = nil
local itemInfoLastEnqueue = nil

-- Trailing-debounce window for GET_ITEM_INFO_RECEIVED. On a cold open the
-- client streams item data in many small waves across consecutive frames.
-- Flushing on C_Timer.After(0) turned each wave into its own full relayout;
-- waiting for a short lull collapses the whole burst into one or two.
local ITEM_INFO_DEBOUNCE = 0.1
-- Hard cap so a continuous trickle of events still flushes periodically
-- instead of being starved by the trailing reset.
local ITEM_INFO_MAX_WAIT = 0.3

-- Fires on infrequent, broad predicate changes (EQUIPMENT_SETS_CHANGED,
-- PLAYER_EQUIPMENT_CHANGED). These affect upgrade/unusable overlays and
-- equipment-set membership across every slot, so a full coalesced visual
-- refresh is appropriate.
function Events:OnPredicateInvalidation()
    ns:InvalidateCategorization("props")

    if not predicateRefreshPending then
        predicateRefreshPending = true
        C_Timer.After(0, function()
            predicateRefreshPending = false
            local refreshBags = ns.GUI:IsShown()
            local refreshBankRelated = ns.bankOpen or ns.guildBankOpen

            if refreshBags and refreshBankRelated then
                ns:RequestVisualRefresh("all")
            elseif refreshBankRelated then
                ns:RequestVisualRefresh("bank_related")
            elseif refreshBags then
                ns:RequestVisualRefresh("bags")
            end
        end)
    end
end

-- Fires per-item as the client streams item data. Using the broad visual
-- refresh path here rebuilds every slot on every event, causing flashing
-- when the server re-queries items (e.g. failed Warband soulbound inserts).
-- Instead, coalesce itemIDs over a short trailing-debounce window (see
-- FlushItemInfo) and re-render only the slots holding those specific items
-- once the burst settles. UpdateSlotsForItemIDs now emits its own
-- per-set layout refreshes for any set that actually matched, so we no
-- longer issue a blanket "all" refresh here.
--
-- Cache invalidation: surgical per-itemID eviction is also coalesced into
-- the batch (InvalidateItemIDs). The previous bulk
-- InvalidateCategorization("props") per event was throwing away the
-- identity-tier caches for unrelated items in the same cold-streaming
-- window; with the batched surgical eviction, only the items whose data
-- actually arrived get re-resolved.
--
-- Flushing uses a trailing debounce (ITEM_INFO_DEBOUNCE) capped at
-- ITEM_INFO_MAX_WAIT: the burst of cold-streaming waves collapses into a
-- single InvalidateItemIDs + UpdateSlotsForItemIDs pass (one full relayout)
-- instead of one per frame-wave.
local function FlushItemInfo()
    local now = GetTime()
    -- Trailing debounce: if more events arrived within the debounce window
    -- and we haven't hit the hard cap, wait for the remaining quiet time.
    if (now - itemInfoLastEnqueue) < ITEM_INFO_DEBOUNCE
        and (now - itemInfoFirstEnqueue) < ITEM_INFO_MAX_WAIT then
        C_Timer.After(ITEM_INFO_DEBOUNCE - (now - itemInfoLastEnqueue), FlushItemInfo)
        return
    end

    local ids = pendingItemIDs
    pendingItemIDs = nil
    itemInfoFlushArmed = false
    itemInfoFirstEnqueue = nil
    itemInfoLastEnqueue = nil
    if not ids then return end

    local Profile = ns.Profile
    if Profile then
        local n = 0
        for _ in pairs(ids) do n = n + 1 end
        -- Marker name encodes the batch size so the dump shows the
        -- distribution of flush sizes naturally (one row per size).
        local sizeKey = "Events:OnItemInfoReceived.flush.size=" .. tostring(n)
        Profile:Start(sizeKey)
        Profile:Stop(sizeKey)
    end
    ns:InvalidateItemIDs(ids)
    ns:UpdateSlotsForItemIDs(ids)
end

function Events:OnItemInfoReceived(itemID)
    if not itemID then return end
    local Profile = ns.Profile
    local now = GetTime()

    if not pendingItemIDs then
        pendingItemIDs = {}
        itemInfoFirstEnqueue = now
    end
    itemInfoLastEnqueue = now
    if not itemInfoFlushArmed then
        itemInfoFlushArmed = true
        C_Timer.After(ITEM_INFO_DEBOUNCE, FlushItemInfo)
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

    local function refreshVisible(reason)
        if ns.GUI and ns.GUI.IsShown and ns.GUI:IsShown()
            and ns.BagSet and ns.BagSet.isBuilt then
            ns:RequestLayoutRefresh("bags", reason)
        end
        if ns.bankOpen and ns.BankGUI and ns.BankGUI.IsShown and ns.BankGUI:IsShown()
            and ns.BankSet and ns.BankSet.isBuilt then
            ns:RequestLayoutRefresh("bank", reason)
        end
        if ns.guildBankOpen and ns.GuildBankGUI and ns.GuildBankGUI.IsShown and ns.GuildBankGUI:IsShown()
            and ns.GuildBankSet and ns.GuildBankSet.isBuilt then
            ns:RequestLayoutRefresh("guild", reason)
        end
    end

    local LD = ns.LayoutDebug
    if LD and LD.enabled then
        local bagsShown = ns.GUI and ns.GUI.IsShown and ns.GUI:IsShown()
        local bankShown = ns.bankOpen and ns.BankGUI and ns.BankGUI.IsShown and ns.BankGUI:IsShown()
        local guildShown = ns.guildBankOpen and ns.GuildBankGUI and ns.GuildBankGUI.IsShown and ns.GuildBankGUI:IsShown()
        LD:Record("entering_world", {
            note = format("bags=%s bank=%s guild=%s", tostring(bagsShown), tostring(bankShown), tostring(guildShown)),
        })
    end

    -- A loading screen can drop the pending zero-delay flush timer and wedge
    -- the refreshScheduled latch. Reset it so any pending bag work flushes.
    ns:KickLayoutScheduler()

    refreshVisible("entering_world")
    C_Timer.After(0.1, function()
        refreshVisible("entering_world_delayed")
    end)
end

--- @param dirty table|nil bagID -> true from Inventory delayed channel
function Events:OnBagUpdateDelayed(dirty)
    local Profile = ns.Profile
    if Profile then Profile:Start("Events:OnBagUpdateDelayed") end
    dirty = dirty or {}
    -- Category caches refresh here. PE props were already wiped by Inventory
    -- on the delayed fan-out; InvalidateCategorization("props") is still needed
    -- for Bags categoryCache / recent-item state (and re-wipes PE harmlessly).
    ns:InvalidateCategorization("props")
    ns:ProcessBagUpdate(dirty)

    local playerBagsDirty = false
    for bagID in pairs(dirty) do
        if BagTypes:IsPlayerBag(bagID) then
            playerBagsDirty = true
            break
        end
    end
    if playerBagsDirty then
        self:SyncUnequippedBagFilters()
        self:RefreshBagBarIcons()
    end

    if Profile then Profile:Stop("Events:OnBagUpdateDelayed") end
end

---@param inventorySlot number
---@return number|nil bagIndex
function Events:GetBagIndexForInventorySlot(inventorySlot)
    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        if BagTypes:IsSwappableBag(bagID) then
            local invSlot = C_Container.ContainerIDToInventoryID(bagID)
            if invSlot == inventorySlot then
                return bagID
            end
        end
    end
    return nil
end

function Events:RefreshBagBarIcons()
    local BagsBar = ns.BagsBar
    if BagsBar then
        BagsBar:UpdateIcons()
    end
end

function Events:SyncUnequippedBagFilters()
    local controller = ns.BagsController
    if not controller then
        return
    end
    local selected = ns:GetDB().global.selectedBag
    if selected ~= nil and not BagTypes:IsBagEquipped(selected) then
        controller:OnBagUnequipped(selected)
    end
end

--- Rebuild BagSet slots when equipped container count diverges from cached buttons.
--- Bag pickup from Blizzard's bar can fire PLAYER_EQUIPMENT_CHANGED without BAG_UPDATE_DELAYED.
function Events:SyncPlayerBagSetSlots()
    local BagSet = ns.BagSet
    if not BagSet.isBuilt then
        return
    end

    local dirty = {}
    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        if BagTypes:IsSwappableBag(bagID) and BagSet.slots[bagID] then
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            local currentCount = 0
            for _ in pairs(BagSet.slots[bagID]) do
                currentCount = currentCount + 1
            end
            if currentCount ~= numSlots then
                dirty[bagID] = true
            end
        end
    end

    if next(dirty) then
        ns:InvalidateCategorization("props")
        ns:ProcessBagUpdate(dirty)
    end
end

---@param bagIndex number
function Events:OnPlayerBagEquipmentChanged(bagIndex)
    local dirty = { [bagIndex] = true }
    ns:InvalidateCategorization("props")
    ns:ProcessBagUpdate(dirty)
    self:SyncUnequippedBagFilters()
    self:RefreshBagBarIcons()
end

---@param inventorySlot number
function Events:OnPlayerEquipmentChanged(inventorySlot)
    local bagIndex = self:GetBagIndexForInventorySlot(inventorySlot)
    if not bagIndex then
        return
    end
    self:OnPlayerBagEquipmentChanged(bagIndex)
end

function Events:OnBagContainerUpdate()
    self:SyncPlayerBagSetSlots()
    self:SyncUnequippedBagFilters()
    self:RefreshBagBarIcons()
end

function Events:OnItemLockChanged(bagID, slotID)
    ns:OnItemLockChanged(bagID, slotID)
end

function Events:OnCooldownUpdate()
    ns:OnCooldownUpdate()
end

function Events:OnQuestAccepted()
    ns:ProcessBagUpdate(BuildAllBagDirtySet())
end

function Events:OnQuestRemoved()
    ns:ProcessBagUpdate(BuildAllBagDirtySet())
end

function Events:OnBankOpened()
    ns:OnBankOpened()
end

function Events:OnBankClosed()
    ns:OnBankClosed()
end

function Events:OnBankTabsChanged(bankType)
    ns:OnBankTabsChanged(bankType)
end

function Events:OnMerchantShow()
    ns:OnMerchantShow()
end

function Events:OnMerchantClosed()
    ns:OnMerchantClosed()
end

function Events:OnGuildBankOpened()
    ns:OnGuildBankOpened()
end

function Events:OnGuildBankClosed()
    ns:OnGuildBankClosed()
end

function Events:OnGuildBankSlotsChanged(...)
    ns:OnGuildBankSlotsChanged(...)
end

function Events:OnGuildBankItemLockChanged(...)
    ns:OnGuildBankItemLockChanged(...)
end

function Events:OnGuildBankTabsUpdated()
    ns:OnGuildBankTabsUpdated()
end

function Events:OnGuildBankMoneyUpdated()
    ns:OnGuildBankMoneyUpdated()
end

function Events:OnGuildBankWithdrawMoneyUpdated()
    ns:OnGuildBankWithdrawMoneyUpdated()
end

function Events:OnPlayerMoney()
    ns:OnPlayerMoney()
end

function Events:OnAccountMoney()
    ns:OnAccountMoney()
end

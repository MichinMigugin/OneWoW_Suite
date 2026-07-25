local _, ns = ...

-- ============================================================================
-- Overlays 2.0 — surfaces
-- ============================================================================
-- All Blizzard-UI hook points and refresh passes: bags, bank (character +
-- Warband), guild bank (Inventory guild-slots + frame hooks), vendor, mail,
-- loot, group loot, quest rewards,
-- Auction House, Encounter Journal, Black Market, Great Vault, and world
-- quest map pins.
--
-- Fixes over the 1.0 surface wiring:
--   * Every throttle COALESCES (pending-reschedule) instead of dropping
--     concurrent requests — the 1.0 bank throttle dropped the second call,
--     which left stale visuals after "Cleanup Warband Bank".
--   * The bank listens to Inventory delayed callbacks while open, and
--     repaints only the selected tab on per-bag dirty callbacks (deposit
--     lag fix). Bag/bank WoW events are owned by OneWoW.Inventory.
--   * No INVENTORY_SEARCH_UPDATE / ItemContextOverlay mirroring at all;
--     Blizzard's own dim layer is never read or copied.
--   * After each bank paint, re-run UpdateItemContextMatching (immediate +
--     deferred). BankDepositing can evaluate IsItemAllowedInBankType too
--     early (Mismatch + ItemContextOverlay stuck) while allow-state is still
--     false; later allowed=true never clears the overlay without a re-sync.
--   * Collection/journal/recipe events call Engine:InvalidateAndRequestRefresh
--     (not bare RequestRefresh) so known/missing icons cannot stick behind
--     same-item skip_same. Surface layout still uses RequestRefresh.
-- ============================================================================

local Engine = ns.OverlayEngine
local Renderer = ns.Overlays2Renderer

local ipairs, pairs = ipairs, pairs

local function ProcessButton(button, link, location, context)
    Engine:ProcessButton(button, link, location, context)
end

local function CleanButton(button)
    Renderer:CleanButton(button)
end

-- ----------------------------------------------------------------------------
-- Bags
-- ----------------------------------------------------------------------------

-- Per-container coalescing throttle: a request during a running pass marks
-- "pending" and reschedules one more pass after the window.
local bagThrottle = {}

local function ProcessBagContainer(container)
    if not container then return end

    local key = tostring(container)
    if bagThrottle[key] then
        bagThrottle[key] = "pending"
        return
    end

    bagThrottle[key] = "running"

    if container.Items then
        for _, itemButton in ipairs(container.Items) do
            if itemButton and itemButton:IsVisible() then
                local bagID  = itemButton.GetBagID and itemButton:GetBagID()
                local slotID = itemButton.GetID and itemButton:GetID()
                if bagID and slotID then
                    local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
                    if C_Item.DoesItemExist(loc) then
                        local link = C_Item.GetItemLink(loc)
                        if link then
                            ProcessButton(itemButton, link, loc)
                        else
                            CleanButton(itemButton)
                        end
                    else
                        CleanButton(itemButton)
                    end
                end
            end
        end
    end

    C_Timer.After(0.1, function()
        if bagThrottle[key] == "pending" then
            bagThrottle[key] = nil
            ProcessBagContainer(container)
        else
            bagThrottle[key] = nil
        end
    end)
end

local function RefreshBags()
    if ContainerFrameCombinedBags:IsVisible() then
        ProcessBagContainer(ContainerFrameCombinedBags)
    end

    for _, cf in ipairs(ContainerFrameContainer.ContainerFrames or {}) do
        if cf and cf:IsVisible() then
            ProcessBagContainer(cf)
        end
    end

    for i = 1, 13 do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsVisible() then
            ProcessBagContainer(cf)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Bank (character + Warband)
-- ----------------------------------------------------------------------------

local trackedBankButtons = {}
local bankContextSyncPending = false

--- Recompute Blizzard BankDepositing match state on tracked bank buttons.
--- Clears sticky ItemContextOverlay when IsItemAllowedInBankType flipped to
--- true after an early Mismatch evaluation.
local function SyncBankItemContextMatching()
    if not (BankPanel and BankPanel:IsVisible()) then return end
    for btn in pairs(trackedBankButtons) do
        if btn.UpdateItemContextMatching then
            btn:UpdateItemContextMatching()
        end
    end
end

local function QueueBankItemContextSync()
    SyncBankItemContextMatching()
    if bankContextSyncPending then return end
    bankContextSyncPending = true
    C_Timer.After(0.25, function()
        bankContextSyncPending = false
        SyncBankItemContextMatching()
    end)
end

local function PaintBankSlot(btn, containerID, slotID)
    local loc = ItemLocation:CreateFromBagAndSlot(containerID, slotID)
    if C_Item.DoesItemExist(loc) then
        local link = C_Item.GetItemLink(loc)
        if link then
            ProcessButton(btn, link, loc)
        else
            CleanButton(btn)
        end
    else
        CleanButton(btn)
    end
end

local function RefreshBankPass()
    for btn in pairs(trackedBankButtons) do
        CleanButton(btn)
    end
    trackedBankButtons = {}

    if not (BankPanel and BankPanel:IsVisible() and BankPanel.selectedTabID) then return end
    if not BankPanel.FindItemButtonByContainerSlotID then return end

    for i = 1, 98 do
        local btn = BankPanel:FindItemButtonByContainerSlotID(i)
        if btn then
            trackedBankButtons[btn] = true
            PaintBankSlot(btn, BankPanel.selectedTabID, i)
        end
    end

    QueueBankItemContextSync()
end

-- Coalescing throttle (pending-reschedule): unlike the 1.0 bankThrottle,
-- requests arriving during the debounce window are never dropped.
local bankThrottleState = nil -- nil | "scheduled" | "pending"

local function RefreshBank()
    if bankThrottleState then
        bankThrottleState = "pending"
        return
    end
    bankThrottleState = "scheduled"
    C_Timer.After(0.1, function()
        local wasPending = (bankThrottleState == "pending")
        bankThrottleState = nil
        RefreshBankPass()
        if wasPending then
            RefreshBank()
        end
    end)
end

-- Incremental repaint: one bag changed (deposit, cleanup move). Only repaint
-- the bank when the changed container IS the selected bank tab.
local function OnBagUpdate(bagID)
    if not (BankPanel and BankPanel:IsVisible()) then return end
    if BankPanel.selectedTabID ~= bagID then return end
    RefreshBank()
end

-- ----------------------------------------------------------------------------
-- Vendor
-- ----------------------------------------------------------------------------

local vendorPending = false

local function RefreshVendor()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if vendorPending then return end
    vendorPending = true
    C_Timer.After(0.05, function()
        vendorPending = false
        if not MerchantFrame or not MerchantFrame:IsShown() then return end

        if not Engine.IsGlobalEnabled() or not Engine:AnyVendorOverlayEnabled() then
            for i = 1, MERCHANT_ITEMS_PER_PAGE do
                local btn = _G["MerchantItem" .. i]
                if btn then CleanButton(btn.ItemButton or btn) end
            end
            return
        end

        for i = 1, MERCHANT_ITEMS_PER_PAGE do
            local btn = _G["MerchantItem" .. i]
            if btn then
                local index   = i + (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE
                local link    = GetMerchantItemLink(index)
                local itemBtn = btn.ItemButton or btn
                if link then
                    ProcessButton(itemBtn, link, nil, "vendor")
                else
                    CleanButton(itemBtn)
                end
            end
        end
    end)
end

-- ----------------------------------------------------------------------------
-- Guild bank
-- ----------------------------------------------------------------------------

local function RefreshGuildBank()
    if not GuildBankFrame or not GuildBankFrame:IsShown() then return end
    -- OneWoW_Bags replaces the guild bank UI and suppresses the Blizzard frame
    -- via SetAlpha(0) + off-screen park (it stays IsShown()). Painting those
    -- invisible buttons is pure waste (hundreds of paints + item-load requests
    -- per open); the Bags integration path covers its own buttons.
    if GuildBankFrame:GetAlpha() == 0 then return end
    for tab = 1, 7 do
        if GuildBankFrame.Columns and GuildBankFrame.Columns[tab] then
            for slot = 1, 14 do
                local btn = GuildBankFrame.Columns[tab].Buttons and GuildBankFrame.Columns[tab].Buttons[slot]
                if btn then
                    local link = GetGuildBankItemLink(tab, slot)
                    if link then
                        ProcessButton(btn, link, nil)
                    else
                        CleanButton(btn)
                    end
                end
            end
        end
    end
end

-- GuildBankFrame Update/OnShow can still burst; Inventory's guild-slots channel
-- already coalesces GUILDBANKBAGSLOTS_CHANGED (~0.2s). This queue is only for
-- the Blizzard frame hooks (and transmog refresh) that bypass Inventory.
local guildBankRefreshQueued = false
local function QueueRefreshGuildBank()
    if guildBankRefreshQueued then return end
    guildBankRefreshQueued = true
    C_Timer.After(0.2, function()
        guildBankRefreshQueued = false
        RefreshGuildBank()
    end)
end

-- ----------------------------------------------------------------------------
-- Mail
-- ----------------------------------------------------------------------------

local selectedMailIndex = nil

local function RefreshMailbox()
    for i = 1, 7 do
        local btn = _G["MailItem" .. i .. "Button"]
        if btn then
            if btn.hasItem == 1 then
                local _, itemID = GetInboxItem(i, 1)
                if itemID then
                    local _, link = C_Item.GetItemInfo(itemID)
                    if link then
                        ProcessButton(btn, link, nil)
                    else
                        CleanButton(btn)
                    end
                else
                    CleanButton(btn)
                end
            else
                CleanButton(btn)
            end
        end
    end

    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        local btn = _G["OpenMailAttachmentButton" .. i]
        if btn and selectedMailIndex then
            local link = GetInboxItemLink(selectedMailIndex, i)
            if link then
                ProcessButton(btn, link, nil)
            else
                CleanButton(btn)
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Loot
-- ----------------------------------------------------------------------------

local function RefreshGroupLoot()
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame and frame:IsShown() and frame.rollID and frame.IconFrame then
            local link = GetLootRollItemLink(frame.rollID)
            if link then
                ProcessButton(frame.IconFrame, link, nil)
            else
                CleanButton(frame.IconFrame)
            end
        end
    end
end

local function RefreshLootFrame()
    if not LootFrame or not LootFrame:IsShown() then return end
    if LootFrame.ScrollBox and LootFrame.ScrollBox.view and LootFrame.ScrollBox.view.frames then
        for _, frame in next, LootFrame.ScrollBox.view.frames do
            if frame and frame.Item then
                local slotIndex = frame.GetSlotIndex and frame:GetSlotIndex()
                if slotIndex then
                    local link = GetLootSlotLink(slotIndex)
                    if link then
                        ProcessButton(frame.Item, link, nil)
                    else
                        CleanButton(frame.Item)
                    end
                end
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Great Vault
-- ----------------------------------------------------------------------------

local function RefreshGreatVault()
    if WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown() then
        for _, v in pairs(WeeklyRewardsFrame.Activities) do
            ---@cast v { hasRewards: boolean?, info: WeeklyRewardActivityInfo?, ItemFrame: Button? }
            if v and v.hasRewards and v.ItemFrame and v.info and v.info.rewards and v.info.rewards[1] then
                local link = C_WeeklyRewards.GetItemHyperlink(v.info.rewards[1].itemDBID)
                if link then
                    ProcessButton(v.ItemFrame, link, nil)
                else
                    CleanButton(v.ItemFrame)
                end
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- World quest map pins
-- ----------------------------------------------------------------------------

local function RefreshWorldQuestPins()
    if not WorldMapFrame then return end
    C_Timer.After(0.1, function()
        for pin in WorldMapFrame:EnumeratePinsByTemplate("WorldMap_WorldQuestPinTemplate") do
            if pin and pin.questID then
                if not pin.onewow_overlayContainer and pin.GetButton then
                    local btn = pin:GetButton()
                    if btn then
                        Renderer:PresetContainerOnIcon(pin, btn, 0)
                        if pin.onewow_overlayContainer then
                            pin.onewow_overlayContainer:SetScale(0.8)
                        end
                    end
                end
                if pin.onewow_overlayContainer then
                    pin.onewow_overlayContainer:Hide()
                end
                local bestIdx, bestType = QuestUtils_GetBestQualityItemRewardIndex(pin.questID)
                if bestIdx and bestType then
                    local link = GetQuestLogItemLink(bestType, bestIdx, pin.questID)
                    if link then
                        ProcessButton(pin, link, nil)
                    end
                end
            end
        end
    end)
end

-- ----------------------------------------------------------------------------
-- Quest rewards
-- ----------------------------------------------------------------------------

local function ProcessQuestRewardFrame(rewardsFrame, mode)
    if not rewardsFrame or not rewardsFrame.RewardButtons then return end
    for k, v in pairs(rewardsFrame.RewardButtons) do
        local btn = QuestInfo_GetRewardButton(rewardsFrame, k)
        if btn then
            if v.objectType == "currency" or not v.type then
                CleanButton(btn)
            else
                local link
                if mode == "turnin" then
                    if GetQuestID() then
                        C_QuestLog.SetSelectedQuest(GetQuestID())
                    end
                    link = GetQuestLogItemLink(v.type, k)
                elseif rewardsFrame == MapQuestInfoRewardsFrame then
                    link = GetQuestLogItemLink(v.type, k)
                else
                    link = GetQuestItemLink(v.type, k)
                end
                if link then
                    if btn.IconBorder and not btn.onewow_overlayContainer then
                        Renderer:PresetContainerOnIcon(btn, btn.IconBorder, 0)
                    end
                    ProcessButton(btn, link, nil)
                else
                    CleanButton(btn)
                end
            end
        end
    end
end

local function RefreshQuestRewards(mode)
    if QuestInfoRewardsFrame and not (WorldMapFrame and WorldMapFrame:IsShown()) then
        ProcessQuestRewardFrame(QuestInfoRewardsFrame, mode)
        C_Timer.After(1, function() ProcessQuestRewardFrame(QuestInfoRewardsFrame, mode) end)
    end
    if MapQuestInfoRewardsFrame and WorldMapFrame and WorldMapFrame:IsShown() then
        ProcessQuestRewardFrame(MapQuestInfoRewardsFrame, mode)
    end
end

-- ----------------------------------------------------------------------------
-- Wiring
-- ----------------------------------------------------------------------------

Engine:RegisterSurfaceRefresher(RefreshBags)
Engine:RegisterSurfaceRefresher(RefreshBank)
Engine:RegisterSurfaceRefresher(RefreshVendor)

function Engine:RefreshBags() RefreshBags() end
function Engine:RefreshBank() RefreshBank() end
function Engine:RefreshVendor() RefreshVendor() end

local initialized = false

local function InitializeSurfaces()
    if LootFrame and LootFrame.HookScript then
        LootFrame:HookScript("OnShow", RefreshLootFrame)
    end

    if GuildBankFrame then
        if GuildBankFrame.Update then
            hooksecurefunc(GuildBankFrame, "Update", QueueRefreshGuildBank)
        end
        GuildBankFrame:HookScript("OnShow", RefreshGuildBank)
    end

    if InboxPrevPageButton then
        InboxPrevPageButton:HookScript("OnClick", RefreshMailbox)
    end
    if InboxNextPageButton then
        InboxNextPageButton:HookScript("OnClick", RefreshMailbox)
    end
    for i = 1, 7 do
        local btn = _G["MailItem" .. i .. "Button"]
        if btn then
            btn:HookScript("OnClick", function()
                selectedMailIndex = btn.index
                RefreshMailbox()
            end)
        end
    end

    if QuestFrameRewardPanel then
        QuestFrameRewardPanel:HookScript("OnShow", function() RefreshQuestRewards() end)
    end
    if QuestInfoRewardsFrame then
        QuestInfoRewardsFrame:HookScript("OnShow", function() RefreshQuestRewards() end)
    end
    if QuestInfo_Display then
        hooksecurefunc("QuestInfo_Display", function() RefreshQuestRewards() end)
    end
    if QuestMapFrame_ShowQuestDetails then
        hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
            RefreshQuestRewards()
            C_Timer.After(0.1, function() RefreshQuestRewards() end)
        end)
    end

    local ejHooked = false
    local function RegisterEJHook()
        if ejHooked then return end
        if not EncounterJournalEncounterFrameInfo then return end
        if not EncounterJournalEncounterFrameInfo.LootContainer then return end
        if not EncounterJournalEncounterFrameInfo.LootContainer.ScrollBox then return end
        EncounterJournalEncounterFrameInfo.LootContainer.ScrollBox:RegisterCallback("OnAcquiredFrame", function(_, v)
            RunNextFrame(function()
                if not v then return end
                if v.icon and not v.onewow_overlayContainer then
                    Renderer:PresetContainerOnIcon(v, v.icon, 4)
                end
                if v.link then
                    ProcessButton(v, v.link, nil)
                else
                    CleanButton(v)
                end
            end)
        end)
        ejHooked = true
    end
    if EncounterJournal then
        EncounterJournal:HookScript("OnShow", RegisterEJHook)
    end
    local ejEventFrame = CreateFrame("Frame")
    ejEventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
    ejEventFrame:SetScript("OnEvent", function()
        if EncounterJournal and EncounterJournal:IsShown() then
            RegisterEJHook()
        end
    end)

    local ahHooked = false
    local function RegisterAHHook()
        if ahHooked then return end
        if not AuctionHouseFrame then return end
        if not AuctionHouseFrame.BrowseResultsFrame then return end
        if not AuctionHouseFrame.BrowseResultsFrame.ItemList then return end
        if not AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox then return end
        AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox:RegisterCallback("OnAcquiredFrame", function(_, v)
            C_Timer.After(0.1, function()
                if not v then return end
                if not Engine:AnyAHOverlayEnabled() then
                    CleanButton(v)
                    return
                end
                Renderer:PresetContainerFixed(v, v, 36, 36, "LEFT", v, 4, 0)
                local rowData = v.rowData
                if rowData and rowData.itemKey then
                    local itemID = rowData.itemKey.itemID
                    if itemID then
                        local _, link = C_Item.GetItemInfo(itemID)
                        if link then
                            ProcessButton(v, link, nil, "auctionhouse")
                        else
                            CleanButton(v)
                        end
                    end
                else
                    CleanButton(v)
                end
            end)
        end)
        ahHooked = true
    end

    local bmHooked = false
    local function RegisterBMHook()
        if bmHooked then return end
        if not BlackMarketFrame then return end
        if not BlackMarketFrame.ScrollBox then return end
        BlackMarketFrame.ScrollBox:RegisterCallback("OnAcquiredFrame", function(_, v, data)
            C_Timer.After(0.1, function()
                if not v then return end
                if v.Item and not v.onewow_overlayContainer then
                    Renderer:PresetContainerOnIcon(v, v.Item, 0)
                end
                local link = data and data.link
                if link then
                    ProcessButton(v, link, nil)
                else
                    CleanButton(v)
                end
            end)
        end)
        bmHooked = true
    end
    if BlackMarketFrame then
        BlackMarketFrame:HookScript("OnShow", RegisterBMHook)
    end

    if WeeklyRewardsFrame then
        WeeklyRewardsFrame:HookScript("OnShow", function()
            RefreshGreatVault()
            C_Timer.After(1, RefreshGreatVault)
        end)
    end

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", RefreshWorldQuestPins)
        EventRegistry:RegisterCallback("MapCanvas.MapSet", RefreshWorldQuestPins)
    end

    -- NEW_RECIPE_LEARNED is funneled through OneWoW.ProfessionRecipe's learned
    -- channel (un-gated: it fires for trainer / world-drop learns too).
    ns.ProfessionRecipe.RegisterLearnedCallback("OverlayEngine", function()
        Engine:InvalidateAndRequestRefresh()
    end)

    local surfaceEventFrame = CreateFrame("Frame")
    surfaceEventFrame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    surfaceEventFrame:RegisterEvent("NEW_MOUNT_ADDED")
    surfaceEventFrame:RegisterEvent("NEW_PET_ADDED")
    surfaceEventFrame:RegisterEvent("NEW_TOY_ADDED")
    surfaceEventFrame:RegisterEvent("HEIRLOOMS_UPDATED")
    surfaceEventFrame:RegisterEvent("HOUSING_STORAGE_UPDATED")
    surfaceEventFrame:RegisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
    surfaceEventFrame:RegisterEvent("MAIL_SHOW")
    surfaceEventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    surfaceEventFrame:RegisterEvent("QUEST_DETAIL")
    surfaceEventFrame:RegisterEvent("QUEST_COMPLETE")
    surfaceEventFrame:RegisterEvent("START_LOOT_ROLL")
    surfaceEventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    surfaceEventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    surfaceEventFrame:SetScript("OnEvent", function(_, event)
        if event == "TRANSMOG_COLLECTION_UPDATED"
            or event == "NEW_MOUNT_ADDED"
            or event == "NEW_PET_ADDED"
            or event == "NEW_TOY_ADDED"
            or event == "HEIRLOOMS_UPDATED"
            or event == "HOUSING_STORAGE_UPDATED"
            or event == "HOUSING_STORAGE_ENTRY_UPDATED" then
            Engine:InvalidateAndRequestRefresh()
            if event == "TRANSMOG_COLLECTION_UPDATED" then
                C_Timer.After(0.1, RefreshGuildBank)
            end
        elseif event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then
            C_Timer.After(0.1, RefreshMailbox)
        elseif event == "QUEST_DETAIL" then
            RefreshQuestRewards()
        elseif event == "QUEST_COMPLETE" then
            RefreshQuestRewards("turnin")
        elseif event == "START_LOOT_ROLL" then
            RunNextFrame(RefreshGroupLoot)
        elseif event == "WEEKLY_REWARDS_UPDATE" then
            RefreshGreatVault()
            C_Timer.After(1, RefreshGreatVault)
        elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
            RegisterAHHook()
        end
    end)
end

function Engine:Initialize()
    if initialized then return end
    initialized = true

    if ContainerFrameCombinedBags then
        hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", function(container)
            ProcessBagContainer(container)
        end)
    end

    if ContainerFrameContainer then
        for _, cf in ipairs(ContainerFrameContainer.ContainerFrames or {}) do
            if cf then
                hooksecurefunc(cf, "UpdateItems", function(container)
                    ProcessBagContainer(container)
                end)
            end
        end
    end

    for i = 1, 6 do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf.UpdateItems then
            hooksecurefunc(cf, "UpdateItems", function(container)
                ProcessBagContainer(container)
            end)
        end
    end

    if BankPanel then
        if BankPanel.RefreshBankPanel then
            hooksecurefunc(BankPanel, "RefreshBankPanel", function() RefreshBank() end)
        end
        if BankPanel.GenerateItemSlotsForSelectedTab then
            hooksecurefunc(BankPanel, "GenerateItemSlotsForSelectedTab", function() RefreshBank() end)
        end
        if BankPanel.RefreshAllItemsForSelectedTab then
            hooksecurefunc(BankPanel, "RefreshAllItemsForSelectedTab", function() RefreshBank() end)
        end
    end

    if MerchantFrame_Update then
        hooksecurefunc("MerchantFrame_Update", RefreshVendor)
    end

    -- Bag/bank/guild overlay repaints route through the core OneWoW.Inventory
    -- funnel (BAG_* / BANKFRAME_* / guild-slots). GuildBankFrame Update/OnShow
    -- hooks remain for Blizzard-driven paints when the frame is visible.
    ns.Inventory.RegisterDirtyCallback("OverlayEngine", OnBagUpdate)
    ns.Inventory.RegisterDelayedCallback("OverlayEngine", function()
        RefreshBags()
        for _, fn in ipairs(Engine.integrationRefreshCallbacks) do fn() end
        -- Warband/character bank deposits fire BAG_UPDATE_DELAYED too;
        -- the 1.0 engine missed this and left stale slots until reload.
        if BankPanel and BankPanel:IsVisible() then
            RefreshBank()
        end
    end)
    ns.Inventory.RegisterBankOpenCallback("OverlayEngine", RefreshBank)
    ns.Inventory.RegisterBankSlotsCallback("OverlayEngine", function()
        RefreshBank()
    end)
    -- Inventory already coalesces GUILDBANKBAGSLOTS_CHANGED (~0.2s).
    ns.Inventory.RegisterGuildSlotsCallback("OverlayEngine", RefreshGuildBank)

    -- Vendor overlay repaints route through the core OneWoW.Merchant funnel
    -- (single MERCHANT_* owner): show for the instant open refresh, scan for
    -- the coalesced MERCHANT_UPDATE refreshes.
    ns.Merchant.RegisterShowCallback("OverlayEngine", RefreshVendor)
    ns.Merchant.RegisterScanCallback("OverlayEngine", RefreshVendor)

    InitializeSurfaces()
end

ns:RegisterCoreLoginHandler("OverlayEngine", function()
    Engine:Initialize()
    -- Journals can lag first bag paint; one settle pass heals false
    -- "missing" icons without relying on a collection event.
    C_Timer.After(1, function()
        Engine:InvalidateAndRequestRefresh()
    end)
end, "early")

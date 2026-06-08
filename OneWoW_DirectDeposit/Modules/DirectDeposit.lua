local _, OneWoW_DirectDeposit = ...
local L = OneWoW_DirectDeposit.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local PE = OneWoW_GUI.PredicateEngine

OneWoW_DirectDeposit.DirectDeposit = {}
local DirectDeposit = OneWoW_DirectDeposit.DirectDeposit

DirectDeposit.guildBankOpen = false
DirectDeposit.currentOpenBankType = nil
DirectDeposit.bankSessionHandled = false
DirectDeposit.isDepositing = false
DirectDeposit.isPaused = false
DirectDeposit.currentDepositIndex = 0
DirectDeposit.totalDepositItems = 0
DirectDeposit.depositedItems = {}
DirectDeposit.failedItems = {}
DirectDeposit.depositTimers = {}
DirectDeposit.progressCallback = nil

local GUILD_BANK_SLOTS_PER_TAB = 98

function DirectDeposit:Initialize()
    self:RegisterEvents()
    self.initialized = true
end

function DirectDeposit:RegisterEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("BANKFRAME_CLOSED")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "BANKFRAME_OPENED" then
            if not DirectDeposit.guildBankOpen then
                DirectDeposit.currentOpenBankType = "personal"
                DirectDeposit:OnBankOpened()
            end
        elseif event == "BANKFRAME_CLOSED" then
            if DirectDeposit.currentOpenBankType == "personal" then
                DirectDeposit.currentOpenBankType = nil
            end
            DirectDeposit.bankSessionHandled = false
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local interactionType = ...
            if interactionType == Enum.PlayerInteractionType.GuildBanker then
                DirectDeposit.guildBankOpen = true
                DirectDeposit.currentOpenBankType = "guild"
                DirectDeposit:OnBankOpened()
            elseif interactionType == 68 then
                DirectDeposit.currentOpenBankType = "warband"
                DirectDeposit:OnBankOpened()
            elseif interactionType == 67 then
                DirectDeposit.currentOpenBankType = "personal"
                DirectDeposit:OnBankOpened()
            end
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            local interactionType = ...
            if interactionType == Enum.PlayerInteractionType.GuildBanker then
                DirectDeposit.guildBankOpen = false
                DirectDeposit.currentOpenBankType = nil
                DirectDeposit.bankSessionHandled = false
            elseif interactionType == 68 or interactionType == 67 then
                DirectDeposit.currentOpenBankType = nil
                DirectDeposit.bankSessionHandled = false
            end
        end
    end)

    self.eventFrame = eventFrame
end

function DirectDeposit:IsEnabled()
    return OneWoW_DirectDeposit.db.global.directDeposit.enabled == true
end

function DirectDeposit:GetCharacterSettings()
    return OneWoW_DirectDeposit.db.char.directDeposit
end

function DirectDeposit:GetActiveSettings()
    local charSettings = self:GetCharacterSettings()

    if charSettings.useAccountSettings then
        return OneWoW_DirectDeposit.db.global.directDeposit
    else
        return charSettings
    end
end

function DirectDeposit:GetTargetGold()
    local settings = self:GetActiveSettings()
    return settings.targetGold
end

function DirectDeposit:OnBankOpened()
    -- The remote Warband Bank (and some banker NPCs) fire BANKFRAME_OPENED and
    -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW back-to-back in the same frame. Without
    -- this guard the body would run twice before the server has a chance to apply
    -- the first deposit/withdraw, causing C_Bank.DepositMoney / C_Bank.WithdrawMoney
    -- to see stale GetMoney() and double the transfer. One run per bank session.
    if self.bankSessionHandled then
        return
    end
    self.bankSessionHandled = true

    self:SweepWarboundItems()

    if not self:IsEnabled() then
        return
    end

    self:NormalizeGold()
    self:DepositItemsToBank()
end

function DirectDeposit:GetItemMaxStack(itemID)
    local _, _, _, _, _, _, _, maxStack = C_Item.GetItemInfo(itemID)
    if type(maxStack) ~= "number" or maxStack < 1 then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    return maxStack
end

function DirectDeposit:GetGuildBankSlotItemID(tabID, slotID)
    local itemLink = GetGuildBankItemLink(tabID, slotID)
    if not itemLink then return nil end

    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID then
        itemID = tonumber(itemLink:match("item:(%d+)"))
    end
    return itemID
end

function DirectDeposit:GetItemClassIDs(itemID)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return classID, subclassID
end

function DirectDeposit:QueryGuildBankTabs()
    local numTabs = GetNumGuildBankTabs() or 0
    for tabID = 1, numTabs do
        local _, _, isViewable = GetGuildBankTabInfo(tabID)
        if isViewable ~= false then
            QueryGuildBankTab(tabID)
        end
    end
end

function DirectDeposit:QueryGuildBankTabsForItems(wantedItemIDs)
    local tabs, hasWarmSource = self:GetWarmGuildBankCandidateTabs(wantedItemIDs)

    if tabs then
        for tabID in pairs(tabs) do
            QueryGuildBankTab(tabID)
        end
        return
    end

    -- No warm source is available, so fall back to loading the tabs we can see.
    self:QueryGuildBankTabs()
end

function DirectDeposit:AddGuildBankIndexCandidate(index, seenSlots, wantedItemIDs, itemID, tabID, slotID, count, locked)
    if not itemID or not tabID or not slotID or locked then return false end
    if wantedItemIDs and not wantedItemIDs[itemID] then return false end

    local _, _, isViewable, canDeposit = GetGuildBankTabInfo(tabID)
    if isViewable == false or canDeposit == false then return false end

    local liveTexture, liveCount, liveLocked = GetGuildBankItemInfo(tabID, slotID)
    if not liveTexture or liveLocked then return false end

    local liveItemID = self:GetGuildBankSlotItemID(tabID, slotID)
    if liveItemID ~= itemID then return false end

    count = liveCount or count or 0
    local maxStack = self:GetItemMaxStack(itemID)
    if count <= 0 then return false end
    if maxStack and maxStack <= count then return false end

    local slotKey = tabID .. ":" .. slotID
    if seenSlots[slotKey] then return false end
    seenSlots[slotKey] = true

    if not index[itemID] then
        index[itemID] = {}
    end

    table.insert(index[itemID], {
        tabID = tabID,
        slotID = slotID,
        count = count,
        maxStack = maxStack,
    })

    return true
end

function DirectDeposit:AddGuildBankCandidateTab(tabs, wantedItemIDs, itemID, tabID, count)
    if not itemID or not tabID then return false end
    if wantedItemIDs and not wantedItemIDs[itemID] then return false end

    local _, _, isViewable, canDeposit = GetGuildBankTabInfo(tabID)
    if isViewable == false or canDeposit == false then return false end

    count = count or 0
    local maxStack = self:GetItemMaxStack(itemID)
    if count <= 0 then return false end
    if maxStack and maxStack <= count then return false end

    tabs[tabID] = true
    return true
end

function DirectDeposit:ForEachWarmGuildBankSlot(callback)
    local usedWarmSource = false

    if OneWoW_Bags and OneWoW_Bags.GuildBankSet and OneWoW_Bags.GuildBankSet.cache then
        usedWarmSource = true
        for tabID, tabCache in pairs(OneWoW_Bags.GuildBankSet.cache) do
            if type(tabCache) == "table" then
                for slotID, cached in pairs(tabCache) do
                    if cached and cached.itemID then
                        callback(cached.itemID, tabID, slotID, cached.itemCount, cached.locked)
                    end
                end
            end
        end
    end

    return usedWarmSource
end

function DirectDeposit:GetWarmGuildBankCandidateTabs(wantedItemIDs)
    local tabs = {}
    local usedWarmSource = self:ForEachWarmGuildBankSlot(function(itemID, tabID, slotID, count)
        self:AddGuildBankCandidateTab(tabs, wantedItemIDs, itemID, tabID, count)
    end)

    if not usedWarmSource then
        return nil, false
    end

    if next(tabs) then
        return tabs, true
    end

    return {}, true
end

function DirectDeposit:BuildGuildBankPartialStackIndex(wantedItemIDs)
    local index = {}
    local seenSlots = {}
    local usedWarmSource = self:ForEachWarmGuildBankSlot(function(itemID, tabID, slotID, count, locked)
        self:AddGuildBankIndexCandidate(index, seenSlots, wantedItemIDs, itemID, tabID, slotID, count, locked)
    end)

    if usedWarmSource then
        return index
    end

    local numTabs = GetNumGuildBankTabs() or 0

    for tabID = 1, numTabs do
        local _, _, isViewable, canDeposit = GetGuildBankTabInfo(tabID)
        if isViewable ~= false and canDeposit ~= false then
            for slotID = 1, GUILD_BANK_SLOTS_PER_TAB do
                local texture, itemCount, locked = GetGuildBankItemInfo(tabID, slotID)
                if texture and itemCount and itemCount > 0 and not locked then
                    local itemID = self:GetGuildBankSlotItemID(tabID, slotID)
                    self:AddGuildBankIndexCandidate(index, seenSlots, wantedItemIDs, itemID, tabID, slotID, itemCount, locked)
                end
            end
        end
    end

    return index
end

function DirectDeposit:BuildGuildBankEmptySlotList()
    local emptySlots = {}
    local occupiedSlots = {}
    local numTabs = GetNumGuildBankTabs() or 0

    for tabID = 1, numTabs do
        local _, _, isViewable, canDeposit = GetGuildBankTabInfo(tabID)
        if isViewable ~= false and canDeposit ~= false then
            for slotID = 1, GUILD_BANK_SLOTS_PER_TAB do
                local texture, itemCount, locked = GetGuildBankItemInfo(tabID, slotID)
                if not texture and not locked then
                    table.insert(emptySlots, {
                        tabID = tabID,
                        slotID = slotID,
                    })
                elseif texture and itemCount and itemCount > 0 and not locked then
                    local itemID = self:GetGuildBankSlotItemID(tabID, slotID)
                    if itemID then
                        local classID, subclassID = self:GetItemClassIDs(itemID)
                        table.insert(occupiedSlots, {
                            tabID = tabID,
                            slotID = slotID,
                            itemID = itemID,
                            classID = classID,
                            subclassID = subclassID,
                        })
                    end
                end
            end
        end
    end

    return emptySlots, occupiedSlots
end

function DirectDeposit:GetGuildBankEmptyTargetScore(emptySlot, occupiedSlots, itemID)
    local classID, subclassID = self:GetItemClassIDs(itemID)
    if not classID then
        return 30000 + (emptySlot.tabID or 0) * 100 + (emptySlot.slotID or 0)
    end

    local bestScore
    for _, occupied in ipairs(occupiedSlots or {}) do
        local matchScore
        if occupied.classID == classID and occupied.subclassID == subclassID then
            matchScore = 0
        elseif occupied.classID == classID then
            matchScore = 10000
        end

        if matchScore then
            local tabDistance = math.abs((emptySlot.tabID or 0) - (occupied.tabID or 0))
            local slotDistance = math.abs((emptySlot.slotID or 0) - (occupied.slotID or 0))
            local score = matchScore + tabDistance * 1000 + slotDistance
            if not bestScore or score < bestScore then
                bestScore = score
            end
        end
    end

    return bestScore or (20000 + (emptySlot.tabID or 0) * 100 + (emptySlot.slotID or 0))
end

function DirectDeposit:ReserveGuildBankEmptyTarget(emptySlots, occupiedSlots, itemID)
    if not emptySlots or #emptySlots == 0 then return nil end

    local bestIndex = 1
    local bestScore = self:GetGuildBankEmptyTargetScore(emptySlots[1], occupiedSlots, itemID)
    for index = 2, #emptySlots do
        local score = self:GetGuildBankEmptyTargetScore(emptySlots[index], occupiedSlots, itemID)
        if score < bestScore then
            bestIndex = index
            bestScore = score
        end
    end

    local target = table.remove(emptySlots, bestIndex)
    local classID, subclassID = self:GetItemClassIDs(itemID)
    table.insert(occupiedSlots, {
        tabID = target.tabID,
        slotID = target.slotID,
        itemID = itemID,
        classID = classID,
        subclassID = subclassID,
    })

    return target
end

function DirectDeposit:ReserveGuildBankStackTargets(index, itemID, count)
    local targets = {}
    local stacks = index and index[itemID]
    local remaining = count or 0

    if not stacks or remaining <= 0 then
        return targets, remaining
    end

    for _, stack in ipairs(stacks) do
        local free = stack.maxStack and ((stack.maxStack or 1) - (stack.count or 0)) or remaining
        if free > 0 then
            local moveCount = math.min(remaining, free)
            table.insert(targets, {
                tabID = stack.tabID,
                slotID = stack.slotID,
                count = moveCount,
            })
            stack.count = stack.count + moveCount
            remaining = remaining - moveCount
            if remaining <= 0 then
                break
            end
        end
    end

    return targets, remaining
end

function DirectDeposit:PickupBagStackAmount(bagID, slotID, amount, stackCount)
    if amount and stackCount and amount < stackCount then
        C_Container.SplitContainerItem(bagID, slotID, amount)
    else
        C_Container.PickupContainerItem(bagID, slotID)
    end
end

function DirectDeposit:RecordDepositedItem(itemID, itemName, count, bankType)
    local resolvedItemName = itemName or C_Item.GetItemNameByID(itemID) or "Item"
    local existing

    for _, rec in ipairs(self.depositedItems) do
        if rec.itemID == itemID and rec.bankType == bankType then
            existing = rec
            break
        end
    end

    if existing then
        existing.count = existing.count + count
    else
        table.insert(self.depositedItems, {
            itemID   = itemID,
            itemName = resolvedItemName,
            count    = count,
            bankType = bankType,
        })
    end
end

function DirectDeposit:CanDepositSlotToGuild(slotInfo, itemInfo)
    if not self.guildBankOpen then
        return false, "Guild bank not open"
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(slotInfo.bagID, slotInfo.slotID)
    if not itemLocation or not itemLocation:IsValid() then
        return false, "Item no longer in bag slot"
    end

    return true
end

function DirectDeposit:ExecuteGuildDepositOperation(op)
    if not op or not self.guildBankOpen then
        return false, 0, "Guild bank not open"
    end
    if GetCursorInfo() then
        return false, 0, "Cursor is busy"
    end

    local itemInfo = C_Container.GetContainerItemInfo(op.bagID, op.slotID)
    if not itemInfo or itemInfo.itemID ~= op.itemID then
        return false, 0, "Item no longer in bag slot"
    end

    local canDeposit, blockReason = self:CanDepositSlotToGuild(op, itemInfo)
    if not canDeposit then
        return false, 0, blockReason or "Item cannot be deposited"
    end

    local stackCount = itemInfo.stackCount or 1

    if op.kind == "guildStack" or op.kind == "guildEmpty" then
        local texture, targetCount, locked = GetGuildBankItemInfo(op.targetTabID, op.targetSlotID)
        if op.kind == "guildStack" and (not texture or locked) then
            return false, 0, "Guild bank target is locked"
        end
        if op.kind == "guildEmpty" and (texture or locked) then
            return false, 0, "Guild bank empty slot is no longer available"
        end

        if op.kind == "guildStack" then
            local targetItemID = self:GetGuildBankSlotItemID(op.targetTabID, op.targetSlotID)
            if targetItemID ~= op.itemID then
                return false, 0, "Guild bank target changed"
            end
        end

        local maxStack = self:GetItemMaxStack(op.itemID)
        local capacity = op.kind == "guildStack" and (maxStack and (maxStack - (targetCount or 0)) or stackCount) or stackCount
        local moveCount = math.min(op.count or stackCount, stackCount, capacity)
        if moveCount <= 0 then
            return false, 0, "Guild bank stack is full"
        end

        op.targetCountBefore = targetCount or 0
        self:PickupBagStackAmount(op.bagID, op.slotID, moveCount, stackCount)
        if GetCursorInfo() == "item" then
            if OneWoW_Bags then
                OneWoW_Bags._wasPlacingBeforeGBOp = true
                OneWoW_Bags._destHadItemBeforeGBOp = true
                if OneWoW_Bags.TrackGuildBankTransferTab then
                    OneWoW_Bags:TrackGuildBankTransferTab(op.targetTabID)
                end
            end
            PickupGuildBankItem(op.targetTabID, op.targetSlotID)
            if GetCursorInfo() == "item" then
                C_Container.PickupContainerItem(op.bagID, op.slotID)
                return false, 0, "Guild bank did not accept item"
            end
            return true, moveCount
        end

        return false, 0, "Could not pick up item"
    else
        C_Container.UseContainerItem(op.bagID, op.slotID)
        return true, stackCount
    end
end

function DirectDeposit:GetBagSlotItemState(op)
    local itemInfo = op and C_Container.GetContainerItemInfo(op.bagID, op.slotID)
    if not itemInfo then
        return nil, 0
    end

    return itemInfo.itemID, itemInfo.stackCount or 1
end

function DirectDeposit:DidGuildDepositOperationApply(op, beforeCount, moveCount)
    if op.kind == "guildStack" then
        local targetItemID = self:GetGuildBankSlotItemID(op.targetTabID, op.targetSlotID)
        local _, targetCount = GetGuildBankItemInfo(op.targetTabID, op.targetSlotID)
        if targetItemID ~= op.itemID then
            return false
        end

        local expectedCount = (op.targetCountBefore or 0) + (moveCount or op.count or 0)
        return (targetCount or 0) >= expectedCount
    end

    local itemID, currentCount = self:GetBagSlotItemState(op)
    if itemID ~= op.itemID then
        return true
    end

    moveCount = moveCount or op.count or beforeCount or 0
    return currentCount <= math.max(0, (beforeCount or currentCount) - moveCount)
end

function DirectDeposit:RecordGuildDepositFailure(op, reason)
    table.insert(self.failedItems, {
        itemID = op and op.itemID,
        itemName = (op and op.itemName) or "Unknown",
        reason = reason or "Deposit did not complete",
    })
end

function DirectDeposit:BuildWantedItemIDSet(slotsToDeposit)
    local wantedItemIDs = {}
    for _, slotInfo in ipairs(slotsToDeposit or {}) do
        if slotInfo.itemID then
            wantedItemIDs[slotInfo.itemID] = true
        end
    end
    return wantedItemIDs
end

function DirectDeposit:StartGuildDepositQueue(slotsToDeposit, manualTrigger)
    local wantedItemIDs = self:BuildWantedItemIDSet(slotsToDeposit)
    local stackIndex = self:BuildGuildBankPartialStackIndex(wantedItemIDs)
    local emptySlots, occupiedSlots = self:BuildGuildBankEmptySlotList()
    local operations = {}
    local planningFailures = {}

    for _, slotInfo in ipairs(slotsToDeposit) do
        local itemInfo = C_Container.GetContainerItemInfo(slotInfo.bagID, slotInfo.slotID)
        local stackCount = itemInfo and itemInfo.stackCount or 1
        local targets, remaining = self:ReserveGuildBankStackTargets(stackIndex, slotInfo.itemID, stackCount)

        for _, target in ipairs(targets) do
            table.insert(operations, {
                kind = "guildStack",
                bagID = slotInfo.bagID,
                slotID = slotInfo.slotID,
                itemID = slotInfo.itemID,
                itemName = slotInfo.itemName,
                count = target.count,
                targetTabID = target.tabID,
                targetSlotID = target.slotID,
            })
        end

        if remaining and remaining > 0 then
            local emptyTarget = self:ReserveGuildBankEmptyTarget(emptySlots, occupiedSlots, slotInfo.itemID)
            if emptyTarget then
                table.insert(operations, {
                    kind = "guildEmpty",
                    bagID = slotInfo.bagID,
                    slotID = slotInfo.slotID,
                    itemID = slotInfo.itemID,
                    itemName = slotInfo.itemName,
                    count = remaining,
                    targetTabID = emptyTarget.tabID,
                    targetSlotID = emptyTarget.slotID,
                })
            else
                table.insert(planningFailures, {
                    itemID = slotInfo.itemID,
                    itemName = slotInfo.itemName or "Unknown",
                    reason = "No guild bank destination slot",
                })
            end
        end
    end

    self.isDepositing = true
    self.isPaused = false
    self.currentDepositIndex = 0
    self.totalDepositItems = #operations
    self.depositedItems = {}
    self.failedItems = planningFailures
    self.depositTimers = {}

    if #operations == 0 then
        self:FinishDeposit()
        return
    end

    if manualTrigger then
        print(L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Starting manual guild deposit of " .. #operations .. " move(s)...|r")
    end

    self.guildDepositOperations = operations
    self.guildDepositManualTrigger = manualTrigger
    self.guildDepositRetryCount = 0
    self.guildDepositTabRetryCount = 0

    self:RunNextGuildDepositOperation(1)
end

function DirectDeposit:RunNextGuildDepositOperation(index)
    if not self.isDepositing or self.isPaused then
        return
    end

    local operations = self.guildDepositOperations or {}
    local op = operations[index]
    if not op then
        local timer = C_Timer.After(0.4, function()
            self.guildDepositOperations = nil
            self.guildDepositManualTrigger = nil
            self.guildDepositRetryCount = 0
            self.guildDepositTabRetryCount = 0
            self:FinishDeposit()
        end)
        table.insert(self.depositTimers, timer)
        return
    end

    self.currentDepositIndex = index
    if self.progressCallback then
        self.progressCallback(index, #operations, op.itemName)
    end

    if op.targetTabID and GetCurrentGuildBankTab() ~= op.targetTabID then
        SetCurrentGuildBankTab(op.targetTabID)
        QueryGuildBankTab(op.targetTabID)
        self.guildDepositTabRetryCount = (self.guildDepositTabRetryCount or 0) + 1
        if self.guildDepositTabRetryCount > 6 then
            self.guildDepositTabRetryCount = 0
            self.guildDepositRetryCount = 0
            self:RecordGuildDepositFailure(op, "Could not switch to guild bank tab")
            self:RunNextGuildDepositOperation(index + 1)
            return
        end
        local timer = C_Timer.After(0.3, function()
            self:RunNextGuildDepositOperation(index)
        end)
        table.insert(self.depositTimers, timer)
        return
    end
    self.guildDepositTabRetryCount = 0

    local beforeItemID, beforeCount = self:GetBagSlotItemState(op)
    if beforeItemID ~= op.itemID then
        self.guildDepositRetryCount = 0
        self:RunNextGuildDepositOperation(index + 1)
        return
    end

    local attempted, moveCount, reason = self:ExecuteGuildDepositOperation(op)
    if not attempted then
        self.guildDepositRetryCount = (self.guildDepositRetryCount or 0) + 1
        if self.guildDepositRetryCount <= 3 then
            local timer = C_Timer.After(0.8, function()
                self:RunNextGuildDepositOperation(index)
            end)
            table.insert(self.depositTimers, timer)
        else
            self:RecordGuildDepositFailure(op, reason)
            self.guildDepositRetryCount = 0
            self:RunNextGuildDepositOperation(index + 1)
        end
        return
    end

    local timer = C_Timer.After(0.9, function()
        if self:DidGuildDepositOperationApply(op, beforeCount, moveCount) then
            self:RecordDepositedItem(op.itemID, op.itemName, moveCount, "guild")
            self.guildDepositRetryCount = 0
            self:RunNextGuildDepositOperation(index + 1)
            return
        end

        self.guildDepositRetryCount = (self.guildDepositRetryCount or 0) + 1
        if self.guildDepositRetryCount <= 3 then
            self:RunNextGuildDepositOperation(index)
        else
            self:RecordGuildDepositFailure(op, "Deposit did not complete")
            self.guildDepositRetryCount = 0
            self:RunNextGuildDepositOperation(index + 1)
        end
    end)
    table.insert(self.depositTimers, timer)
end

--- Decides whether a bag slot holds a warbound item the sweep should deposit.
--- C_Item.IsBound only catches items that are *already* bound (account-bound
--- crafted goods, etc.) and returns false for "Warbound until equipped" gear,
--- which is the most common warbound gear and was silently skipped. The
--- PredicateEngine resolves bind state from tooltip data and exposes isWarbound
--- (isBOA or isWUE), so it catches WUE gear too. IsBound stays as a cheap
--- first check so already-working items take the fast path.
---@param itemLocation ItemLocation
---@param itemInfo table
---@param bagID number
---@param slotID number
---@return boolean
function DirectDeposit:IsWarboundItem(itemLocation, itemInfo, bagID, slotID)
    if C_Item.IsBound(itemLocation) then
        return true
    end
    local props = PE:BuildProps(itemInfo.itemID, bagID, slotID, itemInfo)
    return props ~= nil and props.isWarbound == true
end

--- Tests a bag slot against the compiled warbound-exclude predicate.
--- Returns false when there is no predicate (empty/invalid expression), so an
--- unset exclude box never blocks the sweep.
---@param compiled (fun(props: table): boolean)|nil
---@param itemInfo table
---@param bagID number
---@param slotID number
---@return boolean
function DirectDeposit:MatchesWarboundExclude(compiled, itemInfo, bagID, slotID)
    if not compiled then return false end
    local props = PE:BuildProps(itemInfo.itemID, bagID, slotID, itemInfo)
    if not props then return false end
    local result = PE:SafeEvaluate(compiled, props)
    return result == true
end

--- Returns the warband-exclude item-ID list (keyed by tostring(itemID)).
---@return table
function DirectDeposit:GetWarboundExcludeList()
    return OneWoW_DirectDeposit.db.global.directDeposit.warboundExcludeList
end

--- Adds an item to the warband-exclude list so the sweep never deposits it.
---@param itemID number
---@return boolean success
---@return string message
function DirectDeposit:AddWarboundExclude(itemID)
    if not itemID then
        return false, "Invalid item ID"
    end

    local excludeList = OneWoW_DirectDeposit.db.global.directDeposit.warboundExcludeList
    if excludeList[tostring(itemID)] then
        return false, "Item already excluded"
    end

    local itemName = C_Item.GetItemNameByID(itemID)
    if not itemName then
        return false, "Invalid item ID"
    end

    excludeList[tostring(itemID)] = {
        itemID    = itemID,
        itemName  = itemName,
        addedTime = time(),
    }

    return true, "Item excluded"
end

--- Removes an item from the warband-exclude list.
---@param itemID number
---@return boolean
function DirectDeposit:RemoveWarboundExclude(itemID)
    if not itemID then return false end

    local excludeList = OneWoW_DirectDeposit.db.global.directDeposit.warboundExcludeList
    local key = tostring(itemID)
    if excludeList[key] then
        excludeList[key] = nil
        return true
    end

    return false
end

function DirectDeposit:SweepWarboundItems()
    local dd = OneWoW_DirectDeposit.db.global.directDeposit
    if not dd.warboundAutoDeposit then
        return
    end

    local itemList = dd.itemList
    local excludeList = dd.warboundExcludeList

    -- Keyword/predicate exclude: compile the user's expression once per sweep
    -- (e.g. "#potion | #flask") and skip any slot whose item matches it. nil
    -- when the box is empty or the expression fails to compile, in which case
    -- nothing is excluded by keyword.
    local excludeCompiled = PE:Compile(dd.warboundExcludeExpr)

    local itemsToDeposit = {}

    for bagID = 0, 5 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
                if itemInfo and itemInfo.itemID
                    and not itemList[tostring(itemInfo.itemID)]
                    and not excludeList[tostring(itemInfo.itemID)]
                    and not self:MatchesWarboundExclude(excludeCompiled, itemInfo, bagID, slotID)
                then
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
                    if itemLocation and itemLocation:IsValid() then
                        if C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation)
                            and self:IsWarboundItem(itemLocation, itemInfo, bagID, slotID)
                        then
                            table.insert(itemsToDeposit, {
                                bagID    = bagID,
                                slotID   = slotID,
                                itemID   = itemInfo.itemID,
                            })
                        end
                    end
                end
            end
        end
    end

    if #itemsToDeposit == 0 then return end

    local deposited = 0
    local delay = 0.3

    for _, slot in ipairs(itemsToDeposit) do
        C_Timer.After(delay, function()
            if not C_Bank.CanUseBank(Enum.BankType.Account) then return end
            local currentInfo = C_Container.GetContainerItemInfo(slot.bagID, slot.slotID)
            if currentInfo and currentInfo.itemID == slot.itemID then
                local loc = ItemLocation:CreateFromBagAndSlot(slot.bagID, slot.slotID)
                if loc and loc:IsValid() and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc) then
                    C_Container.UseContainerItem(slot.bagID, slot.slotID, nil, Enum.BankType.Account)
                    deposited = deposited + (currentInfo.stackCount or 1)
                end
            end
        end)
        delay = delay + 0.3
    end

    C_Timer.After(delay + 0.3, function()
        if deposited > 0 then
            local checkmark = "|TInterface\\Buttons\\UI-CheckBox-Check:16|t"
            print(L["ADDON_CHAT_PREFIX"] .. " " .. checkmark .. " |cFF00FF00Auto-deposited|r |cFFFFFFFF" .. deposited .. " warbound item(s)|r to |cFF4A90E2Warband Bank|r")
        end
    end)
end

function DirectDeposit:NormalizeGold()
    local settings = self:GetActiveSettings()
    local targetGold = self:GetTargetGold()

    -- nil = not configured; 0 is a valid target (keep zero gold on character).
    if targetGold == nil then
        return
    end

    local currentGold = GetMoney()
    local targetCopper = targetGold * 10000

    local doDeposit = settings.depositEnabled == true
    local doWithdraw = settings.withdrawEnabled == true
    local bankType = 2

    if doDeposit and currentGold > targetCopper then
        if C_Bank.CanDepositMoney(bankType) then
            local excess = currentGold - targetCopper
            C_Bank.DepositMoney(bankType, excess)

            local checkmark = "|TInterface\\Buttons\\UI-CheckBox-Check:16|t"
            print(L["ADDON_CHAT_PREFIX"] .. " " .. checkmark .. " |cFFE67E22Deposited|r |cFFFFFFFF" .. GetMoneyString(excess, true) .. " to |cFF50C878Warband Bank|r")
        end
    end

    if doWithdraw and currentGold < targetCopper then
        if C_Bank.CanWithdrawMoney(bankType) then
            local needed = targetCopper - currentGold
            local bankGold = C_Bank.FetchDepositedMoney(bankType)
            local toWithdraw = math.min(needed, bankGold)

            if toWithdraw > 0 then
                C_Bank.WithdrawMoney(bankType, toWithdraw)

                local checkmark = "|TInterface\\Buttons\\UI-CheckBox-Check:16|t"
                print(L["ADDON_CHAT_PREFIX"] .. " " .. checkmark .. " |cFF4A90E2Withdrew|r |cFFFFFFFF" .. GetMoneyString(toWithdraw, true) .. " from |cFF50C878Warband Bank|r")
            end
        end
    end
end

function DirectDeposit:DepositItemsToBank(manualTrigger, guildBankReady)
    if not manualTrigger and not OneWoW_DirectDeposit.db.global.directDeposit.itemDepositEnabled then
        return
    end

    if self.isDepositing then
        print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800Deposit already in progress. Use /dddeposit pause to stop.|r")
        return
    end

    local itemList = OneWoW_DirectDeposit.db.global.directDeposit.itemList

    if not next(itemList) then
        if manualTrigger then
            print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000No items in deposit list.|r")
        end
        return
    end

    local activeType = self.currentOpenBankType
    if not activeType then
        if manualTrigger then
            print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000No bank is currently open.|r")
        end
        return
    end

    -- Walk the player's live bags once and only queue slots that hold an item
    -- on the deposit list and are compatible with the currently-open bank.
    -- This keeps the schedule proportional to what's actually being moved
    -- instead of the full list size (which can be hundreds of entries).
    local slotsToDeposit = {}
    local hasGuildItems = false

    for bagID = 0, 5 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
                if itemInfo and itemInfo.itemID then
                    local itemData = itemList[tostring(itemInfo.itemID)]
                    if itemData and itemData.bankType then
                        local targetType = itemData.bankType
                        local shouldDeposit = false
                        if activeType == "guild" then
                            shouldDeposit = targetType == "guild"
                        else
                            shouldDeposit = targetType == "personal" or targetType == "warband"
                        end
                        if shouldDeposit then
                            if targetType == "guild" then
                                hasGuildItems = true
                            end
                            table.insert(slotsToDeposit, {
                                bagID    = bagID,
                                slotID   = slotID,
                                itemID   = itemInfo.itemID,
                                bankType = targetType,
                                itemName = itemData.itemName,
                            })
                        end
                    end
                end
            end
        end
    end

    if #slotsToDeposit == 0 then
        return
    end

    if activeType == "guild" and hasGuildItems then
        if not guildBankReady then
            self:QueryGuildBankTabsForItems(self:BuildWantedItemIDSet(slotsToDeposit))
            C_Timer.After(0.6, function()
                if self.guildBankOpen and not self.isDepositing then
                    self:DepositItemsToBank(manualTrigger, true)
                end
            end)
            return
        end

        self:StartGuildDepositQueue(slotsToDeposit, manualTrigger)
        return
    end

    self.isDepositing = true
    self.isPaused = false
    self.currentDepositIndex = 0
    self.totalDepositItems = #slotsToDeposit
    self.depositedItems = {}
    self.failedItems = {}
    self.depositTimers = {}

    if manualTrigger then
        print(L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Starting manual deposit of " .. #slotsToDeposit .. " stack(s)...|r")
    end

    local delayStep = hasGuildItems and 1.0 or 0.3

    local delay = delayStep
    for i, slotInfo in ipairs(slotsToDeposit) do
        local timer = C_Timer.After(delay, function()
            if self.isPaused then
                return
            end
            self.currentDepositIndex = i
            if self.progressCallback then
                self.progressCallback(i, #slotsToDeposit, slotInfo.itemName)
            end
            self:DepositSingleSlot(slotInfo)

            if i == #slotsToDeposit then
                C_Timer.After(0.5, function()
                    self:FinishDeposit()
                end)
            end
        end)
        table.insert(self.depositTimers, timer)
        delay = delay + delayStep
    end
end

function DirectDeposit:DepositSingleSlot(slotInfo)
    if not slotInfo then return end

    local bagID          = slotInfo.bagID
    local slotID         = slotInfo.slotID
    local expectedID     = slotInfo.itemID
    local targetBankType = slotInfo.bankType
    local itemName       = slotInfo.itemName

    -- Re-verify the slot still holds the expected item. Bag contents can shift
    -- between the initial scan and the scheduled deposit (prior stack merged,
    -- item consumed, user moved it, etc.), so skip silently if it no longer matches.
    local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    if not itemInfo or itemInfo.itemID ~= expectedID then
        return
    end

    local bankTypeEnum
    local isGuildBank = false

    if targetBankType == "warband" then
        bankTypeEnum = Enum.BankType.Account
    elseif targetBankType == "personal" then
        bankTypeEnum = Enum.BankType.Character
    elseif targetBankType == "guild" then
        isGuildBank = true
        if not self.guildBankOpen then
            table.insert(self.failedItems, {itemID = expectedID, itemName = itemName or "Unknown", reason = "Guild bank not open"})
            return
        end
    else
        return
    end

    if not isGuildBank and not C_Bank.CanUseBank(bankTypeEnum) then
        table.insert(self.failedItems, {itemID = expectedID, itemName = itemName or "Unknown", reason = "Bank not accessible"})
        return
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if not itemLocation or not itemLocation:IsValid() then
        return
    end

    if not isGuildBank then
        local allowed = C_Bank.IsItemAllowedInBankType(bankTypeEnum, itemLocation)
        if not allowed then
            table.insert(self.failedItems, {itemID = expectedID, itemName = itemName or "Unknown", reason = "Item binding prevents deposit"})
            return
        end
    end

    if isGuildBank then
        C_Container.UseContainerItem(bagID, slotID)
    else
        C_Container.UseContainerItem(bagID, slotID, nil, bankTypeEnum)
    end

    local stackCount = itemInfo.stackCount or 1
    local resolvedItemName = itemName or C_Item.GetItemNameByID(expectedID) or "Item"

    -- Collapse repeats of the same item+bankType into one summary entry so the
    -- FinishDeposit readout matches the old per-itemID grouping.
    self:RecordDepositedItem(expectedID, resolvedItemName, stackCount, targetBankType)
end

function DirectDeposit:DepositItemByID(itemID, targetBankType, itemName)
    if not itemID or not targetBankType then
        return
    end

    local bankTypeEnum
    local isGuildBank = false

    if targetBankType == "warband" then
        bankTypeEnum = Enum.BankType.Account
    elseif targetBankType == "personal" then
        bankTypeEnum = Enum.BankType.Character
    elseif targetBankType == "guild" then
        isGuildBank = true
        if not self.guildBankOpen then
            table.insert(self.failedItems, {itemID = itemID, itemName = itemName or "Unknown", reason = "Guild bank not open"})
            return
        end
    else
        return
    end

    if not isGuildBank and not C_Bank.CanUseBank(bankTypeEnum) then
        table.insert(self.failedItems, {itemID = itemID, itemName = itemName or "Unknown", reason = "Bank not accessible"})
        return
    end

    local depositedCount = 0
    local hadError = false
    local errorReason = ""

    for bagID = 0, 5 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
                if itemInfo and itemInfo.itemID == itemID then
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
                    if itemLocation and itemLocation:IsValid() then
                        local canDeposit = true

                        if not isGuildBank then
                            local allowed = C_Bank.IsItemAllowedInBankType(bankTypeEnum, itemLocation)
                            if not allowed then
                                canDeposit = false
                                hadError = true
                                errorReason = "Item binding prevents deposit"
                            end
                        end

                        if canDeposit then
                            if isGuildBank then
                                C_Container.UseContainerItem(bagID, slotID)
                            else
                                C_Container.UseContainerItem(bagID, slotID, nil, bankTypeEnum)
                            end
                            depositedCount = depositedCount + (itemInfo.stackCount or 1)
                        end
                    end
                end
            end
        end
    end

    local resolvedItemName = itemName or C_Item.GetItemNameByID(itemID) or "Item"

    if depositedCount > 0 then
        local bankTypeText = targetBankType == "warband" and "|cFF50C878Warband Bank|r"
                          or targetBankType == "personal" and "|cFF4A90E2Personal Bank|r"
                          or "|cFFFF8C00Guild Bank|r"

        table.insert(self.depositedItems, {itemID = itemID, itemName = resolvedItemName, count = depositedCount, bankType = targetBankType})

        if not self.isDepositing then
            local checkmark = "|TInterface\\Buttons\\UI-CheckBox-Check:16|t"
            print(L["ADDON_CHAT_PREFIX"] .. " " .. checkmark .. " |cFFE67E22Deposited|r |cFFFFFFFF" .. depositedCount .. "x " .. resolvedItemName .. "|r to " .. bankTypeText)
        end
    elseif hadError then
        table.insert(self.failedItems, {itemID = itemID, itemName = resolvedItemName, reason = errorReason})

        if not self.isDepositing then
            local errorIcon = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:16|t"
            print(L["ADDON_CHAT_PREFIX"] .. " " .. errorIcon .. " |cFFFF0000Cannot deposit|r |cFFFFFFFF" .. resolvedItemName .. "|r - " .. errorReason)
        end
    end
end

function DirectDeposit:GetItemBindingInfo(itemID)
    if not itemID then
        return {
            isWarbound = false,
            isSoulbound = false,
            canUseWarband = true,
            canUsePersonal = true,
            canUseGuild = true
        }
    end

    for bagID = 0, 5 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotID = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
                if itemInfo and itemInfo.itemID == itemID then
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
                    if itemLocation and itemLocation:IsValid() then
                        local isBound = C_Item.IsBound(itemLocation)
                        local isWarbound = false
                        local isSoulbound = false

                        if isBound then
                            isWarbound = C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation)
                            isSoulbound = not isWarbound
                        end

                        local result = {
                            isWarbound = isWarbound,
                            isSoulbound = isSoulbound,
                            canUseWarband = not isSoulbound,
                            canUsePersonal = true,
                            canUseGuild = not (isSoulbound or isWarbound)
                        }

                        return result
                    end
                end
            end
        end
    end

    return {
        isWarbound = false,
        isSoulbound = false,
        canUseWarband = true,
        canUsePersonal = true,
        canUseGuild = true
    }
end

function DirectDeposit:AddItemToList(itemID, bankType)
    if not itemID or not bankType then
        return false, "Invalid item ID or bank type"
    end

    local itemList = OneWoW_DirectDeposit.db.global.directDeposit.itemList

    if itemList[tostring(itemID)] then
        return false, "Item already in list"
    end

    local itemName = C_Item.GetItemNameByID(itemID)
    if not itemName then
        return false, "Invalid item ID"
    end

    local bindingInfo = self:GetItemBindingInfo(itemID)

    itemList[tostring(itemID)] = {
        itemID = itemID,
        bankType = bankType,
        itemName = itemName,
        bindingInfo = bindingInfo,
        addedTime = time()
    }

    OneWoW_DirectDeposit.db.global.directDeposit.itemList = itemList

    return true, "Item added successfully"
end

function DirectDeposit:RemoveItemFromList(itemID)
    if not itemID then
        print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000Delete failed - no itemID|r")
        return false
    end

    local itemIDStr = tostring(itemID)

    local itemList = OneWoW_DirectDeposit.db.global.directDeposit.itemList

    if itemList[itemIDStr] then
        itemList[itemIDStr] = nil
        return true
    elseif itemList[itemID] then
        itemList[itemID] = nil
        return true
    else
        print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000Item not found in list: " .. itemIDStr .. "|r")
    end

    return false
end

function DirectDeposit:GetItemList()
    return OneWoW_DirectDeposit.db.global.directDeposit.itemList
end

function OneWoW_DirectDeposit:GetAvailableItemIDs()
    local ids = {}
    local itemList = self.DirectDeposit:GetItemList()
    for itemID, _ in pairs(itemList) do
        table.insert(ids, itemID)
    end
    return ids
end

function DirectDeposit:UpdateItemBankType(itemID, newBankType)
    if not itemID or not newBankType then
        return false
    end

    local itemList = OneWoW_DirectDeposit.db.global.directDeposit.itemList

    if itemList[tostring(itemID)] then
        itemList[tostring(itemID)].bankType = newBankType
        OneWoW_DirectDeposit.db.global.directDeposit.itemList = itemList
        return true
    end

    return false
end

function DirectDeposit:FinishDeposit()
    self.isDepositing = false
    self.isPaused = false

    local successCount = #self.depositedItems
    local failedCount = #self.failedItems

    if successCount == 0 and failedCount == 0 then
        self.depositedItems = {}
        self.failedItems = {}
        self.depositTimers = {}
        if self.progressCallback then
            self.progressCallback(nil, nil, nil)
        end
        return
    end

    local checkmark = "|TInterface\\Buttons\\UI-CheckBox-Check:16|t"
    local errorIcon = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:16|t"

    if successCount > 0 then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. checkmark .. " |cFF00FF00Deposit Complete!|r")
        print(L["ADDON_CHAT_PREFIX"] .. " " .. checkmark .. " |cFFFFFFFFSuccessfully deposited " .. successCount .. " item type(s)|r")
        for _, item in ipairs(self.depositedItems) do
            local bankTypeText = item.bankType == "warband" and "|cFF50C878Warband|r"
                              or item.bankType == "personal" and "|cFF4A90E2Personal|r"
                              or "|cFFFF8C00Guild|r"
            print("  " .. checkmark .. " |cFFFFFFFF" .. item.count .. "x " .. item.itemName .. "|r to " .. bankTypeText)
        end
    end

    if failedCount > 0 then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. errorIcon .. " |cFFFF0000Failed to deposit " .. failedCount .. " item type(s)|r")
        for _, item in ipairs(self.failedItems) do
            print("  " .. errorIcon .. " |cFFFF0000" .. item.itemName .. "|r - " .. item.reason)
        end
    end

    self.depositedItems = {}
    self.failedItems = {}
    self.depositTimers = {}
    self.guildDepositOperations = nil
    self.guildDepositManualTrigger = nil
    self.guildDepositRetryCount = 0

    if self.progressCallback then
        self.progressCallback(nil, nil, nil)
    end
end

function DirectDeposit:PauseDeposit()
    if not self.isDepositing then
        return false
    end

    self.isPaused = true
    print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800Deposit paused.|r")
    return true
end

function DirectDeposit:StopDeposit()
    if not self.isDepositing then
        return false
    end

    self.isPaused = true
    self.isDepositing = false

    for _, timer in ipairs(self.depositTimers) do
        if timer then
            timer:Cancel()
        end
    end

    self.depositTimers = {}
    self.guildDepositOperations = nil
    self.guildDepositManualTrigger = nil
    self.guildDepositRetryCount = 0

    print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000Deposit stopped.|r")

    if self.progressCallback then
        self.progressCallback(nil, nil, nil)
    end

    return true
end

function DirectDeposit:SetProgressCallback(callback)
    self.progressCallback = callback
end

function DirectDeposit:GetDepositStatus()
    return {
        isDepositing = self.isDepositing,
        isPaused = self.isPaused,
        currentIndex = self.currentDepositIndex,
        totalItems = self.totalDepositItems,
        successCount = #self.depositedItems,
        failedCount = #self.failedItems
    }
end

function DirectDeposit:ManualDeposit()
    self:DepositItemsToBank(true)
end

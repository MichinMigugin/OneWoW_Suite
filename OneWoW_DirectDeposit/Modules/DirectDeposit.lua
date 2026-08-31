local _, ns = ...

local PE = OneWoW.PredicateEngine
local SE = OneWoW.SearchExpand
local Inventory = OneWoW.Inventory
local GuildBankTransfer = OneWoW.GuildBankTransfer
local tinsert = tinsert

local INVENTORY_OWNER = "DirectDeposit"
local GBT_OWNER = "DirectDeposit"

local L = ns.L

ns.DirectDeposit = {}
local DirectDeposit = ns.DirectDeposit

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

local function GetDB()
    return ns.db
end

function DirectDeposit:Initialize()
    self:RegisterEvents()
    self.initialized = true
end

function DirectDeposit:RegisterEvents()
    Inventory.RegisterBankOpenCallback(INVENTORY_OWNER, function()
        if not DirectDeposit.guildBankOpen then
            DirectDeposit.currentOpenBankType = "personal"
            DirectDeposit:OnBankOpened()
        end
    end)
    Inventory.RegisterBankClosedCallback(INVENTORY_OWNER, function()
        if DirectDeposit.currentOpenBankType == "personal" then
            DirectDeposit.currentOpenBankType = nil
        end
        DirectDeposit.bankSessionHandled = false
    end)
    Inventory.RegisterGuildOpenCallback(INVENTORY_OWNER, function()
        DirectDeposit.guildBankOpen = true
        DirectDeposit.currentOpenBankType = "guild"
        DirectDeposit:OnBankOpened()
    end)
    Inventory.RegisterGuildClosedCallback(INVENTORY_OWNER, function()
        DirectDeposit.guildBankOpen = false
        DirectDeposit.currentOpenBankType = nil
        DirectDeposit.bankSessionHandled = false
    end)

    -- Warband open still needs PIM (BANKFRAME_* does not distinguish warband).
    -- Guild open/close is Inventory-owned; personal uses Inventory bank channels.
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local interactionType = ...
            if interactionType == 68 then
                DirectDeposit.currentOpenBankType = "warband"
                DirectDeposit:OnBankOpened()
            end
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            local interactionType = ...
            if interactionType == 68 then
                DirectDeposit.currentOpenBankType = nil
                DirectDeposit.bankSessionHandled = false
            end
        end
    end)

    self.eventFrame = eventFrame
end

function DirectDeposit:IsEnabled()
    return GetDB().global.directDeposit.enabled == true
end

function DirectDeposit:GetCharacterSettings()
    return GetDB().char.directDeposit
end

function DirectDeposit:GetActiveSettings()
    local charSettings = self:GetCharacterSettings()

    if charSettings.useAccountSettings then
        return GetDB().global.directDeposit
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
    return GetDB().global.directDeposit.warboundExcludeList
end

--- Adds an item to the warband-exclude list so the sweep never deposits it.
---@param itemID number
---@return boolean success
---@return string message
function DirectDeposit:AddWarboundExclude(itemID)
    if not itemID then
        return false, "Invalid item ID"
    end

    local excludeList = GetDB().global.directDeposit.warboundExcludeList
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

    local excludeList = GetDB().global.directDeposit.warboundExcludeList
    local key = tostring(itemID)
    if excludeList[key] then
        excludeList[key] = nil
        return true
    end

    return false
end

function DirectDeposit:SweepWarboundItems()
    local dd = GetDB().global.directDeposit
    if not dd.warboundAutoDeposit then
        return
    end

    local itemList = dd.itemList
    local excludeList = dd.warboundExcludeList

    -- Keyword/predicate exclude: compile the user's expression once per sweep
    -- (e.g. "#potion | #flask") and skip any slot whose item matches it. nil
    -- when the box is empty or the expression fails to compile, in which case
    -- nothing is excluded by keyword.
    local excludeCompiled = SE:Compile(dd.warboundExcludeExpr)

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
            print(L["ADDON_CHAT_PREFIX"] .. " " .. checkmark .. " |cFFE67E22Deposited|r " .. OneWoW.Format.FormatGold(excess) .. " to |cFF50C878Warband Bank|r")
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
                print(L["ADDON_CHAT_PREFIX"] .. " " .. checkmark .. " |cFF4A90E2Withdrew|r " .. OneWoW.Format.FormatGold(toWithdraw) .. " from |cFF50C878Warband Bank|r")
            end
        end
    end
end

function DirectDeposit:DepositItemsToBank(manualTrigger)
    if not manualTrigger and not GetDB().global.directDeposit.itemDepositEnabled then
        return
    end

    if self.isDepositing or GuildBankTransfer.IsBusy() then
        print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800Deposit already in progress. Use /dddeposit pause to stop.|r")
        return
    end

    local itemList = GetDB().global.directDeposit.itemList

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
    local slotsToDeposit = {}

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
                            tinsert(slotsToDeposit, {
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

    if activeType == "guild" then
        self:StartGuildDeposit(slotsToDeposit, manualTrigger)
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

    local delayStep = 0.3
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
        tinsert(self.depositTimers, timer)
        delay = delay + delayStep
    end
end

--- Guild path: EnsureTabsQueried → PlanDeposits → Enqueue via GuildBankTransfer.
function DirectDeposit:StartGuildDeposit(slotsToDeposit, manualTrigger)
    self.isDepositing = true
    self.isPaused = false
    self.currentDepositIndex = 0
    self.totalDepositItems = #slotsToDeposit
    self.depositedItems = {}
    self.failedItems = {}
    self.depositTimers = {}

    if manualTrigger then
        print(L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Starting manual guild deposit...|r")
    end

    local wantedItemIDs = {}
    for _, slotInfo in ipairs(slotsToDeposit) do
        if slotInfo.itemID then
            wantedItemIDs[slotInfo.itemID] = true
        end
    end

    GuildBankTransfer.EnsureTabsQueried(wantedItemIDs, function()
        if self.isPaused or not self.guildBankOpen or not Inventory.IsGuildBankOpen() then
            self.isDepositing = false
            return
        end

        local ops = GuildBankTransfer.PlanDeposits(slotsToDeposit)
        if #ops == 0 then
            self.isDepositing = false
            return
        end

        self.totalDepositItems = #ops

        local started = GuildBankTransfer.Enqueue(ops, {
            ownerID = GBT_OWNER,
            onProgress = function(i, total, op)
                self.currentDepositIndex = i
                if self.progressCallback then
                    self.progressCallback(i, total, op.itemName)
                end
            end,
            onOpComplete = function(op, moved)
                if moved and moved > 0 then
                    self:RecordDepositedItem(op.itemID, op.itemName, moved, "guild")
                end
            end,
            onComplete = function()
                self:FinishDeposit()
            end,
        })

        if not started then
            self.isDepositing = false
            if manualTrigger then
                print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000Could not start guild deposit (queue busy or guild bank closed).|r")
            end
        elseif manualTrigger then
            print(L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Queued " .. #ops .. " guild move(s)...|r")
        end
    end)
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
        tinsert(self.depositedItems, {
            itemID   = itemID,
            itemName = resolvedItemName,
            count    = count,
            bankType = bankType,
        })
    end
end

function DirectDeposit:DepositSingleSlot(slotInfo)
    if not slotInfo then return end

    local bagID          = slotInfo.bagID
    local slotID         = slotInfo.slotID
    local expectedID     = slotInfo.itemID
    local targetBankType = slotInfo.bankType
    local itemName       = slotInfo.itemName

    -- Personal/warband only — guild deposits go through GuildBankTransfer.
    if targetBankType == "guild" then
        return
    end

    -- Re-verify the slot still holds the expected item. Bag contents can shift
    -- between the initial scan and the scheduled deposit (prior stack merged,
    -- item consumed, user moved it, etc.), so skip silently if it no longer matches.
    local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    if not itemInfo or itemInfo.itemID ~= expectedID then
        return
    end

    local bankTypeEnum
    if targetBankType == "warband" then
        bankTypeEnum = Enum.BankType.Account
    elseif targetBankType == "personal" then
        bankTypeEnum = Enum.BankType.Character
    else
        return
    end

    if not C_Bank.CanUseBank(bankTypeEnum) then
        tinsert(self.failedItems, {itemID = expectedID, itemName = itemName or "Unknown", reason = "Bank not accessible"})
        return
    end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if not itemLocation or not itemLocation:IsValid() then
        return
    end

    local allowed = C_Bank.IsItemAllowedInBankType(bankTypeEnum, itemLocation)
    if not allowed then
        tinsert(self.failedItems, {itemID = expectedID, itemName = itemName or "Unknown", reason = "Item binding prevents deposit"})
        return
    end

    C_Container.UseContainerItem(bagID, slotID, nil, bankTypeEnum)
    self:RecordDepositedItem(expectedID, itemName, itemInfo.stackCount or 1, targetBankType)
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
                        else
                            local bindType = itemInfo.hyperlink and select(14, C_Item.GetItemInfo(itemInfo.hyperlink))
                            if bindType == Enum.ItemBind.OnAcquire or bindType == Enum.ItemBind.Quest then
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

    local itemList = GetDB().global.directDeposit.itemList

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

    GetDB().global.directDeposit.itemList = itemList

    return true, "Item added successfully"
end

function DirectDeposit:RemoveItemFromList(itemID)
    if not itemID then
        print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000Delete failed - no itemID|r")
        return false
    end

    local itemIDStr = tostring(itemID)

    local itemList = GetDB().global.directDeposit.itemList

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
    return GetDB().global.directDeposit.itemList
end

function DirectDeposit:GetAvailableItemIDs()
    local ids = {}
    local itemList = self:GetItemList()
    for itemID, _ in pairs(itemList) do
        table.insert(ids, itemID)
    end
    return ids
end

function DirectDeposit:UpdateItemBankType(itemID, newBankType)
    if not itemID or not newBankType then
        return false
    end

    local itemList = GetDB().global.directDeposit.itemList

    if itemList[tostring(itemID)] then
        itemList[tostring(itemID)].bankType = newBankType
        GetDB().global.directDeposit.itemList = itemList
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

    if self.progressCallback then
        self.progressCallback(nil, nil, nil)
    end
end

function DirectDeposit:PauseDeposit()
    if not self.isDepositing and not GuildBankTransfer.IsBusy() then
        return false
    end

    self.isPaused = true
    GuildBankTransfer.Cancel(GBT_OWNER)
    for _, timer in ipairs(self.depositTimers) do
        if timer then
            timer:Cancel()
        end
    end
    self.depositTimers = {}
    self.isDepositing = false
    self.depositedItems = {}
    self.failedItems = {}

    print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800Deposit paused.|r")

    if self.progressCallback then
        self.progressCallback(nil, nil, nil)
    end
    return true
end

function DirectDeposit:StopDeposit()
    if not self.isDepositing and not GuildBankTransfer.IsBusy() then
        return false
    end

    self.isPaused = true
    GuildBankTransfer.Cancel(GBT_OWNER)

    for _, timer in ipairs(self.depositTimers) do
        if timer then
            timer:Cancel()
        end
    end

    self.depositTimers = {}
    self.isDepositing = false

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

local ADDON_NAME, OneWoW_DirectDeposit = ...

OneWoW_DirectDeposit.DirectDeposit = {}
local DirectDeposit = OneWoW_DirectDeposit.DirectDeposit

DirectDeposit.guildBankOpen = false
DirectDeposit.isDepositing = false
DirectDeposit.isPaused = false
DirectDeposit.currentDepositIndex = 0
DirectDeposit.totalDepositItems = 0
DirectDeposit.depositedItems = {}
DirectDeposit.failedItems = {}
DirectDeposit.depositTimers = {}
DirectDeposit.progressCallback = nil

function DirectDeposit:Initialize()
    self:RegisterEvents()
    self.initialized = true
end

function DirectDeposit:RegisterEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "BANKFRAME_OPENED" then
            if not DirectDeposit.guildBankOpen then
                DirectDeposit:OnBankOpened()
            end
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local interactionType = ...
            if interactionType == Enum.PlayerInteractionType.GuildBanker then
                DirectDeposit.guildBankOpen = true
                DirectDeposit:OnBankOpened()
            end
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            local interactionType = ...
            if interactionType == Enum.PlayerInteractionType.GuildBanker then
                DirectDeposit.guildBankOpen = false
            end
        end
    end)

    self.eventFrame = eventFrame
end

function DirectDeposit:IsEnabled()
    return OneWoW_DirectDeposit.db.global.directDeposit.enabled == true
end

function DirectDeposit:GetCharacterSettings()
    local charSettings = OneWoW_DirectDeposit.db.char.directDeposit or {}
    if charSettings.useAccountSettings == nil then
        charSettings.useAccountSettings = true
    end
    return charSettings
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
    return settings.targetGold or 0
end

function DirectDeposit:OnBankOpened()
    if not self:IsEnabled() then
        return
    end

    self:NormalizeGold()
    self:DepositItemsToBank()
end

function DirectDeposit:NormalizeGold()
    local settings = self:GetActiveSettings()
    local targetGold = self:GetTargetGold()

    if targetGold == 0 then
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
            print("|cFFFFD100Direct Deposit:|r " .. checkmark .. " |cFFE67E22Deposited|r |cFFFFFFFF" .. GetMoneyString(excess, true) .. " to |cFF50C878Warband Bank|r")
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
                print("|cFFFFD100Direct Deposit:|r " .. checkmark .. " |cFF4A90E2Withdrew|r |cFFFFFFFF" .. GetMoneyString(toWithdraw, true) .. " from |cFF50C878Warband Bank|r")
            end
        end
    end
end

function DirectDeposit:DepositItemsToBank(manualTrigger)
    if not manualTrigger and not OneWoW_DirectDeposit.db.global.directDeposit.itemDepositEnabled then
        return
    end

    if self.isDepositing then
        print("|cFFFFD100Direct Deposit:|r |cFFFF8800Deposit already in progress. Use /dddeposit pause to stop.|r")
        return
    end

    local itemList = OneWoW_DirectDeposit.db.global.directDeposit.itemList or {}

    if not next(itemList) then
        if manualTrigger then
            print("|cFFFFD100Direct Deposit:|r |cFFFF0000No items in deposit list.|r")
        end
        return
    end

    local itemsToDeposit = {}
    for itemID, itemData in pairs(itemList) do
        if itemData and itemData.bankType then
            table.insert(itemsToDeposit, {itemID = tonumber(itemID), bankType = itemData.bankType, itemName = itemData.itemName})
        end
    end

    if #itemsToDeposit == 0 then
        if manualTrigger then
            print("|cFFFFD100Direct Deposit:|r |cFFFF0000No valid items to deposit.|r")
        end
        return
    end

    self.isDepositing = true
    self.isPaused = false
    self.currentDepositIndex = 0
    self.totalDepositItems = #itemsToDeposit
    self.depositedItems = {}
    self.failedItems = {}
    self.depositTimers = {}

    if manualTrigger then
        print("|cFFFFD100Direct Deposit:|r |cFF00FF00Starting manual deposit of " .. #itemsToDeposit .. " item(s)...|r")
    end

    local hasGuildItems = false
    for _, itemInfo in ipairs(itemsToDeposit) do
        if itemInfo.bankType == "guild" then
            hasGuildItems = true
            break
        end
    end
    local delayStep = hasGuildItems and 1.0 or 0.3

    local delay = delayStep
    for i, itemInfo in ipairs(itemsToDeposit) do
        local timer = C_Timer.After(delay, function()
            if self.isPaused then
                return
            end
            self.currentDepositIndex = i
            if self.progressCallback then
                self.progressCallback(i, #itemsToDeposit, itemInfo.itemName)
            end
            self:DepositItemByID(itemInfo.itemID, itemInfo.bankType, itemInfo.itemName)

            if i == #itemsToDeposit then
                C_Timer.After(0.5, function()
                    self:FinishDeposit()
                end)
            end
        end)
        table.insert(self.depositTimers, timer)
        delay = delay + delayStep
    end
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
                            local ok, bindType = pcall(C_Item.GetItemBindType, itemLocation)
                            if ok and (bindType == Enum.ItemBind.OnAcquire or bindType == Enum.ItemBind.Quest) then
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
            print("|cFFFFD100Direct Deposit:|r " .. checkmark .. " |cFFE67E22Deposited|r |cFFFFFFFF" .. depositedCount .. "x " .. resolvedItemName .. "|r to " .. bankTypeText)
        end
    elseif hadError then
        table.insert(self.failedItems, {itemID = itemID, itemName = resolvedItemName, reason = errorReason})

        if not self.isDepositing then
            local errorIcon = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:16|t"
            print("|cFFFFD100Direct Deposit:|r " .. errorIcon .. " |cFFFF0000Cannot deposit|r |cFFFFFFFF" .. resolvedItemName .. "|r - " .. errorReason)
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

    local itemList = OneWoW_DirectDeposit.db.global.directDeposit.itemList or {}

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
        print("|cFFFF0000DirectDeposit:|r Delete failed - no itemID")
        return false
    end

    local itemIDStr = tostring(itemID)
    print("|cFFFFD100DirectDeposit:|r Attempting to delete itemID: " .. itemIDStr)

    if not OneWoW_DirectDeposit.db.global.directDeposit.itemList then
        return false
    end

    local itemList = OneWoW_DirectDeposit.db.global.directDeposit.itemList

    if itemList[itemIDStr] then
        itemList[itemIDStr] = nil
        print("|cFF00FF00DirectDeposit:|r Item deleted successfully: " .. itemIDStr)
        return true
    elseif itemList[itemID] then
        itemList[itemID] = nil
        print("|cFF00FF00DirectDeposit:|r Item deleted successfully: " .. itemID .. " (numeric key)")
        return true
    else
        print("|cFFFF0000DirectDeposit:|r Item not found in list: " .. itemIDStr)
        print("|cFFFF0000DirectDeposit:|r Available items: " .. table.concat(OneWoW_DirectDeposit:GetAvailableItemIDs(), ", "))
    end

    return false
end

function DirectDeposit:GetItemList()
    return OneWoW_DirectDeposit.db.global.directDeposit.itemList or {}
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

    local itemList = OneWoW_DirectDeposit.db.global.directDeposit.itemList or {}

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

    print("|cFFFFD100Direct Deposit:|r " .. checkmark .. " |cFF00FF00Deposit Complete!|r")
    print("|cFFFFD100Direct Deposit:|r " .. checkmark .. " |cFFFFFFFFSuccessfully deposited " .. successCount .. " item type(s)|r")

    if successCount > 0 then
        for _, item in ipairs(self.depositedItems) do
            local bankTypeText = item.bankType == "warband" and "|cFF50C878Warband|r"
                              or item.bankType == "personal" and "|cFF4A90E2Personal|r"
                              or "|cFFFF8C00Guild|r"
            print("  " .. checkmark .. " |cFFFFFFFF" .. item.count .. "x " .. item.itemName .. "|r to " .. bankTypeText)
        end
    end

    if failedCount > 0 then
        print("|cFFFFD100Direct Deposit:|r " .. errorIcon .. " |cFFFF0000Failed to deposit " .. failedCount .. " item type(s)|r")
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
    if not self.isDepositing then
        return false
    end

    self.isPaused = true
    print("|cFFFFD100Direct Deposit:|r |cFFFF8800Deposit paused.|r")
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

    print("|cFFFFD100Direct Deposit:|r |cFFFF0000Deposit stopped.|r")

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

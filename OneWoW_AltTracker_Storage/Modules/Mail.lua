local addonName, ns = ...

ns.Mail = {}
local Module = ns.Mail

local private = {
    hooks = {},
    rescanContext = {},
}

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    private.hooks.TakeInboxItem = TakeInboxItem
    TakeInboxItem = function(...)
        private.ScanCollectedMail("TakeInboxItem", 1, ...)
    end

    private.hooks.TakeInboxMoney = TakeInboxMoney
    TakeInboxMoney = function(...)
        private.ScanCollectedMail("TakeInboxMoney", 1, ...)
    end

    private.hooks.AutoLootMailItem = AutoLootMailItem
    AutoLootMailItem = function(...)
        private.ScanCollectedMail("AutoLootMailItem", 1, ...)
    end
end

function private.ScanCollectedMail(oFunc, attempt, index, subIndex)
    if not index then
        return
    end

    local subject = select(4, GetInboxHeaderInfo(index))
    if not subject then
        return
    end

    local success = private.RecordMail(index)
    if not success and attempt <= 5 then
        wipe(private.rescanContext)
        private.rescanContext.oFunc = oFunc
        private.rescanContext.attempt = attempt + 1
        private.rescanContext.index = index
        private.rescanContext.subIndex = subIndex
        C_Timer.After(0.2, private.RescanHandler)
    else
        private.hooks[oFunc](index, subIndex)
    end
end

function private.RescanHandler()
    if private.rescanContext.oFunc then
        private.ScanCollectedMail(
            private.rescanContext.oFunc,
            private.rescanContext.attempt,
            private.rescanContext.index,
            private.rescanContext.subIndex
        )
    end
end

function private.RecordMail(index)
    local AccountingAddon = _G.OneWoW_AltTracker_Accounting
    if not AccountingAddon or not AccountingAddon.Transactions or not OneWoW_AltTracker_Accounting_DB then
        return false
    end

    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem = GetInboxHeaderInfo(index)
    local invoiceType, itemName, buyer, bid, buyout, deposit, consignment, count = GetInboxInvoiceInfo(index)
    local quantity = count or 1

    if invoiceType == "seller" or invoiceType == "seller_temp_invoice" then
        if not money or money == 0 then return true end
        return AccountingAddon.Transactions:RecordIncome("auction_sale", money, buyer or "Auction House", nil, itemName, quantity, "Auction sold")

    elseif invoiceType == "buyer" then
        return true

    elseif money and money > 0 and CODAmount and CODAmount > 0 then
        local itemLink = GetInboxItemLink(index, 1)
        local itemInfoName = itemLink and select(1, GetItemInfo(itemLink)) or itemName
        AccountingAddon.Transactions:RecordExpense("mail_cod_send", CODAmount, sender or "Unknown", itemLink, itemInfoName or "Item", nil, "COD payment")
        return true

    elseif money and money > 0 and not invoiceType then
        AccountingAddon.Transactions:RecordIncome("money_transfer_in", money, sender or "Unknown", nil, "Gold Transfer", nil, "Received via mail")
        return true
    end

    return true
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local existingMail = charData.mail or {mails = {}, numMails = 0}
    local mailbox = {mails = {}, numMails = 0}
    local numItems = GetInboxNumItems()
    mailbox.numMails = numItems

    for mailID = 1, math.min(numItems, 20) do
        local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem,
              wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(mailID)

        if sender then
            mailbox.mails[mailID] = {
                sender = sender,
                subject = subject,
                money = money,
                CODAmount = CODAmount,
                daysLeft = daysLeft,
                hasItem = hasItem,
                wasRead = wasRead,
                wasReturned = wasReturned,
                canReply = canReply,
                isGM = isGM,
                items = {},
                collectedAt = time(),
            }

            if hasItem then
                for attachmentIndex = 1, ATTACHMENTS_MAX_RECEIVE do
                    local name, mailItemID, itemTexture, count, quality, canUse = GetInboxItem(mailID, attachmentIndex)
                    if name then
                        local itemLink = GetInboxItemLink(mailID, attachmentIndex)
                        local itemID = mailItemID or (itemLink and tonumber(itemLink:match("item:(%d+)")))
                        local itemName, sellPrice = nil, 0
                        if itemLink then
                            itemName, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
                            sellPrice = sellPrice or 0
                        end
                        mailbox.mails[mailID].items[attachmentIndex] = {
                            name = name,
                            itemLink = itemLink,
                            itemID = itemID,
                            itemName = itemName,
                            texture = itemTexture,
                            sellPrice = sellPrice,
                            count = count,
                            quality = quality,
                            canUse = canUse,
                        }
                    end
                end
            end
        end
    end

    if numItems >= 20 then
        for oldMailID, oldMail in pairs(existingMail.mails or {}) do
            if not mailbox.mails[oldMailID] then
                local expired = false
                if oldMail.collectedAt and oldMail.daysLeft then
                    local expireTime = oldMail.collectedAt + (oldMail.daysLeft * 86400)
                    if time() > expireTime then
                        expired = true
                    end
                end
                if not expired then
                    mailbox.mails[oldMailID] = oldMail
                    mailbox.mails[oldMailID].isAwaitingCollection = true
                end
            end
        end
    end

    mailbox.hasNewMail = false
    for _, mail in pairs(mailbox.mails) do
        if not mail.wasRead or mail.isAwaitingCollection then
            mailbox.hasNewMail = true
            break
        end
    end

    charData.mail = mailbox
    charData.mailLastUpdate = time()
    return true
end

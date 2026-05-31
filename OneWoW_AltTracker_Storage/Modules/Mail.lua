local addonName, ns = ...

ns.Mail = {}
local Module = ns.Mail

local private = {
    hooks = {},
    rescanContext = {},
}

local SECONDS_PER_DAY = 86400

-- Compute live seconds-until-expiry for a stored mail entry. Returns nil if the
-- entry is missing the data needed to compute it (e.g. a legacy/incomplete row).
local function ComputeRemainingSeconds(mail)
    if not mail then return nil end
    local daysLeft = mail.daysLeft
    local collectedAt = mail.collectedAt
    if not daysLeft or not collectedAt then return nil end
    return (daysLeft * SECONDS_PER_DAY) - (time() - collectedAt)
end

-- Build a summary of a stored mailbox: number of non-expired entries, soonest
-- expiry in seconds, and flags. Entries with computed expiry already in the
-- past are excluded; the caller is expected to call PruneExpired for the
-- persistent cleanup pass.
local function SummarizeMails(mailbox)
    local summary = {
        count = 0,
        oldestExpirySeconds = nil,
        hasUnread = false,
        hasCOD = false,
        hasReturned = false,
        hasAttachment = false,
    }
    if not mailbox or not mailbox.mails then return summary end

    for _, mail in pairs(mailbox.mails) do
        local remaining = ComputeRemainingSeconds(mail)
        if not remaining or remaining > 0 then
            summary.count = summary.count + 1
            if remaining and (not summary.oldestExpirySeconds or remaining < summary.oldestExpirySeconds) then
                summary.oldestExpirySeconds = remaining
            end
            if mail.wasRead == false then summary.hasUnread = true end
            if mail.CODAmount and mail.CODAmount > 0 then summary.hasCOD = true end
            if mail.wasReturned then summary.hasReturned = true end
            if mail.hasItem then summary.hasAttachment = true end
        end
    end

    return summary
end

-- Drop entries whose computed expiry has already passed. Returns true if any
-- entries were removed. Safe to call repeatedly; on incomplete entries (no
-- collectedAt / daysLeft) it leaves the entry alone.
local function PruneExpired(mailbox)
    if not mailbox or not mailbox.mails then return false end
    local removed = false
    for mailID, mail in pairs(mailbox.mails) do
        local remaining = ComputeRemainingSeconds(mail)
        if remaining and remaining <= 0 then
            mailbox.mails[mailID] = nil
            removed = true
        end
    end
    return removed
end

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
    local AccountingAddon = OneWoW_AltTracker_Accounting
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
        local itemInfoName = itemLink and select(1, C_Item.GetItemInfo(itemLink)) or itemName
        AccountingAddon.Transactions:RecordExpense("mail_cod_send", CODAmount, sender or "Unknown", itemLink, itemInfoName or "Item", nil, "COD payment")
        return true

    elseif money and money > 0 and not invoiceType then
        AccountingAddon.Transactions:RecordIncome("money_transfer_in", money, sender or "Unknown", nil, "Gold Transfer", nil, "Received via mail")
        return true
    end

    return true
end

-- Public summary accessor used by both Storage and AltTracker UI. Reads only
-- persisted state, so it's safe to call for any character key (current or alt).
function Module:GetSummary(mailbox)
    return SummarizeMails(mailbox)
end

-- Drops already-expired entries from the stored mailbox and refreshes the
-- derived flags. Called from the lightweight flag refresh path so the count
-- displayed in the UI never includes mail that the server has already deleted.
function Module:RefreshDerived(mailbox)
    if not mailbox then return end
    PruneExpired(mailbox)
    local summary = SummarizeMails(mailbox)
    mailbox.numMails = summary.count
    mailbox.hasAnyMail = summary.count > 0
end

-- Lightweight refresh that works away from the mailbox. We do NOT trust
-- HasNewMail() as the authoritative signal for "this character has mail" --
-- it only reflects the minimap envelope, which the user clears just by looking
-- at the mailbox. Instead we derive "has mail" from the stored mail table
-- (filtered to drop already-expired entries), and OR in HasNewMail() as a
-- supplemental hint so a freshly arrived mail on the current character lights
-- up the icon even before we've had a chance to scan the inbox.
function Module:UpdateHasNewMailFlag(charKey, charData)
    if not charKey or not charData then return false end

    charData.mail = charData.mail or { mails = {}, numMails = 0 }
    local mailbox = charData.mail

    PruneExpired(mailbox)
    local summary = SummarizeMails(mailbox)

    mailbox.numMails = summary.count
    mailbox.hasAnyMail = summary.count > 0

    local hasNew = false
    if type(HasNewMail) == "function" then
        hasNew = HasNewMail() == true
    end
    mailbox.hasNewMail = hasNew

    -- Server-side "new mail arrived" on the current character: light up the
    -- icon even if we haven't scanned the inbox yet to confirm. The next
    -- MAIL_SHOW will populate the actual list.
    if hasNew then
        mailbox.hasAnyMail = true
    end

    charData.mailLastUpdate = time()
    return true
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    -- If the mailbox UI isn't actually open, GetInboxNumItems() / GetInboxHeaderInfo()
    -- return 0/nil. Wiping charData.mail in that case would destroy known mail state.
    -- Instead refresh the derived flags from existing data plus HasNewMail().
    local mailboxOpen = MailFrame and MailFrame:IsShown()
    if not mailboxOpen then
        return self:UpdateHasNewMailFlag(charKey, charData)
    end

    local existingMail = charData.mail or {mails = {}, numMails = 0}
    local mailbox = {mails = {}, numMails = 0}
    local numItems = GetInboxNumItems()

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
                            itemName, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemLink)
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

    -- Beyond index 20, GetInboxHeaderInfo returns nil. Carry forward any
    -- prior entries that are still not yet expired so we don't lose data
    -- about mails the player has but hasn't scrolled to.
    if numItems >= 20 then
        for oldMailID, oldMail in pairs(existingMail.mails or {}) do
            if not mailbox.mails[oldMailID] then
                local remaining = ComputeRemainingSeconds(oldMail)
                if not remaining or remaining > 0 then
                    mailbox.mails[oldMailID] = oldMail
                    mailbox.mails[oldMailID].isAwaitingCollection = true
                end
            end
        end
    end

    PruneExpired(mailbox)

    local summary = SummarizeMails(mailbox)
    mailbox.numMails = summary.count
    mailbox.hasAnyMail = summary.count > 0

    -- Retain hasNewMail for compatibility with anything that still reads it.
    -- It reflects "is there unread mail" rather than "is there mail" -- the
    -- UI now uses hasAnyMail for the persistent icon state.
    local hasUnread = summary.hasUnread
    if type(HasNewMail) == "function" and HasNewMail() == true then
        hasUnread = true
    end
    mailbox.hasNewMail = hasUnread

    charData.mail = mailbox
    charData.mailLastUpdate = time()
    return true
end

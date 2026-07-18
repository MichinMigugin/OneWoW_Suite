local _, ns = ...

ns.MailClassify = {}
local MailClassify = ns.MailClassify

--- Turn a localized Blizzard subject template (e.g. AUCTION_EXPIRED_MAIL_SUBJECT,
--- "Auction expired: %s") into an anchored Lua pattern: escape pattern magic
--- characters the localized text may contain (`-`, `(`, `)`, ...), then widen
--- the %s placeholder to a wildcard.
local function SubjectPattern(template)
    local pattern = template:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    pattern = pattern:gsub("%%%%s", ".*")
    return "^" .. pattern
end

local EXPIRED_PATTERN = SubjectPattern(AUCTION_EXPIRED_MAIL_SUBJECT)
local REMOVED_PATTERN = SubjectPattern(AUCTION_REMOVED_MAIL_SUBJECT)

--- Classify an inbox mail by auction invoice / subject heuristics.
---@param index number
---@return string category "sold"|"bought"|"canceled"|"expired"|"gold"|"items"|"other"
---@return boolean hasCOD
---@return boolean isGM
function MailClassify:Classify(index)
    local _, _, _, subject, money, CODAmount, _, hasItem, _, _, _, _, isGM = GetInboxHeaderInfo(index)
    local hasCOD = (CODAmount or 0) > 0
    money = money or 0
    hasItem = hasItem and true or false

    if isGM then
        return "other", hasCOD, true
    end

    local invoiceType = GetInboxInvoiceInfo(index)
    if invoiceType == "seller" or invoiceType == "seller_temp_invoice" then
        return "sold", hasCOD, false
    end
    if invoiceType == "buyer" then
        return "bought", hasCOD, false
    end

    -- No English-substring fallback: subjects that match neither localized
    -- template classify by content below (or "other") instead of guessing.
    if subject then
        if subject:find(EXPIRED_PATTERN) then
            return "expired", hasCOD, false
        end
        if subject:find(REMOVED_PATTERN) then
            return "canceled", hasCOD, false
        end
    end

    if money > 0 and not hasItem then
        return "gold", hasCOD, false
    end
    if hasItem then
        return "items", hasCOD, false
    end
    if money > 0 then
        return "gold", hasCOD, false
    end

    return "other", hasCOD, false
end

--- Whether a mail matches a collect filter.
---@param index number
---@param filter string "all"|"gold"|"items"|"sold"|"bought"|"canceled"|"expired"|"other"|"selected"
---@param selected table|nil map of index -> true
---@return boolean
function MailClassify:MatchesFilter(index, filter, selected)
    if filter == "all" then
        return true
    end
    if filter == "selected" then
        return selected and selected[index] == true
    end

    local category = self:Classify(index)
    if filter == "gold" then
        local _, _, _, _, money = GetInboxHeaderInfo(index)
        return (money or 0) > 0
    end
    if filter == "items" then
        local _, _, _, _, _, _, _, hasItem = GetInboxHeaderInfo(index)
        return hasItem and true or false
    end
    return category == filter
end

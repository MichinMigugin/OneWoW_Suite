local _, ns = ...

-- ============================================================================
-- RunLog
-- ============================================================================
-- Session-scoped ring buffer behind the Activity tab. Errors always mirror to
-- chat; info/warn mirror when mirrorLogToChat is on. Deliberately not persisted
-- to SavedVariables.
-- ============================================================================

ns.RunLog = {}
local RunLog = ns.RunLog

local MAX_ENTRIES = 200
local CHAT_ITEM_CAP = 3

local entries = {} -- chronological, oldest first
local onChanged

--- Build short (chat) and full (Activity detail) loot strings.
---@param gold number|nil copper
---@param items { link: string, count: number }[]|nil
---@return string shortJoined, string fullJoined, number itemCount
function RunLog.FormatLoot(gold, items)
    local L = ns.L
    local shortParts, fullParts = {}, {}
    local itemCount = 0

    if gold and gold > 0 then
        local moneyStr = OneWoW.Format.FormatGold(gold)
        tinsert(shortParts, moneyStr)
        tinsert(fullParts, moneyStr)
    end

    local itemShort, itemFull = {}, {}
    for _, it in ipairs(items or {}) do
        local n = it.count or 1
        itemCount = itemCount + n
        local label = it.link or "?"
        if n > 1 then
            label = label .. "x" .. n
        end
        tinsert(itemFull, label)
        if #itemShort < CHAT_ITEM_CAP then
            tinsert(itemShort, label)
        end
    end

    if #itemFull > 0 then
        local fullStr = table.concat(itemFull, ", ")
        tinsert(fullParts, fullStr)
        local shortStr = table.concat(itemShort, ", ")
        local overflow = #itemFull - CHAT_ITEM_CAP
        if overflow > 0 then
            shortStr = shortStr .. string.format(L["LOG_LOOT_MORE"], overflow)
        end
        tinsert(shortParts, shortStr)
    end

    return table.concat(shortParts, " | "), table.concat(fullParts, "\n"), itemCount
end

--- Append a log entry; oldest entries fall off past MAX_ENTRIES.
---@param severity "info"|"warn"|"error"
---@param shipmentName string|nil
---@param target string|nil
---@param message string already localized short summary
---@param opts { code?: string, detail?: string, itemLink?: string }|nil
function RunLog:Add(severity, shipmentName, target, message, opts)
    opts = opts or {}
    tinsert(entries, {
        time = time(),
        severity = severity,
        shipmentName = shipmentName,
        target = target,
        message = message,
        code = opts.code,
        detail = opts.detail,
        itemLink = opts.itemLink,
    })
    while #entries > MAX_ENTRIES do
        tremove(entries, 1)
    end

    local mirror = severity == "error"
        or (ns.db and ns.db.global.mail.mirrorLogToChat)
    if mirror then
        local context = ""
        if shipmentName and shipmentName ~= "" then
            context = shipmentName
            if target and target ~= "" then
                context = context .. " >> " .. target
            end
            context = context .. ": "
        elseif target and target ~= "" then
            context = target .. ": "
        end
        print(ns.L["ADDON_CHAT_PREFIX"] .. " " .. context .. message)
    end

    if onChanged then
        onChanged()
    end
end

--- Chronological entries (oldest first). Do not mutate.
function RunLog:GetAll()
    return entries
end

function RunLog:Clear()
    wipe(entries)
    if onChanged then
        onChanged()
    end
end

--- Single subscriber (the Activity tab).
function RunLog:SetOnChanged(fn)
    onChanged = fn
end

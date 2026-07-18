local _, ns = ...

-- ============================================================================
-- RunLog
-- ============================================================================
-- Session-scoped ring buffer behind the Activity tab. Errors also mirror to
-- chat so a user who never opens the tab still learns their mail didn't go.
-- Deliberately not persisted to SavedVariables.

ns.RunLog = {}
local RunLog = ns.RunLog

local MAX_ENTRIES = 200

local entries = {} -- chronological, oldest first
local onChanged

--- Append a log entry; oldest entries fall off past MAX_ENTRIES.
---@param severity "info"|"warn"|"error"
---@param shipmentName string|nil
---@param target string|nil
---@param message string already localized
function RunLog:Add(severity, shipmentName, target, message)
    tinsert(entries, {
        time = time(),
        severity = severity,
        shipmentName = shipmentName,
        target = target,
        message = message,
    })
    while #entries > MAX_ENTRIES do
        tremove(entries, 1)
    end

    if severity == "error" then
        local context = ""
        if shipmentName and shipmentName ~= "" then
            context = shipmentName
            if target and target ~= "" then
                context = context .. " → " .. target
            end
            context = context .. ": "
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

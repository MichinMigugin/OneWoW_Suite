local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ErrorAnalyzer = {}
Addon.ErrorAnalyzer = ErrorAnalyzer

local format = string.format
local strmatch = string.match
local strlower = string.lower
local strfind = string.find
local tinsert = tinsert
local tostring = tostring
local type = type

local ROOT_CAUSES = {
    NIL_REFERENCE  = "NIL_REFERENCE",
    NIL_CALL       = "NIL_CALL",
    TYPE_MISMATCH  = "TYPE_MISMATCH",
    SECURE_ACTION  = "SECURE_ACTION",
    TAINT          = "TAINT",
    SECRET_VALUE   = "SECRET_VALUE",
    STACK_OVERFLOW = "STACK_OVERFLOW",
    LUA_WARNING    = "LUA_WARNING",
    UNKNOWN        = "UNKNOWN",
}

local RC_LABEL_KEYS = {
    NIL_REFERENCE  = "ERR_RC_NIL_REFERENCE",
    NIL_CALL       = "ERR_RC_NIL_CALL",
    TYPE_MISMATCH  = "ERR_RC_TYPE_MISMATCH",
    SECURE_ACTION  = "ERR_RC_SECURE_ACTION",
    TAINT          = "ERR_RC_TAINT",
    SECRET_VALUE   = "ERR_RC_SECRET_VALUE",
    STACK_OVERFLOW = "ERR_RC_STACK_OVERFLOW",
    LUA_WARNING    = "ERR_RC_LUA_WARNING",
    UNKNOWN        = "ERR_RC_UNKNOWN",
}

local RC_LABEL_DEFAULTS = {
    NIL_REFERENCE  = "Nil reference",
    NIL_CALL       = "Nil call",
    TYPE_MISMATCH  = "Type mismatch",
    SECURE_ACTION  = "Secure action",
    TAINT          = "Taint",
    SECRET_VALUE   = "Secret value",
    STACK_OVERFLOW = "Stack overflow",
    LUA_WARNING    = "Lua warning",
    UNKNOWN        = "Unknown",
}

local function getL()
    return Addon.L or {}
end

local function rcLabel(rc)
    local L = getL()
    local key = RC_LABEL_KEYS[rc]
    if key and L[key] then
        return L[key]
    end
    return RC_LABEL_DEFAULTS[rc] or rc
end

local function detectErrorType(message)
    if not message or message == "" then
        return "LUA_ERROR", nil, nil
    end

    local actionType = strmatch(message, "^%[ADDON_ACTION_(FORBIDDEN)%]")
    if actionType then
        local reportedAddon = strmatch(message, "AddOn '([^']+)'")
        local protectedFn = strmatch(message, "protected function '([^']+)'")
        return "ADDON_ACTION_FORBIDDEN", reportedAddon, protectedFn
    end

    actionType = strmatch(message, "^%[ADDON_ACTION_(BLOCKED)%]")
    if actionType then
        local reportedAddon = strmatch(message, "AddOn '([^']+)'")
        local protectedFn = strmatch(message, "protected function '([^']+)'")
        return "ADDON_ACTION_BLOCKED", reportedAddon, protectedFn
    end

    if strmatch(message, "^LUA_WARNING:") then
        return "LUA_WARNING", nil, nil
    end

    return "LUA_ERROR", nil, nil
end

local function extractDetail(message)
    if not message or message == "" then
        return ""
    end

    if strmatch(message, "^%[ADDON_ACTION_") then
        return message
    end

    local warnBody = strmatch(message, "^LUA_WARNING: (.+)$")
    if warnBody then
        return warnBody
    end

    local detail = strmatch(message, "^.-:%d+: (.+)$")
    if detail then
        return detail
    end

    return message
end

local function extractTaintSource(text)
    if not text or text == "" then return nil end
    return strmatch(text, "tainted by '([^']+)'")
        or strmatch(text, 'tainted by "([^"]+)"')
        or strmatch(text, "tainted by (%S+)%)")
end

local function isBlizzardAddon(name)
    if not name then return false end
    return strfind(name, "^Blizzard_") ~= nil
end

local function detectRootCause(detail, errorType)
    if not detail or detail == "" then
        if errorType == "ADDON_ACTION_FORBIDDEN" or errorType == "ADDON_ACTION_BLOCKED" then
            return ROOT_CAUSES.SECURE_ACTION
        end
        if errorType == "LUA_WARNING" then
            return ROOT_CAUSES.LUA_WARNING
        end
        return ROOT_CAUSES.UNKNOWN
    end

    local lower = strlower(detail)

    if strfind(lower, "stack overflow", 1, true) then
        return ROOT_CAUSES.STACK_OVERFLOW
    end

    local hasSecret = strfind(lower, "secret", 1, true)
    local hasTainted = strfind(lower, "tainted", 1, true)

    if hasSecret and hasTainted then
        return ROOT_CAUSES.SECRET_VALUE
    end

    if hasTainted then
        return ROOT_CAUSES.TAINT
    end

    if hasSecret then
        return ROOT_CAUSES.SECRET_VALUE
    end

    if strfind(lower, "attempt to index", 1, true) then
        return ROOT_CAUSES.NIL_REFERENCE
    end

    if strfind(lower, "attempt to call", 1, true) then
        return ROOT_CAUSES.NIL_CALL
    end

    if strfind(lower, "bad argument", 1, true) then
        return ROOT_CAUSES.TYPE_MISMATCH
    end

    if strfind(lower, "attempt to perform arithmetic", 1, true)
        or strfind(lower, "attempt to concatenate", 1, true)
        or strfind(lower, "attempt to compare", 1, true)
        or strfind(lower, "attempt to perform numeric", 1, true) then
        return ROOT_CAUSES.TYPE_MISMATCH
    end

    if errorType == "ADDON_ACTION_FORBIDDEN" or errorType == "ADDON_ACTION_BLOCKED" then
        return ROOT_CAUSES.SECURE_ACTION
    end

    if errorType == "LUA_WARNING" then
        return ROOT_CAUSES.LUA_WARNING
    end

    return ROOT_CAUSES.UNKNOWN
end

local function extractAddonFromPath(path)
    if not path then return nil end
    return strmatch(path, "[/\\]AddOns[/\\]([^/\\]+)")
end

local function isLibraryPath(path)
    if not path then return false end
    local lower = strlower(path)
    return strfind(lower, "[/\\]libs[/\\]", 1, false) ~= nil
end

local function parseStackFrames(stackStr)
    if not stackStr or stackStr == "" then
        return {}
    end

    local frames = {}
    for line in stackStr:gmatch("[^\n]+") do
        local trimmed = strtrim(line)
        if trimmed ~= "" then
            local frame = { raw = trimmed }

            if strmatch(trimmed, "^%[C%]") then
                frame.isC = true
            else
                local bracketPath, lineNum, desc = strmatch(trimmed, "^%[(.-)%]:(%d+): (.+)$")
                if bracketPath then
                    frame.path = bracketPath
                    frame.line = lineNum
                    frame.desc = desc
                else
                    local rawPath, lineNum2, desc2 = strmatch(trimmed, "^(.-):(%d+): (.+)$")
                    if rawPath and rawPath ~= "" then
                        frame.path = rawPath
                        frame.line = lineNum2
                        frame.desc = desc2
                    end
                end

                if frame.path then
                    frame.addon = extractAddonFromPath(frame.path)
                    frame.isLib = isLibraryPath(frame.path)
                    frame.funcName = strmatch(frame.desc or "", "in function [`'](.-)['`]$")
                        or strmatch(frame.desc or "", "in function (<.->)$")
                end
            end

            tinsert(frames, frame)
        end
    end

    return frames
end

local function attributeAddons(frames, messageReportedAddon, taintSource)
    local reportedAddon = messageReportedAddon
    local offendingAddon = nil
    local triggerLocation = nil

    if not reportedAddon then
        for _, f in ipairs(frames) do
            if f.addon and not f.isC then
                reportedAddon = f.addon
                break
            end
        end
    end

    for i = 1, #frames do
        local f = frames[i]
        if not f.isC and f.path then
            local loc = f.path
            if f.line then
                loc = loc .. ":" .. f.line
            end
            if f.funcName then
                loc = loc .. " in '" .. f.funcName .. "'"
            end
            triggerLocation = loc
            break
        end
    end

    if taintSource then
        offendingAddon = taintSource
    else
        for i = #frames, 1, -1 do
            local f = frames[i]
            if f.addon and not f.isC and not f.isLib and not isBlizzardAddon(f.addon) then
                if f.addon ~= reportedAddon then
                    offendingAddon = f.addon
                    break
                end
            end
        end

        if not offendingAddon then
            for i = #frames, 1, -1 do
                local f = frames[i]
                if f.addon and not f.isC and not f.isLib then
                    if f.addon ~= reportedAddon then
                        offendingAddon = f.addon
                        break
                    end
                end
            end
        end

        if not offendingAddon then
            offendingAddon = reportedAddon
        end
    end

    return reportedAddon, offendingAddon, triggerLocation
end

local function buildRecommendation(rootCause, detail, errorType, protectedAction, offendingAddon, taintSource)
    local L = getL()

    if rootCause == ROOT_CAUSES.NIL_REFERENCE then
        local fieldName = strmatch(detail or "", "%(global '([^']+)'%)") or strmatch(detail or "", "%(field '([^']+)'%)")
        if fieldName then
            return format(L["ERR_REC_NIL_REF"] or "'%s' is nil when indexed. Ensure the object exists before this line runs.", fieldName)
        end
        return L["ERR_REC_NIL_REF_GENERIC"] or "A nil value is being indexed. Check that the object exists before accessing its fields."
    end

    if rootCause == ROOT_CAUSES.NIL_CALL then
        local methodName = strmatch(detail or "", "call method '([^']+)'") or strmatch(detail or "", "call global '([^']+)'")
        if methodName then
            return format(L["ERR_REC_NIL_CALL"] or "'%s' is nil when called. Verify the function exists and its source file loaded.", methodName)
        end
        return L["ERR_REC_NIL_CALL_GENERIC"] or "A nil value is being called as a function. Verify it is defined and its file loaded."
    end

    if rootCause == ROOT_CAUSES.TYPE_MISMATCH then
        local argNum, funcName = strmatch(detail or "", "bad argument #(%d+) to '([^']+)'")
        if argNum and funcName then
            return format(L["ERR_REC_TYPE_MISMATCH"] or "Argument #%s to '%s' has the wrong type. Check inputs to this call.", argNum, funcName)
        end
        return L["ERR_REC_TYPE_MISMATCH_GENERIC"] or "A value has an unexpected type. Check the inputs to this operation."
    end

    if rootCause == ROOT_CAUSES.SECURE_ACTION then
        local action = protectedAction or "the protected action"
        return format(L["ERR_REC_SECURE"] or "%s is blocked in a restricted state. Move the call to a safe point outside combat or secure flows.", action)
    end

    if rootCause == ROOT_CAUSES.SECRET_VALUE then
        if taintSource then
            return format(L["ERR_REC_SECRET_TAINTED"] or "%s tainted a value that Blizzard code later used as a secret. Update or disable %s, or report this to its author.", taintSource, taintSource)
        end
        return L["ERR_REC_SECRET"] or "A secret value was used in an unsupported way. Do not concatenate, compare, or coerce secret values directly."
    end

    if rootCause == ROOT_CAUSES.TAINT then
        if taintSource then
            return format(L["ERR_REC_TAINT_SOURCE"] or "%s tainted a secure path. Update or disable %s, or report this to its author.", taintSource, taintSource)
        end
        local source = offendingAddon or "addon code"
        return format(L["ERR_REC_TAINT"] or "Insecure code from %s touched a secure path. Avoid writing to Blizzard-owned frames or state from addon code.", source)
    end

    if rootCause == ROOT_CAUSES.STACK_OVERFLOW then
        return L["ERR_REC_STACK_OVERFLOW"] or "Infinite recursion detected. Check for circular function calls in this code path."
    end

    if rootCause == ROOT_CAUSES.LUA_WARNING then
        return L["ERR_REC_LUA_WARNING"] or "WoW flagged suspicious content. Review the warned file for unsupported attributes or syntax."
    end

    return L["ERR_REC_GENERIC"] or "Check the values feeding this line. An input is invalid when this code path runs."
end

function ErrorAnalyzer:Analyze(errorData)
    if not errorData or type(errorData) ~= "table" then
        return nil
    end

    local message = errorData.message or ""
    local errorType, messageAddon, protectedAction = detectErrorType(message)
    local detail = extractDetail(message)
    local rootCause = detectRootCause(detail, errorType)
    local taintSource = extractTaintSource(message) or extractTaintSource(detail)
    local frames = parseStackFrames(errorData.stack)
    local reportedAddon, offendingAddon, triggerLocation = attributeAddons(frames, messageAddon, taintSource)
    local recommendation = buildRecommendation(rootCause, detail, errorType, protectedAction, offendingAddon, taintSource)

    return {
        errorType = errorType,
        rootCause = rootCause,
        rootCauseLabel = rcLabel(rootCause),
        detail = detail,
        reportedAddon = reportedAddon,
        offendingAddon = offendingAddon,
        taintSource = taintSource,
        protectedAction = protectedAction,
        triggerLocation = triggerLocation,
        recommendation = recommendation,
    }
end

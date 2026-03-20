local _, Addon = ...

local tinsert = tinsert
local type = type
local tostring = tostring
local date = date
local format = string.format

Addon.ErrorExport = {}

local function formatTime(err)
    if type(err.time) == "number" then
        return date("%Y-%m-%d %H:%M:%S", err.time)
    end
    return tostring(err.time or "?")
end

--- Remove WoW inline color codes for paste targets that do not understand them.
function Addon.ErrorExport.StripWoWColorCodes(s)
    if type(s) ~= "string" or s == "" then
        return ""
    end
    local t = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    t = t:gsub("|r", "")
    return t
end

function Addon.ErrorExport.BuildPlainText(err, L)
    L = L or {}
    local lines = {}
    tinsert(lines, (L["ERR_DETAIL_TIME"] or "TIME:") .. " " .. formatTime(err))
    tinsert(lines, (L["ERR_DETAIL_SESSION"] or "SESSION:") .. " " .. tostring(err.session or "?"))
    if err.counter and err.counter > 1 then
        tinsert(lines, (L["ERR_DETAIL_COUNT"] or "COUNT:") .. " " .. tostring(err.counter))
    end
    tinsert(lines, "")
    tinsert(lines, (L["ERR_DETAIL_MESSAGE"] or "MESSAGE:"))
    tinsert(lines, err.message or "")
    tinsert(lines, "")
    tinsert(lines, (L["ERR_DETAIL_STACK"] or "STACK TRACE:"))
    tinsert(lines, err.stack or "")
    if err.locals and err.locals ~= "" then
        tinsert(lines, "")
        tinsert(lines, (L["ERR_DETAIL_LOCALS"] or "LOCALS:"))
        tinsert(lines, err.locals)
    end
    return table.concat(lines, "\n")
end

local function buildHeaderLines()
    local version, _, _, interfaceVersion = GetBuildInfo()
    local lines = {
        format("WoW: %s (%s)", tostring(version or "?"), tostring(interfaceVersion or "?")),
        format("Locale: %s", GetLocale() or "?"),
        "",
    }
    return lines
end

function Addon.ErrorExport.BuildCurseForgeText(err, L)
    L = L or {}
    local lines = {}
    for _, ln in ipairs(buildHeaderLines()) do
        tinsert(lines, ln)
    end
    tinsert(lines, (L["ERR_DETAIL_MESSAGE"] or "MESSAGE:"))
    tinsert(lines, Addon.ErrorExport.StripWoWColorCodes(tostring(err.message or "")))
    tinsert(lines, "")
    tinsert(lines, (L["ERR_EXPORT_CF_STACK"] or "Stack / locals (markdown for CurseForge):"))
    tinsert(lines, "```")
    tinsert(lines, Addon.ErrorExport.StripWoWColorCodes(tostring(err.stack or "")))
    if err.locals and err.locals ~= "" then
        tinsert(lines, "")
        tinsert(lines, "--- locals ---")
        tinsert(lines, Addon.ErrorExport.StripWoWColorCodes(tostring(err.locals)))
    end
    tinsert(lines, "```")
    tinsert(lines, "")
    tinsert(lines, format("Session: %s  |  Count: %s  |  Time: %s",
        tostring(err.session or "?"),
        tostring(err.counter or 1),
        formatTime(err)))
    return table.concat(lines, "\n")
end

function Addon.ErrorExport.BuildDiscordText(err, L)
    L = L or {}
    local lines = {}
    for _, ln in ipairs(buildHeaderLines()) do
        tinsert(lines, ln)
    end
    tinsert(lines, "**" .. (L["ERR_DETAIL_MESSAGE"] or "MESSAGE:") .. "**")
    tinsert(lines, "```")
    tinsert(lines, Addon.ErrorExport.StripWoWColorCodes(tostring(err.message or "")))
    tinsert(lines, "```")
    tinsert(lines, "")
    tinsert(lines, "**" .. (L["ERR_DETAIL_STACK"] or "STACK TRACE:") .. "**")
    tinsert(lines, "```log")
    tinsert(lines, Addon.ErrorExport.StripWoWColorCodes(tostring(err.stack or "")))
    tinsert(lines, "```")
    if err.locals and err.locals ~= "" then
        tinsert(lines, "")
        tinsert(lines, "**" .. (L["ERR_DETAIL_LOCALS"] or "LOCALS:") .. "**")
        tinsert(lines, "```log")
        tinsert(lines, Addon.ErrorExport.StripWoWColorCodes(tostring(err.locals)))
        tinsert(lines, "```")
    end
    tinsert(lines, "")
    tinsert(lines, format("*session %s · x%s · %s*",
        tostring(err.session or "?"),
        tostring(err.counter or 1),
        formatTime(err)))
    return table.concat(lines, "\n")
end

function Addon.ErrorExport.GetCopyText(err, formatKey, L)
    if formatKey == "curseforge" then
        return Addon.ErrorExport.BuildCurseForgeText(err, L)
    end
    if formatKey == "discord" then
        return Addon.ErrorExport.BuildDiscordText(err, L)
    end
    return Addon.ErrorExport.BuildPlainText(err, L)
end

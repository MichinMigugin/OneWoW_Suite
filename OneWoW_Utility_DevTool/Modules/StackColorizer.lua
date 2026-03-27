local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local StackColorizer = {}
Addon.StackColorizer = StackColorizer

local format = string.format
local strmatch = string.match
local tinsert = tinsert
local tostring = tostring
local strtrim = strtrim

local palette

local function getPalette()
    if palette then return palette end
    local M = Addon.EditorSyntaxData and Addon.EditorSyntaxData.MONOKAI
    if not M then
        palette = false
        return palette
    end
    palette = {
        HEADER   = M.SELF,
        VALUE    = M.FOREGROUND,
        ERR_TYPE = M.KEYWORD,
        ADDON    = M.STRING,
        PATH     = M.WOW_API,
        LINENUM  = M.NUMBER,
        FUNC     = M.BUILTIN,
        STRUCT   = M.COMMENT,
    }
    return palette
end

local function c(key, text)
    local p = getPalette()
    if not p then return text end
    local hex = p[key]
    if not hex then return text end
    return "|cFF" .. hex .. text .. "|r"
end

local function colorizeRawPath(path)
    local before, addonName, after = strmatch(path, "^(.-[/\\]AddOns[/\\])([^/\\]+)(.*)$")
    if addonName then
        return c("PATH", before) .. c("ADDON", addonName) .. c("PATH", after)
    end
    return c("PATH", path)
end

local function colorizeBracketedSource(src)
    if src == "[C]" then
        return c("STRUCT", src)
    end
    local strContent = strmatch(src, "^%[string (.-)%]$")
    if strContent then
        return c("STRUCT", "[string ") .. c("VALUE", strContent) .. c("STRUCT", "]")
    end
    local inner = strmatch(src, "^%[(.-)%]$")
    if inner then
        return c("STRUCT", "[") .. colorizeRawPath(inner) .. c("STRUCT", "]")
    end
    return c("PATH", src)
end

local function colorizeTailRef(ref)
    local inner = strmatch(ref, "^<(.-)>$")
    if not inner then
        return c("STRUCT", ref)
    end
    local pathPart, lineNum = strmatch(inner, "^(.-):(%d+)$")
    if pathPart and lineNum then
        return c("STRUCT", "<") .. colorizeRawPath(pathPart) .. c("STRUCT", ":") .. c("LINENUM", lineNum) .. c("STRUCT", ">")
    end
    return c("STRUCT", "<") .. colorizeRawPath(inner) .. c("STRUCT", ">")
end

local function colorizeDesc(desc)
    local funcName = strmatch(desc, "^in function [`'](.-)['`]$")
    if funcName then
        return c("STRUCT", "in function '") .. c("FUNC", funcName) .. c("STRUCT", "'")
    end
    local tailRef = strmatch(desc, "^in function (<.->)$")
    if tailRef then
        return c("STRUCT", "in function ") .. colorizeTailRef(tailRef)
    end
    if strmatch(desc, "^in main chunk") then
        return c("STRUCT", desc)
    end
    return c("STRUCT", desc)
end

local function colorizeStackLine(line)
    line = strtrim(line)
    if line == "" then return "" end

    if strmatch(line, "^%[C%]: %?$") then
        return c("STRUCT", line)
    end

    local cFunc = strmatch(line, "^%[C%]: in function [`'](.-)['`]$")
    if cFunc then
        return c("STRUCT", "[C]: in function '") .. c("FUNC", cFunc) .. c("STRUCT", "'")
    end

    local bracketSrc, lineNum, desc = strmatch(line, "^(%[.-%]):(%d+): (.+)$")
    if bracketSrc then
        return colorizeBracketedSource(bracketSrc) .. c("STRUCT", ":") .. c("LINENUM", lineNum) .. c("STRUCT", ": ") .. colorizeDesc(desc)
    end

    local rawPath, lineNum2, desc2 = strmatch(line, "^(.-):(%d+): (.+)$")
    if rawPath and rawPath ~= "" then
        return colorizeRawPath(rawPath) .. c("STRUCT", ":") .. c("LINENUM", lineNum2) .. c("STRUCT", ": ") .. colorizeDesc(desc2)
    end

    return c("VALUE", line)
end

function StackColorizer:ColorizeHeader(label)
    if not getPalette() then return label end
    return c("HEADER", label)
end

function StackColorizer:ColorizeMetaLine(label, value)
    if not getPalette() then return label .. " " .. tostring(value) end
    return c("HEADER", label) .. " " .. c("VALUE", tostring(value))
end

function StackColorizer:ColorizeMessage(msg)
    if not msg or msg == "" then return "" end
    if not getPalette() then return msg end

    local eventName, rest = strmatch(msg, "^%[([%w_]+)%] (.+)$")
    if eventName then
        return c("ERR_TYPE", "[" .. eventName .. "]") .. " " .. c("VALUE", rest)
    end

    local warnBody = strmatch(msg, "^LUA_WARNING: (.+)$")
    if warnBody then
        return c("ERR_TYPE", "LUA_WARNING:") .. " " .. c("VALUE", warnBody)
    end

    local path, lineNum, errText = strmatch(msg, "^(.-):(%d+): (.+)$")
    if path and path ~= "" then
        return colorizeRawPath(path) .. c("STRUCT", ":") .. c("LINENUM", lineNum) .. c("STRUCT", ": ") .. c("VALUE", errText)
    end

    return c("VALUE", msg)
end

function StackColorizer:ColorizeStack(stackStr)
    if not stackStr or stackStr == "" then return "" end
    if not getPalette() then return stackStr end

    local result = {}
    for line in stackStr:gmatch("[^\n]+") do
        tinsert(result, colorizeStackLine(line))
    end
    return table.concat(result, "\n")
end

function StackColorizer:ColorizeLocals(localsStr)
    if not localsStr or localsStr == "" then return "" end
    if not getPalette() then return localsStr end
    return c("VALUE", localsStr)
end

function StackColorizer:ColorizeListRow(timestamp, sessionLabel, isCurrentSession, shortMsg, countStr)
    if not getPalette() then
        return format("[%s] %s - %s%s", timestamp, sessionLabel, shortMsg, countStr)
    end
    local sessionColor = isCurrentSession and "HEADER" or "STRUCT"
    local row = c("STRUCT", "[" .. timestamp .. "] ")
             .. c(sessionColor, sessionLabel)
             .. c("STRUCT", " - ")
             .. c("VALUE", shortMsg)
    if countStr ~= "" then
        row = row .. c("LINENUM", countStr)
    end
    return row
end

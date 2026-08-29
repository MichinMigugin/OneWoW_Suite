local _, ns = ...

local tinsert = tinsert
local ipairs = ipairs
local type = type
local tostring = tostring
local date = date
local format = string.format

ns.ErrorExport = {}

local function formatTime(err)
    if type(err.time) == "number" then
        return date("%Y-%m-%d %H:%M:%S", err.time)
    end
    return tostring(err.time or "?")
end

--- Remove WoW inline color codes for paste targets that do not understand them.
function ns.ErrorExport.StripWoWColorCodes(s)
    if type(s) ~= "string" or s == "" then
        return ""
    end
    local t = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    t = t:gsub("|r", "")
    return t
end

local function appendAnalysisLines(lines, analysis, L, prefix, suffix)
    prefix = prefix or ""
    suffix = suffix or ""
    if not analysis then return end
    tinsert(lines, "")
    tinsert(lines, prefix .. (L["ERR_EXPORT_ANALYSIS"]) .. suffix)
    tinsert(lines, (L["ERR_ANALYSIS_ERROR_TYPE"]) .. " " .. (analysis.errorType or ""))
    tinsert(lines, (L["ERR_ANALYSIS_ROOT_CAUSE"]) .. " " .. (analysis.rootCauseLabel or ""))
    if analysis.reportedAddon then
        tinsert(lines, (L["ERR_ANALYSIS_REPORTED_ADDON"]) .. " " .. analysis.reportedAddon)
    end
    if analysis.offendingAddon and analysis.offendingAddon ~= analysis.reportedAddon then
        tinsert(lines, (L["ERR_ANALYSIS_OFFENDING_ADDON"]) .. " " .. analysis.offendingAddon)
    end
    if analysis.taintSource then
        tinsert(lines, (L["ERR_ANALYSIS_TAINT_SOURCE"]) .. " " .. analysis.taintSource)
    end
    if analysis.triggerLocation then
        tinsert(lines, (L["ERR_ANALYSIS_TRIGGER"]) .. " " .. analysis.triggerLocation)
    end
    if analysis.recommendation then
        tinsert(lines, (L["ERR_ANALYSIS_RECOMMENDATION"]) .. " " .. analysis.recommendation)
    end
end

function ns.ErrorExport.BuildPlainText(err, L, includeAnalysis)
    L = L or {}
    if includeAnalysis == nil then includeAnalysis = true end
    local lines = {}
    tinsert(lines, (L["ERR_DETAIL_TIME"]) .. " " .. formatTime(err))
    tinsert(lines, (L["ERR_DETAIL_SESSION"]) .. " " .. tostring(err.session or "?"))
    if err.counter and err.counter > 1 then
        tinsert(lines, (L["ERR_DETAIL_COUNT"]) .. " " .. tostring(err.counter))
    end
    tinsert(lines, "")
    tinsert(lines, (L["ERR_DETAIL_MESSAGE"]))
    tinsert(lines, err.message or "")
    tinsert(lines, "")
    tinsert(lines, (L["ERR_DETAIL_STACK"]))
    tinsert(lines, err.stack or "")
    if err.locals and err.locals ~= "" then
        tinsert(lines, "")
        tinsert(lines, (L["ERR_DETAIL_LOCALS"]))
        tinsert(lines, err.locals)
    end
    if includeAnalysis then
        appendAnalysisLines(lines, err._analysis, L)
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

function ns.ErrorExport.BuildCurseForgeText(err, L)
    L = L or {}
    local lines = {}
    for _, ln in ipairs(buildHeaderLines()) do
        tinsert(lines, ln)
    end
    tinsert(lines, (L["ERR_DETAIL_MESSAGE"]))
    tinsert(lines, ns.ErrorExport.StripWoWColorCodes(tostring(err.message or "")))
    tinsert(lines, "")
    tinsert(lines, (L["ERR_EXPORT_CF_STACK"]))
    tinsert(lines, "```")
    tinsert(lines, ns.ErrorExport.StripWoWColorCodes(tostring(err.stack or "")))
    if err.locals and err.locals ~= "" then
        tinsert(lines, "")
        tinsert(lines, "--- locals ---")
        tinsert(lines, ns.ErrorExport.StripWoWColorCodes(tostring(err.locals)))
    end
    tinsert(lines, "```")
    appendAnalysisLines(lines, err._analysis, L)
    tinsert(lines, "")
    tinsert(lines, format("Session: %s  |  Count: %s  |  Time: %s",
        tostring(err.session or "?"),
        tostring(err.counter or 1),
        formatTime(err)))
    return table.concat(lines, "\n")
end

function ns.ErrorExport.BuildDiscordText(err, L)
    L = L or {}
    local lines = {}
    for _, ln in ipairs(buildHeaderLines()) do
        tinsert(lines, ln)
    end
    tinsert(lines, "**" .. (L["ERR_DETAIL_MESSAGE"]) .. "**")
    tinsert(lines, "```")
    tinsert(lines, ns.ErrorExport.StripWoWColorCodes(tostring(err.message or "")))
    tinsert(lines, "```")
    tinsert(lines, "")
    tinsert(lines, "**" .. (L["ERR_DETAIL_STACK"]) .. "**")
    tinsert(lines, "```log")
    tinsert(lines, ns.ErrorExport.StripWoWColorCodes(tostring(err.stack or "")))
    tinsert(lines, "```")
    if err.locals and err.locals ~= "" then
        tinsert(lines, "")
        tinsert(lines, "**" .. (L["ERR_DETAIL_LOCALS"]) .. "**")
        tinsert(lines, "```log")
        tinsert(lines, ns.ErrorExport.StripWoWColorCodes(tostring(err.locals)))
        tinsert(lines, "```")
    end
    appendAnalysisLines(lines, err._analysis, L, "**", "**")
    tinsert(lines, "")
    tinsert(lines, format("*session %s · x%s · %s*",
        tostring(err.session or "?"),
        tostring(err.counter or 1),
        formatTime(err)))
    return table.concat(lines, "\n")
end

function ns.ErrorExport.GetCopyText(err, formatKey, L)
    if formatKey == "curseforge" then
        return ns.ErrorExport.BuildCurseForgeText(err, L)
    end
    if formatKey == "discord" then
        return ns.ErrorExport.BuildDiscordText(err, L)
    end
    return ns.ErrorExport.BuildPlainText(err, L)
end

--- Newest-first unique-by-message. Counter is the summed occurrence count.
--- When sessionId is set and that session has errors, only those rows are used.
function ns.ErrorExport.CollectUniqueErrors(errors, sessionId)
    local source = errors
    if type(errors) ~= "table" then
        return {}
    end
    if sessionId ~= nil then
        local filtered = {}
        for i = 1, #errors do
            if errors[i].session == sessionId then
                tinsert(filtered, errors[i])
            end
        end
        if #filtered > 0 then
            source = filtered
        end
    end
    local out = {}
    local byMsg = {}
    for i = #source, 1, -1 do
        local err = source[i]
        local msg = err.message or ""
        local entry = byMsg[msg]
        if not entry then
            entry = {
                message = msg,
                time = err.time,
                counter = err.counter or 1,
                stack = err.stack or "",
                locals = err.locals or "",
                session = err.session,
                source = err,
                _analysis = err._analysis,
            }
            byMsg[msg] = entry
            tinsert(out, entry)
        else
            entry.counter = entry.counter + (err.counter or 1)
        end
    end
    return out
end

function ns.ErrorExport.EnsureAnalysis(err)
    if not err then
        return nil
    end
    if not err._analysis then
        err._analysis = ns.ErrorAnalyzer:Analyze(err)
    end
    return err._analysis
end

--- One clipboard blob: WoW/locale header (plain) plus every unique error.
function ns.ErrorExport.BuildAllText(errors, formatKey, L, sessionId)
    L = L or {}
    local unique = ns.ErrorExport.CollectUniqueErrors(errors, sessionId)
    if #unique == 0 then
        return ""
    end
    local lines = {}
    if formatKey ~= "curseforge" and formatKey ~= "discord" then
        for _, ln in ipairs(buildHeaderLines()) do
            tinsert(lines, ln)
        end
    end
    local total = #unique
    for i, err in ipairs(unique) do
        ns.ErrorExport.EnsureAnalysis(err)
        if #lines > 0 then
            tinsert(lines, "")
        end
        tinsert(lines, "--- " .. format(L["ERR_COPY_ALL_ITEM"], i, total) .. " ---")
        tinsert(lines, "")
        tinsert(lines, ns.ErrorExport.GetCopyText(err, formatKey, L))
    end
    return table.concat(lines, "\n")
end

local AddonName, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ErrorLogger = {}
Addon.ErrorLogger = ErrorLogger

ErrorLogger.currentError = nil

local tinsert, tremove = tinsert, tremove
local format = string.format
local ipairs, type, tostring = ipairs, type, tostring
local time = time
local GetTime = GetTime

local ROW_HEIGHT = 20

local function getConstants()
    return Addon.Constants or {}
end

local function throttlePerSec()
    local c = getConstants()
    return c.ERROR_LOGGER_ERRORS_PER_SEC or 10
end

local function captureEventName()
    local c = getConstants()
    return c.ERROR_CAPTURE_EVENT or "OneWoW_DevTool.ErrorCaptured"
end

local function getErrorDB()
    return Addon.db and Addon.db.errorDB
end

local function maxErrorsCap()
    local db = getErrorDB()
    local n = db and db.maxErrors
    if type(n) ~= "number" or n < 1 then
        return 100
    end
    if n > 500 then
        return 500
    end
    return n
end

local function keepSessionsCap()
    local db = getErrorDB()
    local n = db and db.keepLastSessions
    if type(n) ~= "number" or n < 1 then
        return 10
    end
    if n > 20 then
        return 20
    end
    return n
end

local function soundKitForChoice(key)
    if key == "raid_warning" then
        return SOUNDKIT.RAID_WARNING
    end
    if key == "tell_message" then
        return SOUNDKIT.TELL_MESSAGE
    end
    if key == "map_ping" then
        return SOUNDKIT.MAP_PING or SOUNDKIT.RAID_WARNING
    end
    return nil
end

local function normalizeSoundChoice(db)
    local sc = db.soundChoice
    if sc == "raid_warning" or sc == "tell_message" or sc == "map_ping" or sc == "off" then
        return
    end
    if db.playSound then
        db.soundChoice = "raid_warning"
    else
        db.soundChoice = "off"
    end
end

local function GetErrorStack()
    local GetCallstackHeight = GetCallstackHeight
    local GetErrorCallstackHeight = GetErrorCallstackHeight
    local debugstack = debugstack
    local ech = GetErrorCallstackHeight and GetErrorCallstackHeight()
    if ech then
        local currentStackHeight = GetCallstackHeight()
        local errorStackOffset = ech - 1
        local debugStackLevel = currentStackHeight - errorStackOffset
        return debugstack(debugStackLevel), debugStackLevel
    end
    return debugstack(3), 3
end

local function GetErrorLocals(level)
    local debuglocals = debuglocals
    if not debuglocals then
        return nil
    end
    return debuglocals(level)
end

local function fetchErrorByMessage(errors, targetMsg)
    for i = #errors, 1, -1 do
        local err = errors[i]
        if err.message == targetMsg then
            return err, i
        end
    end
end

local function trimOldest(errors, cap)
    while #errors > cap do
        tremove(errors, 1)
    end
end

local function formatTimeDisplay(err)
    if type(err.time) == "number" then
        return date("%Y-%m-%d %H:%M:%S", err.time)
    end
    return tostring(err.time or "?")
end

ErrorLogger.originalErrorHandler = nil
ErrorLogger._msgsAllowed = nil
ErrorLogger._msgsAllowedLastTime = nil
ErrorLogger._paused = nil
ErrorLogger._lastThrottleWarn = nil
ErrorLogger._lastSoundTime = nil
ErrorLogger._uiRefreshPending = nil
ErrorLogger._eventFrame = nil
ErrorLogger._badAddonBlocked = nil

function ErrorLogger:Initialize()
    local db = getErrorDB()
    if not db then
        return
    end
    normalizeSoundChoice(db)
    if type(db.copyFormat) ~= "string" then
        db.copyFormat = "plain"
    end
    if type(db.clearOnReload) ~= "boolean" then
        db.clearOnReload = false
    end
    if type(db.keepLastSessions) ~= "number" then
        db.keepLastSessions = 10
    end
    if type(db.maxErrors) ~= "number" then
        db.maxErrors = 100
    end

    db.session = (type(db.session) == "number" and db.session or 0) + 1

    if db.clearOnReload then
        db.errors = {}
    else
        local cur = db.session
        local keep = keepSessionsCap()
        local minSession = cur - keep + 1
        local kept = {}
        for _, e in ipairs(db.errors) do
            if type(e.session) == "number" and e.session >= minSession then
                tinsert(kept, e)
            end
        end
        db.errors = kept
    end

    self._msgsAllowed = throttlePerSec()
    self._msgsAllowedLastTime = GetTime()
    self._paused = false

    self.originalErrorHandler = geterrorhandler()
    seterrorhandler(function(msg)
        return ErrorLogger:_onLuaError(msg)
    end)

    self:_registerAuxEvents()

    C_Timer.After(2, function()
        ErrorLogger:UpdateErrorBadge()
    end)
end

function ErrorLogger:_registerAuxEvents()
    if self._eventFrame then
        return
    end
    self._badAddonBlocked = {}
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_ACTION_BLOCKED")
    f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    f:RegisterEvent("LUA_WARNING")
    f:SetScript("OnEvent", function(_, event, ...)
        ErrorLogger:_onAuxEvent(event, ...)
    end)
    self._eventFrame = f

    if UIParent and UIParent.UnregisterEvent then
        pcall(function()
            UIParent:UnregisterEvent("ADDON_ACTION_FORBIDDEN")
            UIParent:UnregisterEvent("ADDON_ACTION_BLOCKED")
        end)
    end

    if ScriptErrorsFrame and ScriptErrorsFrame.UnregisterEvent then
        pcall(function()
            ScriptErrorsFrame:UnregisterEvent("LUA_WARNING")
        end)
    end
end

function ErrorLogger:_onAuxEvent(event, a1, a2)
    local L = Addon.L or {}
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local addonName = a1 or "<name>"
        local fn = a2 or "<func>"
        if not self._badAddonBlocked[addonName] then
            self._badAddonBlocked[addonName] = true
            local template = L["ERR_ADDON_CALL_PROTECTED"] or "[%s] AddOn '%s' tried to call the protected function '%s'."
            self:StoreErrorSimple(format(template, event, addonName, fn))
        end
    elseif event == "LUA_WARNING" then
        local w = a1
        if not w then
            w = ""
        end
        self:StoreErrorSimple("LUA_WARNING: " .. tostring(w))
    end
end

function ErrorLogger:_onLuaError(msg)
    local ok = pcall(function()
        self:_captureFromHandler(msg, false)
    end)
    if not ok then
        -- avoid breaking the error pipeline
    end
    if self.originalErrorHandler then
        return self.originalErrorHandler(msg)
    end
end

function ErrorLogger:StoreErrorSimple(message)
    self:_captureFromHandler(message, true)
end

function ErrorLogger:_captureFromHandler(msg, isSimple)
    local db = getErrorDB()
    if not db then
        return
    end

    local rate = throttlePerSec()
    self._msgsAllowed = self._msgsAllowed + (GetTime() - self._msgsAllowedLastTime) * rate
    self._msgsAllowedLastTime = GetTime()
    if self._msgsAllowed < 1 then
        if not self._paused then
            if GetTime() > (self._lastThrottleWarn or 0) + 10 then
                local L = Addon.L or {}
                Addon:Print(L["ERR_THROTTLE_PAUSED"] or "Too many errors; capture throttled until the flood stops.")
                self._lastThrottleWarn = GetTime()
            end
            self._paused = true
        end
        return
    end
    self._paused = false
    if self._msgsAllowed > rate then
        self._msgsAllowed = rate
    end
    self._msgsAllowed = self._msgsAllowed - 1

    local msgStr
    if OneWoW_GUI:IsSecret(msg) then
        local L = Addon.L or {}
        msgStr = L["ERR_MSG_SECRET"] or "[Secret error — details withheld by the client]"
    else
        msgStr = tostring(msg)
        if OneWoW_GUI:IsSecret(msgStr) then
            local L = Addon.L or {}
            msgStr = L["ERR_MSG_SECRET"] or "[Secret error — details withheld by the client]"
        end
    end
    if msgStr:find("ErrorLogger", 1, true) or msgStr:find("OneWoW_Utility_DevTool", 1, true) then
        return
    end

    local errors = db.errors
    local session = db.session
    local now = time()
    local existing, pos = fetchErrorByMessage(errors, msgStr)

    if not existing then
        local errObj = {
            message = msgStr,
            session = session,
            time = now,
            counter = 1,
            stack = "",
            locals = "",
        }
        if not isSimple then
            local stack, level = GetErrorStack()
            errObj.stack = stack or ""
            local loc = GetErrorLocals(level)
            errObj.locals = loc and tostring(loc) or ""
        end
        tinsert(errors, errObj)
        trimOldest(errors, maxErrorsCap())
        self:_afterNewOrUpdated(errObj)
        return
    end

    local oldSession = existing.session
    existing.counter = (existing.counter or 1) + 1
    existing.session = session
    local prevTime = existing.time
    if type(prevTime) ~= "number" then
        prevTime = now
    end
    existing.time = now

    if not isSimple then
        if oldSession ~= session then
            tremove(errors, pos)
            local stack, level = GetErrorStack()
            existing.stack = stack or ""
            local loc = GetErrorLocals(level)
            existing.locals = loc and tostring(loc) or ""
            tinsert(errors, existing)
        else
            if now - prevTime > 10 then
                tremove(errors, pos)
                tinsert(errors, existing)
            end
            if now - prevTime > 120 then
                local stack, level = GetErrorStack()
                existing.stack = stack or ""
                local loc = GetErrorLocals(level)
                existing.locals = loc and tostring(loc) or ""
            end
        end
    else
        if now - prevTime > 10 then
            tremove(errors, pos)
            tinsert(errors, existing)
        end
    end

    trimOldest(errors, maxErrorsCap())
    self:_afterNewOrUpdated(existing)
end

function ErrorLogger:_afterNewOrUpdated(errObj)
    self:PlayAlertSound()
    EventRegistry:TriggerEvent(captureEventName(), errObj)
    self:ScheduleUIRefresh()
    self:UpdateErrorBadge()
end

function ErrorLogger:ScheduleUIRefresh()
    if self._uiRefreshPending then
        return
    end
    self._uiRefreshPending = true
    C_Timer.After(0, function()
        ErrorLogger._uiRefreshPending = false
        ErrorLogger:UpdateUI()
    end)
end

function ErrorLogger:GetSessionId()
    return getErrorDB() and getErrorDB().session or 0
end

function ErrorLogger:GetErrors()
    return getErrorDB() and getErrorDB().errors or {}
end

function ErrorLogger:PlayAlertSound()
    local db = getErrorDB()
    if not db then
        return
    end
    normalizeSoundChoice(db)
    local kit = soundKitForChoice(db.soundChoice)
    if not kit then
        return
    end
    local t = GetTime()
    if self._lastSoundTime and (t - self._lastSoundTime) < 2 then
        return
    end
    self._lastSoundTime = t
    pcall(function()
        PlaySound(kit, "Master")
    end)
end

--- Play the kit for a soundChoice key (Lua tab preview). No throttle; skips "off".
function ErrorLogger:PreviewSoundChoice(key)
    if key == "off" or not key then
        return
    end
    local kit = soundKitForChoice(key)
    if not kit then
        return
    end
    pcall(function()
        PlaySound(kit, "Master")
    end)
end

function ErrorLogger:GetMinimapButton()
    return OneWoW_GUI:GetMinimapButton("OneWoW_UtilityDevTool")
end

function ErrorLogger:HasCurrentSessionErrors()
    local errors = self:GetErrors()
    local currentSession = self:GetSessionId()
    for i = #errors, 1, -1 do
        if errors[i].session == currentSession then
            return true
        end
    end
    return false
end

function ErrorLogger:UpdateErrorBadge()
    local showBadge = self:HasCurrentSessionErrors()

    if not self.errorBadge then
        if not showBadge then
            return
        end
        local button = self:GetMinimapButton()
        if not button then
            return
        end

        local badge = CreateFrame("Frame", nil, button)
        badge:SetSize(20, 20)
        badge:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
        badge:SetFrameLevel(button:GetFrameLevel() + 5)

        local icon = badge:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetAtlas("Ping_Chat_Warning")

        self.errorBadge = badge
    end

    if showBadge then
        self.errorBadge:Show()
    else
        self.errorBadge:Hide()
    end
end

function ErrorLogger:UpdateUI()
    if not Addon.LuaConsoleTab then
        return
    end

    local tab = Addon.LuaConsoleTab
    local L = Addon.L or {}
    local errors = self:GetErrors()
    local currentSession = self:GetSessionId()

    tab.countLabel:SetText((L["LABEL_ERRORS"] or "Errors:") .. " " .. #errors)

    for i, btn in ipairs(tab.errorButtons) do
        local errorIdx = #errors - (i - 1)
        local err = errors[errorIdx]

        if err then
            local sessionLabel
            if err.session == currentSession then
                sessionLabel = L["ERR_SESSION_CURRENT"] or "Current"
            else
                sessionLabel = (L["ERR_SESSION_PREFIX"] or "Session") .. " " .. (err.session or "?")
            end

            local countStr = ""
            if err.counter and err.counter > 1 then
                countStr = " (x" .. err.counter .. ")"
            end

            local shortMsg = err.message or ""
            if #shortMsg > 60 then
                shortMsg = shortMsg:sub(1, 57) .. "..."
            end

            btn.label:SetText(format("[%s] %s - %s%s", formatTimeDisplay(err), sessionLabel, shortMsg, countStr))
            btn.errorData = err
            btn:Show()
        else
            btn:Hide()
        end
    end

    local displayCount = math.min(#errors, #tab.errorButtons)
    local contentHeight = math.max(displayCount * ROW_HEIGHT + 5, tab.listScroll:GetHeight())
    tab.listScroll:GetScrollChild():SetHeight(contentHeight)
end

function ErrorLogger:ShowErrorDetails(errorData)
    if not Addon.LuaConsoleTab or not errorData then
        return
    end

    self.currentError = errorData
    local tab = Addon.LuaConsoleTab
    local L = Addon.L or {}
    local currentSession = self:GetSessionId()

    local sessionLabel
    if errorData.session == currentSession then
        sessionLabel = L["ERR_SESSION_CURRENT_FULL"] or "Current Session"
    else
        sessionLabel = (L["ERR_SESSION_PREFIX"] or "Session") .. " " .. (errorData.session or "?")
    end

    local details = {}
    tinsert(details, (L["ERR_DETAIL_TIME"] or "TIME:") .. " " .. formatTimeDisplay(errorData))
    tinsert(details, (L["ERR_DETAIL_SESSION"] or "SESSION:") .. " " .. sessionLabel)
    if errorData.counter and errorData.counter > 1 then
        tinsert(details, (L["ERR_DETAIL_COUNT"] or "COUNT:") .. " " .. errorData.counter)
    end
    tinsert(details, "")
    tinsert(details, (L["ERR_DETAIL_MESSAGE"] or "MESSAGE:"))
    tinsert(details, errorData.message or "")
    tinsert(details, "")
    tinsert(details, (L["ERR_DETAIL_STACK"] or "STACK TRACE:"))
    tinsert(details, errorData.stack or "")

    if errorData.locals and errorData.locals ~= "" then
        tinsert(details, "")
        tinsert(details, (L["ERR_DETAIL_LOCALS"] or "LOCALS:"))
        tinsert(details, errorData.locals)
    end

    tab.detailsText:SetText(table.concat(details, "\n"))

    local height = tab.detailsText:GetStringHeight()
    tab.detailsScroll:GetScrollChild():SetHeight(math.max(height + 10, tab.detailsScroll:GetHeight()))
end

function ErrorLogger:CopyCurrentError()
    if not self.currentError then
        Addon:Print(Addon.L and Addon.L["ERR_MSG_NONE_SELECTED"] or "No error selected")
        return
    end

    local db = getErrorDB()
    local fmt = db and db.copyFormat or "plain"
    local L = Addon.L or {}
    local text
    if Addon.ErrorExport and Addon.ErrorExport.GetCopyText then
        text = Addon.ErrorExport.GetCopyText(self.currentError, fmt, L)
    else
        text = tostring(self.currentError.message)
    end

    Addon:CopyToClipboard(text, L["ERR_COPY_TITLE"] or "Copy error")
end

function ErrorLogger:ClearErrors()
    local db = getErrorDB()
    if db then
        db.errors = {}
    end

    self.currentError = nil
    self:UpdateUI()
    self:UpdateErrorBadge()

    if Addon.LuaConsoleTab then
        Addon.LuaConsoleTab.detailsText:SetText(Addon.L and Addon.L["LABEL_NO_ERROR"] or "No error selected")
    end

    Addon:Print(Addon.L and Addon.L["ERR_MSG_CLEARED"] or "Error log cleared")
end

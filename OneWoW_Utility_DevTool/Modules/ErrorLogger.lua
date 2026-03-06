local AddonName, Addon = ...

local ErrorLogger = {}
Addon.ErrorLogger = ErrorLogger

ErrorLogger.currentError = nil

local MAX_ERRORS = 500
local ROW_HEIGHT = 20
local ERROR_SOUND_ID = 8959
local useBugGrabber = false

function ErrorLogger:Initialize()
    local db = Addon.db
    if not db.errorDB then
        db.errorDB = { session = 0, errors = {} }
    end
    if type(db.errorDB.session) ~= "number" then
        db.errorDB.session = 0
    end
    if type(db.errorDB.errors) ~= "table" then
        db.errorDB.errors = {}
    end
    db.errorDB.session = db.errorDB.session + 1

    if _G.BugGrabber and _G.BugGrabber.GetDB then
        useBugGrabber = true
        if _G.BugGrabber.setupCallbacks then
            _G.BugGrabber.setupCallbacks()
        end
        if _G.BugGrabber.RegisterCallback then
            _G.BugGrabber.RegisterCallback(ErrorLogger, "BugGrabber_BugGrabbed", function()
                ErrorLogger:PlayAlertSound()
                ErrorLogger:UpdateUI()
                ErrorLogger:UpdateErrorBadge()
            end)
        end
    else
        self.originalErrorHandler = geterrorhandler()
        local function errorHandler(msg)
            pcall(function()
                ErrorLogger:CaptureError(tostring(msg), debugstack(3))
            end)
            if ErrorLogger.originalErrorHandler then
                return ErrorLogger.originalErrorHandler(msg)
            end
        end
        seterrorhandler(errorHandler)
    end

    C_Timer.After(2, function()
        ErrorLogger:UpdateErrorBadge()
    end)
end

function ErrorLogger:GetSessionId()
    if useBugGrabber then
        return BugGrabber:GetSessionId()
    end
    return Addon.db and Addon.db.errorDB and Addon.db.errorDB.session or 0
end

function ErrorLogger:GetErrors()
    if useBugGrabber then
        return BugGrabber:GetDB() or {}
    end
    return Addon.db and Addon.db.errorDB and Addon.db.errorDB.errors or {}
end

function ErrorLogger:PlayAlertSound()
    if Addon.db and Addon.db.errorDB and Addon.db.errorDB.playSound then
        PlaySound(ERROR_SOUND_ID, "Master")
    end
end

function ErrorLogger:GetMinimapButton()
    if _G["OneWoW_MinimapButton"] then
        return _G["OneWoW_MinimapButton"]
    end
    local libDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if libDBIcon then
        return libDBIcon:GetMinimapButton("OneWoW_UtilityDevTool")
    end
    return nil
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
        if not showBadge then return end
        local button = self:GetMinimapButton()
        if not button then return end

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

function ErrorLogger:CaptureError(message, stack)
    if useBugGrabber then return end

    local db = Addon.db and Addon.db.errorDB
    if not db then return end
    local errors = db.errors

    for i, err in ipairs(errors) do
        if err.message == message then
            err.counter = (err.counter or 1) + 1
            err.session = db.session
            err.time = date("%Y/%m/%d %H:%M:%S")
            table.remove(errors, i)
            errors[#errors + 1] = err
            self:UpdateUI()
            self:UpdateErrorBadge()
            return
        end
    end

    local errorObj = {
        message = message or "Unknown error",
        stack = stack or "",
        locals = "",
        session = db.session,
        time = date("%Y/%m/%d %H:%M:%S"),
        counter = 1,
    }

    errors[#errors + 1] = errorObj

    while #errors > MAX_ERRORS do
        table.remove(errors, 1)
    end

    self:PlayAlertSound()
    self:UpdateUI()
    self:UpdateErrorBadge()
end

function ErrorLogger:UpdateUI()
    if not Addon.LuaConsoleTab then return end

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

            btn:SetText(string.format("[%s] %s - %s%s", err.time or "?", sessionLabel, shortMsg, countStr))
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
    if not Addon.LuaConsoleTab or not errorData then return end

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
    table.insert(details, (L["ERR_DETAIL_TIME"] or "TIME:") .. " " .. (errorData.time or "?"))
    table.insert(details, (L["ERR_DETAIL_SESSION"] or "SESSION:") .. " " .. sessionLabel)
    if errorData.counter and errorData.counter > 1 then
        table.insert(details, (L["ERR_DETAIL_COUNT"] or "COUNT:") .. " " .. errorData.counter)
    end
    table.insert(details, "")
    table.insert(details, (L["ERR_DETAIL_MESSAGE"] or "MESSAGE:"))
    table.insert(details, errorData.message or "")
    table.insert(details, "")
    table.insert(details, (L["ERR_DETAIL_STACK"] or "STACK TRACE:"))
    table.insert(details, errorData.stack or "")

    if errorData.locals and errorData.locals ~= "" then
        table.insert(details, "")
        table.insert(details, (L["ERR_DETAIL_LOCALS"] or "LOCALS:"))
        table.insert(details, errorData.locals)
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

    local err = self.currentError
    local text = string.format("Time: %s\nSession: %s\nCount: %s\n\nMessage:\n%s\n\nStack:\n%s",
        err.time or "?",
        err.session or "?",
        err.counter or 1,
        err.message or "",
        err.stack or ""
    )

    if err.locals and err.locals ~= "" then
        text = text .. "\n\nLocals:\n" .. err.locals
    end

    Addon:CopyToClipboard(text)
end

function ErrorLogger:ClearErrors()
    if useBugGrabber and BugGrabber.Reset then
        BugGrabber:Reset()
    end

    if Addon.db and Addon.db.errorDB then
        Addon.db.errorDB.errors = {}
    end

    self.currentError = nil
    self:UpdateUI()
    self:UpdateErrorBadge()

    if Addon.LuaConsoleTab then
        Addon.LuaConsoleTab.detailsText:SetText(Addon.L and Addon.L["LABEL_NO_ERROR"] or "No error selected")
    end

    Addon:Print(Addon.L and Addon.L["ERR_MSG_CLEARED"] or "Error log cleared")
end

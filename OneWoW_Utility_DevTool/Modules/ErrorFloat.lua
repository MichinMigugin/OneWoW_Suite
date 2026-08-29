local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

local ErrorFloat = {}
ns.ErrorFloat = ErrorFloat

local C_Timer = C_Timer
local CreateFrame = CreateFrame
local date = date
local ipairs = ipairs
local min = math.min
local type = type
local tostring = tostring

local MAX_ROWS = 8
local ROW_HEIGHT = 20
local ROW_GAP = 2
local WIDTH = 640
local PAD = 8
local DETAIL_HEIGHT = 120
local FLASH_STEPS = 6
local FLASH_INTERVAL = 0.12

local function getErrorDB()
    return ns.db.global.errorDB
end

local function formatTimeDisplay(err)
    if type(err.time) == "number" then
        return date("%H:%M:%S", err.time)
    end
    return tostring(err.time or "?")
end

local function collectUniqueErrors()
    return ns.ErrorExport.CollectUniqueErrors(ns.ErrorLogger:GetErrors())
end

local function formatDetail(err)
    local lines = {}
    tinsert(lines, (L["ERR_DETAIL_TIME"]) .. " " .. formatTimeDisplay(err))
    tinsert(lines, (L["ERR_DETAIL_COUNT"]) .. " x" .. (err.counter or 1))
    tinsert(lines, "")
    tinsert(lines, L["ERR_DETAIL_MESSAGE"])
    tinsert(lines, err.message or "")
    if err.stack and err.stack ~= "" then
        tinsert(lines, "")
        tinsert(lines, L["ERR_DETAIL_STACK"])
        tinsert(lines, err.stack)
    end
    return table.concat(lines, "\n")
end

function ErrorFloat:IsShown()
    return self.frame and self.frame:IsShown() and true or false
end

function ErrorFloat:Hide()
    self:_stopFlash()
    if self.frame then
        self.frame:Hide()
    end
end

function ErrorFloat:_stopFlash()
    self._flashGen = (self._flashGen or 0) + 1
end

function ErrorFloat:_applyChrome(warning)
    local frame = self.frame
    if not frame then
        return
    end
    if warning then
        frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    else
        frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    end
end

function ErrorFloat:_flashRow(row)
    if not row then
        return
    end
    self:_stopFlash()
    local gen = self._flashGen
    local step = 0
    local function pulse()
        if gen ~= ErrorFloat._flashGen or not ErrorFloat.frame or not ErrorFloat.frame:IsShown() then
            return
        end
        step = step + 1
        if step > FLASH_STEPS then
            row:SetActive(true)
            ErrorFloat:_applyChrome(false)
            return
        end
        if step % 2 == 1 then
            local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_WARNING")
            row:SetBackdropColor(r, g, b, 0.45)
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            ErrorFloat:_applyChrome(true)
        else
            row:SetActive(true)
            ErrorFloat:_applyChrome(false)
        end
        C_Timer.After(FLASH_INTERVAL, pulse)
    end
    pulse()
end

function ErrorFloat:_ensure()
    if self.frame then
        return
    end

    local C = OneWoW_GUI.Constants
    local titleH = C.GUI.TITLEBAR_HEIGHT
    local frame = OneWoW_GUI:CreateFrame(UIParent, {
        width = WIDTH,
        height = 140,
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        bgColor = "BG_PRIMARY",
        borderColor = "TEXT_WARNING",
    })
    frame:SetFrameStrata("TOOLTIP")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(myself)
        myself:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(myself)
        myself:StopMovingOrSizing()
        OneWoW_GUI:SaveWindowPosition(myself, getErrorDB().devModePosition)
    end)

    local titleBar = OneWoW_GUI:CreateTitleBar(frame, {
        title = L["ERR_DEVMODE"],
        height = titleH,
        showBrand = false,
        onClose = function()
            ErrorFloat:Hide()
            OneWoW_GUI:SaveWindowPosition(frame, getErrorDB().devModePosition)
        end,
    })
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        OneWoW_GUI:SaveWindowPosition(frame, getErrorDB().devModePosition)
    end)

    local copyAllBtn = OneWoW_GUI:CreateFitTextButton(titleBar, {
        text = L["BTN_COPY_DETAILS"],
        height = 18,
        minWidth = 40,
        paddingX = 12,
    })
    copyAllBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -4, 0)
    copyAllBtn:SetScript("OnClick", function()
        ns.ErrorLogger:CopyAllErrors()
    end)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -PAD)
    emptyLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, -PAD)
    emptyLabel:SetJustifyH("LEFT")
    emptyLabel:SetWordWrap(false)
    emptyLabel:SetText(L["ERR_DEVMODE_EMPTY"])
    emptyLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local detailText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailText:SetJustifyH("LEFT")
    detailText:SetJustifyV("TOP")
    detailText:SetWordWrap(true)
    detailText:SetNonSpaceWrap(false)
    detailText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    detailText:Hide()

    self.frame = frame
    self.titleBar = titleBar
    self.copyAllBtn = copyAllBtn
    self.content = content
    self.emptyLabel = emptyLabel
    self.detailText = detailText
    self.rows = {}

    for i = 1, MAX_ROWS do
        local row = OneWoW_GUI:CreateListRowBasic(content, {
            height = ROW_HEIGHT,
            label = "",
        })
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(myself, button)
            local err = myself.errorData
            if not err then
                return
            end
            ErrorFloat.selected = err
            ErrorFloat:Refresh(err, false)
            if button == "RightButton" then
                GameTooltip:Hide()
                ns:OpenDevToolErrorsTab()
                ns.ErrorLogger:ShowErrorDetails(err.source or err)
            end
        end)
        row.label:SetFontObject(GameFontNormalSmall)
        row.label:SetWordWrap(false)
        row.label:SetMaxLines(1)
        row:HookScript("OnEnter", function(myself)
            local err = myself.errorData
            if not err or not err.message or err.message == "" then
                return
            end
            GameTooltip:SetOwner(myself, "ANCHOR_BOTTOMLEFT")
            GameTooltip:AddLine(err.message, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:Hide()
        self.rows[i] = row
    end

    if not OneWoW_GUI:RestoreWindowPosition(frame, getErrorDB().devModePosition) then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:SetWidth(WIDTH)
    OneWoW_GUI:RegisterFontRoot(frame, function()
        if ErrorFloat.frame then
            ErrorFloat:Refresh(nil)
        end
    end)
    frame:Hide()
end

function ErrorFloat:_layout(visibleCount, hasDetail)
    local titleH = OneWoW_GUI.Constants.GUI.TITLEBAR_HEIGHT
    local bodyH
    if visibleCount > 0 then
        bodyH = visibleCount * ROW_HEIGHT + (visibleCount - 1) * ROW_GAP
    else
        bodyH = 24
    end
    if hasDetail then
        bodyH = bodyH + 6 + DETAIL_HEIGHT
    end
    self.frame:SetSize(WIDTH, titleH + PAD + bodyH + PAD)

    for i, row in ipairs(self.rows) do
        if i <= visibleCount then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, -PAD - (i - 1) * (ROW_HEIGHT + ROW_GAP))
            row:SetPoint("RIGHT", self.content, "RIGHT", -PAD, 0)
            row:Show()
        else
            row:Hide()
            row.errorData = nil
        end
    end

    if visibleCount == 0 then
        self.emptyLabel:Show()
        self.detailText:Hide()
    else
        self.emptyLabel:Hide()
        if hasDetail then
            local last = self.rows[visibleCount]
            self.detailText:ClearAllPoints()
            self.detailText:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 2, -6)
            self.detailText:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", -2, -6)
            self.detailText:SetHeight(DETAIL_HEIGHT)
            self.detailText:Show()
        else
            self.detailText:Hide()
        end
    end
end

function ErrorFloat:Refresh(highlightErr, doFlash)
    self:_ensure()
    if highlightErr then
        self.selected = highlightErr
    end
    if self.titleBar and self.titleBar._titleText then
        self.titleBar._titleText:SetText(L["ERR_DEVMODE"])
    end
    self.emptyLabel:SetText(L["ERR_DEVMODE_EMPTY"])
    if self.copyAllBtn then
        self.copyAllBtn:SetFitText(L["BTN_COPY_DETAILS"])
    end

    local unique = collectUniqueErrors()
    local visible = min(#unique, MAX_ROWS)
    local highlightRow
    local selectedMsg = self.selected and self.selected.message
    local detailErr

    for i = 1, visible do
        local err = unique[i]
        local row = self.rows[i]
        local countStr = "x" .. (err.counter or 1) .. "  "
        local msg = err.message or ""
        row.label:SetText(countStr .. msg)
        row.errorData = err
        local isHighlight = selectedMsg and err.message == selectedMsg
        if not selectedMsg and i == 1 then
            isHighlight = true
        end
        row:SetActive(isHighlight)
        if isHighlight then
            highlightRow = row
            detailErr = err
        end
    end

    if not detailErr then
        detailErr = unique[1]
    end
    if detailErr then
        self.selected = detailErr
    end

    local hasDetail = detailErr and detailErr.message and detailErr.message ~= ""
    if hasDetail then
        self.detailText:SetText(formatDetail(detailErr))
    end

    self:_layout(visible, hasDetail)
    self:_applyChrome(false)
    if self.copyAllBtn then
        self.copyAllBtn:SetEnabled(#unique > 0)
    end

    if doFlash and getErrorDB().devModeFlash and highlightRow then
        self:_flashRow(highlightRow)
    end
    if visible == 0 then
        self:Hide()
    end
    return visible
end

--- Show only when DEVMODE is on and at least one stored error exists (any session).
function ErrorFloat:ShowNow(highlightErr, doFlash)
    if not getErrorDB().devMode then
        self:Hide()
        return
    end
    self:_ensure()
    local visible = self:Refresh(highlightErr, doFlash)
    if visible == 0 then
        return
    end
    self.frame:Show()
    self.frame:Raise()
end

function ErrorFloat:ShowSessionErrors(highlightErr)
    if not getErrorDB().devMode then
        return
    end
    self:ShowNow(highlightErr)
end

function ErrorFloat:OnError(errObj)
    if not getErrorDB().devMode then
        return
    end
    self._pendingErr = errObj
    if self._showPending then
        return
    end
    self._showPending = true
    C_Timer.After(0, function()
        ErrorFloat._showPending = false
        local err = ErrorFloat._pendingErr
        ErrorFloat._pendingErr = nil
        ErrorFloat.selected = err
        ErrorFloat:ShowNow(err, true)
    end)
end

function ErrorFloat:ApplyTheme()
    if not self.frame then
        return
    end
    self:_stopFlash()
    self:Refresh(nil)
end

function ErrorFloat:SyncSettingsFromDB()
    local tab = ns.LuaConsoleTab
    if not tab then
        return
    end
    local db = getErrorDB()
    if tab.devModeCheck then
        tab.devModeCheck:SetChecked(db.devMode)
    end
    if tab.SetDevModeFlashEnabled then
        tab.SetDevModeFlashEnabled(db.devMode)
    end
    if tab.devModeFlashCheck then
        tab.devModeFlashCheck:SetChecked(db.devModeFlash)
    end
end

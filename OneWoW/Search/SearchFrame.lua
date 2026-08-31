-- ============================================================================
-- SearchFrame
-- ============================================================================
-- Hub title-bar search box. Queries SearchRegistry (flat list, no widget walk).
-- Result rows are pooled; typing is debounced so a long question does not hitch.
-- ============================================================================

local _, ns = ...

ns.Search = {}
local Search = ns.Search

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER

local CreateFrame = CreateFrame
local ipairs = ipairs
local tinsert, tremove, wipe = tinsert, tremove, wipe

local searchBox = nil
local resultsFrame = nil
local rowPool = {}
local activeRows = {}
local pendingSearch = nil
local accentBar = nil

local DROP_W = 340
local TEXT_PAD = 8
local TEXT_GAP = 3
local PAD = 6
local DEBOUNCE = 0.05
local MIN_CHARS = 2

--- Add or replace a leftover search row. Features that already RegisterModule /
--- Define do not need this.
---@param entry table
function Search:Register(entry)
    ns.SearchRegistry:Register(entry)
end

local function NavigateTo(entry)
    if searchBox then
        searchBox:SetText("")
        searchBox:ClearFocus()
    end
    if resultsFrame then
        resultsFrame:Hide()
        resultsFrame:SetScript("OnUpdate", nil)
    end

    local nav = entry.nav
    if not nav then
        return
    end

    if nav.module then
        local gui = ns.UI
        gui:Show()
        C_Timer.After(DEBOUNCE, function()
            gui:SelectModuleTab(nav.module, nav.subtab)
            if nav.open then
                nav.open()
            end
        end)
        return
    end

    if nav.open then
        nav.open()
    end
end

local function ReleaseRows()
    for i = 1, #activeRows do
        local row = activeRows[i]
        row:Hide()
        row:EnableMouse(false)
        row:SetScript("OnMouseUp", nil)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        row:SetBackdropColor(0, 0, 0, 0)
        tinsert(rowPool, row)
    end
    wipe(activeRows)
end

local function PaintMuted(fs)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
end

local function AcquireRow(parent)
    local row = tremove(rowPool)
    if row then
        row:SetParent(parent)
        tinsert(activeRows, row)
        return row
    end

    row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetBackdrop(BACKDROP_SIMPLE)
    row:SetBackdropColor(0, 0, 0, 0)

    row.pathText = OneWoW_GUI:CreateFS(row, 10)
    row.pathText:SetJustifyH("LEFT")
    row.pathText:SetJustifyV("TOP")
    row.pathText:SetWordWrap(false)

    row.badge = OneWoW_GUI:CreateFS(row, 10)
    row.badge:SetJustifyH("RIGHT")
    row.badge:SetJustifyV("TOP")

    row.descText = OneWoW_GUI:CreateFS(row, 10)
    row.descText:SetJustifyH("LEFT")
    row.descText:SetJustifyV("TOP")
    row.descText:SetWordWrap(true)

    row.sep = row:CreateTexture(nil, "ARTWORK")
    row.sep:SetHeight(1)
    row.sep:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 0)
    row.sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)

    tinsert(activeRows, row)
    return row
end

local function AnchorRow(row, parent, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, y)
end

---@param row Frame
---@param path string
---@param desc string|nil
---@param installed boolean
---@return number
local function FitRow(row, path, desc, installed)
    if installed then
        row.badge:SetText("")
        row.badge:Hide()
    else
        row.badge:SetText(ADDON_MISSING)
        row.badge:Show()
        PaintMuted(row.badge)
    end

    local innerW = DROP_W - 2 - TEXT_PAD * 2
    if not installed then
        innerW = innerW - (row.badge:GetStringWidth() or 0) - TEXT_PAD
    end

    row.pathText:ClearAllPoints()
    row.pathText:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_PAD, -TEXT_PAD)
    row.pathText:SetWidth(innerW)
    row.pathText:SetText(path or "")

    row.badge:ClearAllPoints()
    row.badge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -TEXT_PAD, -TEXT_PAD)

    local pathH = row.pathText:GetStringHeight()
    if pathH < 1 then
        pathH = 12
    end

    local h = TEXT_PAD * 2 + pathH
    if desc and desc ~= "" then
        row.descText:Show()
        row.descText:ClearAllPoints()
        row.descText:SetPoint("TOPLEFT", row.pathText, "BOTTOMLEFT", 0, -TEXT_GAP)
        row.descText:SetWidth(innerW)
        row.descText:SetText(desc)
        local descH = row.descText:GetStringHeight()
        if descH < 1 then
            descH = 12
        end
        h = h + TEXT_GAP + descH
    else
        row.descText:SetText("")
        row.descText:Hide()
    end

    row:SetHeight(h)
    return h
end

local function ShowEmpty()
    ReleaseRows()
    local row = AcquireRow(resultsFrame)
    AnchorRow(row, resultsFrame, -PAD)
    row:Show()
    local h = FitRow(row, ns.L["SEARCH_NO_RESULTS"], "", true)
    PaintMuted(row.pathText)
    row.sep:Hide()
    row:Show()
    resultsFrame:SetHeight(h + PAD * 2)
    resultsFrame:Show()
end

local function ShowResults(hits)
    if not resultsFrame then
        return
    end

    ReleaseRows()

    if #hits == 0 then
        ShowEmpty()
        return
    end

    local y = -PAD
    local total = PAD
    for i, data in ipairs(hits) do
        local entry = data.entry
        local installed = data.installed
        local row = AcquireRow(resultsFrame)
        AnchorRow(row, resultsFrame, y)
        row:Show()

        local h = FitRow(row, data.path, data.desc, installed)
        if installed then
            row.pathText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            row.descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        else
            PaintMuted(row.pathText)
            PaintMuted(row.descText)
        end

        if i < #hits then
            row.sep:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            row.sep:Show()
        else
            row.sep:Hide()
        end

        if installed then
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end)
            row:SetScript("OnLeave", function(myself)
                myself:SetBackdropColor(0, 0, 0, 0)
            end)
            row:SetScript("OnMouseUp", function()
                NavigateTo(entry)
            end)
        end

        y = y - h
        total = total + h
    end

    resultsFrame:SetHeight(total + PAD)
    resultsFrame:Show()
end

local function DoSearch(query)
    ShowResults(ns.SearchRegistry:Query(query, 8))
end

local function CancelPending()
    if pendingSearch then
        pendingSearch:Cancel()
        pendingSearch = nil
    end
end

local function ScheduleSearch(query)
    CancelPending()
    pendingSearch = C_Timer.After(DEBOUNCE, function()
        pendingSearch = nil
        DoSearch(query)
    end)
end

local function HideResults()
    CancelPending()
    if resultsFrame then
        resultsFrame:Hide()
        resultsFrame:SetScript("OnUpdate", nil)
    end
end

local function StartDismissWatcher()
    if not resultsFrame then
        return
    end
    resultsFrame:SetScript("OnUpdate", function(myself, elapsed)
        if not searchBox then
            myself:Hide()
            myself:SetScript("OnUpdate", nil)
            return
        end
        if searchBox:HasFocus() then
            myself.timeOutside = nil
            return
        end
        local overBox = searchBox:IsMouseOver()
        local overResults = myself:IsMouseOver()
        if not overBox and not overResults then
            if not myself.timeOutside then
                myself.timeOutside = 0
            end
            myself.timeOutside = myself.timeOutside + elapsed
            if myself.timeOutside > 0.4 then
                myself:Hide()
                myself:SetScript("OnUpdate", nil)
                myself.timeOutside = nil
            end
        else
            myself.timeOutside = nil
        end
    end)
end

--- Parent is the hub toolbar; search anchors to the right edge of rightAnchor (defaults to parent).
function Search:Init(parent, rightAnchor)
    rightAnchor = rightAnchor or parent
    local box = CreateFrame("EditBox", "OneWoWSearchBox", parent, "BackdropTemplate")
    box:SetSize(200, 22)
    box:SetPoint("RIGHT", rightAnchor, "RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)
    box:SetBackdrop(BACKDROP_INNER)
    box:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    box:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    OneWoW_GUI:ApplyFont(box, 10)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetMaxLetters(80)
    box.placeholderText = ns.L["SEARCH"]
    box:SetText(box.placeholderText)
    box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local isPlaceholder = true

    box:SetScript("OnEditFocusGained", function(myself)
        if isPlaceholder then
            myself:SetText("")
            myself:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            isPlaceholder = false
        end
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)

    box:SetScript("OnEditFocusLost", function(myself)
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        if myself:GetText() == "" then
            myself:SetText(myself.placeholderText)
            myself:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            isPlaceholder = true
        end
    end)

    box:SetScript("OnEscapePressed", function(myself)
        myself:SetText("")
        myself:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        isPlaceholder = true
        myself:ClearFocus()
        HideResults()
    end)

    box:SetScript("OnTextChanged", function(myself, userInput)
        if not userInput then
            return
        end
        if isPlaceholder then
            return
        end
        local q = myself:GetText()
        if #q >= MIN_CHARS then
            ScheduleSearch(q)
            StartDismissWatcher()
        else
            HideResults()
        end
    end)

    OneWoW_GUI:AttachClearButton(box, {
        onClear = function()
            isPlaceholder = true
            HideResults()
        end,
    })

    searchBox = box

    local drop = CreateFrame("Frame", "OneWoWSearchResults", UIParent, "BackdropTemplate")
    drop:SetWidth(DROP_W)
    drop:SetHeight(50)
    drop:SetFrameStrata("FULLSCREEN_DIALOG")
    drop:SetFrameLevel(100)
    drop:SetBackdrop(BACKDROP_INNER)
    drop:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    drop:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    drop:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -2)

    accentBar = drop:CreateTexture(nil, "OVERLAY")
    accentBar:SetHeight(2)
    accentBar:SetPoint("TOPLEFT", drop, "TOPLEFT", 1, -1)
    accentBar:SetPoint("TOPRIGHT", drop, "TOPRIGHT", -1, -1)
    accentBar:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    drop:Hide()

    resultsFrame = drop

    ns.Locale:OnApply(function()
        if not searchBox then
            return
        end
        searchBox.placeholderText = ns.L["SEARCH"]
        if isPlaceholder then
            searchBox:SetText(searchBox.placeholderText)
        end
    end)

    return box
end

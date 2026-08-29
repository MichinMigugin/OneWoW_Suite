local _, ns = ...

ns.Search = {}
local Search = ns.Search

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER

local searchBox = nil
local resultsFrame = nil
local resultRows = {}

local function IsInstalled(addonKey)
    if not addonKey then return true end
    return C_AddOns.DoesAddOnExist(addonKey) and C_AddOns.GetAddOnEnableState(addonKey) ~= 0
end

local function NavigateTo(entry)
    if searchBox then
        searchBox:SetText("")
        searchBox:ClearFocus()
    end
    if resultsFrame then
        resultsFrame:Hide()
    end

    if entry.navType == "module" then
        if not ns.UI then return end
        local gui = ns.UI
        gui:Show()
        C_Timer.After(0.05, function()
            gui:SelectModuleTab(entry.module, entry.subtab)
        end)
    elseif entry.navType == "external" and entry.navFunc then
        entry.navFunc()
    end
end

local function ClearResultRows()
    for _, row in ipairs(resultRows) do
        row:Hide()
        row:SetParent(nil)
    end
    resultRows = {}
end

local function ShowResults(results)
    if not resultsFrame then return end

    ClearResultRows()

    if #results == 0 then
        resultsFrame:Hide()
        return
    end

    local rowH = 46
    local pad = 6
    local totalH = #results * rowH + pad * 2
    resultsFrame:SetHeight(totalH)

    for i, data in ipairs(results) do
        local entry = data.entry
        local installed = data.installed

        local row = CreateFrame("Frame", nil, resultsFrame, "BackdropTemplate")
        row:SetHeight(rowH)
        row:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 1, -(pad + (i - 1) * rowH))
        row:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -1, -(pad + (i - 1) * rowH))
        row:SetBackdrop(BACKDROP_SIMPLE)
        row:SetBackdropColor(0, 0, 0, 0)

        local pathStr = type(entry.path) == "function" and entry.path() or entry.path
        local descStr = type(entry.desc) == "function" and entry.desc() or entry.desc

        local pathText = OneWoW_GUI:CreateFS(row, 10)
        pathText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)
        pathText:SetPoint("RIGHT", row, "RIGHT", installed and -8 or -90, 0)
        pathText:SetJustifyH("LEFT")
        pathText:SetText(pathStr)
        if installed then
            pathText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            pathText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        if not installed then
            local badge = OneWoW_GUI:CreateFS(row, 10)
            badge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)
            badge:SetText("Not Installed")
            badge:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        local descText = OneWoW_GUI:CreateFS(row, 10)
        descText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 8)
        descText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 8)
        descText:SetJustifyH("LEFT")
        descText:SetText(descStr)
        if installed then
            descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        else
            descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        if i < #results then
            local sep = resultsFrame:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 4, -(pad + i * rowH))
            sep:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -4, -(pad + i * rowH))
            sep:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end

        if installed then
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end)
            row:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
            end)
            row:SetScript("OnMouseUp", function()
                NavigateTo(entry)
            end)
        end

        table.insert(resultRows, row)
    end

    resultsFrame:Show()
end

local function DoSearch(query)
    if not ns.SearchData then return end
    query = query:lower():match("^%s*(.-)%s*$")
    if #query < 2 then
        if resultsFrame then resultsFrame:Hide() end
        return
    end

    local hits = {}
    for _, entry in ipairs(ns.SearchData) do
        local score = 0
        for _, kw in ipairs(entry.keywords) do
            local kwL = kw:lower()
            if kwL == query then
                score = math.max(score, 100)
            elseif kwL:sub(1, #query) == query then
                score = math.max(score, 80)
            elseif kwL:find(query, 1, true) then
                score = math.max(score, 50)
            end
        end
        local entryPath = type(entry.path) == "function" and entry.path() or entry.path
        if entryPath:lower():find(query, 1, true) then
            score = math.max(score, 40)
        end
        if score > 0 then
            table.insert(hits, {
                entry = entry,
                score = score,
                installed = IsInstalled(entry.addonKey),
            })
        end
    end

    table.sort(hits, function(a, b)
        if a.installed ~= b.installed then
            return a.installed
        end
        return a.score > b.score
    end)

    local out = {}
    for i = 1, math.min(6, #hits) do
        table.insert(out, hits[i])
    end

    ShowResults(out)
end

local function StartDismissWatcher()
    if not resultsFrame then return end
    resultsFrame:SetScript("OnUpdate", function(self, elapsed)
        if not searchBox then
            self:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end
        if searchBox:HasFocus() then
            self.timeOutside = nil
            return
        end
        local overBox = searchBox:IsMouseOver()
        local overResults = self:IsMouseOver()
        if not overBox and not overResults then
            if not self.timeOutside then self.timeOutside = 0 end
            self.timeOutside = self.timeOutside + elapsed
            if self.timeOutside > 0.4 then
                self:Hide()
                self:SetScript("OnUpdate", nil)
                self.timeOutside = nil
            end
        else
            self.timeOutside = nil
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
    box:SetMaxLetters(50)
    box.placeholderText = "Search..."
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
        if resultsFrame then
            resultsFrame:Hide()
            resultsFrame:SetScript("OnUpdate", nil)
        end
    end)

    box:SetScript("OnTextChanged", function(myself, userInput)
        if not userInput then return end
        if isPlaceholder then return end
        local q = myself:GetText()
        if #q >= 2 then
            DoSearch(q)
            StartDismissWatcher()
        else
            if resultsFrame then
                resultsFrame:Hide()
                resultsFrame:SetScript("OnUpdate", nil)
            end
        end
    end)

    OneWoW_GUI:AttachClearButton(box, {
        onClear = function()
            isPlaceholder = true
            if resultsFrame then
                resultsFrame:Hide()
                resultsFrame:SetScript("OnUpdate", nil)
            end
        end,
    })

    searchBox = box

    local drop = CreateFrame("Frame", "OneWoWSearchResults", UIParent, "BackdropTemplate")
    drop:SetWidth(340)
    drop:SetHeight(50)
    drop:SetFrameStrata("FULLSCREEN_DIALOG")
    drop:SetFrameLevel(100)
    drop:SetBackdrop(BACKDROP_INNER)
    drop:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    drop:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    drop:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -2)

    local accentBar = drop:CreateTexture(nil, "OVERLAY")
    accentBar:SetHeight(2)
    accentBar:SetPoint("TOPLEFT", drop, "TOPLEFT", 1, -1)
    accentBar:SetPoint("TOPRIGHT", drop, "TOPRIGHT", -1, -1)
    accentBar:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    drop:Hide()

    resultsFrame = drop
    return box
end

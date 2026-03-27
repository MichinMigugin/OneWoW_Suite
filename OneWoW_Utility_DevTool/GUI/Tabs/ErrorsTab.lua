local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local format = string.format

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local function getErrorDB()
    return Addon.db and Addon.db.errorDB
end

local function soundChoiceLabel(L, value)
    if value == "devtools_error" then
        return L["ERR_SOUND_DEVTOOL"] or "DevTool alert"
    end
    if value == "raid_warning" then
        return L["ERR_SOUND_RAID_WARNING"] or "Raid warning"
    end
    if value == "tell_message" then
        return L["ERR_SOUND_TELL"] or "Tell message"
    end
    if value == "map_ping" then
        return L["ERR_SOUND_MAP_PING"] or "Map ping"
    end
    return L["ERR_SOUND_OFF"] or "Off"
end

local function copyFormatLabel(L, value)
    if value == "curseforge" then
        return L["ERR_COPY_FMT_CURSEFORGE"] or "CurseForge"
    end
    if value == "discord" then
        return L["ERR_COPY_FMT_DISCORD"] or "Discord"
    end
    return L["ERR_COPY_FMT_PLAIN"] or "Plain text"
end

local function normalizeKeepSessions(n)
    n = tonumber(n) or 10
    if n < 1 then
        return 1
    end
    if n > 20 then
        return 20
    end
    return n
end

local function keepSessionsDropdownText(L, n)
    n = normalizeKeepSessions(n)
    local fmt = L["ERR_KEEP_SESSIONS_VALUE"] or "%d"
    return format(fmt, n)
end

local function refreshDropdownLabels(tab)
    local L = Addon.L or {}
    local db = getErrorDB()
    if not db then
        return
    end
    if tab.soundDropdown and tab.soundDropdown._text then
        tab.soundDropdown._text:SetText(soundChoiceLabel(L, db.soundChoice or "off"))
        tab.soundDropdown._activeValue = db.soundChoice
    end
    if tab.copyFormatDropdown and tab.copyFormatDropdown._text then
        tab.copyFormatDropdown._text:SetText(copyFormatLabel(L, db.copyFormat or "plain"))
        tab.copyFormatDropdown._activeValue = db.copyFormat
    end
    if tab.keepSessionsDropdown and tab.keepSessionsDropdown._text then
        tab.keepSessionsDropdown._text:SetText(keepSessionsDropdownText(L, db.keepLastSessions))
        tab.keepSessionsDropdown._activeValue = normalizeKeepSessions(db.keepLastSessions)
    end
end

function Addon.UI:CreateErrorsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local L = Addon.L or {}

    local bugGrabberNotice = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bugGrabberNotice:SetWordWrap(true)
    bugGrabberNotice:SetJustifyH("LEFT")
    bugGrabberNotice:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    bugGrabberNotice:Hide()

    tab.bugGrabberNotice = bugGrabberNotice

    local clearBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = Addon.L and Addon.L["BTN_CLEAR"] or "Clear",
        height = 22,
        minWidth = 72,
    })
    clearBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    tab.luaClearBtn = clearBtn
    clearBtn:SetScript("OnClick", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:ClearErrors()
        end
    end)

    local countLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("LEFT", clearBtn, "RIGHT", 12, 0)
    countLabel:SetText((Addon.L and Addon.L["LABEL_ERRORS"] or "Errors:") .. " 0")
    countLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    -- Checkbox hit box is only CHECKBOX_SIZE wide; label is cb.label — do not anchor siblings to cb:RIGHT or they overlap the label text.
    local clearReloadCheck = OneWoW_GUI:CreateCheckbox(tab, {
        label = L["ERR_CLEAR_ON_RELOAD"] or "Clear errors on /reload",
    })
    clearReloadCheck:SetChecked(getErrorDB() and getErrorDB().clearOnReload or false)
    clearReloadCheck:SetScript("OnClick", function(self)
        local db = getErrorDB()
        if db then
            db.clearOnReload = self:GetChecked() and true or false
        end
    end)

    local soundDrop = OneWoW_GUI:CreateDropdown(tab, { width = 160, height = 24, text = "" })
    soundDrop:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -8)

    local copyDrop = OneWoW_GUI:CreateDropdown(tab, { width = 160, height = 24, text = "" })

    OneWoW_GUI:AttachFilterMenu(soundDrop, {
        searchable = false,
        menuHeight = 200,
        getActiveValue = function()
            return getErrorDB() and getErrorDB().soundChoice or "off"
        end,
        buildItems = function()
            local loc = Addon.L or {}
            return {
                { value = "off", text = loc["ERR_SOUND_OFF"] or "Off" },
                { value = "devtools_error", text = loc["ERR_SOUND_DEVTOOL"] or "DevTool alert" },
                { value = "raid_warning", text = loc["ERR_SOUND_RAID_WARNING"] or "Raid warning" },
                { value = "tell_message", text = loc["ERR_SOUND_TELL"] or "Tell message" },
                { value = "map_ping", text = loc["ERR_SOUND_MAP_PING"] or "Map ping" },
            }
        end,
        onSelect = function(value)
            local db = getErrorDB()
            if db then
                db.soundChoice = value
            end
            refreshDropdownLabels(tab)
            if Addon.ErrorLogger and Addon.ErrorLogger.PreviewSoundChoice then
                Addon.ErrorLogger:PreviewSoundChoice(value)
            end
        end,
    })

    OneWoW_GUI:AttachFilterMenu(copyDrop, {
        searchable = false,
        menuHeight = 140,
        getActiveValue = function()
            return getErrorDB() and getErrorDB().copyFormat or "plain"
        end,
        buildItems = function()
            local loc = Addon.L or {}
            return {
                { value = "plain", text = loc["ERR_COPY_FMT_PLAIN"] or "Plain text" },
                { value = "curseforge", text = loc["ERR_COPY_FMT_CURSEFORGE"] or "CurseForge" },
                { value = "discord", text = loc["ERR_COPY_FMT_DISCORD"] or "Discord" },
            }
        end,
        onSelect = function(value)
            local db = getErrorDB()
            if db then
                db.copyFormat = value
            end
            refreshDropdownLabels(tab)
        end,
    })

    tab.soundDropdown = soundDrop
    tab.copyFormatDropdown = copyDrop

    local keepLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keepLabel:SetText(L["ERR_KEEP_SESSIONS_LABEL"] or "Keep sessions:")
    keepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local keepSessionsDrop = OneWoW_GUI:CreateDropdown(tab, { width = 56, height = 24, text = "" })

    OneWoW_GUI:AttachFilterMenu(keepSessionsDrop, {
        searchable = false,
        menuHeight = 320,
        getActiveValue = function()
            return normalizeKeepSessions(getErrorDB() and getErrorDB().keepLastSessions)
        end,
        buildItems = function()
            local loc = Addon.L or {}
            local fmt = loc["ERR_KEEP_SESSIONS_VALUE"] or "%d"
            local items = {}
            for i = 1, 20 do
                tinsert(items, { value = i, text = format(fmt, i) })
            end
            return items
        end,
        onSelect = function(value)
            local db = getErrorDB()
            if db then
                db.keepLastSessions = normalizeKeepSessions(value)
            end
            refreshDropdownLabels(tab)
        end,
    })

    tab.keepSessionsDropdown = keepSessionsDrop

    keepLabel:SetPoint("LEFT", soundDrop, "RIGHT", 16, 3)
    keepSessionsDrop:SetPoint("LEFT", keepLabel, "RIGHT", 10, 0)
    keepSessionsDrop:SetPoint("TOP", soundDrop, "TOP", 0, 0)

    local function layoutLuaErrorRowAnchors()
        local cb = clearReloadCheck
        local cl = countLabel
        local btn = clearBtn
        if not cb or not cl or not btn then
            return
        end
        local offsetX = (cl:GetRight() + 16 + cb:GetWidth() / 2) - (btn:GetLeft() + btn:GetWidth() / 2)
        cb:ClearAllPoints()
        cb:SetPoint("CENTER", btn, "CENTER", offsetX, 0)
    end

    tab.LayoutErrorRowAnchors = layoutLuaErrorRowAnchors

    -- Full-width invisible line under the retention row so list top (TOPLEFT + TOPRIGHT) shares one Y (avoids shearing vs tab TOP).
    local belowRetention = CreateFrame("Frame", nil, tab)
    belowRetention:SetPoint("LEFT", tab, "LEFT", 5, 0)
    belowRetention:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
    belowRetention:SetPoint("TOP", soundDrop, "BOTTOM", 0, 0)
    belowRetention:SetHeight(1)

    local listPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 250 })
    listPanel:ClearAllPoints()
    listPanel:SetPoint("TOPLEFT", belowRetention, "BOTTOMLEFT", 0, -12)
    listPanel:SetPoint("TOPRIGHT", belowRetention, "BOTTOMRIGHT", 0, -12)
    listPanel:SetHeight(210)
    self:StyleContentPanel(listPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(listPanel, {})
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 4)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.errorButtons = {}
    for i = 1, 100 do
        local btn = OneWoW_GUI:CreateListRowBasic(listContent, {
            height = 20,
            label = "",
            onClick = function(self)
                if Addon.ErrorLogger and self.errorData then
                    Addon.ErrorLogger:ShowErrorDetails(self.errorData)
                end
            end,
        })
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i - 1) * 20 - 2)
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        btn.label:SetFontObject(GameFontNormalSmall)

        tab.errorButtons[i] = btn
    end

    local detailsPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    detailsPanel:ClearAllPoints()
    detailsPanel:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    detailsPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    self:StyleContentPanel(detailsPanel)

    local detailsScroll, detailsContent = OneWoW_GUI:CreateScrollFrame(detailsPanel, {})
    detailsScroll:ClearAllPoints()
    detailsScroll:SetPoint("TOPLEFT", detailsPanel, "TOPLEFT", 4, -4)
    detailsScroll:SetPoint("BOTTOMRIGHT", detailsPanel, "BOTTOMRIGHT", -14, 4)

    detailsScroll:HookScript("OnSizeChanged", function(self, w)
        detailsContent:SetWidth(w)
    end)

    tab.detailsText = detailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.detailsText:SetPoint("TOPLEFT", 2, -2)
    tab.detailsText:SetPoint("RIGHT", detailsContent, "RIGHT", -2, 0)
    tab.detailsText:SetJustifyH("LEFT")
    tab.detailsText:SetText(Addon.L and Addon.L["LABEL_NO_ERROR"] or "No error selected")
    tab.detailsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = Addon.L and Addon.L["BTN_COPY_ERROR"] or "Copy Error",
        height = 25,
        minWidth = 96,
    })
    copyBtn:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    copyBtn:SetScript("OnClick", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:CopyCurrentError()
        end
    end)

    copyDrop:SetPoint("BOTTOMLEFT", copyBtn, "BOTTOMRIGHT", 10, 0)

    tab.listScroll = listScroll
    tab.detailsScroll = detailsScroll
    tab.countLabel = countLabel
    tab.clearReloadCheck = clearReloadCheck

    tab:SetScript("OnShow", function()
        local db = getErrorDB()
        if tab.clearReloadCheck and db then
            tab.clearReloadCheck:SetChecked(db.clearOnReload and true or false)
        end
        refreshDropdownLabels(tab)
        if Addon.ErrorLogger then
            Addon.ErrorLogger:UpdateLuaTabBugGrabberNotice()
            Addon.ErrorLogger:UpdateUI()
        elseif tab.LayoutErrorRowAnchors then
            tab.LayoutErrorRowAnchors()
        end
    end)

    Addon.LuaConsoleTab = tab
    refreshDropdownLabels(tab)
    if Addon.ErrorLogger and Addon.ErrorLogger.UpdateLuaTabBugGrabberNotice then
        Addon.ErrorLogger:UpdateLuaTabBugGrabberNotice()
    end
    C_Timer.After(0, function()
        if tab.LayoutErrorRowAnchors then
            tab.LayoutErrorRowAnchors()
        end
    end)
    return tab
end

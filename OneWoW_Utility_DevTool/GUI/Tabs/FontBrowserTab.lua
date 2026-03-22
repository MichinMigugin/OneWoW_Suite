local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

local format = format
local floor = math.floor
local max = math.max
local tinsert = tinsert
local pcall = pcall
local tonumber = tonumber
local tostring = tostring

local FB

local BOOKMARK_ICON_PATH = format("Interface\\AddOns\\%s\\Media\\icon-fav.png", ADDON_NAME)

local function getDU()
    return Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
end

local function getEffectivePreviewBg()
    local dbColor = Addon.db and Addon.db.fontBrowserPreviewBg
    if type(dbColor) == "table" and type(dbColor[1]) == "number" and type(dbColor[2]) == "number" and type(dbColor[3]) == "number" then
        return dbColor[1], dbColor[2], dbColor[3], (dbColor[4] or 1)
    end
    local DU = getDU()
    local prevBg = DU.FONT_BROWSER_PREVIEW_BG
    if prevBg and type(prevBg[1]) == "number" then
        return prevBg[1], prevBg[2], prevBg[3], prevBg[4] or 1
    end
    return OneWoW_GUI:GetThemeColor("BG_TERTIARY")
end

local SAMPLE_TEXT_DEFAULT = "The quick brown fox jumps over the lazy dog\nABCDEFGHIJKLMNOPQRSTUVWXYZ\n0123456789 !@#$%^&*()"

local function scheduleFilterRefresh(tab)
    if tab._filterTicker then
        tab._filterTicker:Cancel()
        tab._filterTicker = nil
    end
    tab._filterTicker = C_Timer.After(0.12, function()
        tab._filterTicker = nil
        if not tab.searchBox then return end
        FB:SetFilterText(tab.searchBox:GetSearchText())
        Addon.UI.FontTab_RefreshList(tab)
    end)
end

-- Virtualized list: position rows based on scroll offset
local function ensureListRowBookmarkIcon(btn, rowH)
    if btn._fontBookmarkIcon then return end
    local DU = getDU()
    local sz = DU.FONT_BROWSER_BOOKMARK_ICON_SIZE or 14
    local pad = DU.FONT_BROWSER_BOOKMARK_ICON_RIGHT_PAD or 8
    rowH = rowH or 20
    local topInset = -floor((rowH - sz) / 2 + 0.5)
    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetSize(sz, sz)
    tex:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -pad, topInset)
    tex:SetTexCoord(0, 1, 0, 1)
    btn._fontBookmarkIcon = tex
end

local function styleListButtonText(btn)
    local fs = btn:GetFontString()
    if not fs then return end
    local DU = getDU()
    local gap = DU.FONT_BROWSER_BOOKMARK_ICON_TEXT_GAP or 4
    local rightPad = DU.FONT_BROWSER_BOOKMARK_ICON_RIGHT_PAD or 8
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
    if btn._fontBookmarkIcon and btn._fontBookmarkIcon:IsShown() then
        fs:SetPoint("RIGHT", btn._fontBookmarkIcon, "LEFT", -gap, 0)
    else
        fs:SetPoint("RIGHT", btn, "RIGHT", -rightPad, 0)
    end
end

function Addon.UI.FontTab_RefreshList(tab)
    if not tab or not tab.listScroll then return end
    local DU = getDU()
    local rowH = DU.FONT_BROWSER_LIST_ROW_HEIGHT or 20
    local n = FB:GetFilteredCount()
    local content = tab.listScroll:GetScrollChild()
    content:SetHeight(max(n * rowH, 1))
    local scrollMax = max(content:GetHeight() - tab.listScroll:GetHeight(), 0)
    local vs = tab.listScroll:GetVerticalScroll()
    if vs > scrollMax then
        tab.listScroll:SetVerticalScroll(scrollMax)
    end
    Addon.UI.FontTab_UpdateListRows(tab)
end

function Addon.UI.FontTab_UpdateListRows(tab)
    if not tab or not tab.listButtons then return end
    local DU = getDU()
    local rowH = DU.FONT_BROWSER_LIST_ROW_HEIGHT or 20
    local scroll = tab.listScroll:GetVerticalScroll()
    local startIdx = floor(scroll / rowH) + 1
    local listContent = tab.listScroll:GetScrollChild()

    for i, btn in ipairs(tab.listButtons) do
        local idx = startIdx + i - 1
        local name = FB:GetFilteredEntry(idx)
        if name then
            btn:ClearAllPoints()
            btn:SetHeight(rowH)
            btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(idx - 1) * rowH)
            btn:SetPoint("RIGHT", listContent, "RIGHT", -2, 0)

            ensureListRowBookmarkIcon(btn, rowH)
            if FB:IsBookmarked(name) then
                btn._fontBookmarkIcon:SetTexture(BOOKMARK_ICON_PATH)
                btn._fontBookmarkIcon:Show()
            else
                btn._fontBookmarkIcon:Hide()
            end

            btn:SetText(name)
            btn._entryIndex = idx
            local sel = (tab.selectedFontName == name)
            btn:SetNormalFontObject(sel and GameFontHighlightSmall or GameFontNormalSmall)
            styleListButtonText(btn)
            btn:Show()
        else
            if btn._fontBookmarkIcon then btn._fontBookmarkIcon:Hide() end
            btn:Hide()
            btn._entryIndex = nil
        end
    end
end

local function refreshWidgetSizeDropdownLabel(tab)
    local dd = tab.widgetSizeDropdown
    if not dd or not dd._text then return end
    local v = tab.widgetPresetActiveValue or "none"
    dd._activeValue = v
    if v == "none" then
        dd._text:SetText(L["FONT_WIDGET_SIZE_NONE"] or "None")
    else
        local n = tonumber(v)
        local label = (FB and FB.WIDGET_SIZE_LABELS and n ~= nil) and FB.WIDGET_SIZE_LABELS[n] or tostring(v)
        dd._text:SetText(label)
    end
end

local function applyFontSelection(tab, idx)
    local name = FB:GetFilteredEntry(idx)
    if not name then return end

    tab.selectedFontName = name
    tab.selectedListIndex = idx
    tab.overrides = {}
    tab.widgetPresetActiveValue = "none"

    if tab.nameText then tab.nameText:SetText(name) end

    Addon.UI.FontTab_UpdatePreview(tab)
    Addon.UI.FontTab_UpdateDetails(tab)
    Addon.UI.FontTab_UpdateListRows(tab)
    Addon.UI.FontTab_UpdateCopyButtons(tab)
    Addon.UI.FontTab_UpdateWorkspaceFromFont(tab)
    refreshWidgetSizeDropdownLabel(tab)
end

local function buildFlagsString(outline, thickOutline, monochrome)
    local parts = {}
    if thickOutline then
        tinsert(parts, "THICKOUTLINE")
    elseif outline then
        tinsert(parts, "OUTLINE")
    end
    if monochrome then
        tinsert(parts, "MONOCHROME")
    end
    return table.concat(parts, ", ")
end

local function parseFlagsString(flags)
    flags = (flags or ""):upper()
    return {
        outline = flags:find("OUTLINE", 1, true) and not flags:find("THICKOUTLINE", 1, true),
        thickOutline = flags:find("THICKOUTLINE", 1, true) ~= nil,
        monochrome = flags:find("MONOCHROME", 1, true) ~= nil,
    }
end

local function getEffectiveOverrides(tab)
    local ov = tab.overrides or {}
    local result = {}
    local name = tab.selectedFontName
    if not name then return result end

    local info = FB:GetFontInfo(name)
    if not info then return result end

    if ov.height and ov.height ~= info.height then
        result.height = ov.height
        result.path = info.path
    end
    if ov.flags and ov.flags ~= (info.flags or "") then
        result.flags = ov.flags
        result.path = result.path or info.path
    end
    if ov.textColor then result.textColor = ov.textColor end
    if ov.shadowColor then result.shadowColor = ov.shadowColor end
    if ov.shadowOffset then result.shadowOffset = ov.shadowOffset end
    if ov.justifyH then result.justifyH = ov.justifyH end
    if ov.justifyV then result.justifyV = ov.justifyV end
    if ov.spacing then result.spacing = ov.spacing end
    if ov.alpha then result.alpha = ov.alpha end

    return result
end

-- After SetFontObject, optional SetFont(path,h,flags) replaces rasterization but clears template-derived
-- text/shadow colors on FontStrings. Re-apply properties from GetFontInfo unless the workspace overrides them.
-- Justify is NOT handled here — it is applied in FontTab_UpdatePreview using values captured from the FontString.
local function applyFontStringVisualState(fs, info, ov)
    if not fs then return end
    ov = ov or {}
    info = info or {}

    local tc = ov.textColor or info.textColor
    if tc then
        pcall(fs.SetTextColor, fs, tc.r or 1, tc.g or 1, tc.b or 1, tc.a or 1)
    end

    local sc = ov.shadowColor or info.shadowColor
    if sc then
        pcall(fs.SetShadowColor, fs, sc.r or 0, sc.g or 0, sc.b or 0, sc.a or 1)
    end

    local so = ov.shadowOffset or info.shadowOffset
    if so then
        pcall(fs.SetShadowOffset, fs, so.x or 0, so.y or 0)
    end

    local sp
    if ov.spacing ~= nil then
        sp = ov.spacing
    else
        sp = info.spacing
    end
    if sp ~= nil then pcall(fs.SetSpacing, fs, sp) end

    local al
    if ov.alpha ~= nil then
        al = ov.alpha
    else
        al = info.alpha
    end
    if al ~= nil then pcall(fs.SetAlpha, fs, al) end

    if info.indentedWordWrap ~= nil and fs.SetIndentedWordWrap then
        pcall(fs.SetIndentedWordWrap, fs, info.indentedWordWrap)
    end
end

local function recreateFontString(tab, key)
    if tab[key] then tab[key]:Hide() end
    local fs = tab.previewClip:CreateFontString(nil, "ARTWORK")
    fs:SetWordWrap(true)
    tab[key] = fs
    return fs
end

function Addon.UI.FontTab_UpdatePreview(tab)
    if not tab.selectedFontName then
        if tab.previewFS then tab.previewFS:SetText(L["FONT_MSG_SELECT_FONT"] or "Select a font to preview") end
        if tab.templateFS then tab.templateFS:Hide() end
        if tab.templateLabel then tab.templateLabel:Hide() end
        if tab.previewLabel then tab.previewLabel:Hide() end
        return
    end

    local fontObj = _G[tab.selectedFontName]
    if not fontObj then return end

    local sampleText = tab.sampleText or SAMPLE_TEXT_DEFAULT
    local ov = tab.overrides or {}
    local info = FB:GetFontInfo(tab.selectedFontName)

    local fs = recreateFontString(tab, "previewFS")
    fs:SetFontObject(fontObj)

    if ov.height or ov.flags then
        local path = (info and info.path) or "Fonts\\FRIZQT__.TTF"
        local h = ov.height or (info and info.height) or 12
        local f = ov.flags or (info and info.flags) or ""
        pcall(fs.SetFont, fs, path, h, f)
    end

    fs:SetText(sampleText)
    applyFontStringVisualState(fs, info, ov)
    if ov.justifyH then fs:SetJustifyH(ov.justifyH) end
    if ov.justifyV then fs:SetJustifyV(ov.justifyV) end
    fs:Show()

    if tab.compareMode then
        local tfs = recreateFontString(tab, "templateFS")
        tfs:SetFontObject(fontObj)
        tfs:SetText(sampleText)
        applyFontStringVisualState(tfs, info, nil)
        tfs:Show()
        if tab.templateLabel then tab.templateLabel:Show() end
        if tab.previewLabel then tab.previewLabel:Show() end
    else
        if tab.templateFS then tab.templateFS:Hide() end
        if tab.templateLabel then tab.templateLabel:Hide() end
        if tab.previewLabel then tab.previewLabel:Hide() end
    end

    Addon.UI.FontTab_LayoutPreview(tab)
end

function Addon.UI.FontTab_UpdateDetails(tab)
    if not tab.infoText then return end

    local lines = {}
    local name = tab.selectedFontName

    if not name then
        tab.infoText:SetText(L["FONT_MSG_SELECT_FONT"] or "Select a font to preview")
        local h = tab.infoText:GetStringHeight()
        tab.infoScroll:GetScrollChild():SetHeight(max(h + 16, tab.infoScroll:GetHeight()))
        return
    end

    local info = FB:GetFontInfo(name)

    -- Summary section
    tinsert(lines, "|cffffd100" .. (L["FONT_SECTION_SUMMARY"] or "Summary") .. "|r")
    tinsert(lines, (L["FONT_LABEL_FONT_NAME"] or "Font:") .. " " .. name)
    if info then
        tinsert(lines, (L["LABEL_FILE"] or "File:") .. " " .. (info.path or "?"))
        tinsert(lines, (L["FONT_LABEL_FONT_HEIGHT"] or "Height:") .. " " .. tostring(info.height or "?"))
        tinsert(lines, (L["FONT_LABEL_FONT_FLAGS"] or "Flags:") .. " " .. (info.flags ~= "" and info.flags or (L["FONT_LABEL_NONE"] or "None")))
    end

    -- Inheritance chain
    local chain = FB:GetInheritanceChain(name)
    if #chain > 0 then
        tinsert(lines, "")
        tinsert(lines, "|cffffd100" .. (L["FONT_SECTION_INHERITANCE"] or "Inheritance") .. "|r")
        tinsert(lines, name .. " -> " .. table.concat(chain, " -> "))
    end

    -- Colors & Shadow
    if info then
        tinsert(lines, "")
        tinsert(lines, "|cffffd100" .. (L["FONT_SECTION_COLORS"] or "Colors & Shadow") .. "|r")
        if info.textColor then
            tinsert(lines, (L["FONT_LABEL_TEXT_COLOR"] or "Text Color:") .. " " .. FB:FormatRGBA(info.textColor))
        end
        if info.shadowColor then
            tinsert(lines, (L["FONT_LABEL_SHADOW_COLOR"] or "Shadow Color:") .. " " .. FB:FormatRGBA(info.shadowColor))
        end
        if info.shadowOffset then
            tinsert(lines, (L["FONT_LABEL_SHADOW_OFFSET"] or "Shadow Offset:") .. " " .. format("%.1f, %.1f", info.shadowOffset.x or 0, info.shadowOffset.y or 0))
        end

        -- Layout
        tinsert(lines, "")
        tinsert(lines, "|cffffd100" .. (L["FONT_SECTION_LAYOUT"] or "Layout") .. "|r")
        tinsert(lines, (L["FONT_LABEL_JUSTIFY_H"] or "Justify H:") .. " " .. (info.justifyH or "?"))
        tinsert(lines, (L["FONT_LABEL_JUSTIFY_V"] or "Justify V:") .. " " .. (info.justifyV or "?"))
        if info.spacing and info.spacing ~= 0 then
            tinsert(lines, (L["FONT_LABEL_SPACING"] or "Spacing:") .. " " .. tostring(info.spacing))
        end
        if info.alpha and info.alpha < 1 then
            tinsert(lines, (L["FONT_LABEL_ALPHA"] or "Alpha:") .. " " .. format("%.2f", info.alpha))
        end
    end

    -- Active overrides
    local ov = getEffectiveOverrides(tab)
    local hasOv = false
    for _ in pairs(ov) do hasOv = true; break end
    if hasOv then
        tinsert(lines, "")
        tinsert(lines, "|cffffd100" .. (L["FONT_SECTION_OVERRIDES"] or "Active Overrides") .. "|r")
        if ov.height then tinsert(lines, "  height = " .. tostring(ov.height)) end
        if ov.flags then tinsert(lines, "  flags = " .. ov.flags) end
        if ov.textColor then tinsert(lines, "  textColor = " .. FB:FormatRGBA(ov.textColor)) end
        if ov.shadowColor then tinsert(lines, "  shadowColor = " .. FB:FormatRGBA(ov.shadowColor)) end
        if ov.shadowOffset then tinsert(lines, "  shadowOffset = " .. format("%.1f, %.1f", ov.shadowOffset.x, ov.shadowOffset.y)) end
        if ov.justifyH then tinsert(lines, '  justifyH = "' .. ov.justifyH .. '"') end
        if ov.justifyV then tinsert(lines, '  justifyV = "' .. ov.justifyV .. '"') end
        if ov.spacing then tinsert(lines, "  spacing = " .. tostring(ov.spacing)) end
        if ov.alpha then tinsert(lines, "  alpha = " .. format("%.2f", ov.alpha)) end
    end

    -- Bookmark status
    if FB:IsBookmarked(name) then
        tinsert(lines, "")
        tinsert(lines, "|cff00ff00" .. (L["LABEL_BOOKMARKED"] or "[Bookmarked]") .. "|r")
    end

    tab.infoText:SetText(table.concat(lines, "\n"))
    local h = tab.infoText:GetStringHeight()
    tab.infoScroll:GetScrollChild():SetHeight(max(h + 16, tab.infoScroll:GetHeight()))
end

local function setCopyButtonEnabled(btn, enabled)
    if not btn then return end
    btn:EnableMouse(enabled)
    if enabled then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED")) end
    end
end

function Addon.UI.FontTab_UpdateCopyButtons(tab)
    local hasSel = tab.selectedFontName ~= nil
    setCopyButtonEnabled(tab.copyNameBtn, hasSel)
    setCopyButtonEnabled(tab.copySetFontBtn, hasSel)
    setCopyButtonEnabled(tab.copySnippetBtn, hasSel)
    setCopyButtonEnabled(tab.copyCreateFontBtn, hasSel)
end

local function paintBarButton(btn)
    if not btn or not btn.text then return end
    local active = btn._barActive
    local over = btn:IsMouseOver()
    if active then
        if over then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        end
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        if over then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
end

local function bindBarButtonMouse(btn)
    btn:SetScript("OnEnter", function(self) paintBarButton(self) end)
    btn:SetScript("OnLeave", function(self) paintBarButton(self) end)
    btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED")) end)
    btn:SetScript("OnMouseUp", function(self) paintBarButton(self) end)
end

local function refreshToolbarState(tab)
    if tab.favsBtn then
        tab.favsBtn._barActive = FB.favoritesOnly
        paintBarButton(tab.favsBtn)
    end
    if tab.bookmarkBtn then
        local bookmarked = tab.selectedFontName and FB:IsBookmarked(tab.selectedFontName)
        tab.bookmarkBtn._barActive = bookmarked and true or false
        if tab.bookmarkBtn.SetFitText then
            tab.bookmarkBtn:SetFitText(bookmarked and (L["BTN_REMOVE_BOOKMARK"] or "Remove bookmark") or (L["BTN_BOOKMARK"] or "Bookmark"))
        end
        paintBarButton(tab.bookmarkBtn)
    end
    if tab.compareBtn then
        tab.compareBtn._barActive = tab.compareMode or false
        paintBarButton(tab.compareBtn)
    end
end

function Addon.UI.FontTab_UpdateWorkspaceFromFont(tab)
    if not tab.selectedFontName then return end
    local info = FB:GetFontInfo(tab.selectedFontName)
    if not info then return end

    if tab.sizeEdit then tab.sizeEdit:SetText(tostring(floor((info.height or 12) + 0.5))) end

    local flags = parseFlagsString(info.flags)
    if tab.outlineBtn then
        tab.outlineBtn._barActive = flags.outline
        paintBarButton(tab.outlineBtn)
    end
    if tab.thickBtn then
        tab.thickBtn._barActive = flags.thickOutline
        paintBarButton(tab.thickBtn)
    end
    if tab.monoBtn then
        tab.monoBtn._barActive = flags.monochrome
        paintBarButton(tab.monoBtn)
    end

    if info.textColor and tab.textREdit then
        tab.textREdit:SetText(format("%.2f", info.textColor.r or 1))
        tab.textGEdit:SetText(format("%.2f", info.textColor.g or 1))
        tab.textBEdit:SetText(format("%.2f", info.textColor.b or 1))
        tab.textAEdit:SetText(format("%.2f", info.textColor.a or 1))
    end
    if info.shadowColor and tab.shadREdit then
        tab.shadREdit:SetText(format("%.2f", info.shadowColor.r or 0))
        tab.shadGEdit:SetText(format("%.2f", info.shadowColor.g or 0))
        tab.shadBEdit:SetText(format("%.2f", info.shadowColor.b or 0))
        tab.shadAEdit:SetText(format("%.2f", info.shadowColor.a or 1))
    end
    if info.shadowOffset and tab.shadXEdit then
        tab.shadXEdit:SetText(format("%.1f", info.shadowOffset.x or 0))
        tab.shadYEdit:SetText(format("%.1f", info.shadowOffset.y or 0))
    end
    if tab.spacingEdit then
        tab.spacingEdit:SetText(tostring(info.spacing or 0))
    end
    if tab.alphaEdit then
        tab.alphaEdit:SetText(format("%.2f", info.alpha or 1))
    end
end

local function collectOverridesFromUI(tab)
    local ov = {}
    local name = tab.selectedFontName
    if not name then return ov end
    local info = FB:GetFontInfo(name)
    if not info then return ov end

    local sizeVal = tonumber(tab.sizeEdit and tab.sizeEdit:GetText())
    if sizeVal and sizeVal > 0 and sizeVal ~= floor((info.height or 12) + 0.5) then
        ov.height = sizeVal
    end

    local outline = tab.outlineBtn and tab.outlineBtn._barActive
    local thick = tab.thickBtn and tab.thickBtn._barActive
    local mono = tab.monoBtn and tab.monoBtn._barActive
    local flagsStr = buildFlagsString(outline, thick, mono)
    if flagsStr ~= (info.flags or "") then
        ov.flags = flagsStr
    end

    local tr = tonumber(tab.textREdit and tab.textREdit:GetText())
    local tg = tonumber(tab.textGEdit and tab.textGEdit:GetText())
    local tb = tonumber(tab.textBEdit and tab.textBEdit:GetText())
    local ta = tonumber(tab.textAEdit and tab.textAEdit:GetText())
    if tr and tg and tb and ta and info.textColor then
        local tc = info.textColor
        if math.abs(tr - tc.r) > 0.005 or math.abs(tg - tc.g) > 0.005 or math.abs(tb - tc.b) > 0.005 or math.abs(ta - tc.a) > 0.005 then
            ov.textColor = { r = tr, g = tg, b = tb, a = ta }
        end
    end

    local sr = tonumber(tab.shadREdit and tab.shadREdit:GetText())
    local sg = tonumber(tab.shadGEdit and tab.shadGEdit:GetText())
    local sb = tonumber(tab.shadBEdit and tab.shadBEdit:GetText())
    local sa = tonumber(tab.shadAEdit and tab.shadAEdit:GetText())
    if sr and sg and sb and sa and info.shadowColor then
        local sc = info.shadowColor
        if math.abs(sr - sc.r) > 0.005 or math.abs(sg - sc.g) > 0.005 or math.abs(sb - sc.b) > 0.005 or math.abs(sa - sc.a) > 0.005 then
            ov.shadowColor = { r = sr, g = sg, b = sb, a = sa }
        end
    end

    local sx = tonumber(tab.shadXEdit and tab.shadXEdit:GetText())
    local sy = tonumber(tab.shadYEdit and tab.shadYEdit:GetText())
    if sx and sy and info.shadowOffset then
        if math.abs(sx - info.shadowOffset.x) > 0.05 or math.abs(sy - info.shadowOffset.y) > 0.05 then
            ov.shadowOffset = { x = sx, y = sy }
        end
    end

    local sp = tonumber(tab.spacingEdit and tab.spacingEdit:GetText())
    if sp and sp ~= (info.spacing or 0) then
        ov.spacing = sp
    end

    local al = tonumber(tab.alphaEdit and tab.alphaEdit:GetText())
    if al and info.alpha and math.abs(al - info.alpha) > 0.005 then
        ov.alpha = al
    end

    return ov
end

local function applyWorkspaceOverrides(tab)
    tab.overrides = collectOverridesFromUI(tab)
    Addon.UI.FontTab_UpdatePreview(tab)
    Addon.UI.FontTab_UpdateDetails(tab)
end

local function createMiniEdit(parent, width)
    local edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    edit:SetSize(width or 42, 18)
    edit:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    edit:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    edit:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    edit:SetFontObject(GameFontNormalSmall)
    edit:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    edit:SetJustifyH("CENTER")
    edit:SetAutoFocus(false)
    edit:SetTextInsets(3, 3, 0, 0)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return edit
end

local function createMiniLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return fs
end

-- Right-aligned label in fixed-width band for workspace column alignment.
local function createWorkspaceLabel(parent, text, y, bandWidth)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    fs:SetJustifyH("RIGHT")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    fs:SetPoint("RIGHT", parent, "TOPLEFT", bandWidth, 0)
    return fs
end

function Addon.UI:CreateFontBrowserTab(parent)
    FB = Addon.FontBrowser
    if not FB then return CreateFrame("Frame", nil, parent) end

    FB:BuildCatalog()

    local DU = getDU()
    local ROW_H = DU.FONT_BROWSER_LIST_ROW_HEIGHT or 20
    local NUM_ROWS = DU.FONT_BROWSER_LIST_VISIBLE_ROWS or 40
    local LEFT_DEFAULT = DU.FONT_BROWSER_LEFT_PANE_DEFAULT_WIDTH or 280
    local LEFT_MIN = DU.FONT_BROWSER_LEFT_PANE_MIN_WIDTH or 180
    local RIGHT_MIN = DU.FONT_BROWSER_RIGHT_PANE_MIN_WIDTH or 340
    local DIV_W = DU.FRAME_INSPECTOR_DIVIDER_WIDTH or 6
    local PREVIEW_BG_H = DU.FONT_BROWSER_PREVIEW_BG_HEIGHT or 100
    local WS_EXTRA_H = DU.FONT_BROWSER_WORKSPACE_EXTRA_HEIGHT or 0
    local WS_LABEL_COL = DU.FONT_BROWSER_LABEL_COLUMN_WIDTH or 100
    local WS_LABEL_GAP = 4

    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    tab.compareMode = false
    tab.overrides = {}
    tab.widgetPresetActiveValue = "none"
    tab.sampleText = SAMPLE_TEXT_DEFAULT

    -- Top toolbar: search + buttons
    local searchBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 160,
        height = 22,
        placeholderText = L["FONT_SEARCH_PLACEHOLDER"] or "Search fonts...",
        onTextChanged = function()
            scheduleFilterRefresh(tab)
        end,
    })
    searchBox:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    tab.searchBox = searchBox

    local favsBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_FAVORITES"] or "Favorites",
        height = 22,
        minWidth = 64,
    })
    favsBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    bindBarButtonMouse(favsBtn)
    favsBtn:SetScript("OnClick", function()
        FB:SetFavoritesOnly(not FB.favoritesOnly)
        tab.selectedFontName = nil
        tab.selectedListIndex = nil
        Addon.UI.FontTab_RefreshList(tab)
        if FB:GetFilteredCount() > 0 then
            applyFontSelection(tab, 1)
        else
            Addon.UI.FontTab_UpdatePreview(tab)
            Addon.UI.FontTab_UpdateDetails(tab)
            Addon.UI.FontTab_UpdateCopyButtons(tab)
        end
        refreshToolbarState(tab)
    end)
    tab.favsBtn = favsBtn

    local bookmarkBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_BOOKMARK"] or "Bookmark",
        height = 22,
        minWidth = 64,
    })
    bookmarkBtn:SetPoint("LEFT", favsBtn, "RIGHT", 4, 0)
    bindBarButtonMouse(bookmarkBtn)
    bookmarkBtn:SetScript("OnClick", function()
        if not tab.selectedFontName then return end
        local added = FB:ToggleBookmark(tab.selectedFontName)
        local name = tab.selectedFontName
        if added then
            Addon:Print((L["MSG_BOOKMARKED"] or "Bookmarked: {name}"):gsub("{name}", name))
        else
            Addon:Print((L["MSG_REMOVED_BOOKMARK"] or "Removed: {name}"):gsub("{name}", name))
        end
        if FB.favoritesOnly then
            FB:RebuildFiltered()
            Addon.UI.FontTab_RefreshList(tab)
            if FB:GetFilteredCount() > 0 then
                applyFontSelection(tab, 1)
            else
                tab.selectedFontName = nil
                Addon.UI.FontTab_UpdatePreview(tab)
                Addon.UI.FontTab_UpdateDetails(tab)
            end
        else
            Addon.UI.FontTab_UpdateListRows(tab)
            Addon.UI.FontTab_UpdateDetails(tab)
        end
        refreshToolbarState(tab)
    end)
    tab.bookmarkBtn = bookmarkBtn

    local compareBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["FONT_BTN_COMPARE"] or "Compare",
        height = 22,
        minWidth = 64,
    })
    compareBtn:SetPoint("LEFT", bookmarkBtn, "RIGHT", 4, 0)
    bindBarButtonMouse(compareBtn)
    compareBtn:SetScript("OnClick", function()
        tab.compareMode = not tab.compareMode
        Addon.UI.FontTab_LayoutPreview(tab)
        Addon.UI.FontTab_UpdatePreview(tab)
        refreshToolbarState(tab)
    end)
    tab.compareBtn = compareBtn

    -- Left panel: virtualized font list
    local savedW = Addon.db and Addon.db.fontBrowserLeftPaneWidth
    local initW = LEFT_DEFAULT
    if type(savedW) == "number" and savedW >= LEFT_MIN then
        initW = savedW
    end

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 280, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(initW)
    self:StyleContentPanel(leftPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(leftPanel, { name = "FontBrowserListScroll" })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    listScroll:HookScript("OnSizeChanged", function(_, w)
        listContent:SetWidth(w)
        Addon.UI.FontTab_RefreshList(tab)
    end)
    listScroll:SetScript("OnVerticalScroll", function()
        Addon.UI.FontTab_UpdateListRows(tab)
    end)
    tab.listScroll = listScroll

    tab.listButtons = {}
    for i = 1, NUM_ROWS do
        local btn = CreateFrame("Button", nil, listContent)
        btn:SetHeight(ROW_H)
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i - 1) * ROW_H)
        btn:SetPoint("RIGHT", listContent, "RIGHT", -2, 0)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)
        btn:SetScript("OnClick", function(b)
            if b._entryIndex then
                applyFontSelection(tab, b._entryIndex)
                refreshToolbarState(tab)
            end
        end)
        styleListButtonText(btn)
        tab.listButtons[i] = btn
    end

    -- Right panel
    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    self:StyleContentPanel(rightPanel)

    OneWoW_GUI:CreateVerticalPaneResizer({
        parent = tab,
        leftPanel = leftPanel,
        rightPanel = rightPanel,
        dividerWidth = DIV_W,
        leftMinWidth = LEFT_MIN,
        rightMinWidth = RIGHT_MIN,
        splitPadding = DIV_W + 10,
        bottomOuterInset = 5,
        rightOuterInset = 5,
        resizeCap = DU.MAIN_FRAME_RESIZE_CAP or 0.95,
        mainFrame = Addon.UI and Addon.UI.mainFrame,
        onWidthChanged = function(w)
            if Addon.db then Addon.db.fontBrowserLeftPaneWidth = w end
        end,
    })

    -- Right panel: font name header + preview background color swatch
    local swatchSize = DU.FONT_BROWSER_PREVIEW_SWATCH_SIZE or 18
    local previewBgSwatch = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    previewBgSwatch:SetSize(swatchSize, swatchSize)
    previewBgSwatch:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -8, -6)
    previewBgSwatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    previewBgSwatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    previewBgSwatch.tab = tab

    tab.nameText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tab.nameText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 8, -6)
    tab.nameText:SetPoint("RIGHT", previewBgSwatch, "LEFT", -4, 0)
    tab.nameText:SetJustifyH("LEFT")
    tab.nameText:SetWordWrap(true)
    if tab.nameText.SetMaxLines then tab.nameText:SetMaxLines(2) end
    tab.nameText:SetText("")
    tab.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    -- Preview frame (clips children for clean layout)
    local previewClip = CreateFrame("Frame", nil, rightPanel)
    previewClip:SetPoint("TOP", tab.nameText, "BOTTOM", 0, -6)
    previewClip:SetPoint("LEFT", rightPanel, "LEFT", 8, 0)
    previewClip:SetPoint("RIGHT", rightPanel, "RIGHT", -8, 0)
    previewClip:SetHeight(PREVIEW_BG_H)
    previewClip:SetClipsChildren(true)
    tab.previewClip = previewClip

    -- Preview background (child of clip so it draws behind font strings)
    local previewBg = previewClip:CreateTexture(nil, "BACKGROUND")
    previewBg:SetAllPoints(previewClip)
    local r, g, b, a = getEffectivePreviewBg()
    previewBg:SetColorTexture(r, g, b, a)
    tab.previewBg = previewBg

    -- Swatch: UpdateColor updates both swatch and preview texture
    previewBgSwatch.UpdateColor = function(self)
        local rr, gg, bb, aa = getEffectivePreviewBg()
        self:SetBackdropColor(rr, gg, bb, 1)
        if self.tab and self.tab.previewBg then
            self.tab.previewBg:SetColorTexture(rr, gg, bb, aa)
        end
    end
    previewBgSwatch:SetScript("OnClick", function()
        local r, g, b, a = getEffectivePreviewBg()
        local prev = Addon.db and Addon.db.fontBrowserPreviewBg
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, opacity = a, hasOpacity = true,
            swatchFunc = function()
                if not Addon.db then return end
                local rr, gg, bb = ColorPickerFrame:GetColorRGB()
                local oo = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or ColorPickerFrame.opacity or 1
                Addon.db.fontBrowserPreviewBg = { rr, gg, bb, oo }
                previewBgSwatch:UpdateColor()
            end,
            opacityFunc = function()
                if not Addon.db then return end
                local rr, gg, bb = ColorPickerFrame:GetColorRGB()
                local oo = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or ColorPickerFrame.opacity or 1
                Addon.db.fontBrowserPreviewBg = { rr, gg, bb, oo }
                previewBgSwatch:UpdateColor()
            end,
            cancelFunc = function()
                if Addon.db then Addon.db.fontBrowserPreviewBg = prev end
                previewBgSwatch:UpdateColor()
            end,
        })
    end)
    previewBgSwatch:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            if Addon.db then Addon.db.fontBrowserPreviewBg = nil end
            previewBgSwatch:UpdateColor()
        end
    end)
    previewBgSwatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["FONT_PREVIEW_BG_SWATCH"] or "Preview background (click to change, right-click to reset)", 1, 1, 1, nil, true)
        GameTooltip:Show()
    end)
    previewBgSwatch:SetScript("OnLeave", function() GameTooltip_Hide() end)
    previewBgSwatch:UpdateColor()

    -- Template preview (compare mode left half)
    tab.templateLabel = previewClip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.templateLabel:SetPoint("TOPLEFT", previewClip, "TOPLEFT", 4, -2)
    tab.templateLabel:SetText(L["FONT_COMPARE_TEMPLATE"] or "Template")
    tab.templateLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    tab.templateLabel:Hide()

    tab.templateFS = previewClip:CreateFontString(nil, "ARTWORK")
    tab.templateFS:Hide()

    -- Preview label (compare mode right half)
    tab.previewLabel = previewClip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.previewLabel:SetText(L["FONT_COMPARE_PREVIEW"] or "Preview")
    tab.previewLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    tab.previewLabel:Hide()

    -- Main preview font string
    tab.previewFS = previewClip:CreateFontString(nil, "ARTWORK")
    tab.previewFS:SetFontObject(GameFontNormal)
    tab.previewFS:SetText(L["FONT_MSG_SELECT_FONT"] or "Select a font to preview")
    tab.previewFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    tab.previewFS:SetWordWrap(true)

    -- Initial layout (non-compare)
    function Addon.UI.FontTab_LayoutPreview(t)
        if t.compareMode then
            t.templateFS:ClearAllPoints()
            t.templateFS:SetPoint("TOPLEFT", t.previewClip, "TOPLEFT", 4, -14)
            t.templateFS:SetPoint("BOTTOMRIGHT", t.previewClip, "BOTTOM", -2, 2)
            t.templateFS:SetWordWrap(true)

            t.previewFS:ClearAllPoints()
            t.previewFS:SetPoint("TOPLEFT", t.previewClip, "TOP", 2, -14)
            t.previewFS:SetPoint("BOTTOMRIGHT", t.previewClip, "BOTTOMRIGHT", -4, 2)

            t.templateLabel:ClearAllPoints()
            t.templateLabel:SetPoint("TOPLEFT", t.previewClip, "TOPLEFT", 4, -2)
            t.previewLabel:ClearAllPoints()
            t.previewLabel:SetPoint("TOPLEFT", t.previewClip, "TOP", 2, -2)
        else
            t.previewFS:ClearAllPoints()
            t.previewFS:SetPoint("TOPLEFT", t.previewClip, "TOPLEFT", 4, -4)
            t.previewFS:SetPoint("BOTTOMRIGHT", t.previewClip, "BOTTOMRIGHT", -4, 2)
        end
    end
    Addon.UI.FontTab_LayoutPreview(tab)

    -- Preview border
    local border = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    border:SetPoint("TOPLEFT", previewClip, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", previewClip, "BOTTOMRIGHT", 1, -1)
    border:SetFrameLevel((rightPanel:GetFrameLevel() or 0) + 2)
    border:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    border:SetBackdropColor(0, 0, 0, 0)
    border:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    -- Workspace controls area (between preview and info panel)
    local wsFrame = CreateFrame("Frame", nil, rightPanel)
    wsFrame:SetPoint("TOPLEFT", previewClip, "BOTTOMLEFT", 0, -6)
    wsFrame:SetPoint("RIGHT", rightPanel, "RIGHT", -8, 0)

    -- Vertical layout: sample at top, six middle rows (Spacing/Alpha, Size, Text, Shadow, Shadow Offset), widget+reset at bottom.
    local WS_BOTTOM_PAD = 8
    local hSampleRow = 24
    local hMidRow = 22
    local hWidgetRow = 24
    local gapBase = 8
    local gap = gapBase + floor((WS_EXTRA_H or 0) / 6 + 0.5)
    local wsHeight = WS_BOTTOM_PAD + hSampleRow + 6 * gap + 5 * hMidRow + hWidgetRow
    local ySpacingAlpha = -(hSampleRow + gap)
    local ySize = -(hSampleRow + hMidRow + 2 * gap)
    local yText = -(hSampleRow + 2 * hMidRow + 3 * gap)
    local yShad = -(hSampleRow + 3 * hMidRow + 4 * gap)
    local yShadOff = -(hSampleRow + 4 * hMidRow + 5 * gap)

    -- Sample text row: presets anchored to wsFrame right so edit uses remaining width
    local sampleEdit
    local sampleLabel = createWorkspaceLabel(wsFrame, L["FONT_LABEL_SAMPLE_TEXT"] or "Sample:", 0, WS_LABEL_COL)

    local presetNum = OneWoW_GUI:CreateFitTextButton(wsFrame, {
        text = L["FONT_SAMPLE_NUMBERS"] or "0-9",
        height = 20,
        minWidth = 36,
    })
    presetNum:SetPoint("TOPRIGHT", wsFrame, "TOPRIGHT", 0, 0)
    presetNum:SetScript("OnClick", function()
        tab.sampleText = "0123456789\n1,234,567.89\n$99.99  100%"
        sampleEdit:SetText(tab.sampleText)
        Addon.UI.FontTab_UpdatePreview(tab)
    end)

    local presetLong = OneWoW_GUI:CreateFitTextButton(wsFrame, {
        text = L["FONT_SAMPLE_LONG"] or "Pangram",
        height = 20,
        minWidth = 48,
    })
    presetLong:SetPoint("RIGHT", presetNum, "LEFT", -3, 0)
    presetLong:SetPoint("TOP", presetNum, "TOP", 0, 0)
    presetLong:SetScript("OnClick", function()
        tab.sampleText = SAMPLE_TEXT_DEFAULT
        sampleEdit:SetText(tab.sampleText)
        Addon.UI.FontTab_UpdatePreview(tab)
    end)

    local presetLatin = OneWoW_GUI:CreateFitTextButton(wsFrame, {
        text = L["FONT_SAMPLE_LATIN"] or "Abc 123",
        height = 20,
        minWidth = 48,
    })
    presetLatin:SetPoint("RIGHT", presetLong, "LEFT", -3, 0)
    presetLatin:SetPoint("TOP", presetNum, "TOP", 0, 0)
    presetLatin:SetScript("OnClick", function()
        tab.sampleText = "ABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789"
        sampleEdit:SetText(tab.sampleText)
        Addon.UI.FontTab_UpdatePreview(tab)
    end)

    sampleEdit = CreateFrame("EditBox", nil, wsFrame, "BackdropTemplate")
    sampleEdit:SetHeight(22)
    sampleEdit:SetPoint("TOPLEFT", wsFrame, "TOPLEFT", WS_LABEL_COL + WS_LABEL_GAP, 2)
    sampleEdit:SetPoint("RIGHT", presetLatin, "LEFT", -4, 0)
    sampleEdit:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    sampleEdit:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    sampleEdit:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    sampleEdit:SetFontObject(GameFontNormalSmall)
    sampleEdit:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    sampleEdit:SetAutoFocus(false)
    sampleEdit:SetTextInsets(3, 3, 0, 0)
    sampleEdit:SetText("")
    sampleEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sampleEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local text = strtrim(self:GetText())
        if text ~= "" then
            tab.sampleText = text
        else
            tab.sampleText = SAMPLE_TEXT_DEFAULT
        end
        Addon.UI.FontTab_UpdatePreview(tab)
    end)

    -- Spacing + Alpha row
    local spacingAlphaLabel = createWorkspaceLabel(wsFrame, L["FONT_LABEL_SPACING"] or "Spacing:", ySpacingAlpha, WS_LABEL_COL)
    local spacingEdit = createMiniEdit(wsFrame, 32)
    spacingEdit:SetPoint("LEFT", spacingAlphaLabel, "RIGHT", WS_LABEL_GAP, 0)
    spacingEdit:SetText("0")
    spacingEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.spacingEdit = spacingEdit

    local alphaLabel = createMiniLabel(wsFrame, L["FONT_LABEL_ALPHA"] or "Alpha:")
    alphaLabel:SetPoint("LEFT", spacingEdit, "RIGHT", 12, 0)
    local alphaEdit = createMiniEdit(wsFrame, 36)
    alphaEdit:SetPoint("LEFT", alphaLabel, "RIGHT", 4, 0)
    alphaEdit:SetText("1.00")
    alphaEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.alphaEdit = alphaEdit

    -- Size + Flags row
    local sizeLabel = createWorkspaceLabel(wsFrame, L["FONT_LABEL_SIZE"] or "Size:", ySize, WS_LABEL_COL)

    local sizeEdit = createMiniEdit(wsFrame, 40)
    sizeEdit:SetPoint("LEFT", sizeLabel, "RIGHT", WS_LABEL_GAP, 0)
    sizeEdit:SetText("12")
    sizeEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        applyWorkspaceOverrides(tab)
    end)
    tab.sizeEdit = sizeEdit

    local flagsLabel = createMiniLabel(wsFrame, L["FONT_LABEL_FLAGS"] or "Flags:")
    flagsLabel:SetPoint("LEFT", sizeEdit, "RIGHT", 12, 0)

    local outlineBtn = OneWoW_GUI:CreateFitTextButton(wsFrame, { text = L["FONT_FLAG_OUTLINE"] or "OUTLINE", height = 18, minWidth = 54 })
    outlineBtn:SetPoint("LEFT", flagsLabel, "RIGHT", 4, 0)
    outlineBtn._barActive = false
    bindBarButtonMouse(outlineBtn)
    outlineBtn:SetScript("OnClick", function(self)
        self._barActive = not self._barActive
        if self._barActive and tab.thickBtn then
            tab.thickBtn._barActive = false
            paintBarButton(tab.thickBtn)
        end
        paintBarButton(self)
        applyWorkspaceOverrides(tab)
    end)
    tab.outlineBtn = outlineBtn

    local thickBtn = OneWoW_GUI:CreateFitTextButton(wsFrame, { text = L["FONT_FLAG_THICK"] or "THICK", height = 18, minWidth = 42 })
    thickBtn:SetPoint("LEFT", outlineBtn, "RIGHT", 3, 0)
    thickBtn._barActive = false
    bindBarButtonMouse(thickBtn)
    thickBtn:SetScript("OnClick", function(self)
        self._barActive = not self._barActive
        if self._barActive and tab.outlineBtn then
            tab.outlineBtn._barActive = false
            paintBarButton(tab.outlineBtn)
        end
        paintBarButton(self)
        applyWorkspaceOverrides(tab)
    end)
    tab.thickBtn = thickBtn

    local monoBtn = OneWoW_GUI:CreateFitTextButton(wsFrame, { text = L["FONT_FLAG_MONO"] or "MONO", height = 18, minWidth = 40 })
    monoBtn:SetPoint("LEFT", thickBtn, "RIGHT", 3, 0)
    monoBtn._barActive = false
    bindBarButtonMouse(monoBtn)
    monoBtn:SetScript("OnClick", function(self)
        self._barActive = not self._barActive
        paintBarButton(self)
        applyWorkspaceOverrides(tab)
    end)
    tab.monoBtn = monoBtn

    -- Text Color row: R G B A
    local textColorLabel = createWorkspaceLabel(wsFrame, L["FONT_LABEL_TEXT_COLOR"] or "Text:", yText, WS_LABEL_COL)

    local textRLabel = createMiniLabel(wsFrame, "R")
    textRLabel:SetPoint("LEFT", textColorLabel, "RIGHT", WS_LABEL_GAP, 0)
    local textREdit = createMiniEdit(wsFrame, 36)
    textREdit:SetPoint("LEFT", textRLabel, "RIGHT", 2, 0)
    textREdit:SetText("1.00")
    textREdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.textREdit = textREdit

    local textGLabel = createMiniLabel(wsFrame, "G")
    textGLabel:SetPoint("LEFT", textREdit, "RIGHT", 4, 0)
    local textGEdit = createMiniEdit(wsFrame, 36)
    textGEdit:SetPoint("LEFT", textGLabel, "RIGHT", 2, 0)
    textGEdit:SetText("1.00")
    textGEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.textGEdit = textGEdit

    local textBLabel = createMiniLabel(wsFrame, "B")
    textBLabel:SetPoint("LEFT", textGEdit, "RIGHT", 4, 0)
    local textBEdit = createMiniEdit(wsFrame, 36)
    textBEdit:SetPoint("LEFT", textBLabel, "RIGHT", 2, 0)
    textBEdit:SetText("1.00")
    textBEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.textBEdit = textBEdit

    local textALabel = createMiniLabel(wsFrame, "A")
    textALabel:SetPoint("LEFT", textBEdit, "RIGHT", 4, 0)
    local textAEdit = createMiniEdit(wsFrame, 36)
    textAEdit:SetPoint("LEFT", textALabel, "RIGHT", 2, 0)
    textAEdit:SetText("1.00")
    textAEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.textAEdit = textAEdit

    -- Shadow Color row: R G B A
    local shadColorLabel = createWorkspaceLabel(wsFrame, L["FONT_LABEL_SHADOW_COLOR"] or "Shadow:", yShad, WS_LABEL_COL)

    local shadRLabel = createMiniLabel(wsFrame, "R")
    shadRLabel:SetPoint("LEFT", shadColorLabel, "RIGHT", WS_LABEL_GAP, 0)
    local shadREdit = createMiniEdit(wsFrame, 36)
    shadREdit:SetPoint("LEFT", shadRLabel, "RIGHT", 2, 0)
    shadREdit:SetText("0.00")
    shadREdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.shadREdit = shadREdit

    local shadGLabel = createMiniLabel(wsFrame, "G")
    shadGLabel:SetPoint("LEFT", shadREdit, "RIGHT", 4, 0)
    local shadGEdit = createMiniEdit(wsFrame, 36)
    shadGEdit:SetPoint("LEFT", shadGLabel, "RIGHT", 2, 0)
    shadGEdit:SetText("0.00")
    shadGEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.shadGEdit = shadGEdit

    local shadBLabel = createMiniLabel(wsFrame, "B")
    shadBLabel:SetPoint("LEFT", shadGEdit, "RIGHT", 4, 0)
    local shadBEdit = createMiniEdit(wsFrame, 36)
    shadBEdit:SetPoint("LEFT", shadBLabel, "RIGHT", 2, 0)
    shadBEdit:SetText("0.00")
    shadBEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.shadBEdit = shadBEdit

    local shadALabel = createMiniLabel(wsFrame, "A")
    shadALabel:SetPoint("LEFT", shadBEdit, "RIGHT", 4, 0)
    local shadAEdit = createMiniEdit(wsFrame, 36)
    shadAEdit:SetPoint("LEFT", shadALabel, "RIGHT", 2, 0)
    shadAEdit:SetText("1.00")
    shadAEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.shadAEdit = shadAEdit

    -- Shadow Offset row (X, Y)
    local shadOffLabel = createWorkspaceLabel(wsFrame, L["FONT_LABEL_SHADOW_OFFSET"] or "Shadow Offset:", yShadOff, WS_LABEL_COL)

    local xLabel = createMiniLabel(wsFrame, "X")
    xLabel:SetPoint("LEFT", shadOffLabel, "RIGHT", WS_LABEL_GAP, 0)
    local shadXEdit = createMiniEdit(wsFrame, 32)
    shadXEdit:SetPoint("LEFT", xLabel, "RIGHT", 2, 0)
    shadXEdit:SetText("0")
    shadXEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.shadXEdit = shadXEdit

    local yLabel = createMiniLabel(wsFrame, "Y")
    yLabel:SetPoint("LEFT", shadXEdit, "RIGHT", 4, 0)
    local shadYEdit = createMiniEdit(wsFrame, 32)
    shadYEdit:SetPoint("LEFT", yLabel, "RIGHT", 2, 0)
    shadYEdit:SetText("0")
    shadYEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); applyWorkspaceOverrides(tab) end)
    tab.shadYEdit = shadYEdit

    -- Size preset (bottom row) + Reset right-aligned. Label in fixed column, BOTTOM-anchored to match dropdown.
    local resetBtnH = 18
    local rowMidAboveBottom = WS_BOTTOM_PAD + hWidgetRow / 2
    local widgetLabel = createMiniLabel(wsFrame, L["FONT_LABEL_WIDGET_SIZE"] or "Size preset:")
    widgetLabel:SetJustifyH("RIGHT")
    widgetLabel:SetJustifyV("MIDDLE")
    widgetLabel:SetPoint("TOPLEFT", wsFrame, "BOTTOMLEFT", 0, WS_BOTTOM_PAD + hWidgetRow)
    widgetLabel:SetPoint("BOTTOMRIGHT", wsFrame, "BOTTOMLEFT", WS_LABEL_COL, WS_BOTTOM_PAD)

    local resetBtn = OneWoW_GUI:CreateFitTextButton(wsFrame, {
        text = L["FONT_BTN_RESET"] or "Reset All",
        height = resetBtnH,
        minWidth = 48,
    })
    resetBtn:SetPoint("RIGHT", wsFrame, "BOTTOMRIGHT", 0, 0)
    resetBtn:SetPoint("BOTTOM", wsFrame, "BOTTOM", 0, rowMidAboveBottom - resetBtnH / 2)

    local widgetSizeDrop = OneWoW_GUI:CreateDropdown(wsFrame, { width = 160, height = hWidgetRow, text = "" })
    widgetSizeDrop:SetPoint("BOTTOM", wsFrame, "BOTTOM", 0, WS_BOTTOM_PAD)
    widgetSizeDrop:SetPoint("LEFT", wsFrame, "BOTTOMLEFT", WS_LABEL_COL + WS_LABEL_GAP, 0)
    widgetSizeDrop:SetPoint("RIGHT", resetBtn, "LEFT", -8, 0)
    widgetSizeDrop:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["FONT_WIDGET_SIZE_DISCLAIMER"] or "Approximate point sizes; not Blizzard's official mapping.", 1, 1, 1, nil, true)
        GameTooltip:Show()
    end)
    widgetSizeDrop:SetScript("OnLeave", GameTooltip_Hide)

    OneWoW_GUI:AttachFilterMenu(widgetSizeDrop, {
        searchable = false,
        menuHeight = 196,
        getActiveValue = function()
            return tab.widgetPresetActiveValue or "none"
        end,
        buildItems = function()
            local items = {}
            for enumVal = 0, 4 do
                tinsert(items, {
                    value = tostring(enumVal),
                    text = FB.WIDGET_SIZE_LABELS[enumVal] or tostring(enumVal),
                })
            end
            tinsert(items, { value = "none", text = L["FONT_WIDGET_SIZE_NONE"] or "None" })
            return items
        end,
        onSelect = function(value)
            tab.widgetPresetActiveValue = value
            refreshWidgetSizeDropdownLabel(tab)
            if value ~= "none" then
                local n = tonumber(value)
                if n ~= nil then
                    local pt = FB.WIDGET_SIZE_PT[n] or 12
                    tab.sizeEdit:SetText(tostring(pt))
                    applyWorkspaceOverrides(tab)
                end
            end
        end,
    })

    tab.widgetSizeDropdown = widgetSizeDrop
    refreshWidgetSizeDropdownLabel(tab)

    resetBtn:SetScript("OnClick", function()
        tab.overrides = {}
        tab.widgetPresetActiveValue = "none"
        refreshWidgetSizeDropdownLabel(tab)
        if tab.selectedFontName then
            Addon.UI.FontTab_UpdateWorkspaceFromFont(tab)
        end
        Addon.UI.FontTab_UpdatePreview(tab)
        Addon.UI.FontTab_UpdateDetails(tab)
    end)

    wsFrame:SetHeight(wsHeight)

    -- Info/details panel (scrollable, below workspace)
    local infoPanel = OneWoW_GUI:CreateFrame(rightPanel, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    infoPanel:ClearAllPoints()
    infoPanel:SetPoint("TOPLEFT", wsFrame, "BOTTOMLEFT", 0, -4)
    infoPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -6, 36)
    self:StyleContentPanel(infoPanel)

    local infoScroll, infoContent = OneWoW_GUI:CreateScrollFrame(infoPanel, { name = "FontBrowserInfoScroll" })
    infoScroll:ClearAllPoints()
    infoScroll:SetPoint("TOPLEFT", 4, -4)
    infoScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    infoScroll:HookScript("OnSizeChanged", function(_, w)
        infoContent:SetWidth(w)
    end)
    tab.infoScroll = infoScroll

    tab.infoText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.infoText:SetPoint("TOPLEFT", 2, -2)
    tab.infoText:SetPoint("RIGHT", infoContent, "RIGHT", -2, 0)
    tab.infoText:SetJustifyH("LEFT")
    tab.infoText:SetText("")
    tab.infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    -- Copy row: shared label + action buttons (match LibCopyPaste title: GameFontNormalLarge + gold)
    local copyRowLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    copyRowLabel:SetText(L["FONT_COPY_ROW_LABEL"] or "Copy:")
    copyRowLabel:SetTextColor(1, 0.82, 0)
    copyRowLabel:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 6, 8)

    local copyNameBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["FONT_BTN_COPY_NAME"] or "Name",
        height = 22,
        minWidth = 44,
    })
    copyNameBtn:SetPoint("LEFT", copyRowLabel, "RIGHT", 6, -5)
    copyNameBtn:SetPoint("BOTTOM", rightPanel, "BOTTOM", 0, 6)
    copyNameBtn:SetScript("OnClick", function()
        if tab.selectedFontName then
            Addon:CopyToClipboard(FB:GenerateCopyName(tab.selectedFontName))
        end
    end)
    tab.copyNameBtn = copyNameBtn

    local copySetFontBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["FONT_BTN_COPY_SET_FONT"] or "SetFont",
        height = 22,
        minWidth = 52,
    })
    copySetFontBtn:SetPoint("LEFT", copyNameBtn, "RIGHT", 4, 0)
    copySetFontBtn:SetScript("OnClick", function()
        if tab.selectedFontName then
            Addon:CopyToClipboard(FB:GenerateSetFont(tab.selectedFontName, getEffectiveOverrides(tab)))
        end
    end)
    tab.copySetFontBtn = copySetFontBtn

    local copySnippetBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["FONT_BTN_COPY_SNIPPET"] or "Snippet",
        height = 22,
        minWidth = 52,
    })
    copySnippetBtn:SetPoint("LEFT", copySetFontBtn, "RIGHT", 4, 0)
    copySnippetBtn:SetScript("OnClick", function()
        if tab.selectedFontName then
            Addon:CopyToClipboard(FB:GenerateSnippet(tab.selectedFontName, getEffectiveOverrides(tab)))
        end
    end)
    tab.copySnippetBtn = copySnippetBtn

    local copyCreateFontBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["FONT_BTN_COPY_CREATE_FONT"] or "CreateFont",
        height = 22,
        minWidth = 64,
    })
    copyCreateFontBtn:SetPoint("LEFT", copySnippetBtn, "RIGHT", 4, 0)
    copyCreateFontBtn:SetScript("OnClick", function()
        if tab.selectedFontName then
            Addon:CopyToClipboard(FB:GenerateCreateFont(tab.selectedFontName, getEffectiveOverrides(tab)))
        end
    end)
    tab.copyCreateFontBtn = copyCreateFontBtn

    -- OnShow handler: refresh name header with selection
    tab:SetScript("OnShow", function()
        FB:BuildCatalog()
        FB:SetFilterText(searchBox:GetSearchText())
        Addon.UI.FontTab_RefreshList(tab)
        if tab.selectedFontName then
            tab.nameText:SetText(tab.selectedFontName)
        end
        Addon.UI.FontTab_UpdateCopyButtons(tab)
        refreshToolbarState(tab)
    end)

    tab:SetScript("OnHide", function() end)

    -- Initial state
    Addon.UI.FontTab_RefreshList(tab)
    if FB:GetFilteredCount() > 0 then
        applyFontSelection(tab, 1)
    else
        Addon.UI.FontTab_UpdatePreview(tab)
        Addon.UI.FontTab_UpdateDetails(tab)
    end
    Addon.UI.FontTab_UpdateCopyButtons(tab)
    refreshToolbarState(tab)

    return tab
end

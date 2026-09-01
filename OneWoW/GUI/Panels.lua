local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local unpack = unpack
local tinsert = tinsert
local wipe = wipe

local Constants = OneWoW_GUI.Constants
local noop = OneWoW_GUI.noop

local _splitPanelCount = 0
local _dataTableCount = 0
local _dataRowCount = 0

function OneWoW_GUI:CreateDialog(config)
    config = config or {}
    local name = config.name
    local title = config.title or ""
    local width = config.width or 500
    local height = config.height or 400
    local strata = config.strata or "DIALOG"
    local movable = config.movable ~= false
    local escClose = config.escClose ~= false
    local showBrand = config.showBrand
    local titleIcon = config.titleIcon
    local titleHeight = config.titleHeight or Constants.GUI.TITLEBAR_HEIGHT
    local onClose = config.onClose
    local buttonDefs = config.buttons
    local showScrollFrame = config.showScrollFrame

    local frame = self:CreateFrame(UIParent, { name = name, width = width, height = height, backdrop = Constants.BACKDROP_INNER_NO_INSETS })
    frame:SetPoint("CENTER")
    frame:SetFrameStrata(strata)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    if movable then
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(myself) myself:StartMoving() end)
        frame:SetScript("OnDragStop", function(myself) myself:StopMovingOrSizing() end)
    end

    if escClose and name then
        tinsert(UISpecialFrames, name)
    end

    local result = { frame = frame, buttons = {} }

    local closeFunc = function()
        frame:Hide()
        if onClose then onClose(frame) end
    end

    local titleBarOpts = {
        title = title,
        height = titleHeight,
        onClose = closeFunc,
        showBrand = showBrand,
        factionTheme = config.factionTheme,
    }
    local titleBar = self:CreateTitleBar(frame, titleBarOpts)
    result.titleBar = titleBar

    if movable then
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
        titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    end

    if titleIcon then
        local icon = titleBar:CreateTexture(nil, "OVERLAY")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", titleBar, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
        icon:SetTexture(titleIcon)
        titleBar._titleText:ClearAllPoints()
        titleBar._titleText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    end

    local buttonRowHeight = 0
    if buttonDefs and #buttonDefs > 0 then
        buttonRowHeight = 28 + 10 + 10

        local divider = frame:CreateTexture(nil, "ARTWORK")
        divider:SetHeight(1)
        divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, buttonRowHeight)
        divider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, buttonRowHeight)
        divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local prevBtn
        for i = #buttonDefs, 1, -1 do
            local def = buttonDefs[i]
            local btn = self:CreateFitTextButton(frame, { text = def.text, height = 28, minWidth = 80 })
            if not prevBtn then
                btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
            else
                btn:SetPoint("RIGHT", prevBtn, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
            end

            if def.color then
                local cr, cg, cb = def.color[1], def.color[2], def.color[3]
                btn:SetBackdropColor(cr, cg, cb, 0.6)
                btn:SetScript("OnEnter", function(myself)
                    myself:SetBackdropColor(cr, cg, cb, 0.8)
                    myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                    myself.text:SetTextColor(1, 1, 1)
                end)
                btn:SetScript("OnLeave", function(myself)
                    myself:SetBackdropColor(cr, cg, cb, 0.6)
                    myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                    myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end)
            end

            if def.onClick then
                btn:SetScript("OnClick", function() def.onClick(frame) end)
            end

            result.buttons[i] = btn
            prevBtn = btn
        end
    end

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    contentFrame:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    if buttonRowHeight > 0 then
        contentFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, buttonRowHeight + 1)
        contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, buttonRowHeight + 1)
    else
        contentFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    result.contentFrame = contentFrame

    if showScrollFrame then
        local scrollFrame, scrollContent = self:CreateScrollFrame(contentFrame, {})
        result.scrollFrame = scrollFrame
        result.scrollContent = scrollContent
    end

    -- Auto-handle live font / font-size changes: this dialog lives on UIParent,
    -- outside the main window's rebuild, so register it as a font root. Callers
    -- with a measured stack can pass config.relayout to re-flow after re-fonting.
    self:RegisterFontRoot(frame, config.relayout)

    frame:Hide()
    return result
end

function OneWoW_GUI:CreateConfirmDialog(config)
    config = config or {}
    local headingText = config.title or ""
    local messageText = config.message or ""
    local dialogWidth = config.width or 420
    local checkboxConfig = config.checkbox
    local showBrand = config.showBrand ~= false
    local addonTitle = config.addonTitle or ""
    local titleBarHeight = Constants.GUI.TITLEBAR_HEIGHT

    local headingPad = 15
    local msgPad = 10
    local contentPadBottom = 10
    local btnRowHeight = 28 + 10 + 10
    local cbPadTop = 8
    local cbPadBottom = 8
    local headingBaseSize = 16
    local bodyBaseSize = 12
    local msgWidth = dialogWidth - 40

    local function measureTextHeight(text, baseSize, width, wordWrap)
        local fs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if width and width > 0 then
            fs:SetWidth(width)
            if wordWrap then
                fs:SetWordWrap(true)
                fs:SetNonSpaceWrap(false)
            end
        end
        OneWoW_GUI:SetFontBaseSize(fs, baseSize)
        OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), baseSize)
        fs:SetText(text or "")
        local h = fs:GetStringHeight()
        fs:Hide()
        fs:SetParent(nil)
        return h
    end

    local msgHeight = measureTextHeight(messageText, bodyBaseSize, msgWidth, true)
    local headingHeight = measureTextHeight(headingText, headingBaseSize, nil, false)

    local checkboxRow = 0
    if checkboxConfig then
        local labelGap = OneWoW_GUI:GetSpacing("XS")
        local labelMaxWidth = checkboxConfig.labelMaxWidth
        local labelWidth = labelMaxWidth
        if not labelWidth or labelWidth <= 0 then
            labelWidth = msgWidth - Constants.GUI.CHECKBOX_SIZE - labelGap
        end
        local cbLabelHeight = measureTextHeight(
            checkboxConfig.label or "",
            bodyBaseSize,
            labelWidth,
            checkboxConfig.wrap
        )
        local cbRowContent = math.max(Constants.GUI.CHECKBOX_SIZE, cbLabelHeight)
        checkboxRow = 1 + cbPadTop + cbRowContent + cbPadBottom
    end

    local contentHeight = headingPad + headingHeight + msgPad + msgHeight + contentPadBottom + checkboxRow
    local totalHeight = titleBarHeight + contentHeight + btnRowHeight + 2
    totalHeight = math.max(totalHeight, 140)

    local result = self:CreateDialog({
        name = config.name,
        title = addonTitle,
        width = dialogWidth,
        height = totalHeight,
        movable = false,
        escClose = true,
        showBrand = showBrand,
        factionTheme = config.factionTheme,
        onClose = config.onClose,
        buttons = config.buttons,
    })

    local headingLabel = result.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    OneWoW_GUI:SetFontBaseSize(headingLabel, 16)
    OneWoW_GUI:SafeSetFont(headingLabel, OneWoW_GUI:GetFont(), 16)
    headingLabel:SetPoint("TOP", result.contentFrame, "TOP", 0, -headingPad)
    headingLabel:SetText(headingText)
    headingLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    result.titleLabel = headingLabel

    local msgLabel = result.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(msgLabel, 12)
    OneWoW_GUI:SafeSetFont(msgLabel, OneWoW_GUI:GetFont(), 12)
    msgLabel:SetPoint("TOP", headingLabel, "BOTTOM", 0, -msgPad)
    msgLabel:SetWidth(msgWidth)
    msgLabel:SetWordWrap(true)
    msgLabel:SetNonSpaceWrap(false)
    msgLabel:SetText(messageText)
    msgLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    result.messageLabel = msgLabel

    if checkboxConfig then
        local cbDivider = result.contentFrame:CreateTexture(nil, "ARTWORK")
        cbDivider:SetHeight(1)
        cbDivider:SetPoint("TOPLEFT", result.contentFrame, "TOPLEFT", 10, -(headingPad + headingHeight + msgPad + msgHeight + contentPadBottom))
        cbDivider:SetPoint("TOPRIGHT", result.contentFrame, "TOPRIGHT", -10, -(headingPad + headingHeight + msgPad + msgHeight + contentPadBottom))
        cbDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local cb = self:CreateCheckbox(result.contentFrame, {
            label = checkboxConfig.label or "",
            labelMaxWidth = checkboxConfig.labelMaxWidth,
            wrap = checkboxConfig.wrap,
        })
        cb:SetPoint("TOPLEFT", cbDivider, "BOTTOMLEFT", 0, -cbPadTop)
        if cb.label then
            cb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        result.checkbox = cb
    end

    return result
end

-- Single shared dialog reused across calls; lazy-created on first invocation.
local _urlDialog
local _urlBox
local _urlInstructions

--- Show a small modal containing a copy-friendly editbox for `url`.
--- Reuses one shared dialog across calls. ESC closes (registered via `name`).
---@param title string Heading/title shown in the title bar (e.g. "Discord").
---@param url string URL to display in the editbox.
function OneWoW_GUI:ShowCopyURLDialog(title, url)
    title = title or ""
    url = url or ""

    if not _urlDialog then
        _urlDialog = self:CreateDialog({
            name = "OneWoW_GUI_CopyURLDialog",
            title = title,
            width = 400,
            height = 140,
            movable = false,
            escClose = true,
            showBrand = false,
            buttons = {
                { text = CLOSE, onClick = function(frame) frame:Hide() end },
            },
        })

        _urlInstructions = self:CreateFS(_urlDialog.contentFrame, 12)
        _urlInstructions:SetPoint("TOPLEFT", _urlDialog.contentFrame, "TOPLEFT", 15, -12)
        _urlInstructions:SetPoint("TOPRIGHT", _urlDialog.contentFrame, "TOPRIGHT", -15, -12)
        _urlInstructions:SetJustifyH("LEFT")
        _urlInstructions:SetText("Press Ctrl+C to copy:")
        _urlInstructions:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))

        _urlBox = self:CreateEditBox(_urlDialog.contentFrame, { height = 24 })
        _urlBox:SetPoint("TOPLEFT", _urlDialog.contentFrame, "TOPLEFT", 15, -36)
        _urlBox:SetPoint("TOPRIGHT", _urlDialog.contentFrame, "TOPRIGHT", -15, -36)
        _urlBox:SetAutoFocus(false)
        _urlBox:SetScript("OnEditFocusGained", function(myself)
            myself:HighlightText()
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        end)
        _urlBox:SetScript("OnEditFocusLost", function(myself)
            myself:HighlightText(0, 0)
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end)
        _urlBox:SetScript("OnMouseDown", function(myself)
            myself:SetFocus()
            myself:HighlightText()
        end)
        _urlBox:SetScript("OnEscapePressed", function(myself)
            myself:ClearFocus()
            _urlDialog.frame:Hide()
        end)
    end

    if _urlDialog.titleBar and _urlDialog.titleBar._titleText then
        _urlDialog.titleBar._titleText:SetText(title)
    end
    _urlBox:SetText(url)
    _urlBox:SetCursorPosition(0)

    _urlDialog.frame:Show()
    _urlBox:SetFocus()
    _urlBox:HighlightText()
end

-- Shared dialog + reusable row pool for ShowCopyLinksDialog.
local _linksDialog
local _linkRows = {}
local _LINK_ROW_H = 30

--- Show a modal listing one or more labeled, copy-friendly links.
--- Addons cannot write the OS clipboard, so each URL sits in a highlighted
--- editbox: clicking it (or focusing) selects the text for Ctrl+C. An optional
--- per-link action button is shown to the right (used for e.g. "Open Quest").
---@param title string Title bar text.
---@param instructions string|nil Line shown above the links.
---@param links table[] Array of { label=string, url=string, action={ text=string, onClick=fun() }|nil }.
function OneWoW_GUI:ShowCopyLinksDialog(title, instructions, links)
    title = title or ""
    links = links or {}

    if not _linksDialog then
        _linksDialog = self:CreateDialog({
            name = "OneWoW_GUI_CopyLinksDialog",
            title = title,
            width = 540,
            height = 200,
            movable = true,
            escClose = true,
            showBrand = false,
            buttons = {
                { text = CLOSE, onClick = function(frame) frame:Hide() end },
            },
        })
        _linksDialog._instr = self:CreateFS(_linksDialog.contentFrame, 12)
        _linksDialog._instr:SetPoint("TOPLEFT", _linksDialog.contentFrame, "TOPLEFT", 15, -12)
        _linksDialog._instr:SetPoint("TOPRIGHT", _linksDialog.contentFrame, "TOPRIGHT", -15, -12)
        _linksDialog._instr:SetJustifyH("LEFT")
        _linksDialog._instr:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    end

    if _linksDialog.titleBar and _linksDialog.titleBar._titleText then
        _linksDialog.titleBar._titleText:SetText(title)
    end
    _linksDialog._instr:SetText(instructions or "Click a link to highlight it, then press Ctrl+C to copy:")

    for _, row in ipairs(_linkRows) do row.frame:Hide() end

    local topOffset = -36
    for i, link in ipairs(links) do
        local row = _linkRows[i]
        if not row then
            row = {}
            row.frame = CreateFrame("Frame", nil, _linksDialog.contentFrame)
            row.frame:SetHeight(_LINK_ROW_H)

            row.label = self:CreateFS(row.frame, 12)
            row.label:SetPoint("LEFT", row.frame, "LEFT", 0, 0)
            row.label:SetWidth(64)
            row.label:SetJustifyH("LEFT")

            row.box = self:CreateEditBox(row.frame, { height = 24 })
            row.box:SetAutoFocus(false)
            row.box:SetScript("OnEditFocusGained", function(myself) myself:HighlightText() end)
            row.box:SetScript("OnMouseDown", function(myself) myself:SetFocus(); myself:HighlightText() end)
            row.box:SetScript("OnEscapePressed", function(myself) myself:ClearFocus() end)

            row.action = self:CreateButton(row.frame, { text = "", width = 96, height = 22 })

            _linkRows[i] = row
        end

        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", _linksDialog.contentFrame, "TOPLEFT", 15, topOffset)
        row.frame:SetPoint("TOPRIGHT", _linksDialog.contentFrame, "TOPRIGHT", -15, topOffset)
        row.frame:Show()

        row.label:SetText((link.label or "") .. (link.label and link.label ~= "" and ":" or ""))

        if link.action and link.action.onClick then
            row.action.text:SetText(link.action.text or "")
            row.action:SetScript("OnClick", function() link.action.onClick() end)
            row.action:Show()
            row.box:ClearAllPoints()
            row.box:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
            row.box:SetPoint("RIGHT", row.action, "LEFT", -8, 0)
            row.action:ClearAllPoints()
            row.action:SetPoint("RIGHT", row.frame, "RIGHT", 0, 0)
        else
            row.action:Hide()
            row.box:ClearAllPoints()
            row.box:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
            row.box:SetPoint("RIGHT", row.frame, "RIGHT", 0, 0)
        end

        row.box:SetText(link.url or "")
        row.box:SetCursorPosition(0)

        topOffset = topOffset - (_LINK_ROW_H + 4)
    end

    _linksDialog.frame:SetHeight(70 + (#links * (_LINK_ROW_H + 4)) + 36)
    _linksDialog.frame:Show()
end

function OneWoW_GUI:CreateScrollFrame(parent, options)
    options = options or {}
    local name = options.name
    local width = options.width
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    self:ApplyScrollBarStyle(scrollFrame.ScrollBar, scrollFrame, -2)

    local contentName = name and (name .. "Content") or nil
    local content = CreateFrame("Frame", contentName, scrollFrame)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    if width then
        content:SetWidth(width - 32)
        return scrollFrame, content
    end

    local layoutRightInset = options.layoutRightInset
    if layoutRightInset and layoutRightInset > 0 then
        local function syncOuterFullWidth()
            local w = scrollFrame:GetWidth()
            content:SetWidth(math.max(1, w))
        end
        local layoutName = name and (name .. "Layout") or nil
        local layout = CreateFrame("Frame", layoutName, content)
        layout:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        local function syncLayoutInset(shown)
            local inset = shown and layoutRightInset or 0
            layout:ClearAllPoints()
            layout:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            layout:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -inset, 0)
        end
        scrollFrame._oneWoWOnScrollBarShown = syncLayoutInset
        scrollFrame:HookScript("OnSizeChanged", syncOuterFullWidth)
        scrollFrame:HookScript("OnShow", syncOuterFullWidth)
        syncOuterFullWidth()
        local sb = scrollFrame.ScrollBar
        syncLayoutInset(sb and sb:IsShown() and not sb._oneWoWAlwaysHidden)
        return scrollFrame, layout
    end

    local function scrollChildGutter()
        local sb = scrollFrame.ScrollBar
        if sb and sb:IsShown() and not sb._oneWoWAlwaysHidden then
            return Constants.GUI.SCROLLBAR_CONTENT_GUTTER
        end
        return 0
    end
    local function syncScrollChildWidth()
        local w = scrollFrame:GetWidth()
        content:SetWidth(math.max(1, w - scrollChildGutter()))
    end
    scrollFrame._oneWoWOnScrollBarShown = function()
        syncScrollChildWidth()
    end
    scrollFrame:HookScript("OnSizeChanged", syncScrollChildWidth)
    scrollFrame:HookScript("OnShow", syncScrollChildWidth)
    syncScrollChildWidth()

    return scrollFrame, content
end

-- CreateVirtualizedList / CreateVirtualizer live in GUI/Virtualizer.lua
-- (loaded immediately after this file).

function OneWoW_GUI:CreateSplitPanel(parent, options)
    local panelGap = Constants.GUI.PANEL_GAP or 10

    local backdrop = Constants.BACKDROP_INNER_NO_INSETS

    options = options or {}
    local showSearch = options.showSearch
    local hideTitles = options.hideTitles and true or false

    _splitPanelCount = _splitPanelCount + 1
    local uid = _splitPanelCount

    local listPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
    listPanel:SetWidth(Constants.GUI.LEFT_PANEL_WIDTH)
    listPanel:SetBackdrop(backdrop)
    listPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    listPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local listTitle = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(listTitle, 12)
    OneWoW_GUI:SafeSetFont(listTitle, OneWoW_GUI:GetFont(), 12)
    listTitle:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -10)
    listTitle:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -10, -10)
    listTitle:SetJustifyH("LEFT")
    listTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    if hideTitles then
        listTitle:Hide()
    end

    local searchBox
    if showSearch then
        searchBox = self:CreateEditBox(listPanel, {
            placeholderText = options.searchPlaceholder or "",
        })
        local searchY = hideTitles and -8 or -30
        searchBox:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, searchY)
        searchBox:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -8, searchY)
    end

    local containerTopY
    if showSearch then
        containerTopY = hideTitles and -36 or -58
    else
        containerTopY = hideTitles and -8 or -32
    end
    local listContainer = CreateFrame("Frame", nil, listPanel)
    listContainer:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, containerTopY)
    listContainer:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -8, 8)

    local SPLIT_SCROLL_BAR_INSET = 14

    local function bindSplitScrollGutter(scrollFrame, host)
        local function applyInset(shown)
            local right = shown and -SPLIT_SCROLL_BAR_INSET or 0
            scrollFrame:ClearAllPoints()
            scrollFrame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
            scrollFrame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", right, 0)
        end
        scrollFrame._oneWoWOnScrollBarShown = applyInset
        local sb = scrollFrame.ScrollBar
        applyInset(sb and sb:IsShown() and not sb._oneWoWAlwaysHidden)
    end

    local listScrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_Split_List" .. uid, listContainer, "UIPanelScrollFrameTemplate")
    listScrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -SPLIT_SCROLL_BAR_INSET, 0)
    listScrollFrame:EnableMouseWheel(true)

    self:ApplyScrollBarStyle(listScrollFrame.ScrollBar, listContainer, -2)
    bindSplitScrollGutter(listScrollFrame, listContainer)

    local listScrollChild = CreateFrame("Frame", "OneWoWGUI_Split_ListContent" .. uid, listScrollFrame)
    listScrollChild:SetHeight(1)
    listScrollFrame:SetScrollChild(listScrollChild)
    listScrollFrame:HookScript("OnSizeChanged", function(_, w)
        listScrollChild:SetWidth(w)
    end)

    local detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", panelGap, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)
    detailPanel:SetBackdrop(backdrop)
    detailPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(detailTitle, 12)
    OneWoW_GUI:SafeSetFont(detailTitle, OneWoW_GUI:GetFont(), 12)
    detailTitle:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -10)
    detailTitle:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    if hideTitles then
        detailTitle:Hide()
    end

    local detailContainer = CreateFrame("Frame", nil, detailPanel)
    detailContainer:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, hideTitles and -8 or -32)
    detailContainer:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 8)

    local detailScrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_Split_Detail" .. uid, detailContainer, "UIPanelScrollFrameTemplate")
    detailScrollFrame:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 0, 0)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -SPLIT_SCROLL_BAR_INSET, 0)
    detailScrollFrame:EnableMouseWheel(true)

    self:ApplyScrollBarStyle(detailScrollFrame.ScrollBar, detailContainer, -2)
    bindSplitScrollGutter(detailScrollFrame, detailContainer)

    local detailScrollChild = CreateFrame("Frame", "OneWoWGUI_Split_DetailContent" .. uid, detailScrollFrame)
    detailScrollChild:SetHeight(1)
    detailScrollFrame:SetScrollChild(detailScrollChild)
    detailScrollFrame:HookScript("OnSizeChanged", function(_, w)
        detailScrollChild:SetWidth(w)
    end)

    local leftStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftStatusBar:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)
    leftStatusBar:SetBackdrop(backdrop)
    leftStatusBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    leftStatusBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SetFontBaseSize(leftStatusText, 10)
    OneWoW_GUI:SafeSetFont(leftStatusText, OneWoW_GUI:GetFont(), 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText("")

    local rightStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rightStatusBar:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)
    rightStatusBar:SetBackdrop(backdrop)
    rightStatusBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    rightStatusBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SetFontBaseSize(rightStatusText, 10)
    OneWoW_GUI:SafeSetFont(rightStatusText, OneWoW_GUI:GetFont(), 10)
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText("")

    return {
        listPanel = listPanel,
        listTitle = listTitle,
        listScrollFrame = listScrollFrame,
        listScrollChild = listScrollChild,
        UpdateListThumb = noop,
        detailPanel = detailPanel,
        detailTitle = detailTitle,
        detailScrollFrame = detailScrollFrame,
        detailScrollChild = detailScrollChild,
        UpdateDetailThumb = noop,
        searchBox = searchBox,
        leftStatusBar = leftStatusBar,
        leftStatusText = leftStatusText,
        rightStatusBar = rightStatusBar,
        rightStatusText = rightStatusText,
    }
end

function OneWoW_GUI:CreateDataTable(parent, options)
    options = options or {}
    local columns = options.columns or {}
    local headerHeight = options.headerHeight or 30
    local rowHeight = options.rowHeight or 32
    local colGap = options.colGap or 4
    local scrollBarWidth = options.scrollBarWidth or 10
    local padding = options.padding or 8
    local minFlexWidth = options.minFlexWidth or 20
    local onSort = options.onSort
    local onHeaderCreate = options.onHeaderCreate

    _dataTableCount = _dataTableCount + 1

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    container:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local inner = CreateFrame("Frame", nil, container)
    inner:SetPoint("TOPLEFT", container, "TOPLEFT", padding, -padding)
    inner:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -padding, padding)

    local headerRow = CreateFrame("Frame", nil, inner, "BackdropTemplate")
    headerRow:SetClipsChildren(true)
    headerRow:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, 0)
    headerRow:SetPoint("TOPRIGHT", inner, "TOPRIGHT", 0, 0)
    headerRow:SetHeight(headerHeight)
    headerRow:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    headerRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    headerRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    headerRow.columnButtons = {}
    headerRow.columns = columns

    local state = {
        sortColumn = nil,
        sortAscending = true,
        rows = {},
    }

    -- Public API table (filled below). Deferred layout and OnSizeChanged must call
    -- through this table so callers can wrap UpdateColumnLayout (e.g. virtualizer
    -- rebind) and still receive those callbacks.
    local dataTable = {}

    local function UpdateAllRowCells()
        if not headerRow or not headerRow.columnButtons then return end
        if not state.rows then return end
        for _, row in ipairs(state.rows) do
            if row.cells then
                for i, cell in ipairs(row.cells) do
                    local btn = headerRow.columnButtons[i]
                    if btn and btn.columnWidth and btn.columnX then
                        local width = btn.columnWidth
                        local x = btn.columnX
                        local col = columns[i]
                        cell:ClearAllPoints()
                        if col and col.align == "icon" then
                            cell:SetSize(width, rowHeight)
                            cell:SetPoint("LEFT", row, "LEFT", x, 0)
                        elseif col and col.align == "center" then
                            cell:SetWidth(width - 6)
                            cell:SetPoint("CENTER", row, "LEFT", x + width / 2, 0)
                        elseif col and col.align == "right" then
                            cell:SetWidth(width - 6)
                            cell:SetPoint("RIGHT", row, "LEFT", x + width - 3, 0)
                        else
                            cell:SetWidth(width - 6)
                            cell:SetPoint("LEFT", row, "LEFT", x + 3, 0)
                        end
                    end
                end
            end
        end
    end

    local function UpdateColumnLayout()
        local availableWidth = headerRow:GetWidth() - 10
        if availableWidth <= 0 then return end

        local resolvedWidths = {}
        local fixedWidth = 0
        local flexMinTotal = 0
        local flexWeightTotal = 0
        for i, col in ipairs(columns) do
            if col.fixed then
                local w = col.width or minFlexWidth
                local btn = headerRow.columnButtons[i]
                if btn and btn.text and btn.text.GetStringWidth then
                    local textW = btn.text:GetStringWidth() + 14
                    if textW > w then w = math.ceil(textW) end
                end
                resolvedWidths[i] = w
                fixedWidth = fixedWidth + w
            else
                local minW = col.minWidth or col.width or minFlexWidth
                local weight = col.flexWeight or 1
                if weight < 0 then weight = 0 end
                resolvedWidths[i] = minW
                flexMinTotal = flexMinTotal + minW
                flexWeightTotal = flexWeightTotal + weight
            end
        end

        local totalGaps = (#columns - 1) * colGap
        local remainingWidth = availableWidth - fixedWidth - flexMinTotal - totalGaps
        if remainingWidth < 0 then remainingWidth = 0 end

        if flexWeightTotal > 0 and remainingWidth > 0 then
            for i, col in ipairs(columns) do
                if not col.fixed then
                    local weight = col.flexWeight or 1
                    if weight < 0 then weight = 0 end
                    local extra = math.floor(remainingWidth * (weight / flexWeightTotal))
                    resolvedWidths[i] = resolvedWidths[i] + extra
                end
            end
        end

        local xOffset = 5
        for i, _ in ipairs(columns) do
            local btn = headerRow.columnButtons[i]
            if btn then
                local width = resolvedWidths[i]
                btn:SetWidth(width)
                btn:ClearAllPoints()
                btn:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", xOffset, 2)
                btn.columnWidth = width
                btn.columnX = xOffset
                xOffset = xOffset + width + colGap
            end
        end

        UpdateAllRowCells()
    end

    dataTable.UpdateColumnLayout = UpdateColumnLayout

    local function UpdateSortIndicators()
        if not headerRow or not headerRow.columnButtons then return end
        for i, btn in ipairs(headerRow.columnButtons) do
            local col = columns[i]
            if btn.sortArrow then btn.sortArrow:Hide() end
            if col and col.key == state.sortColumn then
                if not btn.sortArrow then
                    btn.sortArrow = btn:CreateTexture(nil, "OVERLAY")
                    btn.sortArrow:SetSize(8, 8)
                    btn.sortArrow:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
                    btn.sortArrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
                end
                btn.sortArrow:Show()
                if state.sortAscending then
                    btn.sortArrow:SetTexCoord(0, 0.5625, 1, 0)
                else
                    btn.sortArrow:SetTexCoord(0, 0.5625, 0, 1)
                end
            end
        end
    end

    -- Factored so SetColumns can rebuild the header buttons for a new column
    -- set at runtime (adaptive columns / view-mode switching), not just at
    -- creation. Returns the button; the caller registers it.
    local function MakeHeaderButton(col, i)
        local btn = CreateFrame("Button", nil, headerRow, "BackdropTemplate")
        btn:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        btn:SetHeight(headerHeight - 4)

        if col.headerIcon then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(col.headerIconSize or 16, col.headerIconSize or 16)
            icon:SetPoint("CENTER")
            if col.headerIconAtlas then
                icon:SetAtlas(col.headerIcon)
            else
                icon:SetTexture(col.headerIcon)
            end
            btn.icon = icon
        else
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            OneWoW_GUI:SetFontBaseSize(text, 10)
            OneWoW_GUI:SafeSetFont(text, OneWoW_GUI:GetFont(), 10)
            text:SetPoint("CENTER")
            text:SetText(col.label or "")
            text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            btn.text = text
        end

        btn:SetScript("OnEnter", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
            if col.ttTitle and col.ttDesc then
                GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                GameTooltip:SetText(col.ttTitle, 1, 1, 1)
                GameTooltip:AddLine(col.ttDesc, nil, nil, nil, true)
                GameTooltip:Show()
            elseif col.tooltip then
                GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                GameTooltip:SetText(col.tooltip, 1, 1, 1)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
            GameTooltip:Hide()
        end)

        if col.sortable ~= false then
            btn:SetScript("OnClick", function()
                if state.sortColumn == col.key then
                    state.sortAscending = not state.sortAscending
                else
                    state.sortColumn = col.key
                    state.sortAscending = true
                end
                if onSort then
                    onSort(state.sortColumn, state.sortAscending)
                end
                UpdateSortIndicators()
            end)
        end

        if onHeaderCreate then
            onHeaderCreate(btn, col, i)
        end

        return btn
    end

    for i, col in ipairs(columns) do
        tinsert(headerRow.columnButtons, MakeHeaderButton(col, i))
    end

    headerRow:SetScript("OnSizeChanged", function()
        C_Timer.After(0.1, function() dataTable.UpdateColumnLayout() end)
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, inner)
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 0, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(myself, delta)
        local current = myself:GetVerticalScroll()
        local maxScroll = myself:GetVerticalScrollRange()
        if delta > 0 then
            myself:SetVerticalScroll(math.max(0, current - 40))
        else
            myself:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
    end)

    local scrollTrack = CreateFrame("Frame", nil, inner, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:Hide()
    scrollTrack:SetBackdrop(Constants.BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(30)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(Constants.BACKDROP_SIMPLE)
    -- Bright theme-derived thumb so it stands out hard from the ACCENT_PRIMARY row selection.
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetScrollThumbColor(false))
    scrollThumb:Hide()

    local function UpdateScrollThumb()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local needed = math.floor(maxScroll) > 0
        local wasShown = scrollTrack:IsShown() and true or false
        if not needed then
            scrollThumb:Hide()
            scrollTrack:Hide()
            if wasShown then
                local right = 0
                headerRow:SetPoint("TOPRIGHT", inner, "TOPRIGHT", right, 0)
                scrollFrame:ClearAllPoints()
                scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
                scrollFrame:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", right, 0)
                dataTable.UpdateColumnLayout()
            end
            return
        end
        scrollTrack:Show()
        scrollThumb:Show()
        if not wasShown then
            headerRow:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -scrollBarWidth, 0)
            scrollFrame:ClearAllPoints()
            scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
            scrollFrame:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -scrollBarWidth, 0)
            dataTable.UpdateColumnLayout()
        end
        local viewHeight = scrollFrame:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        local thumbHeight = math.max(20, trackHeight * (viewHeight / (viewHeight + maxScroll)))
        local thumbRange = trackHeight - thumbHeight
        local thumbPos = (scrollFrame:GetVerticalScroll() / maxScroll) * thumbRange
        scrollThumb:SetHeight(thumbHeight)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbPos)
    end

    scrollFrame:SetScript("OnVerticalScroll", function() UpdateScrollThumb() end)
    scrollFrame:SetScript("OnScrollRangeChanged", function() UpdateScrollThumb() end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnDragStart", function(myself)
        myself.dragging = true
        myself.dragStartY = select(2, GetCursorPosition()) / myself:GetEffectiveScale()
        myself.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnDragStop", function(myself) myself.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(myself)
        if not myself.dragging then return end
        local curY = select(2, GetCursorPosition()) / myself:GetEffectiveScale()
        local delta = myself.dragStartY - curY
        local trackHeight = scrollTrack:GetHeight()
        local thumbRange = trackHeight - myself:GetHeight()
        if thumbRange > 0 then
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local newScroll = myself.dragStartScroll + (delta / thumbRange) * maxScroll
            scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, newScroll)))
        end
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(scrollFrame:GetWidth())
    scrollContent:SetHeight(400)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(_, width)
        scrollContent:SetWidth(width)
        UpdateScrollThumb()
    end)

    C_Timer.After(0.2, function() dataTable.UpdateColumnLayout() end)

    dataTable.container = container
    dataTable.inner = inner
    dataTable.headerRow = headerRow
    dataTable.scrollFrame = scrollFrame
    dataTable.scrollContent = scrollContent
    dataTable.scrollTrack = scrollTrack
    dataTable.scrollThumb = scrollThumb
    dataTable.state = state
    dataTable.UpdateSortIndicators = UpdateSortIndicators
    dataTable.UpdateScrollThumb = UpdateScrollThumb

    function dataTable:SetColumns(newColumns)
        columns = newColumns
        headerRow.columns = newColumns
        -- Rebuild the header buttons for the new set: tear down the old ones,
        -- recreate from newColumns (re-running onHeaderCreate), then relayout.
        -- Callers clear and re-add their data rows separately.
        for _, oldBtn in ipairs(headerRow.columnButtons) do
            oldBtn:Hide()
            oldBtn:SetParent(nil)
        end
        wipe(headerRow.columnButtons)
        for i, col in ipairs(columns) do
            tinsert(headerRow.columnButtons, MakeHeaderButton(col, i))
        end
        dataTable.UpdateColumnLayout()
    end

    function dataTable:GetSortState()
        return state.sortColumn, state.sortAscending
    end

    function dataTable:SetSortState(column, ascending)
        state.sortColumn = column
        state.sortAscending = ascending
        UpdateSortIndicators()
    end

    function dataTable:RegisterRow(row)
        tinsert(state.rows, row)
    end

    function dataTable:ClearRows()
        state.rows = {}
    end

    function dataTable:GetColumnLayout()
        local layout = {}
        for i, btn in ipairs(headerRow.columnButtons) do
            layout[i] = { width = btn.columnWidth, x = btn.columnX }
        end
        return layout
    end

    return dataTable
end

function OneWoW_GUI:ClearDataRows(scrollContent)
    if not scrollContent or not scrollContent._dataRows then return end
    for _, row in ipairs(scrollContent._dataRows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame = nil
        end
        row:Hide()
        row:SetParent(nil)
    end
    wipe(scrollContent._dataRows)
end

function OneWoW_GUI:LayoutDataRows(scrollContent, options)
    if not scrollContent or not scrollContent._dataRows then return end
    options = options or {}
    local rowHeight = options.rowHeight or 32
    local rowGap = options.rowGap or 2
    local topPadding = options.topPadding or 5

    local yOffset = -topPadding
    for _, row in ipairs(scrollContent._dataRows) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
            row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
            yOffset = yOffset - (rowHeight + rowGap)

            if row.isExpanded and row.expandedFrame and row.expandedFrame:IsShown() then
                row.expandedFrame:ClearAllPoints()
                row.expandedFrame:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -2)
                row.expandedFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
                yOffset = yOffset - (row.expandedFrame:GetHeight() + rowGap)
            end
        end
    end

    local totalHeight = math.abs(yOffset) + 50
    scrollContent:SetHeight(totalHeight)
end

function OneWoW_GUI:CreateDataRow(scrollContent, options)
    options = options or {}
    local rowHeight = options.rowHeight or 32
    local expandedHeight = options.expandedHeight or 160
    local rowGap = options.rowGap or 2
    local expandable = options.expandable ~= false
    local exclusiveExpand = options.exclusiveExpand
    local createDetails = options.createDetails
    local onRowEnter = options.onEnter
    local onRowLeave = options.onLeave

    _dataRowCount = _dataRowCount + 1

    local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_TERTIARY")
    local hoverR, hoverG, hoverB = OneWoW_GUI:GetThemeColor("BG_HOVER")

    local row = CreateFrame("Frame", nil, scrollContent)
    row:SetHeight(rowHeight)
    row.cells = {}
    row.data = options.data
    row.isExpanded = false

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(bgR, bgG, bgB, 0.6)
    row.bg = bg

    row:EnableMouse(true)

    local expandBtn, expandIcon
    if expandable then
        expandBtn = CreateFrame("Button", nil, row)
        expandBtn:SetSize(25, rowHeight)
        expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(14, 14)
        expandIcon:SetPoint("CENTER")
        expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
        expandBtn.icon = expandIcon
        tinsert(row.cells, expandBtn)
    end

    local function ToggleExpanded()
        row.isExpanded = not row.isExpanded

        if row.isExpanded then
            -- Accordion mode: only one row open at a time.
            if exclusiveExpand and scrollContent._dataRows then
                for _, otherRow in ipairs(scrollContent._dataRows) do
                    if otherRow ~= row and otherRow.isExpanded and otherRow.Collapse then
                        otherRow:Collapse()
                    end
                end
            end

            if expandIcon then expandIcon:SetAtlas("Gamepad_Rev_Minus_64") end
            if not row.expandedFrame then
                local detBgR, detBgG, detBgB = OneWoW_GUI:GetThemeColor("BG_SECONDARY")

                row.expandedFrame = CreateFrame("Frame", nil, scrollContent)
                row.expandedFrame:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -2)
                row.expandedFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
                row.expandedFrame:SetHeight(expandedHeight)

                local detBg = row.expandedFrame:CreateTexture(nil, "BACKGROUND")
                detBg:SetAllPoints(row.expandedFrame)
                detBg:SetColorTexture(detBgR, detBgG, detBgB, 0.7)
                row.expandedFrame.bg = detBg

                if createDetails then
                    createDetails(row.expandedFrame, row.data, row)
                end
            end
            row.expandedFrame:Show()
        else
            if expandIcon then expandIcon:SetAtlas("Gamepad_Rev_Plus_64") end
            if row.expandedFrame then
                row.expandedFrame:Hide()
            end
        end

        self:LayoutDataRows(scrollContent, {
            rowHeight = rowHeight,
            rowGap = rowGap,
        })
    end

    -- Public expand API. Lets callers programmatically open/close rows
    -- (e.g. auto-expanding the first row of a tab on initial render to hint
    -- that more data lives behind the +). All three call into the same
    -- ToggleExpanded path used by the button click and OnMouseDown handlers.
    function row:Toggle()
        if not expandable then return end
        ToggleExpanded()
    end

    function row:Expand()
        if not expandable or row.isExpanded then return end
        ToggleExpanded()
    end

    function row:Collapse()
        if not expandable or not row.isExpanded then return end
        ToggleExpanded()
    end

    -- Re-render an already-open row's detail content in place (e.g. when a
    -- modifier key changes what the detail builder wants to show), then reflow
    -- the rows below to match the new height.
    function row:RefreshDetails()
        if not row.expandedFrame or not row.isExpanded then return end
        if createDetails then
            createDetails(row.expandedFrame, row.data, row)
        end
        OneWoW_GUI:LayoutDataRows(scrollContent, {
            rowHeight = rowHeight,
            rowGap = rowGap,
        })
    end

    if expandable and expandBtn then
        expandBtn:SetScript("OnClick", ToggleExpanded)
    end

    row:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and expandable then
            ToggleExpanded()
        end
    end)

    row:SetScript("OnEnter", function(myself)
        myself.bg:SetColorTexture(hoverR, hoverG, hoverB, 0.8)
        if onRowEnter then onRowEnter(myself) end
    end)

    row:SetScript("OnLeave", function(myself)
        myself.bg:SetColorTexture(bgR, bgG, bgB, 0.6)
        if onRowLeave then onRowLeave(myself) end
    end)

    if not scrollContent._dataRows then
        scrollContent._dataRows = {}
    end
    tinsert(scrollContent._dataRows, row)

    return row, expandBtn, expandIcon
end

function OneWoW_GUI:CreateOverviewPanel(parent, options)
    options = options or {}
    local title = options.title
    local hasTitle = type(title) == "string" and title ~= ""
    local height = options.height or 110
    -- Reclaim the title row when callers omit a redundant section label.
    if not hasTitle then
        height = height - 22
    end
    local stats = options.stats or {}
    local numCols = options.columns or 5

    local numRows = math.ceil(#stats / numCols)

    local fontOffset = OneWoW_GUI:GetFontSizeOffset() or 0
    local extraHeight = math.max(0, fontOffset) * 8
    local totalHeight = height + extraHeight

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    panel:SetHeight(totalHeight)
    panel._baseHeight = height
    panel:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local titleFS
    if hasTitle then
        titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        OneWoW_GUI:SetFontBaseSize(titleFS, 12)
        OneWoW_GUI:SafeSetFont(titleFS, OneWoW_GUI:GetFont(), 12)
        titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -6)
        titleFS:SetText(title)
        titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end

    local statsContainer = CreateFrame("Frame", nil, panel)
    if titleFS then
        statsContainer:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -8)
    else
        statsContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    end
    statsContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 6)

    local statBoxes = {}

    for i = 1, #stats do
        local stat = stats[i]

        local statBox = CreateFrame("Frame", nil, statsContainer, "BackdropTemplate")
        statBox:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        statBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        statBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local label = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SafeSetFont(label, OneWoW_GUI:GetFont(), 10)
        label:SetPoint("BOTTOM", statBox, "CENTER", 0, 2)
        label:SetText(stat.label or "")
        label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local value = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        OneWoW_GUI:SafeSetFont(value, OneWoW_GUI:GetFont(), 12)
        value:SetPoint("TOP", statBox, "CENTER", 0, -2)
        value:SetText(stat.value or "0")
        value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        statBox.label = label
        statBox.value = value

        statBox:EnableMouse(true)
        statBox:SetScript("OnEnter", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(stat.ttTitle or "", 1, 1, 1)
            GameTooltip:AddLine(stat.ttDesc or "", nil, nil, nil, true)
            if myself.extraTooltipLines and #myself.extraTooltipLines > 0 then
                GameTooltip:AddLine(" ")
                for _, line in ipairs(myself.extraTooltipLines) do
                    GameTooltip:AddLine(line.text, line.r or 0.8, line.g or 0.8, line.b or 0.8, line.wrap)
                end
            end
            GameTooltip:Show()
        end)
        statBox:SetScript("OnLeave", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            GameTooltip:Hide()
        end)

        tinsert(statBoxes, statBox)
    end

    statsContainer:SetScript("OnSizeChanged", function(myself, width, containerHeight)
        local boxWidth = (width - (numCols + 1) * 3) / numCols
        local boxHeight = (containerHeight - (numRows + 1) * 3) / numRows

        for i, box in ipairs(statBoxes) do
            local r = math.ceil(i / numCols)
            local c = ((i - 1) % numCols) + 1

            local x = 3 + (c - 1) * (boxWidth + 3)
            local y = -3 - (r - 1) * (boxHeight + 3)

            box:SetSize(boxWidth, boxHeight)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", myself, "TOPLEFT", x, y)
        end
    end)

    return {
        panel = panel,
        title = titleFS,
        statsContainer = statsContainer,
        statBoxes = statBoxes,
    }
end

function OneWoW_GUI:CreateStatusBar(parent, anchorFrame, options)
    options = options or {}
    local anchorPoint = options.anchorPoint or "BELOW"
    local initialText = options.text or ""

    local statusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if anchorPoint == "BOTTOM" then
        statusBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 5, 5)
        statusBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 5)
    else
        statusBar:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -5)
        statusBar:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -5)
    end
    statusBar:SetHeight(25)
    statusBar:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    statusBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(statusText, OneWoW_GUI:GetFont(), 10)
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetText(initialText)
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    return {
        bar = statusBar,
        text = statusText,
    }
end

function OneWoW_GUI:CreateRosterPanel(parent, anchorFrame)
    local rosterPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rosterPanel:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -8)
    rosterPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)
    rosterPanel:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    rosterPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    rosterPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    return rosterPanel
end

function OneWoW_GUI:CreateExpandedPanelGrid(ef, options)
    options = options or {}
    local gap = options.gap or 8
    local inset = options.inset or 4
    local lineHeight = options.lineHeight or 14
    local minRows = options.minRows or 5
    local maxRows = options.maxRows or 50

    -- Release panels from a previous render so re-rendering the same expand
    -- frame (e.g. a SHIFT toggle) does not stack new panels on top of old ones.
    local oldPanels = ef._gridPanels
    if oldPanels then
        for _, p in ipairs(oldPanels) do
            p:Hide()
            p:ClearAllPoints()
            p:SetParent(nil)
        end
    end

    local panels = {}
    ef._gridPanels = panels

    local grid = {
        ef = ef,
        panels = panels,
    }

    function grid:AddPanel(title)
        local p = CreateFrame("Frame", nil, ef, "BackdropTemplate")
        p:SetPoint("TOPLEFT", ef, "TOPLEFT", inset, -inset)
        p:SetPoint("BOTTOMLEFT", ef, "BOTTOMLEFT", inset, inset)
        p:SetWidth(100)
        p:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        p:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        p:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        local titleFS = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SafeSetFont(titleFS, OneWoW_GUI:GetFont(), 10)
        titleFS:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -5)
        titleFS:SetText(title)
        titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        p.titleFS = titleFS
        p.dy = -18
        tinsert(panels, p)
        return p
    end

    function grid:AddLine(panel, a1, a2, a3)
        local text, color
        if type(a2) == "string" then
            text = a1 .. " " .. a2
            color = a3
        else
            text = a1
            color = a2
        end

        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), 10)
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, panel.dy)
        fs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, panel.dy)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        if color then
            if type(color) == "table" then
                fs:SetTextColor(unpack(color))
            else
                fs:SetTextColor(color)
            end
        else
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        panel.dy = panel.dy - lineHeight
        return fs
    end

    function grid:Finish()
        local maxLines = 0
        for _, p in ipairs(panels) do
            local lineCount = math.floor((math.abs(p.dy) - 18) / lineHeight) + 1
            if lineCount > maxLines then maxLines = lineCount end
        end
        local clampedLines = math.max(minRows, math.min(maxRows, maxLines))
        local dynamicHeight = 18 + (clampedLines * lineHeight) + 12
        ef:SetHeight(dynamicHeight)

        local function LayoutPanels()
            local w = ef:GetWidth()
            if w <= 10 then return end
            local numPanels = #panels
            if numPanels == 0 then return end
            local panelWidth = (w - gap * (numPanels + 1)) / numPanels
            for i, p in ipairs(panels) do
                p:ClearAllPoints()
                local xOff = gap + (i - 1) * (panelWidth + gap)
                p:SetPoint("TOPLEFT", ef, "TOPLEFT", xOff, -inset)
                p:SetPoint("BOTTOMLEFT", ef, "BOTTOMLEFT", xOff, inset)
                p:SetWidth(panelWidth)
            end
        end

        ef:SetScript("OnSizeChanged", function() LayoutPanels() end)
        C_Timer.After(0.05, function() LayoutPanels() end)

        return dynamicHeight
    end

    return grid
end

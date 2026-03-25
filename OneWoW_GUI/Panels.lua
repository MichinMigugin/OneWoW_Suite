local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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
    local titleHeight = config.titleHeight or 28
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
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
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
                btn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(cr, cg, cb, 0.8)
                    self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                    self.text:SetTextColor(1, 1, 1)
                end)
                btn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(cr, cg, cb, 0.6)
                    self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                    self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

    frame:Hide()
    return result
end

function OneWoW_GUI:CreateConfirmDialog(config)
    config = config or {}
    local titleText = config.title or ""
    local messageText = config.message or ""
    local dialogWidth = config.width or 420

    local titlePad = 20
    local msgPad = 10
    local bottomPad = 10
    local btnRowHeight = 28 + 10 + 10

    local measureFS = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measureFS:SetWidth(dialogWidth - 40)
    measureFS:SetText(messageText)
    local msgHeight = measureFS:GetStringHeight()
    measureFS:Hide()
    measureFS:SetParent(nil)

    local titleFS = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetText(titleText)
    local titleTextHeight = titleFS:GetStringHeight()
    titleFS:Hide()
    titleFS:SetParent(nil)

    local totalHeight = titlePad + titleTextHeight + msgPad + msgHeight + msgPad + btnRowHeight + bottomPad
    totalHeight = math.max(totalHeight, 140)

    local result = self:CreateDialog({
        name = config.name,
        title = "",
        width = dialogWidth,
        height = totalHeight,
        movable = false,
        escClose = true,
        titleHeight = 1,
        buttons = config.buttons,
    })

    result.titleBar:SetAlpha(0)
    result.titleBar:SetHeight(1)

    local titleLabel = result.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOP", result.contentFrame, "TOP", 0, -titlePad)
    titleLabel:SetText(titleText)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    result.titleLabel = titleLabel

    local msgLabel = result.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgLabel:SetPoint("TOP", titleLabel, "BOTTOM", 0, -msgPad)
    msgLabel:SetWidth(dialogWidth - 40)
    msgLabel:SetText(messageText)
    msgLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    result.messageLabel = msgLabel

    return result
end

function OneWoW_GUI:CreateScrollFrame(parent, options)
    options = options or {}
    local name = options.name
    local width = options.width
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    self:ApplyScrollBarStyle(scrollFrame.ScrollBar, parent, -2)

    local contentName = name and (name .. "Content") or nil
    local content = CreateFrame("Frame", contentName, scrollFrame)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    if width then
        content:SetWidth(width - 32)
    else
        scrollFrame:HookScript("OnSizeChanged", function(self, w)
            content:SetWidth(w)
        end)
    end

    return scrollFrame, content
end

function OneWoW_GUI:CreateVirtualizedList(parent, options)
    options = options or {}
    local name = options.name
    local rowHeight = options.rowHeight or 22
    local numVisibleRows = options.numVisibleRows or 40
    local getCount = options.getCount
    local getEntry = options.getEntry
    local onSelect = options.onSelect
    local renderRow = options.renderRow
    local enableKeyboardNav = options.enableKeyboardNav
    local focusCompetitor = options.focusCompetitor

    if not getCount or not getEntry or not onSelect then
        return nil
    end

    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -14, 4)
    self:ApplyScrollBarStyle(scrollFrame.ScrollBar, parent, -2)

    local contentName = name and (name .. "Content") or nil
    local content = CreateFrame("Frame", contentName, scrollFrame)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    local state = { selectedIndex = nil }
    local listButtons = {}

    local function ensureIndexVisible(idx)
        local n = getCount()
        if n <= 0 or idx < 1 or idx > n then return end
        local scroll = scrollFrame:GetVerticalScroll()
        local viewH = scrollFrame:GetHeight()
        local topOfRow = (idx - 1) * rowHeight
        local bottomOfRow = topOfRow + rowHeight
        if topOfRow < scroll then
            scrollFrame:SetVerticalScroll(topOfRow)
        elseif bottomOfRow > scroll + viewH then
            scrollFrame:SetVerticalScroll(bottomOfRow - viewH)
        end
    end

    local function updateVisibleRows()
        local n = getCount()
        local scroll = scrollFrame:GetVerticalScroll()
        local startIdx = math.floor(scroll / rowHeight) + 1
        for i, btn in ipairs(listButtons) do
            local idx = startIdx + i - 1
            local entry = getEntry(idx)
            if entry and idx <= n then
                btn:ClearAllPoints()
                btn:SetHeight(rowHeight)
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -(idx - 1) * rowHeight)
                btn:SetPoint("RIGHT", content, "RIGHT", -2, 0)
                btn:SetNormalFontObject((state.selectedIndex == idx) and GameFontHighlightSmall or GameFontNormalSmall)
                if renderRow then
                    renderRow(btn, idx, entry, state.selectedIndex == idx)
                else
                    btn:SetText(entry.displayName or tostring(entry))
                end
                btn.entryIndex = idx
                btn:Show()
            else
                btn:Hide()
                btn.entryIndex = nil
            end
        end
    end

    local function Refresh()
        if not scrollFrame or not content then return end
        local n = getCount()
        if n <= 0 then
            state.selectedIndex = nil
        elseif state.selectedIndex and state.selectedIndex > n then
            state.selectedIndex = n
        end
        content:SetHeight(math.max(n * rowHeight, 1))
        local scrollMax = math.max(content:GetHeight() - scrollFrame:GetHeight(), 0)
        local vs = scrollFrame:GetVerticalScroll()
        if vs > scrollMax then
            scrollFrame:SetVerticalScroll(scrollMax)
        end
        updateVisibleRows()
    end

    local function SetSelectedIndex(idx)
        local n = getCount()
        if idx == nil or n <= 0 then
            state.selectedIndex = nil
            Refresh()
            return
        end
        local clamped = math.max(1, math.min(idx, n))
        state.selectedIndex = clamped
        ensureIndexVisible(clamped)
        Refresh()
        local entry = getEntry(clamped)
        if entry then
            onSelect(clamped, entry)
        end
    end

    local function GetSelectedIndex()
        return state.selectedIndex
    end

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
        Refresh()
    end)

    for i = 1, numVisibleRows do
        local btn = CreateFrame("Button", nil, content)
        btn:SetHeight(rowHeight)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)
        btn:SetScript("OnClick", function(b)
            if b.entryIndex then
                SetSelectedIndex(b.entryIndex)
            end
        end)
        btn:SetScript("OnEnter", function(self)
            local t = self._tooltipFullText
            if t and t ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
                GameTooltip:SetText(t, r, g, b, nil, true)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
        tinsert(listButtons, btn)
    end

    scrollFrame:SetScript("OnVerticalScroll", updateVisibleRows)

    if enableKeyboardNav and focusCompetitor then
        focusCompetitor:HookScript("OnEditFocusGained", function()
            if parent.EnableKeyboard then
                parent:EnableKeyboard(false)
            end
        end)
        focusCompetitor:HookScript("OnEditFocusLost", function()
            if parent.EnableKeyboard then
                parent:EnableKeyboard(true)
            end
        end)
    end

    if enableKeyboardNav then
        parent:EnableKeyboard(true)
        parent:SetScript("OnKeyDown", function(self, key)
            if key == "UP" or key == "DOWN" then
                self:SetPropagateKeyboardInput(false)
                local n = getCount()
                if n <= 0 then return end
                local cur = state.selectedIndex or 0
                if key == "UP" then
                    SetSelectedIndex(cur > 1 and cur - 1 or 1)
                else
                    SetSelectedIndex(cur < n and cur + 1 or n)
                end
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end

    local result = {
        listPanel = parent,
        listScroll = scrollFrame,
        listContent = content,
        Refresh = Refresh,
        SetSelectedIndex = SetSelectedIndex,
        GetSelectedIndex = GetSelectedIndex,
    }
    return result
end

function OneWoW_GUI:CreateSplitPanel(parent, options)
    local panelGap = Constants.GUI.PANEL_GAP or 10

    local backdrop = Constants.BACKDROP_INNER_NO_INSETS

    options = options or {}
    local showSearch = options.showSearch

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
    listTitle:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -10)
    listTitle:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -10, -10)
    listTitle:SetJustifyH("LEFT")
    listTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local searchBox
    if showSearch then
        searchBox = self:CreateEditBox(listPanel, {
            placeholderText = options.searchPlaceholder or "",
        })
        searchBox:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -30)
        searchBox:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -8, -30)
    end

    local containerTopY = showSearch and -58 or -32
    local listContainer = CreateFrame("Frame", nil, listPanel)
    listContainer:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, containerTopY)
    listContainer:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -8, 8)

    local listScrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_Split_List" .. uid, listContainer, "UIPanelScrollFrameTemplate")
    listScrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -14, 0)
    listScrollFrame:EnableMouseWheel(true)

    self:ApplyScrollBarStyle(listScrollFrame.ScrollBar, listContainer, -2)

    local listScrollChild = CreateFrame("Frame", "OneWoWGUI_Split_ListContent" .. uid, listScrollFrame)
    listScrollChild:SetHeight(1)
    listScrollFrame:SetScrollChild(listScrollChild)
    listScrollFrame:HookScript("OnSizeChanged", function(self, w)
        listScrollChild:SetWidth(w)
    end)

    local detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", panelGap, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)
    detailPanel:SetBackdrop(backdrop)
    detailPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -10)
    detailTitle:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local detailContainer = CreateFrame("Frame", nil, detailPanel)
    detailContainer:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -32)
    detailContainer:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 8)

    local detailScrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_Split_Detail" .. uid, detailContainer, "UIPanelScrollFrameTemplate")
    detailScrollFrame:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 0, 0)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -14, 0)
    detailScrollFrame:EnableMouseWheel(true)

    self:ApplyScrollBarStyle(detailScrollFrame.ScrollBar, detailContainer, -2)

    local detailScrollChild = CreateFrame("Frame", "OneWoWGUI_Split_DetailContent" .. uid, detailScrollFrame)
    detailScrollChild:SetHeight(1)
    detailScrollFrame:SetScrollChild(detailScrollChild)
    detailScrollFrame:HookScript("OnSizeChanged", function(self, w)
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
    local uid = _dataTableCount

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
    headerRow:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -scrollBarWidth, 0)
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

        local fixedWidth = 0
        local flexCount = 0
        for _, col in ipairs(columns) do
            if col.fixed then
                fixedWidth = fixedWidth + col.width
            else
                flexCount = flexCount + 1
            end
        end

        local totalGaps = (#columns - 1) * colGap
        local remainingWidth = availableWidth - fixedWidth - totalGaps
        local flexWidth = flexCount > 0 and math.max(0, remainingWidth / flexCount) or 0

        local xOffset = 5
        for i, col in ipairs(columns) do
            local btn = headerRow.columnButtons[i]
            if btn then
                local width = col.fixed and col.width or math.max(minFlexWidth, flexWidth)
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

    for i, col in ipairs(columns) do
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
            text:SetPoint("CENTER")
            text:SetText(col.label or "")
            text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            btn.text = text
        end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
            if col.ttTitle and col.ttDesc then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.ttTitle, 1, 1, 1)
                GameTooltip:AddLine(col.ttDesc, nil, nil, nil, true)
                GameTooltip:Show()
            elseif col.tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.tooltip, 1, 1, 1)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
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

        tinsert(headerRow.columnButtons, btn)
    end

    headerRow:SetScript("OnSizeChanged", function()
        C_Timer.After(0.1, function() UpdateColumnLayout() end)
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, inner)
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -scrollBarWidth, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
    end)

    local scrollTrack = CreateFrame("Frame", nil, inner, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop(Constants.BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(30)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(Constants.BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local function UpdateScrollThumb()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        if maxScroll <= 0 then
            scrollThumb:Hide()
            return
        end
        scrollThumb:Show()
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
    scrollThumb:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackHeight = scrollTrack:GetHeight()
        local thumbRange = trackHeight - self:GetHeight()
        if thumbRange > 0 then
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local newScroll = self.dragStartScroll + (delta / thumbRange) * maxScroll
            scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, newScroll)))
        end
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(scrollFrame:GetWidth())
    scrollContent:SetHeight(400)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        scrollContent:SetWidth(width)
        UpdateScrollThumb()
    end)

    C_Timer.After(0.2, function() UpdateColumnLayout() end)

    local dataTable = {
        container = container,
        inner = inner,
        headerRow = headerRow,
        scrollFrame = scrollFrame,
        scrollContent = scrollContent,
        scrollTrack = scrollTrack,
        scrollThumb = scrollThumb,
        state = state,
        UpdateColumnLayout = UpdateColumnLayout,
        UpdateSortIndicators = UpdateSortIndicators,
        UpdateScrollThumb = UpdateScrollThumb,
    }

    function dataTable:SetColumns(newColumns)
        columns = newColumns
        headerRow.columns = newColumns
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
                    createDetails(row.expandedFrame, row.data)
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

    if expandable and expandBtn then
        expandBtn:SetScript("OnClick", ToggleExpanded)
    end

    row:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and expandable then
            ToggleExpanded()
        end
    end)

    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(hoverR, hoverG, hoverB, 0.8)
        if onRowEnter then onRowEnter(self) end
    end)

    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(bgR, bgG, bgB, 0.6)
        if onRowLeave then onRowLeave(self) end
    end)

    if not scrollContent._dataRows then
        scrollContent._dataRows = {}
    end
    tinsert(scrollContent._dataRows, row)

    return row, expandBtn, expandIcon
end

function OneWoW_GUI:CreateOverviewPanel(parent, options)
    options = options or {}
    local title = options.title or ""
    local height = options.height or 110
    local stats = options.stats or {}
    local numCols = options.columns or 5

    local numRows = math.ceil(#stats / numCols)

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    panel:SetHeight(height)
    panel:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -6)
    titleFS:SetText(title)
    titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local statsContainer = CreateFrame("Frame", nil, panel)
    statsContainer:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -8)
    statsContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 6)

    local statBoxes = {}

    for i = 1, #stats do
        local stat = stats[i]

        local statBox = CreateFrame("Frame", nil, statsContainer, "BackdropTemplate")
        statBox:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        statBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        statBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local label = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", statBox, "TOP", 0, -5)
        label:SetText(stat.label or "")
        label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local value = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("BOTTOM", statBox, "BOTTOM", 0, 6)
        value:SetText(stat.value or "0")
        value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        statBox.label = label
        statBox.value = value

        statBox:EnableMouse(true)
        statBox:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(stat.ttTitle or "", 1, 1, 1)
            GameTooltip:AddLine(stat.ttDesc or "", nil, nil, nil, true)
            if self.extraTooltipLines and #self.extraTooltipLines > 0 then
                GameTooltip:AddLine(" ")
                for _, line in ipairs(self.extraTooltipLines) do
                    GameTooltip:AddLine(line.text, line.r or 0.8, line.g or 0.8, line.b or 0.8, line.wrap)
                end
            end
            GameTooltip:Show()
        end)
        statBox:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            GameTooltip:Hide()
        end)

        tinsert(statBoxes, statBox)
    end

    statsContainer:SetScript("OnSizeChanged", function(self, width, height)
        local boxWidth = (width - (numCols + 1) * 3) / numCols
        local boxHeight = (height - (numRows + 1) * 3) / numRows

        for i, box in ipairs(statBoxes) do
            local r = math.ceil(i / numCols)
            local c = ((i - 1) % numCols) + 1

            local x = 3 + (c - 1) * (boxWidth + 3)
            local y = -3 - (r - 1) * (boxHeight + 3)

            box:SetSize(boxWidth, boxHeight)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
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

    local panels = {}

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

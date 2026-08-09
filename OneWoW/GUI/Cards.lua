local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local ipairs, math_floor, math_max = ipairs, math.floor, math.max
local strlower, strfind = strlower, string.find
local tinsert = tinsert

local Constants = OneWoW_GUI.Constants

-- ============================================================================
-- CreateCard — collapsible titled section card
-- ============================================================================
-- Full-width settings section: a clickable header bar (arrow + title) over a
-- padded content area. The caller builds widgets into `card.content`, then
-- calls `card:SetContentHeight(h)`; the card sizes itself (header only when
-- collapsed). Collapsing is caller-driven: the header click fires
-- `onToggle(collapsed)` and the caller re-renders its card stack.
--
-- options:
--   title      string   header text
--   collapsed  boolean  start collapsed
--   onToggle   fun(collapsed: boolean)
---@return Frame card with .content, :SetContentHeight(h), :IsCollapsed()
function OneWoW_GUI:CreateCard(parent, options)
    options = options or {}
    local headerHeight = 24
    local padX, padTop, padBottom = 10, 8, 10

    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    card.collapsed = options.collapsed == true

    local header = CreateFrame("Button", nil, card, "BackdropTemplate")
    header:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)
    header:SetHeight(headerHeight)
    header:SetBackdrop(Constants.BACKDROP_SIMPLE)
    header:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    card.header = header

    local arrow = header:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("LEFT", header, "LEFT", 6, 0)
    card.arrow = arrow

    local title = OneWoW_GUI:CreateFS(header, 12)
    title:SetPoint("LEFT", arrow, "RIGHT", 5, 0)
    title:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    title:SetJustifyH("LEFT")
    title:SetText(options.title or "")
    title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    card.title = title

    local content = CreateFrame("Frame", nil, card)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", padX, -padTop)
    content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -padX, -padTop)
    content:SetHeight(1)
    card.content = content

    -- Clip content when collapsed instead of Hide(): hiding can zero content
    -- width, so wrapped FontStrings reflow on re-show while absolute points stay.
    card:SetClipsChildren(true)
    header:SetFrameLevel(card:GetFrameLevel() + 2)

    local function UpdateArrow()
        if card.collapsed then
            arrow:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", false)
        else
            arrow:SetAtlas("UI-HUD-ActionBar-PageUpArrow-Up", false)
        end
    end
    UpdateArrow()

    function card:IsCollapsed()
        return self.collapsed
    end

    --- Size the card to its content (or to the header alone when collapsed).
    function card:SetContentHeight(h)
        self._contentHeight = h
        self.content:Show()
        self.content:SetHeight(h)
        if self.collapsed then
            self.content:EnableMouse(false)
            self:SetHeight(headerHeight + 2)
        else
            self.content:EnableMouse(true)
            self:SetHeight(headerHeight + padTop + h + padBottom)
        end
    end

    header:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
    end)
    header:SetScript("OnLeave", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    end)
    header:SetScript("OnClick", function()
        card.collapsed = not card.collapsed
        UpdateArrow()
        card:SetContentHeight(card._contentHeight or 1)
        if options.onToggle then
            options.onToggle(card.collapsed)
        end
    end)

    return card
end

-- ============================================================================
-- CreateCardStack — reusable stack/orchestrator for collapsible cards
-- ============================================================================
-- Owns vertical card layout, reliable content width measurement, and optional
-- collapsed-state persistence. Callers can add pre-sized frames (hero blocks)
-- and cards. Each card builder receives (content, contentWidth) and returns
-- content height.
--
-- options:
--   getCollapsed fun(key): boolean?
--   setCollapsed fun(key, collapsed)
--   marginX      number? default 4
--   startY       number? default -6
--   gap          number? default 8
---@return table stack
function OneWoW_GUI:CreateCardStack(parent, options)
    options = options or {}
    local stack = { items = {}, parent = parent }
    local marginX = options.marginX or 4
    local startY = options.startY or -6
    local gap = options.gap or 8
    local padX, padTop = 10, 8

    --- Live host width from the stack parent or its parent (detail scroll child).
    local function resolveHostContentWidth()
        local w = parent:GetWidth() or 0
        if w < 100 then
            local hostParent = parent.GetParent and parent:GetParent()
            if hostParent and hostParent.GetWidth then
                w = hostParent:GetWidth() or 0
            end
        end
        if w < 100 then
            return nil
        end
        local cw = w - (marginX * 2) - 22
        if cw < 50 then
            return nil
        end
        return cw
    end

    -- Seed from live width when available; otherwise a temporary fallback used
    -- only until Finish/OnSizeChanged can resolve the real host width.
    stack.contentWidth = resolveHostContentWidth() or (400 - (marginX * 2) - 22)
    stack._builtAtWidth = nil

    --- Resolve wrap width for builders. Prefer live content stretch once the
    --- host has a real width; otherwise pin to stack.contentWidth so metrics
    --- are not a collapsed zero-width column.
    local function prepareCardContent(card, cw)
        local content = card.content
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", card.header, "BOTTOMLEFT", padX, -padTop)
        content:SetPoint("TOPRIGHT", card.header, "BOTTOMRIGHT", -padX, -padTop)
        local measured = content:GetWidth() or 0
        if measured >= 50 then
            return measured
        end
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", card.header, "BOTTOMLEFT", padX, -padTop)
        content:SetWidth(cw)
        return cw
    end

    function stack:EnsureContentWidth()
        local cw = resolveHostContentWidth()
        if not cw then
            return false
        end
        self.contentWidth = cw
        return true
    end

    function stack:SyncContentWidth()
        local cw = resolveHostContentWidth()
        if not cw then
            return false
        end
        if math.abs(cw - self.contentWidth) < 2 then
            return false
        end
        self.contentWidth = cw
        return true
    end

    function stack:Relayout()
        -- OnRelayout often SetHeights the scroll child; that fires OnSizeChanged on
        -- the host and used to re-enter Relayout/ReflowContents (C stack overflow).
        if self._inLayout then
            return
        end
        self._inLayout = true

        local y = startY
        local n = #self.items
        for i, frame in ipairs(self.items) do
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", marginX, y)
            frame:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", -marginX, y)
            y = y - frame:GetHeight()
            -- Gap only between cards — trailing gap + bottom pad used to inflate
            -- nested hosts (e.g. Features toggle cardsHost → CreateCustomDetail).
            if i < n then
                y = y - gap
            end
        end
        local newH = math.abs(y)
        if math.abs((self.parent:GetHeight() or 0) - newH) >= 0.5 then
            self.parent:SetHeight(newH)
        end
        if self.OnRelayout then
            self.OnRelayout()
        end
        self._inLayout = false
    end

    --- Rebuild card bodies for the current contentWidth (wrap + control stretch).
    function stack:ReflowContents()
        if self._inLayout then
            return
        end
        local cw = self.contentWidth
        for _, frame in ipairs(self.items) do
            local build = frame._cardBuild
            if build then
                OneWoW_GUI:ClearFrame(frame.content)
                local useW = prepareCardContent(frame, cw)
                frame:SetContentHeight(build(frame.content, useW) or 1)
                frame._needsBuild = false
            end
        end
        self._builtAtWidth = cw
        self:Relayout()
        OneWoW_GUI:ApplyFontToFrame(self.parent)
    end

    function stack:AddFrame(frame)
        tinsert(self.items, frame)
        frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", marginX, startY)
        frame:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", -marginX, startY)
        return frame
    end

    function stack:AddCard(key, title, build)
        local card = OneWoW_GUI:CreateCard(self.parent, {
            title = title,
            collapsed = options.getCollapsed and options.getCollapsed(key) == true,
            onToggle = function(collapsed)
                if options.setCollapsed then options.setCollapsed(key, collapsed) end
                stack:Relayout()
            end,
        })
        card._cardBuild = build
        self:AddFrame(card)
        -- Only build when the host already has a real width. Building against the
        -- fallback width then reflowing one frame later is what flashed on select.
        if self:EnsureContentWidth() then
            local useW = prepareCardContent(card, self.contentWidth)
            card:SetContentHeight(build(card.content, useW) or 1)
            card._needsBuild = false
            self._builtAtWidth = self.contentWidth
        else
            card:SetContentHeight(1)
            card._needsBuild = true
        end
        return card
    end

    function stack:Finish()
        local function paint(reveal)
            if not self.parent or not self.parent.GetWidth then
                return
            end
            local hadWidth = self:EnsureContentWidth()
            local needsBuild = false
            for _, frame in ipairs(self.items) do
                if frame._needsBuild then
                    needsBuild = true
                    break
                end
            end
            local widthDrift = self._builtAtWidth
                and math.abs(self._builtAtWidth - self.contentWidth) >= 2
            if hadWidth and (needsBuild or widthDrift or not self._builtAtWidth) then
                self:ReflowContents()
            else
                self:Relayout()
                OneWoW_GUI:ApplyFontToFrame(self.parent)
            end
            if reveal then
                self.parent:SetAlpha(1)
            end
        end

        if self:EnsureContentWidth() then
            paint(false)
        else
            -- Hide until the scroll child has a width so we never show the fallback layout.
            self.parent:SetAlpha(0)
            C_Timer.After(0, function()
                paint(true)
            end)
        end

        if not self._widthHooked then
            self._widthHooked = true
            local pending
            local function scheduleReflow()
                -- Relayout holds _inLayout through OnRelayout (scroll-child
                -- SetHeight). Ignoring those events prevents re-entrant reflow.
                if self._inLayout then
                    return
                end
                if pending then return end
                pending = true
                C_Timer.After(0.05, function()
                    pending = false
                    if self._inLayout then return end
                    if not self.parent or not self.parent.GetWidth then return end
                    -- Stack host was ClearFrame'd / unparented when switching features.
                    if self.parent.GetParent and not self.parent:GetParent() then
                        return
                    end
                    if self:SyncContentWidth() then
                        self:ReflowContents()
                    end
                end)
            end
            self.parent:HookScript("OnSizeChanged", scheduleReflow)
            -- Detail hosts often get width via the scroll child one level up;
            -- the stack parent may not see OnSizeChanged until after that.
            local hostParent = self.parent.GetParent and self.parent:GetParent()
            if hostParent and hostParent.HookScript then
                hostParent:HookScript("OnSizeChanged", scheduleReflow)
            end
        end
    end

    return stack
end

-- ============================================================================
-- CreateIconGrid — searchable icon gallery
-- ============================================================================
-- A grid of icon swatches grouped by category with a search box on top.
-- Non-scrolling: it computes the height needed for the full set and keeps it
-- stable while searching (filtered-out cells hide). Hover shows the icon's
-- display name; the selected cell gets an accent ring.
--
-- options:
--   categories        { { name = string, icons = { iconName, ... } }, ... }
--   width             number   layout width (required)
--   selected          string?  initially selected icon name
--   cellSize          number?  default 30
--   gap               number?  default 4
--   applyIcon         fun(texture, iconName)  paints one swatch
--   getDisplayName    fun(iconName): string   hover tooltip text
--   onSelect          fun(iconName)
--   searchPlaceholder string?
---@return Frame grid with :SetSelected(name), :GetSelected()
function OneWoW_GUI:CreateIconGrid(parent, options)
    options = options or {}
    -- Callers must pass a concrete width: rects of freshly created frames are
    -- not resolved yet, so GetWidth() on a new parent yields 0.
    local width = options.width
    if not width or width < 40 then width = 300 end
    local cellSize = options.cellSize or 30
    local gap = options.gap or 4
    local headerHeight = 18
    local searchHeight = 22
    local applyIcon = options.applyIcon
    local getDisplayName = options.getDisplayName
    local onSelect = options.onSelect

    local grid = CreateFrame("Frame", nil, parent)
    grid:SetWidth(width)
    grid._selected = options.selected

    local searchBox = OneWoW_GUI:CreateEditBox(grid, {
        placeholderText = options.searchPlaceholder or "",
        height = searchHeight,
    })
    searchBox:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 0)
    searchBox:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, 0)

    local headers = {}
    local cells = {}

    for _, cat in ipairs(options.categories or {}) do
        local hdr = OneWoW_GUI:CreateFS(grid, 10)
        hdr:SetJustifyH("LEFT")
        hdr:SetText(cat.name or "")
        hdr:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        local hdrLine = grid:CreateTexture(nil, "ARTWORK")
        hdrLine:SetHeight(1)
        hdrLine:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        local entry = { fs = hdr, line = hdrLine, cells = {} }
        tinsert(headers, entry)

        for _, iconName in ipairs(cat.icons or {}) do
            local cell = CreateFrame("Button", nil, grid, "BackdropTemplate")
            cell:SetSize(cellSize, cellSize)
            cell:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
            cell:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            cell:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local tex = cell:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", cell, "TOPLEFT", 3, -3)
            tex:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -3, 3)
            if applyIcon then applyIcon(tex, iconName) end

            local displayName = getDisplayName and getDisplayName(iconName) or iconName
            local record = {
                frame = cell,
                iconName = iconName,
                searchText = strlower(displayName .. " " .. iconName),
            }
            tinsert(cells, record)
            tinsert(entry.cells, record)

            local function Restyle()
                if grid._selected == iconName then
                    cell:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                    cell:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                else
                    cell:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    cell:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end
            end
            record.Restyle = Restyle
            Restyle()

            cell:SetScript("OnEnter", function(myself)
                if grid._selected ~= iconName then
                    myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                    myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
                end
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetText(displayName, 1, 1, 1)
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", function()
                Restyle()
                GameTooltip:Hide()
            end)
            cell:SetScript("OnClick", function()
                grid._selected = iconName
                for _, r in ipairs(cells) do r.Restyle() end
                if onSelect then onSelect(iconName) end
            end)
        end
    end

    -- Lays out matching cells; returns the height used. Height for the empty
    -- filter (everything visible) is the grid's permanent height so the
    -- surrounding layout stays stable while typing.
    local function Layout(filter)
        filter = strlower(filter or "")
        local cols = math_max(4, math_floor((width + gap) / (cellSize + gap)))
        local y = -(searchHeight + 8)

        for _, hdr in ipairs(headers) do
            local matching = {}
            for _, record in ipairs(hdr.cells) do
                if filter == "" or strfind(record.searchText, filter, 1, true) then
                    tinsert(matching, record)
                else
                    record.frame:Hide()
                end
            end

            if #matching == 0 then
                hdr.fs:Hide()
                hdr.line:Hide()
            else
                hdr.fs:ClearAllPoints()
                hdr.fs:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y - 4)
                hdr.fs:Show()
                hdr.line:ClearAllPoints()
                hdr.line:SetPoint("LEFT", hdr.fs, "RIGHT", 6, 0)
                hdr.line:SetPoint("RIGHT", grid, "RIGHT", 0, 0)
                hdr.line:SetPoint("TOP", hdr.fs, "CENTER", 0, 0)
                hdr.line:Show()
                y = y - headerHeight - 4

                for i, record in ipairs(matching) do
                    local col = (i - 1) % cols
                    local rowIdx = math_floor((i - 1) / cols)
                    record.frame:ClearAllPoints()
                    record.frame:SetPoint("TOPLEFT", grid, "TOPLEFT",
                        col * (cellSize + gap),
                        y - rowIdx * (cellSize + gap))
                    record.frame:Show()
                end
                local rows = math_floor((#matching - 1) / cols) + 1
                y = y - rows * (cellSize + gap) - 6
            end
        end

        return -y
    end

    local fullHeight = Layout("")
    grid:SetHeight(fullHeight)

    searchBox:SetScript("OnTextChanged", function(myself)
        Layout(myself:GetSearchText())
    end)

    function grid:SetSelected(name)
        self._selected = name
        for _, r in ipairs(cells) do r.Restyle() end
    end

    function grid:GetSelected()
        return self._selected
    end

    return grid
end

-- ============================================================================
-- CreatePositionGrid — spatial anchor picker
-- ============================================================================
-- A clickable slot diagram replacing anchor-string dropdowns: a 3x3 grid on
-- a mock item slot for the inner anchors, plus a row of 3 cells above and
-- below for the Outer-Top-* / Outer-Bottom-* positions. Hover shows the
-- anchor name; the active cell gets the accent ring.
--
-- options:
--   value     string?  current position
--   onChange  fun(position: string)
---@return Frame widget with :SetValue(pos), fixed size
function OneWoW_GUI:CreatePositionGrid(parent, options)
    options = options or {}
    local cell, gap = 22, 2
    local slotPad = 4
    local slotSize = cell * 3 + gap * 2 + slotPad * 2
    local outerH = 14
    local totalW = slotSize
    local totalH = outerH + gap + slotSize + gap + outerH

    local widget = CreateFrame("Frame", nil, parent)
    widget:SetSize(totalW, totalH)
    widget._value = options.value

    -- Mock slot backdrop behind the inner 3x3.
    local slot = CreateFrame("Frame", nil, widget, "BackdropTemplate")
    slot:SetSize(slotSize, slotSize)
    slot:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -(outerH + gap))
    slot:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    slot:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    slot:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local cellsByPos = {}

    local function MakeCell(pos, parentFrame, x, y, w, h)
        local btn = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
        btn:SetSize(w, h)
        btn:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
        btn:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)

        local function Restyle()
            if widget._value == pos then
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            else
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end
        Restyle()
        cellsByPos[pos] = Restyle

        btn:SetScript("OnEnter", function(myself)
            if widget._value ~= pos then
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(pos, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            Restyle()
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", function()
            local old = widget._value
            widget._value = pos
            if old and cellsByPos[old] then cellsByPos[old]() end
            Restyle()
            if options.onChange then options.onChange(pos) end
        end)
        return btn
    end

    -- Outer rows (above / below the slot).
    local outerCellW = math_floor((totalW - gap * 2) / 3)
    local OUTER_TOP = { "Outer-Top-Left", "Outer-Top-Middle", "Outer-Top-Right" }
    local OUTER_BOTTOM = { "Outer-Bottom-Left", "Outer-Bottom-Middle", "Outer-Bottom-Right" }
    for i = 1, 3 do
        MakeCell(OUTER_TOP[i], widget, (i - 1) * (outerCellW + gap), 0, outerCellW, outerH)
        MakeCell(OUTER_BOTTOM[i], widget, (i - 1) * (outerCellW + gap),
            -(outerH + gap + slotSize + gap), outerCellW, outerH)
    end

    -- Inner 3x3 on the slot.
    local INNER = {
        { "TOPLEFT",    "TOP",    "TOPRIGHT" },
        { "LEFT",       "CENTER", "RIGHT" },
        { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
    }
    for r = 1, 3 do
        for c = 1, 3 do
            MakeCell(INNER[r][c], slot,
                slotPad + (c - 1) * (cell + gap),
                -(slotPad + (r - 1) * (cell + gap)),
                cell, cell)
        end
    end

    function widget:SetValue(pos)
        local old = self._value
        self._value = pos
        if old and cellsByPos[old] then cellsByPos[old]() end
        if pos and cellsByPos[pos] then cellsByPos[pos]() end
    end

    return widget
end

-- ============================================================================
-- ItemListEditor — shared add-row + keyed entry list chrome
-- ============================================================================
-- CreateValueAddRow  — label + input + Add + optional chip drop
-- CreateEntryList    — list panel (grow or fixed+scroll), default/custom rows
-- CreateItemListEditor — thin composite (chip add-row + grow/fixed list + Clear)
-- Item-list sort     — Get/Set/SortItemEntries + sortKey toolbar (name | id)
--
-- Callers own data; these only own layout, theme, enable/disable, refresh, and
-- optional per-list display sort.
-- ============================================================================

local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local wipe = wipe
local tinsert = tinsert
local sort = sort
local strcmputf8i = strcmputf8i

local Constants = OneWoW_GUI.Constants
local GUI = Constants.GUI

local function Trim(s)
    if not s then return "" end
    return (tostring(s):match("^%s*(.-)%s*$")) or ""
end

local function CursorAccepts(infoType, cursorTypes)
    if not infoType or not cursorTypes then return false end
    for _, t in ipairs(cursorTypes) do
        if t == infoType then return true end
    end
    return false
end

local function ValueFromCursor(kind, infoType, arg1)
    if kind == "itemId" and infoType == "item" and arg1 then
        return tonumber(arg1)
    end
    if kind == "text" and infoType == "macro" and arg1 then
        local name = GetMacroInfo(arg1)
        if name and name ~= "" then
            return name
        end
    end
    return nil
end

local function ParseInputValue(kind, raw)
    if kind == "itemId" then
        local id = tonumber(raw)
        if id and id > 0 then
            return id
        end
        return nil
    end
    local text = Trim(raw)
    if text ~= "" then
        return text
    end
    return nil
end

local function SharedL()
    return OneWoW.Locale:GetTable("shared")
end

local function ItemListSortStore()
    return OneWoW:GetCoreGlobal().itemListSort
end

--- Display sort for one item-ID list. Missing key is name.
---@param listKey string
---@return string mode "name"|"id"
function OneWoW_GUI:GetItemListSort(listKey)
    local value = ItemListSortStore()[listKey]
    if value == "id" then
        return "id"
    end
    return "name"
end

--- Persist display sort for one item-ID list.
---@param listKey string
---@param value string "name"|"id"
function OneWoW_GUI:SetItemListSort(listKey, value)
    if value == "id" then
        ItemListSortStore()[listKey] = "id"
    else
        ItemListSortStore()[listKey] = "name"
    end
end

--- Sort an entry array in place by the list's saved Name / Item ID preference.
---@param entries table
---@param listKey string
---@return table entries
function OneWoW_GUI:SortItemEntries(entries, listKey)
    local mode = self:GetItemListSort(listKey)
    if mode == "id" then
        sort(entries, function(a, b)
            local aid = tonumber(a.id) or 0
            local bid = tonumber(b.id) or 0
            if aid ~= bid then
                return aid < bid
            end
            return strcmputf8i(a.label or "", b.label or "") < 0
        end)
    else
        sort(entries, function(a, b)
            local cmp = strcmputf8i(a.label or "", b.label or "")
            if cmp ~= 0 then
                return cmp < 0
            end
            local aid = tonumber(a.id) or 0
            local bid = tonumber(b.id) or 0
            return aid < bid
        end)
    end
    return entries
end

--- Compact Name / Item ID dropdown for a sortKey. Caller SetPoints the button.
---@param parent Frame
---@param options table
---@return Button dropdown
---@return FontString textFS
function OneWoW_GUI:CreateItemListSortDropdown(parent, options)
    options = options or {}
    local sortKey = options.sortKey
    local drop, textFS = self:CreateDropdown(parent, {
        width = options.width or GUI.ENTRY_LIST_SORT_WIDTH,
        height = options.height or GUI.ENTRY_LIST_SORT_HEIGHT,
        text = NAME,
    })

    local function RefreshText()
        local mode = self:GetItemListSort(sortKey)
        if mode == "id" then
            textFS:SetText(SharedL().SORT_BY_ITEM_ID)
        else
            textFS:SetText(NAME)
        end
        drop._activeValue = mode
    end
    RefreshText()

    self:AttachFilterMenu(drop, {
        searchable = false,
        menuWidth = options.width or GUI.ENTRY_LIST_SORT_WIDTH,
        buildItems = function()
            return {
                { text = NAME, value = "name" },
                { text = SharedL().SORT_BY_ITEM_ID, value = "id" },
            }
        end,
        onSelect = function(value)
            self:SetItemListSort(sortKey, value)
            RefreshText()
            if options.onChange then
                options.onChange(value)
            end
        end,
        getActiveValue = function()
            return self:GetItemListSort(sortKey)
        end,
    })

    return drop, textFS
end

local function ClearFrameChildren(frame)
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
end

--- Label + edit box + Add button + optional chip dropzone.
--- drop.mode: "chip" | "panel" | "none". Panel mode builds no chip; use
--- handle:AttachDropTarget(frame) so the outer panel receives drags.
--- drop.align: "right" (default) pins the chip to the row's top-right; "left"
--- packs it after Add. Add is slightly shorter than the edit box / chip.
---@param parent Frame
---@param options table
---@return table handle
function OneWoW_GUI:CreateValueAddRow(parent, options)
    options = options or {}
    local height = options.height or GUI.VALUE_ADD_ROW_HEIGHT
    local inputOpts = options.input or {}
    local kind = inputOpts.kind or "itemId"
    local inputWidth = inputOpts.width or GUI.VALUE_ADD_INPUT_WIDTH
    local maxLetters = inputOpts.maxLetters or (kind == "itemId" and 10 or 64)
    local dropOpts = options.drop or {}
    local dropMode = dropOpts.mode or "none"
    local onAdd = options.onAdd
    local labelText = options.label or ""
    local addText = options.addText or ADD

    local defaultCursorTypes
    if kind == "itemId" then
        defaultCursorTypes = { "item" }
    else
        defaultCursorTypes = { "macro" }
    end
    local cursorTypes = dropOpts.cursorTypes or defaultCursorTypes

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(height)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local box = OneWoW_GUI:CreateEditBox(row, {
        width = inputWidth,
        height = height,
        maxLetters = maxLetters,
    })
    box:SetPoint("LEFT", label, "RIGHT", 8, 0)
    box:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    box:SetText("")
    if kind == "itemId" then
        box:SetNumeric(true)
    end

    local addHeight = options.addHeight or math.max(18, height - 2)
    local addBtn = OneWoW_GUI:CreateFitTextButton(row, {
        text = addText,
        height = addHeight,
        paddingX = options.addPaddingX or 10,
    })
    addBtn:SetPoint("LEFT", box, "RIGHT", 6, 0)

    local chip, chipText
    local chipAlign = dropOpts.align or "right"
    if dropMode == "chip" then
        chip = CreateFrame("Frame", nil, row, "BackdropTemplate")
        chip:SetSize(dropOpts.width or GUI.VALUE_ADD_CHIP_WIDTH, height)
        chip:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        chip:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        chip:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        chip:EnableMouse(true)

        chipText = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        chipText:SetPoint("CENTER")
        chipText:SetText(dropOpts.text or "")
        chipText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        if chipAlign == "left" then
            chip:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        else
            -- Top-right of the row (aligned with the list panel below when the row is full-width).
            chip:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        end
    end

    local packWidth = label:GetStringWidth() + 8 + inputWidth + 6 + addBtn:GetWidth()
    if chip and chipAlign == "left" then
        packWidth = packWidth + 8 + chip:GetWidth()
    end

    if options.yOffset ~= nil then
        local x = options.x or 12
        local rightInset = options.rightInset or 12
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, options.yOffset)
        if chip and chipAlign ~= "left" then
            row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightInset, options.yOffset)
        else
            row:SetWidth(packWidth)
        end
    elseif chip and chipAlign == "left" then
        row:SetWidth(packWidth)
    elseif not chip then
        row:SetWidth(packWidth)
    end

    local handle = {
        frame = row,
        label = label,
        editBox = box,
        addButton = addBtn,
        chip = chip,
        chipText = chipText,
        _enabled = true,
        _kind = kind,
        _cursorTypes = cursorTypes,
        _onAdd = onAdd,
    }

    local function tryAdd(value)
        if value == nil then return false end
        if not handle._enabled then return false end
        local ok = true
        if handle._onAdd then
            local result = handle._onAdd(value)
            if result == false then
                ok = false
            end
        end
        if ok then
            handle:Clear()
        end
        return ok
    end

    local function tryAddFromInput()
        local raw
        if box.GetSearchText then
            raw = box:GetSearchText()
        else
            raw = box:GetText()
        end
        if box.placeholderText and raw == box.placeholderText then
            raw = ""
        end
        return tryAdd(ParseInputValue(kind, raw))
    end

    local function tryAddFromCursor()
        local infoType, arg1 = GetCursorInfo()
        if not CursorAccepts(infoType, handle._cursorTypes) then
            return false
        end
        local value = ValueFromCursor(kind, infoType, arg1)
        if value == nil then return false end
        ClearCursor()
        return tryAdd(value)
    end

    handle.TryAddFromCursor = tryAddFromCursor

    addBtn:SetScript("OnClick", function()
        tryAddFromInput()
    end)

    box:SetScript("OnEnterPressed", function(eb)
        tryAddFromInput()
        eb:ClearFocus()
    end)

    local function wireDropTarget(target)
        if not target then return end
        target:EnableMouse(true)
        target:SetScript("OnReceiveDrag", function()
            tryAddFromCursor()
        end)
        target:SetScript("OnMouseUp", function()
            tryAddFromCursor()
        end)
        if target == chip then
            target:SetScript("OnEnter", function(dz)
                if not handle._enabled then return end
                dz:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            end)
            target:SetScript("OnLeave", function(dz)
                dz:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end)
        end
    end

    if chip then
        wireDropTarget(chip)
    end

    function handle:AttachDropTarget(frame)
        wireDropTarget(frame)
    end

    function handle:Clear()
        box:SetText("")
        box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        if box.ClearFocus then
            box:ClearFocus()
        end
    end

    function handle:SetEnabled(enabled)
        self._enabled = enabled and true or false
        if self._enabled then
            box:Enable()
            box:EnableMouse(true)
            addBtn:Enable()
            label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            if chip then
                chip:EnableMouse(true)
            end
            if chipText then
                chipText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        else
            box:ClearFocus()
            box:Disable()
            box:EnableMouse(false)
            addBtn:Disable()
            label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            if chip then
                chip:EnableMouse(false)
            end
            if chipText then
                chipText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end
    end

    function handle:GetHeight()
        return height
    end

    return handle
end

--- Keyed entry list with empty state. grow=true packs height to content;
--- otherwise options.height is fixed and content scrolls.
---@param parent Frame
---@param options table
---@return table handle
function OneWoW_GUI:CreateEntryList(parent, options)
    options = options or {}
    local grow = options.grow == true
    local fixedHeight = options.height
    local emptyText = options.emptyText or ""
    local getEntries = options.getEntries
    local onRemove = options.onRemove
    local createRow = options.createRow
    local rowHeightDefault = options.rowHeight or GUI.ENTRY_LIST_ROW_HEIGHT
    local x = options.x or 12
    local yOffset = options.yOffset
    local sortKey = options.sortKey

    local listFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listFrame:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    listFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    listFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    if yOffset ~= nil then
        listFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, yOffset)
        listFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(options.rightInset or 12), yOffset)
    end

    local handle = {
        frame = listFrame,
        _enabled = true,
        _removeButtons = {},
        _getEntries = getEntries,
        _onRemove = onRemove,
        _createRow = createRow,
        _rowHeight = rowHeightDefault,
        _emptyText = emptyText,
        _grow = grow,
        _sortKey = sortKey,
    }

    local toolbarH = 0
    if sortKey then
        toolbarH = GUI.ENTRY_LIST_SORT_BAR
        local toolbar = CreateFrame("Frame", nil, listFrame)
        toolbar:SetHeight(toolbarH)
        toolbar:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
        toolbar:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 0, 0)
        local drop = OneWoW_GUI:CreateItemListSortDropdown(toolbar, {
            sortKey = sortKey,
            onChange = function()
                handle:Refresh()
            end,
        })
        drop:SetPoint("RIGHT", toolbar, "RIGHT", -6, 0)
        handle._sortDropdown = drop
    end

    local body = CreateFrame("Frame", nil, listFrame)
    if sortKey then
        body:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -toolbarH)
        body:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 0, -toolbarH)
    else
        body:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
        body:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 0, 0)
    end

    local contentParent = body
    local scrollFrame, scrollChild
    if not grow then
        listFrame:SetHeight(fixedHeight or 120)
        body:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", 0, 0)
        body:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", 0, 0)
        scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(body, {
            name = options.scrollName,
        })
        contentParent = scrollChild
    end

    local emptyFS = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emptyFS:SetPoint("CENTER", body, "CENTER", 0, 0)
    emptyFS:SetJustifyH("CENTER")
    emptyFS:SetWordWrap(true)
    emptyFS:SetText(emptyText)
    emptyFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    emptyFS:Hide()

    handle.scrollFrame = scrollFrame
    handle.scrollChild = scrollChild
    handle.content = contentParent

    local function buildDefaultRow(row, entry, api)
        local iconSize = GUI.ENTRY_LIST_ICON_SIZE
        local left = 0
        if entry.icon then
            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(iconSize, iconSize)
            iconTex:SetPoint("LEFT", row, "LEFT", 0, 0)
            iconTex:SetTexture(entry.icon)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            left = iconSize + 6
        end

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(iconSize, iconSize)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        local capturedID = entry.id
        removeBtn:SetScript("OnClick", function()
            if not handle._enabled then return end
            if handle._onRemove then
                handle._onRemove(capturedID)
            end
            if handle.frame:GetParent() then
                api.RequestRefresh()
            end
        end)
        if not handle._enabled then
            removeBtn:Disable()
        end
        tinsert(handle._removeButtons, removeBtn)

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", row, "LEFT", left, 0)
        nameText:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        nameText:SetText(entry.label or tostring(entry.id))
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        return handle._rowHeight
    end

    function handle:GetFrame()
        return listFrame
    end

    function handle:GetContentFrame()
        return contentParent
    end

    function handle:Refresh()
        wipe(self._removeButtons)
        ClearFrameChildren(contentParent)

        local entries = self._getEntries and self._getEntries() or {}
        if self._sortKey then
            OneWoW_GUI:SortItemEntries(entries, self._sortKey)
        end
        local pad = GUI.ENTRY_LIST_PAD
        local rowOffset = -pad
        local hasItems = false

        local api = {
            RequestRefresh = function()
                handle:Refresh()
            end,
            IsEnabled = function()
                return handle._enabled
            end,
        }

        for i, entry in ipairs(entries) do
            hasItems = true
            local row = CreateFrame("Frame", nil, contentParent, "BackdropTemplate")
            row:SetPoint("TOPLEFT", contentParent, "TOPLEFT", 10, rowOffset)
            row:SetPoint("TOPRIGHT", contentParent, "TOPRIGHT", -10, rowOffset)
            row:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            row._zebraIndex = i
            api.zebraIndex = i
            OneWoW_GUI:ApplyListRowFill(row, { zebraIndex = i })

            local h
            if self._createRow then
                h = self._createRow(row, entry, api)
            else
                h = buildDefaultRow(row, entry, api)
            end
            h = h or self._rowHeight
            row:SetHeight(h)
            rowOffset = rowOffset - h - 2
        end

        if hasItems then
            emptyFS:Hide()
        else
            emptyFS:SetText(self._emptyText)
            emptyFS:Show()
        end

        if self._grow then
            local contentH = hasItems and (math.abs(rowOffset) + pad) or GUI.ENTRY_LIST_EMPTY_HEIGHT
            body:SetHeight(contentH)
            listFrame:SetHeight(contentH + toolbarH)
        else
            local contentH = hasItems and (math.abs(rowOffset) + pad) or 1
            contentParent:SetHeight(math.max(1, contentH))
            if scrollFrame and scrollFrame.UpdateScrollChildRect then
                scrollFrame:UpdateScrollChildRect()
            end
        end
    end

    function handle:SetEnabled(enabled)
        self._enabled = enabled and true or false
        for _, btn in ipairs(self._removeButtons) do
            if self._enabled then
                btn:Enable()
            else
                btn:Disable()
            end
        end
        if self._enabled then
            emptyFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            if self._sortDropdown then
                self._sortDropdown:Enable()
            end
        else
            emptyFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            if self._sortDropdown then
                self._sortDropdown:Disable()
            end
        end
    end

    function handle:GetHeight()
        return listFrame:GetHeight()
    end

    handle:Refresh()
    return handle
end

--- Chip add-row + entry list (+ optional Clear All footer). Returns newYOffset, handle.
---@param parent Frame
---@param options table
---@return number newYOffset
---@return table handle
function OneWoW_GUI:CreateItemListEditor(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local x = options.x or 12
    local rightInset = options.rightInset or 12
    local gapAfterAdd = options.gapAfterAdd or 10
    local gapAfterList = options.gapAfterList or 8

    local handle = {}

    local dropOpts = options.drop or {}
    if dropOpts.mode == nil then
        dropOpts = {
            mode = "chip",
            text = dropOpts.text,
            width = dropOpts.width,
            cursorTypes = dropOpts.cursorTypes,
            align = dropOpts.align,
        }
    end

    local addRow = OneWoW_GUI:CreateValueAddRow(parent, {
        yOffset = yOffset,
        x = x,
        rightInset = rightInset,
        label = options.label,
        addText = options.addText,
        input = options.input,
        drop = dropOpts,
        onAdd = function(value)
            local ok = true
            if options.onAdd then
                local result = options.onAdd(value)
                if result == false then
                    ok = false
                end
            end
            if ok then
                handle.list:Refresh()
            end
            return ok
        end,
    })
    handle.addRow = addRow

    yOffset = yOffset - addRow:GetHeight() - gapAfterAdd

    local listOpts = {
        yOffset = yOffset,
        x = x,
        rightInset = rightInset,
        emptyText = options.emptyText,
        getEntries = options.getEntries,
        onRemove = function(id)
            if options.onRemove then
                options.onRemove(id)
            end
        end,
        createRow = options.createRow,
        rowHeight = options.rowHeight,
        scrollName = options.scrollName,
        sortKey = options.sortKey,
    }
    if options.grow ~= false and not options.height then
        listOpts.grow = true
    else
        listOpts.height = options.height or 120
        listOpts.grow = false
    end

    local list = OneWoW_GUI:CreateEntryList(parent, listOpts)
    handle.list = list
    yOffset = yOffset - list:GetHeight() - gapAfterList

    if options.onClearAll then
        local clearBtn = OneWoW_GUI:CreateFitTextButton(parent, {
            text = options.clearText
                or OneWoW.Locale:GetOptional("shared", "CLEAR")
                or CLEAR_ALL,
            height = GUI.VALUE_ADD_ROW_HEIGHT,
            paddingX = 14,
        })
        -- Anchor under the list so grow-height refresh keeps Clear below content.
        clearBtn:SetPoint("TOPLEFT", list.frame, "BOTTOMLEFT", 0, -gapAfterList)
        clearBtn:SetScript("OnClick", function()
            options.onClearAll()
            list:Refresh()
        end)
        handle.clearButton = clearBtn
        yOffset = yOffset - clearBtn:GetHeight() - 8
    end

    function handle:Refresh()
        self.list:Refresh()
    end

    function handle:SetEnabled(enabled)
        self.addRow:SetEnabled(enabled)
        self.list:SetEnabled(enabled)
        if self.clearButton then
            if enabled then
                self.clearButton:Enable()
            else
                self.clearButton:Disable()
            end
        end
    end

    function handle:GetBottomY()
        return yOffset
    end

    return yOffset, handle
end

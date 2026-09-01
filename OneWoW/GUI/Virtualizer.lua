local OneWoW_GUI = OneWoW_GUI

-- Shared virtualized list engine.
--
-- Domain-agnostic scroll-windowing for large flat lists (same callback style as
-- CreateReorderDrag). The engine owns: ScrollFrame (or an adopted one), row
-- pool growth, scroll→index mapping, content height, selection, optional
-- keyboard nav. Consumers own: data (getCount/getEntry), row chrome
-- (createRow/bindRow), and any expand flattening (rebuild entries, then Refresh).
--
-- Layout:
--   * Fixed stride when only rowHeight is set (DevTool / Catalog browse).
--   * Variable when getRowHeight(index) is supplied (e.g. Vendors); prefix sums
--     rebuild on Refresh.
--
-- Expand-in-list is NOT engine-owned. Flatten child rows into getEntry, keep
-- fixed stride, Refresh. Mixed lists (group/section headers + rows) stay on
-- click-select: pass isSelectable so headers never become selectedIndex.
--
-- ReorderDrag ghosts: a pooled row with `_oneWoWReorderOrigPoints` is mid-drag
-- on UIParent. Skip reposition/bind so auto-scroll does not steal the ghost.
--
-- Usage:
--   api = OneWoW_GUI:CreateVirtualizer(parent, {
--       getCount = function() return #data end,          -- required
--       getEntry = function(i) return data[i] end,       -- required
--       onSelect = function(i, entry) ... end,           -- optional
--       isSelectable = function(i, entry) return true end, -- optional; default all
--       rowHeight = 22,                                  -- default stride
--       getRowHeight = function(i) return heights[i] end, -- optional variable
--       createRow = function(content, api) ... end,      -- optional factory
--       bindRow = function(row, i, entry, state) ... end,-- optional rebind
--       renderRow = function(row, i, entry, selected) end,-- legacy alias
--       numVisibleRows = 40,
--       enableKeyboardNav = true,
--       focusCompetitor = searchEditBox,
--       -- scrollFrame / content = adopt an existing scroll pair (optional)
--   })
--   api.Refresh()
--   api.SetSelectedIndex(1)

local CreateFrame = CreateFrame
local tinsert = tinsert
local wipe = wipe
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min

local DEFAULT_ROW_HEIGHT = 22
local DEFAULT_NUM_VISIBLE = 40
local DEFAULT_ROW_INSET = 2
local POOL_BUFFER_ROWS = 2

--- Binary search: largest i where prefix[i] <= scroll (prefix[0]=0, prefix[i]=top of row i+1).
---@param prefix number[]
---@param scroll number
---@return number startIndex 1-based
local function StartIndexFromPrefix(prefix, scroll)
    local n = #prefix
    if n == 0 then
        return 1
    end
    if scroll <= 0 then
        return 1
    end
    -- prefix[i] = y offset of row i (0-based top). Find largest i with prefix[i] <= scroll.
    local lo, hi = 1, n
    local ans = 1
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        if prefix[mid] <= scroll then
            ans = mid
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return ans
end

--- Create a virtualized list controller on parent (or an adopted scroll frame).
---@param parent Frame
---@param options table
---@return table|nil api
function OneWoW_GUI:CreateVirtualizer(parent, options)
    options = options or {}
    local getCount = options.getCount
    local getEntry = options.getEntry
    if not getCount or not getEntry then
        return nil
    end

    local name = options.name
    local rowHeight = options.rowHeight or DEFAULT_ROW_HEIGHT
    local getRowHeight = options.getRowHeight
    local numVisibleRows = options.numVisibleRows or DEFAULT_NUM_VISIBLE
    local onSelect = options.onSelect
    local createRow = options.createRow
    local bindRow = options.bindRow
    local renderRow = options.renderRow
    local enableKeyboardNav = options.enableKeyboardNav
    local focusCompetitor = options.focusCompetitor
    local selectOnClick = options.selectOnClick
    if selectOnClick == nil then
        selectOnClick = onSelect ~= nil
    end
    local isSelectable = options.isSelectable
    local rowInset = options.rowInset
    if rowInset == nil then
        rowInset = DEFAULT_ROW_INSET
    end
    local minStride = options.minRowHeight or rowHeight

    -- Legacy: renderRow(btn, index, entry, isSelected) → bindRow with state table.
    if not bindRow and renderRow then
        bindRow = function(row, index, entry, state)
            renderRow(row, index, entry, state and state.selected)
        end
    end

    local scrollFrame = options.scrollFrame
    local content = options.content
    local ownedScroll = false

    local VIRT_INSET = 4
    local VIRT_BAR_INSET = 14

    if not scrollFrame then
        ownedScroll = true
        scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", VIRT_INSET, -VIRT_INSET)
        scrollFrame:SetPoint("BOTTOMRIGHT", -VIRT_BAR_INSET, VIRT_INSET)
        self:ApplyScrollBarStyle(scrollFrame.ScrollBar, parent, -2)
        scrollFrame._oneWoWOnScrollBarShown = function(shown)
            local right = shown and -VIRT_BAR_INSET or -VIRT_INSET
            scrollFrame:ClearAllPoints()
            scrollFrame:SetPoint("TOPLEFT", VIRT_INSET, -VIRT_INSET)
            scrollFrame:SetPoint("BOTTOMRIGHT", right, VIRT_INSET)
        end
        local sb = scrollFrame.ScrollBar
        scrollFrame._oneWoWOnScrollBarShown(sb and sb:IsShown() and not sb._oneWoWAlwaysHidden)
    end

    if not content then
        local contentName = name and (name .. "Content") or nil
        content = CreateFrame("Frame", contentName, scrollFrame)
        content:SetHeight(1)
        scrollFrame:SetScrollChild(content)
    end

    local state = { selectedIndex = nil }
    local listRows = {}
    local scrollBar = scrollFrame.ScrollBar
    local prefix = {} -- prefix[i] = top Y of row i (0 for i==1); #prefix == n
    local totalHeight = 1
    local variableLayout = getRowHeight ~= nil

    local function rowIsSelectable(idx)
        if not isSelectable then
            return true
        end
        if not idx or idx < 1 then
            return false
        end
        local entry = getEntry(idx)
        return entry ~= nil and isSelectable(idx, entry) and true or false
    end

    local api

    local function setScrollPosition(pos)
        if scrollBar then
            scrollBar:SetValue(pos)
        else
            scrollFrame:SetVerticalScroll(pos)
        end
    end

    local function heightOf(index)
        if variableLayout then
            return getRowHeight(index) or rowHeight
        end
        return rowHeight
    end

    local function rebuildPrefix(n)
        wipe(prefix)
        local y = 0
        for i = 1, n do
            prefix[i] = y
            y = y + heightOf(i)
        end
        totalHeight = max(y, 1)
    end

    local function topOf(index)
        if variableLayout then
            return prefix[index] or 0
        end
        return (index - 1) * rowHeight
    end

    local function ensureIndexVisible(idx)
        local n = getCount()
        if n <= 0 or idx < 1 or idx > n then
            return
        end
        local scroll = scrollFrame:GetVerticalScroll()
        local viewH = scrollFrame:GetHeight()
        local top = topOf(idx)
        local bottom = top + heightOf(idx)
        if top < scroll then
            setScrollPosition(top)
        elseif bottom > scroll + viewH then
            setScrollPosition(bottom - viewH)
        end
    end

    local function defaultBind(row, _, entry, _)
        if row.SetText then
            row:SetText(entry.displayName or tostring(entry))
        end
    end

    -- Forward-declared: Refresh grows the pool; createPoolRow is wired below.
    local ensureRowPool

    local function updateVisibleRows()
        local n = getCount()
        local scroll = scrollFrame:GetVerticalScroll()
        local startIdx
        if variableLayout then
            startIdx = StartIndexFromPrefix(prefix, scroll)
        else
            startIdx = floor(scroll / rowHeight) + 1
        end
        if startIdx < 1 then
            startIdx = 1
        end

        for i, row in ipairs(listRows) do
            if row._oneWoWReorderOrigPoints then
                -- ReorderDrag ghost: leave parent and anchors alone.
            else
                local idx = startIdx + i - 1
                local entry = (idx <= n) and getEntry(idx) or nil
                if entry then
                    local h = heightOf(idx)
                    local y = topOf(idx)
                    row:ClearAllPoints()
                    row:SetHeight(h)
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", rowInset, -y)
                    row:SetPoint("RIGHT", content, "RIGHT", -rowInset, 0)
                    row.entryIndex = idx
                    row._zebraIndex = idx
                    local rowState = {
                        selected = state.selectedIndex == idx and rowIsSelectable(idx),
                        zebraIndex = idx,
                    }
                    -- Match legacy CreateVirtualizedList: selection font before consumer bind.
                    if row.SetNormalFontObject then
                        row:SetNormalFontObject(rowState.selected and GameFontHighlightSmall or GameFontNormalSmall)
                    end
                    if bindRow then
                        bindRow(row, idx, entry, rowState)
                    else
                        defaultBind(row, idx, entry, rowState)
                    end
                    row:Show()
                else
                    row:Hide()
                    row.entryIndex = nil
                end
            end
        end
    end

    local function Refresh()
        if not scrollFrame or not content then
            return
        end
        -- Adopted scrolls may already be sized when CreateVirtualizer runs, so
        -- OnSizeChanged alone never grows past the initial numVisibleRows seed.
        ensureRowPool()
        local n = getCount()
        if n <= 0 then
            state.selectedIndex = nil
        elseif state.selectedIndex and state.selectedIndex > n then
            state.selectedIndex = n
        end
        if state.selectedIndex and not rowIsSelectable(state.selectedIndex) then
            state.selectedIndex = nil
        end

        if variableLayout then
            rebuildPrefix(n)
        else
            wipe(prefix)
            totalHeight = max(n * rowHeight, 1)
        end
        content:SetHeight(totalHeight)

        local scrollMax = max(totalHeight - scrollFrame:GetHeight(), 0)
        local vs = scrollFrame:GetVerticalScroll()
        if vs > scrollMax then
            setScrollPosition(scrollMax)
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
        local clamped = max(1, min(idx, n))
        if not rowIsSelectable(clamped) then
            return
        end
        state.selectedIndex = clamped
        Refresh()
        ensureIndexVisible(clamped)
        if onSelect then
            local entry = getEntry(clamped)
            if entry then
                onSelect(clamped, entry)
            end
        end
    end

    local function GetSelectedIndex()
        return state.selectedIndex
    end

    local function defaultCreateRow(rowParent)
        local btn = CreateFrame("Button", nil, rowParent)
        btn:SetHeight(rowHeight)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)
        btn:SetScript("OnEnter", function(myself)
            local t = myself._tooltipFullText
            if not t or t == "" then
                return
            end
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
            local firstLine
            for line in tostring(t):gmatch("([^\n]+)") do
                if not firstLine then
                    firstLine = line
                    GameTooltip:SetText(line, r, g, b)
                else
                    GameTooltip:AddLine(line, r, g, b, true)
                end
            end
            if not firstLine then
                GameTooltip:SetText(tostring(t), r, g, b)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
        return btn
    end

    local function wireRow(row)
        if selectOnClick then
            -- HookScript requires an existing handler on the frame.
            if not row:GetScript("OnClick") then
                row:SetScript("OnClick", function() end)
            end
            row:HookScript("OnClick", function(myself, button)
                if button and button ~= "LeftButton" then
                    return
                end
                if myself.entryIndex and rowIsSelectable(myself.entryIndex) then
                    SetSelectedIndex(myself.entryIndex)
                end
            end)
        end
        -- Custom createRow can set _tooltipFullText; attach shared tooltip if none.
        if not row:GetScript("OnEnter") then
            row:SetScript("OnEnter", function(myself)
                local t = myself._tooltipFullText
                if not t or t == "" then
                    return
                end
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
                local firstLine
                for line in tostring(t):gmatch("([^\n]+)") do
                    if not firstLine then
                        firstLine = line
                        GameTooltip:SetText(line, r, g, b)
                    else
                        GameTooltip:AddLine(line, r, g, b, true)
                    end
                end
                if not firstLine then
                    GameTooltip:SetText(tostring(t), r, g, b)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", GameTooltip_Hide)
        end
    end

    local function createPoolRow()
        local row
        if createRow then
            row = createRow(content, api)
        else
            row = defaultCreateRow(content)
        end
        wireRow(row)
        tinsert(listRows, row)
        return row
    end

    ensureRowPool = function()
        local viewH = scrollFrame:GetHeight()
        if viewH <= 0 then
            return
        end
        local needed = ceil(viewH / minStride) + POOL_BUFFER_ROWS
        for _ = #listRows + 1, needed do
            createPoolRow()
        end
    end

    api = {
        listPanel = parent,
        listScroll = scrollFrame,
        listContent = content,
        Refresh = Refresh,
        SetSelectedIndex = SetSelectedIndex,
        GetSelectedIndex = GetSelectedIndex,
        ownedScroll = ownedScroll,
    }

    scrollFrame:HookScript("OnSizeChanged", function(_, w)
        content:SetWidth(w)
        ensureRowPool()
        Refresh()
    end)

    for _ = 1, numVisibleRows do
        createPoolRow()
    end

    -- First layout pass: adopted scrolls are often already sized, so the
    -- OnSizeChanged hook above may never fire until the next resize.
    ensureRowPool()
    Refresh()
    -- Owned scrolls: replace OnVerticalScroll. Adopted (e.g. CreateSplitPanel):
    -- hook so we do not clobber any pre-existing handler.
    if ownedScroll then
        scrollFrame:SetScript("OnVerticalScroll", updateVisibleRows)
    else
        if not scrollFrame:GetScript("OnVerticalScroll") then
            scrollFrame:SetScript("OnVerticalScroll", function() end)
        end
        scrollFrame:HookScript("OnVerticalScroll", updateVisibleRows)
    end

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
        parent:SetScript("OnKeyDown", function(myself, key)
            if key == "UP" or key == "DOWN" then
                myself:SetPropagateKeyboardInput(false)
                local n = getCount()
                if n <= 0 then
                    return
                end
                local step = (key == "UP") and -1 or 1
                local cur = state.selectedIndex or 0
                local nextIdx
                if cur == 0 then
                    nextIdx = (step > 0) and 1 or n
                else
                    nextIdx = cur + step
                end
                while nextIdx >= 1 and nextIdx <= n do
                    if rowIsSelectable(nextIdx) then
                        SetSelectedIndex(nextIdx)
                        return
                    end
                    nextIdx = nextIdx + step
                end
            else
                myself:SetPropagateKeyboardInput(true)
            end
        end)
    end

    return api
end

--- Compatibility wrapper: picker-list defaults over CreateVirtualizer.
--- Existing DevTool call sites (renderRow, etc.) keep working.
---@param parent Frame
---@param options table
---@return table|nil
function OneWoW_GUI:CreateVirtualizedList(parent, options)
    options = options or {}
    if not options.getCount or not options.getEntry or not options.onSelect then
        return nil
    end
    return self:CreateVirtualizer(parent, options)
end

local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

local format = format
local floor = math.floor
local ipairs = ipairs
local max = math.max
local min = math.min
local tostring = tostring
local BreakUpLargeNumbers = _G["BreakUpLargeNumbers"]

local BOOKMARK_ICON_PATH = format("Interface\\AddOns\\%s\\Media\\icon-fav.png", ADDON_NAME)

local NODE_HEIGHT = 18
local INDENT_PX = 14

local GB

local function ensureBrowser()
    if not GB then
        GB = Addon.GlobalsBrowser
    end
    return GB
end

local function getDU()
    return Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
end

local function setActionButtonEnabled(btn, enabled)
    if not btn then
        return
    end
    btn:EnableMouse(enabled)
    if enabled then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        if btn.text then
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        if btn.text then
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end
end

local function refreshToolbarButton(btn, enabled, active)
    if not btn then
        return
    end
    btn:EnableMouse(enabled)
    if not enabled then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        if btn.text then
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        return
    end
    if active then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        if btn.text then
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end
        return
    end
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    if btn.text then
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

local function ensureListRowBookmarkIcon(btn, rowHeight)
    if btn._globalsBookmarkIcon then
        return
    end
    local size = 14
    local pad = 8
    local topInset = -floor(((rowHeight or 20) - size) / 2 + 0.5)
    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetSize(size, size)
    tex:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -pad, topInset)
    btn._globalsBookmarkIcon = tex
end

local function styleListButtonText(btn)
    local fs = btn:GetFontString()
    if not fs then
        return
    end
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    if fs.SetWordWrap then
        fs:SetWordWrap(false)
    end
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
    if btn._globalsBookmarkIcon and btn._globalsBookmarkIcon:IsShown() then
        fs:SetPoint("RIGHT", btn._globalsBookmarkIcon, "LEFT", -4, 0)
    else
        fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    end
end

local function attachTooltip(widget, text)
    if not widget or not text or text == "" then
        return
    end
    if widget.EnableMouse then
        widget:EnableMouse(true)
    end
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", GameTooltip_Hide)
end

local function scheduleFilterRefresh(tab)
    if tab._filterTicker then
        tab._filterTicker:Cancel()
        tab._filterTicker = nil
    end
    tab._filterTicker = C_Timer.NewTimer(0.12, function()
        tab._filterTicker = nil
        if not tab.searchBox then
            return
        end
        GB:SetFilterText(tab.searchBox:GetSearchText())
        Addon.UI.GlobalsTab_RefreshList(tab)
        Addon.UI.GlobalsTab_RestoreSelection(tab, true)
    end)
end

local function scheduleTreeFilterRefresh(tab)
    if tab._treeFilterTicker then
        tab._treeFilterTicker:Cancel()
        tab._treeFilterTicker = nil
    end
    tab._treeFilterTicker = C_Timer.NewTimer(0.12, function()
        tab._treeFilterTicker = nil
        if not tab.treeSearchBox then
            return
        end
        GB:SetTreeFilterText(tab.treeSearchBox:GetSearchText())
        Addon.UI.GlobalsTab_RebuildTree(tab)
    end)
end

local function findFilteredIndexForEntry(targetEntry)
    if not targetEntry then
        return nil
    end
    local targetBookmarkKey = targetEntry.bookmarkKey
    local targetReference = targetEntry.reference
    for index = 1, GB:GetFilteredCount() do
        local entry = GB:GetFilteredEntry(index)
        if entry then
            if targetBookmarkKey and entry.bookmarkKey == targetBookmarkKey then
                return index
            end
            if not targetBookmarkKey and targetReference and entry.reference == targetReference then
                return index
            end
        end
    end
    return nil
end

local function saveCurrentRootIdentity(tab)
    if not tab or not tab.selectedRootEntry then
        return nil
    end
    return {
        reference = tab.selectedRootEntry.reference,
        bookmarkKey = tab.selectedRootEntry.bookmarkKey,
    }
end

local function restoreCurrentRootIdentity(tab, identity)
    if tab and identity then
        tab.selectedRootEntry = {
            reference = identity.reference,
            bookmarkKey = identity.bookmarkKey,
        }
    end
end

local function getRootIdentity(entry)
    if not entry then
        return nil
    end
    return entry.bookmarkKey or entry.reference
end

local function clearTreeBuildState(tab)
    if not tab then
        return
    end
    tab._lastTreeRootIdentity = nil
    tab._lastTreeIndexVersion = nil
    tab._lastTreeFilterText = nil
end

local function getCurrentTarget(tab)
    return tab.selectedTreeNode or tab.selectedRootEntry
end

local function formatRootCountText()
    local count = GB and GB:GetFilteredCount() or 0
    local countText = BreakUpLargeNumbers and BreakUpLargeNumbers(count) or tostring(count)
    return format("%s %s", countText, L["GLOBALS_COUNT_ENTRIES"])
end

local function updateRootCountLabel(tab)
    if tab and tab.rootCountText then
        tab.rootCountText:SetText(formatRootCountText())
    end
end

local function updateHeader(tab)
    local rootTarget = tab.selectedRootEntry
    local pathTarget = tab.selectedTreeNode or rootTarget
    if not rootTarget then
        tab.nameText:SetText(L["GLOBALS_MSG_SELECT"])
        tab.metaText:SetText(" ")
        tab.pathText:SetText(" ")
        return
    end
    tab.nameText:SetText(GB:GetHeaderTitle(rootTarget))
    tab.metaText:SetText(GB:GetHeaderSubtitle(rootTarget))
    tab.pathText:SetText(GB:GetBreadcrumb(pathTarget))
end

local function updateActionButtons(tab)
    local target = getCurrentTarget(tab)
    local hasRoot = tab.selectedRootEntry ~= nil
    local isBookmarked = hasRoot and GB:IsBookmarked(tab.selectedRootEntry)
    setActionButtonEnabled(tab.copyReferenceBtn, target and GB:GetCopyReference(target) ~= nil)
    setActionButtonEnabled(tab.copyValueBtn, target ~= nil)
    setActionButtonEnabled(tab.homeBtn, tab.selectedTreeNode ~= nil)
    setActionButtonEnabled(tab.upBtn, tab.selectedTreeNode and tab.selectedTreeNode.parentNode ~= nil)
    setActionButtonEnabled(tab.expandAllBtn, hasRoot)
    setActionButtonEnabled(tab.collapseAllBtn, hasRoot)
    refreshToolbarButton(tab.bookmarkBtn, hasRoot, isBookmarked)
    refreshToolbarButton(tab.favoritesBtn, true, GB.favoritesOnly)
    if tab.bookmarkBtn then
        local bookmarkText = (isBookmarked and (L["BTN_REMOVE_BOOKMARK"])) or (L["BTN_BOOKMARK"])
        if tab.bookmarkBtn.SetFitText then
            tab.bookmarkBtn:SetFitText(bookmarkText)
        elseif tab.bookmarkBtn.text then
            tab.bookmarkBtn.text:SetText(bookmarkText)
        end
    end
    if tab.noisyRootsCheck then
        tab.noisyRootsCheck:SetChecked(GB.includeNoisyRoots and true or false)
    end
end

local function applyTreeSelection(tab, node)
    tab.selectedTreeNode = node
    updateHeader(tab)
    updateActionButtons(tab)
end

function Addon.UI.GlobalsTab_RebuildTree(tab)
    if not tab or not tab.tree then
        return
    end
    tab.selectedTreeNode = nil
    tab.tree:SetSelectedNode(nil)
    if tab.selectedRootEntry then
        tab.tree:SetNodes(GB:BuildValueTree(tab.selectedRootEntry))
        if GB.treeFilterText ~= "" then
            tab.tree:ExpandAll()
        end
        tab._lastTreeRootIdentity = getRootIdentity(tab.selectedRootEntry)
        tab._lastTreeIndexVersion = GB:GetIndexVersion()
        tab._lastTreeFilterText = GB.treeFilterText
    else
        tab.tree:SetNodes({})
        clearTreeBuildState(tab)
    end
    updateHeader(tab)
    updateActionButtons(tab)
end

local function createGlobalsTree(parentContent, scrollFrame, tab)
    local tree = {}
    tree.parentContent = parentContent
    tree.scrollFrame = scrollFrame
    tree.rootNodes = {}
    tree.nodeFramePool = {}
    tree.expandedNodes = {}
    tree.selectedNodeId = nil
    tree.pendingScroll = false

    function tree:Clear()
        for _, nodeFrame in ipairs(self.nodeFramePool) do
            nodeFrame:Hide()
        end
        self.rootNodes = {}
        self.expandedNodes = {}
        self.selectedNodeId = nil
        self.pendingScroll = false
        self.parentContent:SetHeight(1)
    end

    function tree:SetNodes(nodes)
        self:Clear()
        self.rootNodes = nodes or {}
        self:Render()
    end

    function tree:SetSelectedNode(node)
        if not node then
            self.selectedNodeId = nil
            self.pendingScroll = false
        else
            self.selectedNodeId = node.id
            self.pendingScroll = true
        end
        self:Render()
    end

    function tree:ExpandNode(node)
        if not node or not node.hasChildren then
            return
        end
        if node.children == nil then
            GB:PopulateNodeChildren(node)
        end
        self.expandedNodes[node.id] = true
        self:Render()
    end

    function tree:CollapseNode(node)
        if not node then
            return
        end
        self.expandedNodes[node.id] = false
        self:Render()
    end

    function tree:ToggleNode(node)
        if not node or not node.hasChildren then
            return
        end
        if self.expandedNodes[node.id] then
            self:CollapseNode(node)
        else
            self:ExpandNode(node)
        end
    end

    function tree:CollapseAll()
        self.expandedNodes = {}
        self:Render()
    end

    function tree:ExpandAll()
        local function expandNodes(nodes)
            if not nodes then
                return
            end
            for _, node in ipairs(nodes) do
                if node.hasChildren then
                    if node.children == nil then
                        GB:PopulateNodeChildren(node)
                    end
                    self.expandedNodes[node.id] = true
                    if node.children and #node.children > 0 then
                        expandNodes(node.children)
                    end
                end
            end
        end
        expandNodes(self.rootNodes)
        self:Render()
    end

    local function getOrCreateNodeFrame(index)
        local nodeFrame = tree.nodeFramePool[index]
        if nodeFrame then
            return nodeFrame
        end

        nodeFrame = CreateFrame("Button", nil, parentContent)
        nodeFrame:SetHeight(NODE_HEIGHT)
        nodeFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        nodeFrame.bg = nodeFrame:CreateTexture(nil, "BACKGROUND")
        nodeFrame.bg:SetAllPoints()
        nodeFrame.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        nodeFrame.bg:Hide()

        nodeFrame.toggle = nodeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nodeFrame.toggle:SetPoint("LEFT", 0, 0)
        nodeFrame.toggle:SetWidth(14)
        nodeFrame.toggle:SetJustifyH("CENTER")

        nodeFrame.label = nodeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nodeFrame.label:SetPoint("LEFT", nodeFrame.toggle, "RIGHT", 2, 0)
        nodeFrame.label:SetPoint("RIGHT", nodeFrame, "RIGHT", -2, 0)
        nodeFrame.label:SetJustifyH("LEFT")

        nodeFrame:SetScript("OnEnter", function(self)
            self.bg:Show()
        end)

        nodeFrame:SetScript("OnLeave", function(self)
            if not self.isSelectedStyle then
                self.bg:Hide()
            end
        end)

        nodeFrame:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then
                return
            end
            local cursorX = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            local frameLeft = self:GetLeft() * scale
            local toggleEnd = frameLeft + ((self.nodeData and self.nodeData.depth) or 0) * INDENT_PX * scale + 14 * scale
            self.isToggleHit = cursorX < toggleEnd
        end)

        nodeFrame:SetScript("OnClick", function(self, button)
            local node = self.nodeData
            if not node then
                return
            end
            if button == "RightButton" then
                local copyText = GB:GetCopyReference(node) or node.text
                if copyText then
                    Addon:CopyToClipboard(copyText)
                end
                return
            end
            if node.isTruncated then
                if GB:LoadMoreNode(node) then
                    tree:Render()
                end
                return
            end
            if node.isInfoNode then
                return
            end
            if self.isToggleHit and node.hasChildren then
                tree:ToggleNode(node)
                return
            end
            tree:SetSelectedNode(node)
            applyTreeSelection(tab, node)
        end)

        tree.nodeFramePool[index] = nodeFrame
        return nodeFrame
    end

    function tree:Render()
        local visibleNodes = {}

        local function walk(nodes, depth)
            if not nodes then
                return
            end
            for _, node in ipairs(nodes) do
                node.depth = depth
                visibleNodes[#visibleNodes + 1] = node
                if self.expandedNodes[node.id] and node.children and #node.children > 0 then
                    walk(node.children, depth + 1)
                end
            end
        end

        walk(self.rootNodes, 0)

        for index = #visibleNodes + 1, #self.nodeFramePool do
            if self.nodeFramePool[index] then
                self.nodeFramePool[index]:Hide()
            end
        end

        for index, node in ipairs(visibleNodes) do
            local nodeFrame = getOrCreateNodeFrame(index)
            nodeFrame.nodeData = node
            nodeFrame:ClearAllPoints()
            nodeFrame:SetPoint("TOPLEFT", parentContent, "TOPLEFT", node.depth * INDENT_PX, -(index - 1) * NODE_HEIGHT)
            nodeFrame:SetPoint("RIGHT", parentContent, "RIGHT", 0, 0)

            if node.isTruncated then
                nodeFrame.toggle:SetText("+")
            elseif node.hasChildren then
                nodeFrame.toggle:SetText(self.expandedNodes[node.id] and "-" or "+")
            else
                nodeFrame.toggle:SetText(" ")
            end

            local isSelected = node.id == self.selectedNodeId
            nodeFrame.isSelectedStyle = isSelected
            if isSelected then
                nodeFrame.bg:Show()
                local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_ACCENT")
                nodeFrame.label:SetText(format("|cFF%02x%02x%02x%s|r", floor(r * 255), floor(g * 255), floor(b * 255), node.text or ""))
            else
                nodeFrame.bg:Hide()
                nodeFrame.label:SetText(node.text or "")
            end

            nodeFrame:Show()
        end

        local totalHeight = max(#visibleNodes * NODE_HEIGHT, 1)
        parentContent:SetHeight(totalHeight)

        if self.pendingScroll and self.selectedNodeId then
            self.pendingScroll = false
            for index, node in ipairs(visibleNodes) do
                if node.id == self.selectedNodeId then
                    local selectedY = (index - 1) * NODE_HEIGHT
                    local scrollHeight = scrollFrame:GetHeight()
                    local targetScroll = selectedY - (scrollHeight / 2) + (NODE_HEIGHT / 2)
                    targetScroll = max(0, min(targetScroll, totalHeight - scrollHeight))
                    scrollFrame:SetVerticalScroll(targetScroll)
                    break
                end
            end
        end
    end

    return tree
end

function Addon.UI.GlobalsTab_RefreshList(tab)
    if tab and tab.virtualizedList then
        tab.virtualizedList.Refresh()
    end
    updateRootCountLabel(tab)
end

function Addon.UI.GlobalsTab_RestoreSelection(tab, preferFirst)
    if not tab or not tab.virtualizedList then
        return
    end

    local count = GB:GetFilteredCount()
    if count <= 0 then
        tab.virtualizedList.SetSelectedIndex(nil)
        tab.selectedListIndex = nil
        tab.selectedRootEntry = nil
        tab.selectedTreeNode = nil
        tab.tree:SetNodes({})
        clearTreeBuildState(tab)
        updateHeader(tab)
        updateActionButtons(tab)
        return
    end

    local targetIndex = findFilteredIndexForEntry(tab.selectedRootEntry)
    if not targetIndex and preferFirst then
        targetIndex = 1
    end

    if targetIndex then
        tab.virtualizedList.SetSelectedIndex(targetIndex)
    else
        tab.virtualizedList.SetSelectedIndex(nil)
        tab.selectedListIndex = nil
        tab.selectedRootEntry = nil
        tab.selectedTreeNode = nil
        tab.tree:SetNodes({})
        clearTreeBuildState(tab)
        updateHeader(tab)
        updateActionButtons(tab)
    end
end

local function applyListSelection(tab, index)
    local entry = GB:GetFilteredEntry(index)
    local nextIdentity = getRootIdentity(entry)
    local currentIdentity = getRootIdentity(tab.selectedRootEntry)
    tab.selectedListIndex = index
    tab.selectedRootEntry = entry
    if nextIdentity
        and nextIdentity == currentIdentity
        and tab._lastTreeRootIdentity == nextIdentity
        and tab._lastTreeIndexVersion == GB:GetIndexVersion()
        and tab._lastTreeFilterText == GB.treeFilterText
    then
        updateHeader(tab)
        updateActionButtons(tab)
        return
    end
    Addon.UI.GlobalsTab_RebuildTree(tab)
end

function Addon.UI:CreateGlobalsBrowserTab(parent)
    GB = ensureBrowser()
    local DU = getDU()
    local rowHeight = DU.GLOBALS_BROWSER_LIST_ROW_HEIGHT or 20
    local numRows = DU.GLOBALS_BROWSER_LIST_VISIBLE_ROWS or 40
    local leftDefault = DU.GLOBALS_BROWSER_LEFT_PANE_DEFAULT_WIDTH or 300
    local leftMin = DU.GLOBALS_BROWSER_LEFT_PANE_MIN_WIDTH or 200
    local rightMin = DU.GLOBALS_BROWSER_RIGHT_PANE_MIN_WIDTH or 320
    local dividerWidth = DU.FRAME_INSPECTOR_DIVIDER_WIDTH or 6
    local splitPadding = dividerWidth + 10

    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local searchBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 180,
        height = 22,
        placeholderText = L["LABEL_FILTER"],
        onTextChanged = function()
            scheduleFilterRefresh(tab)
        end,
    })
    searchBox:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    tab.searchBox = searchBox

    local categoryDropdown = OneWoW_GUI:CreateDropdown(tab, { width = 120, height = 22, text = "" })
    categoryDropdown:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    OneWoW_GUI:AttachFilterMenu(categoryDropdown, {
        searchable = false,
        menuHeight = 120,
        getActiveValue = function()
            return GB.categoryFilter
        end,
        buildItems = function()
            return {
                { value = GB.CATEGORY_ALL, text = L["GLOBALS_FILTER_ALL"] },
                { value = GB.CATEGORY_GLOBALS, text = L["GLOBALS_FILTER_GLOBALS"] },
                { value = GB.CATEGORY_ENUM, text = L["GLOBALS_FILTER_ENUM"] },
                { value = GB.CATEGORY_ADDON_DATA, text = L["GLOBALS_FILTER_ADDON_DATA"] },
            }
        end,
        onSelect = function(value)
            GB:SetCategoryFilter(value)
            if categoryDropdown._text then
                categoryDropdown._text:SetText((value == GB.CATEGORY_GLOBALS and (L["GLOBALS_FILTER_GLOBALS"]))
                    or (value == GB.CATEGORY_ENUM and (L["GLOBALS_FILTER_ENUM"]))
                    or (value == GB.CATEGORY_ADDON_DATA and (L["GLOBALS_FILTER_ADDON_DATA"]))
                    or (L["GLOBALS_FILTER_ALL"]))
            end
            local noisyRelevant = (value == GB.CATEGORY_ALL or value == GB.CATEGORY_GLOBALS)
            if tab.noisyRootsCheck then
                if noisyRelevant then
                    tab.noisyRootsCheck:Enable()
                    if tab.noisyRootsCheck.label then
                        tab.noisyRootsCheck.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    end
                else
                    tab.noisyRootsCheck:Disable()
                    if tab.noisyRootsCheck.label then
                        tab.noisyRootsCheck.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    end
                end
            end
            tab.selectedRootEntry = nil
            Addon.UI.GlobalsTab_RefreshList(tab)
            Addon.UI.GlobalsTab_RestoreSelection(tab, true)
        end,
    })
    tab.categoryDropdown = categoryDropdown
    if categoryDropdown._text then
        categoryDropdown._text:SetText(L["GLOBALS_FILTER_ALL"])
    end

    local refreshBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["GLOBALS_BTN_REFRESH"],
        height = 22,
        minWidth = 60,
    })
    refreshBtn:SetPoint("LEFT", categoryDropdown, "RIGHT", 6, 0)
    refreshBtn:SetScript("OnClick", function()
        local currentIdentity = saveCurrentRootIdentity(tab)
        GB:RefreshIndex()
        Addon.UI.GlobalsTab_RefreshList(tab)
        restoreCurrentRootIdentity(tab, currentIdentity)
        Addon.UI.GlobalsTab_RestoreSelection(tab, true)
    end)

    local favoritesBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_FAVORITES"],
        height = 22,
        minWidth = 70,
    })
    favoritesBtn:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -5)
    favoritesBtn:SetScript("OnClick", function()
        GB:SetFavoritesOnly(not GB.favoritesOnly)
        Addon.UI.GlobalsTab_RefreshList(tab)
        Addon.UI.GlobalsTab_RestoreSelection(tab, true)
        updateActionButtons(tab)
    end)
    tab.favoritesBtn = favoritesBtn

    local bookmarkBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_BOOKMARK"],
        height = 22,
        minWidth = 82,
    })
    bookmarkBtn:SetPoint("LEFT", favoritesBtn, "RIGHT", 6, 0)
    bookmarkBtn:SetScript("OnClick", function()
        if not tab.selectedRootEntry then
            return
        end
        GB:ToggleBookmark(tab.selectedRootEntry)
        Addon.UI.GlobalsTab_RefreshList(tab)
        Addon.UI.GlobalsTab_RestoreSelection(tab, true)
        updateActionButtons(tab)
    end)
    tab.bookmarkBtn = bookmarkBtn

    local noisyRootsCheck = OneWoW_GUI:CreateCheckbox(tab, {
        label = L["GLOBALS_TOGGLE_NOISY_ROOTS"],
        checked = GB.includeNoisyRoots,
        onClick = function(self)
            local currentIdentity = saveCurrentRootIdentity(tab)
            GB:SetIncludeNoisyRoots(self:GetChecked())
            Addon.UI.GlobalsTab_RefreshList(tab)
            restoreCurrentRootIdentity(tab, currentIdentity)
            Addon.UI.GlobalsTab_RestoreSelection(tab, true)
        end,
    })
    noisyRootsCheck:SetPoint("LEFT", bookmarkBtn, "RIGHT", 10, 0)
    tab.noisyRootsCheck = noisyRootsCheck
    attachTooltip(noisyRootsCheck, L["GLOBALS_TOGGLE_NOISY_ROOTS_TIP"])
    attachTooltip(noisyRootsCheck.label, L["GLOBALS_TOGGLE_NOISY_ROOTS_TIP"])

    local rootCountText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rootCountText:SetPoint("LEFT", noisyRootsCheck.label, "RIGHT", 8, 0)
    rootCountText:SetJustifyH("LEFT")
    rootCountText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rootCountText:SetText("")
    tab.rootCountText = rootCountText

    local savedListWidth = Addon.db.global.globalsBrowserLeftPaneWidth
    local initialListWidth = leftDefault
    if type(savedListWidth) == "number" and savedListWidth >= leftMin then
        initialListWidth = savedListWidth
    end

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = initialListWidth, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", favoritesBtn, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(initialListWidth)
    self:StyleContentPanel(leftPanel)
    rootCountText:ClearAllPoints()
    rootCountText:SetPoint("LEFT", noisyRootsCheck.label, "RIGHT", 8, 0)

    local listAPI = OneWoW_GUI:CreateVirtualizedList(leftPanel, {
        name = "GlobalsBrowserListScroll",
        rowHeight = rowHeight,
        numVisibleRows = numRows,
        getCount = function()
            return GB:GetFilteredCount()
        end,
        getEntry = function(index)
            return GB:GetFilteredEntry(index)
        end,
        onSelect = function(index)
            applyListSelection(tab, index)
        end,
        renderRow = function(btn, index, entry)
            local label = GB:GetRootLabel(entry)
            btn:SetText(label)
            btn._tooltipFullText = GB:GetRootTooltip(entry)
            ensureListRowBookmarkIcon(btn, rowHeight)
            if btn._globalsBookmarkIcon then
                if GB:IsBookmarked(entry) then
                    btn._globalsBookmarkIcon:SetTexture(BOOKMARK_ICON_PATH)
                    btn._globalsBookmarkIcon:SetTexCoord(0, 1, 0, 1)
                    btn._globalsBookmarkIcon:Show()
                else
                    btn._globalsBookmarkIcon:Hide()
                end
            end
            styleListButtonText(btn)
        end,
        enableKeyboardNav = true,
        focusCompetitor = searchBox,
    })
    tab.virtualizedList = listAPI

    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    self:StyleContentPanel(rightPanel)

    OneWoW_GUI:CreateVerticalPaneResizer({
        parent = tab,
        leftPanel = leftPanel,
        rightPanel = rightPanel,
        dividerWidth = dividerWidth,
        leftMinWidth = leftMin,
        rightMinWidth = rightMin,
        splitPadding = splitPadding,
        bottomOuterInset = 5,
        rightOuterInset = 5,
        resizeCap = DU.MAIN_FRAME_RESIZE_CAP or 0.95,
        mainFrame = Addon.UI and Addon.UI.mainFrame,
        onWidthChanged = function(width)
            Addon.db.global.globalsBrowserLeftPaneWidth = width
        end,
    })

    local rightToolbar = CreateFrame("Frame", nil, tab)
    rightToolbar:SetHeight(48)
    rightToolbar:SetPoint("TOP", searchBox, "TOP", 0, 0)
    rightToolbar:SetPoint("LEFT", rightPanel, "LEFT", 0, 0)
    rightToolbar:SetPoint("RIGHT", rightPanel, "RIGHT", 0, 0)
    tab.rightToolbar = rightToolbar

    local homeBtn = OneWoW_GUI:CreateFitTextButton(rightToolbar, {
        text = L["GLOBALS_NAV_HOME"],
        height = 22,
        minWidth = 44,
    })
    homeBtn:SetPoint("TOPRIGHT", rightToolbar, "TOPRIGHT", -6, 0)
    homeBtn:SetScript("OnClick", function()
        tab.selectedTreeNode = nil
        tab.tree:SetSelectedNode(nil)
        updateHeader(tab)
        updateActionButtons(tab)
    end)
    tab.homeBtn = homeBtn

    local upBtn = OneWoW_GUI:CreateFitTextButton(rightToolbar, {
        text = L["GLOBALS_NAV_UP"],
        height = 22,
        minWidth = 36,
    })
    upBtn:SetPoint("RIGHT", homeBtn, "LEFT", -4, 0)
    upBtn:SetScript("OnClick", function()
        local parentNode = tab.selectedTreeNode and tab.selectedTreeNode.parentNode
        if not parentNode then
            tab.selectedTreeNode = nil
            tab.tree:SetSelectedNode(nil)
        else
            tab.tree:SetSelectedNode(parentNode)
            applyTreeSelection(tab, parentNode)
        end
        updateHeader(tab)
        updateActionButtons(tab)
    end)
    tab.upBtn = upBtn

    local collapseAllBtn = OneWoW_GUI:CreateFitTextButton(rightToolbar, {
        text = L["GLOBALS_BTN_COLLAPSE_ALL"],
        height = 22,
        minWidth = 82,
    })
    collapseAllBtn:SetPoint("RIGHT", upBtn, "LEFT", -4, 0)
    collapseAllBtn:SetScript("OnClick", function()
        tab.tree:CollapseAll()
        tab.tree:SetSelectedNode(nil)
        tab.selectedTreeNode = nil
        updateHeader(tab)
        updateActionButtons(tab)
    end)
    tab.collapseAllBtn = collapseAllBtn

    local expandAllBtn = OneWoW_GUI:CreateFitTextButton(rightToolbar, {
        text = L["GLOBALS_BTN_EXPAND_ALL"],
        height = 22,
        minWidth = 78,
    })
    expandAllBtn:SetPoint("RIGHT", collapseAllBtn, "LEFT", -4, 0)
    expandAllBtn:SetScript("OnClick", function()
        tab.tree:ExpandAll()
        updateActionButtons(tab)
    end)
    tab.expandAllBtn = expandAllBtn

    local treeSearchBox = OneWoW_GUI:CreateEditBox(rightToolbar, {
        width = 120,
        height = 22,
        placeholderText = L["GLOBALS_SEARCH_TREE_PLACEHOLDER"],
        onTextChanged = function()
            scheduleTreeFilterRefresh(tab)
        end,
    })
    treeSearchBox:ClearAllPoints()
    treeSearchBox:SetPoint("TOPLEFT", expandAllBtn, "BOTTOMLEFT", 0, -4)
    treeSearchBox:SetPoint("RIGHT", homeBtn, "RIGHT", 0, 0)
    tab.treeSearchBox = treeSearchBox

    tab.nameText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tab.nameText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 8, -6)
    tab.nameText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -8, 0)
    tab.nameText:SetJustifyH("LEFT")
    tab.nameText:SetWordWrap(true)
    if tab.nameText.SetMaxLines then
        tab.nameText:SetMaxLines(2)
    end
    tab.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    tab.nameText:SetText("")

    tab.metaText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.metaText:SetPoint("TOPLEFT", tab.nameText, "BOTTOMLEFT", 0, -8)
    tab.metaText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -8, 0)
    tab.metaText:SetJustifyH("LEFT")
    tab.metaText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    tab.metaText:SetText("")

    tab.pathText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.pathText:SetPoint("TOPLEFT", tab.metaText, "BOTTOMLEFT", 0, -4)
    tab.pathText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -8, 0)
    tab.pathText:SetJustifyH("LEFT")
    tab.pathText:SetWordWrap(true)
    tab.pathText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    tab.pathText:SetText("")

    local treePanel = OneWoW_GUI:CreateFrame(rightPanel, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    treePanel:ClearAllPoints()
    treePanel:SetPoint("TOPLEFT", tab.pathText, "BOTTOMLEFT", 0, -8)
    treePanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -6, 42)
    self:StyleContentPanel(treePanel)

    local treeScroll, treeContent = OneWoW_GUI:CreateScrollFrame(treePanel, {})
    treeScroll:ClearAllPoints()
    treeScroll:SetPoint("TOPLEFT", 4, -4)
    treeScroll:SetPoint("BOTTOMRIGHT", -14, 4)
    treeScroll:HookScript("OnSizeChanged", function(_, width)
        treeContent:SetWidth(width)
    end)

    tab.treeScroll = treeScroll
    tab.tree = createGlobalsTree(treeContent, treeScroll, tab)

    local copyRowLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    copyRowLabel:SetText(L["GLOBALS_COPY_ROW_LABEL"])
    copyRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    copyRowLabel:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 6, 8)

    local copyReferenceBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["GLOBALS_BTN_COPY_REFERENCE"],
        height = 22,
        minWidth = 68,
    })
    copyReferenceBtn:SetPoint("LEFT", copyRowLabel, "RIGHT", 6, -5)
    copyReferenceBtn:SetPoint("BOTTOM", rightPanel, "BOTTOM", 0, 6)
    copyReferenceBtn:SetScript("OnClick", function()
        local target = getCurrentTarget(tab)
        local reference = target and GB:GetCopyReference(target)
        if reference then
            Addon:CopyToClipboard(reference)
        end
    end)
    tab.copyReferenceBtn = copyReferenceBtn

    local copyValueBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, {
        text = L["GLOBALS_BTN_COPY_VALUE"],
        height = 22,
        minWidth = 52,
    })
    copyValueBtn:SetPoint("LEFT", copyReferenceBtn, "RIGHT", 4, 0)
    copyValueBtn:SetScript("OnClick", function()
        local target = getCurrentTarget(tab)
        if target then
            Addon:CopyToClipboard(GB:GetCopyValue(target))
        end
    end)
    tab.copyValueBtn = copyValueBtn

    tab:SetScript("OnShow", function()
        if GB then
            if not GB.indexBuilt then
                GB:RefreshIndex()
            end
            Addon.UI.GlobalsTab_RefreshList(tab)
            Addon.UI.GlobalsTab_RestoreSelection(tab, true)
        end
    end)

    tab:SetScript("OnHide", function()
        if tab._filterTicker then
            tab._filterTicker:Cancel()
            tab._filterTicker = nil
        end
        if tab._treeFilterTicker then
            tab._treeFilterTicker:Cancel()
            tab._treeFilterTicker = nil
        end
    end)

    function tab:Teardown()
        if self._filterTicker then
            self._filterTicker:Cancel()
            self._filterTicker = nil
        end
        if self._treeFilterTicker then
            self._treeFilterTicker:Cancel()
            self._treeFilterTicker = nil
        end
        if Addon.GlobalsBrowserTab == self then
            Addon.GlobalsBrowserTab = nil
        end
    end

    Addon.GlobalsBrowserTab = tab

    GB:ResetFilterState()
    if categoryDropdown._text then
        categoryDropdown._text:SetText(L["GLOBALS_FILTER_ALL"])
    end
    if noisyRootsCheck then
        noisyRootsCheck:SetChecked(GB.includeNoisyRoots and true or false)
    end
    updateRootCountLabel(tab)
    Addon.UI.GlobalsTab_RefreshList(tab)
    Addon.UI.GlobalsTab_RestoreSelection(tab, true)

    return tab
end

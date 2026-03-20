local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local pairs, ipairs, format, tinsert, tremove, wipe, sort = pairs, ipairs, format, tinsert, tremove, wipe, sort
local strlower = strlower

local LIST_TYPE_ICONS = {
    guide     = "Interface\\Icons\\INV_Misc_Book_09",
    daily     = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    weekly    = "Interface\\Icons\\Achievement_General_100kQuests",
    todo      = "Interface\\Icons\\INV_Misc_Note_01",
    repeating = "Interface\\Icons\\Spell_Nature_TimeStop",
}

local LIST_TYPE_COLORS = {
    guide     = { 0.4, 0.8, 1.0 },
    daily     = { 1.0, 0.82, 0.0 },
    weekly    = { 0.6, 0.4, 1.0 },
    todo      = { 0.8, 0.8, 0.8 },
    repeating = { 0.4, 1.0, 0.6 },
}

function ns.UI.CreateTrackerTab(parent)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    local TP = ns.TrackerPresets
    if not TD or not TE then return end

    local selectedListID = nil
    local filterType = "all"
    local filterCategory = "All"
    local searchFilter = ""
    local listRows = {}

    local controlPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(75)
    controlPanel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    controlPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    controlPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local newBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, {
        text = L["TRACKER_NEW"] or "New",
        height = 26,
    })
    newBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -10)

    local importBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, {
        text = L["TRACKER_IMPORT"] or "Import",
        height = 26,
    })
    importBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)

    local presetBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, {
        text = L["TRACKER_PRESET"] or "Preset",
        height = 26,
    })
    presetBtn:SetPoint("LEFT", importBtn, "RIGHT", 6, 0)

    local restoreBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, {
        text = L["TRACKER_RESTORE"] or "Restore Examples",
        height = 26,
    })
    restoreBtn:SetPoint("LEFT", presetBtn, "RIGHT", 6, 0)

    local typeDropdown, typeText = OneWoW_GUI:CreateDropdown(controlPanel, {
        width = 120,
        height = 26,
        text = L["TRACKER_ALL_TYPES"] or "All Types",
    })
    typeDropdown:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -42)

    OneWoW_GUI:AttachFilterMenu(typeDropdown, {
        buildItems = function()
            local items = {
                { text = L["TRACKER_ALL_TYPES"] or "All Types", value = "all" },
            }
            local types = TD:GetListTypes()
            for _, lt in ipairs(types) do
                tinsert(items, { text = TE:GetListTypeDisplayName(lt), value = lt })
            end
            return items
        end,
        onSelect = function(value)
            filterType = value
            typeText:SetText(value == "all" and (L["TRACKER_ALL_TYPES"] or "All Types") or TE:GetListTypeDisplayName(value))
            parent.RefreshList()
        end,
        getActiveValue = function() return filterType end,
    })

    local catDropdown, catText = OneWoW_GUI:CreateDropdown(controlPanel, {
        width = 140,
        height = 26,
        text = L["TRACKER_ALL_CATEGORIES"] or "All Categories",
    })
    catDropdown:SetPoint("LEFT", typeDropdown, "RIGHT", 6, 0)

    OneWoW_GUI:AttachFilterMenu(catDropdown, {
        buildItems = function()
            local items = {
                { text = L["TRACKER_ALL_CATEGORIES"] or "All Categories", value = "All" },
            }
            local cats = TD:GetCategories()
            for _, cat in ipairs(cats) do
                tinsert(items, { text = cat, value = cat })
            end
            return items
        end,
        onSelect = function(value)
            filterCategory = value
            catText:SetText(value == "All" and (L["TRACKER_ALL_CATEGORIES"] or "All Categories") or value)
            parent.RefreshList()
        end,
        getActiveValue = function() return filterCategory end,
    })

    local searchBox = OneWoW_GUI:CreateEditBox(controlPanel, {
        width = 180,
        height = 26,
        placeholderText = L["TRACKER_SEARCH"] or "Search...",
    })
    searchBox:SetPoint("LEFT", catDropdown, "RIGHT", 6, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        searchFilter = self:GetSearchText() or ""
        parent.RefreshList()
    end)

    local LEFT_PANEL_WIDTH = ns.Constants.GUI.LEFT_PANEL_WIDTH or 350
    local GAP = 10

    local listPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -GAP)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    listPanel:SetWidth(LEFT_PANEL_WIDTH)
    listPanel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    listPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    listPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local listTitle = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -8)
    listTitle:SetText(L["TRACKER_LIST_TITLE"] or "Lists")
    listTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local listScrollFrame, listScrollChild = OneWoW_GUI:CreateScrollFrame(listPanel, {})
    listScrollFrame:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -6)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -6, 4)

    local detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", GAP, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    detailPanel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    detailPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -8)
    detailTitle:SetText(L["TRACKER_DETAIL_TITLE"] or "Details")
    detailTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local detailScrollFrame, detailScrollChild = OneWoW_GUI:CreateScrollFrame(detailPanel, {})
    detailScrollFrame:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -6)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -6, 4)

    local emptyLabel = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyLabel:SetPoint("CENTER", detailPanel, "CENTER", 0, 0)
    emptyLabel:SetText(L["TRACKER_SELECT"] or "Select a list to view its details.")
    emptyLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local function CreateListRow(listData, yOffset)
        local row = CreateFrame("Button", nil, listScrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 4, yOffset)
        row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -4, yOffset)
        row:SetHeight(56)
        row:SetBackdrop(BACKDROP_SIMPLE)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local typeIcon = row:CreateTexture(nil, "ARTWORK")
        typeIcon:SetSize(24, 24)
        typeIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
        typeIcon:SetTexture(LIST_TYPE_ICONS[listData.listType] or LIST_TYPE_ICONS.todo)

        local titleLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleLabel:SetPoint("TOPLEFT", typeIcon, "TOPRIGHT", 8, -2)
        titleLabel:SetPoint("RIGHT", row, "RIGHT", -60, 0)
        titleLabel:SetJustifyH("LEFT")
        titleLabel:SetText(listData.title or "Untitled")
        titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local metaLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        metaLabel:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -2)
        metaLabel:SetPoint("RIGHT", row, "RIGHT", -60, 0)
        metaLabel:SetJustifyH("LEFT")
        local typeColor = LIST_TYPE_COLORS[listData.listType] or { 0.7, 0.7, 0.7 }
        local typeName = TE:GetListTypeDisplayName(listData.listType)
        metaLabel:SetText(format("|cFF%02x%02x%02x%s|r  %s",
            typeColor[1] * 255, typeColor[2] * 255, typeColor[3] * 255,
            typeName, listData.category or ""))
        metaLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local done, total = TD:GetListCompletion(listData.id)

        local progressLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        progressLabel:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        progressLabel:SetText(total > 0 and format("%d/%d", done, total) or "")
        progressLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        if total > 0 then
            local progressBg = row:CreateTexture(nil, "ARTWORK")
            progressBg:SetHeight(3)
            progressBg:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 4)
            progressBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 4)
            progressBg:SetColorTexture(0.2, 0.2, 0.2, 0.5)

            local progressFill = row:CreateTexture(nil, "ARTWORK", nil, 1)
            progressFill:SetHeight(3)
            progressFill:SetPoint("BOTTOMLEFT", progressBg, "BOTTOMLEFT", 0, 0)
            local pct = done / total
            progressFill:SetWidth(math.max(1, progressBg:GetWidth() * pct))
            progressFill:SetColorTexture(OneWoW_GUI:GetProgressColor(done, total))

            C_Timer.After(0.1, function()
                if progressBg:GetWidth() > 0 then
                    progressFill:SetWidth(math.max(1, progressBg:GetWidth() * pct))
                end
            end)
        end

        if listData.favorite then
            local favIcon = row:CreateTexture(nil, "OVERLAY")
            favIcon:SetSize(12, 12)
            favIcon:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
            favIcon:SetAtlas("PetJournal-FavoritesIcon")
        end

        local isSelected = (listData.id == selectedListID)
        if isSelected then
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end

        row:SetScript("OnClick", function()
            selectedListID = listData.id
            parent.RefreshList()
            parent.ShowDetail(listData.id)
        end)

        row:SetScript("OnEnter", function(self)
            if listData.id ~= selectedListID then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)

        row:SetScript("OnLeave", function(self)
            if listData.id ~= selectedListID then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)

        return row
    end

    function parent.RefreshList()
        for _, row in ipairs(listRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(listRows)

        local lists = TD:GetSortedLists(
            filterType ~= "all" and filterType or nil,
            filterCategory ~= "All" and filterCategory or nil,
            searchFilter ~= "" and searchFilter or nil
        )

        local yOffset = 0
        for _, listData in ipairs(lists) do
            local row = CreateListRow(listData, yOffset)
            tinsert(listRows, row)
            yOffset = yOffset - 60
        end

        listScrollChild:SetHeight(math.max(1, math.abs(yOffset)))

        if #lists == 0 then
            if not listPanel.emptyText then
                listPanel.emptyText = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                listPanel.emptyText:SetPoint("CENTER", listPanel, "CENTER", 0, -20)
                listPanel.emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                listPanel.emptyText:SetWidth(LEFT_PANEL_WIDTH - 40)
                listPanel.emptyText:SetWordWrap(true)
            end
            listPanel.emptyText:SetText(L["TRACKER_EMPTY"] or "No lists yet. Click 'New' to create one, or 'Preset' for quick setup.")
            listPanel.emptyText:Show()
        elseif listPanel.emptyText then
            listPanel.emptyText:Hide()
        end
    end

    local detailRows = {}

    local function ClearDetail()
        for _, row in ipairs(detailRows) do
            if row.Hide then row:Hide() end
            if row.SetParent then row:SetParent(nil) end
        end
        wipe(detailRows)
        emptyLabel:Show()
        detailTitle:SetText(L["TRACKER_DETAIL_TITLE"] or "Details")
    end

    function parent.ShowDetail(listID)
        ClearDetail()

        local list = TD:GetList(listID)
        if not list then return end

        if not list.pinned then
            TE:EvaluateList(listID)
        end

        emptyLabel:Hide()
        detailTitle:SetText(list.title or "Untitled")

        local yOffset = 0

        local headerFrame = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
        headerFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
        headerFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
        headerFrame:SetHeight(80)
        headerFrame:SetBackdrop(BACKDROP_SIMPLE)
        headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        headerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        tinsert(detailRows, headerFrame)

        local authorText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        authorText:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 10, -8)
        local typeColor = LIST_TYPE_COLORS[list.listType] or { 0.7, 0.7, 0.7 }
        authorText:SetText(format("|cFF%02x%02x%02x%s|r  |  %s  |  %s",
            typeColor[1] * 255, typeColor[2] * 255, typeColor[3] * 255,
            TE:GetListTypeDisplayName(list.listType),
            list.category or "General",
            (list.author or "")
        ))
        authorText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local done, total = TD:GetListCompletion(list.id)
        local progressBar = OneWoW_GUI:CreateProgressBar(headerFrame, {
            height = 14,
            min = 0,
            max = math.max(total, 1),
            value = done,
        })
        progressBar:SetPoint("TOPLEFT", authorText, "BOTTOMLEFT", 0, -6)
        progressBar:SetPoint("RIGHT", headerFrame, "RIGHT", -10, 0)

        local progressText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        progressText:SetPoint("CENTER", progressBar, "CENTER", 0, 0)
        progressText:SetText(total > 0 and format("%d / %d", done, total) or "")
        progressText:SetTextColor(1, 1, 1)

        local btnY = -54
        local btnX = 10

        local editBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, { text = L["TRACKER_EDIT"] or "Edit", height = 22 })
        editBtn:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", btnX, btnY)
        editBtn:SetScript("OnClick", function()
            if ns.TrackerEditor then
                ns.TrackerEditor:ShowListEditor(list.id, function()
                    parent.RefreshList()
                    parent.ShowDetail(list.id)
                end)
            end
        end)

        local pinBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, {
            text = list.pinned and (L["TRACKER_UNPIN"] or "Unpin") or (L["TRACKER_PIN"] or "Pin"),
            height = 22,
        })
        pinBtn:SetPoint("LEFT", editBtn, "RIGHT", 4, 0)
        pinBtn:SetScript("OnClick", function()
            if list.pinned then
                TE:DestroyPinnedWindow(list.id)
            else
                TE:CreatePinnedWindow(list.id)
            end
            parent.RefreshList()
            parent.ShowDetail(list.id)
        end)

        local exportBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, { text = L["TRACKER_EXPORT"] or "Export", height = 22 })
        exportBtn:SetPoint("LEFT", pinBtn, "RIGHT", 4, 0)
        exportBtn:SetScript("OnClick", function()
            if ns.TrackerEditor then
                ns.TrackerEditor:ShowExportDialog(list.id)
            end
        end)

        local dupeBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, { text = L["TRACKER_DUPLICATE"] or "Duplicate", height = 22 })
        dupeBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
        dupeBtn:SetScript("OnClick", function()
            local copy = TD:DuplicateList(list.id)
            if copy then
                selectedListID = copy.id
                parent.RefreshList()
                parent.ShowDetail(copy.id)
            end
        end)

        local favBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, {
            text = list.favorite and (L["TRACKER_UNFAV"] or "Unfavorite") or (L["TRACKER_FAV"] or "Favorite"),
            height = 22,
        })
        favBtn:SetPoint("LEFT", dupeBtn, "RIGHT", 4, 0)
        favBtn:SetScript("OnClick", function()
            TD:UpdateList(list.id, { favorite = not list.favorite })
            parent.RefreshList()
            parent.ShowDetail(list.id)
        end)

        local resetBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, { text = L["TRACKER_RESET"] or "Reset", height = 22 })
        resetBtn:SetPoint("LEFT", favBtn, "RIGHT", 4, 0)
        resetBtn:SetScript("OnClick", function()
            TD:ResetProgress(list.id)
            TE:FullScan()
            parent.RefreshList()
            parent.ShowDetail(list.id)
        end)

        local deleteBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, { text = L["TRACKER_DELETE"] or "Delete", height = 22 })
        deleteBtn:SetPoint("LEFT", resetBtn, "RIGHT", 4, 0)
        deleteBtn:SetScript("OnClick", function()
            if list._bundledID and TP then
                TP:OnBundledDeleted(list._bundledID)
            end
            TE:DestroyPinnedWindow(list.id)
            TD:RemoveList(list.id)
            selectedListID = nil
            ClearDetail()
            parent.RefreshList()
        end)

        local addSectionBtn = OneWoW_GUI:CreateFitTextButton(headerFrame, { text = "Add Section", height = 22 })
        addSectionBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 4, 0)
        addSectionBtn:SetScript("OnClick", function()
            if ns.TrackerEditor then
                ns.TrackerEditor:ShowSectionEditor(list.id, nil, function()
                    TE:RebuildIndices()
                    parent.RefreshList()
                    parent.ShowDetail(list.id)
                end)
            end
        end)

        yOffset = yOffset - 90

        if list.description and list.description ~= "" then
            local descFrame = CreateFrame("Frame", nil, detailScrollChild)
            descFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
            descFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
            tinsert(detailRows, descFrame)

            local descText = descFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            descText:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 10, -4)
            descText:SetPoint("RIGHT", descFrame, "RIGHT", -10, 0)
            descText:SetJustifyH("LEFT")
            descText:SetWordWrap(true)
            descText:SetText(list.description)
            descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local descH = descText:GetStringHeight() + 12
            descFrame:SetHeight(descH)
            yOffset = yOffset - descH
        end

        for secIdx, sec in ipairs(list.sections) do
          if TE:IsSectionVisible(sec) then
            yOffset = yOffset - 8

            local secHeader = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
            secHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
            secHeader:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
            secHeader:SetHeight(32)
            secHeader:SetBackdrop(BACKDROP_SIMPLE)
            secHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            secHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(detailRows, secHeader)

            local accentLine = secHeader:CreateTexture(nil, "ARTWORK")
            accentLine:SetSize(3, 32)
            accentLine:SetPoint("TOPLEFT", secHeader, "TOPLEFT", 0, 0)
            accentLine:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

            local secLabel = secHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            secLabel:SetPoint("LEFT", accentLine, "RIGHT", 8, 0)
            secLabel:SetText(sec.label or "Section")
            secLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local secDone, secTotal = TD:GetSectionCompletion(list.id, sec.key)
            local secCount = secHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            secCount:SetPoint("RIGHT", secHeader, "RIGHT", -8, 0)
            secCount:SetText(secTotal > 0 and format("%d/%d", secDone, secTotal) or "")
            secCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local secDeleteBtn = OneWoW_GUI:CreateFitTextButton(secHeader, { text = "X", height = 20 })
            secDeleteBtn:SetPoint("RIGHT", secCount, "LEFT", -4, 0)
            secDeleteBtn:SetScript("OnClick", function()
                TD:RemoveSection(list.id, sec.key)
                TE:RebuildIndices()
                parent.RefreshList()
                parent.ShowDetail(list.id)
            end)

            local secEditBtn = OneWoW_GUI:CreateFitTextButton(secHeader, { text = "Edit", height = 20 })
            secEditBtn:SetPoint("RIGHT", secDeleteBtn, "LEFT", -4, 0)
            secEditBtn:SetScript("OnClick", function()
                if ns.TrackerEditor then
                    ns.TrackerEditor:ShowSectionEditor(list.id, sec.key, function()
                        TE:RebuildIndices()
                        parent.RefreshList()
                        parent.ShowDetail(list.id)
                    end)
                end
            end)

            local secMoveDownBtn = OneWoW_GUI:CreateFitTextButton(secHeader, { text = "v", height = 20 })
            secMoveDownBtn:SetPoint("RIGHT", secEditBtn, "LEFT", -4, 0)

            local secMoveUpBtn = OneWoW_GUI:CreateFitTextButton(secHeader, { text = "^", height = 20 })
            secMoveUpBtn:SetPoint("RIGHT", secMoveDownBtn, "LEFT", -2, 0)

            secMoveUpBtn:SetScript("OnClick", function()
                TD:MoveSection(list.id, sec.key, "up")
                parent.RefreshList()
                parent.ShowDetail(list.id)
            end)
            secMoveDownBtn:SetScript("OnClick", function()
                TD:MoveSection(list.id, sec.key, "down")
                parent.RefreshList()
                parent.ShowDetail(list.id)
            end)

            local addStepBtn = OneWoW_GUI:CreateFitTextButton(secHeader, { text = "+", height = 20 })
            addStepBtn:SetPoint("RIGHT", secMoveUpBtn, "LEFT", -4, 0)
            addStepBtn:SetScript("OnClick", function()
                if ns.TrackerEditor then
                    ns.TrackerEditor:ShowStepEditor(list.id, sec.key, nil, function()
                        TE:RebuildIndices()
                        parent.RefreshList()
                        parent.ShowDetail(list.id)
                    end)
                end
            end)

            yOffset = yOffset - 36

            for stepIdx, step in ipairs(sec.steps or {}) do
              if TE:IsStepVisible(step, sec) then
                local sp = TD:GetStepProgress(list.id, sec.key, step.key)
                local isComplete = sp.completed or false

                local depsMet = TD:AreStepDependenciesMet(list.id, step)

                local stepRow = CreateFrame("Button", nil, detailScrollChild, "BackdropTemplate")
                stepRow:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yOffset)
                stepRow:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -10, yOffset)
                stepRow:SetBackdrop(BACKDROP_SIMPLE)
                tinsert(detailRows, stepRow)

                if isComplete then
                    stepRow:SetBackdropColor(0.15, 0.25, 0.15, 0.3)
                    stepRow:SetBackdropBorderColor(0.3, 0.5, 0.3, 0.5)
                elseif not depsMet then
                    stepRow:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
                    stepRow:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.3)
                else
                    stepRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    stepRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end

                local checkSize = 16
                local checkBtn = CreateFrame("CheckButton", nil, stepRow)
                checkBtn:SetSize(checkSize, checkSize)
                checkBtn:SetPoint("LEFT", stepRow, "LEFT", 6, 0)
                checkBtn:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
                checkBtn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
                checkBtn:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
                checkBtn:SetChecked(isComplete)

                if step.trackType == "manual" and (not step.objectives or #step.objectives == 0) then
                    checkBtn:SetScript("OnClick", function(self)
                        TD:ToggleStepComplete(list.id, sec.key, step.key)
                        parent.RefreshList()
                        parent.ShowDetail(list.id)
                        TE:RefreshAllPinnedWindows()
                    end)
                else
                    checkBtn:EnableMouse(false)
                end

                local stepLabel = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                stepLabel:SetPoint("LEFT", checkBtn, "RIGHT", 6, 0)
                stepLabel:SetPoint("RIGHT", stepRow, "RIGHT", -160, 0)
                stepLabel:SetJustifyH("LEFT")
                stepLabel:SetText(step.label or "Step")

                if isComplete then
                    stepLabel:SetTextColor(0.4, 0.8, 0.4)
                elseif not depsMet then
                    stepLabel:SetTextColor(0.5, 0.5, 0.5)
                else
                    stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end

                local progressStr = ""
                if step.trackType ~= "manual" or (step.max and step.max > 1) then
                    local current = sp.current or 0
                    local max = step.noMax and 0 or (step.max or 1)
                    if max > 0 then
                        progressStr = format("%d/%d", current, max)
                    elseif current > 0 then
                        progressStr = tostring(current)
                    end
                end

                local stepProgress = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                stepProgress:SetPoint("RIGHT", stepRow, "RIGHT", -130, 0)
                stepProgress:SetText(progressStr)
                stepProgress:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                local rowHeight = 30

                if step.description and step.description ~= "" then
                    local descFS = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    descFS:SetPoint("TOPLEFT", stepLabel, "BOTTOMLEFT", 0, -2)
                    descFS:SetPoint("RIGHT", stepRow, "RIGHT", -80, 0)
                    descFS:SetJustifyH("LEFT")
                    descFS:SetWordWrap(true)
                    descFS:SetText(step.description)
                    descFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    rowHeight = rowHeight + descFS:GetStringHeight() + 4
                end

                if step.objectives and #step.objectives > 0 then
                    local objY = -(rowHeight - 4)
                    for _, obj in ipairs(step.objectives) do
                        local objComplete = TD:GetObjectiveProgress(list.id, sec.key, step.key, obj.key)

                        local objCheck = CreateFrame("CheckButton", nil, stepRow)
                        objCheck:SetSize(14, 14)
                        objCheck:SetPoint("TOPLEFT", stepRow, "TOPLEFT", 30, objY)
                        objCheck:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
                        objCheck:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
                        objCheck:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
                        objCheck:SetChecked(objComplete)

                        if obj.type == "manual" then
                            objCheck:SetScript("OnClick", function()
                                TD:SetObjectiveComplete(list.id, sec.key, step.key, obj.key, not objComplete)
                                parent.RefreshList()
                                parent.ShowDetail(list.id)
                                TE:RefreshAllPinnedWindows()
                            end)
                        else
                            objCheck:EnableMouse(false)
                        end

                        local objLabel = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        objLabel:SetPoint("LEFT", objCheck, "RIGHT", 4, 0)
                        objLabel:SetPoint("RIGHT", stepRow, "RIGHT", -80, 0)
                        objLabel:SetJustifyH("LEFT")
                        objLabel:SetWordWrap(true)
                        objLabel:SetText(format("[%s] %s", TE:GetTrackTypeDisplayName(obj.type), obj.description or ""))

                        if objComplete then
                            objLabel:SetTextColor(0.4, 0.8, 0.4)
                        else
                            objLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                        end

                        local objH = math.max(18, objLabel:GetStringHeight() + 4)
                        objY = objY - objH
                        rowHeight = rowHeight + objH
                    end
                end

                if step.mapID and step.coordX and step.coordY then
                    local coordFS = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    coordFS:SetPoint("BOTTOMLEFT", stepRow, "BOTTOMLEFT", 30, 4)
                    local mapInfo = C_Map.GetMapInfo(tonumber(step.mapID))
                    local mapName = mapInfo and mapInfo.name or tostring(step.mapID)
                    coordFS:SetText(format("%s (%.1f, %.1f)", mapName, step.coordX, step.coordY))
                    coordFS:SetTextColor(0.5, 0.7, 1.0)
                    rowHeight = rowHeight + 16
                end

                stepRow:SetHeight(math.max(30, rowHeight))

                local stepBtnFrame = CreateFrame("Frame", nil, stepRow)
                stepBtnFrame:SetSize(1, 18)
                stepBtnFrame:SetPoint("TOPRIGHT", stepRow, "TOPRIGHT", -4, -4)

                local stepDelBtn = OneWoW_GUI:CreateFitTextButton(stepBtnFrame, { text = "X", height = 18 })
                stepDelBtn:SetPoint("RIGHT", stepBtnFrame, "RIGHT", 0, 0)
                stepDelBtn:SetScript("OnClick", function()
                    TD:RemoveStep(list.id, sec.key, step.key)
                    TE:RebuildIndices()
                    parent.RefreshList()
                    parent.ShowDetail(list.id)
                    TE:RefreshAllPinnedWindows()
                end)

                local stepEditBtn = OneWoW_GUI:CreateFitTextButton(stepBtnFrame, { text = "Edit", height = 18 })
                stepEditBtn:SetPoint("RIGHT", stepDelBtn, "LEFT", -2, 0)
                stepEditBtn:SetScript("OnClick", function()
                    if ns.TrackerEditor then
                        ns.TrackerEditor:ShowStepEditor(list.id, sec.key, step.key, function()
                            TE:RebuildIndices()
                            parent.RefreshList()
                            parent.ShowDetail(list.id)
                            TE:RefreshAllPinnedWindows()
                        end)
                    end
                end)

                local stepDownBtn = OneWoW_GUI:CreateFitTextButton(stepBtnFrame, { text = "v", height = 18 })
                stepDownBtn:SetPoint("RIGHT", stepEditBtn, "LEFT", -2, 0)

                local stepUpBtn = OneWoW_GUI:CreateFitTextButton(stepBtnFrame, { text = "^", height = 18 })
                stepUpBtn:SetPoint("RIGHT", stepDownBtn, "LEFT", -2, 0)

                stepUpBtn:SetScript("OnClick", function()
                    TD:MoveStep(list.id, sec.key, step.key, "up")
                    parent.RefreshList()
                    parent.ShowDetail(list.id)
                end)
                stepDownBtn:SetScript("OnClick", function()
                    TD:MoveStep(list.id, sec.key, step.key, "down")
                    parent.RefreshList()
                    parent.ShowDetail(list.id)
                end)

                stepRow:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    TE:BuildStepTooltip(GameTooltip, list.id, sec.key, step)
                    GameTooltip:Show()
                end)
                stepRow:SetScript("OnLeave", GameTooltip_Hide)

                local hasCoords = step.mapID and step.coordX and step.coordY and tonumber(step.mapID) and tonumber(step.coordX) and tonumber(step.coordY)
                if hasCoords then
                    stepRow:SetScript("OnClick", function()
                        local mid = tonumber(step.mapID)
                        local cx = tonumber(step.coordX) / 100
                        local cy = tonumber(step.coordY) / 100
                        local mapPoint = UiMapPoint.CreateFromCoordinates(mid, cx, cy)
                        C_Map.SetUserWaypoint(mapPoint)
                        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                        print(format("|cFFFFD100OneWoW Notes:|r Waypoint set for %s (%.1f, %.1f)", step.label or "Step", tonumber(step.coordX), tonumber(step.coordY)))
                    end)
                else
                    stepRow:RegisterForClicks("AnyDown", "AnyUp")
                    stepRow:SetScript("OnClick", function(_, button)
                        if button == "LeftButton" then
                            if step.trackType == "manual" and (not step.objectives or #step.objectives == 0) then
                                TD:ToggleStepComplete(list.id, sec.key, step.key)
                                parent.RefreshList()
                                parent.ShowDetail(list.id)
                                TE:RefreshAllPinnedWindows()
                            end
                        elseif button == "RightButton" then
                            if step.trackType == "manual" and sp.current and sp.current > 0 then
                                local newVal = sp.current - 1
                                TD:SetStepProgress(list.id, sec.key, step.key, newVal, step.max)
                                if newVal < (step.max or 1) then
                                    sp.completed = false
                                end
                                parent.RefreshList()
                                parent.ShowDetail(list.id)
                                TE:RefreshAllPinnedWindows()
                            end
                        end
                    end)
                end

                yOffset = yOffset - (math.max(30, rowHeight) + 4)
              end
            end
          end
        end

        detailScrollChild:SetHeight(math.max(1, math.abs(yOffset) + 20))
    end

    newBtn:SetScript("OnClick", function()
        if ns.TrackerEditor then
            ns.TrackerEditor:ShowNewListDialog(function(newList)
                if newList then
                    selectedListID = newList.id
                    TE:RebuildIndices()
                    parent.RefreshList()
                    parent.ShowDetail(newList.id)
                end
            end)
        end
    end)

    importBtn:SetScript("OnClick", function()
        if ns.TrackerEditor then
            ns.TrackerEditor:ShowImportDialog(function(imported)
                if imported then
                    selectedListID = imported.id
                    TE:RebuildIndices()
                    parent.RefreshList()
                    parent.ShowDetail(imported.id)
                end
            end)
        end
    end)

    presetBtn:SetScript("OnClick", function()
        if ns.TrackerEditor then
            ns.TrackerEditor:ShowPresetDialog(function(newList)
                if newList then
                    selectedListID = newList.id
                    TE:RebuildIndices()
                    parent.RefreshList()
                    parent.ShowDetail(newList.id)
                end
            end)
        end
    end)

    restoreBtn:SetScript("OnClick", function()
        if TP then
            TP:RestoreBundledContent()
            parent.RefreshList()
        end
    end)

    TE:RegisterCallback("OnScanComplete", function()
        if selectedListID then
            parent.ShowDetail(selectedListID)
        end
    end)

    TE:RegisterCallback("OnProgressChanged", function()
        parent.RefreshList()
        if selectedListID then
            parent.ShowDetail(selectedListID)
        end
    end)

    parent.RefreshList()
end

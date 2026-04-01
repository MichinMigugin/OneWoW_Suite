local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.BankCategoryView = {}
local View = OneWoW_Bags.BankCategoryView

local labelPool = {}
local activeLabels = {}

local function AcquireLabel(parent)
    local label
    if #labelPool > 0 then
        label = tremove(labelPool)
        label:SetParent(parent)
    else
        label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    end
    label:ClearAllPoints()
    label:Show()
    activeLabels[label] = true
    return label
end

local function ReleaseAllLabels()
    for label in pairs(activeLabels) do
        label:Hide()
        label:ClearAllPoints()
        tinsert(labelPool, label)
    end
    wipe(activeLabels)
end

function View:Layout(contentFrame, width, filteredButtons)
    local Constants = OneWoW_Bags.Constants
    local db = OneWoW_Bags.db
    local Categories = OneWoW_Bags.Categories
    local BCM = OneWoW_Bags.BankCategoryManager
    local L = OneWoW_Bags.L

    local containerType = db.global.bankShowWarband and "warband_bank" or "character_bank"

    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2
    local compact = db.global.bankCompactCategories
    local showHeaders = db.global.showBankCategoryHeaders ~= false
    local verticalSpacing = (db.global.bankCategorySpacing or 1.0)
    local compactGapSlots = db.global.bankCompactGap or 1

    local filterSet
    if filteredButtons then
        filterSet = {}
        for _, btn in ipairs(filteredButtons) do
            filterSet[btn] = true
        end
    end

    BCM:ReleaseAllSections()
    ReleaseAllLabels()

    local itemsByCategory = {}
    local BankSet = OneWoW_Bags.BankSet
    if not BankSet then return 100 end

    local allButtons = BankSet:GetAllButtons()
    for _, button in ipairs(allButtons) do
        if button.owb_hasItem and button.owb_itemInfo then
            local catName = Categories:GetItemCategory(button.owb_bagID, button.owb_slotID, button.owb_itemInfo)
            button.owb_categoryName = catName
            if catName and (not filterSet or filterSet[button]) then
                if not itemsByCategory[catName] then
                    itemsByCategory[catName] = {}
                end
                tinsert(itemsByCategory[catName], button)
            end
        end
    end

    local categoryNames = {}
    for name in pairs(itemsByCategory) do
        tinsert(categoryNames, name)
    end

    local sortMode = db.global.categorySort or "priority"
    Categories:SortCategories(categoryNames, sortMode)

    local moveUpgradesToTop = db.global.moveUpgradesToTop
    local moveOtherToBottom = db.global.moveOtherToBottom
    if moveUpgradesToTop or moveOtherToBottom then
        local pinRecent, pinUpgrades, pinBottom, rest = {}, {}, {}, {}
        for _, name in ipairs(categoryNames) do
            if name == "Recent Items" and moveUpgradesToTop then
                tinsert(pinRecent, name)
            elseif name == "1W Upgrades" and moveUpgradesToTop then
                tinsert(pinUpgrades, name)
            elseif name == "Other" and moveOtherToBottom then
                tinsert(pinBottom, name)
            else
                tinsert(rest, name)
            end
        end
        categoryNames = {}
        for _, n in ipairs(pinRecent)   do tinsert(categoryNames, n) end
        for _, n in ipairs(pinUpgrades) do tinsert(categoryNames, n) end
        for _, n in ipairs(rest)        do tinsert(categoryNames, n) end
        for _, n in ipairs(pinBottom)   do tinsert(categoryNames, n) end
    end

    local cols = db.global.bankColumns or math.floor((width - padding * 2) / (iconSize + spacing))
    cols = math.max(cols, 1)
    local cellSize = iconSize + spacing
    local totalGridWidth = cols * cellSize - spacing
    local leftPadding = math.max(padding, math.floor((width - totalGridWidth) / 2))

    local yOffset = 0

    if compact then
        local gapSlots = compactGapSlots
        local labelHeight = showHeaders and 16 or 0

        local catInfoList = {}
        for _, categoryName in ipairs(categoryNames) do
            local items = itemsByCategory[categoryName]
            if items and #items > 0 then
                OneWoW_Bags:SortButtons(items)
                local localeKey = "CAT_" .. string.upper(string.gsub(categoryName, "%s+", "_"))
                local displayName = L[localeKey] or categoryName
                tinsert(catInfoList, { name = categoryName, displayName = displayName, items = items })
            end
        end

        local lines = {}
        local currentLine = {}
        local curCol = 0

        for _, catInfo in ipairs(catInfoList) do
            local count = #catInfo.items
            local startCol = curCol > 0 and (curCol + gapSlots) or 0
            local avail = math.floor(cols - startCol)

            if avail < 1 then
                tinsert(lines, currentLine)
                currentLine = {}
                curCol = 0
                startCol = 0
                avail = cols
            end

            local optimalWidth = count <= cols and count or math.max(2, math.floor(math.sqrt(count / 1.618)))
            local blockWidth = math.min(optimalWidth, avail)
            local blockRows = math.ceil(count / blockWidth)

            if blockRows > 1 and (curCol > 0 or blockWidth < cols) then
                if #currentLine > 0 then
                    tinsert(lines, currentLine)
                    currentLine = {}
                end
                curCol = 0
                startCol = 0
                blockWidth = math.min(count, cols)
                blockRows = math.ceil(count / blockWidth)
            end

            tinsert(currentLine, {
                name = catInfo.name,
                displayName = catInfo.displayName,
                items = catInfo.items,
                startCol = startCol,
                blockWidth = blockWidth,
                blockRows = blockRows,
            })

            if blockRows > 1 then
                tinsert(lines, currentLine)
                currentLine = {}
                curCol = 0
            else
                curCol = startCol + blockWidth
            end
        end
        if #currentLine > 0 then
            tinsert(lines, currentLine)
        end

        for _, line in ipairs(lines) do
            if showHeaders then
                for _, cat in ipairs(line) do
                    local label = AcquireLabel(contentFrame)
                    label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT",
                        leftPadding + cat.startCol * cellSize, -yOffset)
                    label:SetWidth(cat.blockWidth * cellSize)
                    label:SetText(cat.displayName)
                    local catMods2 = db.global.categoryModifications or {}
                    local catMod2 = catMods2[cat.name]
                    if catMod2 and catMod2.color then
                        local cr = tonumber(catMod2.color:sub(1,2), 16) / 255
                        local cg = tonumber(catMod2.color:sub(3,4), 16) / 255
                        local cb = tonumber(catMod2.color:sub(5,6), 16) / 255
                        label:SetTextColor(cr, cg, cb, 1.0)
                    else
                        label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    end
                end
            end
            yOffset = yOffset + labelHeight

            local maxRows = 0
            for _, cat in ipairs(line) do
                if cat.blockRows > maxRows then maxRows = cat.blockRows end
                local itemCol = 0
                local itemRow = 0
                for _, button in ipairs(cat.items) do
                    local x = leftPadding + (cat.startCol + itemCol) * cellSize
                    local y = -(yOffset + itemRow * cellSize)
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, y)
                    button:OWB_SetIconSize(iconSize)
                    button:Show()
                    itemCol = itemCol + 1
                    if itemCol >= cat.blockWidth then
                        itemCol = 0
                        itemRow = itemRow + 1
                    end
                end
            end
            yOffset = yOffset + maxRows * cellSize
        end
        if #lines > 0 then
            yOffset = yOffset + math.floor(cellSize * verticalSpacing * 0.25 + 0.5)
        end
    else
        for _, categoryName in ipairs(categoryNames) do
            local items = itemsByCategory[categoryName]
            if items and #items > 0 then
                OneWoW_Bags:SortButtons(items)

                if showHeaders then
                    local section = BCM:AcquireSection(contentFrame)
                    section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
                    section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
                    section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

                    local localeKey = "CAT_" .. string.upper(string.gsub(categoryName, "%s+", "_"))
                    local displayName = L[localeKey] or categoryName
                    section.title:SetText(displayName)
                    local catMods = db.global.categoryModifications or {}
                    local catMod = catMods[categoryName]
                    if catMod and catMod.color then
                        local cr = tonumber(catMod.color:sub(1,2), 16) / 255
                        local cg = tonumber(catMod.color:sub(3,4), 16) / 255
                        local cb = tonumber(catMod.color:sub(5,6), 16) / 255
                        section.title:SetTextColor(cr, cg, cb, 1.0)
                    else
                        section.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    end
                    section.count:SetText(tostring(#items))
                    section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                    local collapsed = db.global.collapsedBankSections[categoryName]
                    section.isCollapsed = collapsed or false

                    local sectionHeight = 26

                    if not section.isCollapsed then
                        local itemRow = 0
                        local itemCol = 0
                        section.content:SetHeight(1)

                        for _, button in ipairs(items) do
                            local x = leftPadding + (itemCol * cellSize)
                            local y = -(itemRow * cellSize)
                            button:ClearAllPoints()
                            button:SetPoint("TOPLEFT", section.content, "TOPLEFT", x, y)
                            button:OWB_SetIconSize(iconSize)
                            button:Show()
                            itemCol = itemCol + 1
                            if itemCol >= cols then
                                itemCol = 0
                                itemRow = itemRow + 1
                            end
                        end

                        local totalRows = (itemCol > 0) and (itemRow + 1) or itemRow
                        local contentHeight = totalRows * cellSize
                        section.content:SetHeight(contentHeight)
                        section.content:Show()
                        sectionHeight = sectionHeight + contentHeight + 4
                    else
                        section.content:Hide()
                        for _, button in ipairs(items) do
                            button:Hide()
                        end
                    end

                    section:SetHeight(sectionHeight)
                    yOffset = yOffset + sectionHeight + math.floor(cellSize * verticalSpacing * 0.25 + 0.5)

                    local capturedName = categoryName
                    section.header:SetScript("OnClick", function()
                        section.isCollapsed = not section.isCollapsed
                        db.global.collapsedBankSections[categoryName] = section.isCollapsed or nil
                        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
                            OneWoW_Bags.BankGUI:RefreshLayout()
                        end
                    end)
                else
                    local itemRow = 0
                    local itemCol = 0
                    for _, button in ipairs(items) do
                        local x = leftPadding + (itemCol * cellSize)
                        local y = -(yOffset + itemRow * cellSize)
                        button:ClearAllPoints()
                        button:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, y)
                        button:OWB_SetIconSize(iconSize)
                        button:Show()
                        itemCol = itemCol + 1
                        if itemCol >= cols then
                            itemCol = 0
                            itemRow = itemRow + 1
                        end
                    end
                    local totalRows = (itemCol > 0) and (itemRow + 1) or itemRow
                    yOffset = yOffset + totalRows * cellSize + math.floor(cellSize * verticalSpacing * 0.25 + 0.5)
                end
            end
        end
    end

    return math.max(yOffset, 100)
end

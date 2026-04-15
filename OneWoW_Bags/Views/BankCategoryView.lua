local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local Categories = OneWoW_Bags.Categories
local BankSet = OneWoW_Bags.BankSet
local H = OneWoW_Bags.CategoryViewHelpers

local tinsert = tinsert
local pairs, ipairs = pairs, ipairs
local floor, max = math.floor, math.max

OneWoW_Bags.BankCategoryView = {}
local View = OneWoW_Bags.BankCategoryView

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local AcquireLabel, ReleaseAllLabels = H.CreateLabelPool()

function View:Layout(contentFrame, width, filteredButtons, viewContext)
    local db = GetDB()
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

    local sortButtons = viewContext.sortButtons
    local acquireSection = viewContext.acquireSection
    local getCollapsed = viewContext.getCollapsed
    local setCollapsed = viewContext.setCollapsed

    ReleaseAllLabels()

    local itemsByCategory = {}
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

    local sortMode = db.global.categorySort
    Categories:SortCategories(categoryNames, sortMode)

    categoryNames = H.PinSpecialCategories(categoryNames, db.global.moveRecentToTop, db.global.moveOtherToBottom)

    local cols = db.global.bankColumns or floor((width - padding * 2) / (iconSize + spacing))
    cols = max(cols, 1)
    local cellSize = iconSize + spacing
    local totalGridWidth = cols * cellSize - spacing
    local leftPadding = max(padding, floor((width - totalGridWidth) / 2))

    local catMods = db.global.categoryModifications
    local yOffset = 0

    local function GetCategorySortMode(categoryName)
        local mod = catMods[categoryName]
        if mod and mod.sortMode then return mod.sortMode end
        return nil
    end

    if compact then
        local catInfoList = {}
        for _, categoryName in ipairs(categoryNames) do
            local items = itemsByCategory[categoryName]
            if items and #items > 0 then
                sortButtons(items, GetCategorySortMode(categoryName))
                tinsert(catInfoList, {
                    name = categoryName,
                    displayName = H.ResolveCategoryName(categoryName),
                    items = items,
                })
            end
        end

        yOffset = H.LayoutCompactGroup(catInfoList, contentFrame, {
            yOffset = yOffset,
            cols = cols,
            gapSlots = compactGapSlots,
            showHeaders = showHeaders,
            leftPadding = leftPadding,
            cellSize = cellSize,
            iconSize = iconSize,
            catMods = catMods,
            AcquireLabel = AcquireLabel,
            verticalSpacing = verticalSpacing,
        })
    else
        for _, categoryName in ipairs(categoryNames) do
            local items = itemsByCategory[categoryName]
            if items and #items > 0 then
                sortButtons(items, GetCategorySortMode(categoryName))

                if showHeaders then
                    local section = acquireSection(contentFrame)
                    H.SetupCategorySection(section, contentFrame, yOffset, categoryName, #items, catMods)

                    local collapsed = getCollapsed("category", categoryName)
                    section.isCollapsed = collapsed or false

                    local sectionHeight = 26

                    if not section.isCollapsed then
                        section.content:SetHeight(1)
                        local contentHeight = H.RenderItemGrid(section.content, items, 0, leftPadding, cellSize, iconSize, cols)
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
                    yOffset = yOffset + sectionHeight + H.VerticalGap(cellSize, verticalSpacing)

                    section.header:SetScript("OnClick", function()
                        section.isCollapsed = not section.isCollapsed
                        setCollapsed("category", categoryName, section.isCollapsed)
                    end)
                else
                    local gridHeight = H.RenderItemGrid(contentFrame, items, yOffset, leftPadding, cellSize, iconSize, cols)
                    yOffset = yOffset + gridHeight + H.VerticalGap(cellSize, verticalSpacing)
                end
            end
        end
    end

    return max(yOffset, 100)
end

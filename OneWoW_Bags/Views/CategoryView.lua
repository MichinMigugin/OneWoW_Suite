local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local CategoryManager = OneWoW_Bags.CategoryManager
local H = OneWoW_Bags.CategoryViewHelpers
local PE = OneWoW_Bags.PredicateEngine

local floor, max = math.floor, math.max
local ipairs = ipairs

OneWoW_Bags.CategoryView = {}
local View = OneWoW_Bags.CategoryView

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local AcquireLabel, ReleaseAllLabels = H.CreateLabelPool()

function View:Layout(contentFrame, width, filteredButtons, containerType, viewContext)
    local db = GetDB()
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2
    local compact = db.global.compactCategories
    local showHeaders = db.global.showCategoryHeaders ~= false
    local verticalSpacing = (db.global.categorySpacing or 1.0)
    local compactGapSlots = db.global.compactGap or 1

    local filterSet
    if filteredButtons then
        filterSet = {}
        for _, btn in ipairs(filteredButtons) do
            filterSet[btn] = true
        end
    end

    CategoryManager:AssignCategories()

    local itemsByCategory = CategoryManager:GetItemsByCategory()
    local layout = H.GetSectionedLayout(itemsByCategory, containerType)

    local cols = db.global.bagColumns or floor((width - padding * 2) / (iconSize + spacing))
    cols = max(cols, 1)
    local cellSize = iconSize + spacing
    local totalGridWidth = cols * cellSize - spacing
    local leftPadding = max(padding, floor((width - totalGridWidth) / 2))

    return H.LayoutCategoryContent({
        contentFrame = contentFrame,
        viewContext = viewContext,
        itemsByCategory = itemsByCategory,
        layout = layout,
        compact = compact,
        showHeaders = showHeaders,
        verticalSpacing = verticalSpacing,
        compactGapSlots = compactGapSlots,
        cols = cols,
        leftPadding = leftPadding,
        cellSize = cellSize,
        iconSize = iconSize,
        filterSet = filterSet,
        db = db,
        PE = PE,
        AcquireLabel = AcquireLabel,
        ReleaseAllLabels = ReleaseAllLabels,
        moveRecentToTop = db.global.moveRecentToTop,
        moveOtherToBottom = db.global.moveOtherToBottom,
    })
end

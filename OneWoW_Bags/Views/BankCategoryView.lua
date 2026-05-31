local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local H = OneWoW_Bags.CategoryViewHelpers
local PE = OneWoW_GUI.PredicateEngine

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
    local BC = OneWoW_Bags.BankController
    local compact = BC:Get("compactCategories")
    local showHeaders = BC:Get("showCategoryHeaders") ~= false
    local verticalSpacing = (BC:Get("categorySpacing") or 1.0)
    local compactGapSlots = BC:Get("compactGap") or 1

    local filterToken = filteredButtons and filteredButtons._owb_filterToken

    local containerType = viewContext.containerType

    local BankCategoryManager = OneWoW_Bags.BankCategoryManager
    local itemsByCategory = BankCategoryManager:AssignAndGroupCategories()

    local layout = H.GetSectionedLayout(itemsByCategory, containerType)

    local cols = BC:Get("columns") or floor((width - padding * 2) / (iconSize + spacing))
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
        filterToken = filterToken,
        db = db,
        PE = PE,
        AcquireLabel = AcquireLabel,
        ReleaseAllLabels = ReleaseAllLabels,
        moveRecentToTop = db.global.moveRecentToTop,
        moveOtherToBottom = db.global.moveOtherToBottom,
        containerType = containerType,
    })
end

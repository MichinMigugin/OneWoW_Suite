local _, ns = ...

local Constants = ns.Constants
local H = ns.CategoryViewHelpers
local PE = OneWoW.PredicateEngine

local floor, max = math.floor, math.max

ns.BankCategoryView = {}
local View = ns.BankCategoryView

local function GetDB()
    return ns:GetDB()
end

local AcquireLabel, ReleaseAllLabels = H.CreateLabelPool()

function View:ReleaseCompactLabels()
    ReleaseAllLabels()
end

function View:Layout(contentFrame, width, filteredButtons, viewContext)
    local db = GetDB()
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2
    local BC = ns.BankController
    local compact = BC:Get("compactCategories")
    local showHeaders = BC:Get("showCategoryHeaders") ~= false
    local verticalSpacing = (BC:Get("categorySpacing") or 1.0)
    local compactGapSlots = BC:Get("compactGap") or 1

    local filterToken = filteredButtons and filteredButtons._owb_filterToken

    local containerType = viewContext.containerType

    local BankCategoryManager = ns.BankCategoryManager
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

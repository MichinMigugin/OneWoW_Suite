local _, OneWoW_Bags = ...

local Constants = OneWoW_Bags.Constants
local BagTypes = OneWoW_Bags.BagTypes

local floor, max = math.floor, math.max
local ipairs = ipairs
local tinsert = tinsert

OneWoW_Bags.ListView = {}
local View = OneWoW_Bags.ListView

function View:Layout(contentFrame, buttons, width, viewContext)
    local db = OneWoW_Bags:GetDB()
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2
    local sortButtons = viewContext and viewContext.sortButtons or function(list)
        OneWoW_Bags:SortButtons(list, db.global.itemSort)
    end

    local showEmpty = db.global.showEmptySlots
    if showEmpty == nil then showEmpty = true end

    local cols = floor((width + spacing) / (iconSize + spacing))
    cols = max(cols, 1)

    local leftPadding = padding

    local normalButtons = {}
    local reagentButtons = {}

    for _, button in ipairs(buttons) do
        if not button.owb_isGuildBank and BagTypes:IsReagentBag(button.owb_bagID) then
            tinsert(reagentButtons, button)
        else
            tinsert(normalButtons, button)
        end
    end

    sortButtons(normalButtons)
    sortButtons(reagentButtons)

    local row = 0
    local col = 0

    local extraYOffset = 0
    local reagentGapPx = floor((iconSize + spacing) * 0.2)

    local function placeButton(button)
        local x = leftPadding + (col * (iconSize + spacing))
        local y = -(padding + (row * (iconSize + spacing)) + extraYOffset)

        button:ClearAllPoints()
        OneWoW_Bags.WindowHelpers:SetPointPixelAligned(button, contentFrame, x, y)
        button:OWB_SetIconSize(iconSize)
        button:Show()

        col = col + 1
        if col >= cols then
            col = 0
            row = row + 1
        end
    end

    for _, button in ipairs(normalButtons) do
        if not showEmpty and not button.owb_hasItem then
            button:Hide()
        else
            placeButton(button)
        end
    end

    if #reagentButtons > 0 then
        -- finish current row if we were mid-row
        if col > 0 then
            row = row + 1
            col = 0
        end

        -- smaller gap than a full extra row
        extraYOffset = reagentGapPx

        for _, button in ipairs(reagentButtons) do
            if not showEmpty and not button.owb_hasItem then
                button:Hide()
            else
                placeButton(button)
            end
        end
    end

    local totalRows = (col > 0) and (row + 1) or row
    local totalHeight = padding * 2 + totalRows * (iconSize + spacing) + extraYOffset
    return max(totalHeight, 100)
end

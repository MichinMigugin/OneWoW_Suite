local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.ListView = {}
local View = OneWoW_Bags.ListView

function View:Layout(contentFrame, buttons, width)
    local Constants = OneWoW_Bags.Constants
    local db = OneWoW_Bags.db
    local BagTypes = OneWoW_Bags.BagTypes

    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2

    local showEmpty = db.global.showEmptySlots
    if showEmpty == nil then showEmpty = true end

    local cols = math.floor((width - padding * 2) / (iconSize + spacing))
    cols = math.max(cols, 1)

    local totalGridWidth = cols * (iconSize + spacing) - spacing
    local leftPadding = math.max(padding, math.floor((width - totalGridWidth) / 2))

    local normalButtons = {}
    local reagentButtons = {}

    for _, button in ipairs(buttons) do
        if BagTypes:IsReagentBag(button.owb_bagID) then
            table.insert(reagentButtons, button)
        else
            table.insert(normalButtons, button)
        end
    end

    local row = 0
    local col = 0

    local extraYOffset = 0
    local reagentGapPx = math.floor((iconSize + spacing) * 0.2)

    local function placeButton(button)
        local x = leftPadding + (col * (iconSize + spacing))
        local y = -(padding + (row * (iconSize + spacing)) + extraYOffset)

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, y)
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
    return math.max(totalHeight, 100)
end

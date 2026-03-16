local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankListView = {}
local View = OneWoW_Bags.GuildBankListView

function View:Layout(contentFrame, buttons, width)
    local Constants = OneWoW_Bags.Constants
    local db = OneWoW_Bags.db

    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2

    local cols = math.floor((width - padding * 2) / (iconSize + spacing))
    cols = math.max(cols, 1)

    local totalGridWidth = cols * (iconSize + spacing) - spacing
    local leftPadding = math.max(padding, math.floor((width - totalGridWidth) / 2))

    local row = 0
    local col = 0

    for _, button in ipairs(buttons) do
        if button.owb_hasItem then
            local x = leftPadding + (col * (iconSize + spacing))
            local y = -(padding + (row * (iconSize + spacing)))

            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, y)
            button:OWB_SetIconSize(iconSize)
            button:Show()

            col = col + 1
            if col >= cols then
                col = 0
                row = row + 1
            end
        else
            button:Hide()
        end
    end

    local totalRows = (col > 0) and (row + 1) or row
    local totalHeight = padding * 2 + totalRows * (iconSize + spacing)
    return math.max(totalHeight, 100)
end

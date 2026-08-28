local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

ns.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WAYPIN_MAP_BUTTON_SIZE = 36,
    }),
    -- Detail editor chrome shared across Notes / Zones / Players / NPCs / Items / Collectibles.
    Detail = {
        HEADER_HEIGHT = 95,
        BODY_HEIGHT   = 190,
        PANEL_INSET   = 10,   -- detailPanel → header
        SECTION_GAP   = 10,   -- header → body → tooltip / todo
        -- L, T, R, B insets for CreateScrollEditBox inside contentBg
        BODY_SCROLL_INSET = { 4, -4, -26, 4 },
        META_LINE_Y_UPPER = 24,  -- BOTTOMRIGHT secondary meta (type / category / map)
        META_LINE_Y_LOWER = 8,
        TOOLTIP_LINE_COUNT  = 4,
        TOOLTIP_LINE_HEIGHT = 22,
        TOOLTIP_LINE_PITCH  = 28,
        TOOLTIP_LABEL_Y     = -8,
        TOOLTIP_FIRST_ROW_Y = -30,
        -- Label pad above first row: |TOOLTIP_FIRST_ROW_Y| - TOOLTIP_LINE_HEIGHT/2 ≈ 19–20;
        -- section height = |FIRST_ROW_Y| + (COUNT - 1) * PITCH + LINE_HEIGHT + bottom pad (8)
        HEADER_ICON_SIZE = 22,
    },
}

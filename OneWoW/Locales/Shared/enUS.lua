local _, OneWoW = ...

OneWoW.Locale:RegisterShared("enUS", {
    -- Language picker (native names come from Locale.SUPPORTED, not from here)
    ["LANGUAGE_SELECTION"] = "Language Selection",
    ["LANGUAGE_DESC"] = "Choose your preferred language for the addon interface. Changes apply instantly.",

    -- Theme picker
    ["THEME_SECTION"] = "Color Theme",
    ["THEME_DESC"] = "Themes are grouped below. Random picks one palette each reload; reopen the menu and choose Random again to reroll this session.",
    ["THEME_RANDOM"] = "Random (new each reload)",
    ["THEME_RANDOM_CURRENT"] = "Random (%s)",

    -- Theme menu group titles
    ["THEME_GROUP_CLASSIC"] = "Classic accents",
    ["THEME_GROUP_DARK"] = "Dark & minimal",
    ["THEME_GROUP_BOLD"] = "Bold & stylized",
    ["THEME_GROUP_LIGHT"] = "Light & accessibility",

    -- Theme display names (keyed THEME_<UPPER themeKey>; resolved at runtime)
    ["THEME_GREEN"] = "Forest Green",
    ["THEME_BLUE"] = "Ocean Blue",
    ["THEME_PURPLE"] = "Royal Purple",
    ["THEME_GOLD"] = "Classic Gold",
    ["THEME_RED"] = "Crimson Red",
    ["THEME_SLATE"] = "Slate Gray",
    ["THEME_ORANGE"] = "Sunset Orange",
    ["THEME_TEAL"] = "Mystic Teal",
    ["THEME_CYAN"] = "Arctic Cyan",
    ["THEME_PINK"] = "Rose Pink",
    ["THEME_DARK"] = "Midnight Dark",
    ["THEME_AMBER"] = "Amber Fire",
    ["THEME_VOIDBLACK"] = "Void Black",
    ["THEME_CHARCOAL"] = "Charcoal Deep",
    ["THEME_FORESTNIGHT"] = "Forest Night",
    ["THEME_OBSIDIAN"] = "Obsidian Minimal",
    ["THEME_MONOCHROME"] = "Monochrome Pro",
    ["THEME_TWILIGHT"] = "Twilight Compact",
    ["THEME_NEON"] = "Neon Synthwave",
    ["THEME_GLASSMORPHIC"] = "Glassmorphic",
    ["THEME_LIGHTMODE"] = "Minimal White",
    ["THEME_RETRO"] = "Retro Classic",
    ["THEME_FANTASY"] = "RPG Fantasy",
    ["THEME_NIGHTFAE"] = "Covenant Twilight",
    ["THEME_HIGHCONTRAST"] = "High Contrast",

    -- Font section (font family names are proper nouns; "Font Size" uses FONT_SIZE global)
    ["FONT_SECTION"] = "Font",
    ["FONT_DESC"] = "Choose the font used across all OneWoW addons. SharedMedia fonts from other addons are also supported and will appear in the list.",
    ["FONT_SIZE_DESC"] = "Adjust font size across all addons.",
    ["FONT_SIZE_WARNING"] = "EXPERIMENTAL: Not all OneWoW addons are compatible or adapted for font size adjustments yet.",

    -- Value display section
    ["VALUE_DISPLAY_SECTION"] = "Value display",
    ["VALUE_DISPLAY_DESC"] = "How gold and prices are shown across OneWoW (bags, AltTracker, Catalog, tooltips, farm value tracker, etc.).",
    ["VALUE_DISPLAY_LETTERS"] = "Show letters g, s, c (instead of coin icons)",
    ["VALUE_DISPLAY_REGIONAL"] = "Use regional number grouping (client locale)",
    ["VALUE_DISPLAY_WHITE"] = "Use white values (letter mode; classic look when off)",

    -- Footer links (Discord / OneWoW are proper nouns)
    ["LINK_DONATE"] = "Donate",

    -- Minimap section labels (faction icon names come from FACTION_* globals)
    ["MINIMAP_SECTION"] = "Minimap Button",
    ["MINIMAP_SECTION_DESC"] = "Show or hide the minimap button.",
    ["MINIMAP_SHOW_BTN"] = "Show Minimap Button",
    ["MINIMAP_ICON_SECTION"] = "Icon Theme",
    ["MINIMAP_ICON_DESC"] = "Choose your faction icon for the minimap button and title bar.",

    -- Common
    ["CURRENT_VALUE"] = "Current: %s",

    -- Phase 3 consolidated (cross-scope duplicates)
    ["ADD_ITEM"] = "Add Item",
    ["BATTLE_PET"] = "Battle Pet",
    ["BUTTON_SIZE"] = "Button Size",
    ["DRAG_ITEM_HERE"] = "Drag Item Here",
    ["GROW_DIRECTION"] = "Grow Direction",
    ["ITEM_ID"] = "Item ID:",
    ["NEW_CATEGORY"] = "New Category",
    ["OPEN_SETTINGS"] = "Open Settings",
    ["TYPE_S"] = "Type: %s",
    ["UNLOCK_POSITION"] = "Unlock Position",
    ["D_OF_D_ITEMS"] = "%d of %d items",
    ["ADD_BY_ID"] = "Add by ID",
    ["ADDED_NPC_S"] = "Added NPC: %s",
    ["ADDED_PLAYER_S"] = "Added player: %s",
    ["ALL_DIFFICULTIES"] = "All Difficulties",
    ["BAR_SETTINGS"] = "Bar Settings",
    ["CLICK_AND_DRAG_TO_MOVE"] = "Click and drag to move",
    ["DISCORD"] = "Discord",
    ["DOUBLE_CLICK_OR_SHIFT_CLICK_TO_COLLAPSE_OR_EXPAND"] = "Double-click or Shift+click to collapse or expand",
    ["HIDE_ANCHOR_SHOW_ON_HOVER"] = "Hide Anchor (show on hover)",
    ["HIDE_BAR"] = "Hide Bar",
    ["ICON_SPACING"] = "Icon Spacing",
    ["LEFT_CLICK_TO_USE"] = "Left-click to use",
    ["LOCK_MOVE"] = "Lock Move",
    ["LOCK_RESIZE"] = "Lock Resize",
    ["NPC_NOTE_ALREADY_EXISTS"] = "NPC note already exists.",
    ["OPEN_ONEWOW"] = "Open OneWoW",
    ["OPEN_THE_AUCTION_HOUSE_FIRST_TO_SCAN_PRICES"] = "Open the Auction House first to scan prices.",
    ["PRICES_FOUND"] = "prices found",
    ["RIGHT_CLICK_FOR_MORE_OPTIONS"] = "Right-click for more options",
    ["SCAN_AH"] = "SCAN AH",
    ["SEARCH_ITEMS"] = "Search items...",
    ["SHOW_BAR"] = "Show Bar",
    ["GOLD_TOTAL"] = "Total Gold",
    ["WORLD_QUEST"] = "World Quest",

    -- Phase 3 consolidated (cross-scope bare-word terms)
    ["ITEM"] = "Item",
    ["RENAME"] = "Rename",
    ["EXPANSION"] = "Expansion",
    ["SEARCH"] = "Search...",
    ["MAIL"] = "Mail",
    ["UP"] = "Up",
    ["ACHIEVEMENT"] = "Achievement",
    ["CREATE"] = "Create",
    ["DOWN"] = "Down",
    ["DUPLICATE"] = "Duplicate",
    ["FILTER"] = "Filter:",
    ["KEEP"] = "Keep",
    ["PAUSE"] = "Pause",
    ["PROGRESS"] = "Progress",
    ["STOP"] = "Stop",
    ["BLACKLIST"] = "Blacklist",
    ["CAMPAIGN"] = "Campaign",
    ["DECOR"] = "Decor",
    ["DISCARD"] = "Discard",
    ["FILE"] = "File:",
    ["GUILD"] = "Guild:",
    ["ID"] = "ID:",
    ["LOCKOUTS"] = "Lockouts",
    ["RACE"] = "Race:",
    ["SESSION"] = "Session",
    ["SLOT"] = "Slot",
    ["SUMMARY"] = "Summary",

    -- Deliberately NOT consolidated into shared (kept per-scope) — do not move these
    -- in during a future consolidation pass. Each is one English word whose
    -- translation diverges by grammatical context, so a single shared value can't fit:
    --   Active, Expired, Personal, Minimal, Manual — adjectives that must agree in
    --     gender/number with the noun they describe (e.g. fr actif/active,
    --     es mínimo/mínima), which differs per call site.
    --   Pin — two distinct senses: noun "map pin" (Catalog) vs verb "pin" (Trackers).
    -- ("%d" is a bare format placeholder, also intentionally left scoped.)
})

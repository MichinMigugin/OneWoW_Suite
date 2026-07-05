local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["INSPECTMOG_TITLE"] = "Inspect Gear",
    ["INSPECTMOG_DESC"] = "Adds a side panel to the inspect window listing the equipped gear of the player you are inspecting. Save the whole list to a OneWoW Notes player note, or Shift-click any item to add it to your Item Notes.",

    ["INSPECTMOG_ADD_NOTE"] = "Add to Player Note",
    ["INSPECTMOG_ADD_ALL"] = "Add All",
    ["INSPECTMOG_EMPTY"] = "No inspectable gear yet.",
    ["INSPECTMOG_PANEL_TITLE"] = "Inspect Transmog Tool",
    ["INSPECTMOG_NO_DATA"] = "No inspect data available.",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "Inspected player",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "Native appearance",
    ["INSPECTMOG_SOURCE_FORMAT"] = "Source #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "Appearance source: %d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl-click to preview in the Dressing Room",
    ["INSPECTMOG_TT_NOTES"] = "Shift-click to add to Notes > Items",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Shift-click to add equipped item to Notes > Items",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Shift-click to add this item's appearance to Notes > Collectibles",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Shift-click to add transmog appearance to Notes > Items",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Shift-click to add transmog appearance to Notes > Collectibles",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "Add appearances to Collectibles",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl-click to preview equipped item",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl-click to preview transmog appearance",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "Hidden appearances are not added to Item Notes",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "Add All Transmog",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "Add all visible transmog appearance items to Notes > Items.",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "Save Gear to Player Note",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "Writes every listed slot and item to this player's note in OneWoW Notes. Re-saving updates the gear block and keeps the rest of the note.",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "Inspected: %s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG Inspected on %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "Saved gear to %s's note.",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "Updated gear in %s's note.",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "Added %s to Item Notes.",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "OneWoW Notes is not installed.",
    ["INSPECTMOG_STATUS_NO_DATA"] = "No gear data available yet.",
})

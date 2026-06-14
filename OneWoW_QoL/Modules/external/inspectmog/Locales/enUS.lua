-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/inspectmog/Locales/enUS.lua
local addonName, ns = ...
local L_enUS = ns.L_enUS

L_enUS["INSPECTMOG_TITLE"] = "Inspect Gear"
L_enUS["INSPECTMOG_DESC"]  = "Adds a side panel to the inspect window listing the equipped gear of the player you are inspecting. Save the whole list to a OneWoW Notes player note, or Shift-click any item to add it to your Item Notes."

L_enUS["INSPECTMOG_ADD_NOTE"] = "Add to Player Note"
L_enUS["INSPECTMOG_ADD_ALL"]  = "Add All"
L_enUS["INSPECTMOG_EMPTY"]    = "No inspectable gear yet."
L_enUS["INSPECTMOG_PANEL_TITLE"] = "Inspect Transmog Tool"
L_enUS["INSPECTMOG_NO_DATA"]     = "No inspect data available."
L_enUS["INSPECTMOG_UNKNOWN_PLAYER"] = "Inspected player"
L_enUS["INSPECTMOG_EMPTY_SLOT"]      = "Empty"
L_enUS["INSPECTMOG_NATIVE_APPEARANCE"] = "Native appearance"
L_enUS["INSPECTMOG_SOURCE_FORMAT"] = "Source #%d"
L_enUS["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "Appearance source: %d"

-- Row hover help
L_enUS["INSPECTMOG_TT_PREVIEW"] = "Ctrl-click to preview in the Dressing Room"
L_enUS["INSPECTMOG_TT_NOTES"]   = "Shift-click to add to Notes > Items"
L_enUS["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"]    = "Shift-click to add equipped item to Notes > Items"
L_enUS["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"]  = "Shift-click to add transmog appearance to Notes > Items"
L_enUS["INSPECTMOG_TT_PREVIEW_EQUIPPED"]      = "Ctrl-click to preview equipped item"
L_enUS["INSPECTMOG_TT_PREVIEW_APPEARANCE"]    = "Ctrl-click to preview transmog appearance"
L_enUS["INSPECTMOG_TT_HIDDEN_APPEARANCE"]     = "Hidden appearances are not added to Item Notes"
L_enUS["INSPECTMOG_TT_ADD_ALL_TITLE"]         = "Add All Transmog"
L_enUS["INSPECTMOG_TT_ADD_ALL_DESC"]          = "Add all visible transmog appearance items to Notes > Items."

-- Add-to-note button help
L_enUS["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "Save Gear to Player Note"
L_enUS["INSPECTMOG_TT_ADD_NOTE_DESC"]  = "Writes every listed slot and item to this player's note in OneWoW Notes. Re-saving updates the gear block and keeps the rest of the note."

-- Player-note block (this text is written into the saved note)
L_enUS["INSPECTMOG_NOTE_HEADER"]  = "[OneWoW Inspect Mog]"
L_enUS["INSPECTMOG_NOTE_FOOTER"]  = "[/OneWoW Inspect Mog]"
L_enUS["INSPECTMOG_NOTE_UPDATED"] = "Inspected: %s"
L_enUS["INSPECTMOG_NOTE_LINE"]    = "%s - %s"

-- Item-note stamp (appended to an Item Notes entry)
L_enUS["INSPECTMOG_ITEM_STAMP"] = "TMOG Inspected on %s - %s"

-- Status line feedback
L_enUS["INSPECTMOG_STATUS_NOTE_SAVED"]    = "Saved gear to %s's note."
L_enUS["INSPECTMOG_STATUS_NOTE_UPDATED"]  = "Updated gear in %s's note."
L_enUS["INSPECTMOG_STATUS_ITEM_ADDED"]    = "Added %s to Item Notes."
L_enUS["INSPECTMOG_STATUS_NOTES_MISSING"] = "OneWoW Notes is not installed."
L_enUS["INSPECTMOG_STATUS_NO_DATA"]       = "No gear data available yet."

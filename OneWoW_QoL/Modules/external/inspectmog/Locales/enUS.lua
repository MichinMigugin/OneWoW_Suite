-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/inspectmog/Locales/enUS.lua
local addonName, ns = ...
local L_enUS = ns.L_enUS

L_enUS["INSPECTMOG_TITLE"] = "Inspect Gear"
L_enUS["INSPECTMOG_DESC"]  = "Adds a side panel to the inspect window listing the equipped gear of the player you are inspecting. Save the whole list to a OneWoW Notes player note, or Ctrl-click any item to add it to your Item Notes."

L_enUS["INSPECTMOG_ADD_NOTE"] = "Add to Player Note"
L_enUS["INSPECTMOG_EMPTY"]    = "No inspectable gear yet."

-- Row hover help
L_enUS["INSPECTMOG_TT_PREVIEW"] = "Click to preview in the Dressing Room"
L_enUS["INSPECTMOG_TT_CHAT"]    = "Shift-click to link in chat"
L_enUS["INSPECTMOG_TT_NOTES"]   = "Ctrl-click to add to Item Notes"

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

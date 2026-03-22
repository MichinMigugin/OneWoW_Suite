-- OneWoW Addon File
-- OneWoW_CatalogData_Journal/Locales/enUS.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.Locales = ns.Locales or {}
ns.Locales["enUS"] = {
    ["ADDON_LOADED"] = "OneWoW CatalogData: Journal data loaded.",

    ["JOURNAL_STATUS_COLLECTED"]     = "Collected",
    ["JOURNAL_STATUS_NOT_COLLECTED"] = "Not Collected",
    ["JOURNAL_STATUS_KNOWN"]         = "Known",
    ["JOURNAL_STATUS_UNKNOWN"]       = "Not Known",
    ["JOURNAL_STATUS_COMPLETED"]     = "Completed",
    ["JOURNAL_STATUS_NOT_COMPLETED"] = "Not Completed",
    ["JOURNAL_STATUS_NA"]            = "N/A",

    ["JOURNAL_GENERAL_LOOT"]  = "General Loot",
    ["JOURNAL_UNKNOWN_ITEM"]  = "Unknown Item",
    ["JOURNAL_UNKNOWN_INST"]  = "Unknown Instance",
    ["JOURNAL_LOADING"]       = "Loading...",
    ["JOURNAL_LIVE_EJ_TAG"]   = "Guide",
}

ns.L = {}
for k, v in pairs(ns.Locales["enUS"]) do ns.L[k] = v end

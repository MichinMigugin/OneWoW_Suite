local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUTOOPEN_TITLE"] = "Auto Open",
    ["AUTOOPEN_DESC"] = "Automatically opens bags, boxes, and other container items when they appear in your inventory. Does not open items while at a bank, mailbox, or merchant. Items you cannot open yet (locked lockboxes, wrong level/class/profession, or while the slot is busy) are automatically skipped.",
    ["AUTOOPEN_OPENING"] = "Auto-opening: %s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "Add items to prevent Auto Open from opening them.",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "Removed from blacklist: %s",
})

-- OneWoW Addon File
-- OneWoW_Catalog/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.DatabaseDefaults = {
    global = {
        language          = nil,
        theme             = "green",
        lastTab           = "journal",
        mainFrameSize     = nil,
        mainFramePosition = nil,
        minimap           = { hide = false, minimapPos = 220, theme = "horde" },
    },
}

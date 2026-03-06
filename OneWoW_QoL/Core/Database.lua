-- OneWoW_QoL Addon File
-- OneWoW_QoL/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.DatabaseDefaults = {
    global = {
        language = nil,
        theme = "green",
        lastTab = "features",
        mainFrameSize = nil,
        mainFramePosition = nil,
        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "horde",
        },
        modules = {},
    },
}

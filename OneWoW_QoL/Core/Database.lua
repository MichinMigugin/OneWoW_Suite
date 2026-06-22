local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

local defaults = {
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
        modules = {
            bagbar = {
                locked            = false,
                maxButtons        = 12,
                buttonSize        = 36,
                columns           = 12,
                iconSpacing       = 4,
                manualItems       = {},
                manualMacros      = {},
                blacklist         = {},
                hideAnchor        = false,
                growDirection     = "RIGHT",
                expressionFilter  = "#usable",
            },
        },
        uiFavorites = {
            features = {},
            toggles  = {},
        },
    },
}

function ns:InitializeDatabase()
    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar  = "OneWoW_QoL_DB",
        defaults  = defaults,
    })
    ns.db = db
end

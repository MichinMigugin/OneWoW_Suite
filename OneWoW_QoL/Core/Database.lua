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

    -- Two modules persist user-authored expressions. Registered here rather
    -- than inside each module because a disabled module's settings still live
    -- in SavedVariables — its expressions would still break on a rename, so
    -- they still have to be visible to the reference index.
    OneWoW.SearchCatalog:RegisterExpressionSource("qol_bagbar", {
        sourceLabel = "QoL — Bag Bar",
        Enumerate = function()
            local bagbar = ns.db.global.modules.bagbar
            local expr = bagbar and bagbar.expressionFilter
            if type(expr) ~= "string" or expr == "" then return {} end
            return { { expression = expr, label = "Bag Bar filter" } }
        end,
    })

    OneWoW.SearchCatalog:RegisterExpressionSource("qol_vendorpanel", {
        sourceLabel = "QoL — Vendor Panel",
        Enumerate = function()
            local out = {}
            local bucket = ns.db.global.modules.vendorpanel
            local filters = bucket and bucket.settings and bucket.settings.customFilters
            for i, filter in ipairs(filters or {}) do
                if type(filter) == "table" and type(filter.expr) == "string"
                    and filter.expr ~= "" then
                    tinsert(out, {
                        expression = filter.expr,
                        label = filter.name or ("Filter " .. i),
                    })
                end
            end
            return out
        end,
    })
end

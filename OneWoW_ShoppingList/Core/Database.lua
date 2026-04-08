local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.Database = {}
local Database = ns.Database

local MAIN_LIST_KEY = "Main List"
ns.MAIN_LIST_KEY = MAIN_LIST_KEY

local DB_DEFAULTS = {
    global = {
        schemaVersion   = 1,
        mainFramePosition = {},
        shoppingLists = {
            lists       = {},
            activeList  = MAIN_LIST_KEY,
            defaultList = MAIN_LIST_KEY,
        },
        settings = {
            language              = "enUS",
            theme                 = "green",
            enableTooltips        = true,
            searchAlts            = true,
            showMinimapButton     = true,
            showBagButtons        = true,
            showProfessionButtons = true,
            showAHButton          = true,
            confirmItemDelete     = true,
            confirmListDelete     = true,
            overlay = {
                enabled  = true,
                position = "BOTTOMRIGHT",
                scale    = 1.0,
                alpha    = 1.0,
            },
        },
        minimap = {
            hide       = false,
            minimapPos = 220,
            theme      = "neutral",
        },
    },
}

function Database:Initialize(savedDB)
    local db = savedDB

    if not db.global then db.global = {} end

    OneWoW_GUI.DB:MergeMissing(db.global, DB_DEFAULTS.global)

    self:EnsureMainList(db)

    return db
end

function Database:EnsureMainList(db)
    if not db.global.shoppingLists.lists[MAIN_LIST_KEY] then
        db.global.shoppingLists.lists[MAIN_LIST_KEY] = {
            items           = {},
            isCraftOrder    = false,
            parentList      = nil,
            createdAt       = time(),
        }
    end
end

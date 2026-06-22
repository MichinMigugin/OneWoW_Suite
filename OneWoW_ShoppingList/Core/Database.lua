local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local MAIN_LIST_KEY = "Main List"
ns.MAIN_LIST_KEY = MAIN_LIST_KEY

local defaults = {
    global = {
        mainFramePosition = {},
        shoppingLists = {
            lists       = {},
            activeList  = MAIN_LIST_KEY,
            defaultList = MAIN_LIST_KEY,
        },
        settings = {
            enableTooltips        = true,
            showBagButtons        = true,
            showProfessionButtons = true,
            showOrdersButtons     = true,
            showAHButton          = true,
            confirmItemDelete     = true,
            confirmListDelete     = true,
            wrapItemNames         = true,
            overlay = {
                enabled  = true,
                position = "BOTTOMRIGHT",
                scale    = 1.0,
                alpha    = 1.0,
            },
        },
        minimap = {
            hide  = false,
            theme = "neutral",
        },
    },
}

local function EnsureMainList(db)
    local lists = db.global.shoppingLists.lists
    if not lists[MAIN_LIST_KEY] then
        lists[MAIN_LIST_KEY] = {
            items        = {},
            isCraftOrder = false,
            parentList   = nil,
            createdAt    = time(),
        }
    end
end

function ns:InitializeDatabase()
    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar  = "OneWoW_ShoppingList_DB",
        defaults  = defaults,
    })
    ns.db = db
    EnsureMainList(db)
end

local ADDON_NAME, ns = ...

ns.Database = {}
local Database = ns.Database

local MAIN_LIST_KEY = "Main List"
ns.MAIN_LIST_KEY = MAIN_LIST_KEY

local DB_DEFAULTS = {
    global = {
        schemaVersion = 1,
        mainFramePosition = {},
        shoppingLists = {
            lists = {},
            activeList = MAIN_LIST_KEY,
            defaultList = MAIN_LIST_KEY,
        },
        settings = {
            language = "enUS",
            theme = "green",
            enableTooltips = true,
            searchAlts = true,
            overlay = {
                enabled = true,
                position = "BOTTOMRIGHT",
                scale = 1.0,
                alpha = 1.0,
            },
        },
        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "neutral",
        },
    },
}

function Database:Initialize(savedDB)
    local db = savedDB

    if not db.global then db.global = {} end
    if not db.global.schemaVersion then db.global.schemaVersion = 1 end

    if not db.global.shoppingLists then
        db.global.shoppingLists = {}
    end
    if not db.global.shoppingLists.lists then
        db.global.shoppingLists.lists = {}
    end
    if not db.global.shoppingLists.activeList then
        db.global.shoppingLists.activeList = MAIN_LIST_KEY
    end
    if not db.global.shoppingLists.defaultList then
        db.global.shoppingLists.defaultList = MAIN_LIST_KEY
    end

    if not db.global.settings then
        db.global.settings = {}
    end
    local s = db.global.settings
    if s.language == nil then s.language = "enUS" end
    if s.theme == nil then s.theme = "green" end
    if s.enableTooltips == nil then s.enableTooltips = true end
    if s.searchAlts == nil then s.searchAlts = true end
    if s.showMinimapButton == nil then s.showMinimapButton = true end
    if s.showBagButtons == nil then s.showBagButtons = true end
    if s.showProfessionButtons == nil then s.showProfessionButtons = true end
    if s.showAHButton == nil then s.showAHButton = true end
    if not s.overlay then s.overlay = {} end
    local o = s.overlay
    if o.enabled == nil then o.enabled = true end
    if o.position == nil then o.position = "BOTTOMRIGHT" end
    if o.scale == nil then o.scale = 1.0 end
    if o.alpha == nil then o.alpha = 1.0 end

    if not db.global.mainFramePosition then
        db.global.mainFramePosition = {}
    end
    if not db.global.minimap then
        db.global.minimap = {}
    end
    if db.global.minimap.hide == nil then db.global.minimap.hide = false end
    if db.global.minimap.minimapPos == nil then db.global.minimap.minimapPos = 220 end
    if db.global.minimap.theme == nil then db.global.minimap.theme = "neutral" end

    self:EnsureMainList(db)

    return db
end

function Database:EnsureMainList(db)
    if not db.global.shoppingLists.lists[MAIN_LIST_KEY] then
        db.global.shoppingLists.lists[MAIN_LIST_KEY] = {
            items = {},
            isCraftOrder = false,
            parentList = nil,
            createdAt = time(),
        }
    end
end

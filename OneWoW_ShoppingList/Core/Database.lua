local ADDON_NAME, ns = ...

ns.Database = {}
local Database = ns.Database

local MAIN_LIST_KEY = "Main List"
ns.MAIN_LIST_KEY = MAIN_LIST_KEY

local DB_DEFAULTS = {
    global = {
        schemaVersion = 1,
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

    if not db.global.minimap then
        db.global.minimap = {}
    end
    if db.global.minimap.hide == nil then db.global.minimap.hide = false end
    if db.global.minimap.minimapPos == nil then db.global.minimap.minimapPos = 220 end
    if db.global.minimap.theme == nil then db.global.minimap.theme = "neutral" end

    self:EnsureMainList(db)
    self:MigrateFromWoWNotesShoppingList(db)

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

function Database:MigrateFromWoWNotesShoppingList(db)
    if db.global.schemaVersion and db.global.schemaVersion >= 1 then
        if db.global._migratedFromWNSL then return end
    end

    local wnslDB = _G.WoWNotesShoppingListDB
    if not wnslDB or not wnslDB.global then return end
    local src = wnslDB.global

    if not src.shoppingLists then return end

    local stats = { lists = 0, items = 0, craftOrders = 0 }
    local hasData = false

    if src.shoppingLists.lists and next(src.shoppingLists.lists) then
        hasData = true
        for listName, listData in pairs(src.shoppingLists.lists) do
            if not db.global.shoppingLists.lists[listName] then
                db.global.shoppingLists.lists[listName] = listData
                stats.lists = stats.lists + 1
                if listData.isCraftOrder then
                    stats.craftOrders = stats.craftOrders + 1
                end
                if listData.items then
                    for _ in pairs(listData.items) do
                        stats.items = stats.items + 1
                    end
                end
            end
        end
    end

    if src.shoppingLists.activeList and not db.global.shoppingLists.activeList then
        db.global.shoppingLists.activeList = src.shoppingLists.activeList
    end

    if src.shoppingLists.settings then
        hasData = true
        local ss = src.shoppingLists.settings
        if ss.language and not db.global.settings.language then
            db.global.settings.language = ss.language
        end
        if ss.enableTooltips ~= nil and db.global.settings.enableTooltips == nil then
            db.global.settings.enableTooltips = ss.enableTooltips
        end
        if ss.overlaySettings then
            local ov = db.global.settings.overlay
            local sov = ss.overlaySettings
            if sov.enabled ~= nil then ov.enabled = sov.enabled end
            if sov.position then ov.position = sov.position end
            if sov.scale then ov.scale = sov.scale end
            if sov.alpha then ov.alpha = sov.alpha end
        end
    end

    if hasData then
        db.global._migratedFromWNSL = true
        local parts = {}
        if stats.lists > 0 then
            table.insert(parts, string.format("%d list%s", stats.lists, stats.lists ~= 1 and "s" or ""))
        end
        if stats.craftOrders > 0 then
            table.insert(parts, string.format("%d craft order%s", stats.craftOrders, stats.craftOrders ~= 1 and "s" or ""))
        end
        if stats.items > 0 then
            table.insert(parts, string.format("%d item%s", stats.items, stats.items ~= 1 and "s" or ""))
        end
        if #parts > 0 then
            print("|cFFFFD100OneWoW Shopping List:|r Migrated " .. table.concat(parts, ", ") .. " from previous install.")
        end
    end
end

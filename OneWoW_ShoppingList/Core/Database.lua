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
    ns:MigrateLegacyOverlaySettings()
end

--- One-shot: copy the old Shopping List bag-overlay checkbox / placement
--- onto the Overlays 2.0 shoppinglist preset, then drop the SL-side key.
function ns:MigrateLegacyOverlaySettings()
    local old = ns.db.global.settings.overlay
    if type(old) ~= "table" then return end

    local Registry = OneWoW.SettingsFeatureRegistry
    local userOverlays = Registry:GetFeatureSettings("overlays", "userOverlays")
    local entry = userOverlays.ov_shoppinglist
    if type(entry) == "table" then
        local migrated = CopyTable(entry)
        if old.enabled == false then
            migrated.enabled = false
        end
        if type(old.position) == "string" then
            migrated.position = old.position
        end
        if type(old.scale) == "number" then
            migrated.scale = old.scale
        end
        if type(old.alpha) == "number" then
            migrated.alpha = old.alpha
        end
        Registry:SetSetting("overlays", "userOverlays", "ov_shoppinglist", migrated)
    end
    ns.db.global.settings.overlay = nil
end

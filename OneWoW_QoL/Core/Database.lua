local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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

function ns.InitializeDatabase(addon)
    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar  = "OneWoW_QoL_DB",
        defaults  = defaults,
    })
    addon.db = db

    DB:RunMigrations(db, {
        { version = 1, name = "drop_acedb_shape", run = function(d)
            local root = d.root
            if not root then return end
            root.char        = nil
            root.profileKeys = nil
        end },
        { version = 2, name = "rename_minimapskin_to_map_mini_tools", run = function(d)
            local mods = d.global.modules
            if mods.minimapskin and not mods.map_mini_tools then
                mods.map_mini_tools = mods.minimapskin
                mods.minimapskin = nil
            end
            local fav = d.global.uiFavorites
            if fav.features.minimapskin and not fav.features.map_mini_tools then
                fav.features.map_mini_tools = fav.features.minimapskin
                fav.features.minimapskin = nil
            end
        end },
        { version = 3, name = "bagbar_rename_category_keys", run = function(d)
            local bb = d.global.modules and d.global.modules.bagbar
            if not bb then return end
            if bb.showUsableItems ~= nil then
                bb.showConsumables = bb.showUsableItems
                bb.showUsableItems = nil
            end
            if bb.showDecor ~= nil then
                bb.showMiscOther = bb.showDecor
                bb.showDecor = nil
            end
        end },
        { version = 4, name = "bagbar_checkbox_to_expression", run = function(d)
            local strtrim = strtrim
            local tinsert = tinsert
            local bb = d.global.modules and d.global.modules.bagbar
            if not bb then return end

            local hadLegacy = bb.showRecipes ~= nil or bb.showMounts ~= nil or bb.showPets ~= nil
                or bb.showConsumables ~= nil or bb.showContainers ~= nil or bb.showMiscOther ~= nil
                or bb.advancedFilter ~= nil

            if hadLegacy then
                local parts = {}
                if bb.showRecipes == false then
                    tinsert(parts, "!(#recipe|#profession)")
                end
                if bb.showMounts == false then
                    tinsert(parts, "!#mount")
                end
                if bb.showPets == false then
                    tinsert(parts, "!#pet")
                end
                if bb.showConsumables == false then
                    tinsert(parts, "!#consumable")
                end
                if bb.showContainers == false then
                    tinsert(parts, "!#container")
                end
                if bb.showMiscOther == false then
                    tinsert(parts, "!(#miscellaneous & !#mount & !#companionpet)")
                end
                local categoryExpr = table.concat(parts, " & ")
                local adv = strtrim(bb.advancedFilter or "")
                local merged
                if adv == "" then
                    merged = categoryExpr
                elseif categoryExpr == "" then
                    merged = adv
                else
                    merged = "(" .. categoryExpr .. ") & (" .. adv .. ")"
                end
                bb.expressionFilter = merged
                bb.advancedFilter = nil
                bb.showRecipes = nil
                bb.showMounts = nil
                bb.showPets = nil
                bb.showConsumables = nil
                bb.showContainers = nil
                bb.showMiscOther = nil
            elseif bb.expressionFilter == nil then
                bb.expressionFilter = "#usable"
            end

            if bb.maxButtons and bb.maxButtons > 24 then
                bb.maxButtons = 24
            end
        end },
    })
end

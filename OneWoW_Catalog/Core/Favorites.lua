-- OneWoW Addon File
-- OneWoW_Catalog/Core/Favorites.lua
local addonName, ns = ...

local Fav = {}
ns.Favorites = Fav

function Fav:IsFavorite(category, id)
    if id == nil then return false end
    local db = ns.addon and ns.addon.db and ns.addon.db.global
    if not db or not db.favorites then return false end
    local bucket = db.favorites[category]
    if not bucket then return false end
    return bucket[tostring(id)] == true
end

function Fav:SetFavorite(category, id, on)
    if id == nil then return end
    local db = ns.addon and ns.addon.db and ns.addon.db.global
    if not db then return end
    db.favorites = db.favorites or {}
    db.favorites[category] = db.favorites[category] or {}
    local key = tostring(id)
    if on then
        db.favorites[category][key] = true
    else
        db.favorites[category][key] = nil
    end
end

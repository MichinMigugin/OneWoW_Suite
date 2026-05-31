local _, ns = ...

local Fav = {}
ns.Favorites = Fav

function Fav:IsFavorite(category, id)
    if id == nil then return false end
    local db = ns.addon.db.global
    local bucket = db.favorites[category]
    if not bucket then return false end
    return bucket[tostring(id)] == true
end

function Fav:SetFavorite(category, id, on)
    if id == nil then return end
    local db = ns.addon.db.global
    db.favorites[category] = db.favorites[category] or {}
    local key = tostring(id)
    if on then
        db.favorites[category][key] = true
    else
        db.favorites[category][key] = nil
    end
end

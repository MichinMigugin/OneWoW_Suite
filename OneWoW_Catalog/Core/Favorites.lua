local _, ns = ...

local Fav = {}
ns.Favorites = Fav

function Fav:IsFavorite(category, id)
    if id == nil then return false end
    local bucket = ns.db.global.favorites[category]
    if not bucket then return false end
    return bucket[tostring(id)] == true
end

function Fav:SetFavorite(category, id, on)
    if id == nil then return end
    local db = ns.db.global
    db.favorites[category] = db.favorites[category] or {}
    local key = tostring(id)
    if on then
        db.favorites[category][key] = true
    else
        db.favorites[category][key] = nil
    end
end

--- Returns an array of numeric favorite IDs for a category.
---@param category string
---@return number[]
function Fav:GetFavoriteIDs(category)
    local out = {}
    local bucket = ns.db.global.favorites[category]
    if bucket then
        for key in pairs(bucket) do
            local id = tonumber(key)
            if id then out[#out + 1] = id end
        end
    end
    return out
end

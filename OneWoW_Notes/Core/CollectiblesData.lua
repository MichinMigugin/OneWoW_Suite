local _, ns = ...

-- Notes-side user data for collectibles. Rows are keyed by the canonical
-- collectible KEY string ("mount:2240", "appearance:source:5678") produced by
-- the core OneWoW.Collectibles service — NOT a numeric id like the other data
-- modules. This module owns only user content (category, intent, notes,
-- acquisition metadata); identity + live collection state stay in core and are
-- resolved at display time (never persisted here).
--
-- Note the deliberate name split: `ns.Collectibles` (below) is this Notes data
-- module; `OneWoW.Collectibles` is the core identity service. They are separate
-- namespaces and both are referenced in this file.

local Collectibles = ns.DataModule:New("collectibles", "collectibleCustomCategories", {
    "General", "Mount", "Transmog", "Want List", "Other"
})
ns.Collectibles = Collectibles

local pairs = pairs

-- Valid intent values (user-facing meaning): none | want | spotted | farming.

--- Returns a collectible record by key (canonicalized), or nil.
---@param key string
---@return table|nil record
function Collectibles:GetCollectible(key)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then return nil end
    return self:GetAll()[key]
end

--- Persists a record under its canonical key, honoring its `storage` scope.
---@param key string
---@param data table
function Collectibles:SaveCollectible(key, data)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key or not data then return end

    data.key = key
    data.modified = GetServerTime()

    if (data.storage or "account") == "character" then
        ns.db.char.collectibles[key] = data
    else
        ns.db.global.collectibles[key] = data
    end

    self:InvalidateCache()
end

--- Create-or-update a collectible record. On update, only non-nil `fields`
--- overwrite. On create, a record is built from the key descriptor + core
--- display resolution (name is a search/fallback convenience only — live
--- display comes from OneWoW.Collectibles.ResolveDisplay at render time).
---@param key string
---@param fields table|nil
---@return boolean ok, table|nil record
function Collectibles:UpsertCollectible(key, fields)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then return false end
    fields = fields or {}

    local existing = self:GetCollectible(key)
    if existing then
        for k, v in pairs(fields) do
            if v ~= nil then existing[k] = v end
        end
        self:SaveCollectible(key, existing)
        return true, existing
    end

    local descriptor = OneWoW.Collectibles.ParseKey(key)
    local display = OneWoW.Collectibles.ResolveDisplay(key)

    local record = {
        key          = key,
        type         = descriptor.type,
        name         = fields.name or (display and display.name),
        category     = fields.category or "General",
        storage      = fields.storage or "account",
        content      = fields.content or "",
        intent       = fields.intent or "none",
        acquisition  = fields.acquisition or { vendorOffers = {}, achievements = {} },
        created      = GetServerTime(),
        modified     = GetServerTime(),
        tooltipLines = fields.tooltipLines or {"", "", "", ""},
    }

    self:SaveCollectible(key, record)
    return true, record
end

--- Removes a collectible record by key.
---@param key string
function Collectibles:RemoveCollectible(key)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then return end
    self:Remove(key)
end

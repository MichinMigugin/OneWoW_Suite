local _, ns = ...
local L = ns.L

local Location = OneWoW.Location

local CopyTable = CopyTable
local pairs, ipairs, type, tonumber = pairs, ipairs, type, tonumber
local tinsert, sort, format = tinsert, sort, string.format
local GetServerTime = GetServerTime
local C_Map = C_Map

-- ============================================================================
-- WayPins
-- ============================================================================
-- Persistent OneWay Pin landmarks (mapID + percent coords + overlay icon).
-- Separate from zone notes (prose/todos). The zone pinned window hosts the
-- list; this module owns storage and CRUD.
-- ============================================================================

local WayPins = ns.DataModule:New("waypins", nil, {})
ns.WayPins = WayPins

local DEFAULT_ICON = { kind = "list", value = "VignetteEvent-SuperTracked" }
local PERCENT_COORDS = { format = "percent" }
local idSeq = 0

local function CopyIcon(spec)
    if type(spec) ~= "table" or not spec.value or spec.value == "" then
        return CopyTable(DEFAULT_ICON)
    end
    local icon = {
        kind = spec.kind or "list",
        value = spec.value,
    }
    if type(spec.tint) == "table" then
        icon.tint = { spec.tint[1], spec.tint[2], spec.tint[3] }
    end
    return icon
end

local function CopyBg(bg)
    if type(bg) ~= "table" or not bg.enabled then
        return nil
    end
    local copy = {
        enabled = true,
        style = bg.style or "Solid-Circle",
        effect = bg.effect or "none",
        scale = tonumber(bg.scale) or 1,
    }
    if type(bg.color) == "table" then
        copy.color = { bg.color[1] or 1, bg.color[2] or 1, bg.color[3] or 1 }
    end
    return copy
end

local function CopyEffect(effect)
    if effect == "spinning" or effect == "zooming" or effect == "both" then
        return effect
    end
    return nil
end

local function NotifyChanged()
    WayPins:InvalidateCache()
    if ns.WayPinsMap then
        ns.WayPinsMap:Refresh()
    end
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:Sync()
    end
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:Sync()
    end
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

function WayPins:MakeNewId()
    idSeq = idSeq + 1
    return format("wp_%d_%d", GetServerTime() or 0, idSeq)
end

function WayPins:GetPin(pinID)
    if not pinID then return nil end
    return self:GetAll()[pinID]
end

--- Pins for a uiMapID, title-sorted.
---@param mapID number|nil
---@return table[]
function WayPins:GetForMap(mapID)
    mapID = tonumber(mapID)
    local out = {}
    if not mapID or mapID == 0 then
        return out
    end
    for _, pin in pairs(self:GetAll()) do
        if type(pin) == "table" and tonumber(pin.mapID) == mapID then
            tinsert(out, pin)
        end
    end
    sort(out, function(a, b)
        local ta = a.title or ""
        local tb = b.title or ""
        if ta == tb then
            return (a.id or "") < (b.id or "")
        end
        return ta < tb
    end)
    return out
end

---@param fields table
---@return string|nil pinID
function WayPins:Add(fields)
    if not ns.WayPinsVisual.Enabled() then return nil end
    if type(fields) ~= "table" then return nil end
    local mapID = tonumber(fields.mapID)
    local x = tonumber(fields.x)
    local y = tonumber(fields.y)
    if not mapID or mapID == 0 or not x or not y then
        return nil
    end

    local pinID = fields.id
    if type(pinID) ~= "string" or not pinID:match("^wp_") then
        pinID = self:MakeNewId()
    end

    local title = fields.title
    if type(title) ~= "string" or title == "" then
        title = L["WAYPINS_UNTITLED"]
    end

    local storage = fields.storage == "character" and "character" or "account"
    local pin = {
        id        = pinID,
        title     = title,
        mapID     = mapID,
        x         = x,
        y         = y,
        icon      = CopyIcon(fields.icon),
        bg        = CopyBg(fields.bg),
        effect    = CopyEffect(fields.effect),
        mapSize      = tonumber(fields.mapSize),
        minimapSize  = tonumber(fields.minimapSize),
        source    = fields.source or "manual",
        sourceKey = fields.sourceKey,
        storage   = storage,
        created   = fields.created or GetServerTime(),
        modified  = GetServerTime(),
    }

    local targetDB = self:GetDataDB(storage)
    targetDB[pinID] = pin
    NotifyChanged()
    return pinID
end

function WayPins:Save(pinID, pin)
    if not pinID or type(pin) ~= "table" then return end
    pin.id = pinID
    pin.mapID = tonumber(pin.mapID) or pin.mapID
    pin.x = tonumber(pin.x) or pin.x
    pin.y = tonumber(pin.y) or pin.y
    pin.icon = CopyIcon(pin.icon)
    pin.bg = CopyBg(pin.bg)
    pin.effect = CopyEffect(pin.effect)
    pin.mapSize = tonumber(pin.mapSize)
    pin.minimapSize = tonumber(pin.minimapSize)
    pin.storage = pin.storage == "character" and "character" or "account"
    pin.modified = GetServerTime()

    local targetDB = self:GetDataDB(pin.storage)
    if pin.storage == "character" then
        ns.db.global.waypins[pinID] = nil
    else
        ns.db.char.waypins[pinID] = nil
    end
    targetDB[pinID] = pin
    NotifyChanged()
end

function WayPins:Remove(pinID)
    if not pinID then return end
    ns.DataModule.Remove(self, pinID)
    NotifyChanged()
end

function WayPins:Track(pinID)
    local pin = self:GetPin(pinID)
    if not pin then return false end
    if ns.WayPinsMap then
        return ns.WayPinsMap:TrackPin(pin)
    end
    return Location.SetWaypoint(pin.mapID, pin.x, pin.y, PERCENT_COORDS)
end

--- Ensure a zone note exists for this pin's map, enable the floating window,
--- and show the OneWay Pins companion on it.
---@param pinID string
---@return string|nil noteId
function WayPins:AttachToZoneNotes(pinID)
    local pin = self:GetPin(pinID)
    if not pin then return nil end

    local mapID = tonumber(pin.mapID)
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    local zoneName = (mapInfo and mapInfo.name) or ""
    if zoneName == "" then return nil end

    local noteId
    for id, data in pairs(ns.Zones:GetAll()) do
        if type(data) == "table" and tonumber(data.mapID) == mapID then
            noteId = id
            break
        end
    end
    if not noteId then
        noteId = ns.Zones:FindIdByParts(zoneName, "")
    end

    if not noteId then
        noteId = ns.Zones:AddZone({
            zone         = zoneName,
            subzone      = "",
            mapID        = mapID,
            content      = "",
            category     = "General",
            storage      = pin.storage or "account",
            pinEnabled   = true,
            showWayPins  = true,
            alertEnabled = false,
        })
    else
        local zd = ns.Zones:GetZone(noteId)
        zd.pinEnabled = true
        zd.showWayPins = true
        if not zd.mapID then
            zd.mapID = mapID
        end
        ns.Zones:SaveZone(noteId, zd)
    end

    local zd = ns.Zones:GetZone(noteId)
    if zd and ns.ZonePins then
        ns.ZonePins:ShowZonePin(noteId, zd)
    end
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:Sync()
    end
    return noteId
end

function WayPins:MapDisplayName(mapID)
    mapID = tonumber(mapID)
    if not mapID then return "" end
    local info = C_Map.GetMapInfo(mapID)
    return (info and info.name) or tostring(mapID)
end

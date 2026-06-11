local _, ns = ...

-- ============================================================================
-- Navigation
-- ============================================================================
-- Shared map navigation for the Catalog: opens the world map to a zone and, when
-- coordinates are known, drops a super-tracked user waypoint.
--
-- Coordinates are stored 0-100 in the quest/vendor data; the waypoint API wants
-- 0-1, so values > 1 are scaled here.
-- ============================================================================

local tonumber = tonumber
local C_Map, C_SuperTrack = C_Map, C_SuperTrack

ns.Navigation = ns.Navigation or {}
local Navigation = ns.Navigation

local function ToFraction(value)
    value = tonumber(value)
    if not value then return nil end
    if value > 1 then
        value = value / 100
    end
    return value
end

--- Opens the world map to `mapID` and sets a super-tracked user waypoint when
--- x/y are provided and the map supports waypoints.
---@param mapID number
---@param x number|nil  0-100 or 0-1
---@param y number|nil  0-100 or 0-1
---@return boolean opened
function Navigation:OpenMapPin(mapID, x, y)
    mapID = tonumber(mapID)
    if not mapID or mapID == 0 then return false end

    OpenWorldMap(mapID)

    x = ToFraction(x)
    y = ToFraction(y)
    if x and y and C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end

    return true
end

--- Opens OneWoW_Notes to the given NPC, adding it under "Quest Givers" if it is
--- not already a saved note. No-op (returns false) when Notes is not installed.
--- OneWoW_Notes is an optional dependency, so its presence is checked here.
---@param npcID number
---@param npcInfo table|nil  { name, zone, mapID, coords = { x, y } }
---@return boolean opened
function Navigation:OpenNPC(npcID, npcInfo)
    npcID = tonumber(npcID)
    if not npcID then return false end

    local notes = OneWoW_Notes
    if not notes then return false end

    npcInfo = npcInfo or {}
    local existing = notes.NPCs:GetNPC(npcID)
    if not existing then
        notes.NPCs:AddNPC(npcID, {
            name     = npcInfo.name,
            zone     = npcInfo.zone,
            mapID    = npcInfo.mapID,
            coords   = npcInfo.coords,
            category = "Quest Givers",
        })
    elseif npcInfo.name and npcInfo.name ~= "" then
        -- Heal a previously-saved placeholder name once a real one is known.
        local cur = existing.name
        if not cur or cur == "" or cur:find("^NPC %d") then
            existing.name = npcInfo.name
            notes.NPCs:SaveNPC(npcID, existing)
        end
    end

    -- pendingNPCSelect covers the case where the NPCs tab is created fresh by
    -- SelectSubTab (its create path consumes it); the direct SelectNPC covers a
    -- tab that already exists.
    notes.pendingNPCSelect = npcID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "npcs")

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "npcs")
    if tabFrame and tabFrame.SelectNPC then
        tabFrame.SelectNPC(npcID)
        notes.pendingNPCSelect = nil
    end

    return true
end

--- Opens OneWoW_Notes to the given item's note, creating it under the "Quest"
--- category if it does not exist yet. No-op (returns false) when Notes is not
--- installed.
---@param itemID number
---@param itemInfo table|nil  { category }
---@return boolean opened
function Navigation:OpenItemNote(itemID, itemInfo)
    itemID = tonumber(itemID)
    if not itemID then return false end

    local notes = OneWoW_Notes
    if not notes then return false end

    if not notes.Items:GetItem(itemID) then
        itemInfo = itemInfo or {}
        notes.Items:AddItem(itemID, { category = itemInfo.category or "Quest" })
    end

    notes.pendingItemSelect = itemID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "items")

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "items")
    if tabFrame and tabFrame.SelectItem then
        tabFrame.SelectItem(itemID)
        notes.pendingItemSelect = nil
    end

    return true
end

--- Mirrors a Catalog item-favorite into OneWoW_Notes > Items: favoriting creates
--- the note (if missing) and flags it favorite; unfavoriting clears the flag but
--- keeps the note. No-op when Notes is not installed.
---@param itemID number
---@param on boolean
function Navigation:SetItemNoteFavorite(itemID, on)
    itemID = tonumber(itemID)
    if not itemID then return end

    local notes = OneWoW_Notes
    if not notes then return end

    local item = notes.Items:GetItem(itemID)
    if on then
        if not item then
            notes.Items:AddItem(itemID, { category = "General", favorite = true })
        else
            item.favorite = true
            notes.Items:SaveItem(itemID, item)
        end
    elseif item then
        item.favorite = false
        notes.Items:SaveItem(itemID, item)
    end
end

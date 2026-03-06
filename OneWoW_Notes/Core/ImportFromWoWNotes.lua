-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/ImportFromWoWNotes.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.ImportFromWoWNotes = {}
local Import = ns.ImportFromWoWNotes

local function copyTable(src)
    local dest = {}
    for k, v in pairs(src) do dest[k] = v end
    return dest
end

local function mergeCategories(srcList, dstList)
    if not srcList or type(srcList) ~= "table" then return end
    local existing = {}
    for _, v in ipairs(dstList) do existing[v] = true end
    for _, v in ipairs(srcList) do
        if not existing[v] then
            table.insert(dstList, v)
        end
    end
end

local function importNotes(srcNotes, dstNotes, counts)
    if not srcNotes then return end
    for noteID, noteData in pairs(srcNotes) do
        if type(noteData) == "table" and not dstNotes[noteID] then
            local imported = copyTable(noteData)
            imported.fontColor = imported.fontColor or "match"
            imported.fontSize  = imported.fontSize  or 12
            imported.opacity   = imported.opacity   or 0.9
            dstNotes[noteID] = imported
            counts.notes = counts.notes + 1
        end
    end
end

local function importPlayers(srcPlayers, dstPlayers, counts)
    if not srcPlayers then return end
    for fullName, playerData in pairs(srcPlayers) do
        if type(playerData) == "table" and not dstPlayers[fullName] then
            local imported = copyTable(playerData)
            if imported.alertOnFound ~= nil and imported.soundEnabled == nil then
                imported.soundEnabled = imported.alertOnFound
                imported.alertOnFound = nil
            end
            imported.soundEnabled = imported.soundEnabled or false
            imported.favorite     = imported.favorite     or false
            dstPlayers[fullName] = imported
            counts.players = counts.players + 1
        end
    end
end

local function importNPCs(srcNPCs, dstNPCs, counts)
    if not srcNPCs then return end
    for npcID, npcData in pairs(srcNPCs) do
        if type(npcData) == "table" and not dstNPCs[npcID] then
            local imported = copyTable(npcData)
            imported.favorite = imported.favorite or false
            dstNPCs[npcID] = imported
            counts.npcs = counts.npcs + 1
        end
    end
end

local function importZones(srcZones, dstZones, counts)
    if not srcZones then return end
    for zoneName, zoneData in pairs(srcZones) do
        if type(zoneData) == "table" and not dstZones[zoneName] then
            local imported = copyTable(zoneData)
            imported.fontColor = imported.fontColor or "match"
            imported.fontSize  = imported.fontSize  or 12
            imported.opacity   = imported.opacity   or 0.9
            dstZones[zoneName] = imported
            counts.zones = counts.zones + 1
        end
    end
end

local function importItems(srcItems, dstItems, counts)
    if not srcItems then return end
    for itemID, itemData in pairs(srcItems) do
        if type(itemData) == "table" and not dstItems[itemID] then
            local imported = copyTable(itemData)
            imported.favorite = imported.favorite or false
            dstItems[itemID] = imported
            counts.items = counts.items + 1
        end
    end
end

function Import:Run()
    local wnDB = _G.WoWNotesDB
    if not wnDB then
        return false
    end

    local addon = _G.OneWoW_Notes
    local counts = { notes = 0, players = 0, npcs = 0, zones = 0, items = 0 }

    local g = wnDB.global
    if g then
        addon.db.global.notes   = addon.db.global.notes   or {}
        addon.db.global.players = addon.db.global.players or {}
        addon.db.global.npcs    = addon.db.global.npcs    or {}
        addon.db.global.zones   = addon.db.global.zones   or {}
        addon.db.global.items   = addon.db.global.items   or {}

        importNotes(g.notes,     addon.db.global.notes,   counts)
        importPlayers(g.players, addon.db.global.players, counts)
        importNPCs(g.npcs,       addon.db.global.npcs,    counts)
        importZones(g.zones,     addon.db.global.zones,   counts)
        importItems(g.items,     addon.db.global.items,   counts)

        local categoryKeys = {
            "notesCustomCategories",
            "itemCustomCategories",
            "zoneCustomCategories",
            "playerCustomCategories",
            "npcCustomCategories",
        }
        for _, key in ipairs(categoryKeys) do
            if g[key] then
                addon.db.global[key] = addon.db.global[key] or {}
                mergeCategories(g[key], addon.db.global[key])
            end
        end
    end

    local charKey = GetRealmName() .. " - " .. UnitName("player")
    local wc = wnDB.char and wnDB.char[charKey]
    if wc then
        addon.db.char.notes   = addon.db.char.notes   or {}
        addon.db.char.players = addon.db.char.players or {}
        addon.db.char.npcs    = addon.db.char.npcs    or {}
        addon.db.char.zones   = addon.db.char.zones   or {}
        addon.db.char.items   = addon.db.char.items   or {}

        importNotes(wc.notes,     addon.db.char.notes,   counts)
        importPlayers(wc.players, addon.db.char.players, counts)
        importNPCs(wc.npcs,       addon.db.char.npcs,    counts)
        importZones(wc.zones,     addon.db.char.zones,   counts)
        importItems(wc.items,     addon.db.char.items,   counts)
    end

    return true, counts
end

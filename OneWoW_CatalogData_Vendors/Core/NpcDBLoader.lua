local _, ns = ...

-- ============================================================================
-- NpcDBLoader
-- ============================================================================
-- Assembles the shipped static NPC database. Each generated data file under
-- Data/NpcDB calls ns:RegisterNpcData{...}; this file defines that registrar
-- and the two lookup tables it feeds:
--
--   ns.StaticVendors      [npcID]  = npc record (roles includes "vendor")
--   ns.StaticVendorItems  [itemID].vendors[npcID] = true
--
-- Shards are emitted offline by bin/npc_split.py. The registrar is a plain
-- merge: no runtime scraping, no _G scanning, no global pollution.
-- ============================================================================

local pairs = pairs

ns.StaticVendors = ns.StaticVendors or {}
ns.StaticVendorItems = ns.StaticVendorItems or {}

local vendors = ns.StaticVendors
local items = ns.StaticVendorItems

--- Merge a generated NpcDB table into the static database.
--- Called once per shipped Data/NpcDB file.
---@param source table<number, table>  npcID -> npc record
function ns:RegisterNpcData(source)
    if type(source) ~= "table" then return end

    for npcID, record in pairs(source) do
        if type(npcID) == "number" and type(record) == "table" then
            vendors[npcID] = record
            if record.items then
                for itemID in pairs(record.items) do
                    if type(itemID) == "number" then
                        items[itemID] = items[itemID] or { vendors = {} }
                        items[itemID].vendors[npcID] = true
                    end
                end
            end
        end
    end
end

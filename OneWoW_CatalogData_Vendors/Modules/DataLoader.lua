-- Adds vendor-specific NPC name resolution to the ItemDataLoader.
local _, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local tremove = tremove
local pairs = pairs
local C_Timer = C_Timer
local C_TooltipInfo = C_TooltipInfo

local nameQueue = {}
local totalNamesResolved = 0

function ns:ExtendDataLoaderWithNPC(loader)
    function loader:GetCachedNPCName(npcID)
        local db = ns:GetDB()
        return db.nameCache and db.nameCache[npcID]
    end

    function loader:ResolveVendorNames()
        if not ns.StaticVendors then return end
        local db = ns:GetDB()
        if not db.nameCache then db.nameCache = {} end

        for npcID in pairs(ns.StaticVendors) do
            if not db.nameCache[npcID] then
                nameQueue[#nameQueue + 1] = npcID
            end
        end

        if #nameQueue > 0 then
            C_Timer.After(2, function()
                loader:ProcessNameQueue()
            end)
        end
    end

    function loader:ProcessNameQueue()
        local db = ns:GetDB()

        for _ = 1, 20 do
            local npcID = tremove(nameQueue, 1)
            if not npcID then break end

            local tooltipData = C_TooltipInfo.GetHyperlink(
                string.format("unit:Creature-0-0-0-0-%d-0000000000", npcID)
            )

            if tooltipData and tooltipData.lines and tooltipData.lines[1] then
                local name = tooltipData.lines[1].leftText
                if name and name ~= "" and not name:find("Retrieving") then
                    db.nameCache[npcID] = name
                    totalNamesResolved = totalNamesResolved + 1
                end
            end
        end

        if #nameQueue > 0 then
            C_Timer.After(0.05, function()
                loader:ProcessNameQueue()
            end)
        else
            if totalNamesResolved > 0 then
                ns:FireScanCallbacks(nil)
            end
            totalNamesResolved = 0
        end
    end

    loader:ResolveVendorNames()
end

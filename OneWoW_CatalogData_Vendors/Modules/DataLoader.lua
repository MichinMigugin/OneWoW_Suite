-- Adds vendor-specific NPC name resolution to the ItemDataLoader.
local _, ns = ...

local wipe, ipairs = wipe, ipairs
local pairs = pairs
local C_Timer = C_Timer
local C_TooltipInfo = C_TooltipInfo
local RETRIEVING_ITEM_INFO = RETRIEVING_ITEM_INFO

local nameQueue = {}
local qHead = 1
local qTail = 0
local retryCount = {}
local totalNamesResolved = 0
local MAX_NAME_RETRIES = 8

local function enqueue(npcID)
    qTail = qTail + 1
    nameQueue[qTail] = npcID
end

local function dequeue()
    if qHead > qTail then
        return nil
    end
    local npcID = nameQueue[qHead]
    nameQueue[qHead] = nil
    qHead = qHead + 1
    return npcID
end

local function queueEmpty()
    return qHead > qTail
end

local function resetQueue()
    wipe(nameQueue)
    wipe(retryCount)
    qHead = 1
    qTail = 0
end

function ns:ExtendDataLoaderWithNPC(loader)
    function loader:GetCachedNPCName(npcID)
        return ns:GetDB().nameCache[npcID]
    end

    function loader:ResolveVendorNames()
        if not ns.StaticVendors then return end
        local db = ns:GetDB()

        for npcID in pairs(ns.StaticVendors) do
            if not db.nameCache[npcID] then
                enqueue(npcID)
            end
        end

        if not queueEmpty() then
            C_Timer.After(2, function()
                loader:ProcessNameQueue()
            end)
        end
    end

    function loader:ProcessNameQueue()
        local db = ns:GetDB()

        for _ = 1, 20 do
            local npcID = dequeue()
            if not npcID then break end

            local tooltipData = C_TooltipInfo.GetHyperlink(
                string.format("unit:Creature-0-0-0-0-%d-0000000000", npcID)
            )

            local name
            if tooltipData and tooltipData.lines then
                for _, line in ipairs(tooltipData.lines) do
                    local text = line.leftText
                    if text and text ~= "" and text ~= RETRIEVING_ITEM_INFO then
                        name = text
                        break
                    end
                end
            end

            if name then
                db.nameCache[npcID] = name
                retryCount[npcID] = nil
                totalNamesResolved = totalNamesResolved + 1
            else
                local tries = (retryCount[npcID] or 0) + 1
                retryCount[npcID] = tries
                if tries < MAX_NAME_RETRIES then
                    enqueue(npcID)
                end
            end
        end

        if not queueEmpty() then
            C_Timer.After(0.05, function()
                loader:ProcessNameQueue()
            end)
        else
            resetQueue()
            if totalNamesResolved > 0 then
                ns:FireScanCallbacks(nil)
            end
            totalNamesResolved = 0
        end
    end

    loader:ResolveVendorNames()
end

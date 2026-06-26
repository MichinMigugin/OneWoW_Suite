local _, ns = ...

ns.Bags = {}
local Module = ns.Bags

-- Backpack + bags 0-5. Flat (no tabs): each bag is its own unit. Slot scanning
-- and the canonical record shape live in ns.ContainerScan.
function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local bags = {}

    for bagID = 0, 5 do
        local slots, _, numSlots = ns.ContainerScan:BagSlots(bagID)
        if numSlots and numSlots > 0 then
            bags[bagID] = {
                slots = slots,
                numSlots = numSlots,
            }
        end
    end

    charData.bags = bags
    charData.bagsLastUpdate = time()

    return true
end

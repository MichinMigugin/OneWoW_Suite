local _, ns = ...

local E = ns.TrackerEvaluators
local tonumber = tonumber
local Collectibles = OneWoW.Collectibles

E.Register("toy", function(op)
    local itemID = tonumber(op.itemID)
    if itemID then
        local st = Collectibles.GetCollectionState(Collectibles.BuildKey("toy", itemID))
        return (st and st.collected) and 1 or 0, 1
    end
end)

E.Register("mount", function(op)
    local mountID = tonumber(op.mountID)
    if mountID then
        local st = Collectibles.GetCollectionState(Collectibles.BuildKey("mount", mountID))
        return (st and st.collected) and 1 or 0, 1
    end
end)

E.Register("pet", function(op)
    local speciesID = tonumber(op.speciesID)
    if speciesID then
        local st = Collectibles.GetCollectionState(Collectibles.BuildKey("pet", speciesID))
        return (st and st.numCollected) or 0, 1
    end
end)

E.Register("transmog", function(op)
    local appearanceID = tonumber(op.itemModifiedAppearanceID)
    if appearanceID then
        local st = Collectibles.GetCollectionState(Collectibles.BuildKey("appearance", "source", appearanceID))
        return (st and st.collected) and 1 or 0, 1
    end
end)

-- Live ATT extras overlay. Only runs if AllTheThings is already loaded.
-- Never LoadAddOn / EnsureLoaded ATT. Per-card SearchForField only.
local _, ns = ...

local JournalData = ns.JournalData
local ATTLive = {}
ns.ATTLiveExtras = ATTLive

local HEADER_RARES = -46
local HEADER_WORLD_BOSSES = -61

---@return table|nil
local function GetATT()
    if not C_AddOns.IsAddOnLoaded("AllTheThings") then
        return nil
    end
    local att = AllTheThings
    if not att or not att.SearchForField then
        return nil
    end
    return att
end

---@param group table
---@param out table
local function CollectItemGroups(group, out)
    if group.itemID then
        tinsert(out, group)
    end
    local kids = group.g
    if kids then
        for i = 1, #kids do
            CollectItemGroups(kids[i], out)
        end
    end
end

---@param group table
---@param out table
local function CollectWorldRareItems(group, out)
    local headerID = group.headerID
    if headerID == HEADER_RARES or headerID == HEADER_WORLD_BOSSES then
        CollectItemGroups(group, out)
        return
    end
    local kids = group.g
    if kids then
        for i = 1, #kids do
            CollectWorldRareItems(kids[i], out)
        end
    end
end

---@param inst table
---@return table seen
local function ExistingItemIDs(inst)
    local seen = {}
    for _, enc in ipairs(inst.encounters or {}) do
        for _, item in ipairs(enc.items or {}) do
            if item.itemID then
                seen[item.itemID] = true
            end
        end
    end
    return seen
end

---@param inst table
---@param groups table|nil
---@param worldOnly boolean
---@param att table
---@param seen table
---@param extras table
local function HarvestGroups(inst, groups, worldOnly, att, seen, extras)
    if not groups then
        return
    end
    local GetRelativeValue = att.GetRelativeValue
    for i = 1, #groups do
        local group = groups[i]
        local harvested = {}
        if worldOnly then
            CollectWorldRareItems(group, harvested)
        else
            CollectItemGroups(group, harvested)
        end
        for j = 1, #harvested do
            local node = harvested[j]
            local itemID = node.itemID
            if itemID and not seen[itemID] then
                local unobtainable = node.u or (GetRelativeValue and GetRelativeValue(node, "u"))
                if not unobtainable then
                    seen[itemID] = true
                    local loc = {
                        encounterID = GetRelativeValue and GetRelativeValue(node, "encounterID") or 0,
                        instanceID  = inst.instanceID,
                        npcID       = GetRelativeValue and GetRelativeValue(node, "npcID") or node.npcID,
                        source      = "att-live",
                    }
                    tinsert(extras, {
                        itemID   = itemID,
                        itemData = {
                            itemID      = itemID,
                            name        = node.text or node.name,
                            toyID       = node.toyID,
                            mountID     = node.mountID,
                            speciesID   = node.speciesID,
                            spellID     = node.spellID,
                            questID     = node.questID,
                            achievementID = node.achievementID,
                            source      = "att-live",
                        },
                        difficulties = {},
                        source       = "att-live",
                        encounterID  = loc.encounterID,
                        instanceID   = loc.instanceID,
                        npcID        = loc.npcID,
                    })
                end
            end
        end
    end
end

--- Append unseen ATT extras onto an already-built card. Safe no-op without ATT.
---@param inst table
---@return boolean added
function JournalData:MergeLiveATTExtras(inst)
    if not inst or inst.instanceType == "delve" then
        return false
    end
    local att = GetATT()
    if not att then
        return false
    end
    if att.GetDatabaseRoot then
        att:GetDatabaseRoot()
    end

    local seen = ExistingItemIDs(inst)
    local extras = {}
    if inst.instanceID and inst.instanceID > 0 then
        HarvestGroups(inst, att.SearchForField("instanceID", inst.instanceID), false, att, seen, extras)
    end
    if inst.instanceType == "world" and inst.mapID then
        HarvestGroups(inst, att.SearchForField("mapID", inst.mapID), true, att, seen, extras)
    end
    if #extras == 0 then
        return false
    end

    local extrasEnc
    for _, enc in ipairs(inst.encounters) do
        if enc.encounterID == self.EXTRAS_ENC_ID then
            extrasEnc = enc
            break
        end
    end
    local built = self:BuildExtrasEncounter(extras)
    if not built then
        return false
    end
    if extrasEnc then
        for _, item in ipairs(built.items) do
            tinsert(extrasEnc.items, item)
        end
        sort(extrasEnc.items, function(a, b)
            return (a.name or "") < (b.name or "")
        end)
    else
        tinsert(inst.encounters, built)
        self:SortEncountersInPlace(inst)
    end
    self:RecalculateInstanceTotals(inst)
    return true
end

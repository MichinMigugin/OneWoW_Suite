local _, ns = ...

-- Read-side query layer (CROSS_ALT_SEARCH_DESIGN.md §3-§5). A container
-- descriptor registry drives a single Gather that normalizes every stored slot
-- shape into OneWoWItemInstance[]; Filter runs PE in link-mode; Group buckets by
-- a key function. FindDuplicates is Group(BuildDupeKey) plus a min-count cut and
-- an ilvl within-bucket pass. Pure addition: nothing on the write side calls in.

local PE = OneWoW.PredicateEngine
local API = OneWoW_AltTracker_Storage_API

ns.Query = {}
local Query = ns.Query

-- ---------------------------------------------------------------------------
-- Normalization
-- ---------------------------------------------------------------------------

-- Char display fields, resolved from the Character unit when present. Mirrors
-- ItemIndex's GetCharMeta so locations carry the same name/realm a charKey maps
-- to elsewhere; falls back to splitting the key if the unit isn't loaded.
local function GetCharMeta(charKey)
    local capi = OneWoW_AltTracker_Character_API
    local cd = capi and capi.GetCharacterData(charKey)
    if cd then return cd.name, cd.realm end
    local name, realm = charKey:match("^(.+)-(.+)$")
    return name or charKey, realm or ""
end

-- Build one OneWoWItemInstance from a stored slot record. The stored shapes
-- disagree on field names (stackCount vs count, itemName vs name) -- this is the
-- single place that reconciles them. Returns nil for empty/0-itemID slots so
-- callers never branch on a missing item (§11 "Empty / 0-itemID slots").
local function MakeInstance(slot, locType, where, lastSeen)
    if not slot then return nil end
    local itemID = slot.itemID
    if not itemID or itemID == 0 then return nil end

    where.type = locType
    return {
        itemID      = itemID,
        itemLink    = slot.itemLink,
        name        = slot.itemName or slot.name,
        quality     = slot.quality or slot.itemRarity,
        texture     = slot.texture,
        count       = slot.stackCount or slot.count or slot.quantity or 1,
        vendorPrice = slot.sellPrice or 0,
        isBound     = slot.isBound == true,
        lastSeen    = lastSeen or 0,
        where       = where,
    }
end

-- ---------------------------------------------------------------------------
-- Container descriptor registry (§3)
-- ---------------------------------------------------------------------------
-- Each descriptor owns the read traversal for one container kind. scopeType
-- encodes the account/guild rule (§6): "character" containers iterate the
-- resolved char set; "account"/"guild" are gated only by their own flag.
-- `gather(ctx, emit)` walks the right SV path and emits an instance per slot.
--
-- Equipped + auction sources (which live in sibling units, not this unit's SV)
-- are intentionally out of scope for this first read layer; they join when the
-- Items tab migrates onto Query (§10 step 4).

local DESCRIPTORS = {
    {
        id = "bags", scopeType = "character", locationType = "bags", setting = "trackBags",
        gather = function(ctx, emit)
            for charKey in pairs(ctx.charSet) do
                local cd = ctx.db.characters[charKey]
                if cd and cd.bags then
                    local name = GetCharMeta(charKey)
                    local lastSeen = cd.bagsLastUpdate or 0
                    for bagID, bagData in pairs(cd.bags) do
                        if bagData.slots then
                            for slotID, slot in pairs(bagData.slots) do
                                emit(MakeInstance(slot, "bags", {
                                    charKey = charKey, charName = name,
                                    bagID = bagID, slotID = slotID,
                                }, lastSeen))
                            end
                        end
                    end
                end
            end
        end,
    },
    {
        id = "personal", scopeType = "character", locationType = "bank", setting = "trackPersonalBank",
        gather = function(ctx, emit)
            for charKey in pairs(ctx.charSet) do
                local cd = ctx.db.characters[charKey]
                if cd and cd.personalBank and cd.personalBank.tabs then
                    local name = GetCharMeta(charKey)
                    local lastSeen = cd.personalBankLastUpdate or 0
                    for tabIndex, tabData in pairs(cd.personalBank.tabs) do
                        if tabData.items then
                            for slotID, slot in pairs(tabData.items) do
                                emit(MakeInstance(slot, "bank", {
                                    charKey = charKey, charName = name,
                                    tabIndex = tabIndex, slotID = slotID,
                                }, lastSeen))
                            end
                        end
                    end
                end
            end
        end,
    },
    {
        id = "warband", scopeType = "account", locationType = "warband", setting = "trackWarbandBank",
        gather = function(ctx, emit)
            local wb = ctx.db.warbandBank
            if wb and wb.tabs then
                local lastSeen = wb.lastUpdateTime or 0
                for tabIndex, tabData in pairs(wb.tabs) do
                    if tabData.items then
                        for slotID, slot in pairs(tabData.items) do
                            emit(MakeInstance(slot, "warband", {
                                tabIndex = tabIndex, slotID = slotID,
                            }, lastSeen))
                        end
                    end
                end
            end
        end,
    },
    {
        id = "guild", scopeType = "guild", locationType = "guild", setting = "trackGuildBank",
        gather = function(ctx, emit)
            local banks = ctx.db.guildBanks
            if not banks then return end
            for guildName, guildData in pairs(banks) do
                if (not ctx.guildsFilter or ctx.guildsFilter[guildName]) and guildData.tabs then
                    local lastSeen = guildData.lastUpdateTime or 0
                    for tabIndex, tabData in pairs(guildData.tabs) do
                        if tabData.slots then
                            for slotID, slot in pairs(tabData.slots) do
                                emit(MakeInstance(slot, "guild", {
                                    guildName = guildName,
                                    tabIndex = tabIndex, slotID = slotID,
                                }, lastSeen))
                            end
                        end
                    end
                end
            end
        end,
    },
    {
        id = "mail", scopeType = "character", locationType = "mail", setting = "trackMail",
        gather = function(ctx, emit)
            for charKey in pairs(ctx.charSet) do
                local cd = ctx.db.characters[charKey]
                if cd and cd.mail and cd.mail.mails then
                    local name = GetCharMeta(charKey)
                    local lastSeen = cd.mailLastUpdate or 0
                    for mailID, mail in pairs(cd.mail.mails) do
                        if mail.items then
                            for attachmentIndex, slot in pairs(mail.items) do
                                emit(MakeInstance(slot, "mail", {
                                    charKey = charKey, charName = name,
                                    mailID = mailID, slotID = attachmentIndex,
                                }, lastSeen))
                            end
                        end
                    end
                end
            end
        end,
    },
}

-- ---------------------------------------------------------------------------
-- Effective ilvl (lazy, memoized -- §4)
-- ---------------------------------------------------------------------------

--- Effective item level for an instance, resolved on first access from the link
--- and cached on the record. Only ilvl grouping / ilvl predicates trigger it.
---@param inst table OneWoWItemInstance
---@return number ilvl effective; 0 if the link is missing or uncached
function API.GetEffectiveILvl(inst)
    if inst._ilvl then return inst._ilvl end
    local lvl = inst.itemLink and C_Item.GetDetailedItemLevelInfo(inst.itemLink)
    inst._ilvl = lvl or 0
    return inst._ilvl
end

-- ---------------------------------------------------------------------------
-- Gather / Filter / Group / Query (§5)
-- ---------------------------------------------------------------------------

local function ResolveCharSet(chars, db)
    local set = {}
    if chars == nil or chars == "all" then
        for k in pairs(db.characters) do set[k] = true end
    elseif type(chars) == "string" then
        set[chars] = true
    else
        for _, k in ipairs(chars) do set[k] = true end
    end
    return set
end

--- EXPENSIVE, scope-driven. Walks the enabled descriptors and normalizes every
--- occupied slot into OneWoWItemInstance[]. Call on scope change; cache it.
---@param scope table OneWoWQueryScope { chars, containers, guilds }
---@return table[] instances
function Query.Gather(scope)
    scope = scope or {}
    local db = OneWoW_AltTracker_Storage_DB
    local containers = scope.containers or {}

    local ctx = { db = db, charSet = ResolveCharSet(scope.chars, db) }
    if scope.guilds then
        ctx.guildsFilter = {}
        for _, g in ipairs(scope.guilds) do ctx.guildsFilter[g] = true end
    end

    local results = {}
    local function emit(inst)
        if inst then results[#results + 1] = inst end
    end

    for _, d in ipairs(DESCRIPTORS) do
        if containers[d.id] then
            d.gather(ctx, emit)
        end
    end
    return results
end

--- CHEAP, predicate-driven. Compiles the PE expr once and evaluates each
--- instance via BuildProps in link-mode (the MatchesSearch pattern, one place).
--- A nil/empty predicate returns the input untouched; an invalid one yields {}.
---@param instances table[]
---@param predicate string|nil PE expression, e.g. "#gear & ilvl<=263"
---@return table[] instances
function Query.Filter(instances, predicate)
    if not predicate or predicate == "" then return instances end
    local compiled = PE:Compile(predicate)
    if not compiled then return {} end

    local out = {}
    for _, inst in ipairs(instances) do
        local props = PE:BuildProps(inst.itemID, nil, nil, inst.itemLink)
        if PE:SafeEvaluate(compiled, props) then
            out[#out + 1] = inst
        end
    end
    return out
end

--- Bucket instances by a key function (nil key => instance skipped). Returns
--- nil when keyFn is nil so the caller falls back to the flat list. Group order
--- is first-seen for stable display.
---@param instances table[]
---@param keyFn fun(inst:table):string|nil
---@return table[]|nil groups
function Query.Group(instances, keyFn)
    if not keyFn then return nil end

    local byKey, order = {}, {}
    for _, inst in ipairs(instances) do
        local key = keyFn(inst)
        if key ~= nil then
            local g = byKey[key]
            if not g then
                g = { key = key, members = {}, totalCount = 0, slotCount = 0 }
                byKey[key] = g
                order[#order + 1] = g
            end
            g.members[#g.members + 1] = inst
            g.totalCount = g.totalCount + (inst.count or 1)
            g.slotCount = g.slotCount + 1
        end
    end
    return order
end

local function ResolveGroupKeyFn(group)
    if group == nil or group == "none" then return nil end
    if group == "itemID" then
        return function(inst) return "id:" .. inst.itemID end
    end
    if type(group) == "function" then return group end
    return nil
end

--- One-shot Gather -> Filter -> Group for non-interactive callers. Returns the
--- flat instance list when no grouping is requested, else the group list.
---@param opts table OneWoWQueryOpts (scope + .predicate + .group)
---@return table[] instances|groups
function Query.Query(opts)
    opts = opts or {}
    local insts = Query.Filter(Query.Gather(opts), opts.predicate)
    local keyFn = ResolveGroupKeyFn(opts.group)
    if not keyFn then return insts end
    return Query.Group(insts, keyFn)
end

-- ---------------------------------------------------------------------------
-- Duplicate finder (§5 "what is a duplicate")
-- ---------------------------------------------------------------------------

-- The initial default: same base item, redundant within an ilvl band, split by
-- primary/secondary stats and socket presence. Presets are named specs the UI
-- loads into its controls; tweaking from there yields a "Custom" spec.
local DEFAULT_DUPE_SPEC = {
    mode = "item", ilvlMode = "range", ilvlTolerance = 0,
    matchPrimary = true, matchSecondary = true, matchSocket = true,
    matchTrack = false,
    minCount = 2,
}

-- matchTrack defaults off in every preset: the ilvl-range pass already separates
-- copies by power, and the dupe table surfaces the track column, so casual
-- "what dupes do I have" grouping stays broad. Toggle it on to keep different
-- upgrade tracks (Hero vs Veteran) as separate duplicates.
local PRESETS = {
    same_item      = { mode = "item",    ilvlMode = "off",   matchPrimary = false, matchSecondary = false, matchSocket = false, matchTrack = false, minCount = 2 },
    same_item_ilvl = { mode = "item",    ilvlMode = "exact", matchPrimary = false, matchSecondary = false, matchSocket = false, matchTrack = false, minCount = 2 },
    same_gear      = { mode = "item",    ilvlMode = "range", matchPrimary = true,  matchSecondary = true,  matchSocket = true,  matchTrack = false, minCount = 2 },
    similar_gear   = { mode = "similar", ilvlMode = "range", matchPrimary = true,  matchSecondary = true,  matchSocket = true,  matchTrack = false, minCount = 2 },
}

-- Dominant primary stat as a stable code. Same itemID => same primary, so this
-- only splits in "similar" mode / across bonus-varied tertiaries. Stamina is a
-- fallback only (it's on nearly all gear and would dominate by magnitude), used
-- when the item has no Int/Str/Agi -- kept in sync with the UI's PrimaryDisplay.
local function PrimaryFrom(p)
    local i = p.statIntellect or 0
    local s = p.statStrength or 0
    local a = p.statAgility or 0
    if i == 0 and s == 0 and a == 0 then
        return (p.statStamina or 0) > 0 and "stam" or "0"
    end
    if i >= s and i >= a then return "int" end
    if s >= a then return "str" end
    return "agi"
end

-- Presence SET of secondary stats (not magnitudes) as a stable signature.
local SECONDARY = {
    { "c", "statCrit" }, { "h", "statHaste" },
    { "m", "statMastery" }, { "v", "statVersatility" },
}
local function SecondarySetFrom(p)
    local parts = {}
    for _, pair in ipairs(SECONDARY) do
        if (p[pair[2]] or 0) > 0 then parts[#parts + 1] = pair[1] end
    end
    return table.concat(parts)
end

-- Reads PE prop VALUES from one identity-cached BuildProps(link) call. ilvlMode
-- =="range" is deliberately NOT a key component -- range isn't a clean
-- equivalence, so it's a within-bucket post-pass (ApplyIlvlRangePass) instead.
-- Returns nil for non-equippable items in "similar" mode (they have no slot to
-- be functionally equivalent on), excluding them from the grouping.
local function BuildDupeKey(inst, spec)
    local p = PE:BuildProps(inst.itemID, nil, nil, inst.itemLink)
    local key
    if spec.mode == "similar" then
        local loc = p.equipLoc
        if not loc or loc == "" or loc == "INVTYPE_NON_EQUIP" then return nil end
        key = "slot:" .. loc .. ":" .. tostring(p.classID) .. ":" .. tostring(p.subClassID)
    else
        key = "id:" .. inst.itemID
    end
    if spec.ilvlMode == "exact" then key = key .. "|i" .. (p.ilvl or 0) end
    if spec.matchPrimary       then key = key .. "|p" .. PrimaryFrom(p) end
    if spec.matchSecondary     then key = key .. "|s" .. SecondarySetFrom(p) end
    if spec.matchSocket        then key = key .. "|k" .. (p.hasSocket and 1 or 0) end
    -- Split by upgrade track only (Hero/Veteran/...); level differences within a
    -- track are handled by the ilvl-range post-pass, not the key.
    if spec.matchTrack         then key = key .. "|t" .. (p.upgradeTrackStringID or 0) end
    return key
end

-- Within one dupe bucket: anchor to the highest effective ilvl and flag copies
-- within `tolerance` below it as redundant ("a best copy and N near-copies you
-- don't need"). Records the sorted distinct ilvls as group.ilvlSpread.
local function ApplyIlvlRangePass(group, tolerance)
    local maxILvl, seen = 0, {}
    for _, inst in ipairs(group.members) do
        local lvl = API.GetEffectiveILvl(inst)
        if lvl > maxILvl then maxILvl = lvl end
        seen[lvl] = true
    end

    local spread = {}
    for lvl in pairs(seen) do spread[#spread + 1] = lvl end
    sort(spread)
    group.ilvlSpread = spread
    group.anchorILvl = maxILvl

    for _, inst in ipairs(group.members) do
        inst.redundant = API.GetEffectiveILvl(inst) >= (maxILvl - tolerance)
    end
end

--- Duplicate groups = Group by BuildDupeKey(spec), kept where slotCount >=
--- spec.minCount. In "range" ilvl mode each surviving group also gets the
--- anchor-to-max redundancy pass.
---@param opts table OneWoWQueryScope + .predicate + .dupe (OneWoWDupeSpec)
---@return table[] groups
function Query.FindDuplicates(opts)
    opts = opts or {}
    local spec = opts.dupe or DEFAULT_DUPE_SPEC
    local insts = Query.Filter(Query.Gather(opts), opts.predicate)
    local groups = Query.Group(insts, function(inst) return BuildDupeKey(inst, spec) end)

    local minCount = spec.minCount or 2
    local dupes = {}
    for _, g in ipairs(groups) do
        if g.slotCount >= minCount then
            if spec.ilvlMode == "range" then
                ApplyIlvlRangePass(g, spec.ilvlTolerance or 0)
            end
            dupes[#dupes + 1] = g
        end
    end
    return dupes
end

-- ---------------------------------------------------------------------------
-- Public read surface
-- ---------------------------------------------------------------------------

API.Gather         = Query.Gather
API.Filter         = Query.Filter
API.Group          = Query.Group
API.Query          = Query.Query
API.FindDuplicates = Query.FindDuplicates

--- Named dupe presets the UI loads into its controls. Keyed by preset id.
---@return table presets
function API.GetDupePresets()
    return PRESETS
end

--- A fresh copy of the default dupe spec ("Same gear"). Copy so callers can
--- mutate it (toggle controls) without touching the shared default.
---@return table spec OneWoWDupeSpec
function API.GetDefaultDupeSpec()
    local copy = {}
    for k, v in pairs(DEFAULT_DUPE_SPEC) do copy[k] = v end
    return copy
end

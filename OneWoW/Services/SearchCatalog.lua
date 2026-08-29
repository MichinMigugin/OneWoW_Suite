local _, ns = ...

-- ============================================================================
-- SearchCatalog
-- ============================================================================
-- One registry of named search expressions. The three surface syntaxes are
-- lenses over the same entry model, each with its own name namespace:
--   #token          token-safe names       (native, core SV)
--   SAVED(Name)     free-form names        (native, core SV)
--   CATEGORY(Name)  Bags category rules    (external provider)
--
-- Design decisions:
--   - Ids are internal and never appear in expression text. Expressions keep
--     human names, so a rename must never require rewriting stored text
--   - Rename pushes the old name onto formerNames and resolution falls back to
--     them, so stale text, old exports, and frozen profile snapshots still work
--   - Former names are unique within a kind: claiming a name strips it from
--     every other entry, so (kind, name) resolves to at most one entry
--   - Namespaces are kind-scoped, so #sell and SAVED(Sell) may differ
--   - Kinds owned by another load unit register a provider instead of storing
--     here, which keeps optional units' data in their own SavedVariables
-- ============================================================================

local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local error = error
local type = type
local sort = sort
local tinsert = tinsert
local tremove = tremove
local wipe = wipe
local strlower = string.lower
local strmatch = string.match
local strgmatch = string.gmatch
local strgsub = string.gsub
local strtrim = strtrim
local format = string.format
local tconcat = table.concat
local print = print
local time = time
local random = math.random

ns.SearchCatalog = {}
local SearchCatalog = ns.SearchCatalog

local PE = ns.PredicateEngine

local SCHEMA_VERSION = 1

-- Former names exist only to keep stale text resolving, so the oldest is
-- dropped once an entry has been renamed this many times.
-- TODO: prune former names no expression references, once a reference index
-- can tell which ones are still load-bearing.
local MAX_FORMER_NAMES = 5

-- `native` kinds live in core SV. `pattern` is the name grammar, `lowerNames`
-- forces stored names lowercase (tokens are written as #name, so case would be
-- misleading), and `isReserved` rejects names the engine already owns.
local KINDS = {
    token = {
        native = true,
        pattern = "^[%w_]+$",
        lowerNames = true,
        -- Called at validation time, not capture time: #upgrade, #combineready
        -- and #disenchantable register after this file loads.
        --
        -- The onewow_ prefix is reserved because SearchExpand emits sentinel
        -- tokens like #onewow_saved_missing to make a broken reference match
        -- nothing. Those only fail closed while no token resolves them, so a
        -- user must not be able to define one and turn a fail-closed into a hit.
        isReserved = function(name)
            return PE:IsBuiltinKeyword(name) or strmatch(name, "^onewow_") ~= nil
        end,
    },
    saved = {
        native = true,
        pattern = "^[%w %-%_%+]+$",
        lowerNames = false,
    },
    category = {
        native = false,
    },
}

-- Stable iteration order for anything that walks every kind. `pairs(KINDS)` is
-- unordered, so a cross-kind search would return a different winner run to run.
local KIND_ORDER = { "token", "saved", "category" }

local providers = {}       ---@type table<string, table>
local indexCache = {}      ---@type table<string, table>
local changeCallbacks = {} ---@type table<string, fun()>

-- Change notification is expensive downstream: a single fire drops PE's token
-- and expression caches and drags Bags through a re-categorize plus a full
-- layout refresh. Batching collapses a run of mutations into one fire.
local batchDepth = 0
local batchPending = false

local function GetStore()
    return ns.db.global.searchCatalog
end

local function NormKey(name)
    return strlower(strtrim(name or ""))
end

local function FireChanged()
    if batchDepth > 0 then
        batchPending = true
        return
    end
    for _, fn in pairs(changeCallbacks) do
        fn()
    end
end

-- Cache-only, deliberately silent. The notifying counterpart is the public
-- `SearchCatalog:InvalidateKind`, which is this plus `FireChanged`. They used to
-- share a name, so a call site that meant "and tell the UI" and one that meant
-- "just drop the cache" were one `self:` apart and read identically — which is
-- exactly how the prune ended up mutating former names with nothing listening.
local function DropIndex(kind)
    indexCache[kind] = nil
end

--- Visit every entry of a kind, whether it is stored natively or supplied by a
--- provider. Provider-backed entries are live tables owned by that unit.
---@param kind string
---@param fn fun(entry: table)
local function EachEntry(kind, fn)
    if KINDS[kind].native then
        for _, entry in pairs(GetStore().entries) do
            if entry.kind == kind then fn(entry) end
        end
        return
    end
    local provider = providers[kind]
    if not provider then return end
    for _, entry in ipairs(provider.Enumerate()) do
        fn(entry)
    end
end

-- Former names are seeded first so a current name always overwrites them.
local function GetIndex(kind)
    local index = indexCache[kind]
    if index then return index end

    index = {}
    EachEntry(kind, function(entry)
        if entry.formerNames then
            for _, former in ipairs(entry.formerNames) do
                index[NormKey(former)] = { id = entry.id, via = "former" }
            end
        end
    end)
    EachEntry(kind, function(entry)
        index[NormKey(entry.name)] = { id = entry.id, via = "current" }
    end)

    indexCache[kind] = index
    return index
end

local function GetEntryById(kind, id)
    if KINDS[kind].native then
        return GetStore().entries[id]
    end
    local provider = providers[kind]
    if not provider then return nil end
    return provider.Get(id)
end

local function ValidateName(kind, name)
    local spec = KINDS[kind]
    name = strtrim(name or "")
    if name == "" then return nil, "CATALOG_INVALID_NAME" end
    if spec.pattern and not strmatch(name, spec.pattern) then
        return nil, "CATALOG_INVALID_NAME"
    end
    if spec.lowerNames then name = strlower(name) end
    return name
end

local function PushFormerName(entry, oldName)
    local formers = entry.formerNames
    if not formers then
        formers = {}
        entry.formerNames = formers
    end
    local key = NormKey(oldName)
    for i = #formers, 1, -1 do
        if NormKey(formers[i]) == key then tremove(formers, i) end
    end
    tinsert(formers, oldName)
    while #formers > MAX_FORMER_NAMES do
        tremove(formers, 1)
    end
end

--- Enforce former-name uniqueness: once `name` is a live name, no entry of the
--- kind may keep it as a former name. Without this, two entries could both
--- claim it and resolution would be ambiguous. This also covers reclaiming a
--- name the owner itself had retired.
---@param kind string
---@param name string
local function ClaimName(kind, name)
    local key = NormKey(name)
    EachEntry(kind, function(entry)
        local formers = entry.formerNames
        if not formers then return end
        for i = #formers, 1, -1 do
            if NormKey(formers[i]) == key then tremove(formers, i) end
        end
    end)
end

local function NewId(entries)
    local id
    repeat
        id = format("sc_%d_%d", time(), random(1000, 9999))
    until not entries[id]
    return id
end

-- ---- Providers and change notification ----

--- Register the owner of a non-native kind.
---
--- Contract:
---   Enumerate() -> entry[]     every entry of the kind
---   Get(id)     -> entry|nil   one entry by id
---   SetName(id, name)          optional; required for RenameExternal
---
--- An entry is `{ id, kind, name, formerNames, body }`. `body` is nil or empty
--- for an entry that exists but carries no rule — a type-mode Bags category —
--- which callers see as the `empty` status rather than `missing`.
---
--- Read-only by design: the owner keeps its records in its own SavedVariables,
--- which is what lets an optional load unit stay self-contained. Entries may be
--- adapters over those records rather than the records themselves, so anything
--- that must persist has to go back through the owner. `formerNames` is the
--- exception and must be passed through by reference, because rename
--- bookkeeping writes into it.
---
--- The owner calls InvalidateKind whenever names or bodies change, or the
--- kind-scoped name index goes stale.
--- Registration is silent on purpose — the only two `DropIndex` calls here that
--- do not notify. It happens during load, before anything is listening, and a
--- fire would drag every consumer through a rebuild for a kind whose contents
--- have not changed yet.
---@param kind string
---@param provider table
function SearchCatalog:RegisterProvider(kind, provider)
    providers[kind] = provider
    DropIndex(kind)
end

---@param kind string
function SearchCatalog:UnregisterProvider(kind)
    providers[kind] = nil
    DropIndex(kind)
end

--- Drop the cached name index for a kind. Providers must call this when their
--- underlying data changes, or lookups will resolve against stale names.
---@param kind string
function SearchCatalog:InvalidateKind(kind)
    DropIndex(kind)
    FireChanged()
end

--- Drop every cached name index. For callers that swap the whole store out
--- from under the catalog, such as applying a profile snapshot.
function SearchCatalog:InvalidateAll()
    wipe(indexCache)
    FireChanged()
end

-- ---- Batching ----

--- Hold change notifications until the matching EndBatch. Nesting is a depth
--- counter, so an inner batch cannot release an outer one early. At most one
--- notification fires when the outermost batch ends, and none at all if nothing
--- actually changed. Prefer WithBatch, which cannot leak the counter.
function SearchCatalog:BeginBatch()
    batchDepth = batchDepth + 1
end

--- Release one level of batching, firing the coalesced notification when the
--- outermost level closes.
function SearchCatalog:EndBatch()
    if batchDepth == 0 then return end
    batchDepth = batchDepth - 1
    if batchDepth > 0 or not batchPending then return end
    batchPending = false
    FireChanged()
end

--- Run `fn` with change notifications coalesced into a single fire. The depth
--- counter is unwound even when `fn` errors, so a failure part-way through a
--- bulk operation cannot leave the change bus muted for the rest of the
--- session; the error is re-raised afterwards.
---@param fn fun()
function SearchCatalog:WithBatch(fn)
    self:BeginBatch()
    local ok, err = pcall(fn)
    self:EndBatch()
    if not ok then error(err, 0) end
end

---@param id string
---@param fn fun()
function SearchCatalog:RegisterChangedCallback(id, fn)
    changeCallbacks[id] = fn
end

---@param id string
function SearchCatalog:UnregisterChangedCallback(id)
    changeCallbacks[id] = nil
end

-- ---- Lookup ----

--- Resolve a name within a kind. Current names win over former names.
---@param kind string
---@param name string|nil
---@return table|nil entry
---@return string status "current" | "former" | "missing"
function SearchCatalog:Resolve(kind, name)
    local key = NormKey(name)
    if key == "" then return nil, "missing" end
    local hit = GetIndex(kind)[key]
    if not hit then return nil, "missing" end
    local entry = GetEntryById(kind, hit.id)
    if not entry then return nil, "missing" end
    return entry, hit.via
end

--- Resolve a name to its expression body. `empty` distinguishes an entry that
--- exists but carries no rule (a type-mode Bags category) from a name that
--- resolves to nothing at all, so callers can report the two differently.
---@param kind string
---@param name string|nil
---@return string|nil body
---@return string status "current" | "former" | "missing" | "empty"
function SearchCatalog:GetBody(kind, name)
    local entry, status = self:Resolve(kind, name)
    if not entry then return nil, status end
    if type(entry.body) ~= "string" or entry.body == "" then return nil, "empty" end
    return entry.body, status
end

---@param kind string
---@param id string
---@return table|nil
function SearchCatalog:GetById(kind, id)
    return GetEntryById(kind, id)
end

--- Every entry of a kind, sorted by name (case-insensitive).
---@param kind string
---@return table[]
function SearchCatalog:GetAll(kind)
    local out = {}
    EachEntry(kind, function(entry) tinsert(out, entry) end)
    sort(out, function(a, b) return NormKey(a.name) < NormKey(b.name) end)
    return out
end

--- Validate and normalize a display name for a kind.
---
--- Public so no other file has to restate a name grammar. Returns the catalog's
--- own error code; callers map that to their own message keys (see
--- `SAVED_ERRORS` / `ALIAS_ERRORS` in SearchExpand) rather than letting internal
--- codes reach user-facing text.
---@param kind string
---@param name string|nil
---@return string|nil normalized
---@return string|nil errorKey
function SearchCatalog:ValidateName(kind, name)
    if not KINDS[kind] then return nil, "CATALOG_INVALID_NAME" end
    return ValidateName(kind, name)
end

--- Name check for create/rename *before* confirm dialogs.
---
--- Create (`exceptId` nil): an existing live name is allowed — `Set` updates that
--- body. Reserved only rejects names that are not already a live entry.
--- Rename (`exceptId` set): a live clash with another id is `CATALOG_DUPLICATE_NAME`;
--- reserved names that are not this entry are `CATALOG_NAME_RESERVED`.
---@param kind string
---@param name string|nil
---@param exceptId string|nil
---@return string|nil normalized
---@return string|nil errorKey
function SearchCatalog:ValidateWritableName(kind, name, exceptId)
    local spec = KINDS[kind]
    if not spec then return nil, "CATALOG_INVALID_NAME" end

    local normalized, err = ValidateName(kind, name)
    if not normalized then return nil, err end

    local clash, status = self:Resolve(kind, normalized)
    if clash and status == "current" then
        if exceptId and clash.id ~= exceptId then
            return nil, "CATALOG_DUPLICATE_NAME"
        end
        -- Create targeting an existing live name, or rename keeping this entry.
        return normalized
    end

    if spec.isReserved and spec.isReserved(normalized) then
        return nil, "CATALOG_NAME_RESERVED"
    end
    return normalized
end

--- Canonical form of a body for *comparison only*, never for storage.
---
--- An edit box returns every typed `|` doubled while code writes single pipes;
--- PE treats both as one OR token, so two bodies can be the same expression and
--- still differ byte for byte. Storage keeps whatever the producer wrote — the
--- doubling is what lets an edit box round-trip its own content.
---@param body string|nil
---@return string
function SearchCatalog:NormalizeBody(body)
    if type(body) ~= "string" then return "" end
    return strtrim((strgsub(body, "||", "|")))
end

--- An entry in any kind whose body is the same expression as `body`.
---
--- Kind-scoped namespaces make duplicate *bodies* the easy mistake rather than
--- name collisions — `#sell` and `SAVED(Sell)` can hold the same rule and drift
--- apart silently — so this deliberately searches across kinds.
---@param body string|nil
---@param exceptKind string|nil
---@param exceptId string|nil
---@return table|nil entry
---@return string|nil kind
function SearchCatalog:FindDuplicateBody(body, exceptKind, exceptId)
    local norm = self:NormalizeBody(body)
    if norm == "" then return nil end

    for _, kind in ipairs(KIND_ORDER) do
        for _, entry in ipairs(self:GetAll(kind)) do
            local same = kind == exceptKind and entry.id == exceptId
            if not same and self:NormalizeBody(entry.body) == norm then
                return entry, kind
            end
        end
    end
    return nil
end

-- ---- Mutation (native kinds only) ----

--- Create an entry, or update the body of an existing one with the same name.
---@param kind string
---@param name string|nil
---@param body string|nil
---@return table|nil entry
---@return string|nil errorKey
function SearchCatalog:Set(kind, name, body)
    local spec = KINDS[kind]
    if not spec.native then return nil, "CATALOG_KIND_EXTERNAL" end

    local normalized, err = ValidateName(kind, name)
    if not normalized then return nil, err end

    body = strtrim(body or "")
    if body == "" then return nil, "CATALOG_EMPTY_BODY" end

    local existing, status = self:Resolve(kind, normalized)
    if existing and status == "current" then
        existing.body = body
        FireChanged()
        return existing
    end

    if spec.isReserved and spec.isReserved(normalized) then
        return nil, "CATALOG_NAME_RESERVED"
    end

    local entries = GetStore().entries
    local id = NewId(entries)
    local entry = {
        id = id,
        kind = kind,
        name = normalized,
        body = body,
        created = time(),
    }
    entries[id] = entry
    ClaimName(kind, normalized)
    DropIndex(kind)
    FireChanged()
    return entry
end

--- Rename an entry. The old name is retained as a former name so expressions
--- that still reference it keep resolving; no stored text is rewritten.
---@param kind string
---@param id string
---@param newName string|nil
---@return boolean ok
---@return string|nil errorKey
function SearchCatalog:Rename(kind, id, newName)
    local spec = KINDS[kind]
    if not spec.native then return false, "CATALOG_KIND_EXTERNAL" end

    local entry = GetStore().entries[id]
    if not entry then return false, "CATALOG_NOT_FOUND" end

    local normalized, err = ValidateName(kind, newName)
    if not normalized then return false, err end

    -- A case-only change keeps the same identity, so it needs no former name.
    if NormKey(normalized) == NormKey(entry.name) then
        if normalized == entry.name then return true end
        entry.name = normalized
        DropIndex(kind)
        FireChanged()
        return true
    end

    if spec.isReserved and spec.isReserved(normalized) then
        return false, "CATALOG_NAME_RESERVED"
    end

    local clash, status = self:Resolve(kind, normalized)
    if clash and status == "current" and clash.id ~= id then
        return false, "CATALOG_DUPLICATE_NAME"
    end

    PushFormerName(entry, entry.name)
    entry.name = normalized
    ClaimName(kind, normalized)
    DropIndex(kind)
    FireChanged()
    return true
end

-- ---- Mutation (provider-owned kinds) ----

--- Enforce the former-name uniqueness invariant for a name an owner is about to
--- make live. Public because a provider-owned kind creates entries through its
--- own code path, and a new name that happens to be another entry's *former*
--- name would otherwise leave two entries answering to it.
---
--- `RenameExternal` already does this; call it directly only when creating.
---@param kind string
---@param name string
function SearchCatalog:ClaimName(kind, name)
    ClaimName(kind, name)
    DropIndex(kind)
    -- Claiming strips the name off whichever entry was holding it as a former
    -- name, so some other row's redirect list just got shorter. Callers batch
    -- this with the create that follows, which collapses both into one fire.
    FireChanged()
end

--- Rename a provider-owned entry. Keeps every rule about what a rename *means*
--- in one place: former-name bookkeeping, the per-entry cap, the uniqueness
--- invariant, and index invalidation. A provider that hand-rolled this would
--- get the easy half right and the invariant wrong.
---
--- Requires `SetName(id, name)` on the provider: entries are adapters, so
--- assigning `entry.name` would not reach the underlying record. `formerNames`
--- *is* mutated in place, so the provider must hand back a live table — that is
--- checked rather than assumed, because losing it silently discards the rename.
---@param kind string
---@param id string
---@param newName string|nil
---@return boolean ok
---@return string|nil errorKey
function SearchCatalog:RenameExternal(kind, id, newName)
    local spec = KINDS[kind]
    if spec.native then return false, "CATALOG_KIND_NATIVE" end

    local provider = providers[kind]
    if not provider or not provider.SetName then return false, "CATALOG_KIND_EXTERNAL" end

    local entry = provider.Get(id)
    if not entry then return false, "CATALOG_NOT_FOUND" end
    if type(entry.formerNames) ~= "table" then return false, "CATALOG_PROVIDER_CONTRACT" end

    local normalized, err = ValidateName(kind, newName)
    if not normalized then return false, err end

    -- A case-only change keeps the same identity, so it needs no former name.
    if NormKey(normalized) == NormKey(entry.name) then
        if normalized ~= entry.name then
            provider.SetName(id, normalized)
            DropIndex(kind)
            FireChanged()
        end
        return true
    end

    if spec.isReserved and spec.isReserved(normalized) then
        return false, "CATALOG_NAME_RESERVED"
    end

    local clash, status = self:Resolve(kind, normalized)
    if clash and status == "current" and clash.id ~= id then
        return false, "CATALOG_DUPLICATE_NAME"
    end

    PushFormerName(entry, entry.name)
    provider.SetName(id, normalized)
    ClaimName(kind, normalized)
    DropIndex(kind)
    FireChanged()
    return true
end

---@param kind string
---@param id string
---@return boolean ok
function SearchCatalog:Delete(kind, id)
    if not KINDS[kind].native then return false end
    local entries = GetStore().entries
    if not entries[id] then return false end
    entries[id] = nil
    DropIndex(kind)
    FireChanged()
    return true
end

-- ============================================================================
-- Reference index
-- ============================================================================
-- Former-name redirects make renaming safe. They do nothing for delete, or for
-- taking a name back off an entry that had retired it — both quietly change or
-- destroy what stored expressions mean. The only way to say what a write will
-- cost is to know who is referencing what, so every store that persists an
-- expression registers itself here and the catalog reads them back.
--
-- Read-only and pull-based on purpose: each owner keeps its own SavedVariables
-- (a load unit's SV is not even loaded until it is), and nothing here writes to
-- a source.

local expressionSources = {} ---@type table<string, table>

-- How a reference to each kind appears in stored expression text.
local KIND_REF_PATTERN = {
    token    = "#([%w_]+)",
    saved    = "SAVED%(([^%)]*)%)",
    category = "CATEGORY%(([^%)]*)%)",
}

-- Suite units that persist user-authored expressions. A unit that is installed
-- but not currently loaded has its SavedVariables unloaded, so its references
-- are invisible to the walk below — every answer this file gives is then a
-- lower bound, and says so rather than pretending to be complete.
local EXPRESSION_OWNING_ADDONS = {
    "OneWoW_Bags",
    "OneWoW_Mail",
    "OneWoW_QoL",
    "OneWoW_DirectDeposit",
}

--- Register a store that persists user-authored expressions.
---
--- `sourceLabel` names the owner and store for grouping ("Bags — Search
--- History"); `Enumerate` returns `{ expression, label }` per usage, where
--- `label` identifies the individual item inside that store (the category name,
--- the shipment name) so a report can point somewhere rather than count.
---
--- `class` says which timeline the usage lives in, and defaults to `live`:
---
---  * `live` — evaluated now. Breaking it breaks something the user can see.
---  * `restorable` — an alternate state the user can switch to, such as a saved
---    profile or the import undo snapshot. Nothing breaks today, but restoring
---    brings back text that would then resolve to nothing.
---
--- The split exists because counting the two together inflates a *safety*
--- number, and a warning that overstates gets dismissed. Pruning still has to see
--- both — a former name must outlive any snapshot depending on it — so the
--- reference report carries the two separately rather than filtering one out.
---@param id string
---@param source table { sourceLabel: string, Enumerate: fun(): table[], class: string|nil }
function SearchCatalog:RegisterExpressionSource(id, source)
    expressionSources[id] = source
end

---@param id string
function SearchCatalog:UnregisterExpressionSource(id)
    expressionSources[id] = nil
end

local lintSources = {} ---@type table<string, table>

--- Register a store that can report problems of its own to the lint.
---
--- Separate from `RegisterExpressionSource`, which answers "who references this
--- name". This answers "what else is wrong in here" — a Bags category whose
--- stored type names no longer resolve, say. The owner supplies finished text,
--- because *why* something is wrong is its knowledge, not the catalog's:
--- collapsing `UNKNOWN_TYPE` and `SUBTYPE_NOT_IN_TYPE` into one message would
--- send users to re-pick names that are already correct.
---@param id string
---@param source table { sourceLabel: string, Enumerate: fun(): table[] } each { label, note }
function SearchCatalog:RegisterLintSource(id, source)
    lintSources[id] = source
end

---@param id string
function SearchCatalog:UnregisterLintSource(id)
    lintSources[id] = nil
end

--- Findings contributed by registered lint sources, grouped by store.
---@return table[] groups { sourceLabel, findings[] }
function SearchCatalog:LintExtras()
    local groups = {}
    for _, source in pairs(lintSources) do
        local findings = source.Enumerate()
        if findings and #findings > 0 then
            tinsert(groups, { sourceLabel = source.sourceLabel, findings = findings })
        end
    end
    sort(groups, function(a, b) return (a.sourceLabel or "") < (b.sourceLabel or "") end)
    return groups
end

--- Suite units that own expressions, are installed, and are not loaded.
--- Non-empty means any reference count is incomplete.
---@return string[]
function SearchCatalog:GetUnscannableAddons()
    local out = {}
    for _, name in ipairs(EXPRESSION_OWNING_ADDONS) do
        if C_AddOns.GetAddOnInfo(name) and not C_AddOns.IsAddOnLoaded(name) then
            tinsert(out, name)
        end
    end
    return out
end

---@param kind string
---@param expression string|nil
---@param key string normalized name
---@return boolean
local function ExpressionReferences(kind, expression, key)
    local pattern = KIND_REF_PATTERN[kind]
    if not pattern or type(expression) ~= "string" then return false end
    for captured in strgmatch(expression, pattern) do
        if NormKey(captured) == key then return true end
    end
    return false
end

local function SortByLabel(a, b)
    return (a.sourceLabel or "") < (b.sourceLabel or "")
end

--- Every stored usage referencing any of `names` within a kind, grouped by the
--- store it lives in and split by whether that store is live.
---
--- Both halves are always returned rather than selected by an argument, so a
--- caller cannot ask for the wrong one: a confirmation headlines `total` and
--- mentions `restorableTotal` separately, while pruning adds them.
---@param kind string
---@param names string[]
---@return table report { total, groups[], restorableTotal, restorableGroups[], incomplete[] }
local function CollectReferences(kind, names)
    local keys = {}
    for _, name in ipairs(names) do
        local key = NormKey(name)
        if key ~= "" then keys[key] = name end
    end

    local groups, restorableGroups = {}, {}
    local total, restorableTotal = 0, 0

    for id, source in pairs(expressionSources) do
        local usages = {}
        for _, usage in ipairs(source.Enumerate()) do
            for key, name in pairs(keys) do
                if ExpressionReferences(kind, usage.expression, key) then
                    tinsert(usages, { label = usage.label, name = name })
                    break
                end
            end
        end
        if #usages > 0 then
            local group = { id = id, sourceLabel = source.sourceLabel, usages = usages }
            if source.class == "restorable" then
                tinsert(restorableGroups, group)
                restorableTotal = restorableTotal + #usages
            else
                tinsert(groups, group)
                total = total + #usages
            end
        end
    end

    sort(groups, SortByLabel)
    sort(restorableGroups, SortByLabel)
    return {
        total            = total,
        groups           = groups,
        restorableTotal  = restorableTotal,
        restorableGroups = restorableGroups,
        incomplete       = SearchCatalog:GetUnscannableAddons(),
    }
end

--- Find every stored reference to a name within a kind.
---
--- Takes a name rather than an id: expression text holds names, and a reclaim
--- check has to ask about a name that no longer belongs to the entry being
--- edited.
---@param kind string
---@param name string
---@return table report
function SearchCatalog:FindReferences(kind, name)
    return CollectReferences(kind, { name })
end

--- Live reference counts for every referenced name of a kind, in one pass.
---
--- `FindReferences` re-walks every source per call, which is right for a single
--- preflight and wrong for a list: rendering N entries that way is N times the
--- work for the same scan. This inverts it — walk once, count what is found —
--- so a list costs the same as a single lookup.
---
--- Live sources only. A count beside an entry answers "what breaks if this
--- goes", and a profile that would restore the reference alongside it does not
--- belong in that number.
---@param kind string
---@return table<string, number> counts keyed by normalized name
function SearchCatalog:CountReferencesByName(kind)
    local counts = {}
    local pattern = KIND_REF_PATTERN[kind]
    if not pattern then return counts end

    for _, source in pairs(expressionSources) do
        if source.class ~= "restorable" then
            for _, usage in ipairs(source.Enumerate()) do
                if type(usage.expression) == "string" then
                    for captured in strgmatch(usage.expression, pattern) do
                        local key = NormKey(captured)
                        if key ~= "" then counts[key] = (counts[key] or 0) + 1 end
                    end
                end
            end
        end
    end
    return counts
end

-- ---- Preflight ----
--
-- The catalog never prompts. Each mutator has a matching preflight that returns
-- a structured account of what the write would cost, or nil when it costs
-- nothing, and the mutators stay unconditional so a caller that means it can
-- still force through.

local function Loss(name, reason, refs)
    return { name = name, reason = reason, references = refs }
end

--- A report, or nil when the write costs nothing at all.
---
--- A usage found only in a profile or an undo snapshot still counts as a cost:
--- nothing breaks today, but the text comes back broken when that state is
--- restored. It is reported separately from the live count, not dropped.
local function Report(action, kind, losses)
    local total, restorableTotal = 0, 0
    for _, loss in ipairs(losses) do
        total = total + loss.references.total
        restorableTotal = restorableTotal + loss.references.restorableTotal
    end
    if total == 0 and restorableTotal == 0 then return nil end
    return {
        action = action,
        kind = kind,
        losses = losses,
        total = total,
        restorableTotal = restorableTotal,
        incomplete = SearchCatalog:GetUnscannableAddons(),
    }
end

--- What breaks if this entry is deleted: its current name and every former name
--- it still answers to.
---@param kind string
---@param id string
---@return table|nil report
function SearchCatalog:PreflightDelete(kind, id)
    local entry = GetEntryById(kind, id)
    if not entry then return nil end

    local losses = { Loss(entry.name, "deleted", self:FindReferences(kind, entry.name)) }
    for _, former in ipairs(entry.formerNames or {}) do
        tinsert(losses, Loss(former, "deleted", self:FindReferences(kind, former)))
    end
    return Report("delete", kind, losses)
end

--- What breaks if `name` becomes live under this kind.
---
--- Reclaiming a name that is another entry's former name is accepted by Set and
--- Rename, and strips it from that entry — every stale reference silently means
--- something else afterwards. Worse, deleting the *new* holder later does not
--- give the name back, so those references degrade to matching nothing. This is
--- the last way the no-rewrite promise can still change behavior.
---@param kind string
---@param name string|nil
---@param exceptId string|nil entry being renamed, which cannot clash with itself
---@return table|nil report
function SearchCatalog:PreflightClaim(kind, name, exceptId)
    if type(name) ~= "string" then return nil end
    local entry, status = self:Resolve(kind, name)
    if not entry or status ~= "former" or entry.id == exceptId then return nil end
    return Report("claim", kind, { Loss(name, "reclaimed", self:FindReferences(kind, name)) })
end

--- What breaks if this entry is renamed.
---
--- The rename itself is safe — the old name is retained. The hazards are the
--- new name being someone else's former name, and the per-entry cap evicting
--- the oldest former name to make room, which is silent data loss if anything
--- still references it.
---@param kind string
---@param id string
---@param newName string|nil
---@return table|nil report
function SearchCatalog:PreflightRename(kind, id, newName)
    local entry = GetEntryById(kind, id)
    if not entry then return nil end

    local normalized = ValidateName(kind, newName)
    if not normalized or NormKey(normalized) == NormKey(entry.name) then return nil end

    local losses = {}

    local clash, status = self:Resolve(kind, normalized)
    if clash and status == "former" and clash.id ~= id then
        tinsert(losses, Loss(normalized, "reclaimed", self:FindReferences(kind, normalized)))
    end

    local formers = entry.formerNames
    if formers and #formers >= MAX_FORMER_NAMES then
        local evicted = formers[1]
        tinsert(losses, Loss(evicted, "capped", self:FindReferences(kind, evicted)))
    end

    return Report("rename", kind, losses)
end

-- ---- Former-name pruning ----

--- True when any registered source still references this name for this kind.
local function AnyReference(kind, name)
    local key = NormKey(name)
    if key == "" then return false end
    for _, source in pairs(expressionSources) do
        for _, usage in ipairs(source.Enumerate()) do
            if ExpressionReferences(kind, usage.expression, key) then return true end
        end
    end
    return false
end

--- Drop former names nothing references any more.
---
--- A former name exists only to keep stale text resolving, so once nothing
--- points at it, it is dead weight taking up a capped slot. Refuses to run when
--- a suite unit that owns expressions is installed but not loaded: its
--- references are invisible, and pruning against a partial view would delete
--- exactly the redirects that unit still needs.
---
--- This is the one operation here that destroys data rather than warning about
--- it, and a source that under-reports makes it silent. Hence `dryRun`, and
--- hence no automatic invocation — it is driven manually from `/owsc`
--- until the lint UI can show what it would remove.
---@param opts table|nil { force: boolean, dryRun: boolean } force skips the not-loaded gate
---@return number|nil pruned count, or would-be count under dryRun; nil when gated
---@return string[]|nil blockedBy
---@return table[] dropped { kind, name, owner }
function SearchCatalog:PruneFormerNames(opts)
    opts = opts or {}

    local blocked = self:GetUnscannableAddons()
    if #blocked > 0 and not opts.force then
        return nil, blocked, {}
    end

    local dropped = {}
    local touched = {}

    self:WithBatch(function()
        for kind in pairs(KINDS) do
            EachEntry(kind, function(entry)
                local formers = entry.formerNames
                if not formers then return end
                for i = #formers, 1, -1 do
                    local former = formers[i]
                    if not AnyReference(kind, former) then
                        tinsert(dropped, { kind = kind, name = former, owner = entry.name })
                        if not opts.dryRun then
                            tremove(formers, i)
                            touched[kind] = true
                        end
                    end
                end
            end)
        end
        for kind in pairs(touched) do
            DropIndex(kind)
        end
        -- Former names are user-visible — a list showing "also answers to X"
        -- goes stale the moment X is pruned. Inside the batch, so a prune that
        -- touches every kind still notifies once.
        if next(touched) then FireChanged() end
    end)

    return #dropped, nil, dropped
end

-- ---- Lint ----

--- Classify every reference in every registered source.
---
--- `former` is not an error — it still resolves — but it is the set that a
--- prune or a reclaim would break, so it is worth showing.
---@return table[] findings { kind, name, status, sourceLabel, label }
---@return string[] incomplete
function SearchCatalog:Lint()
    local findings = {}

    for _, source in pairs(expressionSources) do
        for _, usage in ipairs(source.Enumerate()) do
            local expression = usage.expression
            if type(expression) == "string" and expression ~= "" then
                for kind, pattern in pairs(KIND_REF_PATTERN) do
                    local spec = KINDS[kind]
                    for captured in strgmatch(expression, pattern) do
                        local name = strtrim(captured)
                        -- A #token that is a built-in keyword is not a catalog
                        -- reference at all, and neither is a reserved sentinel.
                        local reserved = spec.isReserved and spec.isReserved(name)
                        if name ~= "" and not reserved then
                            local _, status = self:GetBody(kind, name)
                            if status ~= "current" then
                                tinsert(findings, {
                                    kind = kind,
                                    name = name,
                                    status = status,
                                    sourceLabel = source.sourceLabel,
                                    label = usage.label,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    sort(findings, function(a, b)
        if a.status ~= b.status then return a.status < b.status end
        return NormKey(a.name) < NormKey(b.name)
    end)
    return findings, self:GetUnscannableAddons()
end

-- ============================================================================
-- Export / import payload
-- ============================================================================
-- Core owns this format and other units embed it as an opaque sub-blob. If a
-- consumer learned the entry shape, a later core-side export — sharing a single
-- #token without a whole category bundle — would grow a second, drifting
-- format. So Bags asks for a payload and hands one back; it never reads inside.

local PAYLOAD_VERSION = 1

--- Resolve every reference in a body to its owner's *current* name.
---
--- The no-rewrite promise covers stored text, not artifacts: an export is a new
--- document, and the importer has no idea what our former names were. Doing this
--- on the way out keeps `formerNames` out of the payload entirely.
---@param body string|nil
---@return string|nil
local function CanonicalizeBody(body)
    if type(body) ~= "string" then return body end

    local out = strgsub(body, "#([%w_]+)", function(name)
        local entry = SearchCatalog:Resolve("token", name)
        return "#" .. (entry and entry.name or name)
    end)
    out = strgsub(out, "SAVED%(([^%)]*)%)", function(name)
        local trimmed = strtrim(name)
        local entry = SearchCatalog:Resolve("saved", trimmed)
        return "SAVED(" .. (entry and entry.name or trimmed) .. ")"
    end)
    out = strgsub(out, "CATEGORY%(([^%)]*)%)", function(name)
        local trimmed = strtrim(name)
        local entry = SearchCatalog:Resolve("category", trimmed)
        return "CATEGORY(" .. (entry and entry.name or trimmed) .. ")"
    end)
    return out
end

--- Build the catalog payload for a set of seed expressions.
---
--- Walks the transitive closure across all three kinds, not just SAVED: a
--- category rule can say `#sell`, and that token's body can say
--- `CATEGORY(Junk)`, so stopping at one kind ships a bundle that resolves to
--- nothing on the far side.
---
--- Category entries are *not* in the payload — the unit that owns them exports
--- them itself — but their names come back so the caller can check them against
--- its own selection and warn about the ones it is not shipping.
---@param seeds string[] expressions to start from
---@return table payload
---@return string[] referencedCategories current names, deduplicated
function SearchCatalog:BuildExportPayload(seeds)
    local entries = {}
    local categories = {}
    local seen = {}
    local queue = {}

    local function Enqueue(text)
        if type(text) ~= "string" then return end
        for kind, pattern in pairs(KIND_REF_PATTERN) do
            local spec = KINDS[kind]
            for captured in strgmatch(text, pattern) do
                local name = strtrim(captured)
                if name ~= "" and not (spec.isReserved and spec.isReserved(name)) then
                    local entry = self:Resolve(kind, name)
                    if entry then
                        local key = kind .. "\0" .. NormKey(entry.name)
                        if not seen[key] then
                            seen[key] = true
                            if spec.native then
                                tinsert(queue, entry)
                            else
                                tinsert(categories, entry.name)
                            end
                        end
                    end
                end
            end
        end
    end

    for _, seed in ipairs(seeds or {}) do
        Enqueue(seed)
    end

    local idx = 1
    while idx <= #queue do
        local entry = queue[idx]
        idx = idx + 1
        tinsert(entries, {
            kind = entry.kind,
            name = entry.name,
            body = CanonicalizeBody(entry.body),
        })
        Enqueue(entry.body)
    end

    -- Stable ordering so re-exporting an unchanged setup produces an identical
    -- string, which makes diffing and dedup on the receiving end meaningful.
    sort(entries, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return NormKey(a.name) < NormKey(b.name)
    end)
    sort(categories, function(a, b) return NormKey(a) < NormKey(b) end)

    return { version = PAYLOAD_VERSION, entries = entries }, categories
end

--- A free name near `name`, for importing alongside a conflicting local entry.
local function SuggestImportName(kind, name)
    -- Token names cannot contain spaces or parentheses, so they get a suffix
    -- the grammar actually accepts.
    local template = (kind == "token") and "%s_imported%s" or "%s (imported)%s"
    local candidate = format(template, name, "")
    local n = 2
    while SearchCatalog:Resolve(kind, candidate) do
        candidate = format(template, name, tostring(n))
        n = n + 1
    end
    return candidate
end

--- Turn an incoming payload into a plan the caller can present and edit.
---
--- Never a boolean, and never applied directly: the caller owns the UI, and a
--- conflict is a decision rather than an error. Foreign ids are ignored outright
--- — ids are ours, and trusting theirs would collide two unrelated catalogs.
---
--- Actions: `create` (no local entry), `merge` (identical body — the same thing,
--- so no prompt), `conflict` (same name, different body).
---@param payload table|nil
---@return table[] plan
function SearchCatalog:PlanImport(payload)
    local plan = {}
    if type(payload) ~= "table" then return plan end

    for _, incoming in ipairs(payload.entries or {}) do
        local spec = KINDS[incoming.kind or ""]
        if spec and spec.native and type(incoming.name) == "string"
            and type(incoming.body) == "string" and incoming.body ~= "" then

            local existing, status = self:Resolve(incoming.kind, incoming.name)
            local item = {
                kind = incoming.kind,
                name = incoming.name,
                body = incoming.body,
            }

            if not existing or status ~= "current" then
                item.action = "create"
                -- Importing under a name some entry retired takes it back, and
                -- every stale reference to it silently changes meaning. Flagged
                -- so the caller can say so rather than discovering it later.
                if existing and status == "former" then
                    item.reclaims = existing.name
                end
            elseif strtrim(existing.body or "") == strtrim(incoming.body) then
                item.action = "merge"
            else
                item.action = "conflict"
                item.existingBody = existing.body
                item.suggestedName = SuggestImportName(incoming.kind, incoming.name)
                item.options = { "import_as_new", "keep_mine" }
            end

            tinsert(plan, item)
        end
    end
    return plan
end

--- Apply a plan produced by PlanImport, after the caller has resolved conflicts.
---
--- Each item's `action` is honoured as given; `conflict` items must have been
--- turned into `import_as_new` (optionally with a chosen `newName`) or
--- `keep_mine` first. Returns what was created so a rollback can reach it —
--- without that record, an undo restores the importing unit's own tables and
--- leaves catalog entries behind as orphans.
---@param plan table[]
---@return table[] created { kind, id }
function SearchCatalog:ApplyImportPlan(plan)
    local created = {}

    self:WithBatch(function()
        for _, item in ipairs(plan or {}) do
            local action = item.action
            local name, body

            if action == "create" then
                name, body = item.name, item.body
            elseif action == "import_as_new" then
                name, body = item.newName or item.suggestedName, item.body
            end

            if name then
                local entry = self:Set(item.kind, name, body)
                if entry then
                    tinsert(created, { kind = item.kind, id = entry.id })
                end
            end
        end
    end)

    return created
end

--- Undo the catalog half of an import.
---@param created table[] as returned by ApplyImportPlan
function SearchCatalog:RollbackImportedEntries(created)
    self:WithBatch(function()
        for _, rec in ipairs(created or {}) do
            self:Delete(rec.kind, rec.id)
        end
    end)
end

-- ---- The catalog's own bodies are an expression source ----
--
-- Entries reference each other: a SAVED body can contain #token, a token body
-- can contain SAVED(...) or CATEGORY(...). Those are stored expressions like any
-- other and have to be in the reference index, or prune drops a former name
-- that only another entry was relying on — silently, because nothing else
-- looks at these bodies.
--
-- Native kinds only. Provider-backed kinds are registered by their owner (Bags
-- registers its categories), and enumerating them here would double-count.

local NATIVE_KIND_LABEL = {
    token = "OneWoW — Keyword Synonyms",
    saved = "OneWoW — Named Expressions",
}

local NATIVE_KIND_DISPLAY = {
    token = function(name) return "#" .. name end,
    saved = function(name) return "SAVED(" .. name .. ")" end,
}

for kind, sourceLabel in pairs(NATIVE_KIND_LABEL) do
    local display = NATIVE_KIND_DISPLAY[kind]
    SearchCatalog:RegisterExpressionSource("catalog_" .. kind, {
        sourceLabel = sourceLabel,
        Enumerate = function()
            local out = {}
            EachEntry(kind, function(entry)
                if type(entry.body) == "string" and entry.body ~= "" then
                    tinsert(out, { expression = entry.body, label = display(entry.name) })
                end
            end)
            return out
        end,
    })
end

-- ---- Migration ----

--- Lift the pre-catalog `searchShortcuts` store into catalog entries. Aliases
--- become token entries whose body is the `#keyword` they pointed at, which is
--- why token bodies are ordinary expressions rather than a target field.
function SearchCatalog:MigrateFromSearchShortcuts()
    local g = ns.db.global
    local store = g.searchCatalog
    if store.schemaVersion >= SCHEMA_VERSION then return end

    local legacy = g.searchShortcuts
    if type(legacy) == "table" then
        for alias, target in pairs(legacy.aliases or {}) do
            if type(alias) == "string" and type(target) == "string" and target ~= "" then
                self:Set("token", alias, "#" .. target)
            end
        end
        for name, query in pairs(legacy.saved or {}) do
            if type(name) == "string" and type(query) == "string" then
                self:Set("saved", name, query)
            end
        end
        g.searchShortcuts = nil
    end

    store.schemaVersion = SCHEMA_VERSION
end

-- ---- Maintenance command ----
--
-- Dev/maintenance chat tool, hardcoded English, following the /1wtrace and
-- /owblayout precedent — deliberately not localized and not a settings surface.
-- The reporting this exposes gets a real UI in the catalog tab; until then this
-- is the only way to see the reference index, and the only way to prune, which
-- is not run automatically because it deletes redirects rather than warning
-- about them.

local CMD_PREFIX = "|cFF33FF99OneWoW Search Catalog|r"

local STATUS_NOTE = {
    missing = "no such entry (typo, or deleted)",
    former  = "resolves via a former name",
    empty   = "entry exists but has no rule",
}

local function PrintLint()
    local findings, incomplete = SearchCatalog:Lint()
    if #findings == 0 then
        print(CMD_PREFIX .. ": no broken or stale references found.")
    else
        print(CMD_PREFIX .. ": " .. #findings .. " reference(s) worth a look:")
        for _, f in ipairs(findings) do
            print(format("  [%s] %s(%s) — %s  |cFF888888(%s: %s)|r",
                f.status, f.kind, f.name, STATUS_NOTE[f.status] or f.status,
                f.sourceLabel or "?", f.label or "?"))
        end
    end
    if #incomplete > 0 then
        print(CMD_PREFIX .. ": |cFFFFAA00" .. #incomplete
            .. " addon(s) not loaded, so this is incomplete:|r " .. tconcat(incomplete, ", "))
    end
end

--- List every registered source and what it currently yields. The reference
--- index is only ever as good as its sources, and a source that is missing, or
--- present but returning nothing, looks exactly like "no references found" from
--- the outside. This is how to tell those apart.
local function PrintSources()
    local rows = {}
    local total = 0
    for id, source in pairs(expressionSources) do
        local ok, usages = pcall(source.Enumerate)
        local count = ok and #usages or -1
        if count > 0 then total = total + count end
        tinsert(rows, { id = id, label = source.sourceLabel or "?", count = count })
    end
    sort(rows, function(a, b) return a.id < b.id end)

    print(format("%s: %d source(s), %d expression(s) visible:", CMD_PREFIX, #rows, total))
    for _, row in ipairs(rows) do
        if row.count < 0 then
            print(format("  |cFFFF5555%s|r — %s |cFFFF5555(Enumerate errored)|r", row.id, row.label))
        else
            print(format("  %s — %s |cFF888888(%d)|r", row.id, row.label, row.count))
        end
    end

    local incomplete = SearchCatalog:GetUnscannableAddons()
    if #incomplete > 0 then
        print(CMD_PREFIX .. ": |cFFFFAA00not loaded, so their sources are absent:|r "
            .. tconcat(incomplete, ", "))
    end
end

local function PrintPrune(apply, force)
    local count, blocked, dropped = SearchCatalog:PruneFormerNames({
        dryRun = not apply,
        force = force,
    })

    if not count then
        print(CMD_PREFIX .. ": |cFFFF5555prune skipped|r — these own expressions but are not loaded: "
            .. tconcat(blocked or {}, ", "))
        print(CMD_PREFIX .. ": load them, or use |cFFFFFFFF/1wsc prune apply force|r to prune anyway.")
        return
    end

    if count == 0 then
        print(CMD_PREFIX .. ": nothing to prune; every former name is still referenced.")
        return
    end

    print(format("%s: %d former name(s) %s:", CMD_PREFIX, count,
        apply and "pruned" or "would be pruned"))
    for _, d in ipairs(dropped) do
        print(format("  %s(%s) |cFF888888— former name of '%s'|r", d.kind, d.name, d.owner or "?"))
    end
    if not apply then
        print(CMD_PREFIX .. ": run |cFFFFFFFF/1wsc prune apply|r to remove them.")
    end
end

-- Named for the *search* catalog, not the OneWoW_Catalog addon, which owns the
-- word "catalog" for users and will want the obvious command. The globals matter
-- as much as the visible name: DB:RegisterSlashCommand builds
-- SLASH_ONEWOW_<UPPER>1, so registering that addon as "catalog" would produce
-- SLASH_ONEWOW_CATALOG1 and SlashCmdList["ONEWOW_CATALOG"] — exactly what this
-- used to define, and one would have silently won.
SLASH_ONEWOW_SEARCHCATALOG1 = "/1wsc"
SlashCmdList["ONEWOW_SEARCHCATALOG"] = function(msg)
    msg = strlower(strtrim(msg or ""))

    if msg == "lint" then
        PrintLint()
    elseif msg == "sources" then
        PrintSources()
    elseif msg == "prune" then
        PrintPrune(false, false)
    elseif msg == "prune apply" then
        PrintPrune(true, false)
    elseif msg == "prune apply force" then
        PrintPrune(true, true)
    else
        print(CMD_PREFIX .. ": usage:")
        print("  |cFFFFFFFF/1wsc lint|r — list broken, stale, and rule-less references")
        print("  |cFFFFFFFF/1wsc sources|r — list registered stores and how many expressions each sees")
        print("  |cFFFFFFFF/1wsc prune|r — show which former names are no longer referenced")
        print("  |cFFFFFFFF/1wsc prune apply|r — actually remove them")
        print("  |cFFFFFFFF/1wsc prune apply force|r — ignore the not-loaded-addon safety gate")
    end
end

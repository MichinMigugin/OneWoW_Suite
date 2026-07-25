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
local strtrim = strtrim
local format = string.format
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

local function InvalidateKind(kind)
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
---@param kind string
---@param provider table
function SearchCatalog:RegisterProvider(kind, provider)
    providers[kind] = provider
    InvalidateKind(kind)
end

---@param kind string
function SearchCatalog:UnregisterProvider(kind)
    providers[kind] = nil
    InvalidateKind(kind)
end

--- Drop the cached name index for a kind. Providers must call this when their
--- underlying data changes, or lookups will resolve against stale names.
---@param kind string
function SearchCatalog:InvalidateKind(kind)
    InvalidateKind(kind)
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
    InvalidateKind(kind)
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
        InvalidateKind(kind)
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
    InvalidateKind(kind)
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
    InvalidateKind(kind)
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
            InvalidateKind(kind)
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
    InvalidateKind(kind)
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
    InvalidateKind(kind)
    FireChanged()
    return true
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

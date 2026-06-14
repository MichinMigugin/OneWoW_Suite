local _, OneWoW = ...

-- OneWoW Locale service (Phase 0 — see Docs/LOCALE_MIGRATION.md).
--
-- One service owns localization for the whole suite. Core fills the shared and
-- "OneWoW" scopes; every other addon registers its own scope and reads back a
-- stable, read-only view modeled on OneWoW_GUI ApplyTheme / Constants.ACTIVE_THEME
-- (a metatable __index fallback chain with __newindex = noop).
--
-- Contract:
--   * A key is EITHER shared (identical everywhere) OR scoped (per-addon), never
--     both. shared and scope keysets are disjoint; /owlocale reports violations.
--   * Views are identity-stable: GetTable(scope) hands back the SAME table for the
--     life of the session. SetLanguage mutates the underlying resolved tables IN
--     PLACE so cached `local L = OneWoW.Locale:GetTable(scope)` never goes stale.
--   * A missing key resolves to its own name (never nil).

local Locale = {}
OneWoW.Locale = Locale

local DEFAULT_LOCALE = "enUS"
local SHARED_SCOPE   = "shared"

local noop = OneWoW_GUI.noop
local tinsert, sort, tconcat = tinsert, sort, table.concat
local wipe = wipe
local format = format

-- store[scope][locale]  = { KEY = value }   raw registered entries
-- resolved[scope]       = { KEY = value }   folded (enUS <- activeLang), mutated in place
-- _views[scope]         = metatable view    identity-stable, read-only
Locale.store      = {}
Locale.resolved   = {}
Locale._views     = {}
Locale._callbacks = {}
Locale._activeLang = DEFAULT_LOCALE

local function NormalizeLocale(locale)
    if locale == "esMX" then return "esES" end
    return locale
end

-- Fold DEFAULT_LOCALE then the active language into resolved[scope], in place, and
-- push any BINDING_* keys to _G so keybinding labels stay current on every refold.
function Locale:_resolveScope(scope)
    local resolved = self.resolved[scope]
    if not resolved then
        resolved = {}
        self.resolved[scope] = resolved
    end
    wipe(resolved)

    local store = self.store[scope]
    if store then
        local base = store[DEFAULT_LOCALE]
        if base then
            for k, v in pairs(base) do resolved[k] = v end
        end
        local lang = self._activeLang
        if lang and lang ~= DEFAULT_LOCALE and store[lang] then
            for k, v in pairs(store[lang]) do resolved[k] = v end
        end
    end

    for k, v in pairs(resolved) do
        if type(k) == "string" and k:find("^BINDING_") then
            _G[k] = v
        end
    end
end

-- Register a table of KEY=value into store[scope][locale]. Safe at file-load.
-- Folds the scope immediately so reads work without waiting for SetLanguage.
function Locale:Register(scope, locale, entries)
    assert(type(scope) == "string", "Locale:Register - scope must be a string")
    assert(type(locale) == "string", "Locale:Register - locale must be a string")
    assert(type(entries) == "table", "Locale:Register - entries must be a table")
    locale = NormalizeLocale(locale)

    local s = self.store[scope]
    if not s then
        s = {}
        self.store[scope] = s
    end

    local l = s[locale]
    if not l then
        l = {}
        s[locale] = l
    end

    for k, v in pairs(entries) do
        l[k] = v
    end

    self:_resolveScope(scope)
    return self
end

-- Sugar for the shared scope (THEME_*, language names, MINIMAP_* labels, buttons).
function Locale:RegisterShared(locale, entries)
    return self:Register(SHARED_SCOPE, locale, entries)
end

-- Identity-stable, read-only view for a scope. Cache it once at file scope.
-- Resolution order: scope -> shared -> key name.
function Locale:GetTable(scope)
    local view = self._views[scope]
    if view then return view end

    local resolved = self.resolved
    view = setmetatable({}, {
        __index = function(_, key)
            local sc = resolved[scope]
            if sc then
                local v = sc[key]
                if v ~= nil then return v end
            end
            local sh = resolved[SHARED_SCOPE]
            if sh then
                local v = sh[key]
                if v ~= nil then return v end
            end
            return key -- self-documenting miss, never nil
        end,
        __newindex = noop, -- read-only
    })
    self._views[scope] = view
    return view
end

-- Set the active language, refold every scope in place, fire OnApply listeners.
function Locale:SetLanguage(lang)
    self._activeLang = NormalizeLocale(lang) or DEFAULT_LOCALE
    for scope in pairs(self.store) do
        self:_resolveScope(scope)
    end
    for _, fn in ipairs(self._callbacks) do
        local ok, err = pcall(fn, self._activeLang)
        if not ok then geterrorhandler()(err) end
    end
    return self
end

function Locale:GetLanguage()
    return self._activeLang
end

-- Register a listener fired after each SetLanguage (rebuild cached UI strings).
-- Replaces the per-addon ApplyLanguage hook.
function Locale:OnApply(fn)
    assert(type(fn) == "function", "Locale:OnApply - fn must be a function")
    tinsert(self._callbacks, fn)
    return self
end

-- Collision audit: any key present in BOTH the shared scope and a non-shared scope
-- is a contract violation (it should have been one or the other, not both). Checks
-- the full key set across all registered locales, so a collision in an inactive
-- language is still caught. Returns an array of { scope = , key = }.
function Locale:Audit()
    local sharedKeys = {}
    local sharedStore = self.store[SHARED_SCOPE]
    if sharedStore then
        for _, tbl in pairs(sharedStore) do
            for k in pairs(tbl) do
                sharedKeys[k] = true
            end
        end
    end

    local collisions = {}
    for scope, locales in pairs(self.store) do
        if scope ~= SHARED_SCOPE then
            local seen = {}
            for _, tbl in pairs(locales) do
                for k in pairs(tbl) do
                    if sharedKeys[k] and not seen[k] then
                        seen[k] = true
                        tinsert(collisions, { scope = scope, key = k })
                    end
                end
            end
        end
    end

    return collisions
end

-- /owlocale — sole locale-debug command (no debug builds). On-demand only:
-- never auto-prints, never throws. Mirrors /owbperf, /owblayout, /owtrace.
local function Hex(text, hex)
    return "|cff" .. hex .. text .. "|r"
end

function Locale:PrintReport()
    print(Hex("OneWoW Locale", "ffd100") .. " — active language: " .. tostring(self._activeLang or "(none)"))

    local scopes = {}
    for scope in pairs(self.store) do
        tinsert(scopes, scope)
    end
    sort(scopes)

    for _, scope in ipairs(scopes) do
        local locales = self.store[scope]
        local locNames, count = {}, 0
        for loc in pairs(locales) do
            tinsert(locNames, loc)
        end
        sort(locNames)

        local base = locales[DEFAULT_LOCALE]
        if base then
            for _ in pairs(base) do
                count = count + 1
            end
        end

        local tag = (scope == SHARED_SCOPE) and Hex(scope, "66ccff") or scope
        print(format("  %s: %d keys [%s]", tag, count, tconcat(locNames, ", ")))
    end

    local collisions = self:Audit()
    if #collisions == 0 then
        print("  " .. Hex("No shared/scope collisions.", "00ff00"))
    else
        print("  " .. Hex(#collisions .. " shared/scope collision(s):", "ff4040"))
        for _, c in ipairs(collisions) do
            print(string.format("    %s defines shared key %s", c.scope, Hex(c.key, "ffd100")))
        end
    end
end

SLASH_OWLOCALE1 = "/owlocale"
SlashCmdList["OWLOCALE"] = function()
    Locale:PrintReport()
end

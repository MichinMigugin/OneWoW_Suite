local _, ns = ...

-- OneWoW Locale service. Contract documented in Docs/ARCHITECTURE.md
-- (§6 "Localization (ns.Locale)").
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
--     PLACE so cached `local L = ns.Locale:GetTable(scope)` never goes stale.
--   * A missing key resolves to its own name (never nil).

---@class ns.Locale
local Locale = {}
ns.Locale = Locale

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

-- Supported locales (ordered) — the single source for the language picker and for
-- normalization. `native` is each language in its own script (the picker shows the
-- native name regardless of the active UI language).
Locale.SUPPORTED = {
    { code = "enUS", native = "English"      },
    { code = "koKR", native = "한국어"        },
    { code = "frFR", native = "Français"     },
    { code = "deDE", native = "Deutsch"      },
    { code = "zhCN", native = "简体中文"      },
    { code = "esES", native = "Español (EU)" },
    { code = "zhTW", native = "繁體中文"      },
    { code = "esMX", native = "Español (AL)" },
    { code = "ruRU", native = "Русский"      },
    { code = "ptBR", native = "Português"    },
    { code = "itIT", native = "Italiano"     },
}

-- Client-locale aliases resolved by NormalizeLocale (WoW client locale -> our locale).
-- enGB is a real GetLocale() value (British English) that shares enUS strings; all
-- other Blizzard client locales now map 1:1 to a SUPPORTED entry (esMX is its own).
Locale.ALIASES = { enGB = "enUS" }

local KNOWN_LOCALE = {}
for _, e in ipairs(Locale.SUPPORTED) do KNOWN_LOCALE[e.code] = true end

local function NormalizeLocale(locale)
    return Locale.ALIASES[locale] or locale
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

--- Register a table of KEY=value into store[scope][locale]. Safe at file-load.
--- Folds the scope immediately so reads work without waiting for SetLanguage.
---@param scope string registration scope (ADDON_NAME, or "shared" via RegisterShared)
---@param locale string WoW locale code (enUS, koKR, …); esMX is its own locale (only enGB aliases to enUS)
---@param entries table { KEY = value } pairs merged into the scope/locale store
---@return ns.Locale self for chaining
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

--- Sugar for the shared scope (THEME_*, language names, MINIMAP_* labels, buttons).
---@param locale string WoW locale code
---@param entries table { KEY = value } pairs merged into the shared scope
---@return ns.Locale self for chaining
function Locale:RegisterShared(locale, entries)
    return self:Register(SHARED_SCOPE, locale, entries)
end

--- Identity-stable, read-only view for a scope. Cache it once at file scope; it
--- survives SetLanguage (the underlying resolved table mutates in place, the view
--- table is never replaced). Resolution order: scope -> shared -> key name, so a
--- miss returns the key string itself (never nil) to surface missing-key bugs.
---@param scope string
---@return table view read-only (__newindex is a noop); index it as `L.KEY`
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

--- Set the active language, refold every scope in place, fire OnApply listeners.
--- Cached GetTable views stay valid (resolved tables mutate, not replaced).
---@param lang string locale code; nil/unknown falls back to enUS
---@return ns.Locale self for chaining
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

--- The active language code (defaults to enUS until SetLanguage runs).
---@return string activeLang
function Locale:GetLanguage()
    return self._activeLang
end

--- Raw registered store for a scope: { [locale] = { KEY = value } }. For the rare
--- consumer that needs a SPECIFIC locale's raw strings (e.g. import/export
--- cross-locale maps, a DB-migration default in a fixed locale) rather than the
--- folded active-language view. Read-only by convention.
---@param scope string
---@return table<string, table<string, any>>|nil store nil if the scope was never registered
function Locale:GetStore(scope)
    return self.store[scope]
end

--- Optional lookup: the resolved value for `key` (scope, then shared) if it was
--- registered, else nil. Unlike the view `L[key]` -- which returns the key name on a
--- miss to surface missing-key bugs -- this is for GENUINELY OPTIONAL localization:
--- "use a translation if one exists, otherwise a dynamic fallback" (e.g. localize a
--- built-in category name, else show the user's raw SavedVariables name). Do NOT use
--- it to paper over keys that should always exist -- use the view for those so the
--- miss is visible.
---@param scope string
---@param key string
---@return any|nil value the registered value, or nil if absent in both scope and shared
function Locale:GetOptional(scope, key)
    local r = self.resolved
    if r[scope] and r[scope][key] ~= nil then return r[scope][key] end
    if r[SHARED_SCOPE] and r[SHARED_SCOPE][key] ~= nil then return r[SHARED_SCOPE][key] end
    return nil
end

--- Register a listener fired after each SetLanguage (rebuild cached UI strings).
--- Replaces the per-addon ApplyLanguage hook. Listeners run under pcall, so a
--- throwing listener routes to geterrorhandler() without blocking the others.
---@param fn fun(activeLang: string)
---@return ns.Locale self for chaining
function Locale:OnApply(fn)
    assert(type(fn) == "function", "Locale:OnApply - fn must be a function")
    tinsert(self._callbacks, fn)
    return self
end

--- Collision audit: any key present in BOTH the shared scope and a non-shared scope
--- is a contract violation (it should have been one or the other, not both). Checks
--- the full key set across all registered locales, so a collision in an inactive
--- language is still caught.
---@return { scope: string, key: string }[] collisions one entry per offending scope/key
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

--- Print the locale report to chat: active language, supported codes, per-scope key
--- counts + registered locales, shared/scope collisions, and any unknown locales.
--- Backs /owlocale; on-demand only (never auto-prints, never throws).
---@return nil
function Locale:PrintReport()
    print(Hex("OneWoW Locale", "ffd100") .. " — active language: " .. tostring(self._activeLang or "(none)"))

    local codes = {}
    for _, e in ipairs(self.SUPPORTED) do tinsert(codes, e.code) end
    print("  supported: " .. tconcat(codes, ", "))

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

    -- registered locales not in SUPPORTED (typo'd locale file, or unsupported code)
    local unknown = {}
    for _, locales in pairs(self.store) do
        for loc in pairs(locales) do
            if not KNOWN_LOCALE[loc] then unknown[loc] = true end
        end
    end
    local unknownList = {}
    for loc in pairs(unknown) do tinsert(unknownList, loc) end
    if #unknownList > 0 then
        sort(unknownList)
        print("  " .. Hex("Unknown locales (not in SUPPORTED): ", "ffaa00") .. tconcat(unknownList, ", "))
    end
end

SLASH_OWLOCALE1 = "/1wlocale"
SlashCmdList["OWLOCALE"] = function()
    Locale:PrintReport()
end

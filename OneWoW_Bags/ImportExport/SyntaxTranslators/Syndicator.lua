local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.SyntaxTranslators = OneWoW_Bags.ImportExport.SyntaxTranslators or {}
local ST = OneWoW_Bags.ImportExport.SyntaxTranslators

local Registry = ST.Registry

local Syndicator = ST.Syndicator or {}
ST.Syndicator = Syndicator

local tinsert, tconcat = table.insert, table.concat
local string_lower, string_gsub, string_match = string.lower, string.gsub, string.match
local string_sub = string.sub
local pairs, ipairs, type = pairs, ipairs, type

-- English -> OneWoW canonical keyword map.
-- Left-hand side is the canonical English form of a Syndicator keyword.
-- Right-hand side is what OneWoW's PredicateEngine expects. `false` = known
-- Syndicator keyword with no OneWoW equivalent (emit warning, strip from output).
local ENGLISH_TO_OW = {
    -- quality
    poor = "poor", common = "common", uncommon = "uncommon",
    rare = "rare", epic = "epic", legendary = "legendary",
    artifact = "artifact", heirloom = "heirloom",
    -- classes / types
    weapon = "weapon", armor = "armor", consumable = "consumable",
    container = "container", bag = "container",
    reagent = "reagent", tradegoods = "tradegoods", tradegood = "tradegoods",
    recipe = "recipe", gem = "gem",
    questitem = "quest", quest = "quest",
    key = "key", miscellaneous = "miscellaneous", misc = "miscellaneous",
    glyph = "glyph", profession = "tradeskill", tradeskill = "tradeskill",
    housing = "housing",
    itemenhancement = "itemenhancement", enhancement = "itemenhancement",
    projectile = "projectile", quiver = "quiver",
    -- consumable subtypes
    potion = "potion", flask = "flask", elixir = "elixir",
    food = "food", drink = "food", bandage = "bandage",
    scroll = "scroll", vantusrune = "vantusrune",
    -- binding
    soulbound = "soulbound", bound = "soulbound", bop = "soulbound",
    boe = "boe", bindonequip = "boe",
    bou = "bou", bindonuse = "bou",
    boa = "boa", accountbound = "boa", warbound = "boa",
    wue = "wue", warbounduntilequip = "wue",
    -- collections
    toy = "toy", mount = "mount",
    pet = "pet", battlepet = "pet",
    collected = "collected", uncollected = "uncollected",
    -- misc
    junk = "junk", trash = "junk",
    set = "set", equipmentset = "set",
    equippable = "gear", equipment = "gear", gear = "gear",
    cosmetic = "cosmetic", socket = "socket",
    new = "new", usable = "usable", unusable = "unusable",
    equipped = "equipped",
    -- negative / untranslatable Syndicator-only keywords
    -- (entry set to false => emit warning, drop from output)
    ["auto"] = false,
    ["recent"] = false,
    ["bagtype"] = false,
}

local function addWarning(warnings, term, reason, severity)
    tinsert(warnings, {
        term = term or "",
        text = reason or "",
        severity = severity or "warn",
    })
end

local function normalizeKeyword(rawToken, context, warnings)
    local token = string_lower(rawToken)
    -- Step 1: direct English match
    local hit = ENGLISH_TO_OW[token]
    if hit ~= nil then
        if hit == false then
            addWarning(warnings, "#" .. rawToken, "Keyword has no OneWoW equivalent; rule dropped.", "warn")
            return nil, false
        end
        return hit, true
    end

    -- Step 2: live Syndicator API lookup for localized keywords -> English
    local live = rawget(_G, "Syndicator")
    if live and live.Search and live.Search.GetKeywordsForSubstring then
        -- Best effort: GetKeywordsForSubstring returns candidate keywords matching
        -- the substring; we only trust exact prefix/equality matches.
        local ok, candidates = pcall(live.Search.GetKeywordsForSubstring, token)
        if ok and type(candidates) == "table" then
            for _, cand in ipairs(candidates) do
                local candLower = string_lower(cand)
                if candLower == token then
                    local eng = ENGLISH_TO_OW[candLower]
                    if eng and eng ~= false then
                        return eng, true
                    end
                end
            end
        end
    end

    -- Step 3: bundled reverse map
    local localeMap = ST.SyndicatorLocaleMap
    if localeMap then
        local english = localeMap[token]
        if english then
            local owKey = ENGLISH_TO_OW[english]
            if owKey and owKey ~= false then
                return owKey, true
            end
        end
    end

    -- Step 4: unresolved — warn and preserve literal
    local locale = context and context.locale or (GetLocale and GetLocale() or "")
    local msg = "Keyword '#" .. rawToken .. "' could not be resolved"
    if locale ~= "" then
        msg = msg .. " (source locale " .. locale .. ")"
    end
    msg = msg .. "; preserved as-is."
    addWarning(warnings, "#" .. rawToken, msg, "warn")
    return rawToken, false
end

-- Translate a single "atom": a non-operator, non-whitespace token.
-- Atoms can be:
--   #keyword          -> normalize
--   !atom / ~atom     -> negation prefix (Syndicator treats ~ and ! as NOT)
--   "quoted string"   -> passthrough (name-substring)
--   name~substring    -> passthrough (same semantics in OneWoW)
--   ilvl comparisons  -> passthrough
--   12g / >5s etc     -> passthrough (OneWoW supports money shorthand)
--   bare numbers      -> passthrough (ilvl or itemID)
--   otherwise         -> passthrough + info warning
local function translateAtom(atom, context, warnings)
    -- Handle leading negation (~ or !)
    local negated = false
    local body = atom
    while true do
        local c = string_sub(body, 1, 1)
        if c == "!" or c == "~" then
            negated = not negated
            body = string_sub(body, 2)
        else
            break
        end
    end

    if body == "" then
        return atom
    end

    local prefix = negated and "!" or ""

    if string_sub(body, 1, 1) == "#" then
        local kw = string_sub(body, 2)
        if kw == "" then
            addWarning(warnings, body, "Empty keyword token dropped.", "warn")
            return ""
        end
        local owKw, ok = normalizeKeyword(kw, context, warnings)
        if owKw == nil then
            return ""
        end
        if not ok then
            -- preserved literal (already warned)
            return prefix .. "#" .. owKw
        end
        return prefix .. "#" .. owKw
    end

    -- Quoted string: passthrough
    if string_sub(body, 1, 1) == '"' then
        return prefix .. body
    end

    -- name~substring / name:substring / generic property predicates (ilvl:, quality:, ...)
    -- All are passthrough — OneWoW's predicate engine consumes the same shapes.
    return prefix .. body
end

-- Very lightweight tokenizer: splits the input into atoms and operators while
-- keeping bracket/quote balance. Syndicator's grammar uses `&`, `|`, `()`
-- operators with space-separated atoms. `&&` and `||` are both accepted and
-- reduced to `&` / `|` (the Baganator clipboard flow doubles them).
local function tokenize(input)
    local tokens = {}
    local i, n = 1, #input
    while i <= n do
        local c = string_sub(input, i, i)
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            i = i + 1
        elseif c == "(" or c == ")" then
            tinsert(tokens, { kind = "paren", value = c })
            i = i + 1
        elseif c == "&" then
            if string_sub(input, i + 1, i + 1) == "&" then
                tinsert(tokens, { kind = "op", value = "&" })
                i = i + 2
            else
                tinsert(tokens, { kind = "op", value = "&" })
                i = i + 1
            end
        elseif c == "|" then
            if string_sub(input, i + 1, i + 1) == "|" then
                tinsert(tokens, { kind = "op", value = "|" })
                i = i + 2
            else
                tinsert(tokens, { kind = "op", value = "|" })
                i = i + 1
            end
        elseif c == '"' then
            -- read quoted
            local j = i + 1
            while j <= n do
                if string_sub(input, j, j) == '"' then
                    break
                end
                j = j + 1
            end
            tinsert(tokens, { kind = "atom", value = string_sub(input, i, j) })
            i = j + 1
        else
            -- read atom: until whitespace or operator
            local j = i
            while j <= n do
                local cc = string_sub(input, j, j)
                if cc == " " or cc == "\t" or cc == "\n" or cc == "\r"
                   or cc == "(" or cc == ")" or cc == "&" or cc == "|" then
                    break
                end
                j = j + 1
            end
            tinsert(tokens, { kind = "atom", value = string_sub(input, i, j - 1) })
            i = j
        end
    end
    return tokens
end

-- Public contract — Syndicator translator entry point.
-- input: Syndicator search string.
-- context: { locale, liveSyndicator }
-- returns: { expression, warnings, translatable }
function Syndicator:Translate(input, context)
    local warnings = {}
    if type(input) ~= "string" or input == "" then
        return { expression = "", warnings = warnings, translatable = true }
    end

    -- Pre-normalize: Baganator clipboard export doubles `|` into `||` to escape
    -- WoW chat-link pipes; undo that here.
    local text = string_gsub(input, "||", "|")
    text = string_gsub(text, "&&", "&")

    local tokens = tokenize(text)
    local out = {}
    local translatable = true
    for idx, tok in ipairs(tokens) do
        if tok.kind == "atom" then
            local before = #warnings
            local atomOut = translateAtom(tok.value, context, warnings)
            for i = before + 1, #warnings do
                local w = warnings[i]
                if w.severity == "warn" or w.severity == "error" then
                    translatable = false
                end
            end
            if atomOut and atomOut ~= "" then
                tinsert(out, atomOut)
            end
        else
            tinsert(out, tok.value)
        end
    end

    -- Rejoin with spaces (operators get their own slots).
    local expression = tconcat(out, " ")
    -- Collapse accidental double-spaces from dropped atoms.
    expression = string_gsub(expression, "%s+", " ")
    expression = string_gsub(expression, "^%s+", "")
    expression = string_gsub(expression, "%s+$", "")

    return {
        expression = expression,
        warnings = warnings,
        translatable = translatable,
    }
end

if Registry and Registry.Register then
    Registry:Register("syndicator", Syndicator)
end

local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.Serializer = OneWoW_Bags.ImportExport.Serializer or {}
local Serializer = OneWoW_Bags.ImportExport.Serializer

Serializer.FORMAT = "OneWoW_Bags.Export"
Serializer.VERSION = 1

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert, tconcat = table.insert, table.concat
local sort = table.sort
local string_format, string_byte, string_sub = string.format, string.byte, string.sub
local string_gsub, string_match, string_find = string.gsub, string.match, string.find

-- ============================================================================
-- Encode
-- ============================================================================

local KEYWORD_TRUE = "true"
local KEYWORD_FALSE = "false"
local KEYWORD_NIL = "nil"

local function escapeString(s)
    local out = { '"' }
    for i = 1, #s do
        local c = string_sub(s, i, i)
        local b = string_byte(c)
        if c == '"' then
            tinsert(out, '\\"')
        elseif c == '\\' then
            tinsert(out, '\\\\')
        elseif c == '\n' then
            tinsert(out, '\\n')
        elseif c == '\r' then
            tinsert(out, '\\r')
        elseif c == '\t' then
            tinsert(out, '\\t')
        elseif b < 0x20 or b == 0x7F then
            tinsert(out, string_format("\\%03d", b))
        else
            tinsert(out, c)
        end
    end
    tinsert(out, '"')
    return tconcat(out)
end

local IDENT_PATTERN = "^[%a_][%w_]*$"
local RESERVED = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true,
}

local function formatKey(k)
    if type(k) == "number" then
        return "[" .. tostring(k) .. "]"
    end
    if type(k) == "string" then
        if string_match(k, IDENT_PATTERN) and not RESERVED[k] then
            return k
        end
        return "[" .. escapeString(k) .. "]"
    end
    error("Serializer: unsupported key type " .. type(k))
end

local function formatScalar(v)
    local t = type(v)
    if t == "string" then
        return escapeString(v)
    elseif t == "number" then
        if v ~= v then return "0/0" end
        if v == math.huge then return "1/0" end
        if v == -math.huge then return "-1/0" end
        return tostring(v)
    elseif t == "boolean" then
        return v and KEYWORD_TRUE or KEYWORD_FALSE
    elseif t == "nil" then
        return KEYWORD_NIL
    end
    error("Serializer: unsupported scalar type " .. t)
end

local function sortedKeys(tbl)
    local stringKeys = {}
    local numKeys = {}
    for k in pairs(tbl) do
        if type(k) == "number" then
            tinsert(numKeys, k)
        elseif type(k) == "string" then
            tinsert(stringKeys, k)
        end
    end
    sort(stringKeys)
    sort(numKeys)
    return stringKeys, numKeys
end

local encodeValue
local function encodeTable(tbl, indent, seen, out)
    if seen[tbl] then
        error("Serializer: cannot encode cyclic tables")
    end
    seen[tbl] = true

    local stringKeys, numKeys = sortedKeys(tbl)

    local isArray = (#stringKeys == 0) and (#numKeys > 0)
    if isArray then
        for i = 1, #numKeys do
            if numKeys[i] ~= i then
                isArray = false
                break
            end
        end
    end

    if (#stringKeys == 0) and (#numKeys == 0) then
        tinsert(out, "{}")
        seen[tbl] = nil
        return
    end

    local childIndent = indent .. "    "
    tinsert(out, "{\n")

    if isArray then
        for i, idx in ipairs(numKeys) do
            tinsert(out, childIndent)
            encodeValue(tbl[idx], childIndent, seen, out)
            if i < #numKeys then tinsert(out, ",") end
            tinsert(out, "\n")
        end
    else
        local first = true
        for _, k in ipairs(numKeys) do
            if not first then tinsert(out, ",\n") end
            first = false
            tinsert(out, childIndent)
            tinsert(out, formatKey(k))
            tinsert(out, " = ")
            encodeValue(tbl[k], childIndent, seen, out)
        end
        for _, k in ipairs(stringKeys) do
            if not first then tinsert(out, ",\n") end
            first = false
            tinsert(out, childIndent)
            tinsert(out, formatKey(k))
            tinsert(out, " = ")
            encodeValue(tbl[k], childIndent, seen, out)
        end
        tinsert(out, "\n")
    end

    tinsert(out, indent)
    tinsert(out, "}")
    seen[tbl] = nil
end

encodeValue = function(v, indent, seen, out)
    if type(v) == "table" then
        encodeTable(v, indent, seen, out)
    else
        tinsert(out, formatScalar(v))
    end
end

function Serializer:Encode(tbl)
    if type(tbl) ~= "table" then
        error("Serializer:Encode expected a table, got " .. type(tbl))
    end
    local out = {}
    encodeValue(tbl, "", {}, out)
    return tconcat(out)
end

-- ============================================================================
-- Decode (strict hand-written parser)
-- ============================================================================

local function makeState(text)
    return { text = text, pos = 1, len = #text }
end

local function skipWS(s)
    local t = s.text
    while s.pos <= s.len do
        local c = string_sub(t, s.pos, s.pos)
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            s.pos = s.pos + 1
        elseif c == "-" and string_sub(t, s.pos + 1, s.pos + 1) == "-" then
            -- line comment
            local nl = string_find(t, "\n", s.pos + 2, true)
            if not nl then
                s.pos = s.len + 1
            else
                s.pos = nl + 1
            end
        else
            break
        end
    end
end

local function decodeError(s, msg)
    local row, col = 1, 1
    for i = 1, s.pos - 1 do
        if string_sub(s.text, i, i) == "\n" then
            row = row + 1
            col = 1
        else
            col = col + 1
        end
    end
    return nil, string_format("Decode error at line %d col %d: %s", row, col, msg)
end

local function peek(s)
    return string_sub(s.text, s.pos, s.pos)
end

local function consume(s, ch)
    if peek(s) ~= ch then
        return false
    end
    s.pos = s.pos + 1
    return true
end

local function parseString(s)
    if peek(s) ~= '"' then
        return nil, "expected string"
    end
    s.pos = s.pos + 1
    local out = {}
    while s.pos <= s.len do
        local c = string_sub(s.text, s.pos, s.pos)
        if c == '"' then
            s.pos = s.pos + 1
            return tconcat(out)
        elseif c == "\\" then
            local n = string_sub(s.text, s.pos + 1, s.pos + 1)
            if n == "n" then tinsert(out, "\n"); s.pos = s.pos + 2
            elseif n == "r" then tinsert(out, "\r"); s.pos = s.pos + 2
            elseif n == "t" then tinsert(out, "\t"); s.pos = s.pos + 2
            elseif n == '"' then tinsert(out, '"'); s.pos = s.pos + 2
            elseif n == "\\" then tinsert(out, "\\"); s.pos = s.pos + 2
            elseif n == "'" then tinsert(out, "'"); s.pos = s.pos + 2
            elseif string_match(n, "%d") then
                local digits = string_match(s.text, "^%d%d?%d?", s.pos + 1)
                local b = tonumber(digits)
                if not b or b > 255 then
                    return nil, "invalid string escape"
                end
                tinsert(out, string.char(b))
                s.pos = s.pos + 1 + #digits
            else
                return nil, "invalid string escape \\" .. n
            end
        elseif c == "\n" then
            return nil, "unterminated string"
        else
            tinsert(out, c)
            s.pos = s.pos + 1
        end
    end
    return nil, "unterminated string"
end

local function parseNumber(s)
    local start = s.pos
    local m = string_match(s.text, "^-?%d+%.?%d*[eE]?[%+%-]?%d*", start)
    if not m or m == "" or m == "-" then
        return nil, "invalid number"
    end
    local n = tonumber(m)
    if n == nil then
        return nil, "invalid number '" .. m .. "'"
    end
    s.pos = start + #m
    return n
end

local function parseIdent(s)
    local m = string_match(s.text, "^[%a_][%w_]*", s.pos)
    if not m then return nil end
    s.pos = s.pos + #m
    return m
end

local parseValue

local function parseTable(s)
    if not consume(s, "{") then
        return nil, "expected '{'"
    end
    local out = {}
    local arrayIdx = 1
    skipWS(s)
    if consume(s, "}") then
        return out
    end
    while true do
        skipWS(s)
        local c = peek(s)
        if c == "[" then
            -- bracketed key
            s.pos = s.pos + 1
            skipWS(s)
            local k, err
            local ck = peek(s)
            if ck == '"' then
                k, err = parseString(s)
            else
                k, err = parseNumber(s)
            end
            if err then return nil, err end
            skipWS(s)
            if not consume(s, "]") then return nil, "expected ']'" end
            skipWS(s)
            if not consume(s, "=") then return nil, "expected '=' after key" end
            skipWS(s)
            local v
            v, err = parseValue(s)
            if err then return nil, err end
            out[k] = v
        else
            -- try ident = value OR positional value
            local savedPos = s.pos
            local ident = parseIdent(s)
            if ident then
                skipWS(s)
                if consume(s, "=") then
                    if ident == "true" or ident == "false" or ident == "nil" then
                        return nil, "reserved identifier as key"
                    end
                    skipWS(s)
                    local v, err = parseValue(s)
                    if err then return nil, err end
                    out[ident] = v
                else
                    -- treat ident as bare value (true/false/nil)
                    if ident == "true" then
                        out[arrayIdx] = true; arrayIdx = arrayIdx + 1
                    elseif ident == "false" then
                        out[arrayIdx] = false; arrayIdx = arrayIdx + 1
                    elseif ident == "nil" then
                        arrayIdx = arrayIdx + 1
                    else
                        return nil, "unexpected identifier '" .. ident .. "'"
                    end
                end
            else
                s.pos = savedPos
                local v, err = parseValue(s)
                if err then return nil, err end
                out[arrayIdx] = v
                arrayIdx = arrayIdx + 1
            end
        end
        skipWS(s)
        if consume(s, ",") then
            skipWS(s)
            if consume(s, "}") then return out end
        elseif consume(s, ";") then
            skipWS(s)
            if consume(s, "}") then return out end
        elseif consume(s, "}") then
            return out
        else
            return nil, "expected ',' or '}' in table"
        end
    end
end

parseValue = function(s)
    skipWS(s)
    local c = peek(s)
    if c == "" then return nil, "unexpected end of input" end
    if c == "{" then
        return parseTable(s)
    elseif c == '"' then
        return parseString(s)
    elseif c == "-" or string_match(c, "%d") then
        return parseNumber(s)
    else
        local ident = parseIdent(s)
        if ident == "true" then return true end
        if ident == "false" then return false end
        if ident == "nil" then return nil end
        return nil, "unexpected token near '" .. (ident or c) .. "'"
    end
end

function Serializer:Decode(text)
    if type(text) ~= "string" then
        return nil, "input must be a string"
    end
    local trimmed = string_gsub(text, "^%s+", "")
    trimmed = string_gsub(trimmed, "%s+$", "")
    if trimmed == "" then
        return nil, "empty input"
    end
    local s = makeState(trimmed)
    skipWS(s)
    local v, err = parseValue(s)
    if err then return nil, err end
    skipWS(s)
    if s.pos <= s.len then
        return decodeError(s, "trailing content after value")
    end
    return v
end

-- ============================================================================
-- BuildExport
-- ============================================================================

local function deepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, vv in pairs(v) do
        out[k] = deepCopy(vv, seen)
    end
    return out
end

local function copyAllowedCategoryFields(cat)
    if type(cat) ~= "table" then return nil end
    local out = {}
    if cat.name ~= nil then out.name = cat.name end
    if cat.enabled ~= nil then out.enabled = cat.enabled end
    if cat.sortOrder ~= nil then out.sortOrder = cat.sortOrder end
    if cat.filterMode ~= nil then out.filterMode = cat.filterMode end
    if cat.searchExpression ~= nil then out.searchExpression = cat.searchExpression end
    if cat.itemType ~= nil then out.itemType = cat.itemType end
    if cat.itemSubType ~= nil then out.itemSubType = cat.itemSubType end
    if cat.typeMatchMode ~= nil then out.typeMatchMode = cat.typeMatchMode end
    if cat.items ~= nil then out.items = deepCopy(cat.items) end
    if cat.isTSM ~= nil then out.isTSM = cat.isTSM end
    if cat.isBaganator ~= nil then out.isBaganator = cat.isBaganator end
    return out
end

local function copyAllowedSectionFields(sec, keepCategories)
    if type(sec) ~= "table" then return nil end
    local out = {}
    if sec.name ~= nil then out.name = sec.name end
    if sec.collapsed ~= nil then out.collapsed = sec.collapsed end
    if sec.showHeader ~= nil then out.showHeader = sec.showHeader end
    if sec.showHeaderBank ~= nil then out.showHeaderBank = sec.showHeaderBank end
    if keepCategories and sec.categories then
        out.categories = deepCopy(sec.categories)
    end
    return out
end

function Serializer:BuildExport(db)
    local g = db and db.global
    if not g then error("Serializer:BuildExport: missing db.global") end

    local SD = OneWoW_Bags.SectionDefaults
    local ownBagsId = SD and SD.SEC_ONEWOW_BAGS

    local sections = {}
    for sid, sec in pairs(g.categorySections or {}) do
        -- export the ONEWOW BAGS section shell but strip its categories (regenerated on import)
        local keepCats = (sid ~= ownBagsId)
        sections[sid] = copyAllowedSectionFields(sec, keepCats)
        if not keepCats and sections[sid] then
            sections[sid].categories = nil
        end
    end

    local categories = {}
    for cid, cat in pairs(g.customCategoriesV2 or {}) do
        categories[cid] = copyAllowedCategoryFields(cat)
    end

    local playerName = UnitName and UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or ""
    local exportedBy = playerName
    if realm ~= "" then
        exportedBy = playerName .. "-" .. string_gsub(realm, "%s+", "")
    end

    local envelope = {
        format             = Serializer.FORMAT,
        version            = Serializer.VERSION,
        addon              = "OneWoW_Bags",
        exportedAt         = time and time() or 0,
        exportedBy         = exportedBy,
        exportedLocale     = GetLocale and GetLocale() or "enUS",
        scope              = "all",
        sections           = sections,
        sectionOrder       = deepCopy(g.sectionOrder) or {},
        categories         = categories,
        modifications      = deepCopy(g.categoryModifications) or {},
        disabledCategories = deepCopy(g.disabledCategories) or {},
        categoryOrder      = deepCopy(g.categoryOrder) or {},
        displayOrder       = deepCopy(g.displayOrder) or {},
    }
    return envelope
end

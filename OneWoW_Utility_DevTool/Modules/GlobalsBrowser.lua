local _, Addon = ...

local GB = {}
Addon.GlobalsBrowser = GB
local L = Addon.L or {}

local format = format
local gsub = string.gsub
local ipairs = ipairs
local lower = string.lower
local match = string.match
local pcall = pcall
local pairs = pairs
local sort = sort
local strfind = string.find
local tostring = tostring
local tinsert = tinsert
local tremove = tremove
local type = type
local wipe = wipe

local CATEGORY_ALL = "all"
local CATEGORY_GLOBALS = "globals"
local CATEGORY_ENUM = "enum"
local CATEGORY_ADDON_DATA = "addon_data"

local ROOT_SCAN_COUNT_LIMIT = 500
local CHILD_COUNT_LIMIT = 200
local TREE_MAX_DEPTH = 8
local STRING_PREVIEW_LIMIT = 96
local SERIALIZE_MAX_DEPTH = 5
local SERIALIZE_CHILD_LIMIT = 200
local FILTERED_SEARCH_BUDGET = 50000

local EXCLUDED_GLOBALS = {
    _G = true,
    Enum = true,
    APIDocumentation = true,
}

local MIXIN_SUFFIXES = {
    "Mixin$",
    "Template$",
    "Util$",
    "Behavior$",
    "Handler$",
    "Controller$",
    "Provider$",
    "Manager$",
    "Base$",
    "Proto$",
    "Frame$",
    "Button$",
    "Dialog$",
    "Tooltip$",
}

GB.CATEGORY_ALL = CATEGORY_ALL
GB.CATEGORY_GLOBALS = CATEGORY_GLOBALS
GB.CATEGORY_ENUM = CATEGORY_ENUM
GB.CATEGORY_ADDON_DATA = CATEGORY_ADDON_DATA

GB.filterText = ""
GB.treeFilterText = ""
GB.categoryFilter = CATEGORY_ALL
GB.favoritesOnly = false
GB.includeNoisyRoots = false
GB.rootEntries = {}
GB.filteredEntries = {}
GB.globalCount = 0
GB.enumCount = 0
GB.addonDataCount = 0
GB.indexVersion = 0
GB.indexBuilt = false
GB._entryPool = {}

local function copyMap(src)
    local out = {}
    if not src then
        return out
    end
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

local function copySeenMapForChild(seenMap, childValue)
    local childSeenMap = copyMap(seenMap)
    childSeenMap[childValue] = true
    return childSeenMap
end

local function normalizeSearch(text)
    return lower(gsub(text or "", "%s+", ""))
end

local function trimText(text)
    text = tostring(text or "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function escapeLuaString(text)
    text = tostring(text or "")
    text = gsub(text, "\\", "\\\\")
    text = gsub(text, "\"", "\\\"")
    text = gsub(text, "\n", "\\n")
    text = gsub(text, "\r", "\\r")
    return text
end

local function isIdentifier(text)
    return type(text) == "string" and match(text, "^[%a_][%w_]*$") ~= nil
end

local function isSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

local function isSecretTable(value)
    return issecrettable and issecrettable(value) or false
end

local function _iterateAndCount(value, limit)
    local count = 0
    for _ in pairs(value) do
        count = count + 1
        if count >= limit then
            return count, true
        end
    end
    return count, false
end

local function _callGetObjectType(value)
    return value.GetObjectType and value:GetObjectType()
end

local function _countMixinHits(value)
    local hitCount = 0
    if type(value.OnLoad) == "function" then hitCount = hitCount + 1 end
    if type(value.OnEvent) == "function" then hitCount = hitCount + 1 end
    if type(value.OnShow) == "function" then hitCount = hitCount + 1 end
    if type(value.OnHide) == "function" then hitCount = hitCount + 1 end
    if type(value.Init) == "function" then hitCount = hitCount + 1 end
    if type(value.OnUpdate) == "function" then hitCount = hitCount + 1 end
    return hitCount
end

local function _callGetName(value)
    if value.GetName then
        return value:GetName()
    end
    return nil
end

local function _safeTableIndex(tbl, key)
    return tbl[key]
end

local function _collectKeys(value, numKeys, strKeys, otherKeys)
    for key in pairs(value) do
        local keyType = type(key)
        if keyType == "number" then
            tinsert(numKeys, key)
        elseif keyType == "string" then
            tinsert(strKeys, key)
        else
            tinsert(otherKeys, key)
        end
    end
end

local _searchParts = {}
local _filterParts = {}
local _numKeys = {}
local _strKeys = {}
local _otherKeys = {}

local function safePairsCount(value, limit)
    if type(value) ~= "table" then
        return nil, false
    end
    if isSecretTable(value) then
        return nil, false
    end
    local ok, count, capped = pcall(_iterateAndCount, value, limit)
    if not ok then
        return nil, false
    end
    return count, capped
end

local function getWidgetObjectType(value)
    if value == nil then
        return nil
    end
    local valueType = type(value)
    if valueType ~= "table" and valueType ~= "userdata" then
        return nil
    end
    local ok, objectType = pcall(_callGetObjectType, value)
    if ok and type(objectType) == "string" then
        return objectType
    end
    return nil
end

local function looksLikeWidget(value)
    return getWidgetObjectType(value) ~= nil
end

local function looksLikeMixin(value)
    if type(value) ~= "table" then
        return false
    end
    local ok, hitCount = pcall(_countMixinHits, value)
    return ok and hitCount >= 2
end

local function isMixinNamed(key)
    if type(key) ~= "string" then
        return false
    end
    for _, suffix in ipairs(MIXIN_SUFFIXES) do
        if match(key, suffix) then
            return true
        end
    end
    return false
end

local function safeToString(value)
    if isSecretValue(value) or isSecretTable(value) then
        return "[secret]"
    end
    local ok, result = pcall(tostring, value)
    if not ok then
        return "[error]"
    end
    return result
end

local function getGlobalReference(key)
    if isIdentifier(key) then
        return key
    end
    return format('_G["%s"]', escapeLuaString(key))
end

local function getKeyReferenceSuffix(key)
    local keyType = type(key)
    if keyType == "string" then
        if isIdentifier(key) then
            return "." .. key, true
        end
        return format('["%s"]', escapeLuaString(key)), true
    end
    if keyType == "number" then
        return "[" .. tostring(key) .. "]", true
    end
    if keyType == "boolean" then
        return "[" .. tostring(key) .. "]", true
    end
    return nil, false
end

local function composeChildReference(parentReference, key)
    if type(parentReference) ~= "string" or parentReference == "" then
        return nil, false
    end
    local suffix, ok = getKeyReferenceSuffix(key)
    if not ok then
        return nil, false
    end
    return parentReference .. suffix, true
end

local function getTypePriority(valueType)
    if valueType == "table" then return 1 end
    if valueType == "userdata" then return 2 end
    if valueType == "function" then return 3 end
    if valueType == "string" then return 4 end
    if valueType == "number" then return 5 end
    if valueType == "boolean" then return 6 end
    return 7
end

local function getCategoryPriority(category)
    if category == CATEGORY_ENUM then return 1 end
    if category == CATEGORY_GLOBALS then return 2 end
    if category == CATEGORY_ADDON_DATA then return 3 end
    return 4
end

local function rootEntryComparator(a, b)
    local aCat = getCategoryPriority(a.category)
    local bCat = getCategoryPriority(b.category)
    if aCat ~= bCat then return aCat < bCat end
    local aType = getTypePriority(a.valueType)
    local bType = getTypePriority(b.valueType)
    if aType ~= bType then return aType < bType end
    return lower(a.listLabel or a.label) < lower(b.listLabel or b.label)
end

local function getTableCountText(value)
    local count, capped = safePairsCount(value, ROOT_SCAN_COUNT_LIMIT)
    if count == nil then
        return nil
    end
    if capped then
        return tostring(count) .. "+"
    end
    return tostring(count)
end

local function getDisplayType(value)
    if isSecretValue(value) or isSecretTable(value) then
        return "secret"
    end
    return type(value)
end

function GB:DescribeValue(value)
    local valueType = getDisplayType(value)
    local summary = {
        valueType = valueType,
        typeLabel = valueType,
        count = nil,
        countText = nil,
        preview = nil,
    }

    if valueType == "table" then
        local count, capped = safePairsCount(value, ROOT_SCAN_COUNT_LIMIT)
        summary.count = count
        if count ~= nil then
            summary.countText = capped and (tostring(count) .. "+") or tostring(count)
        end
        if summary.countText then
            summary.preview = summary.countText .. " entries"
        else
            summary.preview = "table"
        end
        return summary
    end

    if valueType == "string" then
        local display = value
        if #display > STRING_PREVIEW_LIMIT then
            display = display:sub(1, STRING_PREVIEW_LIMIT) .. "..."
        end
        summary.preview = '"' .. display:gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
        return summary
    end

    if valueType == "userdata" then
        local objectType = getWidgetObjectType(value)
        local ok, name = pcall(_callGetName, value)
        if objectType then
            summary.typeLabel = objectType
        end
        if ok and type(name) == "string" and name ~= "" then
            summary.preview = name
        else
            summary.preview = safeToString(value)
        end
        return summary
    end

    summary.preview = safeToString(value)
    return summary
end

function GB:FormatValue(value)
    if isSecretValue(value) or isSecretTable(value) then
        return "[secret]"
    end

    local valueType = type(value)
    if value == nil then
        return "nil"
    end
    if valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end
    if valueType == "string" then
        local display = value
        if #display > STRING_PREVIEW_LIMIT then
            display = display:sub(1, STRING_PREVIEW_LIMIT) .. "..."
        end
        return '"' .. display:gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
    end
    if valueType == "function" then
        return "function"
    end
    if valueType == "table" then
        local count, capped = safePairsCount(value, ROOT_SCAN_COUNT_LIMIT)
        if count == nil then
            return "{? entries}"
        end
        local countText = capped and (tostring(count) .. "+") or tostring(count)
        return "{" .. countText .. " entries}"
    end
    if valueType == "userdata" then
        local objectType = getWidgetObjectType(value)
        local nameOk, name = pcall(_callGetName, value)
        if objectType and nameOk and type(name) == "string" and name ~= "" then
            return "<" .. objectType .. ": " .. name .. ">"
        end
        if objectType then
            return "<" .. objectType .. ">"
        end
        return safeToString(value)
    end
    return safeToString(value)
end

function GB:FormatDisplayKey(key)
    local keyType = type(key)
    if keyType == "number" then
        return "[" .. tostring(key) .. "]"
    end
    if keyType == "string" then
        if isIdentifier(key) then
            return key
        end
        return format('["%s"]', escapeLuaString(key))
    end
    if keyType == "boolean" then
        return "[" .. tostring(key) .. "]"
    end
    return "[" .. safeToString(key) .. "]"
end

local function getSortedKeys(value)
    wipe(_numKeys)
    wipe(_strKeys)
    wipe(_otherKeys)
    local ok = pcall(_collectKeys, value, _numKeys, _strKeys, _otherKeys)
    if not ok then
        return {}
    end
    sort(_numKeys)
    sort(_strKeys)
    sort(_otherKeys, function(a, b)
        return safeToString(a) < safeToString(b)
    end)
    local result = {}
    for _, key in ipairs(_numKeys) do
        tinsert(result, key)
    end
    for _, key in ipairs(_strKeys) do
        tinsert(result, key)
    end
    for _, key in ipairs(_otherKeys) do
        tinsert(result, key)
    end
    return result
end

local function buildSearchText(entry)
    wipe(_searchParts)
    _searchParts[1] = entry.label or ""
    _searchParts[2] = entry.listLabel or ""
    _searchParts[3] = entry.reference or ""
    _searchParts[4] = entry.valueType or ""
    _searchParts[5] = entry.category or ""
    local n = 5
    if entry.ownerAddon then n = n + 1; _searchParts[n] = entry.ownerAddon end
    if entry.ownerTitle then n = n + 1; _searchParts[n] = entry.ownerTitle end
    if entry.scopeLabel then n = n + 1; _searchParts[n] = entry.scopeLabel end
    if entry.sourceLabel then n = n + 1; _searchParts[n] = entry.sourceLabel end
    if entry.countText then n = n + 1; _searchParts[n] = entry.countText end
    return normalizeSearch(table.concat(_searchParts, " ", 1, n))
end

local function getAddOnCount()
    if not C_AddOns or not C_AddOns.GetNumAddOns then
        return 0
    end
    local ok, count = pcall(C_AddOns.GetNumAddOns)
    if ok and type(count) == "number" then
        return count
    end
    return 0
end

local function getAddOnInfo(index)
    if not C_AddOns or not C_AddOns.GetAddOnInfo then
        return nil
    end
    local ok, name, title = pcall(C_AddOns.GetAddOnInfo, index)
    if not ok then
        return nil, nil
    end
    if type(name) == "table" then
        return name.name or name.Name, name.title or name.Title
    end
    return name, title
end

local function resolveAddOnDataTable(addOnName)
    if type(addOnName) ~= "string" or addOnName == "" then
        return nil, nil
    end
    if C_AddOns and C_AddOns.GetAddOnLocalTable then
        local ok, value = pcall(C_AddOns.GetAddOnLocalTable, addOnName)
        if ok and type(value) == "table" then
            return value, "local"
        end
    end
    local globalValue = _G[addOnName]
    if type(globalValue) == "table" then
        return globalValue, "global"
    end
    return nil, nil
end

local function getBookmarkKey(entry)
    if not entry then
        return nil
    end
    return entry.bookmarkKey or entry.reference
end

local function valueMatchesFilter(self, filterText, keyLabel, reference, value)
    if not filterText or filterText == "" then
        return true
    end
    wipe(_filterParts)
    _filterParts[1] = keyLabel or ""
    _filterParts[2] = reference or ""
    _filterParts[3] = getDisplayType(value) or ""
    _filterParts[4] = self:FormatValue(value)
    local haystack = normalizeSearch(table.concat(_filterParts, " ", 1, 4))
    return strfind(haystack, filterText, 1, true) ~= nil
end

local function shouldIncludeGlobal(key, value)
    if type(key) ~= "string" then
        return false
    end
    if EXCLUDED_GLOBALS[key] then
        return false
    end
    if not GB.includeNoisyRoots then
        if match(key, "^C_") then
            return false
        end
        if looksLikeWidget(value) then
            return false
        end
        if type(value) == "table" then
            if isMixinNamed(key) then
                return false
            end
            if looksLikeMixin(value) then
                return false
            end
        end
    end
    return true
end

function GB:RebuildRootIndex()
    local roots = self.rootEntries
    local pool = self._entryPool

    for i = 1, #roots do
        local e = roots[i]
        wipe(e)
        pool[#pool + 1] = e
    end
    wipe(roots)

    self.globalCount = 0
    self.enumCount = 0
    self.addonDataCount = 0

    if type(Enum) == "table" then
        for key, value in pairs(Enum) do
            if type(key) == "string" and type(value) == "table" then
                local entry = tremove(pool) or {}
                entry.category = CATEGORY_ENUM
                entry.key = key
                entry.label = key
                entry.listLabel = key
                entry.reference = "Enum." .. key
                entry.bookmarkKey = "enum:" .. key
                entry.value = value
                entry.valueType = getDisplayType(value)
                entry.countText = getTableCountText(value)
                tinsert(roots, entry)
                self.enumCount = self.enumCount + 1
            end
        end
    end

    for key, value in pairs(_G) do
        if shouldIncludeGlobal(key, value) then
            local entry = tremove(pool) or {}
            entry.category = CATEGORY_GLOBALS
            entry.key = key
            entry.label = key
            entry.listLabel = key
            entry.reference = getGlobalReference(key)
            entry.bookmarkKey = "global:" .. key
            entry.value = value
            entry.valueType = getDisplayType(value)
            entry.countText = type(value) == "table" and getTableCountText(value) or nil
            tinsert(roots, entry)
            self.globalCount = self.globalCount + 1
        end
    end

    local addOnCount = getAddOnCount()
    for index = 1, addOnCount do
        local addOnName, addOnTitle = getAddOnInfo(index)
        if type(addOnName) == "string" and addOnName ~= "" then
            local addOnValue, sourceKind = resolveAddOnDataTable(addOnName)
            if type(addOnValue) == "table" then
                local entry = tremove(pool) or {}
                entry.category = CATEGORY_ADDON_DATA
                entry.key = addOnName
                entry.label = addOnName
                entry.listLabel = (type(addOnTitle) == "string" and addOnTitle ~= "" and addOnTitle) or addOnName
                entry.reference = sourceKind == "global" and getGlobalReference(addOnName) or nil
                entry.bookmarkKey = "addon:" .. addOnName
                entry.value = addOnValue
                entry.valueType = getDisplayType(addOnValue)
                entry.countText = getTableCountText(addOnValue)
                entry.ownerAddon = addOnName
                entry.ownerTitle = (type(addOnTitle) == "string" and addOnTitle ~= "" and addOnTitle) or addOnName
                entry.sourceKind = sourceKind
                entry.sourceLabel = (sourceKind == "local")
                    and (L["GLOBALS_ADDON_SOURCE_LOCAL"])
                    or (L["GLOBALS_ADDON_SOURCE_GLOBAL"])
                tinsert(roots, entry)
                self.addonDataCount = self.addonDataCount + 1
            end
        end
    end

    sort(roots, rootEntryComparator)
end

function GB:RebuildFiltered()
    if not self.filteredEntries then
        self.filteredEntries = {}
    else
        wipe(self.filteredEntries)
    end

    local filterText = self.filterText or ""
    local categoryFilter = self.categoryFilter or CATEGORY_ALL
    local needsSearch = filterText ~= ""

    for _, entry in ipairs(self.rootEntries) do
        if (not self.favoritesOnly or self:IsBookmarked(entry))
            and (categoryFilter == CATEGORY_ALL or entry.category == categoryFilter)
        then
            if needsSearch then
                if not entry.searchText then
                    entry.searchText = buildSearchText(entry)
                end
                if strfind(entry.searchText, filterText, 1, true) then
                    tinsert(self.filteredEntries, entry)
                end
            else
                tinsert(self.filteredEntries, entry)
            end
        end
    end
end

function GB:ResetFilterState()
    self.filterText = ""
    self.treeFilterText = ""
    self.categoryFilter = CATEGORY_ALL
    self.favoritesOnly = false
    self.includeNoisyRoots = Addon.db and Addon.db.globalsIncludeNoisyRoots and true or false
    if self.indexBuilt then
        self:RebuildFiltered()
    else
        self:RefreshIndex()
    end
end

function GB:RefreshIndex()
    self:RebuildRootIndex()
    self:RebuildFiltered()
    self.indexBuilt = true
    self.indexVersion = (self.indexVersion or 0) + 1
end

function GB:GetIndexVersion()
    return self.indexVersion or 0
end

function GB:SetFilterText(text)
    self.filterText = normalizeSearch(text)
    self:RebuildFiltered()
end

function GB:SetTreeFilterText(text)
    self.treeFilterText = normalizeSearch(text)
end

function GB:SetCategoryFilter(category)
    if category ~= CATEGORY_GLOBALS and category ~= CATEGORY_ENUM and category ~= CATEGORY_ADDON_DATA then
        self.categoryFilter = CATEGORY_ALL
    else
        self.categoryFilter = category
    end
    self:RebuildFiltered()
end

function GB:SetFavoritesOnly(on)
    self.favoritesOnly = on and true or false
    self:RebuildFiltered()
end

function GB:SetIncludeNoisyRoots(on)
    self.includeNoisyRoots = on and true or false
    if Addon.db then
        Addon.db.globalsIncludeNoisyRoots = self.includeNoisyRoots
    end
    self:RefreshIndex()
end

function GB:GetFilteredCount()
    return #self.filteredEntries
end

function GB:GetFilteredEntry(index)
    return self.filteredEntries[index]
end

function GB:IsBookmarked(entry)
    local bookmarkKey = getBookmarkKey(entry)
    if not bookmarkKey or not Addon.db or not Addon.db.globalsBookmarks then
        return false
    end
    return Addon.db.globalsBookmarks[bookmarkKey] and true or false
end

function GB:ToggleBookmark(entry)
    local bookmarkKey = getBookmarkKey(entry)
    if not bookmarkKey or not Addon.db then
        return nil
    end
    Addon.db.globalsBookmarks = Addon.db.globalsBookmarks or {}
    if Addon.db.globalsBookmarks[bookmarkKey] then
        Addon.db.globalsBookmarks[bookmarkKey] = nil
        return false
    end
    Addon.db.globalsBookmarks[bookmarkKey] = true
    return true
end

function GB:GetRootLabel(entry)
    if not entry then
        return ""
    end
    local parts = {
        entry.listLabel or entry.label or "",
        "(" .. (entry.valueType or "?"),
    }
    if entry.countText then
        parts[#parts] = parts[#parts] .. ", " .. entry.countText
    end
    parts[#parts] = parts[#parts] .. ")"
    return table.concat(parts, " ")
end

function GB:GetRootTooltip(entry)
    if not entry then
        return nil
    end
    local lines = {
        entry.reference or entry.label or "",
        "Type: " .. (entry.valueType or "?"),
    }
    if entry.ownerTitle then
        tinsert(lines, "Addon: " .. entry.ownerTitle)
    end
    if entry.sourceLabel then
        tinsert(lines, "Source: " .. entry.sourceLabel)
    end
    if entry.scopeLabel then
        tinsert(lines, "Scope: " .. entry.scopeLabel)
    end
    if entry.countText then
        tinsert(lines, "Entries: " .. entry.countText)
    end
    return table.concat(lines, "\n")
end

function GB:GetHeaderTitle(target)
    if not target then
        return ""
    end
    return target.reference or target.label or ""
end

function GB:GetHeaderSubtitle(target)
    if not target then
        return ""
    end
    local summary = self:DescribeValue(target.value)
    local parts = { summary.typeLabel or "?" }
    if summary.countText then
        tinsert(parts, summary.countText .. " entries")
    elseif summary.preview and summary.valueType ~= "table" then
        tinsert(parts, summary.preview)
    end
    return table.concat(parts, " | ")
end

function GB:GetBreadcrumb(target)
    if not target then
        return ""
    end
    return target.reference or target.label or ""
end

local function makeNodeId(parentId, key, offset)
    local keyText = safeToString(key)
    return format("%s::%s::%s", parentId or "root", keyText, tostring(offset or 0))
end

local function makeInfoNode(id, text, parentNode)
    return {
        id = id,
        text = text,
        parentNode = parentNode,
        value = nil,
        reference = nil,
        canCopyReference = false,
        hasChildren = false,
        children = {},
        isInfoNode = true,
    }
end

local function setChildParents(nodes, parentNode)
    for _, child in ipairs(nodes) do
        child.parentNode = parentNode
    end
end

function GB:BuildValueTree(target)
    if not target then
        return {}
    end
    local value = target.value
    local filterText = self.treeFilterText or ""
    if isSecretTable(value) or isSecretValue(value) then
        return {
            makeInfoNode("root.secret", "[secret]", nil),
        }
    end
    if type(value) ~= "table" then
        return {
            {
                id = "root.value",
                text = self:FormatValue(value),
                value = value,
                reference = target.reference,
                canCopyReference = target.reference ~= nil,
                hasChildren = false,
                children = {},
                parentNode = nil,
            },
        }
    end
    local seen = { [value] = true }
    local nodes
    if filterText ~= "" then
        local budget = { FILTERED_SEARCH_BUDGET }
        nodes = self:BuildFilteredTableChildren(value, target.reference, 0, seen, nil, filterText, budget)
        if #nodes == 0 then
            return {
                makeInfoNode("root.nomatch", L["GLOBALS_MSG_NO_MATCHES"], nil),
            }
        end
    else
        nodes = self:BuildTableChildren(value, target.reference, 0, seen, nil)
    end
    setChildParents(nodes, nil)
    return nodes
end

function GB:BuildFilteredTableChildren(tableValue, parentReference, depth, seenMap, parentNode, filterText, budget)
    if type(tableValue) ~= "table" then
        return {}
    end
    if isSecretTable(tableValue) or depth >= TREE_MAX_DEPTH then
        return {}
    end
    if budget and budget[1] <= 0 then
        return {}
    end

    local keys = getSortedKeys(tableValue)
    local nodes = {}
    local omitted = 0

    for index, key in ipairs(keys) do
        if budget then
            budget[1] = budget[1] - 1
            if budget[1] <= 0 then
                tinsert(nodes, makeInfoNode(makeNodeId(parentReference, "__budget", depth), "... (search limit reached)", parentNode))
                break
            end
        end

        local ok, childValue = pcall(_safeTableIndex, tableValue, key)
        if not ok then
            childValue = nil
        end

        local keyLabel = self:FormatDisplayKey(key)
        local childReference, canCopyReference = composeChildReference(parentReference, key)
        local selfMatches = valueMatchesFilter(self, filterText, keyLabel, childReference, childValue)
        local childChildren = nil
        local childHasMatches = false

        if type(childValue) == "table" and not isSecretTable(childValue) and not isSecretValue(childValue) and not seenMap[childValue] then
            seenMap[childValue] = true
            childChildren = self:BuildFilteredTableChildren(childValue, childReference, depth + 1, seenMap, nil, filterText, budget)
            seenMap[childValue] = nil
            childHasMatches = childChildren and #childChildren > 0
        end

        if selfMatches or childHasMatches then
            if #nodes < CHILD_COUNT_LIMIT then
                local text = keyLabel .. " = "
                local childNode = {
                    id = makeNodeId(parentReference, key, index),
                    key = key,
                    label = keyLabel,
                    value = childValue,
                    reference = childReference,
                    canCopyReference = canCopyReference,
                    parentNode = parentNode,
                    hasChildren = false,
                    children = {},
                    depth = depth,
                }

                if isSecretValue(childValue) or isSecretTable(childValue) then
                    childNode.text = text .. "[secret]"
                elseif type(childValue) == "table" then
                    childNode.text = text .. self:FormatValue(childValue)
                    if childHasMatches then
                        childNode.hasChildren = true
                        childNode.children = childChildren
                        setChildParents(childNode.children, childNode)
                    end
                else
                    childNode.text = text .. self:FormatValue(childValue)
                end

                tinsert(nodes, childNode)
            else
                omitted = omitted + 1
            end
        end
    end

    if omitted > 0 then
        tinsert(nodes, makeInfoNode(makeNodeId(parentReference, "__filtered", depth), "... (" .. tostring(omitted) .. " more matches)", parentNode))
    end

    return nodes
end

function GB:BuildTableChildren(tableValue, parentReference, depth, seenMap, parentNode)
    if type(tableValue) ~= "table" then
        return {
            makeInfoNode(makeNodeId(parentReference, "__value", depth), self:FormatValue(tableValue), parentNode),
        }
    end

    if isSecretTable(tableValue) then
        return {
            makeInfoNode(makeNodeId(parentReference, "__secret", depth), "[secret]", parentNode),
        }
    end

    if depth >= TREE_MAX_DEPTH then
        return {
            makeInfoNode(makeNodeId(parentReference, "__maxdepth", depth), "[max depth reached]", parentNode),
        }
    end

    local keys = getSortedKeys(tableValue)
    local nodes = {}
    local shown = 0

    for i, key in ipairs(keys) do
        if shown >= CHILD_COUNT_LIMIT then
            local remaining = #keys - shown
            tinsert(nodes, {
                id = makeNodeId(parentReference, "__more", depth),
                text = "... (" .. tostring(remaining) .. " more)",
                isTruncated = true,
                parentNode = parentNode,
                parentNodes = nodes,
                sourceTable = tableValue,
                sourceKeys = keys,
                sourceOffset = shown,
                parentReference = parentReference,
                depth = depth,
                seenMap = seenMap,
            })
            break
        end

        local ok, childValue = pcall(_safeTableIndex, tableValue, key)
        if not ok then
            childValue = nil
        end

        local keyLabel = self:FormatDisplayKey(key)
        local childReference, canCopyReference = composeChildReference(parentReference, key)
        local text = keyLabel .. " = "
        local childSeenMap = nil
        local childNode = {
            id = makeNodeId(parentReference, key, i),
            key = key,
            label = keyLabel,
            value = childValue,
            reference = childReference,
            canCopyReference = canCopyReference,
            parentNode = parentNode,
            hasChildren = false,
            children = {},
            seenMap = nil,
            depth = depth,
        }

        if isSecretValue(childValue) or isSecretTable(childValue) then
            childNode.text = text .. "[secret]"
        elseif type(childValue) == "table" then
            if seenMap[childValue] then
                childNode.text = text .. "[circular reference]"
            else
                childNode.text = text .. self:FormatValue(childValue)
                childNode.hasChildren = true
                childNode.children = nil
                childSeenMap = copySeenMapForChild(seenMap, childValue)
                childNode.seenMap = childSeenMap
            end
        else
            childNode.text = text .. self:FormatValue(childValue)
        end

        tinsert(nodes, childNode)
        shown = shown + 1
    end

    if #nodes == 0 then
        tinsert(nodes, makeInfoNode(makeNodeId(parentReference, "__empty", depth), "(empty table)", parentNode))
    end

    return nodes
end

function GB:PopulateNodeChildren(node)
    if not node or not node.hasChildren or node.children ~= nil then
        return false
    end
    node.children = self:BuildTableChildren(node.value, node.reference, (node.depth or 0) + 1, node.seenMap or {}, node)
    setChildParents(node.children, node)
    return true
end

function GB:LoadMoreNode(node)
    if not node or not node.isTruncated then
        return false
    end

    local parentNode = node.parentNode
    local parentChildren = node.parentNodes or (parentNode and parentNode.children)
    if type(parentChildren) ~= "table" then
        return false
    end

    local insertAt
    for idx, child in ipairs(parentChildren) do
        if child == node then
            insertAt = idx
            break
        end
    end
    if not insertAt then
        return false
    end

    local keys = node.sourceKeys or {}
    local tableValue = node.sourceTable
    local offset = node.sourceOffset or 0
    local parentReference = node.parentReference
    local depth = node.depth or 0
    local seenMap = node.seenMap or {}

    parentChildren[insertAt] = nil
    for i = insertAt, #parentChildren do
        parentChildren[i] = parentChildren[i + 1]
    end
    parentChildren[#parentChildren] = nil

    local appended = {}
    local shown = 0

    for index = offset + 1, #keys do
        if shown >= CHILD_COUNT_LIMIT then
            local remaining = #keys - (offset + shown)
            tinsert(appended, {
                id = makeNodeId(parentReference, "__more", depth + shown),
                text = "... (" .. tostring(remaining) .. " more)",
                isTruncated = true,
                parentNode = parentNode,
                parentNodes = parentChildren,
                sourceTable = tableValue,
                sourceKeys = keys,
                sourceOffset = offset + shown,
                parentReference = parentReference,
                depth = depth,
                seenMap = seenMap,
            })
            break
        end

        local key = keys[index]
        local ok, childValue = pcall(_safeTableIndex, tableValue, key)
        if not ok then
            childValue = nil
        end

        local keyLabel = self:FormatDisplayKey(key)
        local childReference, canCopyReference = composeChildReference(parentReference, key)
        local childNode = {
            id = makeNodeId(parentReference, key, index),
            key = key,
            label = keyLabel,
            value = childValue,
            reference = childReference,
            canCopyReference = canCopyReference,
            parentNode = parentNode,
            hasChildren = false,
            children = {},
            seenMap = nil,
            depth = depth,
        }

        local text = keyLabel .. " = "
        if isSecretValue(childValue) or isSecretTable(childValue) then
            childNode.text = text .. "[secret]"
        elseif type(childValue) == "table" then
            if seenMap[childValue] then
                childNode.text = text .. "[circular reference]"
            else
                childNode.text = text .. self:FormatValue(childValue)
                childNode.hasChildren = true
                childNode.children = nil
                childNode.seenMap = copySeenMapForChild(seenMap, childValue)
            end
        else
            childNode.text = text .. self:FormatValue(childValue)
        end

        tinsert(appended, childNode)
        shown = shown + 1
    end

    for _, child in ipairs(appended) do
        tinsert(parentChildren, child)
    end
    return true
end

local function serializeScalar(value)
    if isSecretValue(value) or isSecretTable(value) then
        return '"<secret>"'
    end
    local valueType = type(value)
    if valueType == "nil" then
        return "nil"
    end
    if valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end
    if valueType == "string" then
        return '"' .. escapeLuaString(value) .. '"'
    end
    if valueType == "function" then
        return '"<function>"'
    end
    if valueType == "userdata" then
        return '"' .. escapeLuaString(safeToString(value)) .. '"'
    end
    return '"' .. escapeLuaString("<" .. valueType .. ">") .. '"'
end

local function serializeKey(key)
    local keyType = type(key)
    if keyType == "string" then
        if isIdentifier(key) then
            return key
        end
        return format('["%s"]', escapeLuaString(key))
    end
    if keyType == "number" or keyType == "boolean" then
        return "[" .. tostring(key) .. "]"
    end
    return format('["<%s key>"]', keyType)
end

local function serializeValue(value, depth, seen)
    if type(value) ~= "table" or isSecretTable(value) then
        return serializeScalar(value)
    end
    if seen[value] then
        return '"<circular>"'
    end
    if depth >= SERIALIZE_MAX_DEPTH then
        return '"<max depth>"'
    end

    seen[value] = true

    local keys = getSortedKeys(value)
    local lines = { "{" }
    local childCount = 0
    for _, key in ipairs(keys) do
        childCount = childCount + 1
        if childCount > SERIALIZE_CHILD_LIMIT then
            tinsert(lines, string.rep("  ", depth + 1) .. format('["<truncated>"] = "%d more entries",', #keys - SERIALIZE_CHILD_LIMIT))
            break
        end
        local ok, childValue = pcall(_safeTableIndex, value, key)
        if not ok then
            childValue = "<error>"
        end
        tinsert(lines, string.rep("  ", depth + 1) .. serializeKey(key) .. " = " .. serializeValue(childValue, depth + 1, seen) .. ",")
    end
    tinsert(lines, string.rep("  ", depth) .. "}")

    seen[value] = nil
    return table.concat(lines, "\n")
end

function GB:GetCopyValue(target)
    if not target then
        return ""
    end
    return serializeValue(target.value, 0, {})
end

function GB:GetCopyReference(target)
    if not target or not target.canCopyReference and not target.reference then
        return nil
    end
    return target.reference
end

GB:RefreshIndex()

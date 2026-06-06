local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.Util = OneWoW_Bags.ImportExport.Util or {}
local Util = OneWoW_Bags.ImportExport.Util

local pairs, type = pairs, type
local tinsert = tinsert
local string_lower = string.lower
local strtrim = strtrim or function(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

--- Recursively deep-copy a value. Tables are cloned with shared-table aliasing
--- preserved across the traversal via the `seen` map.
---@param v any
---@param seen table|nil internal — maps original tables to clones
---@return any
function Util.DeepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, vv in pairs(v) do
        out[k] = Util.DeepCopy(vv, seen)
    end
    return out
end

--- Normalize a string key for case-insensitive, whitespace-tolerant comparison.
--- Non-string inputs collapse to the empty string.
---@param name any
---@return string
function Util.NormKey(name)
    if type(name) ~= "string" then return "" end
    return string_lower(strtrim(name))
end

--- Trim leading/trailing whitespace from a string. Falls back to a Lua-only
--- implementation when the WoW global `strtrim` is unavailable (e.g. tests).
---@param s string|nil
---@return string
function Util.StrTrim(s)
    return strtrim(s or "")
end

--- Queue SAVED(Name) tokens from a predicate string into a normKey visit set and
--- FIFO queue (deduped by normKey).
---@param text string|nil
---@param visited table<string, boolean>
---@param queue string[]
local function enqueueSavedTokens(text, visited, queue)
    if type(text) ~= "string" or text == "" then return end
    for inner in text:gmatch("SAVED%(([^%)]*)%)") do
        local nk = Util.NormKey(inner)
        if nk ~= "" and not visited[nk] then
            visited[nk] = true
            tinsert(queue, nk)
        end
    end
end

--- Collect the transitive closure of saved searches referenced by exported categories.
--- Returns displayName -> query using keys from the live store.
---@param categories table<string, table>
---@param store table<string, string>|nil
---@return table<string, string>
function Util.CollectReferencedSavedSearches(categories, store)
    local out = {}
    local visited = {}
    local queue = {}

    for _, cat in pairs(categories or {}) do
        if type(cat) == "table" and cat.searchExpression then
            enqueueSavedTokens(cat.searchExpression, visited, queue)
        end
    end

    local idx = 1
    while idx <= #queue do
        local nk = queue[idx]
        idx = idx + 1
        for key, query in pairs(store or {}) do
            if Util.NormKey(key) == nk then
                out[key] = query
                if type(query) == "string" then
                    enqueueSavedTokens(query, visited, queue)
                end
                break
            end
        end
    end

    return out
end

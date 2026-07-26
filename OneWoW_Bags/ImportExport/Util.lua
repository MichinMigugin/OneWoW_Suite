local _, ns = ...

ns.ImportExport = ns.ImportExport or {}
ns.ImportExport.Util = ns.ImportExport.Util or {}
local Util = ns.ImportExport.Util

local pairs, type = pairs, type
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

-- The SAVED-only closure walk that used to live here is gone: it covered one of
-- the three reference kinds, so a rule saying `#sell` shipped a bundle that
-- resolved to nothing on the far side. SearchCatalog:BuildExportPayload walks
-- all three, and core owns the payload format.

---@meta _

-- Even though we overload these, the base GetCursorInfo() definition with no return values gets merged in.

---@overload fun(): "item", number, string
---@overload fun(): "spell", number, string, number, number
---@overload fun(): "petaction", number, number, string
---@overload fun(): "macro", number
---@overload fun(): "money", number
---@overload fun(): "mount", number, number
---@overload fun(): "merchant", number
---@overload fun(): "battlepet", string
function GetCursorInfo() end

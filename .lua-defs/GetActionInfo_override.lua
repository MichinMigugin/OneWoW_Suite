---@meta _

---@alias ActionInfoType
---| "spell"
---| "item"
---| "macro"
---| "companion"
---| "summonpet"
---| "equipmentset"
---| "outfit"
---| "flyout"
---| "assistedcombat"

---@param slot number
---@return ActionInfoType actionType
---@return number|string id
---@return string subType
function GetActionInfo(slot) end

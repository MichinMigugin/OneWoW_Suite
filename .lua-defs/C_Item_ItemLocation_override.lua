---@meta _

---@overload fun(emptiableItemLocation: ItemLocationMixin): boolean
function C_Item.DoesItemExist(emptiableItemLocation) end

---@overload fun(itemLocation: ItemLocationMixin): string?
function C_Item.GetItemLink(itemLocation) end

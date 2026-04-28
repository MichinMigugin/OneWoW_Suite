---@meta _

---@overload fun(emptiableItemLocation: ItemLocationMixin): boolean
function C_Item.DoesItemExist(emptiableItemLocation) end

---@overload fun(itemLocation: ItemLocationMixin): string?
function C_Item.GetItemLink(itemLocation) end

---@overload fun(itemLocation: ItemLocationMixin): boolean
function C_Item.CanBeRefunded(itemLocation) end

---@overload fun(itemLocation: ItemLocationMixin): boolean
function C_Item.CanScrapItem(itemLocation) end

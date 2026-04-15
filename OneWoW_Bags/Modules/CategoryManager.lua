local _, OneWoW_Bags = ...

local base = OneWoW_Bags.CategoryManagerBase:Create()
OneWoW_Bags.CategoryManager = base
local CM = base

function CM:AssignCategories()
    local BagSet = OneWoW_Bags.BagSet
    local Categories = OneWoW_Bags.Categories
    local buttons = BagSet:GetAllButtons()

    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo then
            button.owb_categoryName = Categories:GetItemCategory(button.owb_bagID, button.owb_slotID, button.owb_itemInfo)
        else
            button.owb_categoryName = nil
        end
    end
end

function CM:GetItemsByCategory()
    local BagSet = OneWoW_Bags.BagSet
    local result = {}
    local buttons = BagSet:GetAllButtons()

    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_categoryName then
            if not result[button.owb_categoryName] then
                result[button.owb_categoryName] = {}
            end
            tinsert(result[button.owb_categoryName], button)
        end
    end

    return result
end



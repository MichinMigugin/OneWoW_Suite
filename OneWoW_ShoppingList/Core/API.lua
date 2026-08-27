local _, ns = ...

-- Public, cross-addon read surface for the ShoppingList hub. ns stays private.
OneWoW_ShoppingList_API = {}

--- Toggle the Shopping List main window.
function OneWoW_ShoppingList_API.Toggle()
    if ns.MainWindow and ns.MainWindow.Toggle then
        ns.MainWindow:Toggle()
    end
end

--- Show the Shopping List main window.
function OneWoW_ShoppingList_API.Show()
    if ns.MainWindow and ns.MainWindow.Show then
        ns.MainWindow:Show()
    end
end

--- Hide the Shopping List main window.
function OneWoW_ShoppingList_API.Hide()
    if ns.MainWindow and ns.MainWindow.Hide then
        ns.MainWindow:Hide()
    end
end

--- Name of the list currently selected in Shopping List.
---@return string|nil
function OneWoW_ShoppingList_API.GetActiveListName()
    return ns.ShoppingList:GetActiveListName()
end

--- Parent (top-level) list names, favorites first.
---@return string[]
function OneWoW_ShoppingList_API.GetParentListNames()
    return ns.ShoppingList:GetParentLists()
end

--- Merge `{ itemID, quantity }` rows into a list. Quantities add if the item exists.
---@param listName string
---@param items { itemID: number, quantity: number }[]
---@return boolean
function OneWoW_ShoppingList_API.AddItems(listName, items)
    if not listName or type(items) ~= "table" then
        return false
    end
    local sl = ns.ShoppingList
    for i = 1, #items do
        local row = items[i]
        if row and row.itemID then
            sl:AddItemToList(listName, row.itemID, row.quantity or 1)
        end
    end
    return true
end

--- Create an empty named list. Returns false if the name is already used.
---@param name string
---@return boolean
function OneWoW_ShoppingList_API.CreateNamedList(name)
    if not name or name == "" then
        return false
    end
    local ok = ns.ShoppingList:CreateList(name)
    return ok == true
end

--- True when itemID is on any resolved shopping list.
---@param itemID number|string
---@return boolean onList
---@return string[] listNames
function OneWoW_ShoppingList_API.IsOnAnyList(itemID)
    return ns.ShoppingList:IsOnAnyList(itemID)
end

--- True when at least one list still has owned < needed for this itemID.
---@param itemID number|string
---@return boolean
function OneWoW_ShoppingList_API.IsStillNeeded(itemID)
    return ns.ShoppingList:IsStillNeeded(itemID)
end

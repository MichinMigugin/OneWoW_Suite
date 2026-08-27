local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

-- Cross-unit Shopping List writes go through OneWoW_ShoppingList_API only.
-- Optional at call time: no suite OptionalDeps; recover via data-ready.

function M:HasShoppingList()
    return OneWoW_ShoppingList_API ~= nil
end

function M:GetActiveShoppingListName()
    if not OneWoW_ShoppingList_API then return nil end
    return OneWoW_ShoppingList_API.GetActiveListName()
end

function M:AddReagentsToList(listName, items)
    if not OneWoW_ShoppingList_API or not listName or not items or #items == 0 then
        return false
    end
    return OneWoW_ShoppingList_API.AddItems(listName, items)
end

function M:AddReagentsToActive(items)
    local name = M:GetActiveShoppingListName()
    if not name then return false end
    return M:AddReagentsToList(name, items)
end

function M:MakeListForOrder(entry)
    if not OneWoW_ShoppingList_API then return false end
    if not entry or not entry.missingReagents or #entry.missingReagents == 0 then
        return false
    end
    local api = OneWoW_ShoppingList_API
    local base = L["CRAFTORDERS_ORDER_LIST_NAME"]:format(entry.name or "")
    local name = base
    local n = 2
    while not api.CreateNamedList(name) do
        name = base .. " (" .. n .. ")"
        n = n + 1
        if n > 30 then return false end
    end
    return api.AddItems(name, entry.missingReagents)
end

function M:ShowAddMenu(owner, entry)
    if not OneWoW_ShoppingList_API then return end
    local api = OneWoW_ShoppingList_API
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        local active = api.GetActiveListName()
        if active then
            rootDescription:CreateButton(L["CRAFTORDERS_ADD_ACTIVE"]:format(active), function()
                M:AddReagentsToList(active, entry.missingReagents)
            end)
        end
        rootDescription:CreateButton(L["CRAFTORDERS_MAKE_LIST"], function()
            M:MakeListForOrder(entry)
        end)
        local names = api.GetParentListNames()
        if names then
            for i = 1, #names do
                local listName = names[i]
                if listName ~= active then
                    rootDescription:CreateButton(listName, function()
                        M:AddReagentsToList(listName, entry.missingReagents)
                    end)
                end
            end
        end
    end)
end

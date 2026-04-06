local ADDON_NAME, ns = ...
local L = ns.L

ns.ShoppingList = {}
local ShoppingList = ns.ShoppingList

local MAIN_LIST_KEY = ns.MAIN_LIST_KEY or "Main List"
local alertCooldowns = {}
local ALERT_COOLDOWN = 60
local craftableCache = {}

local refreshPending = false
local function ScheduleRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.05, function()
        refreshPending = false
        if ns.MainWindow and ns.MainWindow.RefreshSidebar then
            ns.MainWindow:RefreshSidebar()
        end
        if ns.MainWindow and ns.MainWindow.RefreshItemList then
            ns.MainWindow:RefreshItemList()
        end
        if ns.BagOverlays and ns.BagOverlays.RefreshAll then
            ns.BagOverlays:RefreshAll()
        end
    end)
end

local function GetDB()
    return OneWoW_ShoppingList_DB
end

function ShoppingList:Initialize()
    MAIN_LIST_KEY = ns.MAIN_LIST_KEY or "Main List"
    craftableCache = {}
    self.initialized = true
    C_Timer.After(2, function()
        self:FixAllCraftOrderNames()
    end)
end

function ShoppingList:GenerateUUID()
    local t = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return t:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

function ShoppingList:GetAllLists()
    return GetDB().global.shoppingLists.lists
end

function ShoppingList:GetActiveListName()
    return GetDB().global.shoppingLists.activeList
end

function ShoppingList:SetActiveList(listName)
    if GetDB().global.shoppingLists.lists[listName] then
        GetDB().global.shoppingLists.activeList = listName
        return true
    end
    return false
end

function ShoppingList:GetDefaultListName()
    return GetDB().global.shoppingLists.defaultList or MAIN_LIST_KEY
end

function ShoppingList:SetDefaultList(listName)
    if GetDB().global.shoppingLists.lists[listName] then
        GetDB().global.shoppingLists.defaultList = listName
        return true
    end
    return false
end

function ShoppingList:GetList(listName)
    return GetDB().global.shoppingLists.lists[listName]
end

function ShoppingList:CreateList(listName, parentListName)
    local db = GetDB().global.shoppingLists.lists
    if db[listName] then
        return false, L["OWSL_LIST_EXISTS"]
    end

    db[listName] = {
        uuid        = self:GenerateUUID(),
        name        = listName,
        created     = GetServerTime(),
        items       = {},
        unresolvedItems = {},
        baseItems   = {},
        searchAlts  = false,
        isParent    = false,
        isCraftOrder = false,
        parentList  = nil,
        childLists  = {},
        quantity    = 1,
    }

    if parentListName then
        local parentList = self:GetList(parentListName)
        if parentList then
            db[listName].parentList = parentListName
            if not parentList.childLists then parentList.childLists = {} end
            table.insert(parentList.childLists, listName)
            parentList.isParent = true
        end
    end

    return true
end

function ShoppingList:CreateCraftOrder(parentListName, itemID, quantity, recipeID, recipeName)
    if not parentListName or not itemID or not quantity then
        return false, "Missing required parameters", false
    end

    local parentList = self:GetList(parentListName)
    if not parentList then
        return false, "Parent list not found", false
    end

    local existingOrders = self:GetCraftOrdersByItem(itemID)
    for _, order in ipairs(existingOrders) do
        if order.parentList == parentListName then
            local existingList = self:GetList(order.listName)
            if existingList then
                self:UpdateListQuantity(order.listName, (existingList.quantity or 1) + quantity)
                return true, order.listName, true
            end
        end
    end

    C_Item.RequestLoadItemDataByID(itemID)
    local itemName = C_Item.GetItemNameByID(itemID) or C_Item.GetItemInfo(itemID) or (string.format(L["OWSL_ITEM_PREFIX"], itemID))

    local craftOrderName = "Craft: " .. itemName
    if self:GetList(craftOrderName) then
        craftOrderName = craftOrderName .. " #" .. math.random(1000, 9999)
    end

    local db = GetDB().global.shoppingLists.lists
    db[craftOrderName] = {
        uuid         = self:GenerateUUID(),
        name         = craftOrderName,
        created      = GetServerTime(),
        items        = {},
        unresolvedItems = {},
        baseItems    = {},
        searchAlts   = parentList.searchAlts or false,
        isParent     = false,
        isCraftOrder = true,
        parentList   = parentListName,
        childLists   = {},
        quantity     = quantity,
        craftedItem  = {
            itemID    = itemID,
            quantity  = quantity,
            itemName  = itemName,
            recipeID  = recipeID,
            recipeName = recipeName,
        },
    }

    if not parentList.childLists then parentList.childLists = {} end
    table.insert(parentList.childLists, craftOrderName)
    parentList.isParent = true

    if itemName:match("^Item %d+$") then
        C_Timer.After(0.5, function()
            self:UpdateCraftOrderName(craftOrderName, itemID)
        end)
    end

    return true, craftOrderName, false
end

function ShoppingList:GetCraftOrdersByItem(itemID)
    local result = {}
    for listName, list in pairs(GetDB().global.shoppingLists.lists) do
        if list.isCraftOrder and list.craftedItem and list.craftedItem.itemID == itemID then
            table.insert(result, {
                listName   = listName,
                parentList = list.parentList,
                quantity   = list.quantity or 1,
            })
        end
    end
    return result
end

function ShoppingList:GetParentLists()
    local result = {}
    for listName, list in pairs(GetDB().global.shoppingLists.lists) do
        if not list.isCraftOrder and not list.parentList then
            table.insert(result, listName)
        end
    end
    return result
end

function ShoppingList:GetChildLists(listName)
    local list = self:GetList(listName)
    if not list or not list.childLists then return {} end
    return list.childLists
end

function ShoppingList:IsCraftOrder(listName)
    local list = self:GetList(listName)
    return list and list.isCraftOrder or false
end

function ShoppingList:UpdateCraftOrderName(oldName, itemID)
    local list = self:GetList(oldName)
    if not list or not list.isCraftOrder then return false end

    C_Item.RequestLoadItemDataByID(itemID)
    local itemName = C_Item.GetItemNameByID(itemID) or C_Item.GetItemInfo(itemID)
    if not itemName or itemName:match("^Item %d+$") then return false end

    local newName = "Craft: " .. itemName
    if oldName == newName then return false end

    local existing = self:GetList(newName)
    if existing and existing ~= list then
        newName = newName .. " #" .. math.random(1000, 9999)
    end

    local ok = self:RenameList(oldName, newName)
    if ok and list.craftedItem then
        list.craftedItem.itemName = itemName
    end

    return ok
end

function ShoppingList:FixAllCraftOrderNames()
    local toFix = {}
    for listName, list in pairs(GetDB().global.shoppingLists.lists) do
        if list.isCraftOrder and list.craftedItem and listName:match("^Craft: Item %d+") then
            table.insert(toFix, { listName = listName, itemID = list.craftedItem.itemID })
        end
    end
    local fixed = 0
    for _, info in ipairs(toFix) do
        if self:UpdateCraftOrderName(info.listName, info.itemID) then
            fixed = fixed + 1
        end
    end
    return fixed
end

function ShoppingList:RenameList(oldName, newName)
    local db = GetDB().global.shoppingLists
    if not db.lists[oldName] then
        return false, L["OWSL_LIST_NOT_FOUND"]
    end
    if db.lists[newName] then
        return false, L["OWSL_TARGET_EXISTS"]
    end

    local list = db.lists[oldName]
    list.name = newName
    db.lists[newName] = list
    db.lists[oldName] = nil

    if db.activeList == oldName then db.activeList = newName end
    if db.defaultList == oldName then db.defaultList = newName end

    if list.parentList then
        local parentList = self:GetList(list.parentList)
        if parentList and parentList.childLists then
            for i, childName in ipairs(parentList.childLists) do
                if childName == oldName then
                    parentList.childLists[i] = newName
                    break
                end
            end
        end
    end

    if list.childLists then
        for _, childName in ipairs(list.childLists) do
            local child = self:GetList(childName)
            if child then child.parentList = newName end
        end
    end

    return true
end

function ShoppingList:DeleteList(listName)
    local db = GetDB().global.shoppingLists
    if listName == MAIN_LIST_KEY then
        return false, L["OWSL_CANNOT_DELETE_MAIN"]
    end
    if not db.lists[listName] then
        return false, L["OWSL_LIST_NOT_FOUND"]
    end

    local list = db.lists[listName]

    if list.childLists then
        for _, childName in ipairs(list.childLists) do
            db.lists[childName] = nil
            if db.activeList == childName then db.activeList = MAIN_LIST_KEY end
        end
    end

    if list.parentList then
        local parentList = self:GetList(list.parentList)
        if parentList and parentList.childLists then
            for i, childName in ipairs(parentList.childLists) do
                if childName == listName then
                    table.remove(parentList.childLists, i)
                    break
                end
            end
            if #parentList.childLists == 0 then
                parentList.isParent = false
            end
        end
    end

    db.lists[listName] = nil
    if db.activeList == listName then db.activeList = MAIN_LIST_KEY end
    if db.defaultList == listName then db.defaultList = MAIN_LIST_KEY end

    ScheduleRefresh()
    return true
end

function ShoppingList:AddItemToList(listName, itemID, quantity, notes)
    local list = self:GetList(listName)
    if not list then return false, L["OWSL_LIST_NOT_FOUND"] end

    itemID = tonumber(itemID)
    if not itemID then return false, L["OWSL_INVALID_ITEM"] end

    quantity = tonumber(quantity) or 1
    if quantity < 1 then quantity = 1 end

    if not list.baseItems then list.baseItems = {} end
    if not list.items then list.items = {} end

    local listQty = list.quantity or 1

    if list.baseItems[itemID] then
        list.baseItems[itemID].quantity = list.baseItems[itemID].quantity + quantity
    else
        list.baseItems[itemID] = { itemID = itemID, quantity = quantity, notes = notes or "" }
    end

    if list.items[itemID] then
        list.items[itemID].quantity = list.baseItems[itemID].quantity * listQty
        if notes and notes ~= "" then list.items[itemID].notes = notes end
    else
        list.items[itemID] = {
            itemID    = itemID,
            quantity  = list.baseItems[itemID].quantity * listQty,
            addedTime = GetServerTime(),
            notes     = notes or "",
        }
    end

    ScheduleRefresh()
    return true
end

function ShoppingList:AddItemByName(listName, itemName, quantity, notes)
    local list = self:GetList(listName)
    if not list then return false, L["OWSL_LIST_NOT_FOUND"] end
    if not itemName or itemName == "" then return false, "Invalid item name" end

    quantity = tonumber(quantity) or 1
    if quantity < 1 then quantity = 1 end

    if not list.unresolvedItems then list.unresolvedItems = {} end

    local unresolvedID = "unresolved_" .. itemName:gsub("%s+", "_"):lower() .. "_" .. tostring(GetServerTime())
    list.unresolvedItems[unresolvedID] = {
        itemName  = itemName,
        quantity  = quantity,
        addedTime = GetServerTime(),
        notes     = notes or "",
    }

    ScheduleRefresh()
    return true
end

function ShoppingList:RemoveItemFromList(listName, itemID)
    local list = self:GetList(listName)
    if not list then return false, L["OWSL_LIST_NOT_FOUND"] end

    itemID = tonumber(itemID)
    if not itemID then return false, L["OWSL_INVALID_ITEM"] end

    list.items[itemID] = nil
    if list.baseItems then list.baseItems[itemID] = nil end

    ScheduleRefresh()
    return true
end

function ShoppingList:RemoveUnresolvedItem(listName, unresolvedID)
    local list = self:GetList(listName)
    if not list then return false, L["OWSL_LIST_NOT_FOUND"] end
    if not list.unresolvedItems then return false, "Item not found" end
    list.unresolvedItems[unresolvedID] = nil
    ScheduleRefresh()
    return true
end

function ShoppingList:ConvertUnresolvedToResolved(listName, unresolvedID, itemID)
    local list = self:GetList(listName)
    if not list then return false, L["OWSL_LIST_NOT_FOUND"] end
    if not list.unresolvedItems or not list.unresolvedItems[unresolvedID] then
        return false, "Unresolved item not found"
    end

    itemID = tonumber(itemID)
    if not itemID then return false, L["OWSL_INVALID_ITEM"] end

    local itemName = C_Item.GetItemNameByID(itemID)
    if not itemName then return false, "Item ID not found" end

    local unresolved = list.unresolvedItems[unresolvedID]
    local ok = self:AddItemToList(listName, itemID, unresolved.quantity, unresolved.notes)
    if ok then
        list.unresolvedItems[unresolvedID] = nil
        return true, itemName
    end

    return false, "Failed to add item"
end

function ShoppingList:UpdateListQuantity(listName, newQty)
    local list = self:GetList(listName)
    if not list then return false, "List not found" end

    newQty = tonumber(newQty) or 1
    if newQty < 1 then newQty = 1 end

    list.quantity = newQty
    if list.isCraftOrder and list.craftedItem then
        list.craftedItem.quantity = newQty
    end

    if list.baseItems and next(list.baseItems) then
        for itemID, baseItem in pairs(list.baseItems) do
            if list.items[itemID] then
                list.items[itemID].quantity = baseItem.quantity * newQty
            end
        end
    end

    return true
end

function ShoppingList:UpdateItemQuantity(listName, itemID, quantity)
    local list = self:GetList(listName)
    if not list then return false, L["OWSL_LIST_NOT_FOUND"] end

    itemID = tonumber(itemID)
    if not itemID or not list.items[itemID] then return false, "Item not in list" end

    quantity = tonumber(quantity) or 1
    if quantity < 1 then quantity = 1 end

    list.items[itemID].quantity = quantity
    if list.baseItems and list.baseItems[itemID] then
        list.baseItems[itemID].quantity = math.ceil(quantity / (list.quantity or 1))
    end

    ScheduleRefresh()
    return true
end

function ShoppingList:UpdateUnresolvedQuantity(listName, uid, quantity)
    local list = self:GetList(listName)
    if not list or not list.unresolvedItems or not list.unresolvedItems[uid] then return false end
    quantity = tonumber(quantity) or 1
    if quantity < 1 then quantity = 1 end
    list.unresolvedItems[uid].quantity = quantity
    ScheduleRefresh()
    return true
end

function ShoppingList:GetCraftOrderTotalQuantity(itemID, parentListName)
    local total = 0
    for _, list in pairs(GetDB().global.shoppingLists.lists) do
        if list.isCraftOrder and list.craftedItem and list.craftedItem.itemID == itemID and list.parentList == parentListName then
            total = total + (list.quantity or 1)
        end
    end
    return total
end

function ShoppingList:IsOnAnyList(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false, {} end

    local found = {}
    for listName, list in pairs(GetDB().global.shoppingLists.lists) do
        if list.items and list.items[itemID] then
            table.insert(found, listName)
        end
    end

    return #found > 0, found
end

function ShoppingList:GetItemStatus(itemID, specificListName)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local listName = specificListName
    if not listName then
        local isOnList, lists = self:IsOnAnyList(itemID)
        if not isOnList or #lists == 0 then return nil end
        listName = lists[1]
    end

    local list = self:GetList(listName)
    if not list or not list.items or not list.items[itemID] then return nil end

    local needed = list.items[itemID].quantity
    local inventoryData = ns.DataAccess:GetItemInventoryData(itemID, list)

    local owned    = inventoryData.owned    or 0
    local altOwned = inventoryData.altOwned or 0
    local total    = owned + altOwned

    local status, statusColor
    if total >= needed then
        if owned >= needed then
            status = "green";  statusColor = {0, 1, 0}
        else
            status = "blue";   statusColor = {0.3, 0.5, 1}
        end
    elseif total > 0 then
        status = "yellow"; statusColor = {1, 1, 0}
    else
        status = "red";    statusColor = {1, 0, 0}
    end

    return {
        needed      = needed,
        owned       = owned,
        altOwned    = altOwned,
        totalOwned  = total,
        status      = status,
        statusColor = statusColor,
        locations   = inventoryData.locations or {},
        listName    = listName,
    }
end

function ShoppingList:GetAllItemStatuses(itemID)
    itemID = tonumber(itemID)
    if not itemID then return {} end

    local isOnList, lists = self:IsOnAnyList(itemID)
    if not isOnList then return {} end

    local statuses = {}
    for _, listName in ipairs(lists) do
        local s = self:GetItemStatus(itemID, listName)
        if s then table.insert(statuses, s) end
    end

    return statuses
end

function ShoppingList:IsItemCraftable(itemID)
    if not itemID then return false end

    if craftableCache[itemID] ~= nil then
        return craftableCache[itemID].result, craftableCache[itemID].recipes
    end

    local profAddon = _G.OneWoW_CatalogData_Tradeskills
    if not profAddon then
        craftableCache[itemID] = { result = false }
        return false
    end

    local DataAPI = profAddon.GetDataAPI and profAddon:GetDataAPI()
    if not DataAPI or not DataAPI.IsDataAddonReady or not DataAPI:IsDataAddonReady() then
        craftableCache[itemID] = { result = false }
        return false
    end

    local recipes = DataAPI:FindRecipesByItem(itemID)
    if recipes and #recipes > 0 then
        craftableCache[itemID] = { result = true, recipes = recipes }
        return true, recipes
    end

    craftableCache[itemID] = { result = false }
    return false
end

function ShoppingList:GetCraftableRecipes(itemID)
    local ok, recipes = self:IsItemCraftable(itemID)
    if not ok then return {} end
    return recipes or {}
end

function ShoppingList:CalculateCraftIngredients(recipeID, quantity)
    if not recipeID or not quantity then return {} end

    local profAddon = _G.OneWoW_CatalogData_Tradeskills
    if not profAddon then return {} end

    local profNS = profAddon.GetNamespace and profAddon:GetNamespace()
    if not profNS or not profNS.RecipeHelper then return {} end

    local details = profNS.RecipeHelper:GetRecipeDetails(recipeID)
    if not details or not details.reagents or #details.reagents == 0 then return {} end

    local ingredients = {}
    for _, reagent in ipairs(details.reagents) do
        table.insert(ingredients, {
            itemID       = reagent.itemID,
            quantity     = reagent.qtyRequired * quantity,
            baseQuantity = reagent.qtyRequired,
        })
    end

    return ingredients, details
end

function ShoppingList:GetRecipeKnownBy(recipeID)
    if not recipeID then return {} end

    local profAddon = _G.OneWoW_CatalogData_Tradeskills
    if not profAddon then return {} end

    local profNS = profAddon.GetNamespace and profAddon:GetNamespace()
    if not profNS or not profNS.RecipeHelper then return {} end

    local details = profNS.RecipeHelper:GetRecipeDetails(recipeID)
    if not details or not details.knownBy then return {} end

    local knownBy = {}
    for _, charInfo in ipairs(details.knownBy) do
        if charInfo.knows then
            local key = charInfo.characterKey
            table.insert(knownBy, {
                characterKey  = key,
                characterName = key:match("([^%-]+)"),
                realm         = key:match("%-(.+)"),
            })
        end
    end

    return knownBy
end

function ShoppingList:CanShowAlert(itemID, alertType)
    local now = GetServerTime()
    local key = tostring(itemID) .. "_" .. alertType

    if alertCooldowns[key] then
        if now - alertCooldowns[key] < ALERT_COOLDOWN then
            return false
        end
    end

    alertCooldowns[key] = now
    return true
end

function ShoppingList:ExportList(listName)
    local list = self:GetList(listName)
    if not list then return nil, "List not found" end

    local items = {}
    for itemID, itemInfo in pairs(list.items or {}) do
        local itemName = C_Item.GetItemNameByID(itemID) or (string.format(L["OWSL_ITEM_PREFIX"], itemID))
        table.insert(items, {
            itemID   = itemID,
            name     = itemName,
            quantity = itemInfo.quantity,
            notes    = itemInfo.notes or "",
        })
    end

    table.sort(items, function(a, b) return a.name < b.name end)

    local lines = {}
    table.insert(lines, "OWSL-Export-v1:" .. listName)
    for _, item in ipairs(items) do
        table.insert(lines, string.format("%d|%d|%s", item.itemID, item.quantity, item.notes))
    end
    table.insert(lines, "-- Shopping List: " .. listName)
    for _, item in ipairs(items) do
        local notePart = (item.notes ~= "") and (" (" .. item.notes .. ")") or ""
        table.insert(lines, string.format("x%d %s%s", item.quantity, item.name, notePart))
    end

    return table.concat(lines, "\n")
end

function ShoppingList:ImportList(encoded, targetListName)
    if not encoded or encoded == "" then
        return false, L["OWSL_MSG_PASTE_TEXT"]
    end

    local header = encoded:match("^OWSL%-Export%-v1:([^\n]+)")
    if not header then
        return self:ImportTextFormat(encoded, targetListName)
    end

    local listName = targetListName or header
    local items = {}

    for line in encoded:gmatch("[^\n]+") do
        local id, qty, notes = line:match("^(%d+)|(%d+)|(.*)$")
        if id then
            table.insert(items, { itemID = tonumber(id), quantity = tonumber(qty), notes = notes })
        end
    end

    if #items == 0 then
        return false, L["OWSL_MSG_NO_VALID_ITEMS"]
    end

    local db = GetDB().global.shoppingLists
    if db.lists[listName] then
        for _, item in ipairs(items) do
            self:AddItemToList(listName, item.itemID, item.quantity, item.notes)
        end
    else
        local ok, err = self:CreateList(listName)
        if not ok then return false, err end
        for _, item in ipairs(items) do
            self:AddItemToList(listName, item.itemID, item.quantity, item.notes)
        end
    end

    return true, #items
end

function ShoppingList:ImportTextFormat(text, targetListName)
    if not text or text == "" then
        return false, L["OWSL_MSG_PASTE_TEXT"]
    end

    local items = {}
    local withID = 0

    for line in text:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            local qty, name = line:match("^(%d+)[x%%c3%%97]%s+(.+)$")
            if not qty then
                qty, name = line:match("^x(%d+)%s+(.+)$")
            end

            if qty and name then
                table.insert(items, {
                    quantity = tonumber(qty) or 1,
                    name     = name:match("^%s*(.-)%s*$"),
                    itemID   = nil,
                })
            end
        end
    end

    if #items == 0 then
        return false, L["OWSL_MSG_NO_VALID_ITEMS"]
    end

    local listName = targetListName or string.format(L["OWSL_LABEL_IMPORTED_LIST"], tostring(math.random(100, 999)))
    local db = GetDB().global.shoppingLists
    if not db.lists[listName] then
        local ok, err = self:CreateList(listName)
        if not ok then return false, err end
    end

    local list = self:GetList(listName)
    local nameOnlyCount = 0

    for _, item in ipairs(items) do
        if not list.unresolvedItems then list.unresolvedItems = {} end
        local uid = "unresolved_" .. item.name:gsub("%s+", "_"):lower() .. "_" .. tostring(GetServerTime()) .. math.random(1000, 9999)
        list.unresolvedItems[uid] = {
            itemName  = item.name,
            quantity  = item.quantity,
            addedTime = GetServerTime(),
            notes     = "",
        }
        nameOnlyCount = nameOnlyCount + 1
    end

    ScheduleRefresh()
    return true, #items, nameOnlyCount
end

function ShoppingList:ScanUnresolvedItems(listName)
    local list = self:GetList(listName)
    if not list or not list.unresolvedItems then
        return 0, 0, 0
    end

    local unresolvedCount = 0
    for _ in pairs(list.unresolvedItems) do
        unresolvedCount = unresolvedCount + 1
    end

    if unresolvedCount == 0 then
        return 0, 0, 0
    end

    print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_SCANNING_UNRESOLVED"], unresolvedCount))

    local resolved = 0
    local partial = 0
    local notFound = 0

    for uid, unresolved in pairs(list.unresolvedItems) do
        local name = unresolved.itemName
        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_SCANNING_FOR"], name))

        local itemID = C_Item.GetItemInfoInstant(name)
        if itemID then
            self:AddItemToList(listName, itemID, unresolved.quantity, unresolved.notes)
            list.unresolvedItems[uid] = nil
            resolved = resolved + 1
            print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_EXACT_MATCH"], name, itemID))
        else
            notFound = notFound + 1
        end
    end

    print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_SCAN_COMPLETE"], resolved, partial, notFound))
    ScheduleRefresh()
    return resolved, partial, notFound
end

function ShoppingList:RemoveCompletedItems(listName)
    local list = self:GetList(listName)
    if not list then return 0 end

    local removed = 0
    for itemID, _ in pairs(list.items or {}) do
        local status = self:GetItemStatus(itemID, listName)
        if status and status.status == "green" then
            list.items[itemID] = nil
            if list.baseItems then list.baseItems[itemID] = nil end
            removed = removed + 1
        end
    end

    if removed > 0 then
        ScheduleRefresh()
    end

    return removed
end

function ShoppingList:MoveItem(itemID, fromList, toList)
    local src = self:GetList(fromList)
    if not src then return false, L["OWSL_MSG_MOVE_FAILED_NOT_FOUND"] end

    itemID = tonumber(itemID)
    if not itemID or not src.items[itemID] then
        return false, L["OWSL_MSG_ITEM_NOT_IN_SOURCE"]
    end

    local dst = self:GetList(toList)
    if not dst then return false, L["OWSL_MSG_MOVE_FAILED_NOT_FOUND"] end

    local itemInfo = src.items[itemID]
    local ok, err = self:AddItemToList(toList, itemID, itemInfo.quantity, itemInfo.notes)
    if not ok then return false, string.format(L["OWSL_MSG_MOVE_FAILED"], err or "") end

    src.items[itemID] = nil
    if src.baseItems then src.baseItems[itemID] = nil end

    ScheduleRefresh()
    return true
end

function ShoppingList:InvalidateCraftableCache()
    craftableCache = {}
end

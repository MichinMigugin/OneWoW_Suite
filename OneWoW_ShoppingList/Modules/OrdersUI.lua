local ADDON_NAME, ns = ...
local L = ns.L

ns.OrdersUI = {}
local OrdersUI = ns.OrdersUI

local function GetDB()
    return _G.OneWoW_ShoppingList_DB
end

local function GetOrderDetailsFrame()
    local pf = _G.ProfessionsFrame
    if not pf then return nil end
    local ordersPage = pf.OrdersPage
    if not ordersPage then return nil end
    local orderView = ordersPage.OrderView
    if not orderView then return nil end
    return orderView.OrderDetails
end

local function GetOrderViewFrame()
    local pf = _G.ProfessionsFrame
    if not pf then return nil end
    local ordersPage = pf.OrdersPage
    if not ordersPage then return nil end
    return ordersPage.OrderView
end

local function GetOrdersSchematicForm()
    local details = GetOrderDetailsFrame()
    if not details then return nil end
    return details.SchematicForm
end

local function TryReadOrderIDFromDetails(details)
    if not details then return nil end
    if details.orderID then return details.orderID end
    if details.orderInfo and details.orderInfo.orderID then return details.orderInfo.orderID end
    if details.order and details.order.orderID then return details.order.orderID end
    if details.currentOrder and details.currentOrder.orderID then return details.currentOrder.orderID end
    if details.SchematicForm then
        local sf = details.SchematicForm
        if sf.orderID then return sf.orderID end
        if sf.orderInfo and sf.orderInfo.orderID then return sf.orderInfo.orderID end
        if sf.order and sf.order.orderID then return sf.order.orderID end
        if sf.currentOrder and sf.currentOrder.orderID then return sf.currentOrder.orderID end
    end
    if details.GetOrder then
        local ok, o = pcall(details.GetOrder, details)
        if ok and o and o.orderID then return o.orderID end
    end
    if details.GetOrderInfo then
        local ok, o = pcall(details.GetOrderInfo, details)
        if ok and o and o.orderID then return o.orderID end
    end
    if details.GetOrderID then
        local ok, val = pcall(details.GetOrderID, details)
        if ok and val then return val end
    end
    return nil
end

local function TryReadRecipeIDFromOrdersSchematic()
    local sf = GetOrdersSchematicForm()
    if not sf then return nil end
    if sf.GetRecipeInfo then
        local ok, info = pcall(sf.GetRecipeInfo, sf)
        if ok and info and info.recipeID then return info.recipeID, info end
    end
    if sf.GetRecipeID then
        local ok, id = pcall(sf.GetRecipeID, sf)
        if ok and id then return id, { recipeID = id } end
    end
    return nil
end

local function GetActiveOrDefaultListName()
    local db = GetDB()
    if not db or not db.global or not db.global.shoppingLists then
        return ns.MAIN_LIST_KEY or "Main List"
    end
    return db.global.shoppingLists.defaultList
        or db.global.shoppingLists.activeList
        or ns.MAIN_LIST_KEY
        or "Main List"
end

local function CreateTextButton(parent, width, label)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 30)
    b:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    b:SetBackdropColor(0.14, 0.16, 0.14, 1.0)
    b:SetBackdropBorderColor(0.32, 0.48, 0.35, 0.5)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b.text:SetTextColor(0.88, 0.90, 0.88, 1.0)
    return b
end

local openBtn
local makeListBtn
local addToActiveBtn
local addToListBtn

local function UpdateButtonsState()
    local details = GetOrderDetailsFrame()
    local orderID = TryReadOrderIDFromDetails(details)
    local recipeID = TryReadRecipeIDFromOrdersSchematic()
    local hasOrderOrRecipe = (orderID ~= nil) or (recipeID ~= nil)

    if openBtn then openBtn:SetEnabled(true) end

    for _, b in ipairs({ makeListBtn, addToActiveBtn, addToListBtn }) do
        if b then
            b:SetEnabled(hasOrderOrRecipe)
            b:SetAlpha(hasOrderOrRecipe and 1.0 or 0.5)
        end
    end
end

local function GetCrafterOrderByID(orderID)
    if not orderID or not C_CraftingOrders or not C_CraftingOrders.GetCrafterOrders then return nil end
    local orders = C_CraftingOrders.GetCrafterOrders()
    if not orders then return nil end
    for _, o in ipairs(orders) do
        if o and o.orderID == orderID then
            return o
        end
    end
    return nil
end

local function BuildMissingBasicReagents(orderInfo)
    if not orderInfo or not orderInfo.reagents then return {} end

    local CUSTOMER = (Enum and Enum.CraftingOrderReagentSource and Enum.CraftingOrderReagentSource.Customer) or 1
    local totals = {}

    for _, r in ipairs(orderInfo.reagents) do
        if r and r.isBasicReagent and r.source ~= CUSTOMER then
            local reagentInfo = r.reagentInfo or r.reagent
            local reagent = reagentInfo and reagentInfo.reagent or nil
            local itemID = (reagent and reagent.itemID) or (reagentInfo and reagentInfo.itemID)
            local qty = (reagentInfo and reagentInfo.quantity) or r.quantity

            itemID = tonumber(itemID)
            qty = tonumber(qty)
            if itemID and itemID > 0 and qty and qty > 0 then
                totals[itemID] = (totals[itemID] or 0) + qty
            end
        end
    end

    local out = {}
    for itemID, qty in pairs(totals) do
        table.insert(out, { itemID = itemID, quantity = qty })
    end
    table.sort(out, function(a, b) return a.itemID < b.itemID end)
    return out
end

local function BuildBasicReagentsFromSchematic(recipeID)
    recipeID = tonumber(recipeID)
    if not recipeID then return {} end
    local schematic = C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    if not schematic or not schematic.reagentSlotSchematics then return {} end

    local totals = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if slot and slot.reagentType == Enum.CraftingReagentType.Basic and slot.reagents and #slot.reagents > 0 then
            local reagent = slot.reagents[1]
            local itemID = reagent and reagent.itemID
            local qty = slot.quantityRequired or 0
            itemID = tonumber(itemID)
            qty = tonumber(qty)
            if itemID and itemID > 0 and qty and qty > 0 then
                totals[itemID] = (totals[itemID] or 0) + qty
            end
        end
    end

    local out = {}
    for itemID, qty in pairs(totals) do
        table.insert(out, { itemID = itemID, quantity = qty })
    end
    table.sort(out, function(a, b) return a.itemID < b.itemID end)
    return out
end

local function BuildMissingBasicReagentsFromOrdersUI()
    local sf = GetOrdersSchematicForm()
    if not sf then return {} end

    local reagentsFrame = sf.Reagents
    if not reagentsFrame then return {} end

    local totals = {}

    local function GetCheckmark(frame)
        return frame and (frame.Checkmark or frame.checkmark or frame.CheckMark)
    end

    local function IsProvidedByUI(frame)
        local cm = GetCheckmark(frame)
        if not cm then return false end
        if cm.IsVisible and cm:IsVisible() then return true end
        if cm.IsShown and cm:IsShown() then return true end
        if cm.GetAlpha and (cm:GetAlpha() or 0) > 0.1 then return true end
        return false
    end

    local function FindSlotSchematic(frame)
        if not frame then return nil end

        -- Common direct fields / alternates
        local direct =
            frame.reagentSlotSchematic
            or frame.reagentSlotSchema
            or frame.slotSchematic
            or (frame.Slot and frame.Slot.reagentSlotSchematic)
            or (frame.Slot and frame.Slot.slotSchematic)
            or (frame.slot and frame.slot.reagentSlotSchematic)
            or (frame.slot and frame.slot.slotSchematic)
            or (frame.data and frame.data.reagentSlotSchematic)
            or (frame.data and frame.data.slotSchematic)
        if direct and type(direct) == "table" and direct.reagentType ~= nil then
            return direct
        end

        -- Getter methods sometimes exist on mixins
        for _, fn in ipairs({ "GetSlotSchematic", "GetReagentSlotSchematic", "GetReagentSlot", "GetSchematic" }) do
            if frame[fn] then
                local ok, val = pcall(frame[fn], frame)
                if ok and type(val) == "table" and val.reagentType ~= nil then
                    return val
                end
            end
        end

        -- Search one level down in frame's table keys for a schematic table
        local okPairs = pcall(function()
            for _, v in pairs(frame) do
                if type(v) == "table" then
                    if v.reagentType ~= nil and v.quantityRequired ~= nil and v.reagents ~= nil then
                        return v
                    end
                    if v.reagentSlotSchematic and type(v.reagentSlotSchematic) == "table" and v.reagentSlotSchematic.reagentType ~= nil then
                        return v.reagentSlotSchematic
                    end
                    if v.slotSchematic and type(v.slotSchematic) == "table" and v.slotSchematic.reagentType ~= nil then
                        return v.slotSchematic
                    end
                end
            end
        end)
        if okPairs then
            -- pcall doesn't return the inner return value above, so do a second safe pass
            for _, v in pairs(frame) do
                if type(v) == "table" then
                    if v.reagentType ~= nil and v.quantityRequired ~= nil and v.reagents ~= nil then
                        return v
                    end
                    if v.reagentSlotSchematic and type(v.reagentSlotSchematic) == "table" and v.reagentSlotSchematic.reagentType ~= nil then
                        return v.reagentSlotSchematic
                    end
                    if v.slotSchematic and type(v.slotSchematic) == "table" and v.slotSchematic.reagentType ~= nil then
                        return v.slotSchematic
                    end
                end
            end
        end

        return nil
    end

    local function GetCrafterProvidedQuantityFromUI(frame, requiredQty)
        requiredQty = tonumber(requiredQty) or 0
        if requiredQty <= 0 or not frame or not frame.GetRegions then return nil end

        local foundHave, foundNeed
        local sawAnyText = false
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
                local txt = region:GetText()
                if txt and txt ~= "" then
                    sawAnyText = true
                    local have, need = txt:match("^(%d+)%s*/%s*(%d+)$")
                    if have and need then
                        foundHave = tonumber(have)
                        foundNeed = tonumber(need)
                        break
                    end
                    -- Some UIs include extra text like "2 / 5" or "2/5 (Customer)"
                    have, need = txt:match("(%d+)%s*/%s*(%d+)")
                    if have and need then
                        foundHave = tonumber(have)
                        foundNeed = tonumber(need)
                    end
                end
            end
        end

        if foundNeed and foundNeed > 0 then
            -- Orders UI observation: rows showing "have/need" represent reagents the crafter provides.
            -- Add the full required amount; ShoppingList will handle owned-vs-needed display.
            return foundNeed
        end

        -- Orders UI observation: when a reagent is provided by the customer, the row often
        -- shows only the required quantity (no "have/need" slash count). Treat that as 0 missing.
        if sawAnyText then
            return 0
        end

        return nil
    end

    local function FindDisplayedItemID(frame, slot)
        if not frame then return nil end

        if frame.itemID then
            local id = tonumber(frame.itemID)
            if id and id > 0 then return id end
        end

        for _, fn in ipairs({ "GetItemID", "GetReagentItemID", "GetReagentID" }) do
            if frame[fn] then
                local ok, id = pcall(frame[fn], frame)
                id = tonumber(id)
                if ok and id and id > 0 then return id end
            end
        end

        -- Try common nested tables
        for _, k in ipairs({ "reagent", "reagentInfo", "reagentData", "data", "info" }) do
            local v = frame[k]
            if type(v) == "table" then
                local id = tonumber(v.itemID or (v.reagent and v.reagent.itemID))
                if id and id > 0 then return id end
            end
        end

        -- Parse any item hyperlink present on regions
        if frame.GetRegions then
            for _, region in ipairs({ frame:GetRegions() }) do
                if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
                    local txt = region:GetText()
                    if txt and txt:find("|Hitem:", 1, true) then
                        local id = tonumber(txt:match("|Hitem:(%d+):"))
                        if id and id > 0 then return id end
                    end
                end
            end
        end

        -- Fallback: use the displayed name to resolve an itemID
        local nameFS = frame.Name or frame.name or frame.Label or frame.label
        if nameFS and nameFS.GetText then
            local name = nameFS:GetText()
            if name and name ~= "" then
                -- Strip color codes and leading quantities (e.g. "|cffffffff3 Foo|r" or "1/6 Bar")
                name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                name = name:gsub("^%s*%d+%s*/%s*%d+%s+", ""):gsub("^%s*%d+%s+", "")
                local id = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(name)
                id = tonumber(id)
                if id and id > 0 then return id end
            end
        end

        -- Last resort: use schematic first reagent option
        local reagent = slot and slot.reagents and slot.reagents[1]
        local id = reagent and reagent.itemID
        id = tonumber(id)
        if id and id > 0 then return id end

        return nil
    end

    local function TryConsumeSlotFrame(frame)
        if not frame then return end
        local slot = FindSlotSchematic(frame)
        if not slot or slot.reagentType == nil then return end

        if slot.reagentType ~= Enum.CraftingReagentType.Basic then return end

        -- Best effort: use the row's displayed "have/need" to compute missing.
        -- This works even when orderID/orderInfo isn't exposed.
        local requiredQty = tonumber(slot.quantityRequired) or 0
        local neededQty = GetCrafterProvidedQuantityFromUI(frame, requiredQty)
        if neededQty ~= nil then
            if neededQty <= 0 then return end
        else
            -- If we can't read counts from UI, fall back to source heuristics.
            local CUSTOMER = (Enum and Enum.CraftingOrderReagentSource and Enum.CraftingOrderReagentSource.Customer) or 1
            if slot.orderSource ~= nil then
                if slot.orderSource == CUSTOMER then return end
            else
                if IsProvidedByUI(frame) then return end
            end
            neededQty = requiredQty
        end

        local itemID = FindDisplayedItemID(frame, slot)
        neededQty = tonumber(neededQty)
        if itemID and itemID > 0 and neededQty and neededQty > 0 then
            totals[itemID] = (totals[itemID] or 0) + neededQty
        end
    end

    local visited = setmetatable({}, { __mode = "k" })
    local function Walk(frame, depth)
        if not frame or visited[frame] or depth > 6 then return end
        visited[frame] = true

        TryConsumeSlotFrame(frame)

        if frame.GetLayoutChildren then
            local ok, kids = pcall(frame.GetLayoutChildren, frame)
            if ok and type(kids) == "table" then
                for _, child in ipairs(kids) do
                    Walk(child, depth + 1)
                end
            end
        end

        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                Walk(child, depth + 1)
            end
        end
    end

    Walk(reagentsFrame, 0)

    local out = {}
    for itemID, qty in pairs(totals) do
        table.insert(out, { itemID = itemID, quantity = qty })
    end
    table.sort(out, function(a, b) return a.itemID < b.itemID end)
    return out
end

local function AddMissingToList(listName)
    local details = GetOrderDetailsFrame()
    local orderID = TryReadOrderIDFromDetails(details)
    local reagents
    if orderID then
        local orderInfo = GetCrafterOrderByID(orderID)
        if not orderInfo then
            print((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW|r:") .. " Could not read crafting order details.")
            return
        end
        reagents = BuildMissingBasicReagents(orderInfo)
    else
        local recipeID = TryReadRecipeIDFromOrdersSchematic()
        if not recipeID then
            print((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW|r:") .. " No crafting order selected.")
            return
        end
        reagents = BuildMissingBasicReagentsFromOrdersUI()
        if #reagents == 0 then
            reagents = BuildBasicReagentsFromSchematic(recipeID)
        end
    end

    if #reagents == 0 then
        print((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW|r:") .. " No missing basic reagents for this order.")
        return
    end

    local added = 0
    for _, info in ipairs(reagents) do
        if ns.ShoppingList and ns.ShoppingList.AddItemToList then
            ns.ShoppingList:AddItemToList(listName, info.itemID, info.quantity)
            added = added + 1
        end
    end

    print(string.format((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW|r:") .. " Added %d reagent%s to %s.",
        added, added ~= 1 and "s" or "", tostring(listName)))

    if ns.MainWindow and ns.MainWindow.RefreshSidebar then
        ns.MainWindow:RefreshSidebar()
    end
    if ns.MainWindow and ns.MainWindow.RefreshItemList then
        ns.MainWindow:RefreshItemList()
    end
end

local function MakeNewListAndAddMissing()
    local details = GetOrderDetailsFrame()
    local orderID = TryReadOrderIDFromDetails(details)
    local baseName
    if orderID then
        local orderInfo = GetCrafterOrderByID(orderID)
        if orderInfo then
            local itemID = tonumber(orderInfo.itemID)
            local itemName
            if itemID and itemID > 0 then
                C_Item.RequestLoadItemDataByID(itemID)
                itemName = C_Item.GetItemNameByID(itemID) or C_Item.GetItemInfo(itemID)
            end
            baseName = itemName and ("Order: " .. itemName) or ("Order: " .. tostring(orderID))
        else
            baseName = "Order: " .. tostring(orderID)
        end
    else
        local recipeID, recipeInfo = TryReadRecipeIDFromOrdersSchematic()
        if not recipeID then
            print((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW|r:") .. " No crafting order selected.")
            return
        end
        local recipeName = recipeInfo and recipeInfo.name
        baseName = recipeName and ("Order: " .. recipeName) or ("Order Recipe: " .. tostring(recipeID))
    end

    local listName = baseName

    local allLists = ns.ShoppingList and ns.ShoppingList.GetAllLists and ns.ShoppingList:GetAllLists() or {}
    if allLists[listName] then
        listName = baseName .. " #" .. tostring(math.random(1000, 9999))
    end

    if ns.ShoppingList and ns.ShoppingList.CreateList then
        local ok = ns.ShoppingList:CreateList(listName)
        if not ok then
            print((L and L["ADDON_CHAT_PREFIX"] or "|cFFFFD100OneWoW|r:") .. " Could not create list.")
            return
        end
        ns.ShoppingList:SetActiveList(listName)
    end

    AddMissingToList(listName)
end

local function CreateButtons(details)
    if openBtn then return end

    openBtn = CreateFrame("Button", nil, details, "BackdropTemplate")
    openBtn:SetSize(30, 30)
    openBtn:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", -10, 10)
    openBtn:SetNormalAtlas("Perks-ShoppingCart")
    openBtn:SetPushedAtlas("Perks-ShoppingCart")
    openBtn:SetHighlightAtlas("Perks-ShoppingCart")
    openBtn:GetHighlightTexture():SetAlpha(0.5)
    openBtn:SetScript("OnClick", function()
        if ns.MainWindow then ns.MainWindow:Toggle() end
    end)
    openBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText((L and L["OWSL_TT_OPEN_LIST_TITLE"]) or "Open Shopping List", 1, 1, 1)
        GameTooltip:AddLine((L and L["OWSL_TT_OPEN_LIST_DESC"]) or "Open the Shopping List window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    openBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    makeListBtn = CreateTextButton(details, 90, (L and L["OWSL_PROF_BTN_MAKE_LIST"]) or "Make List")
    makeListBtn:SetPoint("RIGHT", openBtn, "LEFT", -5, 0)
    makeListBtn:SetScript("OnClick", function()
        MakeNewListAndAddMissing()
    end)
    makeListBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText((L and L["OWSL_TT_MAKE_LIST_TITLE"]) or "Make List", 1, 1, 1)
        GameTooltip:AddLine((L and L["OWSL_TT_MAKE_LIST_DESC"]) or "Creates a new list for this order's reagents.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    makeListBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addToActiveBtn = CreateTextButton(details, 130, (L and L["OWSL_PROF_BTN_ADD_TO_ACTIVE"]) or "Add to * List")
    addToActiveBtn:SetPoint("RIGHT", makeListBtn, "LEFT", -5, 0)
    addToActiveBtn:SetScript("OnClick", function()
        AddMissingToList(GetActiveOrDefaultListName())
    end)
    addToActiveBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Add missing reagents", 1, 1, 1)
        GameTooltip:AddLine("Adds missing basic reagents from this crafting order to your active/default shopping list.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addToActiveBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addToListBtn = CreateTextButton(details, 110, (L and L["OWSL_PROF_BTN_ADD_TO_LIST"]) or "Add to List")
    addToListBtn:SetPoint("RIGHT", addToActiveBtn, "LEFT", -5, 0)
    addToListBtn:SetScript("OnClick", function()
        local allLists = ns.ShoppingList and ns.ShoppingList.GetAllLists and ns.ShoppingList:GetAllLists() or {}
        MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle("Add missing reagents to...")
            for listName in pairs(allLists) do
                local capturedName = listName
                rootDescription:CreateButton(listName, function()
                    AddMissingToList(capturedName)
                end)
            end
        end)
    end)
    addToListBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Add missing reagents to list", 1, 1, 1)
        GameTooltip:AddLine("Choose a shopping list to receive missing basic reagents from this crafting order.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addToListBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdateButtonsState()
end

function OrdersUI:HookOrdersPage()
    local details = GetOrderDetailsFrame()
    if not details then return end

    CreateButtons(details)

    for _, fnName in ipairs({ "SetOrder", "SetOrderID", "SetOrderInfo", "Refresh", "UpdateOrder", "SetDisplayedOrder" }) do
        if details[fnName] then
            hooksecurefunc(details, fnName, function()
                C_Timer.After(0, UpdateButtonsState)
            end)
        end
    end

    if details.HookScript then
        details:HookScript("OnShow", function()
            C_Timer.After(0, UpdateButtonsState)
        end)
    end

    local orderView = GetOrderViewFrame()
    if orderView then
        for _, fnName in ipairs({ "SetOrder", "SetOrderID", "SetOrderInfo", "Refresh", "UpdateOrder", "SetDisplayedOrder" }) do
            if orderView[fnName] then
                hooksecurefunc(orderView, fnName, function()
                    C_Timer.After(0, UpdateButtonsState)
                end)
            end
        end
    end
end

function OrdersUI:Initialize()
    if not _G.ProfessionsFrame then
        local hookFrame = CreateFrame("Frame")
        hookFrame:RegisterEvent("ADDON_LOADED")
        hookFrame:SetScript("OnEvent", function(self, event, addon)
            if addon == "Blizzard_Professions" then
                C_Timer.After(0.5, function()
                    OrdersUI:HookOrdersPage()
                end)
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    else
        C_Timer.After(0.5, function()
            OrdersUI:HookOrdersPage()
        end)
    end
end


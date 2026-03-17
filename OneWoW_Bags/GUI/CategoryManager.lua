local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.CategoryManagerUI = {}
local CatMgrUI = OneWoW_Bags.CategoryManagerUI

local managerFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function S(key)
    return OneWoW_GUI:GetSpacing(key)
end

StaticPopupDialogs["ONEWOW_BAGS_CREATE_CATEGORY"] = {
    text = "",
    button1 = OneWoW_Bags.L["POPUP_CREATE"] or "Create",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        self.Text:SetText(OneWoW_Bags.L["CATEGORY_CREATE_ENTER"])
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        if name and name ~= "" then
            local db = OneWoW_Bags.db
            if not db.global.customCategoriesV2 then
                db.global.customCategoriesV2 = {}
            end
            local id = tostring(GetTime()) .. "_" .. name
            local newOrder = 1
            for _, cat in pairs(db.global.customCategoriesV2) do
                if cat.sortOrder and cat.sortOrder >= newOrder then
                    newOrder = cat.sortOrder + 1
                end
            end
            db.global.customCategoriesV2[id] = { name = name, items = {}, enabled = true, sortOrder = newOrder }
            if CatMgrUI.Refresh then CatMgrUI:Refresh() end
            if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                OneWoW_Bags.GUI:RefreshLayout()
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["ONEWOW_BAGS_CREATE_CATEGORY"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ONEWOW_BAGS_RENAME_CATEGORY"] = {
    text = "",
    button1 = OneWoW_Bags.L["POPUP_RENAME"] or "Rename",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    hasEditBox = true,
    OnShow = function(self, data)
        self.Text:SetText(OneWoW_Bags.L["CATEGORY_RENAME_ENTER"])
        if data and OneWoW_Bags.db.global.customCategoriesV2[data] then
            self.EditBox:SetText(OneWoW_Bags.db.global.customCategoriesV2[data].name)
            self.EditBox:HighlightText()
        end
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = self.EditBox:GetText()
        if name and name ~= "" and data then
            local cat = OneWoW_Bags.db.global.customCategoriesV2[data]
            if cat then
                cat.name = name
                if CatMgrUI.Refresh then CatMgrUI:Refresh() end
                if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                    OneWoW_Bags.GUI:RefreshLayout()
                end
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local data = parent.data
        StaticPopupDialogs["ONEWOW_BAGS_RENAME_CATEGORY"].OnAccept(parent, data)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ONEWOW_BAGS_DELETE_CATEGORY"] = {
    text = "",
    button1 = OneWoW_Bags.L["POPUP_DELETE"] or "Delete",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self)
        self.Text:SetText(OneWoW_Bags.L["CATEGORY_DELETE_CONFIRM"])
    end,
    OnAccept = function(self, data)
        if data then
            OneWoW_Bags.db.global.customCategoriesV2[data] = nil
            if CatMgrUI.Refresh then CatMgrUI:Refresh() end
            if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                OneWoW_Bags.GUI:RefreshLayout()
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function CatMgrUI:Refresh()
    if not managerFrame or not managerFrame.scrollContent then return end

    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db
    local scrollContent = managerFrame.scrollContent

    for _, child in ipairs({ scrollContent:GetChildren() }) do
        child:Hide()
        child:SetParent(UIParent)
    end

    local disabled = db.global.disabledCategories or {}
    local customCats = db.global.customCategoriesV2 or {}
    local yOffset = 0

    local BUILTIN_LOCALE_KEYS = {
        ["Recent Items"]    = "CAT_RECENT",
        ["Equipment"]       = "CAT_EQUIPMENT",
        ["Consumables"]     = "CAT_CONSUMABLES",
        ["Reagents"]        = "CAT_REAGENTS",
        ["Trade Goods"]     = "CAT_TRADE_GOODS",
        ["Tradeskill"]      = "CAT_TRADESKILL",
        ["Recipes"]         = "CAT_RECIPES",
        ["Gems"]            = "CAT_GEMS",
        ["Quest Items"]     = "CAT_QUEST",
        ["Cosmetics"]       = "CAT_COSMETICS",
        ["Toys"]            = "CAT_TOYS",
        ["Pets and Mounts"] = "CAT_PETS_MOUNTS",
        ["Keys"]            = "CAT_KEYS",
        ["Junk"]            = "CAT_JUNK",
        ["Other"]           = "CAT_OTHER",
    }

    local BUILTIN_NAMES = {
        "Recent Items", "Equipment", "Consumables", "Reagents", "Trade Goods",
        "Tradeskill", "Recipes", "Gems", "Quest Items", "Cosmetics", "Toys",
        "Pets and Mounts", "Keys", "Junk", "Other",
    }

    local BUILTIN_PRIORITY = {
        ["Recent Items"] = 1,  ["Equipment"] = 2,       ["Consumables"] = 3,
        ["Reagents"] = 4,      ["Trade Goods"] = 5,     ["Tradeskill"] = 6,
        ["Recipes"] = 7,       ["Gems"] = 8,            ["Quest Items"] = 9,
        ["Cosmetics"] = 10,    ["Toys"] = 11,           ["Pets and Mounts"] = 12,
        ["Keys"] = 13,         ["Junk"] = 14,           ["Other"] = 15,
    }

    local allCategories = {}
    for _, name in ipairs(BUILTIN_NAMES) do
        table.insert(allCategories, { name = name, isBuiltin = true })
    end
    for catID, catData in pairs(customCats) do
        table.insert(allCategories, { name = catData.name, isBuiltin = false, id = catID, data = catData })
    end

    local savedOrder = db.global.categoryOrder or {}
    if #savedOrder > 0 then
        local orderMap = {}
        for i, name in ipairs(savedOrder) do orderMap[name] = i end
        table.sort(allCategories, function(a, b)
            local aPos = orderMap[a.name] or 999
            local bPos = orderMap[b.name] or 999
            if aPos ~= bPos then return aPos < bPos end
            return a.name < b.name
        end)
    else
        table.sort(allCategories, function(a, b)
            local aPri = BUILTIN_PRIORITY[a.name] or 50
            local bPri = BUILTIN_PRIORITY[b.name] or 50
            if aPri ~= bPri then return aPri < bPri end
            return a.name < b.name
        end)
    end

    db.global.categoryOrder = {}
    for i, entry in ipairs(allCategories) do
        db.global.categoryOrder[i] = entry.name
    end

    local function MoveItemToCategory(itemID, destCatID)
        for otherID, otherCat in pairs(customCats) do
            if otherID ~= destCatID and otherCat.items then
                otherCat.items[tostring(itemID)] = nil
            end
        end
        local dest = customCats[destCatID]
        if dest then
            if not dest.items then dest.items = {} end
            dest.items[tostring(itemID)] = true
        end
        if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
        CatMgrUI:Refresh()
        if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
            OneWoW_Bags.GUI:RefreshLayout()
        end
    end

    for idx, entry in ipairs(allCategories) do
        local capturedIdx = idx

        local function doMoveUp()
            local tmp = db.global.categoryOrder[capturedIdx]
            db.global.categoryOrder[capturedIdx] = db.global.categoryOrder[capturedIdx - 1]
            db.global.categoryOrder[capturedIdx - 1] = tmp
            CatMgrUI:Refresh()
            if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                OneWoW_Bags.GUI:RefreshLayout()
            end
        end

        local function doMoveDown()
            local tmp = db.global.categoryOrder[capturedIdx]
            db.global.categoryOrder[capturedIdx] = db.global.categoryOrder[capturedIdx + 1]
            db.global.categoryOrder[capturedIdx + 1] = tmp
            CatMgrUI:Refresh()
            if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                OneWoW_Bags.GUI:RefreshLayout()
            end
        end

        if entry.isBuiltin then
            local catName = entry.name
            local locKey = BUILTIN_LOCALE_KEYS[catName]
            local displayName = (locKey and L[locKey]) or catName
            local isDisabled = disabled[catName]

            local row = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
            row:SetHeight(28)
            row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -yOffset)
            row:SetPoint("RIGHT", scrollContent, "RIGHT", 0, 0)
            row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            if isDisabled then
                row:SetBackdropColor(T("BG_SECONDARY"))
            else
                row:SetBackdropColor(T("BG_TERTIARY"))
            end
            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local downBtn = OneWoW_GUI:CreateFitTextButton(row, { text = "Dn", height = 22 })
            downBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            if idx < #allCategories then
                downBtn:SetScript("OnClick", doMoveDown)
            else
                downBtn:Disable()
            end

            local upBtn = OneWoW_GUI:CreateFitTextButton(row, { text = "Up", height = 22 })
            upBtn:SetPoint("RIGHT", downBtn, "LEFT", -4, 0)
            if idx > 1 then
                upBtn:SetScript("OnClick", doMoveUp)
            else
                upBtn:Disable()
            end

            local cb = OneWoW_GUI:CreateCheckbox(row, { label = "" })
            cb:SetSize(22, 22)
            cb:SetPoint("LEFT", row, "LEFT", 4, 0)
            cb:SetChecked(not isDisabled)
            local capturedName = catName
            cb:SetScript("OnClick", function(self)
                if self:GetChecked() then
                    db.global.disabledCategories[capturedName] = nil
                else
                    db.global.disabledCategories[capturedName] = true
                end
                if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
                CatMgrUI:Refresh()
                if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                    OneWoW_Bags.GUI:RefreshLayout()
                end
            end)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            nameText:SetText(displayName)
            if isDisabled then
                nameText:SetTextColor(T("TEXT_MUTED"))
            else
                nameText:SetTextColor(T("TEXT_PRIMARY"))
            end

            if isDisabled then
                local disabledTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                disabledTag:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
                disabledTag:SetText("(" .. (L["DISABLED"]) .. ")")
                disabledTag:SetTextColor(T("TEXT_MUTED"))
            end

            yOffset = yOffset + 30
        else
            local catID = entry.id
            local catData = entry.data
            local capturedID = catID
            local items = catData.items or {}
            local itemCount = 0
            for _ in pairs(items) do itemCount = itemCount + 1 end

            local catFrame = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
            catFrame:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -yOffset)
            catFrame:SetPoint("RIGHT", scrollContent, "RIGHT", 0, 0)
            catFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            catFrame:SetBackdropColor(T("BG_SECONDARY"))
            catFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local header = CreateFrame("Button", nil, catFrame, "BackdropTemplate")
            header:SetHeight(28)
            header:SetPoint("TOPLEFT", catFrame, "TOPLEFT", 0, 0)
            header:SetPoint("TOPRIGHT", catFrame, "TOPRIGHT", 0, 0)
            header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            header:SetBackdropColor(T("BG_TERTIARY"))
            header:EnableMouse(true)
            header:RegisterForDrag("LeftButton")

            header:SetScript("OnEnter", function(self)
                local cursorType = GetCursorInfo()
                if cursorType == "item" then self:SetBackdropColor(T("BG_ACTIVE")) end
            end)
            header:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T("BG_TERTIARY"))
            end)

            header:SetScript("OnReceiveDrag", function(self)
                local cursorType, itemID = GetCursorInfo()
                if cursorType == "item" and itemID then
                    ClearCursor()
                    MoveItemToCategory(itemID, capturedID)
                end
            end)
            header:SetScript("OnMouseUp", function(self, btn)
                if btn == "LeftButton" then
                    local cursorType, itemID = GetCursorInfo()
                    if cursorType == "item" and itemID then
                        ClearCursor()
                        MoveItemToCategory(itemID, capturedID)
                    end
                end
            end)

            local catNameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            catNameText:SetPoint("LEFT", header, "LEFT", 8, 0)
            catNameText:SetText(catData.name)
            catNameText:SetTextColor(T("ACCENT_PRIMARY"))

            local countText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            countText:SetPoint("LEFT", catNameText, "RIGHT", 6, 0)
            countText:SetText(string.format(L["CATEGORY_ITEMS_COUNT"], itemCount))
            countText:SetTextColor(T("TEXT_MUTED"))

            local deleteBtn = OneWoW_GUI:CreateFitTextButton(header, { text = L["CATEGORY_DELETE"], height = 22 })
            deleteBtn:SetPoint("RIGHT", header, "RIGHT", -8, 0)
            deleteBtn:SetScript("OnClick", function()
                StaticPopup_Show("ONEWOW_BAGS_DELETE_CATEGORY", catData.name, nil, capturedID)
            end)

            local renameBtn = OneWoW_GUI:CreateFitTextButton(header, { text = L["CATEGORY_RENAME"], height = 22 })
            renameBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -4, 0)
            renameBtn:SetScript("OnClick", function()
                StaticPopup_Show("ONEWOW_BAGS_RENAME_CATEGORY", catData.name, nil, capturedID)
            end)

            local downBtn = OneWoW_GUI:CreateFitTextButton(header, { text = "Dn", height = 22 })
            downBtn:SetPoint("RIGHT", renameBtn, "LEFT", -4, 0)
            if idx < #allCategories then
                downBtn:SetScript("OnClick", doMoveDown)
            else
                downBtn:Disable()
            end

            local upBtn = OneWoW_GUI:CreateFitTextButton(header, { text = "Up", height = 22 })
            upBtn:SetPoint("RIGHT", downBtn, "LEFT", -4, 0)
            if idx > 1 then
                upBtn:SetScript("OnClick", doMoveUp)
            else
                upBtn:Disable()
            end

            local dropHint = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            dropHint:SetPoint("RIGHT", upBtn, "LEFT", -4, 0)
            dropHint:SetText(L["CATEGORY_DRAG_HINT"])
            dropHint:SetTextColor(T("TEXT_MUTED"))

            local catBodyY = -34
            local catBody = CreateFrame("Frame", nil, catFrame)
            catBody:SetPoint("TOPLEFT", catFrame, "TOPLEFT", 8, catBodyY)
            catBody:SetPoint("RIGHT", catFrame, "RIGHT", -8, 0)

            local addLabel = catBody:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            addLabel:SetPoint("TOPLEFT", catBody, "TOPLEFT", 0, 0)
            addLabel:SetText(L["CATEGORY_ADD_BY_ID"])
            addLabel:SetTextColor(T("TEXT_PRIMARY"))

            local addBox = OneWoW_GUI:CreateEditBox(catBody, { width = 100, height = 22 })
            addBox:SetPoint("LEFT", addLabel, "RIGHT", 6, 0)
            addBox:SetNumeric(true)

            local addBtn = OneWoW_GUI:CreateFitTextButton(catBody, { text = L["ADD_ITEM"], height = 22 })
            addBtn:SetPoint("LEFT", addBox, "RIGHT", 4, 0)
            addBtn:SetScript("OnClick", function()
                local text = addBox.GetSearchText and addBox:GetSearchText() or addBox:GetText()
                local itemID = tonumber(text)
                if itemID and itemID > 0 then
                    addBox:SetText("")
                    MoveItemToCategory(itemID, capturedID)
                end
            end)

            catBodyY = catBodyY - 30

            local itemsList = {}
            for itemIDStr in pairs(items) do
                table.insert(itemsList, tonumber(itemIDStr))
            end

            if #itemsList == 0 then
                local emptyText = catBody:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                emptyText:SetPoint("TOPLEFT", catBody, "TOPLEFT", 0, catBodyY)
                emptyText:SetText(L["CATEGORY_NO_ITEMS"])
                emptyText:SetTextColor(T("TEXT_MUTED"))
                catBodyY = catBodyY - 20
            else
                for _, itemID in ipairs(itemsList) do
                    local itemRow = CreateFrame("Frame", nil, catBody)
                    itemRow:SetPoint("TOPLEFT", catBody, "TOPLEFT", 0, catBodyY)
                    itemRow:SetPoint("RIGHT", catBody, "RIGHT", 0, 0)
                    itemRow:SetHeight(22)

                    local iconFrame = OneWoW_GUI:CreateSkinnedIcon(itemRow, {
                        size = 18,
                        preset = "clean",
                        iconTexture = C_Item.GetItemIconByID(itemID),
                    })
                    iconFrame:SetPoint("LEFT", itemRow, "LEFT", 0, 0)

                    local nameText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    nameText:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
                    local itemName = C_Item.GetItemNameByID(itemID)
                    nameText:SetText(itemName or ("Item " .. itemID))
                    nameText:SetTextColor(T("TEXT_PRIMARY"))

                    local capturedItemID = itemID
                    local capturedCatID = capturedID
                    local removeBtn = OneWoW_GUI:CreateFitTextButton(itemRow, { text = L["REMOVE_ITEM"], height = 18 })
                    removeBtn:SetPoint("RIGHT", itemRow, "RIGHT", 0, 0)
                    removeBtn:SetScript("OnClick", function()
                        local cat = db.global.customCategoriesV2[capturedCatID]
                        if cat and cat.items then
                            cat.items[tostring(capturedItemID)] = nil
                            if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
                            CatMgrUI:Refresh()
                            if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                                OneWoW_Bags.GUI:RefreshLayout()
                            end
                        end
                    end)

                    catBodyY = catBodyY - 24
                end
            end

            local totalHeight = 28 + math.abs(catBodyY) + 8
            catBody:SetHeight(math.abs(catBodyY))
            catFrame:SetHeight(totalHeight)
            yOffset = yOffset + totalHeight + 6
        end
    end

    scrollContent:SetHeight(math.max(yOffset + 10, 100))
end

function CatMgrUI:Show()
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db

    if managerFrame then
        CatMgrUI:Refresh()
        managerFrame:Show()
        managerFrame:Raise()
        return
    end

    local dialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_BagsCatManager",
        title = L["CATEGORY_MANAGER_TITLE"],
        width = 580,
        height = 560,
        strata = "DIALOG",
        movable = true,
        escClose = true,
    })

    managerFrame = dialog.frame

    local createBtn = OneWoW_GUI:CreateFitTextButton(managerFrame, { text = L["CATEGORY_CREATE"], height = 26 })
    createBtn:SetPoint("TOPLEFT", managerFrame, "TOPLEFT", S("SM"), -(S("XS") + 28 + S("SM")))
    createBtn:SetScript("OnClick", function()
        StaticPopup_Show("ONEWOW_BAGS_CREATE_CATEGORY")
    end)

    local infoText = managerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("LEFT", createBtn, "RIGHT", S("SM"), 0)
    infoText:SetPoint("RIGHT", managerFrame, "RIGHT", -S("SM"), 0)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)
    infoText:SetText(L["CATEGORY_MANAGER_INFO"])
    infoText:SetTextColor(T("TEXT_SECONDARY"))

    local contentArea = CreateFrame("Frame", nil, managerFrame)
    contentArea:SetPoint("TOPLEFT", managerFrame, "TOPLEFT", S("XS"), -(S("XS") + 28 + 34 + S("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", managerFrame, "BOTTOMRIGHT", -S("XS"), S("XS"))

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(contentArea, { name = "OneWoW_BagsCatMgrScroll" })
    managerFrame.scrollContent = scrollContent

    CatMgrUI:Refresh()
    managerFrame:Show()
end

function CatMgrUI:Toggle()
    if managerFrame and managerFrame:IsShown() then
        managerFrame:Hide()
    else
        CatMgrUI:Show()
    end
end

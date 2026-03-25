local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.CategoryManagerUI = {}
local CatMgrUI = OneWoW_Bags.CategoryManagerUI

local managerFrame       = nil
local dialogContentFrame = nil
local leftScrollContent  = nil
local rightTopArea       = nil
local rightItemArea      = nil
local rightItemScrollContent = nil
local rightTopWrapper    = nil
local rightItemWrapper   = nil
local leftWrapper        = nil
local selectedCatKey     = nil  -- nil | "builtin:Name" | "section:ID" | customID

local OneWoW_GUI = OneWoW_Bags.GUILib

local BUILTIN_NAMES = {
    "Recent Items", "Hearthstone", "Keystone", "Potions", "Food",
    "Consumables", "Quest Items", "Equipment Sets", "Weapons", "Armor",
    "Reagents", "Trade Goods", "Tradeskill", "Recipes", "Housing",
    "Gems", "Item Enhancement", "Containers", "Keys", "Miscellaneous",
    "Pets and Mounts", "Toys", "Cosmetics", "Other", "Junk",
}

local BUILTIN_LOCALE_KEYS = {
    ["Recent Items"]     = "CAT_RECENT_ITEMS",
    ["Hearthstone"]      = "CAT_HEARTHSTONE",
    ["Keystone"]         = "CAT_KEYSTONE",
    ["Potions"]          = "CAT_POTIONS",
    ["Food"]             = "CAT_FOOD",
    ["Consumables"]      = "CAT_CONSUMABLES",
    ["Quest Items"]      = "CAT_QUEST_ITEMS",
    ["Equipment Sets"]   = "CAT_EQUIPMENT_SETS",
    ["Weapons"]          = "CAT_WEAPONS",
    ["Armor"]            = "CAT_ARMOR",
    ["Reagents"]         = "CAT_REAGENTS",
    ["Trade Goods"]      = "CAT_TRADE_GOODS",
    ["Tradeskill"]       = "CAT_TRADESKILL",
    ["Recipes"]          = "CAT_RECIPES",
    ["Housing"]          = "CAT_HOUSING",
    ["Gems"]             = "CAT_GEMS",
    ["Item Enhancement"] = "CAT_ITEM_ENHANCEMENT",
    ["Containers"]       = "CAT_CONTAINERS",
    ["Keys"]             = "CAT_KEYS",
    ["Miscellaneous"]    = "CAT_MISCELLANEOUS",
    ["Pets and Mounts"]  = "CAT_PETS_AND_MOUNTS",
    ["Toys"]             = "CAT_TOYS",
    ["Cosmetics"]        = "CAT_COSMETICS",
    ["Other"]            = "CAT_OTHER",
    ["Junk"]             = "CAT_JUNK",
}

local BUILTIN_PRIORITY = {
    ["Recent Items"]=1,     ["Hearthstone"]=2,      ["Keystone"]=3,
    ["Potions"]=4,          ["Food"]=5,             ["Consumables"]=6,
    ["Quest Items"]=7,      ["Equipment Sets"]=8,   ["Weapons"]=9,
    ["Armor"]=10,           ["Reagents"]=11,        ["Trade Goods"]=12,
    ["Tradeskill"]=13,      ["Recipes"]=14,         ["Housing"]=15,
    ["Gems"]=16,            ["Item Enhancement"]=17,["Containers"]=18,
    ["Keys"]=19,            ["Miscellaneous"]=20,   ["Pets and Mounts"]=21,
    ["Toys"]=22,            ["Cosmetics"]=23,       ["Other"]=24,
    ["Junk"]=25,
}

local BAGANATOR_CAT_MAP = {
    ["default_auto_recents"]      = "Recent Items",
    ["default_weapon"]            = "Weapons",
    ["default_armor"]             = "Armor",
    ["default_auto_equipment_sets"]= "Equipment Sets",
    ["default_consumable"]        = "Consumables",
    ["default_food"]              = "Food",
    ["default_potion"]            = "Potions",
    ["default_reagent"]           = "Reagents",
    ["default_tradegoods"]        = "Trade Goods",
    ["default_profession"]        = "Tradeskill",
    ["default_recipe"]            = "Recipes",
    ["default_gem"]               = "Gems",
    ["default_questitem"]         = "Quest Items",
    ["default_toy"]               = "Toys",
    ["default_battlepet"]         = "Pets and Mounts",
    ["default_miscellaneous"]     = "Miscellaneous",
    ["default_key"]               = "Keys",
    ["default_keystone"]          = "Keystone",
    ["default_junk"]              = "Junk",
    ["default_other"]             = "Other",
    ["default_housing"]           = "Housing",
    ["default_container"]         = "Containers",
    ["default_itemenhancement"]   = "Item Enhancement",
    ["default_hearthstone"]       = "Hearthstone",
    ["default_special_empty"]     = "Empty",
}

-- ============================================================
-- Helpers
-- ============================================================

local function T(key) return OneWoW_GUI:GetThemeColor(key) end

local function GetDB()
    local db = OneWoW_Bags.db
    if not db.global.categorySections then db.global.categorySections = {} end
    if not db.global.sectionOrder     then db.global.sectionOrder = {} end
    return db
end

local function EnsureDefaultSection()
    local db = GetDB()
    local sections = db.global.categorySections
    local sectOrder = db.global.sectionOrder

    if #sectOrder > 0 then return end

    local defaultCats = {}
    for _, name in ipairs(BUILTIN_NAMES) do
        table.insert(defaultCats, name)
    end

    if #defaultCats == 0 then return end

    local id = "sec_default"
    sections[id] = { name = "Default", categories = defaultCats, collapsed = false }
    table.insert(sectOrder, 1, id)
end

local function ReleaseWrapper(w)
    if w then w:Hide(); w:SetParent(UIParent) end
    return nil
end

local function MakeSmallBtn(parent, label, onClick, active)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(20, 20)
    btn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    if active then
        btn:SetBackdropColor(T("BTN_NORMAL"))
        btn:SetBackdropBorderColor(T("BTN_BORDER"))
        btn:SetScript("OnClick", onClick)
    else
        btn:SetBackdropColor(T("BG_TERTIARY"))
        btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetText(label)
    if active then
        lbl:SetTextColor(T("TEXT_PRIMARY"))
    else
        lbl:SetTextColor(T("TEXT_MUTED"))
    end
    return btn
end

local function MoveItemToCategory(itemID, destCatID)
    local db = GetDB()
    local customCats = db.global.customCategoriesV2 or {}
    for id, cat in pairs(customCats) do
        if id ~= destCatID and cat.items then cat.items[tostring(itemID)] = nil end
    end
    local dest = customCats[destCatID]
    if dest then
        if not dest.items then dest.items = {} end
        dest.items[tostring(itemID)] = true
    end
    if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
    CatMgrUI:Refresh()
    if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then OneWoW_Bags.GUI:RefreshLayout() end
end

local function RefreshBagLayout()
    if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then OneWoW_Bags.GUI:RefreshLayout() end
end

-- ============================================================
-- Static Popups
-- ============================================================

StaticPopupDialogs["ONEWOW_BAGS_CREATE_CATEGORY"] = {
    text = "", hasEditBox = true,
    button1 = OneWoW_Bags.L["POPUP_CREATE"] or "Create",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self)
        self.Text:SetText(OneWoW_Bags.L["CATEGORY_CREATE_ENTER"])
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        if name and name ~= "" then
            local db = GetDB()
            if not db.global.customCategoriesV2 then db.global.customCategoriesV2 = {} end
            local id = "custom_" .. time() .. "_" .. math.random(1000, 9999)
            local order = 1
            for _, c in pairs(db.global.customCategoriesV2) do
                if c.sortOrder and c.sortOrder >= order then order = c.sortOrder + 1 end
            end
            db.global.customCategoriesV2[id] = { name=name, items={}, enabled=true, sortOrder=order }
            selectedCatKey = id
            if CatMgrUI.Refresh then CatMgrUI:Refresh() end
            RefreshBagLayout()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        StaticPopupDialogs["ONEWOW_BAGS_CREATE_CATEGORY"].OnAccept(p)
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
}

StaticPopupDialogs["ONEWOW_BAGS_RENAME_CATEGORY"] = {
    text = "", hasEditBox = true,
    button1 = OneWoW_Bags.L["POPUP_RENAME"] or "Rename",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self, data)
        self.Text:SetText(OneWoW_Bags.L["CATEGORY_RENAME_ENTER"])
        local cat = data and OneWoW_Bags.db.global.customCategoriesV2[data]
        if cat then self.EditBox:SetText(cat.name); self.EditBox:HighlightText() end
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = self.EditBox:GetText()
        if name and name ~= "" and data then
            local cat = OneWoW_Bags.db.global.customCategoriesV2[data]
            if cat then
                cat.name = name
                if CatMgrUI.Refresh then CatMgrUI:Refresh() end
                RefreshBagLayout()
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        StaticPopupDialogs["ONEWOW_BAGS_RENAME_CATEGORY"].OnAccept(p, p.data)
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
}

StaticPopupDialogs["ONEWOW_BAGS_DELETE_CATEGORY"] = {
    text = "",
    button1 = OneWoW_Bags.L["POPUP_DELETE"] or "Delete",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self) self.Text:SetText(OneWoW_Bags.L["CATEGORY_DELETE_CONFIRM"]) end,
    OnAccept = function(self, data)
        if data then
            OneWoW_Bags.db.global.customCategoriesV2[data] = nil
            if selectedCatKey == data then selectedCatKey = nil end
            if CatMgrUI.Refresh then CatMgrUI:Refresh() end
            RefreshBagLayout()
        end
    end,
    timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
}

StaticPopupDialogs["ONEWOW_BAGS_CREATE_SECTION"] = {
    text = "", hasEditBox = true,
    button1 = OneWoW_Bags.L["POPUP_CREATE"] or "Create",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self)
        self.Text:SetText(OneWoW_Bags.L["SECTION_CREATE_ENTER"] or "Enter section name:")
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        if name and name ~= "" then
            local db = GetDB()
            local id = "sec_" .. time() .. "_" .. math.random(1000, 9999)
            db.global.categorySections[id] = { name=name, categories={}, collapsed=false }
            table.insert(db.global.sectionOrder, id)
            selectedCatKey = "section:" .. id
            if CatMgrUI.Refresh then CatMgrUI:Refresh() end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        StaticPopupDialogs["ONEWOW_BAGS_CREATE_SECTION"].OnAccept(p)
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
}

StaticPopupDialogs["ONEWOW_BAGS_RENAME_SECTION"] = {
    text = "", hasEditBox = true,
    button1 = OneWoW_Bags.L["POPUP_RENAME"] or "Rename",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self, data)
        self.Text:SetText(OneWoW_Bags.L["SECTION_RENAME_ENTER"] or "Enter new section name:")
        local db = GetDB()
        local sec = data and db.global.categorySections[data]
        if sec then self.EditBox:SetText(sec.name); self.EditBox:HighlightText() end
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = self.EditBox:GetText()
        if name and name ~= "" and data then
            local sec = GetDB().global.categorySections[data]
            if sec then
                sec.name = name
                if CatMgrUI.Refresh then CatMgrUI:Refresh() end
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        StaticPopupDialogs["ONEWOW_BAGS_RENAME_SECTION"].OnAccept(p, p.data)
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
}

StaticPopupDialogs["ONEWOW_BAGS_DELETE_SECTION"] = {
    text = "",
    button1 = OneWoW_Bags.L["POPUP_DELETE"] or "Delete",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self) self.Text:SetText(OneWoW_Bags.L["SECTION_DELETE_CONFIRM"] or "Delete this section? Categories will remain ungrouped.") end,
    OnAccept = function(self, data)
        if data then
            local db = GetDB()
            db.global.categorySections[data] = nil
            for i, sid in ipairs(db.global.sectionOrder) do
                if sid == data then table.remove(db.global.sectionOrder, i); break end
            end
            if selectedCatKey == ("section:" .. data) then selectedCatKey = nil end
            if CatMgrUI.Refresh then CatMgrUI:Refresh() end
        end
    end,
    timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
}

-- ============================================================
-- Baganator Import
-- ============================================================

local function ImportFromBaganator()
    if not _G.BAGANATOR_CONFIG then return 0, 0 end
    local db = GetDB()
    if not db.global.customCategoriesV2 then db.global.customCategoriesV2 = {} end

    local importedCats = 0
    local importedSecs = 0

    local profiles = _G.BAGANATOR_CONFIG.Profiles
    if not profiles then return 0, 0 end

    -- Process only the first non-empty profile (DEFAULT usually)
    local profile
    for _, p in pairs(profiles) do profile = p; break end
    if not profile then return 0, 0 end

    -- Import custom categories (item-assignment categories)
    local customCats = profile.custom_categories
    if customCats then
        for _, catData in pairs(customCats) do
            local name = catData.name
            if name and name ~= "" then
                local exists = false
                for _, ex in pairs(db.global.customCategoriesV2) do
                    if ex.name == name then exists = true; break end
                end
                if not exists then
                    local newID = "custom_" .. time() .. "_" .. math.random(1000, 9999)
                    local items = {}
                    if catData.items then
                        if catData.items[1] ~= nil then
                            for _, id in ipairs(catData.items) do
                                if tonumber(id) then items[tostring(id)] = true end
                            end
                        else
                            for k in pairs(catData.items) do
                                if tonumber(k) then items[tostring(k)] = true end
                            end
                        end
                    end
                    if catData.rules then
                        for _, rule in ipairs(catData.rules) do
                            if rule.type == "item" and rule.itemID then
                                items[tostring(rule.itemID)] = true
                            end
                        end
                    end
                    local order = 1
                    for _, c in pairs(db.global.customCategoriesV2) do
                        if c.sortOrder and c.sortOrder >= order then order = c.sortOrder + 1 end
                    end
                    db.global.customCategoriesV2[newID] = { name=name, items=items, enabled=true, sortOrder=order }
                    importedCats = importedCats + 1
                end
            end
        end
    end

    -- Import category sections
    local bagSections = profile.category_sections  -- { ["1"]={name="EQUIPMENT"}, ["2"]={name="CRAFTING"}, ... }
    local displayOrder = profile.category_display_order

    if bagSections and displayOrder then
        -- Build a map: bagSectionIndex -> our new sectionID
        local sectionIDMap = {}
        for bagIdx, secData in pairs(bagSections) do
            local secName = secData.name
            if secName and secName ~= "" then
                -- Check not already imported
                local exists = false
                for _, sec in pairs(db.global.categorySections) do
                    if sec.name == secName then exists = true; break end
                end
                if not exists then
                    local newID = "sec_" .. time() .. "_" .. math.random(1000, 9999)
                    db.global.categorySections[newID] = { name=secName, categories={}, collapsed=false }
                    table.insert(db.global.sectionOrder, newID)
                    sectionIDMap[bagIdx] = newID
                    importedSecs = importedSecs + 1
                end
            end
        end

        -- Walk displayOrder and assign categories to sections
        local currentSectionID = nil
        local addedToSection = {}  -- prevent duplicates within a section

        for _, entry in ipairs(displayOrder) do
            if entry:sub(1, 1) == "_" and entry ~= "----" then
                if entry == "__end" then
                    currentSectionID = nil
                    wipe(addedToSection)
                else
                    -- Section start: "_1", "_2", "_3" etc.
                    local bagIdx = entry:sub(2)
                    currentSectionID = sectionIDMap[bagIdx]
                end
            elseif entry ~= "----" and currentSectionID then
                local ourCatName = BAGANATOR_CAT_MAP[entry]
                if ourCatName and not addedToSection[ourCatName] then
                    local sec = db.global.categorySections[currentSectionID]
                    if sec then
                        table.insert(sec.categories, ourCatName)
                        addedToSection[ourCatName] = true
                    end
                end
            end
        end
    end

    return importedCats, importedSecs
end

-- ============================================================
-- Right Panel
-- ============================================================

function CatMgrUI:RefreshRight()
    rightTopWrapper  = ReleaseWrapper(rightTopWrapper)
    rightItemWrapper = ReleaseWrapper(rightItemWrapper)
    if not rightTopArea or not rightItemArea then return end

    local L = OneWoW_Bags.L
    local db = GetDB()

    -- ---- Nothing selected ----
    if not selectedCatKey then
        rightTopArea:SetHeight(80)
        rightItemArea:Hide()
        rightTopWrapper = CreateFrame("Frame", nil, rightTopArea)
        rightTopWrapper:SetAllPoints()
        local hint = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hint:SetPoint("CENTER")
        hint:SetText(L["CATEGORY_SELECT_PROMPT"])
        hint:SetTextColor(T("TEXT_MUTED"))
        return
    end

    -- ---- Section selected ----
    if selectedCatKey:sub(1, 8) == "section:" then
        local sectionID = selectedCatKey:sub(9)
        local section   = db.global.categorySections[sectionID]
        if not section then selectedCatKey = nil; self:RefreshRight(); return end

        rightTopArea:SetHeight(84)
        rightItemArea:Show()

        rightTopWrapper = CreateFrame("Frame", nil, rightTopArea)
        rightTopWrapper:SetAllPoints()

        local header = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, -10)
        header:SetText(section.name)
        header:SetTextColor(T("ACCENT_PRIMARY"))

        local captID = sectionID
        local delBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["CATEGORY_DELETE"], height=22 })
        delBtn:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -6, -10)
        delBtn:SetScript("OnClick", function()
            StaticPopup_Show("ONEWOW_BAGS_DELETE_SECTION", section.name, nil, captID)
        end)
        local renBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["CATEGORY_RENAME"], height=22 })
        renBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
        renBtn:SetScript("OnClick", function()
            StaticPopup_Show("ONEWOW_BAGS_RENAME_SECTION", section.name, nil, captID)
        end)

        local div = rightTopWrapper:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, -36)
        div:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, -36)
        div:SetColorTexture(T("BORDER_SUBTLE"))

        local showHeaderCB = CreateFrame("CheckButton", nil, rightTopWrapper, "UICheckButtonTemplate")
        showHeaderCB:SetSize(18, 18)
        showHeaderCB:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 8, -42)
        showHeaderCB:SetChecked(section.showHeader or false)
        local captSection = section
        showHeaderCB:SetScript("OnClick", function(self)
            captSection.showHeader = self:GetChecked() or false
            RefreshBagLayout()
        end)
        local showHeaderLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        showHeaderLbl:SetPoint("LEFT", showHeaderCB, "RIGHT", 4, 0)
        showHeaderLbl:SetText(L["SECTION_SHOW_HEADER"] or "Show section header in bags")
        showHeaderLbl:SetTextColor(T("TEXT_PRIMARY"))

        local infoLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, -66)
        infoLbl:SetText(L["CATEGORY_IN_SECTION"] or "Toggle categories to include in this section:")
        infoLbl:SetTextColor(T("TEXT_SECONDARY"))

        local allCatNames = {}
        for _, n in ipairs(BUILTIN_NAMES) do table.insert(allCatNames, n) end
        for _, cd in pairs(db.global.customCategoriesV2 or {}) do table.insert(allCatNames, cd.name) end

        local memberSet = {}
        for _, n in ipairs(section.categories) do memberSet[n] = true end

        rightItemWrapper = CreateFrame("Frame", nil, rightItemScrollContent)
        rightItemWrapper:SetPoint("TOPLEFT", rightItemScrollContent, "TOPLEFT", 2, 0)
        rightItemWrapper:SetPoint("RIGHT",   rightItemScrollContent, "RIGHT", -2, 0)

        local checkY = 0
        for _, catName in ipairs(allCatNames) do
            local locKey   = BUILTIN_LOCALE_KEYS[catName]
            local dispName = (locKey and L[locKey]) or catName
            local isMember = memberSet[catName]

            local row = CreateFrame("Frame", nil, rightItemWrapper)
            row:SetHeight(22)
            row:SetPoint("TOPLEFT", rightItemWrapper, "TOPLEFT", 0, checkY)
            row:SetPoint("RIGHT",   rightItemWrapper, "RIGHT",   0, 0)

            local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            cb:SetSize(18, 18)
            cb:SetPoint("LEFT", row, "LEFT", 4, 0)
            cb:SetChecked(isMember)

            local cbLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cbLbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            cbLbl:SetText(dispName)
            cbLbl:SetTextColor(T("TEXT_PRIMARY"))

            local captCat = catName
            local captSec = section
            cb:SetScript("OnClick", function(self)
                if self:GetChecked() then
                    if not memberSet[captCat] then
                        table.insert(captSec.categories, captCat)
                        memberSet[captCat] = true
                    end
                else
                    for i, n in ipairs(captSec.categories) do
                        if n == captCat then table.remove(captSec.categories, i); break end
                    end
                    memberSet[captCat] = nil
                end
                CatMgrUI:RefreshLeft()
            end)

            checkY = checkY - 24
        end

        local totalH = math.max(math.abs(checkY) + 4, 40)
        rightItemWrapper:SetHeight(totalH)
        rightItemScrollContent:SetHeight(totalH)
        return
    end

    -- ---- Built-in category selected ----
    if selectedCatKey:sub(1, 8) == "builtin:" then
        local catName  = selectedCatKey:sub(9)
        local locKey   = BUILTIN_LOCALE_KEYS[catName]
        local dispName = (locKey and L[locKey]) or catName

        rightTopArea:SetHeight(120)
        rightItemArea:Hide()
        rightTopWrapper = CreateFrame("Frame", nil, rightTopArea)
        rightTopWrapper:SetAllPoints()

        local header = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, -10)
        header:SetText(dispName)
        header:SetTextColor(T("ACCENT_PRIMARY"))

        local div = rightTopWrapper:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, -36)
        div:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, -36)
        div:SetColorTexture(T("BORDER_SUBTLE"))

        local desc = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, -44)
        desc:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -10, -44)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetText(L["CATEGORY_BUILTIN_DESC"])
        desc:SetTextColor(T("TEXT_SECONDARY"))
        return
    end

    -- ---- Custom category selected ----
    local catID   = selectedCatKey
    local customCats = db.global.customCategoriesV2 or {}
    local catData = customCats[catID]
    if not catData then selectedCatKey = nil; self:RefreshRight(); return end

    local capturedID = catID
    rightTopArea:SetHeight(158)
    rightItemArea:Show()

    rightTopWrapper = CreateFrame("Frame", nil, rightTopArea)
    rightTopWrapper:SetAllPoints()

    local header = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, -10)
    header:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -160, -10)
    header:SetJustifyH("LEFT")
    header:SetText(catData.name)
    header:SetTextColor(T("ACCENT_PRIMARY"))

    local delBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["CATEGORY_DELETE"], height=22 })
    delBtn:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -6, -10)
    delBtn:SetScript("OnClick", function()
        StaticPopup_Show("ONEWOW_BAGS_DELETE_CATEGORY", catData.name, nil, capturedID)
    end)
    local renBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["CATEGORY_RENAME"], height=22 })
    renBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
    renBtn:SetScript("OnClick", function()
        StaticPopup_Show("ONEWOW_BAGS_RENAME_CATEGORY", catData.name, nil, capturedID)
    end)

    local div1 = rightTopWrapper:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, -36)
    div1:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, -36)
    div1:SetColorTexture(T("BORDER_SUBTLE"))

    -- Drop zone
    local dropZone = CreateFrame("Button", nil, rightTopWrapper, "BackdropTemplate")
    dropZone:SetHeight(32)
    dropZone:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, -44)
    dropZone:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, -44)
    dropZone:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    dropZone:SetBackdropColor(T("BG_TERTIARY"))
    dropZone:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    dropZone:EnableMouse(true)
    dropZone:RegisterForDrag("LeftButton")

    local dropTxt = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropTxt:SetPoint("CENTER")
    dropTxt:SetText(L["CATEGORY_DRAG_HINT"])
    dropTxt:SetTextColor(T("TEXT_MUTED"))

    dropZone:SetScript("OnEnter", function()
        if GetCursorInfo() == "item" then
            dropZone:SetBackdropColor(T("BG_ACTIVE"))
            dropTxt:SetTextColor(T("ACCENT_PRIMARY"))
        end
    end)
    dropZone:SetScript("OnLeave", function()
        dropZone:SetBackdropColor(T("BG_TERTIARY"))
        dropTxt:SetTextColor(T("TEXT_MUTED"))
    end)
    local function handleDrop()
        local cType, itemID = GetCursorInfo()
        if cType == "item" and itemID then ClearCursor(); MoveItemToCategory(itemID, capturedID) end
    end
    dropZone:SetScript("OnReceiveDrag", handleDrop)
    dropZone:SetScript("OnMouseUp", function(_, btn) if btn == "LeftButton" then handleDrop() end end)

    -- Add by ID
    local addLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 8, -84)
    addLbl:SetText(L["CATEGORY_ADD_BY_ID"])
    addLbl:SetTextColor(T("TEXT_PRIMARY"))

    local addBox = OneWoW_GUI:CreateEditBox(rightTopWrapper, { width=100, height=22 })
    addBox:SetPoint("LEFT", addLbl, "RIGHT", 8, 0)
    addBox:SetNumeric(true)

    local addBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["ADD_ITEM"], height=22 })
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
    addBtn:SetScript("OnClick", function()
        local text = addBox.GetSearchText and addBox:GetSearchText() or addBox:GetText()
        local id = tonumber(text)
        if id and id > 0 then addBox:SetText(""); MoveItemToCategory(id, capturedID) end
    end)

    -- Item count label
    local items = catData.items or {}
    local itemCount = 0
    for _ in pairs(items) do itemCount = itemCount + 1 end

    local countLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 8, -120)
    countLbl:SetText(string.format(L["CATEGORY_ITEMS_COUNT"], itemCount))
    countLbl:SetTextColor(T("TEXT_SECONDARY"))

    -- Item list
    local itemsList = {}
    for idStr in pairs(items) do table.insert(itemsList, tonumber(idStr)) end
    table.sort(itemsList)

    rightItemWrapper = CreateFrame("Frame", nil, rightItemScrollContent)
    rightItemWrapper:SetPoint("TOPLEFT", rightItemScrollContent, "TOPLEFT", 2, 0)
    rightItemWrapper:SetPoint("RIGHT",   rightItemScrollContent, "RIGHT", -2, 0)

    local itemY = 0
    if #itemsList == 0 then
        local emptyLbl = rightItemWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyLbl:SetPoint("TOPLEFT", rightItemWrapper, "TOPLEFT", 8, -8)
        emptyLbl:SetText(L["CATEGORY_NO_ITEMS"])
        emptyLbl:SetTextColor(T("TEXT_MUTED"))
        itemY = -28
    else
        for _, itemID in ipairs(itemsList) do
            local row = CreateFrame("Frame", nil, rightItemWrapper, "BackdropTemplate")
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", rightItemWrapper, "TOPLEFT", 0, itemY)
            row:SetPoint("RIGHT",   rightItemWrapper, "RIGHT",   0, 0)
            row:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
            row:SetBackdropColor(T("BG_SECONDARY"))
            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            local tex = C_Item.GetItemIconByID(itemID)
            if tex then icon:SetTexture(tex) end

            local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameTxt:SetPoint("LEFT",  icon, "RIGHT", 6, 0)
            nameTxt:SetPoint("RIGHT", row,  "RIGHT", -72, 0)
            nameTxt:SetJustifyH("LEFT")
            nameTxt:SetText(C_Item.GetItemNameByID(itemID) or ("Item " .. itemID))
            nameTxt:SetTextColor(T("TEXT_PRIMARY"))

            local captItemID = itemID
            local captCatID  = capturedID
            local remBtn = OneWoW_GUI:CreateFitTextButton(row, { text=L["REMOVE_ITEM"], height=18 })
            remBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            remBtn:SetScript("OnClick", function()
                local cat = db.global.customCategoriesV2[captCatID]
                if cat and cat.items then
                    cat.items[tostring(captItemID)] = nil
                    if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
                    CatMgrUI:Refresh()
                    RefreshBagLayout()
                end
            end)
            itemY = itemY - 28
        end
    end

    local itemsH = math.max(math.abs(itemY) + 4, 40)
    rightItemWrapper:SetHeight(itemsH)
    rightItemScrollContent:SetHeight(itemsH)
end

-- ============================================================
-- Left Panel
-- ============================================================

function CatMgrUI:RefreshLeft()
    leftWrapper = ReleaseWrapper(leftWrapper)
    if not leftScrollContent then return end

    local L  = OneWoW_Bags.L
    local db = GetDB()
    local disabled   = db.global.disabledCategories or {}
    local sections   = db.global.categorySections
    local sectOrder  = db.global.sectionOrder
    local customCats = db.global.customCategoriesV2 or {}

    leftWrapper = CreateFrame("Frame", nil, leftScrollContent)
    leftWrapper:SetPoint("TOPLEFT", leftScrollContent, "TOPLEFT", 0, 0)
    leftWrapper:SetPoint("RIGHT",   leftScrollContent, "RIGHT",   0, 0)

    local yOffset = 0

    -- Determine which categories are inside a section
    local inSection = {}
    for _, sec in pairs(sections) do
        for _, nm in ipairs(sec.categories or {}) do inSection[nm] = true end
    end

    -- Build root category list (not in any section)
    local rootCats = {}
    for _, name in ipairs(BUILTIN_NAMES) do
        if not inSection[name] then
            table.insert(rootCats, { name=name, isBuiltin=true, key="builtin:"..name })
        end
    end
    for catID, catData in pairs(customCats) do
        if not inSection[catData.name] then
            table.insert(rootCats, { name=catData.name, isBuiltin=false, id=catID, data=catData, key=catID })
        end
    end

    local savedOrder = db.global.categoryOrder or {}
    if #savedOrder > 0 then
        local orderMap = {}
        for i, name in ipairs(savedOrder) do orderMap[name] = i end
        table.sort(rootCats, function(a, b)
            local aP = orderMap[a.name] or 999
            local bP = orderMap[b.name] or 999
            if aP ~= bP then return aP < bP end
            return a.name < b.name
        end)
    else
        table.sort(rootCats, function(a, b)
            local aP = BUILTIN_PRIORITY[a.name] or 50
            local bP = BUILTIN_PRIORITY[b.name] or 50
            if aP ~= bP then return aP < bP end
            return a.name < b.name
        end)
    end

    -- Update categoryOrder from root cats
    db.global.categoryOrder = {}
    for i, e in ipairs(rootCats) do db.global.categoryOrder[i] = e.name end

    -- Helper: render one category row
    local function RenderCatRow(entry, idxInGroup, totalInGroup, indent)
        indent = indent or 0
        local isSelected = (selectedCatKey == entry.key)

        local row = CreateFrame("Button", nil, leftWrapper, "BackdropTemplate")
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", indent, -yOffset)
        row:SetPoint("RIGHT",   leftWrapper, "RIGHT",   0, 0)
        row:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })

        if isSelected then
            row:SetBackdropColor(T("BG_ACTIVE"))
            row:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
        elseif entry.isBuiltin then
            row:SetBackdropColor(T("BG_TERTIARY"))
            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        else
            row:SetBackdropColor(T("BG_SECONDARY"))
            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end

        local captKey = entry.key
        row:SetScript("OnClick", function()
            selectedCatKey = captKey
            CatMgrUI:Refresh()
        end)

        -- Up / Down
        local function doUp()
            if idxInGroup > 1 then
                local ord = db.global.categoryOrder
                local tmp = ord[idxInGroup]; ord[idxInGroup] = ord[idxInGroup-1]; ord[idxInGroup-1] = tmp
                CatMgrUI:Refresh(); RefreshBagLayout()
            end
        end
        local function doDown()
            if idxInGroup < totalInGroup then
                local ord = db.global.categoryOrder
                local tmp = ord[idxInGroup]; ord[idxInGroup] = ord[idxInGroup+1]; ord[idxInGroup+1] = tmp
                CatMgrUI:Refresh(); RefreshBagLayout()
            end
        end
        local dnB = MakeSmallBtn(row, "v", doDown, idxInGroup < totalInGroup)
        dnB:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        local upB = MakeSmallBtn(row, "^", doUp, idxInGroup > 1)
        upB:SetPoint("RIGHT", dnB, "LEFT", -2, 0)

        if entry.isBuiltin then
            local catName   = entry.name
            local isDisabled = disabled[catName]
            local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            cb:SetSize(18, 18)
            cb:SetPoint("LEFT", row, "LEFT", 4, 0)
            cb:SetChecked(not isDisabled)
            local capN = catName
            cb:SetScript("OnClick", function(self)
                if self:GetChecked() then
                    db.global.disabledCategories[capN] = nil
                else
                    db.global.disabledCategories[capN] = true
                end
                if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
                CatMgrUI:Refresh(); RefreshBagLayout()
            end)
            local locKey   = BUILTIN_LOCALE_KEYS[catName]
            local nameTxt  = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameTxt:SetPoint("LEFT",  cb,  "RIGHT", 3, 0)
            nameTxt:SetPoint("RIGHT", upB, "LEFT",  -4, 0)
            nameTxt:SetJustifyH("LEFT")
            nameTxt:SetText((locKey and L[locKey]) or catName)
            if isDisabled then
                nameTxt:SetTextColor(T("TEXT_MUTED"))
            elseif isSelected then
                nameTxt:SetTextColor(T("ACCENT_PRIMARY"))
            else
                nameTxt:SetTextColor(T("TEXT_PRIMARY"))
            end
        else
            local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameTxt:SetPoint("LEFT",  row, "LEFT",  8, 0)
            nameTxt:SetPoint("RIGHT", upB, "LEFT", -4, 0)
            nameTxt:SetJustifyH("LEFT")
            nameTxt:SetText(entry.data.name)
            if isSelected then
                nameTxt:SetTextColor(T("ACCENT_PRIMARY"))
            else
                nameTxt:SetTextColor(T("TEXT_PRIMARY"))
            end
        end

        yOffset = yOffset + 30
    end

    -- Render root categories
    for i, entry in ipairs(rootCats) do
        RenderCatRow(entry, i, #rootCats, 0)
    end

    -- Render sections
    local totalSections = #sectOrder
    for secIdx, sectionID in ipairs(sectOrder) do
        local section = sections[sectionID]
        if section then
            local sKey      = "section:" .. sectionID
            local isSelSec  = (selectedCatKey == sKey)
            local collapsed = section.collapsed

            -- Section header
            local secRow = CreateFrame("Button", nil, leftWrapper, "BackdropTemplate")
            secRow:SetHeight(28)
            secRow:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", 0, -yOffset)
            secRow:SetPoint("RIGHT",   leftWrapper, "RIGHT",   0, 0)
            secRow:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })

            if isSelSec then
                secRow:SetBackdropColor(T("BG_ACTIVE"))
                secRow:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            else
                secRow:SetBackdropColor(T("BG_PRIMARY"))
                secRow:SetBackdropBorderColor(T("BORDER_DEFAULT"))
            end

            -- Section up/down (reorders among sections only)
            local captSecIdx = secIdx
            local dnSec = MakeSmallBtn(secRow, "v", function()
                if captSecIdx < totalSections then
                    local t = sectOrder[captSecIdx]; sectOrder[captSecIdx] = sectOrder[captSecIdx+1]; sectOrder[captSecIdx+1] = t
                    CatMgrUI:Refresh()
                end
            end, secIdx < totalSections)
            dnSec:SetPoint("RIGHT", secRow, "RIGHT", -2, 0)

            local upSec = MakeSmallBtn(secRow, "^", function()
                if captSecIdx > 1 then
                    local t = sectOrder[captSecIdx]; sectOrder[captSecIdx] = sectOrder[captSecIdx-1]; sectOrder[captSecIdx-1] = t
                    CatMgrUI:Refresh()
                end
            end, secIdx > 1)
            upSec:SetPoint("RIGHT", dnSec, "LEFT", -2, 0)

            local arrow = secRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            arrow:SetPoint("LEFT", secRow, "LEFT", 4, 0)
            if collapsed then
                arrow:SetText(">")
            else
                arrow:SetText("v")
            end
            arrow:SetTextColor(T("ACCENT_SECONDARY"))

            local secName = secRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            secName:SetPoint("LEFT",  secRow, "LEFT",  18, 0)
            secName:SetPoint("RIGHT", upSec,  "LEFT",  -4, 0)
            secName:SetJustifyH("LEFT")
            secName:SetText(section.name)
            if isSelSec then
                secName:SetTextColor(T("ACCENT_PRIMARY"))
            else
                secName:SetTextColor(T("TEXT_PRIMARY"))
            end

            local captSKey = sKey
            secRow:SetScript("OnClick", function()
                section.collapsed = not section.collapsed
                selectedCatKey = captSKey
                CatMgrUI:Refresh()
            end)
            yOffset = yOffset + 30

            -- Member categories (indented)
            if not collapsed then
                local cats = section.categories or {}
                for catIdx, catName in ipairs(cats) do
                    local isBuiltin = BUILTIN_PRIORITY[catName] ~= nil
                    local catData, catID = nil, nil
                    if not isBuiltin then
                        for id, data in pairs(customCats) do
                            if data.name == catName then catData = data; catID = id; break end
                        end
                    end
                    local entry = {
                        name = catName, isBuiltin = isBuiltin,
                        id = catID, data = catData,
                        key = isBuiltin and ("builtin:" .. catName) or catID,
                    }
                    if entry.key then
                        -- Section-internal up/down uses section.categories array
                        local captIdx = catIdx
                        local captCats = cats
                        local isSelCat = (selectedCatKey == entry.key)

                        local row = CreateFrame("Button", nil, leftWrapper, "BackdropTemplate")
                        row:SetHeight(26)
                        row:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", 16, -yOffset)
                        row:SetPoint("RIGHT",   leftWrapper, "RIGHT",    0, 0)
                        row:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
                        if isSelCat then
                            row:SetBackdropColor(T("BG_ACTIVE"))
                            row:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                        elseif isBuiltin then
                            row:SetBackdropColor(T("BG_TERTIARY"))
                            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                        else
                            row:SetBackdropColor(T("BG_SECONDARY"))
                            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                        end
                        local captEKey = entry.key
                        row:SetScript("OnClick", function()
                            selectedCatKey = captEKey
                            CatMgrUI:Refresh()
                        end)

                        local dnB2 = MakeSmallBtn(row, "v", function()
                            if captIdx < #captCats then
                                local t = captCats[captIdx]; captCats[captIdx] = captCats[captIdx+1]; captCats[captIdx+1] = t
                                CatMgrUI:Refresh()
                            end
                        end, catIdx < #cats)
                        dnB2:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                        local upB2 = MakeSmallBtn(row, "^", function()
                            if captIdx > 1 then
                                local t = captCats[captIdx]; captCats[captIdx] = captCats[captIdx-1]; captCats[captIdx-1] = t
                                CatMgrUI:Refresh()
                            end
                        end, catIdx > 1)
                        upB2:SetPoint("RIGHT", dnB2, "LEFT", -2, 0)

                        local nameX = 8
                        if isBuiltin then
                            local capN2 = catName
                            local isDisabled2 = disabled[catName]
                            local cb2 = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                            cb2:SetSize(16, 16)
                            cb2:SetPoint("LEFT", row, "LEFT", 4, 0)
                            cb2:SetChecked(not isDisabled2)
                            cb2:SetScript("OnClick", function(self)
                                if self:GetChecked() then db.global.disabledCategories[capN2] = nil
                                else db.global.disabledCategories[capN2] = true end
                                if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
                                CatMgrUI:Refresh(); RefreshBagLayout()
                            end)
                            nameX = 22
                        end

                        local locKey2 = BUILTIN_LOCALE_KEYS[catName]
                        local nTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        nTxt:SetPoint("LEFT",  row,  "LEFT",  nameX, 0)
                        nTxt:SetPoint("RIGHT", upB2, "LEFT", -4, 0)
                        nTxt:SetJustifyH("LEFT")
                        nTxt:SetText((locKey2 and L[locKey2]) or catName)
                        if isSelCat then
                            nTxt:SetTextColor(T("ACCENT_PRIMARY"))
                        else
                            nTxt:SetTextColor(T("TEXT_PRIMARY"))
                        end

                        yOffset = yOffset + 28
                    end
                end
            end
        end
    end

    local totalH = yOffset + 4
    leftWrapper:SetHeight(math.max(totalH, 40))
    leftScrollContent:SetHeight(math.max(totalH, 40))
end

-- ============================================================
-- Public API
-- ============================================================

function CatMgrUI:Refresh()
    self:RefreshLeft()
    self:RefreshRight()
end

function CatMgrUI:Show()
    local L = OneWoW_Bags.L

    EnsureDefaultSection()

    if managerFrame then
        CatMgrUI:Refresh()
        managerFrame:Show()
        managerFrame:Raise()
        return
    end

    local dialog = OneWoW_GUI:CreateDialog({
        name       = "OneWoW_BagsCatManager",
        title      = L["CATEGORY_MANAGER_TITLE"],
        width      = 740,
        height     = 580,
        strata     = "DIALOG",
        movable    = true,
        escClose   = true,
    })
    managerFrame       = dialog.frame
    dialogContentFrame = dialog.contentFrame

    -- ---- Action bar ----
    local actionBar = CreateFrame("Frame", nil, dialogContentFrame, "BackdropTemplate")
    actionBar:SetPoint("TOPLEFT",  dialogContentFrame, "TOPLEFT",  4, -4)
    actionBar:SetPoint("TOPRIGHT", dialogContentFrame, "TOPRIGHT", -4, -4)
    actionBar:SetHeight(32)
    actionBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    actionBar:SetBackdropColor(T("BG_SECONDARY"))
    actionBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local createBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["CATEGORY_CREATE"], height=24 })
    createBtn:SetPoint("LEFT", actionBar, "LEFT", 6, 0)
    createBtn:SetScript("OnClick", function() StaticPopup_Show("ONEWOW_BAGS_CREATE_CATEGORY") end)

    local sectionBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["SECTION_CREATE"] or "New Section", height=24 })
    sectionBtn:SetPoint("LEFT", createBtn, "RIGHT", 6, 0)
    sectionBtn:SetScript("OnClick", function() StaticPopup_Show("ONEWOW_BAGS_CREATE_SECTION") end)

    if _G.BAGANATOR_CONFIG then
        local bagBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["BAGANATOR_IMPORT"], height=24 })
        bagBtn:SetPoint("RIGHT", actionBar, "RIGHT", -6, 0)
        bagBtn:SetScript("OnClick", function()
            local cats, secs = ImportFromBaganator()
            if cats > 0 or secs > 0 then
                if OneWoW_Bags.Categories then
                    OneWoW_Bags.Categories:SetCustomCategories(OneWoW_Bags.db.global.customCategoriesV2)
                    OneWoW_Bags.Categories:InvalidateCache()
                end
                CatMgrUI:Refresh()
                RefreshBagLayout()
                if secs > 0 then
                    print(string.format("|cFFFFD100OneWoW Bags:|r Imported %d |4category:categories; and %d |4section:sections; from Baganator.", cats, secs))
                else
                    print(string.format("|cFFFFD100OneWoW Bags:|r " .. L["BAGANATOR_IMPORT_SUCCESS"], cats))
                end
            else
                print("|cFFFFD100OneWoW Bags:|r " .. L["BAGANATOR_IMPORT_NONE"])
            end
        end)

        local bagLbl = actionBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bagLbl:SetPoint("RIGHT", bagBtn, "LEFT", -6, 0)
        bagLbl:SetText("Baganator |")
        bagLbl:SetTextColor(T("TEXT_MUTED"))
    end

    -- ---- Split area ----
    local splitArea = CreateFrame("Frame", nil, dialogContentFrame)
    splitArea:SetPoint("TOPLEFT",     actionBar,         "BOTTOMLEFT",  0, -4)
    splitArea:SetPoint("BOTTOMRIGHT", dialogContentFrame, "BOTTOMRIGHT", -4, 4)

    -- Left panel
    local leftPanel = CreateFrame("Frame", nil, splitArea, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT",    splitArea, "TOPLEFT",    0, 0)
    leftPanel:SetPoint("BOTTOMLEFT", splitArea, "BOTTOMLEFT", 0, 0)
    leftPanel:SetWidth(235)
    leftPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    leftPanel:SetBackdropColor(T("BG_PRIMARY"))
    leftPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local leftTitleLbl = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitleLbl:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -8)
    leftTitleLbl:SetText(L["CUSTOM_CATEGORIES"] or "Categories")
    leftTitleLbl:SetTextColor(T("ACCENT_PRIMARY"))

    local leftInner = CreateFrame("Frame", nil, leftPanel)
    leftInner:SetPoint("TOPLEFT",     leftPanel, "TOPLEFT",     4, -26)
    leftInner:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -4,  4)

    local _, lContent = OneWoW_GUI:CreateScrollFrame(leftInner, { name="OneWoW_BagsCatMgrLeft" })
    leftScrollContent = lContent

    -- Right panel (resizer will reanchor it)
    local rightPanel = CreateFrame("Frame", nil, splitArea, "BackdropTemplate")
    rightPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    rightPanel:SetBackdropColor(T("BG_PRIMARY"))
    rightPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    -- Vertical pane resizer
    OneWoW_GUI:CreateVerticalPaneResizer({
        parent          = splitArea,
        leftPanel       = leftPanel,
        rightPanel      = rightPanel,
        leftMinWidth    = 180,
        rightMinWidth   = 320,
        bottomOuterInset = 0,
        rightOuterInset  = 0,
    })

    -- Right panel fixed top area
    rightTopArea = CreateFrame("Frame", nil, rightPanel)
    rightTopArea:SetPoint("TOPLEFT",  rightPanel, "TOPLEFT",  8, -8)
    rightTopArea:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -8, -8)
    rightTopArea:SetHeight(80)

    -- Right panel item scroll area (anchored below rightTopArea, fills to bottom)
    rightItemArea = CreateFrame("Frame", nil, rightPanel)
    rightItemArea:SetPoint("TOPLEFT",     rightTopArea, "BOTTOMLEFT",  0, -4)
    rightItemArea:SetPoint("BOTTOMRIGHT", rightPanel,   "BOTTOMRIGHT", -8, 8)

    local _, rContent = OneWoW_GUI:CreateScrollFrame(rightItemArea, { name="OneWoW_BagsCatMgrItems" })
    rightItemScrollContent = rContent

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

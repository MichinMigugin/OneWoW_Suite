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
    "Battle Pets", "Toys", "Other", "Junk",
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
    ["Battle Pets"]      = "CAT_BATTLE_PETS",
    ["Toys"]             = "CAT_TOYS",
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
    ["Keys"]=19,            ["Miscellaneous"]=20,   ["Battle Pets"]=21,
    ["Toys"]=22,            ["Junk"]=90,
    ["Other"]=98,
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
    ["default_battlepet"]         = "Battle Pets",
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

    local secEquip = "sec_equipment"
    local secCraft = "sec_crafting"
    local secHouse = "sec_housing"

    sections[secEquip] = { name = "EQUIPMENT", categories = { "Equipment Sets", "Weapons", "Armor" }, collapsed = false, showHeader = true }
    sections[secCraft] = { name = "CRAFTING",  categories = { "Reagents", "Trade Goods", "Tradeskill", "Recipes" }, collapsed = false, showHeader = true }
    sections[secHouse] = { name = "HOUSING",   categories = { "Housing" }, collapsed = false, showHeader = true }

    sectOrder[1] = secEquip
    sectOrder[2] = secCraft
    sectOrder[3] = secHouse
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

local function SetEditBoxValue(box, value)
    if value and value ~= "" then
        box:SetText(value)
        box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        box:SetText(box.placeholderText or "")
        box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

local function MakeEditBoxWithSave(parent, opts, getValue, setValue)
    local box = OneWoW_GUI:CreateEditBox(parent, opts)
    SetEditBoxValue(box, getValue())
    local function Save(self)
        local val = self.GetSearchText and self:GetSearchText() or self:GetText()
        if val == self.placeholderText then val = "" end
        setValue((val ~= "") and val or nil)
        if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
        if OneWoW_Bags.SearchEngine then OneWoW_Bags.SearchEngine:InvalidateCache() end
        RefreshBagLayout()
    end
    box:SetScript("OnEnterPressed", function(self) Save(self); self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) SetEditBoxValue(self, getValue()); self:ClearFocus() end)
    box:HookScript("OnEditFocusLost", function(self)
        local val = self.GetSearchText and self:GetSearchText() or self:GetText()
        if val == self.placeholderText then val = "" end
        if val ~= (getValue() or "") then Save(self) end
    end)
    box:HookScript("OnEditFocusGained", function(self)
        local cur = getValue()
        if cur and cur ~= "" then
            self:SetText(cur)
            self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            self:HighlightText()
        end
    end)
    return box
end

local function StyleToggleBtn(btn, active)
    if active then
        btn:SetBackdropColor(T("BG_ACTIVE"))
        btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
        if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
    else
        btn:SetBackdropColor(T("BTN_NORMAL"))
        btn:SetBackdropBorderColor(T("BTN_BORDER"))
        if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
    end
end

function CatMgrUI:RefreshRight()
    rightTopWrapper  = ReleaseWrapper(rightTopWrapper)
    rightItemWrapper = ReleaseWrapper(rightItemWrapper)
    if not rightItemArea then return end

    local L = OneWoW_Bags.L
    local db = GetDB()

    if not selectedCatKey then
        rightTopWrapper = CreateFrame("Frame", nil, rightItemScrollContent)
        rightTopWrapper:SetPoint("TOPLEFT", rightItemScrollContent, "TOPLEFT", 0, 0)
        rightTopWrapper:SetPoint("RIGHT", rightItemScrollContent, "RIGHT", 0, 0)
        rightTopWrapper:SetHeight(80)
        local hint = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hint:SetPoint("CENTER")
        hint:SetText(L["CATEGORY_SELECT_PROMPT"])
        hint:SetTextColor(T("TEXT_MUTED"))
        rightItemScrollContent:SetHeight(80)
        return
    end

    if selectedCatKey:sub(1, 8) == "section:" then
        local sectionID = selectedCatKey:sub(9)
        local section   = db.global.categorySections[sectionID]
        if not section then selectedCatKey = nil; self:RefreshRight(); return end

        rightTopWrapper = CreateFrame("Frame", nil, rightItemScrollContent)
        rightTopWrapper:SetPoint("TOPLEFT", rightItemScrollContent, "TOPLEFT", 0, 0)
        rightTopWrapper:SetPoint("RIGHT", rightItemScrollContent, "RIGHT", 0, 0)

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

        local checkY = -84
        for _, catName in ipairs(allCatNames) do
            local locKey   = BUILTIN_LOCALE_KEYS[catName]
            local dispName = (locKey and L[locKey]) or catName
            local isMember = memberSet[catName]

            local row = CreateFrame("Frame", nil, rightTopWrapper)
            row:SetHeight(22)
            row:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 0, checkY)
            row:SetPoint("RIGHT",   rightTopWrapper, "RIGHT",   0, 0)

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

        local totalH = math.max(math.abs(checkY) + 4, 100)
        rightTopWrapper:SetHeight(totalH)
        rightItemScrollContent:SetHeight(totalH)
        return
    end

    local isBuiltin = selectedCatKey:sub(1, 8) == "builtin:"
    local isCustom = not isBuiltin

    local catName, catData, catID, capturedID
    if isBuiltin then
        catName = selectedCatKey:sub(9)
    else
        catID = selectedCatKey
        local customCats = db.global.customCategoriesV2 or {}
        catData = customCats[catID]
        if not catData then selectedCatKey = nil; self:RefreshRight(); return end
        catName = catData.name
        capturedID = catID
    end

    local locKey = BUILTIN_LOCALE_KEYS[catName]
    local dispName = (locKey and L[locKey]) or catName

    if not db.global.categoryModifications then db.global.categoryModifications = {} end
    if not db.global.categoryModifications[catName] then db.global.categoryModifications[catName] = {} end
    local catMod = db.global.categoryModifications[catName]

    local SORT_OPTIONS = { "none", "default", "name", "rarity", "ilvl", "type", "expansion" }
    local SORT_LABELS = { L["SORT_OFF"], L["SORT_DEFAULT"], L["SORT_NAME"], L["SORT_RARITY"], L["SORT_ITEM_LEVEL"], L["SORT_TYPE"], L["SORT_EXPANSION"] or "Expansion" }
    local GROUP_OPTIONS = { "none", "expansion", "type", "slot", "quality" }
    local GROUP_LABELS = { L["GROUP_NONE"] or "None", L["GROUP_EXPANSION"] or "Expansion", L["GROUP_TYPE"] or "Type", L["GROUP_SLOT"] or "Slot", L["GROUP_QUALITY"] or "Quality" }
    local PRIORITY_OPTIONS = { -2, -1, 0, 1, 2, 3 }
    local PRIORITY_LABELS = { L["PRIORITY_LOWEST"] or "Lowest", L["PRIORITY_LOW"] or "Low", L["PRIORITY_NORMAL"] or "Normal", L["PRIORITY_HIGH"] or "High", L["PRIORITY_HIGHEST"] or "Highest", "Max" }

    rightTopWrapper = CreateFrame("Frame", nil, rightItemScrollContent)
    rightTopWrapper:SetPoint("TOPLEFT", rightItemScrollContent, "TOPLEFT", 0, 0)
    rightTopWrapper:SetPoint("RIGHT", rightItemScrollContent, "RIGHT", 0, 0)

    local capCatName = catName
    local yPos = -10

    local header = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    header:SetText(dispName)
    header:SetTextColor(T("ACCENT_PRIMARY"))

    if catMod.color then
        local cr = tonumber(catMod.color:sub(1,2), 16) / 255
        local cg = tonumber(catMod.color:sub(3,4), 16) / 255
        local cb = tonumber(catMod.color:sub(5,6), 16) / 255
        header:SetTextColor(cr, cg, cb, 1.0)
    end

    local typeLabel = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("LEFT", header, "RIGHT", 8, 0)
    if isBuiltin then
        typeLabel:SetText("[" .. (L["CATEGORY_TYPE_BUILTIN"] or "Built-in") .. "]")
    elseif catData and catData.isTSM then
        typeLabel:SetText("[" .. (L["CATEGORY_TYPE_TSM"] or "TSM") .. "]")
    else
        typeLabel:SetText("[" .. (L["CATEGORY_TYPE_CUSTOM"] or "Custom") .. "]")
    end
    typeLabel:SetTextColor(T("TEXT_MUTED"))

    if isCustom then
        local delBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["CATEGORY_DELETE"], height=22 })
        delBtn:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -6, yPos)
        delBtn:SetScript("OnClick", function()
            StaticPopup_Show("ONEWOW_BAGS_DELETE_CATEGORY", catData.name, nil, capturedID)
        end)
        local renBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["CATEGORY_RENAME"], height=22 })
        renBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
        renBtn:SetScript("OnClick", function()
            StaticPopup_Show("ONEWOW_BAGS_RENAME_CATEGORY", catData.name, nil, capturedID)
        end)
    end

    yPos = yPos - 28
    local div1 = rightTopWrapper:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, yPos)
    div1:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, yPos)
    div1:SetColorTexture(T("BORDER_SUBTLE"))
    yPos = yPos - 8

    if isBuiltin then
        local Categories = OneWoW_Bags.Categories
        local descText = Categories and Categories.GetCategoryDescription and Categories:GetCategoryDescription(catName)
        if descText then
            local ruleLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ruleLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
            ruleLbl:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -10, yPos)
            ruleLbl:SetJustifyH("LEFT")
            ruleLbl:SetWordWrap(true)
            ruleLbl:SetText((L["CATEGORY_RULE"] or "Rule:") .. " " .. descText)
            ruleLbl:SetTextColor(T("TEXT_SECONDARY"))
            yPos = yPos - ruleLbl:GetStringHeight() - 6
        end
    end

    if isCustom and catData then
        local filterMode = catData.filterMode
        if not filterMode then
            if catData.searchExpression and catData.searchExpression ~= "" then
                filterMode = "search"
            elseif (catData.itemType and catData.itemType ~= "") or (catData.itemSubType and catData.itemSubType ~= "") then
                filterMode = "type"
            else
                filterMode = "type"
            end
        end

        local filterLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        filterLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
        filterLbl:SetText("Auto-Match Mode:")
        filterLbl:SetTextColor(T("TEXT_PRIMARY"))

        local typeFilterBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = "By Type", height = 20, minWidth = 70 })
        typeFilterBtn:SetPoint("LEFT", filterLbl, "RIGHT", 8, 0)
        local advFilterBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = "Advanced", height = 20, minWidth = 70 })
        advFilterBtn:SetPoint("LEFT", typeFilterBtn, "RIGHT", 4, 0)

        local filterContent = CreateFrame("Frame", nil, rightTopWrapper)
        filterContent:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 0, yPos - 26)
        filterContent:SetPoint("RIGHT", rightTopWrapper, "RIGHT", 0, 0)

        local function BuildTypeFilter(parent)
            local fY = -4
            local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, fY)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetText(L["CAT_TYPE_FILTER_DESC"])
            desc:SetTextColor(T("TEXT_MUTED"))
            fY = fY - desc:GetStringHeight() - 6

            local tLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            tLbl:SetText(L["CAT_ITEM_TYPE"])
            tLbl:SetTextColor(T("TEXT_PRIMARY"))
            local tBox = MakeEditBoxWithSave(parent,
                { width=160, height=22, placeholderText = "Housing" },
                function() return catData.itemType end,
                function(v) catData.itemType = v end)
            tBox:SetPoint("LEFT", tLbl, "RIGHT", 8, 0)
            tBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - 28

            local sLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            sLbl:SetText(L["CAT_ITEM_SUBTYPE"])
            sLbl:SetTextColor(T("TEXT_PRIMARY"))
            local sBox = MakeEditBoxWithSave(parent,
                { width=160, height=22, placeholderText = "Decor" },
                function() return catData.itemSubType end,
                function(v) catData.itemSubType = v end)
            sBox:SetPoint("LEFT", sLbl, "RIGHT", 8, 0)
            sBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - 28

            local mLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            mLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            mLbl:SetText(L["CAT_TYPE_MATCH_MODE"])
            mLbl:SetTextColor(T("TEXT_PRIMARY"))
            local curMode = catData.typeMatchMode or "and"
            local andB = OneWoW_GUI:CreateFitTextButton(parent, { text = L["CAT_TYPE_MATCH_AND"], height = 20, minWidth = 40 })
            andB:SetPoint("LEFT", mLbl, "RIGHT", 8, 0)
            local orB = OneWoW_GUI:CreateFitTextButton(parent, { text = L["CAT_TYPE_MATCH_OR"], height = 20, minWidth = 40 })
            orB:SetPoint("LEFT", andB, "RIGHT", 4, 0)
            StyleToggleBtn(andB, curMode ~= "or")
            StyleToggleBtn(orB, curMode == "or")
            andB:SetScript("OnClick", function()
                catData.typeMatchMode = "and"
                StyleToggleBtn(andB, true); StyleToggleBtn(orB, false)
                if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
                RefreshBagLayout()
            end)
            orB:SetScript("OnClick", function()
                catData.typeMatchMode = "or"
                StyleToggleBtn(andB, false); StyleToggleBtn(orB, true)
                if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
                RefreshBagLayout()
            end)
            fY = fY - 26
            return math.abs(fY)
        end

        local function BuildSearchFilter(parent)
            local fY = -4
            local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, fY)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetText("Use search keywords with operators to match items automatically.")
            desc:SetTextColor(T("TEXT_MUTED"))
            fY = fY - desc:GetStringHeight() - 6

            local sBox = MakeEditBoxWithSave(parent,
                { width=200, height=22, placeholderText = "#battlepet&!#collected" },
                function() return catData.searchExpression end,
                function(v) catData.searchExpression = v end)
            sBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            sBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - 28

            local helpLines = {
                L["SEARCH_HELP_KEYWORDS"] or "",
                L["SEARCH_HELP_QUALITY"] or "",
                L["SEARCH_HELP_OPERATORS"] or "",
                L["SEARCH_HELP_ILVL"] or "",
                L["SEARCH_HELP_EXAMPLE"] or "",
            }
            for _, line in ipairs(helpLines) do
                if line ~= "" then
                    local hl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    hl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
                    hl:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, fY)
                    hl:SetJustifyH("LEFT")
                    hl:SetWordWrap(true)
                    hl:SetText(line)
                    hl:SetTextColor(T("TEXT_MUTED"))
                    fY = fY - hl:GetStringHeight() - 2
                end
            end
            return math.abs(fY)
        end

        local filterH = 0
        local function ShowFilter(mode)
            for _, child in pairs({filterContent:GetChildren()}) do child:Hide(); child:SetParent(UIParent) end
            for _, region in pairs({filterContent:GetRegions()}) do region:Hide(); region:SetParent(UIParent) end
            catData.filterMode = mode
            StyleToggleBtn(typeFilterBtn, mode == "type")
            StyleToggleBtn(advFilterBtn, mode == "search")
            if mode == "type" then
                filterH = BuildTypeFilter(filterContent)
            else
                filterH = BuildSearchFilter(filterContent)
            end
            filterContent:SetHeight(filterH)
            if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
        end
        typeFilterBtn:SetScript("OnClick", function() ShowFilter("type"); CatMgrUI:RefreshRight() end)
        advFilterBtn:SetScript("OnClick", function() ShowFilter("search"); CatMgrUI:RefreshRight() end)
        ShowFilter(filterMode)
        yPos = yPos - 26 - filterH - 4
    end

    local div2 = rightTopWrapper:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, yPos)
    div2:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, yPos)
    div2:SetColorTexture(T("BORDER_SUBTLE"))
    yPos = yPos - 8

    local sortLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sortLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    sortLbl:SetText(L["CAT_SORT"] or "Sort")
    sortLbl:SetTextColor(T("TEXT_PRIMARY"))
    local currentSort = catMod.sortMode or "none"
    local sortIdx = 1
    for i, v in ipairs(SORT_OPTIONS) do if v == currentSort then sortIdx = i; break end end
    local sortBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = SORT_LABELS[sortIdx], height = 20, minWidth = 60 })
    sortBtn:SetPoint("LEFT", sortLbl, "RIGHT", 8, 0)
    sortBtn:SetScript("OnClick", function()
        sortIdx = (sortIdx % #SORT_OPTIONS) + 1
        sortBtn.text:SetText(SORT_LABELS[sortIdx])
        db.global.categoryModifications[capCatName].sortMode = SORT_OPTIONS[sortIdx]
        RefreshBagLayout()
    end)

    local groupLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    groupLbl:SetPoint("LEFT", sortBtn, "RIGHT", 16, 0)
    groupLbl:SetText(L["GROUP_BY"] or "Group By")
    groupLbl:SetTextColor(T("TEXT_PRIMARY"))
    local currentGroup = catMod.groupBy or "none"
    local groupIdx = 1
    for i, v in ipairs(GROUP_OPTIONS) do if v == currentGroup then groupIdx = i; break end end
    local groupBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = GROUP_LABELS[groupIdx], height = 20, minWidth = 60 })
    groupBtn:SetPoint("LEFT", groupLbl, "RIGHT", 8, 0)
    groupBtn:SetScript("OnClick", function()
        groupIdx = (groupIdx % #GROUP_OPTIONS) + 1
        groupBtn.text:SetText(GROUP_LABELS[groupIdx])
        db.global.categoryModifications[capCatName].groupBy = GROUP_OPTIONS[groupIdx]
        RefreshBagLayout()
    end)
    yPos = yPos - 28

    local prioLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prioLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    prioLbl:SetText(L["PRIORITY"] or "Priority")
    prioLbl:SetTextColor(T("TEXT_PRIMARY"))
    local currentPrio = catMod.priority or 0
    local prioIdx = 3
    for i, v in ipairs(PRIORITY_OPTIONS) do if v == currentPrio then prioIdx = i; break end end
    local prioBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = PRIORITY_LABELS[prioIdx], height = 20, minWidth = 60 })
    prioBtn:SetPoint("LEFT", prioLbl, "RIGHT", 8, 0)
    prioBtn:SetScript("OnClick", function()
        prioIdx = (prioIdx % #PRIORITY_OPTIONS) + 1
        prioBtn.text:SetText(PRIORITY_LABELS[prioIdx])
        db.global.categoryModifications[capCatName].priority = PRIORITY_OPTIONS[prioIdx]
        if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
        RefreshBagLayout()
    end)

    local colorLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorLbl:SetPoint("LEFT", prioBtn, "RIGHT", 16, 0)
    colorLbl:SetText(L["COLOR"] or "Color")
    colorLbl:SetTextColor(T("TEXT_PRIMARY"))

    local colorSwatch = CreateFrame("Button", nil, rightTopWrapper, "BackdropTemplate")
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("LEFT", colorLbl, "RIGHT", 6, 0)
    colorSwatch:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    colorSwatch:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    if catMod.color then
        local cr = tonumber(catMod.color:sub(1,2), 16) / 255
        local cg = tonumber(catMod.color:sub(3,4), 16) / 255
        local cb = tonumber(catMod.color:sub(5,6), 16) / 255
        colorSwatch:SetBackdropColor(cr, cg, cb, 1.0)
    else
        colorSwatch:SetBackdropColor(T("ACCENT_PRIMARY"))
    end
    colorSwatch:SetScript("OnClick", function()
        local r, g, b = 1, 0.82, 0
        if catMod.color then
            r = tonumber(catMod.color:sub(1,2), 16) / 255
            g = tonumber(catMod.color:sub(3,4), 16) / 255
            b = tonumber(catMod.color:sub(5,6), 16) / 255
        end
        local info = {}
        info.r, info.g, info.b = r, g, b
        info.swatchFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local hex = string.format("%02X%02X%02X", math.floor(nr*255+0.5), math.floor(ng*255+0.5), math.floor(nb*255+0.5))
            db.global.categoryModifications[capCatName].color = hex
            colorSwatch:SetBackdropColor(nr, ng, nb, 1.0)
            CatMgrUI:RefreshLeft()
            RefreshBagLayout()
        end
        info.cancelFunc = function(prev)
            db.global.categoryModifications[capCatName].color = catMod.color
            CatMgrUI:RefreshLeft()
            RefreshBagLayout()
        end
        info.hasOpacity = false
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local clearColorBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = L["COLOR_CLEAR"] or "Clear", height = 20 })
    clearColorBtn:SetPoint("LEFT", colorSwatch, "RIGHT", 4, 0)
    clearColorBtn:SetScript("OnClick", function()
        db.global.categoryModifications[capCatName].color = nil
        colorSwatch:SetBackdropColor(T("ACCENT_PRIMARY"))
        CatMgrUI:RefreshLeft()
        RefreshBagLayout()
    end)
    yPos = yPos - 28

    local hideLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hideLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    hideLbl:SetText(L["HIDE_IN"] or "Hide In")
    hideLbl:SetTextColor(T("TEXT_PRIMARY"))

    if not catMod.hideIn then catMod.hideIn = {} end
    local hideContainers = {
        { key = "backpack", label = L["HIDE_BACKPACK"] or "Backpack" },
        { key = "character_bank", label = L["HIDE_CHAR_BANK"] or "Character Bank" },
        { key = "warband_bank", label = L["HIDE_WARBAND_BANK"] or "Warband Bank" },
    }
    local hideX = 60
    for _, hc in ipairs(hideContainers) do
        local cb = CreateFrame("CheckButton", nil, rightTopWrapper, "UICheckButtonTemplate")
        cb:SetSize(18, 18)
        cb:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", hideX, yPos + 2)
        cb:SetChecked(catMod.hideIn[hc.key] or false)
        local capKey = hc.key
        cb:SetScript("OnClick", function(self)
            catMod.hideIn[capKey] = self:GetChecked() or false
            if not self:GetChecked() then catMod.hideIn[capKey] = nil end
            RefreshBagLayout()
        end)
        local cbLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cbLbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cbLbl:SetText(hc.label)
        cbLbl:SetTextColor(T("TEXT_PRIMARY"))
        hideX = hideX + cbLbl:GetStringWidth() + 28
    end
    yPos = yPos - 26

    local div3 = rightTopWrapper:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, yPos)
    div3:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, yPos)
    div3:SetColorTexture(T("BORDER_SUBTLE"))
    yPos = yPos - 8

    local addItemsLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addItemsLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    addItemsLbl:SetText(L["ADDED_ITEMS"] or "Added Items")
    addItemsLbl:SetTextColor(T("ACCENT_SECONDARY"))
    yPos = yPos - 16

    local addDescLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addDescLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    addDescLbl:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -10, yPos)
    addDescLbl:SetJustifyH("LEFT")
    addDescLbl:SetWordWrap(true)
    addDescLbl:SetText(L["ADDED_ITEMS_DESC"] or "Items manually assigned override normal classification.")
    addDescLbl:SetTextColor(T("TEXT_MUTED"))
    yPos = yPos - addDescLbl:GetStringHeight() - 6

    local dropZone = CreateFrame("Button", nil, rightTopWrapper, "BackdropTemplate")
    dropZone:SetHeight(28)
    dropZone:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, yPos)
    dropZone:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, yPos)
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
        if cType == "item" and itemID then
            ClearCursor()
            if isCustom and capturedID then
                MoveItemToCategory(itemID, capturedID)
            elseif isBuiltin then
                if OneWoW_Bags.Categories then
                    OneWoW_Bags.Categories:AddItemToBuiltinCategory(capCatName, itemID)
                end
                CatMgrUI:Refresh()
                RefreshBagLayout()
            end
        end
    end
    dropZone:SetScript("OnReceiveDrag", handleDrop)
    dropZone:SetScript("OnMouseUp", function(_, btn) if btn == "LeftButton" then handleDrop() end end)
    yPos = yPos - 32

    local addLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    addLbl:SetText(L["CATEGORY_ADD_BY_ID"])
    addLbl:SetTextColor(T("TEXT_PRIMARY"))
    local addBox = OneWoW_GUI:CreateEditBox(rightTopWrapper, { width=120, height=22 })
    addBox:SetPoint("LEFT", addLbl, "RIGHT", 8, 0)
    local addBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["ADD_ITEM"], height=22 })
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
    addBtn:SetScript("OnClick", function()
        local text = addBox.GetSearchText and addBox:GetSearchText() or addBox:GetText()
        if not text or text == "" then return end
        local added = 0
        for idStr in text:gmatch("[^%s,;]+") do
            local id = tonumber(idStr)
            if id and id > 0 then
                if isCustom and capturedID then
                    MoveItemToCategory(id, capturedID)
                elseif isBuiltin then
                    if OneWoW_Bags.Categories then
                        OneWoW_Bags.Categories:AddItemToBuiltinCategory(capCatName, id)
                    end
                end
                added = added + 1
            end
        end
        if added > 0 then
            addBox:SetText("")
            CatMgrUI:Refresh()
            RefreshBagLayout()
        end
    end)
    yPos = yPos - 28

    local allItems = {}
    if isCustom and catData and catData.items then
        for idStr in pairs(catData.items) do
            local id = tonumber(idStr)
            if id then table.insert(allItems, { id = id, isCustom = true }) end
        end
    end
    if catMod.addedItems then
        for idStr in pairs(catMod.addedItems) do
            local id = tonumber(idStr)
            if id then table.insert(allItems, { id = id, isCustom = false }) end
        end
    end
    table.sort(allItems, function(a, b) return a.id < b.id end)

    if #allItems == 0 then
        local emptyLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 8, yPos - 8)
        emptyLbl:SetText(L["ADDED_ITEMS_NONE"] or "No items manually added.")
        emptyLbl:SetTextColor(T("TEXT_MUTED"))
        yPos = yPos - 28
    else
        for _, itemEntry in ipairs(allItems) do
            local itemID = itemEntry.id
            local row = CreateFrame("Frame", nil, rightTopWrapper, "BackdropTemplate")
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 0, yPos)
            row:SetPoint("RIGHT", rightTopWrapper, "RIGHT", 0, 0)
            row:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
            row:SetBackdropColor(T("BG_SECONDARY"))
            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            local tex = C_Item.GetItemIconByID(itemID)
            if tex then icon:SetTexture(tex) end

            local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameTxt:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            nameTxt:SetPoint("RIGHT", row, "RIGHT", -72, 0)
            nameTxt:SetJustifyH("LEFT")
            nameTxt:SetText(C_Item.GetItemNameByID(itemID) or ("Item " .. itemID))
            nameTxt:SetTextColor(T("TEXT_PRIMARY"))

            local captItemID = itemID
            local captIsCustom = itemEntry.isCustom
            local remBtn = OneWoW_GUI:CreateFitTextButton(row, { text=L["REMOVE_ITEM"], height=18 })
            remBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            remBtn:SetScript("OnClick", function()
                if captIsCustom and capturedID then
                    local cat = db.global.customCategoriesV2[capturedID]
                    if cat and cat.items then cat.items[tostring(captItemID)] = nil end
                else
                    if OneWoW_Bags.Categories then
                        OneWoW_Bags.Categories:RemoveItemFromBuiltinCategory(capCatName, captItemID)
                    end
                end
                if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
                CatMgrUI:Refresh()
                RefreshBagLayout()
            end)
            yPos = yPos - 28
        end
    end

    local totalH = math.max(math.abs(yPos) + 8, 100)
    rightTopWrapper:SetHeight(totalH)
    rightItemScrollContent:SetHeight(totalH)
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
        local catMods = db.global.categoryModifications or {}
        local mod = catMods[entry.name] or {}

        local dnB = MakeSmallBtn(row, "v", doDown, idxInGroup < totalInGroup)
        dnB:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        local upB = MakeSmallBtn(row, "^", doUp, idxInGroup > 1)
        upB:SetPoint("RIGHT", dnB, "LEFT", -2, 0)

        local badges = ""
        if mod.sortMode and mod.sortMode ~= "none" then badges = badges .. "S" end
        if mod.groupBy and mod.groupBy ~= "none" then badges = badges .. "G" end
        if mod.addedItems and next(mod.addedItems) then badges = badges .. "+" end
        if mod.hideIn and next(mod.hideIn) then badges = badges .. "H" end
        if mod.priority and mod.priority ~= 0 then badges = badges .. "P" end
        if not entry.isBuiltin and entry.data and entry.data.searchExpression then badges = badges .. "E" end

        local badgeAnchor = upB
        if badges ~= "" then
            local badgeTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badgeTxt:SetPoint("RIGHT", upB, "LEFT", -4, 0)
            badgeTxt:SetText(badges)
            badgeTxt:SetTextColor(T("ACCENT_SECONDARY"))
            badgeAnchor = badgeTxt
        end

        local colorAnchor = badgeAnchor
        if mod.color then
            local swatch = row:CreateTexture(nil, "ARTWORK")
            swatch:SetSize(8, 8)
            swatch:SetPoint("RIGHT", badgeAnchor, "LEFT", -4, 0)
            local cr = tonumber(mod.color:sub(1,2), 16) / 255
            local cg = tonumber(mod.color:sub(3,4), 16) / 255
            local cb = tonumber(mod.color:sub(5,6), 16) / 255
            swatch:SetColorTexture(cr, cg, cb, 1.0)
            colorAnchor = swatch
        end

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
            nameTxt:SetPoint("RIGHT", colorAnchor, "LEFT", -4, 0)
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
            nameTxt:SetPoint("RIGHT", colorAnchor, "LEFT", -4, 0)
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

    local TSM = OneWoW_Bags.TSMIntegration
    if TSM and TSM:IsAvailable() then
        local tsmBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["TSM_IMPORT"] or "Import TSM", height=24 })
        if _G.BAGANATOR_CONFIG then
            tsmBtn:SetPoint("RIGHT", actionBar, "RIGHT", -6, 0)
        else
            tsmBtn:SetPoint("RIGHT", actionBar, "RIGHT", -6, 0)
        end
        tsmBtn:SetScript("OnClick", function()
            local count = TSM:Import()
            if count > 0 then
                CatMgrUI:Refresh()
                RefreshBagLayout()
                print(string.format("|cFFFFD100OneWoW Bags:|r " .. (L["TSM_IMPORT_SUCCESS"] or "Imported %d categories from TSM."), count))
            else
                print("|cFFFFD100OneWoW Bags:|r " .. (L["TSM_IMPORT_NONE"] or "No TSM data found."))
            end
        end)
    end

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

    rightTopArea = nil

    rightItemArea = CreateFrame("Frame", nil, rightPanel)
    rightItemArea:SetPoint("TOPLEFT",     rightPanel, "TOPLEFT",      8, -8)
    rightItemArea:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -8,  8)

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

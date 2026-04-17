local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = OneWoW_Bags.L
local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetController()
    return OneWoW_Bags.CategoryController
end

local function HasBaganator()
    return rawget(_G, "BAGANATOR_CONFIG") ~= nil
end

local db = setmetatable({}, {
    __index = function(_, key)
        local liveDB = GetDB()
        return liveDB and liveDB[key]
    end,
    __newindex = function(_, key, value)
        local liveDB = GetDB()
        if liveDB then
            liveDB[key] = value
        end
    end,
})

local PE = OneWoW_Bags.PredicateEngine
local Categories = OneWoW_Bags.Categories
local SD = OneWoW_Bags.SectionDefaults

local random, max, floor, time = math.random, math.max, math.floor, time
local pairs, ipairs = pairs, ipairs
local strtrim = strtrim
local C_Timer = C_Timer
local GameTooltip = GameTooltip
local tostring, tonumber, format = tostring, tonumber, format
local tinsert, tremove, wipe = tinsert, tremove, wipe
local sort = table.sort

OneWoW_Bags.CategoryManagerUI = {}
local CatMgrUI = OneWoW_Bags.CategoryManagerUI

local managerFrame       = nil
local dialogContentFrame = nil
local leftScrollFrame    = nil
local leftScrollContent  = nil
local rightScrollFrame   = nil
local rightItemArea      = nil
local rightItemScrollContent = nil
local rightTopWrapper    = nil
local rightItemWrapper   = nil
local leftWrapper        = nil
local selectedCatKey     = nil  -- nil | "builtin:Name" | "section:ID" | customID

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
    ["Mats"]             = "CAT_MATS",
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
    ["1W Junk"]          = "CAT_1W_JUNK",
    ["1W Upgrades"]      = "CAT_1W_UPGRADES",
}

local BUILTIN_PRIORITY = {
    ["1W Junk"]=1,          ["1W Upgrades"]=1,
    ["Recent Items"]=1,     ["Hearthstone"]=2,      ["Keystone"]=3,
    ["Potions"]=4,          ["Food"]=5,             ["Consumables"]=6,
    ["Quest Items"]=7,      ["Equipment Sets"]=8,   ["Weapons"]=9,
    ["Armor"]=10,           ["Mats"]=10.5,          ["Reagents"]=11,        ["Trade Goods"]=12,
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
local function GetEffectiveBuiltinNamesList()
    return SD:GetEffectiveBuiltinNames(GetDB().global)
end

local function EnsureDefaultSection()
    local sections = db.global.categorySections
    local sectOrder = db.global.sectionOrder

    if #sectOrder > 0 then return end

    local secEquip = SD.SEC_EQUIPMENT
    local secCraft = SD.SEC_CRAFTING
    local secHouse = SD.SEC_HOUSING
    local secOw = SD.SEC_ONEWOW_BAGS

    sections[secEquip] = { name = "EQUIPMENT", categories = CopyTable(SD.EQUIPMENT_CATEGORIES), collapsed = false, showHeader = true }
    sections[secCraft] = { name = "CRAFTING",  categories = CopyTable(SD.CRAFTING_CATEGORIES), collapsed = false, showHeader = true }
    sections[secHouse] = { name = "HOUSING",   categories = CopyTable(SD.HOUSING_CATEGORIES), collapsed = false, showHeader = true }

    local members = SD:BuildOnewowMembers(db.global)
    sections[secOw] = {
        name = L["SECTION_ONEWOW_BAGS"],
        categories = members,
        collapsed = false,
        showHeader = false,
    }

    sectOrder[1] = secOw
    sectOrder[2] = secEquip
    sectOrder[3] = secCraft
    sectOrder[4] = secHouse
end

local function ReleaseWrapper(w)
    if w then
        w:Hide()
        w:SetParent(UIParent)
    end
    return nil
end

local function MakeSmallBtn(parent, label, onClick, active)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(20, 20)
    btn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    if active then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        btn:SetScript("OnClick", onClick)
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetText(label)
    if active then
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
    return btn
end

local function MoveItemToCategory(itemID, destCatID)
    local controller = GetController()
    if controller and controller.AddItemToCategory then
        local ok, ownerName = controller:AddItemToCategory(destCatID, itemID)
        if not ok then
            if ownerName then
                UIErrorsFrame:AddMessage(format(L["ERR_ITEM_ALREADY_MANUAL_CATEGORY"], ownerName), 1, 0, 0)
            else
                UIErrorsFrame:AddMessage(L["ERR_ITEM_ALREADY_MANUAL_CATEGORY_GENERIC"], 1, 0, 0)
            end
        end
    end
end

-- ============================================================
-- Static Popups
-- ============================================================

StaticPopupDialogs["ONEWOW_BAGS_CREATE_CATEGORY"] = {
    text = "", hasEditBox = true,
    button1 = L["POPUP_CREATE"],
    button2 = L["POPUP_CANCEL"],
    OnShow = function(self)
        self.Text:SetText(L["CATEGORY_CREATE_ENTER"])
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = strtrim(self.EditBox:GetText() or "")
        if name == "" then return end
        local controller = GetController()
        if not controller or not controller.CreateCategory then return end
        local prevSel = selectedCatKey
        local id, err = controller:CreateCategory(name)
        if not id then
            if err and L[err] then
                UIErrorsFrame:AddMessage(L[err], 1, 0, 0)
            end
            C_Timer.After(0, function()
                local d = StaticPopup_Show("ONEWOW_BAGS_CREATE_CATEGORY")
                if d and d.EditBox then
                    d.EditBox:SetText(name)
                    d.EditBox:SetFocus()
                end
            end)
            return
        end
        selectedCatKey = id
        local g = GetDB().global
        local secId = prevSel and prevSel:match("^section:(.+)$")
        if secId and secId ~= SD.SEC_ONEWOW_BAGS then
            controller:SetSectionMembership(secId, name, true)
        elseif g.categorySections[SD.SEC_ONEWOW_BAGS] then
            SD:SyncOnewowSectionCategories(g)
            controller:RefreshUI()
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
    button1 = L["POPUP_RENAME"] or "Rename",
    button2 = L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self, data)
        self.Text:SetText(L["CATEGORY_RENAME_ENTER"])
        local cat = data and db.global.customCategoriesV2[data]
        if cat then self.EditBox:SetText(cat.name); self.EditBox:HighlightText() end
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = strtrim(self.EditBox:GetText() or "")
        if name == "" or not data then return end
        local controller = GetController()
        if not controller or not controller.RenameCategory then return end
        local ok, err = controller:RenameCategory(data, name)
        if not ok then
            if err and L[err] then
                UIErrorsFrame:AddMessage(L[err], 1, 0, 0)
            end
            C_Timer.After(0, function()
                local d = StaticPopup_Show("ONEWOW_BAGS_RENAME_CATEGORY", nil, nil, data)
                if d and d.EditBox then
                    d.EditBox:SetText(name)
                    d.EditBox:SetFocus()
                end
            end)
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
    button1 = L["POPUP_DELETE"],
    button2 = L["POPUP_CANCEL"],
    OnShow = function(self) self.Text:SetText(L["CATEGORY_DELETE_CONFIRM"]) end,
    OnAccept = function(self, data)
        if data then
            local controller = GetController()
            if controller and controller.DeleteCategory then
                controller:DeleteCategory(data)
            end
            if selectedCatKey == data then selectedCatKey = nil end
        end
    end,
    timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
}

StaticPopupDialogs["ONEWOW_BAGS_CREATE_SECTION"] = {
    text = "", hasEditBox = true,
    button1 = L["POPUP_CREATE"],
    button2 = L["POPUP_CANCEL"],
    OnShow = function(self)
        self.Text:SetText(L["SECTION_CREATE_ENTER"] or "Enter section name:")
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = strtrim(self.EditBox:GetText() or "")
        if name == "" then return end
        local controller = GetController()
        if not controller or not controller.CreateSection then return end
        local id, err = controller:CreateSection(name)
        if not id then
            if err and L[err] then
                UIErrorsFrame:AddMessage(L[err], 1, 0, 0)
            end
            C_Timer.After(0, function()
                local d = StaticPopup_Show("ONEWOW_BAGS_CREATE_SECTION")
                if d and d.EditBox then
                    d.EditBox:SetText(name)
                    d.EditBox:SetFocus()
                end
            end)
            return
        end
        selectedCatKey = "section:" .. id
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
    button1 = L["POPUP_RENAME"] or "Rename",
    button2 = L["POPUP_CANCEL"] or "Cancel",
    OnShow = function(self, data)
        self.Text:SetText(L["SECTION_RENAME_ENTER"] or "Enter new section name:")
        local sec = data and db.global.categorySections[data]
        if sec then self.EditBox:SetText(sec.name); self.EditBox:HighlightText() end
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = strtrim(self.EditBox:GetText() or "")
        if name == "" or not data then return end
        local controller = GetController()
        if not controller or not controller.RenameSection then return end
        local ok, err = controller:RenameSection(data, name)
        if not ok then
            if err and L[err] then
                UIErrorsFrame:AddMessage(L[err], 1, 0, 0)
            end
            C_Timer.After(0, function()
                local d = StaticPopup_Show("ONEWOW_BAGS_RENAME_SECTION", nil, nil, data)
                if d and d.EditBox then
                    d.EditBox:SetText(name)
                    d.EditBox:SetFocus()
                end
            end)
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
    button1 = L["POPUP_DELETE"],
    button2 = L["POPUP_CANCEL"],
    OnShow = function(self) self.Text:SetText(L["SECTION_DELETE_CONFIRM"]) end,
    OnAccept = function(self, data)
        if data then
            local controller = GetController()
            if controller and controller.DeleteSection then
                controller:DeleteSection(data)
            end
            if selectedCatKey == ("section:" .. data) then selectedCatKey = nil end
        end
    end,
    timeout=0, whileDead=true, hideOnEscape=true, preferredIndex=3,
}

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
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
    end
end

function CatMgrUI:RefreshRight()
    rightTopWrapper  = ReleaseWrapper(rightTopWrapper)
    rightItemWrapper = ReleaseWrapper(rightItemWrapper)
    if not rightItemArea then return end

    if not selectedCatKey then
        rightTopWrapper = CreateFrame("Frame", nil, rightItemScrollContent)
        rightTopWrapper:SetPoint("TOPLEFT", rightItemScrollContent, "TOPLEFT", 0, 0)
        rightTopWrapper:SetPoint("RIGHT", rightItemScrollContent, "RIGHT", 0, 0)
        rightTopWrapper:SetHeight(80)
        local hint = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hint:SetPoint("CENTER")
        hint:SetText(L["CATEGORY_SELECT_PROMPT"])
        hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        if rightScrollFrame then
            rightScrollFrame:GetScrollChild():SetHeight(80)
        end
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
        header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

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
        div:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local captSectionID = sectionID

        local showHeaderCB = CreateFrame("CheckButton", nil, rightTopWrapper, "UICheckButtonTemplate")
        showHeaderCB:SetSize(18, 18)
        showHeaderCB:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 8, -42)
        showHeaderCB:SetChecked(section.showHeader or false)
        showHeaderCB:SetScript("OnClick", function(self)
            local controller = GetController()
            if controller and controller.SetSectionShowHeader then
                controller:SetSectionShowHeader(captSectionID, self:GetChecked())
            end
        end)
        local showHeaderLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        showHeaderLbl:SetPoint("LEFT", showHeaderCB, "RIGHT", 4, 0)
        showHeaderLbl:SetText(L["SECTION_SHOW_HEADER_BAGS"])
        showHeaderLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local showHeaderBankCB = CreateFrame("CheckButton", nil, rightTopWrapper, "UICheckButtonTemplate")
        showHeaderBankCB:SetSize(18, 18)
        showHeaderBankCB:SetPoint("LEFT", showHeaderLbl, "RIGHT", 8, 0)
        local bankHeaderVal = section.showHeaderBank
        if bankHeaderVal == nil then bankHeaderVal = section.showHeader or false end
        showHeaderBankCB:SetChecked(bankHeaderVal)
        showHeaderBankCB:SetScript("OnClick", function(self)
            local controller = GetController()
            if controller and controller.SetSectionShowHeaderBank then
                controller:SetSectionShowHeaderBank(captSectionID, self:GetChecked())
            end
        end)
        local showHeaderBankLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        showHeaderBankLbl:SetPoint("LEFT", showHeaderBankCB, "RIGHT", 4, 0)
        showHeaderBankLbl:SetText(L["SECTION_SHOW_HEADER_BANK"])
        showHeaderBankLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local infoLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, -66)
        infoLbl:SetText(L["CATEGORY_IN_SECTION"] or "Toggle categories to include in this section:")
        infoLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local allCatNames = {}
        for _, n in ipairs(GetEffectiveBuiltinNamesList()) do tinsert(allCatNames, n) end
        for _, cd in pairs(db.global.customCategoriesV2) do tinsert(allCatNames, cd.name) end

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
            cbLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local captCat = catName
            cb:SetScript("OnClick", function(self)
                local controller = GetController()
                if controller and controller.SetSectionMembership then
                    controller:SetSectionMembership(sectionID, captCat, self:GetChecked())
                end
            end)

            checkY = checkY - 24
        end

        local totalH = max(abs(checkY) + 4, 100)
        rightTopWrapper:SetHeight(totalH)
        if rightScrollFrame then
            rightScrollFrame:GetScrollChild():SetHeight(totalH)
        end
        return
    end

    local isBuiltin = selectedCatKey:sub(1, 8) == "builtin:"
    local isCustom = not isBuiltin

    local catName, catData, catID, capturedID
    if isBuiltin then
        catName = selectedCatKey:sub(9)
    else
        catID = selectedCatKey
        local customCats = db.global.customCategoriesV2
        catData = customCats[catID]
        if not catData then selectedCatKey = nil; self:RefreshRight(); return end
        catName = catData.name
        capturedID = catID
    end

    local locKey = BUILTIN_LOCALE_KEYS[catName]
    local dispName = (locKey and L[locKey]) or catName

    local catMod = OneWoW_Bags:EnsureCategoryModification(catName)

    local SORT_OPTIONS = { "none", "default", "name", "rarity", "ilvl", "type", "expansion" }
    local SORT_LABELS = { L["SORT_OFF"], L["SORT_DEFAULT"], L["SORT_NAME"], L["SORT_RARITY"], L["SORT_ITEM_LEVEL"], L["SORT_TYPE"], L["SORT_EXPANSION"] }
    local GROUP_OPTIONS = { "none", "expansion", "type", "slot", "quality" }
    local GROUP_LABELS = { L["GROUP_NONE"], L["GROUP_EXPANSION"], L["GROUP_TYPE"], L["GROUP_SLOT"], L["GROUP_QUALITY"] }
    local PRIORITY_OPTIONS = { -2, -1, 0, 1, 2, 3 }
    local PRIORITY_LABELS = { L["PRIORITY_LOWEST"], L["PRIORITY_LOW"], L["PRIORITY_NORMAL"], L["PRIORITY_HIGH"], L["PRIORITY_HIGHEST"], L["PRIORITY_MAX"] }

    rightTopWrapper = CreateFrame("Frame", nil, rightItemScrollContent)
    rightTopWrapper:SetPoint("TOPLEFT", rightItemScrollContent, "TOPLEFT", 0, 0)
    rightTopWrapper:SetPoint("RIGHT", rightItemScrollContent, "RIGHT", 0, 0)

    local capCatName = catName
    local yPos = -10

    local header = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    header:SetText(dispName)
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    if catMod.color then
        local cr = tonumber(catMod.color:sub(1,2), 16) / 255
        local cg = tonumber(catMod.color:sub(3,4), 16) / 255
        local cb = tonumber(catMod.color:sub(5,6), 16) / 255
        header:SetTextColor(cr, cg, cb, 1.0)
    end

    local typeLabel = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("LEFT", header, "RIGHT", 8, 0)
    if isBuiltin then
        typeLabel:SetText("[" .. (L["CATEGORY_TYPE_BUILTIN"]) .. "]")
    elseif catData and catData.isTSM then
        typeLabel:SetText("[" .. (L["CATEGORY_TYPE_TSM"]) .. "]")
    else
        typeLabel:SetText("[" .. (L["CATEGORY_TYPE_CUSTOM"]) .. "]")
    end
    typeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

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
    div1:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yPos = yPos - 8

    if isBuiltin then
        local descText = Categories:GetCategoryDescription(catName)
        if descText then
            local ruleLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ruleLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
            ruleLbl:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -10, yPos)
            ruleLbl:SetJustifyH("LEFT")
            ruleLbl:SetWordWrap(true)
            ruleLbl:SetText((L["CATEGORY_RULE"]) .. " " .. descText)
            ruleLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
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
        filterLbl:SetText(L["CAT_MATCH_MODE"])
        filterLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local typeFilterBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = L["CAT_MATCH_BY_TYPE"], height = 20, minWidth = 70 })
        typeFilterBtn:SetPoint("LEFT", filterLbl, "RIGHT", 8, 0)
        local advFilterBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = L["CAT_MATCH_ADVANCED"], height = 20, minWidth = 70 })
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
            desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            fY = fY - desc:GetStringHeight() - 6

            local tLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            tLbl:SetText(L["CAT_ITEM_TYPE"])
            tLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            local tBox = MakeEditBoxWithSave(parent,
                { width=160, height=22, placeholderText = L["CAT_HOUSING"] },
                function() return catData.itemType end,
                function(v)
                    local controller = GetController()
                    if controller and controller.SetCustomCategoryValue then
                        controller:SetCustomCategoryValue(capturedID, "itemType", v)
                    end
                end)
            tBox:SetPoint("LEFT", tLbl, "RIGHT", 8, 0)
            tBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - 28

            local sLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            sLbl:SetText(L["CAT_ITEM_SUBTYPE"])
            sLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            local sBox = MakeEditBoxWithSave(parent,
                { width=160, height=22, placeholderText = L["PLACEHOLDER_ITEM_SUBTYPE"] },
                function() return catData.itemSubType end,
                function(v)
                    local controller = GetController()
                    if controller and controller.SetCustomCategoryValue then
                        controller:SetCustomCategoryValue(capturedID, "itemSubType", v)
                    end
                end)
            sBox:SetPoint("LEFT", sLbl, "RIGHT", 8, 0)
            sBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - 28

            local mLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            mLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            mLbl:SetText(L["CAT_TYPE_MATCH_MODE"])
            mLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            local curMode = catData.typeMatchMode or "and"
            local andB = OneWoW_GUI:CreateFitTextButton(parent, { text = L["CAT_TYPE_MATCH_AND"], height = 20, minWidth = 40 })
            andB:SetPoint("LEFT", mLbl, "RIGHT", 8, 0)
            local orB = OneWoW_GUI:CreateFitTextButton(parent, { text = L["CAT_TYPE_MATCH_OR"], height = 20, minWidth = 40 })
            orB:SetPoint("LEFT", andB, "RIGHT", 4, 0)
            StyleToggleBtn(andB, curMode ~= "or")
            StyleToggleBtn(orB, curMode == "or")
            andB:SetScript("OnClick", function()
                local controller = GetController()
                if controller and controller.SetCustomCategoryValue then
                    controller:SetCustomCategoryValue(capturedID, "typeMatchMode", "and")
                end
                StyleToggleBtn(andB, true); StyleToggleBtn(orB, false)
            end)
            orB:SetScript("OnClick", function()
                local controller = GetController()
                if controller and controller.SetCustomCategoryValue then
                    controller:SetCustomCategoryValue(capturedID, "typeMatchMode", "or")
                end
                StyleToggleBtn(andB, false); StyleToggleBtn(orB, true)
            end)
            fY = fY - 26
            return abs(fY)
        end

        local function BuildSearchFilter(parent)
            local fY = -4
            local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, fY)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetText(L["SEARCH_HELP_DESC"])
            desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            fY = fY - desc:GetStringHeight() - 6

            local sBox = MakeEditBoxWithSave(parent,
                { width=200, height=22, placeholderText = L["SEARCH_HELP_PLACEHOLDER"] },
                function() return catData.searchExpression end,
                function(v)
                    local controller = GetController()
                    if controller and controller.SetCustomCategoryValue then
                        controller:SetCustomCategoryValue(capturedID, "searchExpression", v)
                    end
                end)
            sBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
            sBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - 28

            local helpLines = {
                L["SEARCH_HELP_KEYWORDS"],
                L["SEARCH_HELP_QUALITY"],
                L["SEARCH_HELP_OPERATORS"],
                L["SEARCH_HELP_ILVL"],
                L["SEARCH_HELP_EXAMPLE"],
            }
            for _, line in ipairs(helpLines) do
                if line ~= "" then
                    local hl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    hl:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, fY)
                    hl:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, fY)
                    hl:SetJustifyH("LEFT")
                    hl:SetWordWrap(true)
                    hl:SetText(line)
                    hl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    fY = fY - hl:GetStringHeight() - 2
                end
            end
            return abs(fY)
        end

        local filterH = 0
        local function ShowFilter(mode)
            for _, child in pairs({filterContent:GetChildren()}) do child:Hide(); child:SetParent(UIParent) end
            for _, region in pairs({filterContent:GetRegions()}) do region:Hide(); region:SetParent(UIParent) end
            local controller = GetController()
            if controller and controller.SetCustomCategoryValue then
                controller:SetCustomCategoryValue(capturedID, "filterMode", mode, { refreshUI = false })
            end
            StyleToggleBtn(typeFilterBtn, mode == "type")
            StyleToggleBtn(advFilterBtn, mode == "search")
            if mode == "type" then
                filterH = BuildTypeFilter(filterContent)
            else
                filterH = BuildSearchFilter(filterContent)
            end
            filterContent:SetHeight(filterH)
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
    div2:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yPos = yPos - 8

    local sortLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sortLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    sortLbl:SetText(L["CAT_SORT"])
    sortLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local currentSort = catMod.sortMode or "none"
    local sortIdx = 1
    for i, v in ipairs(SORT_OPTIONS) do if v == currentSort then sortIdx = i; break end end
    local sortBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = SORT_LABELS[sortIdx], height = 20, minWidth = 60 })
    sortBtn:SetPoint("LEFT", sortLbl, "RIGHT", 8, 0)
    sortBtn:SetScript("OnClick", function()
        sortIdx = (sortIdx % #SORT_OPTIONS) + 1
        sortBtn.text:SetText(SORT_LABELS[sortIdx])
        local controller = GetController()
        if controller and controller.SetCategorySortMode then
            controller:SetCategorySortMode(capCatName, SORT_OPTIONS[sortIdx])
        end
    end)

    local groupLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    groupLbl:SetPoint("LEFT", sortBtn, "RIGHT", 16, 0)
    groupLbl:SetText(L["GROUP_BY"])
    groupLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local currentGroup = catMod.groupBy or "none"
    local groupIdx = 1
    for i, v in ipairs(GROUP_OPTIONS) do if v == currentGroup then groupIdx = i; break end end
    local groupBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = GROUP_LABELS[groupIdx], height = 20, minWidth = 60 })
    groupBtn:SetPoint("LEFT", groupLbl, "RIGHT", 8, 0)
    groupBtn:SetScript("OnClick", function()
        groupIdx = (groupIdx % #GROUP_OPTIONS) + 1
        groupBtn.text:SetText(GROUP_LABELS[groupIdx])
        local controller = GetController()
        if controller and controller.SetCategoryGroupBy then
            controller:SetCategoryGroupBy(capCatName, GROUP_OPTIONS[groupIdx])
        end
    end)
    yPos = yPos - 28

    local prioLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prioLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    prioLbl:SetText(L["PRIORITY"])
    prioLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local currentPrio = catMod.priority or 0
    local prioIdx = 3
    for i, v in ipairs(PRIORITY_OPTIONS) do if v == currentPrio then prioIdx = i; break end end
    local prioBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = PRIORITY_LABELS[prioIdx], height = 20, minWidth = 60 })
    prioBtn:SetPoint("LEFT", prioLbl, "RIGHT", 8, 0)
    prioBtn:SetScript("OnClick", function()
        prioIdx = (prioIdx % #PRIORITY_OPTIONS) + 1
        prioBtn.text:SetText(PRIORITY_LABELS[prioIdx])
        local controller = GetController()
        if controller and controller.SetCategoryPriority then
            controller:SetCategoryPriority(capCatName, PRIORITY_OPTIONS[prioIdx])
        end
    end)

    local colorLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorLbl:SetPoint("LEFT", prioBtn, "RIGHT", 16, 0)
    colorLbl:SetText(L["COLOR"])
    colorLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local colorSwatch = CreateFrame("Button", nil, rightTopWrapper, "BackdropTemplate")
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("LEFT", colorLbl, "RIGHT", 6, 0)
    colorSwatch:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    colorSwatch:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    if catMod.color then
        local cr = tonumber(catMod.color:sub(1,2), 16) / 255
        local cg = tonumber(catMod.color:sub(3,4), 16) / 255
        local cb = tonumber(catMod.color:sub(5,6), 16) / 255
        colorSwatch:SetBackdropColor(cr, cg, cb, 1.0)
    else
        colorSwatch:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
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
            local hex = format("%02X%02X%02X", floor(nr*255+0.5), floor(ng*255+0.5), floor(nb*255+0.5))
            local controller = GetController()
            if controller and controller.SetCategoryColor then
                controller:SetCategoryColor(capCatName, hex)
            end
            colorSwatch:SetBackdropColor(nr, ng, nb, 1.0)
        end
        info.cancelFunc = function(prev)
            local controller = GetController()
            if controller and controller.SetCategoryColor then
                controller:SetCategoryColor(capCatName, catMod.color)
            end
        end
        info.hasOpacity = false
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local clearColorBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = L["COLOR_CLEAR"], height = 20 })
    clearColorBtn:SetPoint("LEFT", colorSwatch, "RIGHT", 4, 0)
    clearColorBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.ClearCategoryColor then
            controller:ClearCategoryColor(capCatName)
        end
        colorSwatch:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end)
    yPos = yPos - 28

    local appliesLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    appliesLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    appliesLbl:SetText(L["APPLIES_TO"])
    appliesLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local appliesContainers = {
        { key = "backpack", label = L["APPLIES_BACKPACK"] },
        { key = "character_bank", label = L["APPLIES_CHAR_BANK"] },
        { key = "warband_bank", label = L["APPLIES_WARBAND_BANK"] },
    }
    local appliesX = 70
    for _, hc in ipairs(appliesContainers) do
        local cb = CreateFrame("CheckButton", nil, rightTopWrapper, "UICheckButtonTemplate")
        cb:SetSize(18, 18)
        cb:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", appliesX, yPos + 2)
        local isApplied = not (catMod.appliesIn and catMod.appliesIn[hc.key] == false)
        cb:SetChecked(isApplied)
        local capKey = hc.key
        cb:SetScript("OnClick", function(self)
            local controller = GetController()
            if controller and controller.SetCategoryAppliesIn then
                controller:SetCategoryAppliesIn(capCatName, capKey, self:GetChecked())
            end
        end)
        local cbLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cbLbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cbLbl:SetText(hc.label)
        cbLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        appliesX = appliesX + cbLbl:GetStringWidth() + 28
    end
    yPos = yPos - 26

    local div3 = rightTopWrapper:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, yPos)
    div3:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, yPos)
    div3:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yPos = yPos - 8

    local addItemsLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addItemsLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    addItemsLbl:SetText(L["ADDED_ITEMS"])
    addItemsLbl:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yPos = yPos - 16

    local addDescLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addDescLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    addDescLbl:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -10, yPos)
    addDescLbl:SetJustifyH("LEFT")
    addDescLbl:SetWordWrap(true)
    addDescLbl:SetText(L["ADDED_ITEMS_DESC"])
    addDescLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yPos = yPos - addDescLbl:GetStringHeight() - 6

    local dropZone = CreateFrame("Button", nil, rightTopWrapper, "BackdropTemplate")
    dropZone:SetHeight(28)
    dropZone:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 4, yPos)
    dropZone:SetPoint("TOPRIGHT", rightTopWrapper, "TOPRIGHT", -4, yPos)
    dropZone:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    dropZone:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    dropZone:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    dropZone:EnableMouse(true)
    dropZone:RegisterForDrag("LeftButton")

    local dropTxt = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropTxt:SetPoint("CENTER")
    dropTxt:SetText(L["CATEGORY_DRAG_HINT"])
    dropTxt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    dropZone:SetScript("OnEnter", function()
        if GetCursorInfo() == "item" then
            dropZone:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            dropTxt:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
    end)
    dropZone:SetScript("OnLeave", function()
        dropZone:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        dropTxt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end)
    local function handleDrop()
        local cType, itemID = GetCursorInfo()
        if cType == "item" and itemID then
            ClearCursor()
            local controller = GetController()
            if controller then
                local ok, ownerName
                if isCustom and capturedID and controller.AddItemToCategory then
                    ok, ownerName = controller:AddItemToCategory(capturedID, itemID)
                elseif isBuiltin and controller.AddItemToCategory then
                    ok, ownerName = controller:AddItemToCategory(selectedCatKey, itemID)
                end
                if ok == false then
                    if ownerName then
                        UIErrorsFrame:AddMessage(format(L["ERR_ITEM_ALREADY_MANUAL_CATEGORY"], ownerName), 1, 0, 0)
                    else
                        UIErrorsFrame:AddMessage(L["ERR_ITEM_ALREADY_MANUAL_CATEGORY_GENERIC"], 1, 0, 0)
                    end
                end
            end
        end
    end
    dropZone:SetScript("OnReceiveDrag", handleDrop)
    dropZone:SetScript("OnMouseUp", function(_, btn) if btn == "LeftButton" then handleDrop() end end)
    yPos = yPos - 32

    local addLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 10, yPos)
    addLbl:SetText(L["CATEGORY_ADD_BY_ID"])
    addLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local addBox = OneWoW_GUI:CreateEditBox(rightTopWrapper, { width=120, height=22 })
    addBox:SetPoint("LEFT", addLbl, "RIGHT", 8, 0)
    local addBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text=L["ADD_ITEM"], height=22 })
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
    addBtn:SetScript("OnClick", function()
        local text = addBox.GetSearchText and addBox:GetSearchText() or addBox:GetText()
        if not text or text == "" then return end
        local addedItems = {}
        for idStr in text:gmatch("[^%s,;]+") do
            local id = tonumber(idStr)
            if id and id > 0 then
                tinsert(addedItems, id)
            end
        end
        if #addedItems > 0 then
            local controller = GetController()
            if controller and controller.AddItemsToCategory then
                local ok, ownerName = controller:AddItemsToCategory(selectedCatKey, addedItems)
                if not ok then
                    if ownerName then
                        UIErrorsFrame:AddMessage(format(L["ERR_ITEM_ALREADY_MANUAL_CATEGORY"], ownerName), 1, 0, 0)
                    else
                        UIErrorsFrame:AddMessage(L["ERR_ITEM_ALREADY_MANUAL_CATEGORY_GENERIC"], 1, 0, 0)
                    end
                end
            end
            addBox:SetText("")
        end
    end)
    yPos = yPos - 28

    local allItems = {}
    if isCustom and catData and catData.items then
        for idStr in pairs(catData.items) do
            local id = tonumber(idStr)
            if id then tinsert(allItems, { id = id, isCustom = true }) end
        end
    end
    if catMod.addedItems then
        for idStr in pairs(catMod.addedItems) do
            local id = tonumber(idStr)
            if id then tinsert(allItems, { id = id, isCustom = false }) end
        end
    end
    sort(allItems, function(a, b) return a.id < b.id end)

    if #allItems == 0 then
        local emptyLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 8, yPos - 8)
        emptyLbl:SetText(L["ADDED_ITEMS_NONE"])
        emptyLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        yPos = yPos - 28
    else
        for _, itemEntry in ipairs(allItems) do
            local itemID = itemEntry.id
            local row = CreateFrame("Frame", nil, rightTopWrapper, "BackdropTemplate")
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 0, yPos)
            row:SetPoint("RIGHT", rightTopWrapper, "RIGHT", 0, 0)
            row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

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
            nameTxt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local captItemID = itemID
            local captIsCustom = itemEntry.isCustom
            local remBtn = OneWoW_GUI:CreateFitTextButton(row, { text=L["REMOVE_ITEM"], height=18 })
            remBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            remBtn:SetScript("OnClick", function()
                local controller = GetController()
                if controller and controller.RemoveItemFromCategory then
                    if captIsCustom and capturedID then
                        controller:RemoveItemFromCategory(capturedID, captItemID)
                    else
                        controller:RemoveItemFromCategory(selectedCatKey, captItemID)
                    end
                end
            end)
            yPos = yPos - 28
        end
    end

    local totalH = max(abs(yPos) + 8, 100)
    rightTopWrapper:SetHeight(totalH)
    if rightScrollFrame then
        rightScrollFrame:GetScrollChild():SetHeight(totalH)
    end
end

-- ============================================================
-- Left Panel
-- ============================================================

function CatMgrUI:RefreshLeft()
    leftWrapper = ReleaseWrapper(leftWrapper)
    if not leftScrollContent then return end

    local disabled   = db.global.disabledCategories
    local sections   = db.global.categorySections
    local sectOrder  = db.global.sectionOrder
    local customCats = db.global.customCategoriesV2

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
    for _, name in ipairs(GetEffectiveBuiltinNamesList()) do
        if not inSection[name] then
            tinsert(rootCats, { name=name, isBuiltin=true, key="builtin:"..name })
        end
    end
    for catID, catData in pairs(customCats) do
        if not inSection[catData.name] then
            tinsert(rootCats, { name=catData.name, isBuiltin=false, id=catID, data=catData, key=catID })
        end
    end

    local savedOrder = db.global.categoryOrder
    if #savedOrder > 0 then
        local orderMap = {}
        for i, name in ipairs(savedOrder) do orderMap[name] = i end
        sort(rootCats, function(a, b)
            local aP = orderMap[a.name] or 999
            local bP = orderMap[b.name] or 999
            if aP ~= bP then return aP < bP end
            return a.name < b.name
        end)
    else
        sort(rootCats, function(a, b)
            local aP = BUILTIN_PRIORITY[a.name] or 50
            local bP = BUILTIN_PRIORITY[b.name] or 50
            if aP ~= bP then return aP < bP end
            return a.name < b.name
        end)
    end

    -- Helper: render one category row
    local function RenderCatRow(entry, idxInGroup, totalInGroup, indent)
        indent = indent or 0
        local isSelected = (selectedCatKey == entry.key)

        local row = CreateFrame("Button", nil, leftWrapper, "BackdropTemplate")
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", indent, -yOffset)
        row:SetPoint("RIGHT",   leftWrapper, "RIGHT",   0, 0)
        row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)

        if isSelected then
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        elseif entry.isBuiltin then
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        else
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end

        local captKey = entry.key
        row:SetScript("OnClick", function()
            selectedCatKey = captKey
            CatMgrUI:Refresh()
        end)

        -- Up / Down
        local function doUp()
            if idxInGroup > 1 then
                local controller = GetController()
                if controller and controller.MoveRootCategory then
                    controller:MoveRootCategory(rootCats, idxInGroup, -1)
                end
            end
        end
        local function doDown()
            if idxInGroup < totalInGroup then
                local controller = GetController()
                if controller and controller.MoveRootCategory then
                    controller:MoveRootCategory(rootCats, idxInGroup, 1)
                end
            end
        end
        local catMods = db.global.categoryModifications
        local mod = catMods[entry.name] or {}

        local dnB = MakeSmallBtn(row, "v", doDown, idxInGroup < totalInGroup)
        dnB:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        local upB = MakeSmallBtn(row, "^", doUp, idxInGroup > 1)
        upB:SetPoint("RIGHT", dnB, "LEFT", -2, 0)

        local badges = ""
        if mod.sortMode and mod.sortMode ~= "none" then badges = badges .. "S" end
        if mod.groupBy and mod.groupBy ~= "none" then badges = badges .. "G" end
        if mod.addedItems and next(mod.addedItems) then badges = badges .. "+" end
        if mod.appliesIn then
            for _, v in pairs(mod.appliesIn) do
                if v == false then badges = badges .. "A"; break end
            end
        end
        if mod.priority and mod.priority ~= 0 then badges = badges .. "P" end
        local searchExpr = not entry.isBuiltin and entry.data and entry.data.searchExpression
        if searchExpr and searchExpr ~= "" then badges = badges .. "E" end

        local badgeAnchor = upB
        if badges ~= "" then
            local badgeTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badgeTxt:SetPoint("RIGHT", upB, "LEFT", -4, 0)
            badgeTxt:SetText(badges)
            badgeTxt:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            local badgeHit = CreateFrame("Frame", nil, row)
            badgeHit:EnableMouse(true)
            badgeHit:SetSize(max(24, #badges * 9 + 8), 28)
            badgeHit:SetPoint("RIGHT", upB, "LEFT", -4, 0)
            badgeHit:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["CATEGORY_BADGE_TOOLTIP_TITLE"], 1, 1, 1)
                local tr, tg, tb = OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
                GameTooltip:AddLine(L["CATEGORY_BADGE_TOOLTIP_BODY"], tr, tg, tb, true)
                GameTooltip:Show()
            end)
            badgeHit:SetScript("OnLeave", GameTooltip_Hide)
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
                local controller = GetController()
                if controller and controller.SetBuiltinCategoryEnabled then
                    controller:SetBuiltinCategoryEnabled(capN, self:GetChecked())
                end
            end)
            local locKey   = BUILTIN_LOCALE_KEYS[catName]
            local nameTxt  = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameTxt:SetPoint("LEFT",  cb,  "RIGHT", 3, 0)
            nameTxt:SetPoint("RIGHT", colorAnchor, "LEFT", -4, 0)
            nameTxt:SetJustifyH("LEFT")
            nameTxt:SetText((locKey and L[locKey]) or catName)
            if isDisabled then
                nameTxt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            elseif isSelected then
                nameTxt:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                nameTxt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        else
            local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameTxt:SetPoint("LEFT",  row, "LEFT",  8, 0)
            nameTxt:SetPoint("RIGHT", colorAnchor, "LEFT", -4, 0)
            nameTxt:SetJustifyH("LEFT")
            nameTxt:SetText(entry.data.name)
            if isSelected then
                nameTxt:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                nameTxt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end

        yOffset = yOffset + 30
    end

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
            secRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)

            if isSelSec then
                secRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                secRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                secRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                secRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            end

            -- Section up/down (reorders among sections only)
            local captSecIdx = secIdx
            local dnSec = MakeSmallBtn(secRow, "v", function()
                if captSecIdx < totalSections then
                    local controller = GetController()
                    if controller and controller.MoveSection then
                        controller:MoveSection(sectionID, 1)
                    end
                end
            end, secIdx < totalSections)
            dnSec:SetPoint("RIGHT", secRow, "RIGHT", -2, 0)

            local upSec = MakeSmallBtn(secRow, "^", function()
                if captSecIdx > 1 then
                    local controller = GetController()
                    if controller and controller.MoveSection then
                        controller:MoveSection(sectionID, -1)
                    end
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
            arrow:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))

            local secName = secRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            secName:SetPoint("LEFT",  secRow, "LEFT",  18, 0)
            secName:SetPoint("RIGHT", upSec,  "LEFT",  -4, 0)
            secName:SetJustifyH("LEFT")
            secName:SetText(section.name)
            if isSelSec then
                secName:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                secName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            local captSKey = sKey
            secRow:SetScript("OnClick", function()
                local controller = GetController()
                if controller and controller.SetSectionCollapsed then
                    controller:SetSectionCollapsed(sectionID, not section.collapsed)
                end
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
                        row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
                        if isSelCat then
                            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                        elseif isBuiltin then
                            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                        else
                            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                        end
                        local captEKey = entry.key
                        row:SetScript("OnClick", function()
                            selectedCatKey = captEKey
                            CatMgrUI:Refresh()
                        end)

                        local dnB2 = MakeSmallBtn(row, "v", function()
                            if captIdx < #captCats then
                                local controller = GetController()
                                if controller and controller.MoveSectionCategory then
                                    controller:MoveSectionCategory(sectionID, captIdx, 1)
                                end
                            end
                        end, catIdx < #cats)
                        dnB2:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                        local upB2 = MakeSmallBtn(row, "^", function()
                            if captIdx > 1 then
                                local controller = GetController()
                                if controller and controller.MoveSectionCategory then
                                    controller:MoveSectionCategory(sectionID, captIdx, -1)
                                end
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
                                local controller = GetController()
                                if controller and controller.SetBuiltinCategoryEnabled then
                                    controller:SetBuiltinCategoryEnabled(capN2, self:GetChecked())
                                end
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
                            nTxt:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                        else
                            nTxt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                        end

                        yOffset = yOffset + 28
                    end
                end
            end
        end
    end

    for i, entry in ipairs(rootCats) do
        RenderCatRow(entry, i, #rootCats, 0)
    end

    local totalH = yOffset + 4
    leftWrapper:SetHeight(max(totalH, 40))
    if leftScrollFrame then
        leftScrollFrame:GetScrollChild():SetHeight(max(totalH, 40))
    end
end

-- ============================================================
-- Public API
-- ============================================================

function CatMgrUI:Refresh()
    self:RefreshLeft()
    self:RefreshRight()
end

function CatMgrUI:Show()
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
    actionBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    actionBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local createBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["CATEGORY_CREATE"], height=24 })
    createBtn:SetPoint("LEFT", actionBar, "LEFT", 6, 0)
    createBtn:SetScript("OnClick", function() StaticPopup_Show("ONEWOW_BAGS_CREATE_CATEGORY") end)

    local sectionBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["SECTION_CREATE"], height=24 })
    sectionBtn:SetPoint("LEFT", createBtn, "RIGHT", 6, 0)
    sectionBtn:SetScript("OnClick", function() StaticPopup_Show("ONEWOW_BAGS_CREATE_SECTION") end)

    if HasBaganator() then
        local bagBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["BAGANATOR_IMPORT"], height=24 })
        bagBtn:SetPoint("RIGHT", actionBar, "RIGHT", -6, 0)
        bagBtn:SetScript("OnClick", function()
            local controller = GetController()
            local cats, secs = 0, 0
            if controller and controller.ImportBaganator then
                cats, secs = controller:ImportBaganator()
            end
            if cats > 0 or secs > 0 then
                if secs > 0 then
                    print("|cFFFFD100" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. string.format(L["BAGANATOR_IMPORT_WITH_SECTIONS"], cats, secs))
                else
                    print("|cFFFFD100" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. string.format(L["BAGANATOR_IMPORT_SUCCESS"], cats))
                end
            else
                print("|cFFFFD100" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. L["BAGANATOR_IMPORT_NONE"])
            end
        end)

        local bagLbl = actionBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bagLbl:SetPoint("RIGHT", bagBtn, "LEFT", -6, 0)
        bagLbl:SetText(L["BAGANATOR_LABEL"])
        bagLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    local TSM = OneWoW_Bags.TSMIntegration
    if TSM and TSM:IsAvailable() then
        local tsmBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["TSM_IMPORT"] or "Import TSM", height=24 })
        tsmBtn:SetPoint("RIGHT", actionBar, "RIGHT", -6, 0)
        tsmBtn:SetScript("OnClick", function()
            local controller = GetController()
            local count = 0
            if controller and controller.ImportTSM then
                count = controller:ImportTSM()
            end
            if count > 0 then
                print("|cFFFFD100" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. string.format(L["TSM_IMPORT_SUCCESS"], count))
            else
                print("|cFFFFD100" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. L["TSM_IMPORT_NONE"])
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
    leftPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    leftPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local leftInner = CreateFrame("Frame", nil, leftPanel)
    leftInner:SetPoint("TOPLEFT",     leftPanel, "TOPLEFT",     4, -8)
    leftInner:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -4,  4)

    leftScrollFrame, leftScrollContent = OneWoW_GUI:CreateScrollFrame(leftInner, {
        name = "OneWoW_BagsCatMgrLeft",
        layoutRightInset = 24,
    })

    -- Right panel (resizer will reanchor it)
    local rightPanel = CreateFrame("Frame", nil, splitArea, "BackdropTemplate")
    rightPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    rightPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    rightPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

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

    rightItemArea = CreateFrame("Frame", nil, rightPanel)
    rightItemArea:SetPoint("TOPLEFT",     rightPanel, "TOPLEFT",      8, -8)
    rightItemArea:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -8,  8)

    rightScrollFrame, rightItemScrollContent = OneWoW_GUI:CreateScrollFrame(rightItemArea, {
        name = "OneWoW_BagsCatMgrItems",
        layoutRightInset = 24,
    })

    CatMgrUI:Refresh()
    if managerFrame then
        managerFrame:Show()
    end
end

function CatMgrUI:Toggle()
    if managerFrame and managerFrame:IsShown() then
        managerFrame:Hide()
    else
        CatMgrUI:Show()
    end
end

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

local PE = OneWoW_GUI.PredicateEngine
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
local sectionReorder     = nil
local sectionRowFrames   = nil
local leftLayoutFrames   = nil
local dragCollapseState  = nil
local dragDriver         = nil
local categoryReorder    = nil
local categoryRowFrames  = nil
local dwellState         = nil
local dwellDriver        = nil

-- Rollup pacing for the drag-collapse animation. Each step hides one member
-- row (from the bottom up) and slides the followers up by one row-height.
-- 8ms yields ~208ms total for a 26-member section, which still feels snappy.
local COLLAPSE_STEP_SEC = 0.008

-- How long the cursor must dwell on a collapsed section header during a
-- category drag before we auto-expand it in place.
local CATEGORY_DWELL_EXPAND_SEC = 0.4
local SECTION_ROW_HEIGHT = 30
local MEMBER_ROW_HEIGHT  = 28

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

local function ApplySectionHeaderReorderVisual(secRow)
    if not secRow then return end
    ---@diagnostic disable-next-line: undefined-field
    if secRow._catMgrSelected then
        secRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        secRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    end
end

-- Visually collapse the dragged section for the duration of the drag.
-- We hide its member rows one-by-one from the bottom up and slide every frame
-- below the section's tail up by one row-height per step, producing a rollup
-- animation that keeps the scroll list gap-free and always exposes a drop
-- target. EndDragCollapse cancels the animation and snaps everything back.
-- On a successful drop the controller's RefreshUI rebuilds the list from
-- scratch and the temporary shift state is discarded naturally.
local function StopDragDriver()
    if dragDriver then
        dragDriver:SetScript("OnUpdate", nil)
        dragDriver:Hide()
    end
end

local function ApplyFollowerShift(dy)
    local st = dragCollapseState
    if not st or not leftWrapper then return end
    for frame, orig in pairs(st.shifted) do
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", orig.origX, -(orig.origY - dy))
        frame:SetPoint("RIGHT",   leftWrapper, "RIGHT",   0, 0)
    end
    if leftWrapper._catMgrBaseHeight then
        local newH = max(leftWrapper._catMgrBaseHeight - dy, 40)
        leftWrapper:SetHeight(newH)
        if leftScrollFrame then
            leftScrollFrame:GetScrollChild():SetHeight(newH)
        end
    end
end

local function BeginDragCollapse(secRow)
    if dragCollapseState then return end
    if not secRow or not leftLayoutFrames or not leftWrapper then return end
    local members = secRow._catMgrMemberRows
    if not members or #members == 0 then return end
    local tailIdx = secRow._catMgrTailIndex
    if not tailIdx then return end

    local shifted = {}
    for i = tailIdx + 1, #leftLayoutFrames do
        local e = leftLayoutFrames[i]
        shifted[e.frame] = { origX = e.origX, origY = e.origY }
    end

    dragCollapseState = {
        secRow      = secRow,
        members     = members,
        shifted     = shifted,
        nextIdx     = #members,
        hiddenCount = 0,
        stepAccum   = 0,
    }

    if not dragDriver then
        dragDriver = CreateFrame("Frame")
    end
    dragDriver:Show()
    dragDriver:SetScript("OnUpdate", function(_, dt)
        local st = dragCollapseState
        if not st then
            StopDragDriver()
            return
        end
        st.stepAccum = st.stepAccum + dt
        while st.stepAccum >= COLLAPSE_STEP_SEC and st.nextIdx > 0 do
            st.stepAccum = st.stepAccum - COLLAPSE_STEP_SEC
            local row = st.members[st.nextIdx]
            if row then row:Hide() end
            st.nextIdx = st.nextIdx - 1
            st.hiddenCount = st.hiddenCount + 1
            ApplyFollowerShift(st.hiddenCount * 28)
        end
        if st.nextIdx == 0 then
            StopDragDriver()
        end
    end)
end

local function EndDragCollapse()
    StopDragDriver()
    if not dragCollapseState then return end
    local st = dragCollapseState
    dragCollapseState = nil

    for frame, orig in pairs(st.shifted) do
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", orig.origX, -orig.origY)
        frame:SetPoint("RIGHT",   leftWrapper, "RIGHT",   0, 0)
    end

    local secRow = st.secRow
    if secRow and secRow._catMgrMemberRows then
        for _, r in ipairs(secRow._catMgrMemberRows) do r:Show() end
    end

    if leftWrapper and leftWrapper._catMgrBaseHeight then
        leftWrapper:SetHeight(leftWrapper._catMgrBaseHeight)
        if leftScrollFrame then
            leftScrollFrame:GetScrollChild():SetHeight(leftWrapper._catMgrBaseHeight)
        end
    end
end

local function EnsureSectionReorder()
    if sectionReorder then return sectionReorder end
    local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
    sectionReorder = OneWoW_GUI:CreateReorderDrag({
        getItems = function()
            return sectionRowFrames
        end,
        dropIndicator = {
            thickness         = 2,
            horizontalPadding = 4,
            color             = { r, g, b, 1 },
        },
        autoScroll = {
            getFrame = function() return leftScrollFrame end,
            edgeZone = 40,
            maxSpeed = 14,
            minSpeed = 2,
        },
        onReorder = function(fromIdx, toIdx, insertBefore)
            local destIdx = insertBefore and toIdx or (toIdx + 1)
            if destIdx > fromIdx then destIdx = destIdx - 1 end
            if destIdx == fromIdx then return end
            local controller = GetController()
            if controller and controller.MoveSectionOrder then
                controller:MoveSectionOrder(fromIdx, destIdx)
            end
        end,
        onPickup = function(secRow)
            ---@diagnostic disable-next-line: undefined-field
            secRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            BeginDragCollapse(secRow)
        end,
        onRestore = function(secRow)
            EndDragCollapse()
            ApplySectionHeaderReorderVisual(secRow)
        end,
        onHover = function(secRow)
            ---@diagnostic disable-next-line: undefined-field
            secRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end,
        onUnhover = function(secRow)
            ApplySectionHeaderReorderVisual(secRow)
        end,
    })
    return sectionReorder
end

-- ============================================================
-- Category drag/drop (intra- and inter-section)
-- ============================================================

local ApplyMemberRowReorderVisual
local ApplyCategoryHoverVisual
local ClearCategoryHoverVisual
local InlineExpandSection
local BuildSectionMemberRows
local EnsureCategoryReorder
local StopDwellTimer

local function RestoreMemberRowBorder(row)
    if not row then return end
    if row._catMgrSelected then
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
end

ApplyMemberRowReorderVisual = function(row, picked)
    if not row then return end
    if picked then
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    else
        RestoreMemberRowBorder(row)
    end
end

StopDwellTimer = function()
    dwellState = nil
    if dwellDriver then dwellDriver:Hide() end
end

local function StartDwellTimer(target)
    if not target then return end
    dwellState = {
        sectionID = target._catMgrSectionID,
        startedAt = GetTime(),
        target    = target,
    }
    if not dwellDriver then
        dwellDriver = CreateFrame("Frame")
        dwellDriver:SetScript("OnUpdate", function()
            local st = dwellState
            if not st then
                dwellDriver:Hide()
                return
            end
            if GetTime() - st.startedAt >= CATEGORY_DWELL_EXPAND_SEC then
                local sid = st.sectionID
                local tgt = st.target
                dwellState = nil
                dwellDriver:Hide()
                if sid and tgt and InlineExpandSection then
                    InlineExpandSection(sid, tgt)
                end
            end
        end)
    end
    dwellDriver:Show()
end

ApplyCategoryHoverVisual = function(target, _)
    if not target then return end
    if target._catMgrKind == "header" then
        if categoryReorder then categoryReorder:SetIndicatorVisible(false) end
        target:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        target:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        local section = db.global.categorySections[target._catMgrSectionID]
        if section and section.collapsed then
            if not dwellState or dwellState.target ~= target then
                StartDwellTimer(target)
            end
        else
            StopDwellTimer()
        end
    else
        if categoryReorder then categoryReorder:SetIndicatorVisible(true) end
        target:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
        StopDwellTimer()
    end
end

ClearCategoryHoverVisual = function(target)
    if not target then return end
    if target._catMgrKind == "header" then
        if target._catMgrSelected then
            target:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            target:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            target:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            target:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        end
    else
        RestoreMemberRowBorder(target)
    end
    StopDwellTimer()
end

EnsureCategoryReorder = function()
    if categoryReorder then return categoryReorder end
    local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
    categoryReorder = OneWoW_GUI:CreateReorderDrag({
        getItems = function()
            return categoryRowFrames
        end,
        dropIndicator = {
            thickness         = 2,
            horizontalPadding = 6,
            color             = { r, g, b, 1 },
        },
        autoScroll = {
            getFrame = function() return leftScrollFrame end,
            edgeZone = 40,
            maxSpeed = 14,
            minSpeed = 2,
        },
        onPickup = function(row)
            ApplyMemberRowReorderVisual(row, true)
        end,
        onRestore = function(row)
            ApplyMemberRowReorderVisual(row, false)
            StopDwellTimer()
        end,
        onHover = function(target, _, insertBefore)
            ApplyCategoryHoverVisual(target, insertBefore)
        end,
        onUnhover = function(target)
            ClearCategoryHoverVisual(target)
        end,
        onReorder = function(fromIdx, toIdx, insertBefore)
            local src = categoryRowFrames and categoryRowFrames[fromIdx]
            local tgt = categoryRowFrames and categoryRowFrames[toIdx]
            if not src or not tgt or src._catMgrKind ~= "member" then return end
            if tgt == src then return end

            local destSection, destIdx
            if tgt._catMgrKind == "header" then
                destSection = tgt._catMgrSectionID
                destIdx = 1
            else
                destSection = tgt._catMgrSectionID
                destIdx = insertBefore and tgt._catMgrSectionIdx or (tgt._catMgrSectionIdx + 1)
            end
            local controller = GetController()
            if controller and controller.MoveCategoryToSection then
                controller:MoveCategoryToSection(src._catMgrSectionID, src._catMgrSectionIdx,
                                                 destSection, destIdx)
            end
        end,
    })
    return categoryReorder
end

BuildSectionMemberRows = function(secRow, section, sectionID, startY)
    local customCats = db.global.customCategoriesV2
    local disabled   = db.global.disabledCategories
    local reorder    = EnsureCategoryReorder()

    local y = startY
    local cats = section.categories or {}
    for catIdx, catName in ipairs(cats) do
        local isBuiltin = BUILTIN_PRIORITY[catName] ~= nil
        local catData, catID = nil, nil
        if not isBuiltin then
            for id, data in pairs(customCats) do
                if data.name == catName then catData = data; catID = id; break end
            end
        end
        local key = isBuiltin and ("builtin:" .. catName) or catID
        if key then
            local isSelCat = (selectedCatKey == key)

            local row = CreateFrame("Button", nil, leftWrapper, "BackdropTemplate")
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", 16, -y)
            row:SetPoint("RIGHT",   leftWrapper, "RIGHT",    0, 0)
            row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            ---@diagnostic disable-next-line: param-type-mismatch
            tinsert(leftLayoutFrames, { frame = row, origX = 16, origY = y })
            secRow._catMgrTailIndex = #leftLayoutFrames
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

            row._catMgrKind       = "member"
            row._catMgrSectionID  = sectionID
            row._catMgrSectionIdx = catIdx
            row._catMgrSelected   = isSelCat

            local captEKey = key
            row:SetScript("OnClick", function()
                if reorder:IsActive() then return end
                selectedCatKey = captEKey
                CatMgrUI:Refresh()
            end)

            local captName = catName
            row:SetScript("OnEnter", function(self)
                if reorder:IsActive() then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local locKey = BUILTIN_LOCALE_KEYS[captName]
                GameTooltip:SetText((locKey and L[locKey]) or captName, 1, 1, 1)
                GameTooltip:AddLine(" ")
                local tr, tg, tb = OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
                GameTooltip:AddLine(L["CATEGORY_REORDER_HINT"], tr, tg, tb, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", GameTooltip_Hide)

            local nameX = 8
            if catName ~= "Other" then
                local capN2 = catName
                local isDisabled2 = disabled[catName]
                local cb2 = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                cb2:SetSize(16, 16)
                cb2:SetPoint("LEFT", row, "LEFT", 4, 0)
                cb2:SetChecked(not isDisabled2)
                cb2:SetScript("OnClick", function(self)
                    local controller = GetController()
                    if controller and controller.SetCategoryEnabled then
                        controller:SetCategoryEnabled(capN2, self:GetChecked())
                    end
                end)
                nameX = 22
            end

            local locKey2 = BUILTIN_LOCALE_KEYS[catName]
            local nTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nTxt:SetPoint("LEFT",  row,  "LEFT",  nameX, 0)
            nTxt:SetPoint("RIGHT", row,  "RIGHT", -6, 0)
            nTxt:SetJustifyH("LEFT")
            nTxt:SetText((locKey2 and L[locKey2]) or catName)
            if isSelCat then
                nTxt:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                nTxt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            tinsert(secRow._catMgrMemberRows, row)
            ---@diagnostic disable-next-line: param-type-mismatch
            tinsert(categoryRowFrames, row)
            reorder:Attach(row)
            y = y + MEMBER_ROW_HEIGHT
        end
    end
    return y
end

InlineExpandSection = function(sectionID, secRow)
    if not secRow or not leftWrapper or not leftLayoutFrames then return end
    local section = db.global.categorySections[sectionID]
    if not section or not section.collapsed then return end

    section.collapsed = false

    local tailIdx = secRow._catMgrTailIndex
    if not tailIdx or not leftLayoutFrames[tailIdx] then return end
    local headerEntry = leftLayoutFrames[tailIdx]

    local trailing = {}
    for i = tailIdx + 1, #leftLayoutFrames do
        trailing[#trailing + 1] = leftLayoutFrames[i]
        leftLayoutFrames[i] = nil
    end

    local startY = headerEntry.origY + SECTION_ROW_HEIGHT
    local newEndY = BuildSectionMemberRows(secRow, section, sectionID, startY)
    local dy = newEndY - startY
    local addedCount = #leftLayoutFrames - tailIdx

    for _, e in ipairs(trailing) do
        e.origY = e.origY + dy
        e.frame:ClearAllPoints()
        e.frame:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", e.origX, -e.origY)
        e.frame:SetPoint("RIGHT",   leftWrapper, "RIGHT",   0, 0)
        tinsert(leftLayoutFrames, e)
    end

    if sectionRowFrames then
        for i = 1, #sectionRowFrames do
            local otherRow = sectionRowFrames[i]
            if otherRow ~= secRow and otherRow._catMgrTailIndex and otherRow._catMgrTailIndex > tailIdx then
                otherRow._catMgrTailIndex = otherRow._catMgrTailIndex + addedCount
            end
        end
    end

    local newH = (leftWrapper._catMgrBaseHeight or leftWrapper:GetHeight()) + dy
    leftWrapper._catMgrBaseHeight = newH
    leftWrapper:SetHeight(newH)
    if leftScrollFrame then
        leftScrollFrame:GetScrollChild():SetHeight(newH)
    end

    if secRow._catMgrCollapseTex then
        secRow._catMgrCollapseTex:SetAtlas("uitools-icon-chevron-down")
    end
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
        showHeaderBankCB:SetPoint("TOPLEFT", showHeaderCB, "BOTTOMLEFT", 0, -6)
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

        local totalH = 96
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
    local GROUP_OPTIONS = { "none", "expansion", "type", "slot", "quality", "equipmentset" }
    local GROUP_LABELS = { L["GROUP_NONE"], L["GROUP_EXPANSION"], L["GROUP_TYPE"], L["GROUP_SLOT"], L["GROUP_QUALITY"], L["GROUP_EQUIPMENT_SET"] }
    local PRIORITY_OPTIONS = { -2, -1, 0, 1, 2, 3 }
    local PRIORITY_LABELS = { L["PRIORITY_LOWEST"], L["PRIORITY_LOW"], L["PRIORITY_NORMAL"], L["PRIORITY_HIGH"], L["PRIORITY_HIGHEST"], L["PRIORITY_MAX"] }

    local LABEL_X   = 16
    local CONTROL_X = 140
    local ROW_H     = 26
    local DROPDOWN_W = 140
    local DROPDOWN_H = 22

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
            ruleLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", LABEL_X, yPos)
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
        filterLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", LABEL_X, yPos)
        filterLbl:SetText(L["CAT_MATCH_MODE"])
        filterLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local typeFilterBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = L["CAT_MATCH_BY_TYPE"], height = 20, minWidth = 70, toggleable = true })
        typeFilterBtn:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", CONTROL_X, yPos + 2)
        local advFilterBtn = OneWoW_GUI:CreateFitTextButton(rightTopWrapper, { text = L["CAT_MATCH_ADVANCED"], height = 20, minWidth = 70, toggleable = true })
        advFilterBtn:SetPoint("LEFT", typeFilterBtn, "RIGHT", 4, 0)

        local filterContent = CreateFrame("Frame", nil, rightTopWrapper)
        filterContent:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", 0, yPos - 26)
        filterContent:SetPoint("RIGHT", rightTopWrapper, "RIGHT", 0, 0)

        local function BuildTypeFilter(parent)
            local fY = -4
            local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            desc:SetPoint("TOPLEFT", parent, "TOPLEFT", LABEL_X, fY)
            desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, fY)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetText(L["CAT_TYPE_FILTER_DESC"])
            desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            fY = fY - desc:GetStringHeight() - 12

            local tLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", LABEL_X, fY)
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
            tBox:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTROL_X, fY + 2)
            tBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - ROW_H

            local sLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", LABEL_X, fY)
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
            sBox:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTROL_X, fY + 2)
            sBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - ROW_H

            local mLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            mLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", LABEL_X, fY)
            mLbl:SetText(L["CAT_TYPE_MATCH_MODE"])
            mLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            local curMode = catData.typeMatchMode or "and"
            local andB = OneWoW_GUI:CreateFitTextButton(parent, { text = L["CAT_TYPE_MATCH_AND"], height = 20, minWidth = 40, toggleable = true })
            andB:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTROL_X, fY + 2)
            local orB = OneWoW_GUI:CreateFitTextButton(parent, { text = L["CAT_TYPE_MATCH_OR"], height = 20, minWidth = 40, toggleable = true })
            orB:SetPoint("LEFT", andB, "RIGHT", 4, 0)
            andB:SetActive(curMode ~= "or")
            orB:SetActive(curMode == "or")
            andB:SetScript("OnClick", function()
                local controller = GetController()
                if controller and controller.SetCustomCategoryValue then
                    controller:SetCustomCategoryValue(capturedID, "typeMatchMode", "and")
                end
                andB:SetActive(true); orB:SetActive(false)
            end)
            orB:SetScript("OnClick", function()
                local controller = GetController()
                if controller and controller.SetCustomCategoryValue then
                    controller:SetCustomCategoryValue(capturedID, "typeMatchMode", "or")
                end
                andB:SetActive(false); orB:SetActive(true)
            end)
            fY = fY - 26 - 8
            return abs(fY)
        end

        local function BuildSearchFilter(parent)
            local fY = -4
            local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            desc:SetPoint("TOPLEFT", parent, "TOPLEFT", LABEL_X, fY)
            desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, fY)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(true)
            desc:SetText(L["SEARCH_HELP_DESC"])
            desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            fY = fY - desc:GetStringHeight() - 12

            local sBox = MakeEditBoxWithSave(parent,
                { width=200, height=22, placeholderText = L["SEARCH_HELP_PLACEHOLDER"] },
                function() return catData.searchExpression end,
                function(v)
                    local controller = GetController()
                    if controller and controller.SetCustomCategoryValue then
                        controller:SetCustomCategoryValue(capturedID, "searchExpression", v)
                    end
                end)
            sBox:SetPoint("TOPLEFT", parent, "TOPLEFT", LABEL_X, fY)
            sBox:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
            fY = fY - 28

            local helpLines = {
                L["SEARCH_HELP_OPERATORS"],
                L["SEARCH_HELP_ILVL"],
                L["SEARCH_HELP_EXAMPLE"],
            }
            for _, line in ipairs(helpLines) do
                if line ~= "" then
                    local hl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    hl:SetPoint("TOPLEFT", parent, "TOPLEFT", LABEL_X, fY)
                    hl:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, fY)
                    hl:SetJustifyH("LEFT")
                    hl:SetWordWrap(true)
                    hl:SetText(line)
                    hl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    fY = fY - hl:GetStringHeight() - 2
                end
            end
            fY = fY - 8
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
            typeFilterBtn:SetActive(mode == "type")
            advFilterBtn:SetActive(mode == "search")
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
    yPos = yPos - 10

    local function BuildLabelRow(textKey, yOffset)
        local lbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", LABEL_X, yOffset)
        lbl:SetText(L[textKey])
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        return lbl
    end

    local function LabelFromOptions(options, labels, value, fallbackIdx)
        for i, v in ipairs(options) do
            if v == value then return labels[i] end
        end
        return labels[fallbackIdx or 1]
    end

    BuildLabelRow("CAT_SORT", yPos)
    local currentSort = catMod.sortMode or "none"
    local sortDropdown, sortDropdownText = OneWoW_GUI:CreateDropdown(rightTopWrapper, {
        width = DROPDOWN_W,
        height = DROPDOWN_H,
        text = LabelFromOptions(SORT_OPTIONS, SORT_LABELS, currentSort, 1),
    })
    sortDropdown:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", CONTROL_X, yPos + 2)
    OneWoW_GUI:AttachFilterMenu(sortDropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for i, v in ipairs(SORT_OPTIONS) do
                tinsert(items, { text = SORT_LABELS[i], value = v })
            end
            return items
        end,
        getActiveValue = function() return catMod.sortMode or "none" end,
        onSelect = function(value, text)
            sortDropdownText:SetText(text)
            local controller = GetController()
            if controller and controller.SetCategorySortMode then
                controller:SetCategorySortMode(capCatName, value)
            end
        end,
    })
    yPos = yPos - ROW_H

    BuildLabelRow("GROUP_BY", yPos)
    local currentGroup = catMod.groupBy or "none"
    local groupDropdown, groupDropdownText = OneWoW_GUI:CreateDropdown(rightTopWrapper, {
        width = DROPDOWN_W,
        height = DROPDOWN_H,
        text = LabelFromOptions(GROUP_OPTIONS, GROUP_LABELS, currentGroup, 1),
    })
    groupDropdown:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", CONTROL_X, yPos + 2)
    OneWoW_GUI:AttachFilterMenu(groupDropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for i, v in ipairs(GROUP_OPTIONS) do
                tinsert(items, { text = GROUP_LABELS[i], value = v })
            end
            return items
        end,
        getActiveValue = function() return catMod.groupBy or "none" end,
        onSelect = function(value, text)
            groupDropdownText:SetText(text)
            local controller = GetController()
            if controller and controller.SetCategoryGroupBy then
                controller:SetCategoryGroupBy(capCatName, value)
            end
        end,
    })
    yPos = yPos - ROW_H

    BuildLabelRow("PRIORITY", yPos)
    local currentPrio = catMod.priority or 0
    local prioDropdown, prioDropdownText = OneWoW_GUI:CreateDropdown(rightTopWrapper, {
        width = DROPDOWN_W,
        height = DROPDOWN_H,
        text = LabelFromOptions(PRIORITY_OPTIONS, PRIORITY_LABELS, currentPrio, 3),
    })
    prioDropdown:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", CONTROL_X, yPos + 2)
    OneWoW_GUI:AttachFilterMenu(prioDropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for i, v in ipairs(PRIORITY_OPTIONS) do
                tinsert(items, { text = PRIORITY_LABELS[i], value = v })
            end
            return items
        end,
        getActiveValue = function() return catMod.priority or 0 end,
        onSelect = function(value, text)
            prioDropdownText:SetText(text)
            local controller = GetController()
            if controller and controller.SetCategoryPriority then
                controller:SetCategoryPriority(capCatName, value)
            end
        end,
    })
    yPos = yPos - ROW_H

    BuildLabelRow("COLOR", yPos)
    local colorSwatch = CreateFrame("Button", nil, rightTopWrapper, "BackdropTemplate")
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", CONTROL_X, yPos + 2)
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
    clearColorBtn:SetPoint("LEFT", colorSwatch, "RIGHT", 6, 0)
    clearColorBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.ClearCategoryColor then
            controller:ClearCategoryColor(capCatName)
        end
        colorSwatch:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end)
    yPos = yPos - ROW_H

    BuildLabelRow("APPLIES_TO", yPos)

    local appliesContainers = {
        { key = "backpack", label = L["APPLIES_BACKPACK"] },
        { key = "character_bank", label = L["APPLIES_CHAR_BANK"] },
        { key = "warband_bank", label = L["APPLIES_WARBAND_BANK"] },
    }
    local appliesX = CONTROL_X
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
        appliesX = appliesX + 20 + cbLbl:GetStringWidth() + 14
    end
    yPos = yPos - ROW_H

    BuildLabelRow("CAT_FORCE_OWN_LINE", yPos)

    local compactForKey = {
        backpack       = db.global.compactCategories and true or false,
        character_bank = OneWoW_Bags.BankController:GetFor("personal", "compactCategories") and true or false,
        warband_bank   = OneWoW_Bags.BankController:GetFor("warband", "compactCategories") and true or false,
    }

    local ownLineX = CONTROL_X
    for _, hc in ipairs(appliesContainers) do
        local cb = CreateFrame("CheckButton", nil, rightTopWrapper, "UICheckButtonTemplate")
        cb:SetSize(18, 18)
        cb:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", ownLineX, yPos + 2)
        cb:SetChecked(catMod.forceOwnLine and catMod.forceOwnLine[hc.key] and true or false)

        local isApplied = not (catMod.appliesIn and catMod.appliesIn[hc.key] == false)
        local enabled = isApplied and compactForKey[hc.key]

        local lbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        lbl:SetText(hc.label)

        if enabled then
            cb:Enable()
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            cb:Disable()
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        local capKey = hc.key
        cb:SetScript("OnClick", function(self)
            local controller = GetController()
            if controller and controller.SetCategoryForceOwnLine then
                controller:SetCategoryForceOwnLine(capCatName, capKey, self:GetChecked())
            end
        end)

        ownLineX = ownLineX + 20 + lbl:GetStringWidth() + 14
    end
    yPos = yPos - ROW_H

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
    yPos = yPos - addDescLbl:GetStringHeight() - 10

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
    yPos = yPos - 44

    local addLbl = rightTopWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLbl:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", LABEL_X, yPos)
    addLbl:SetText(L["CATEGORY_ADD_BY_ID"])
    addLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local addBox = OneWoW_GUI:CreateEditBox(rightTopWrapper, { width=120, height=22 })
    addBox:SetPoint("TOPLEFT", rightTopWrapper, "TOPLEFT", CONTROL_X, yPos + 2)
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
    if sectionReorder then
        sectionReorder:Cancel()
    end
    if categoryReorder then
        categoryReorder:Cancel()
    end
    StopDwellTimer()
    EndDragCollapse()
    leftLayoutFrames = nil
    leftWrapper = ReleaseWrapper(leftWrapper)
    if not leftScrollContent then return end

    local sections   = db.global.categorySections
    local sectOrder  = db.global.sectionOrder

    leftWrapper = CreateFrame("Frame", nil, leftScrollContent)
    leftWrapper:SetPoint("TOPLEFT", leftScrollContent, "TOPLEFT", 0, 0)
    leftWrapper:SetPoint("RIGHT",   leftScrollContent, "RIGHT",   0, 0)

    leftLayoutFrames = {}
    local yOffset = 0

    sectionRowFrames = {}
    categoryRowFrames = {}
    local sReorder = EnsureSectionReorder()
    EnsureCategoryReorder()
    for secIdx, sectionID in ipairs(sectOrder) do
        local section = sections[sectionID]
        if section then
            local sKey      = "section:" .. sectionID
            local isSelSec  = (selectedCatKey == sKey)
            local collapsed = section.collapsed

            local secRow = CreateFrame("Button", nil, leftWrapper, "BackdropTemplate")
            secRow:SetHeight(28)
            secRow:SetPoint("TOPLEFT", leftWrapper, "TOPLEFT", 0, -yOffset)
            secRow:SetPoint("RIGHT",   leftWrapper, "RIGHT",   0, 0)
            secRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            secRow:EnableMouse(true)
            secRow:RegisterForClicks("LeftButtonUp")
            secRow._catMgrSelected   = isSelSec
            secRow._catMgrKind       = "header"
            secRow._catMgrSectionID  = sectionID
            tinsert(leftLayoutFrames, { frame = secRow, origX = 0, origY = yOffset })
            secRow._catMgrTailIndex = #leftLayoutFrames

            if isSelSec then
                secRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                secRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                secRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                secRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            end

            local collapseBtn = CreateFrame("Button", nil, secRow)
            collapseBtn:SetSize(22, 22)
            collapseBtn:SetPoint("LEFT", secRow, "LEFT", 2, 0)
            collapseBtn:SetFrameLevel(secRow:GetFrameLevel() + 1)
            local collapseTex = collapseBtn:CreateTexture(nil, "ARTWORK")
            collapseTex:SetAllPoints()
            if collapsed then
                collapseTex:SetAtlas("uitools-icon-chevron-right")
            else
                collapseTex:SetAtlas("uitools-icon-chevron-down")
            end
            collapseTex:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))

            local captSKey = sKey
            local captSecId = sectionID
            collapseBtn:SetScript("OnClick", function()
                local controller = GetController()
                if controller and controller.SetSectionCollapsed then
                    controller:SetSectionCollapsed(captSecId, not section.collapsed)
                end
                selectedCatKey = captSKey
                CatMgrUI:Refresh()
            end)

            local secName = secRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            secName:SetPoint("LEFT", collapseBtn, "RIGHT", 4, 0)
            secName:SetPoint("RIGHT", secRow, "RIGHT", -6, 0)
            secName:SetJustifyH("LEFT")
            secName:SetText(section.name)
            if isSelSec then
                secName:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                secName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            secRow:SetScript("OnClick", function()
                selectedCatKey = captSKey
                CatMgrUI:Refresh()
            end)

            secRow:SetScript("OnEnter", function(self)
                if sReorder:IsActive() or (categoryReorder and categoryReorder:IsActive()) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(section.name, 1, 1, 1)
                GameTooltip:AddLine(" ")
                local tr, tg, tb = OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
                GameTooltip:AddLine(L["SECTION_DRAG_HINT"], tr, tg, tb, true)
                GameTooltip:Show()
            end)
            secRow:SetScript("OnLeave", GameTooltip_Hide)

            secRow._catMgrCollapseTex = collapseTex
            secRow._catMgrMemberRows = {}

            tinsert(sectionRowFrames, secRow)
            tinsert(categoryRowFrames, secRow)
            sReorder:Attach(secRow, secIdx)
            yOffset = yOffset + SECTION_ROW_HEIGHT

            if not collapsed then
                yOffset = BuildSectionMemberRows(secRow, section, sectionID, yOffset)
            end
        end
    end

    local totalH = max(yOffset + 4, 40)
    leftWrapper:SetHeight(totalH)
    leftWrapper._catMgrBaseHeight = totalH
    if leftScrollFrame then
        leftScrollFrame:GetScrollChild():SetHeight(totalH)
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
    managerFrame:HookScript("OnHide", function()
        if sectionReorder then
            sectionReorder:Cancel()
        end
        if categoryReorder then
            categoryReorder:Cancel()
        end
        StopDwellTimer()
    end)

    -- ---- Action bar ----
    local actionBar = CreateFrame("Frame", nil, dialogContentFrame, "BackdropTemplate")
    actionBar:SetPoint("TOPLEFT",  dialogContentFrame, "TOPLEFT",  4, -4)
    actionBar:SetPoint("TOPRIGHT", dialogContentFrame, "TOPRIGHT", -4, -4)
    actionBar:SetHeight(32)
    actionBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    actionBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    actionBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local sectionBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["SECTION_CREATE"], height=24 })
    sectionBtn:SetPoint("LEFT", actionBar, "LEFT", 6, 0)
    sectionBtn:SetScript("OnClick", function() StaticPopup_Show("ONEWOW_BAGS_CREATE_SECTION") end)

    local createBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text=L["CATEGORY_CREATE"], height=24 })
    createBtn:SetPoint("LEFT", sectionBtn, "RIGHT", 6, 0)
    createBtn:SetScript("OnClick", function() StaticPopup_Show("ONEWOW_BAGS_CREATE_CATEGORY") end)

    -- ---- Import / Export / Undo ----
    local Backup = OneWoW_Bags.ImportExport and OneWoW_Bags.ImportExport.Backup
    local Serializer = OneWoW_Bags.ImportExport and OneWoW_Bags.ImportExport.Serializer
    local Planner = OneWoW_Bags.ImportExport and OneWoW_Bags.ImportExport.Planner
    local ImportPreview = OneWoW_Bags.ImportPreview
    local LibCopyPaste = LibStub and LibStub("LibCopyPaste-1.0", true)

    -- Undo (icon-only) pinned to the far right
    local undoBtn = CreateFrame("Button", nil, actionBar, "BackdropTemplate")
    undoBtn:SetSize(22, 22)
    undoBtn:SetPoint("RIGHT", actionBar, "RIGHT", -6, 0)
    local undoTex = undoBtn:CreateTexture(nil, "ARTWORK")
    undoTex:SetAllPoints(undoBtn)
    undoTex:SetAtlas("common-icon-undo")
    local function refreshUndoBtn()
        if Backup and Backup:HasBackup(GetDB()) then
            undoBtn:Enable()
            undoTex:SetDesaturated(false)
        else
            undoBtn:Disable()
            undoTex:SetDesaturated(true)
        end
    end
    undoBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if self:IsEnabled() then
            GameTooltip:SetText(L["IMPORT_UNDO_TOOLTIP"] or "Undo last import")
        else
            GameTooltip:SetText(L["IMPORT_UNDO_TOOLTIP_DISABLED"] or "No import to undo")
        end
        GameTooltip:Show()
    end)
    undoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    undoBtn:SetScript("OnClick", function()
        if not Backup or not Backup:HasBackup(GetDB()) then return end
        StaticPopup_Show("ONEWOW_BAGS_UNDO_IMPORT")
    end)
    StaticPopupDialogs["ONEWOW_BAGS_UNDO_IMPORT"] = StaticPopupDialogs["ONEWOW_BAGS_UNDO_IMPORT"] or {
        text = L["IMPORT_UNDO_CONFIRM"] or "Undo the last import and restore previous categories?",
        button1 = YES, button2 = NO,
        OnAccept = function()
            if not Backup then return end
            Backup:Restore(GetDB(), GetController())
            Backup:Clear(GetDB())
            refreshUndoBtn()
            print("|cFFFFD100" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. (L["IMPORT_UNDO_SUCCESS"] or "Import reverted."))
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    -- LibCopyPaste uses DIALOG strata; the Category Manager also uses DIALOG, so
    -- the copy dialog can render at or below it. Discover the singleton frame on
    -- first use (by matching our title text) and raise it to FULLSCREEN_DIALOG.
    local cachedCPFrame
    local function raiseCopyPasteDialog(title)
        if cachedCPFrame and cachedCPFrame:IsShown() then
            cachedCPFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            cachedCPFrame:Raise()
            return
        end
        local children = { UIParent:GetChildren() }
        for i = #children, 1, -1 do
            local child = children[i]
            if child and child.IsShown and child:IsShown() and child.GetFrameStrata then
                for _, region in ipairs({ child:GetRegions() }) do
                    if region.GetText and region:GetText() == title then
                        cachedCPFrame = child
                        child:SetFrameStrata("FULLSCREEN_DIALOG")
                        child:Raise()
                        return
                    end
                end
            end
        end
    end

    -- Export button (right of undo)
    local exportBtn = OneWoW_GUI:CreateFitTextButton(actionBar, { text = L["EXPORT_LABEL"] or "Export", height = 24 })
    exportBtn:SetPoint("RIGHT", undoBtn, "LEFT", -6, 0)
    exportBtn:SetScript("OnClick", function()
        if not Serializer or not LibCopyPaste then return end
        local title = L["EXPORT_DIALOG_TITLE"] or "OneWoW Bags Export"
        local payload = Serializer:Encode(Serializer:BuildExport(GetDB()))
        LibCopyPaste:Copy(title, payload, { readOnly = true })
        raiseCopyPasteDialog(title)
    end)

    -- Import pulldown (right of export button)
    local importDropdown = OneWoW_GUI:CreateDropdown(actionBar, {
        text   = L["IMPORT_FROM_LABEL"] or "Import from...",
        width  = 160,
        height = 24,
    })
    importDropdown:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)

    local function doOpenPreview(plan)
        if not plan or not ImportPreview then return end
        ImportPreview:Show(plan, GetController(), GetDB())
    end

    OneWoW_GUI:AttachFilterMenu(importDropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            local bagAvailable = HasBaganator()
            local tsm = OneWoW_Bags.TSMIntegration
            local tsmAvailable = tsm and tsm.IsAvailable and tsm:IsAvailable()

            tinsert(items, {
                value = "baganator_direct",
                text  = (L["IMPORT_SRC_BAGANATOR_DIRECT"] or "Baganator (direct)")
                    .. (bagAvailable and "" or "  " .. (L["IMPORT_NOT_AVAILABLE_HINT"] or "(not loaded)")),
            })
            tinsert(items, {
                value = "tsm_direct",
                text  = (L["IMPORT_SRC_TSM_DIRECT"] or "TSM (direct)")
                    .. (tsmAvailable and "" or "  " .. (L["IMPORT_NOT_AVAILABLE_HINT"] or "(not loaded)")),
            })
            tinsert(items, { type = "divider" })
            tinsert(items, { value = "onewow_string",    text = L["IMPORT_SRC_ONEWOW_PASTE"]    or "OneWoW string (paste)" })
            tinsert(items, { value = "baganator_string", text = L["IMPORT_SRC_BAGANATOR_PASTE"] or "Baganator string (paste)" })
            return items
        end,
        onSelect = function(value)
            if value == "baganator_direct" then
                if not HasBaganator() then
                    print("|cFFFFD100" .. L["ADDON_CHAT_PREFIX"] .. "|r "
                        .. (L["IMPORT_NOT_AVAILABLE_TOOLTIP"] or "Baganator is not loaded."))
                    return
                end
                doOpenPreview(Planner:FromBaganatorDirect(GetDB()))
            elseif value == "tsm_direct" then
                local tsm = OneWoW_Bags.TSMIntegration
                if not tsm or not tsm:IsAvailable() then
                    print("|cFFFFD100" .. L["ADDON_CHAT_PREFIX"] .. "|r "
                        .. (L["IMPORT_NOT_AVAILABLE_TOOLTIP"] or "TSM is not loaded."))
                    return
                end
                doOpenPreview(Planner:FromTsmDirect(GetDB(), { tsmPrefix = true }))
            elseif value == "onewow_string" and LibCopyPaste then
                local title = L["IMPORT_DIALOG_TITLE"] or "Paste OneWoW export"
                LibCopyPaste:Paste(title, function(text)
                    doOpenPreview(Planner:FromOneWowString(text, GetDB()))
                end)
                raiseCopyPasteDialog(title)
            elseif value == "baganator_string" and LibCopyPaste then
                local title = L["IMPORT_DIALOG_TITLE"] or "Paste Baganator export"
                LibCopyPaste:Paste(title, function(text)
                    doOpenPreview(Planner:FromBaganatorString(text, GetDB()))
                end)
                raiseCopyPasteDialog(title)
            end
        end,
    })

    actionBar:HookScript("OnShow", refreshUndoBtn)
    refreshUndoBtn()

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
        if sectionReorder then
            sectionReorder:Cancel()
        end
        if categoryReorder then
            categoryReorder:Cancel()
        end
        StopDwellTimer()
        managerFrame:Hide()
    else
        CatMgrUI:Show()
    end
end

function CatMgrUI:IsOpen()
    return managerFrame ~= nil and managerFrame:IsShown() == true
end

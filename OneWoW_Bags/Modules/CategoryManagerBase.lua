local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local tinsert, tremove, pairs, ipairs, wipe = tinsert, tremove, pairs, ipairs, wipe

OneWoW_Bags.CategoryManagerBase = {}

--- Walk a list of item buttons, assign each one a category name (or clear it
--- when the slot is empty / lacks itemInfo). Used by both bag and bank
--- category managers — only the button source differs.
---@param buttons table[] item-button list
local function AssignCategoriesForButtons(buttons)
    local Categories = OneWoW_Bags.Categories
    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo then
            button.owb_categoryName = Categories:GetItemCategory(button.owb_bagID, button.owb_slotID, button.owb_itemInfo)
        else
            button.owb_categoryName = nil
        end
    end
end

--- Bucket a list of item buttons by their assigned `owb_categoryName`.
--- Empty / uncategorized slots are skipped.
---@param buttons table[] item-button list
---@return table<string, table[]> itemsByCategory
local function GroupButtonsByCategory(buttons)
    local result = {}
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

local function ClearActiveBuckets(activeBuckets)
    for _, bucket in pairs(activeBuckets) do
        wipe(bucket)
    end
    wipe(activeBuckets)
end

OneWoW_Bags.CategoryManagerBase.AssignCategoriesForButtons = AssignCategoriesForButtons
OneWoW_Bags.CategoryManagerBase.GroupButtonsByCategory = GroupButtonsByCategory

function OneWoW_Bags.CategoryManagerBase:Create()
    local cm = {}
    local sectionPool = {}
    local activeSections = {}
    local dividerPool = {}
    local activeDividers = {}
    local categoryBuckets = {}
    local activeCategoryBuckets = {}

    --- Subclasses set this in their constructor so the base AssignCategories /
    --- GetItemsByCategory methods know which button list to iterate.
    ---@return table[] buttons
    function cm:GetSourceButtons() return {} end

    function cm:AssignCategories()
        self:AssignAndGroupCategories(self:GetSourceButtons())
    end

    function cm:GetItemsByCategory()
        if not self._itemsByCategory then
            self:AssignAndGroupCategories(self:GetSourceButtons())
        end
        return self._itemsByCategory
    end

    function cm:AssignAndGroupCategories(buttons)
        local Profile = OneWoW_Bags.Profile
        Profile:Start("CategoryManager.AssignAndGroupCategories")
        local Categories = OneWoW_Bags.Categories
        ClearActiveBuckets(activeCategoryBuckets)

        for _, button in ipairs(buttons or self:GetSourceButtons()) do
            if button.owb_hasItem and button.owb_itemInfo then
                local categoryName = Categories:GetItemCategory(button.owb_bagID, button.owb_slotID, button.owb_itemInfo)
                button.owb_categoryName = categoryName
                if categoryName then
                    local bucket = categoryBuckets[categoryName]
                    if not bucket then
                        bucket = {}
                        categoryBuckets[categoryName] = bucket
                    end
                    activeCategoryBuckets[categoryName] = bucket
                    tinsert(bucket, button)
                end
            else
                button.owb_categoryName = nil
            end
        end

        self._itemsByCategory = activeCategoryBuckets
        Profile:Stop("CategoryManager.AssignAndGroupCategories")
        return activeCategoryBuckets
    end

    function cm:AcquireSection(parent)
        local section
        if #sectionPool > 0 then
            section = tremove(sectionPool)
            section:SetParent(parent)
            section:Show()
        else
            section = cm:CreateSection(parent)
        end
        activeSections[section] = true
        return section
    end

    function cm:ReleaseSection(section)
        if not section then return end
        section:Hide()
        section:ClearAllPoints()
        activeSections[section] = nil
        tinsert(sectionPool, section)
    end

    function cm:ReleaseAllSections()
        for section in pairs(activeSections) do
            section:Hide()
            section:ClearAllPoints()
            tinsert(sectionPool, section)
        end
        activeSections = {}
        for divider in pairs(activeDividers) do
            divider:Hide()
            divider:ClearAllPoints()
            tinsert(dividerPool, divider)
        end
        activeDividers = {}
    end

    function cm:CreateSection(parent)
        local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        section:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
        section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        section.header = CreateFrame("Button", nil, section)
        section.header:SetHeight(24)
        section.header:SetPoint("TOPLEFT", 0, 0)
        section.header:SetPoint("TOPRIGHT", 0, 0)

        section.collapseBtn = CreateFrame("Button", nil, section.header)
        section.collapseBtn:SetSize(20, 20)
        section.collapseBtn:SetPoint("LEFT", section.header, "LEFT", 4, 0)
        section.collapseBtn:SetFrameLevel(section.header:GetFrameLevel() + 1)
        section.collapseBtn.icon = section.collapseBtn:CreateTexture(nil, "ARTWORK")
        section.collapseBtn.icon:SetAllPoints()

        section.title = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        section.title:SetPoint("LEFT", section.collapseBtn, "RIGHT", 4, 0)
        section.title:SetJustifyH("LEFT")

        section.count = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        section.count:SetPoint("RIGHT", -8, 0)
        section.count:SetJustifyH("RIGHT")

        section.content = CreateFrame("Frame", nil, section)
        section.content:SetPoint("TOPLEFT", section.header, "BOTTOMLEFT", 0, -2)
        section.content:SetPoint("TOPRIGHT", section.header, "BOTTOMRIGHT", 0, -2)

        section.isCollapsed = false

        return section
    end

    function cm:AcquireDivider(parent)
        local divider
        if #dividerPool > 0 then
            divider = tremove(dividerPool)
            divider:SetParent(parent)
            divider:Show()
        else
            divider = parent:CreateTexture(nil, "ARTWORK")
            divider:SetHeight(1)
        end
        activeDividers[divider] = true
        return divider
    end

    function cm:AcquireSectionHeader(parent)
        return cm:AcquireSection(parent)
    end

    return cm
end

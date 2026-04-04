local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local tinsert, tremove = tinsert, tremove

OneWoW_Bags.CategoryManagerBase = {}

function OneWoW_Bags.CategoryManagerBase:Create(refreshTargetKey)
    local cm = {}
    local sectionPool = {}
    local activeSections = {}
    local dividerPool = {}
    local activeDividers = {}

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

        section.title = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        section.title:SetPoint("LEFT", 8, 0)
        section.title:SetJustifyH("LEFT")

        section.count = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        section.count:SetPoint("RIGHT", -8, 0)
        section.count:SetJustifyH("RIGHT")

        section.content = CreateFrame("Frame", nil, section)
        section.content:SetPoint("TOPLEFT", section.header, "BOTTOMLEFT", 0, -2)
        section.content:SetPoint("TOPRIGHT", section.header, "BOTTOMRIGHT", 0, -2)

        section.isCollapsed = false

        section.header:SetScript("OnClick", function()
            section.isCollapsed = not section.isCollapsed
            local target = OneWoW_Bags[refreshTargetKey]
            if target and target.RefreshLayout then
                target:RefreshLayout()
            end
        end)

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

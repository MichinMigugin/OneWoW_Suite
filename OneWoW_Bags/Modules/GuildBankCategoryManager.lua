local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankCategoryManager = {}
local CM = OneWoW_Bags.GuildBankCategoryManager

local sectionPool = {}
local activeSections = {}

function CM:AcquireSection(parent)
    local section
    if #sectionPool > 0 then
        section = table.remove(sectionPool)
        section:SetParent(parent)
        section:Show()
    else
        section = CM:CreateSection(parent)
    end
    activeSections[section] = true
    return section
end

function CM:ReleaseSection(section)
    if not section then return end
    section:Hide()
    section:ClearAllPoints()
    activeSections[section] = nil
    table.insert(sectionPool, section)
end

function CM:ReleaseAllSections()
    for section in pairs(activeSections) do
        section:Hide()
        section:ClearAllPoints()
        table.insert(sectionPool, section)
    end
    activeSections = {}
end

function CM:CreateSection(parent)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

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
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            OneWoW_Bags.GuildBankGUI:RefreshLayout()
        end
    end)

    return section
end

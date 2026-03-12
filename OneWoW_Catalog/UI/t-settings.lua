-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-settings.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local OneWoWCatalog = OneWoW_Catalog
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = ns.UI.CreateScrollFrame(nil, parent, parent:GetWidth(), parent:GetHeight())
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local yOffset = -10

    local dbSection = ns.UI.CreateSectionHeader(scrollContent, L["DATA_MANAGER_TITLE"], yOffset)
    yOffset = dbSection.bottomY - 8

    local dbDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbDesc:SetPoint("TOPLEFT", 15, yOffset)
    dbDesc:SetPoint("TOPRIGHT", -15, yOffset)
    dbDesc:SetJustifyH("LEFT")
    dbDesc:SetWordWrap(true)
    dbDesc:SetText(L["DATA_MANAGER_DESC"])
    dbDesc:SetTextColor(T("TEXT_SECONDARY"))
    dbDesc:SetSpacing(3)
    yOffset = yOffset - 30

    local databases = {
        { key = "OneWoW_Catalog",              name = "Catalog Core",       desc = "Main addon settings and UI state" },
        { key = "OneWoW_CatalogData_Journal",  name = "Journal Data",       desc = "Instance and encounter journal data" },
        { key = "OneWoW_CatalogData_Vendors",  name = "Vendors Data",       desc = "Vendor and item data" },
        { key = "OneWoW_CatalogData_Tradeskills", name = "Tradeskills Data",desc = "Profession and recipe data" },

    }

    local function GetTableSize(dbKey)
        if not _G[dbKey .. "_DB"] then return 0 end
        local db = _G[dbKey .. "_DB"]
        local size = 0
        for _ in pairs(db) do size = size + 1 end
        return math.max(0, size - 5)
    end

    local function CreateDatabaseEntry(parent, dbData, yPos)
        local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yPos)
        container:SetSize(770, 60)
        container:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        container:SetBackdropColor(T("BG_TERTIARY"))
        container:SetBackdropBorderColor(T("BORDER_DEFAULT"))

        local nameText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", 12, -10)
        nameText:SetText(dbData.name)
        nameText:SetTextColor(T("TEXT_PRIMARY"))

        local descText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descText:SetPoint("TOPLEFT", 12, -28)
        descText:SetText(dbData.desc)
        descText:SetTextColor(T("TEXT_SECONDARY"))
        descText:SetWidth(400)

        local sizeText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sizeText:SetPoint("TOPLEFT", 450, -18)

        local function UpdateSize()
            local db = _G[dbData.key .. "_DB"]
            if db then
                local size = GetTableSize(dbData.key)
                sizeText:SetText("Entries: " .. size)
                sizeText:SetTextColor(T("TEXT_SECONDARY"))
            else
                sizeText:SetText("Not Loaded")
                sizeText:SetTextColor(1, 0.5, 0.5)
            end
        end
        UpdateSize()

        local resetBtn = ns.UI.CreateFitTextButton(container, "Reset", { height = 28, minWidth = 75 })
        resetBtn:SetPoint("TOPRIGHT", -12, -16)
        resetBtn:SetBackdropColor(1, 0.3, 0.3)
        resetBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 0.1, 0.1) end)
        resetBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 0.3, 0.3) end)

        resetBtn:SetScript("OnClick", function()
            StaticPopupDialogs["OWCAT_RESET_DB_CONFIRM"] = {
                text = "Are you sure you want to reset " .. dbData.name .. "?\n\nThis will permanently delete all data in this database.",
                button1 = "Reset",
                button2 = "Cancel",
                OnAccept = function()
                    _G[dbData.key .. "_DB"] = nil
                    C_UI.Reload()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("OWCAT_RESET_DB_CONFIRM")
        end)

        return 65
    end

    for _, dbData in ipairs(databases) do
        local height = CreateDatabaseEntry(scrollContent, dbData, yOffset)
        yOffset = yOffset - height - 8
    end

    yOffset = yOffset - 20
    scrollContent:SetHeight(math.abs(yOffset) + 20)
end

-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-settings.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local OneWoWCatalog = OneWoW_Catalog
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

ns.UI = ns.UI or {}

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(parent, { width = parent:GetWidth(), height = parent:GetHeight() })
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local yOffset = -10

    if not _G.OneWoW then
        yOffset = OneWoW_GUI:CreateSettingsPanel(scrollContent, {
            yOffset = yOffset, addonName = "OneWoW_Catalog"
        })
    end

    local dbSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = L["DATA_MANAGER_TITLE"], yOffset = yOffset })
    yOffset = dbSection.bottomY - 8

    local dbDesc = OneWoW_GUI:CreateFS(scrollContent, 12)
    dbDesc:SetPoint("TOPLEFT", 15, yOffset)
    dbDesc:SetPoint("TOPRIGHT", -15, yOffset)
    dbDesc:SetJustifyH("LEFT")
    dbDesc:SetWordWrap(true)
    dbDesc:SetText(L["DATA_MANAGER_DESC"])
    dbDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
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
        local container = OneWoW_GUI:CreateFrame(parent, {
            width = 770, height = 60,
            backdrop = BACKDROP_INNER_NO_INSETS,
            bgColor = "BG_TERTIARY",
            borderColor = "BORDER_DEFAULT",
        })
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yPos)

        local nameText = OneWoW_GUI:CreateFS(container, 12)
        nameText:SetPoint("TOPLEFT", 12, -10)
        nameText:SetText(dbData.name)
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local descText = OneWoW_GUI:CreateFS(container, 10)
        descText:SetPoint("TOPLEFT", 12, -28)
        descText:SetText(dbData.desc)
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        descText:SetWidth(400)

        local sizeText = OneWoW_GUI:CreateFS(container, 10)
        sizeText:SetPoint("TOPLEFT", 450, -18)

        local function UpdateSize()
            local db = _G[dbData.key .. "_DB"]
            if db then
                local size = GetTableSize(dbData.key)
                sizeText:SetText("Entries: " .. size)
                sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            else
                sizeText:SetText("Not Loaded")
                sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            end
        end
        UpdateSize()

        local resetBtn = OneWoW_GUI:CreateFitTextButton(container, { text = "Reset", height = 28, minWidth = 75 })
        resetBtn:SetPoint("TOPRIGHT", -12, -16)
        resetBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
        resetBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER")) end)
        resetBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL")) end)

        resetBtn:SetScript("OnClick", function()
            OneWoW_GUI:CreateConfirmDialog({
                title = "Reset " .. dbData.name,
                text = "Are you sure you want to reset " .. dbData.name .. "?\n\nThis will permanently delete all data in this database.",
                confirmText = "Reset",
                cancelText = "Cancel",
                showBrand = true,
                onConfirm = function()
                    _G[dbData.key .. "_DB"] = nil
                    C_UI.Reload()
                end,
            })
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

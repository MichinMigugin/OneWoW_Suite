local _, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local L = ns.L
ns.UI = ns.UI or {}

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(parent, { width = parent:GetWidth(), height = parent:GetHeight() })
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local yOffset = -10

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
        { key = "OneWoW_Catalog",               nameKey = "SETTINGS_DB_NAME_CATALOG",    descKey = "SETTINGS_DB_DESC_CATALOG" },
        { key = "OneWoW_CatalogData_Journal",   nameKey = "SETTINGS_DB_NAME_JOURNAL",    descKey = "SETTINGS_DB_DESC_JOURNAL" },
        { key = "OneWoW_CatalogData_Vendors",   nameKey = "SETTINGS_DB_NAME_VENDORS",    descKey = "SETTINGS_DB_DESC_VENDORS" },
        { key = "OneWoW_CatalogData_Tradeskills", nameKey = "SETTINGS_DB_NAME_TRADESKILLS", descKey = "SETTINGS_DB_DESC_TRADESKILLS" },
    }

    local function GetTableSize(dbKey)
        local svGlobal = _G[dbKey .. "_DB"]
        if not svGlobal then return 0 end
        local db = svGlobal
        local size = 0
        for _ in pairs(db) do size = size + 1 end
        return math.max(0, size - 5)
    end

    local function ApplyDangerResetVisual(myself, hovering)
        if hovering then
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER_HOVER"))
            if myself.text then
                myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        else
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            if myself.text then
                myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
    end

    local function CreateDatabaseEntry(myparent, dbData, yPos)
        local container = OneWoW_GUI:CreateFrame(myparent, {
            width = 770, height = 60,
            backdrop = BACKDROP_INNER_NO_INSETS,
            bgColor = "BG_TERTIARY",
            borderColor = "BORDER_DEFAULT",
        })
        container:SetPoint("TOPLEFT", myparent, "TOPLEFT", 15, yPos)

        local displayName = L[dbData.nameKey]

        local nameText = OneWoW_GUI:CreateFS(container, 12)
        nameText:SetPoint("TOPLEFT", 12, -10)
        nameText:SetText(displayName)
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local descText = OneWoW_GUI:CreateFS(container, 10)
        descText:SetPoint("TOPLEFT", 12, -28)
        descText:SetText(L[dbData.descKey])
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        descText:SetWidth(400)

        local sizeText = OneWoW_GUI:CreateFS(container, 10)
        sizeText:SetPoint("TOPLEFT", 450, -18)

        local function UpdateSize()
            local svGlobal = _G[dbData.key .. "_DB"]
            if svGlobal then
                local size = GetTableSize(dbData.key)
                sizeText:SetText(string.format(L["SETTINGS_DB_ENTRIES"], size))
                sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            else
                sizeText:SetText(L["SETTINGS_DB_NOT_LOADED"])
                sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            end
        end
        UpdateSize()

        local resetBtn = OneWoW_GUI:CreateFitTextButton(container, { text = L["SETTINGS_DB_RESET"], height = 28, minWidth = 75 })
        resetBtn:SetPoint("TOPRIGHT", -12, -16)
        ApplyDangerResetVisual(resetBtn, false)
        resetBtn:SetScript("OnEnter", function(myself) ApplyDangerResetVisual(myself, true) end)
        resetBtn:SetScript("OnLeave", function(myself) ApplyDangerResetVisual(myself, false) end)

        resetBtn:SetScript("OnClick", function()
            OneWoW_GUI:CreateConfirmDialog({
                title = string.format(L["SETTINGS_DB_RESET_TITLE"], displayName),
                text = string.format(L["SETTINGS_DB_RESET_TEXT"], displayName),
                confirmText = L["SETTINGS_DB_RESET"],
                cancelText = L["SETTINGS_DIALOG_CANCEL"],
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

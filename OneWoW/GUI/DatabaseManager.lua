local OneWoW_GUI = OneWoW_GUI

local Constants = OneWoW_GUI.Constants

local ROW_HEIGHT = 60
local ROW_GAP = 8

local function SharedL()
    return OneWoW.Locale:GetTable("shared")
end

local function CanResetAddon(addonKey)
    local state = OneWoW:GetFeatureUnitState(addonKey)
    return state == "all" or state == "some" or state == "pending_disable"
end

---@class OneWoW_GUI_DatabaseManagerRowOptions
---@field name string
---@field description string
---@field addonKey string
---@field yOffset number
---@field getEntryCount fun(): number|nil  nil when the SV is not loaded

--- Database Manager row: name + description left; Entries + Reset right-aligned column.
--- Used by Catalog and AltTracker settings (identical chrome and layout).
---@param parent Frame
---@param options OneWoW_GUI_DatabaseManagerRowOptions
---@return number height  row height + gap for stacking (caller: y = y - height)
function OneWoW_GUI:CreateDatabaseManagerRow(parent, options)
    options = options or {}
    local name = options.name or ""
    local description = options.description or ""
    local addonKey = options.addonKey
    local yOffset = options.yOffset or 0
    local getEntryCount = options.getEntryCount
    local L = SharedL()

    local container = OneWoW_GUI:CreateFrame(parent, {
        height = ROW_HEIGHT,
        backdrop = Constants.BACKDROP_INNER_NO_INSETS,
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_DEFAULT",
    })
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -15, yOffset)

    local resetEnabled = addonKey and CanResetAddon(addonKey)
    local resetBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = RESET,
        height = 28,
        danger = true,
    })
    resetBtn:SetPoint("RIGHT", container, "RIGHT", -12, 0)

    local sizeText = OneWoW_GUI:CreateFS(container, 10)
    sizeText:SetJustifyH("RIGHT")
    sizeText:SetPoint("RIGHT", resetBtn, "LEFT", -12, 0)
    sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local nameText = OneWoW_GUI:CreateFS(container, 12)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetPoint("TOPLEFT", container, "TOPLEFT", 12, -10)
    nameText:SetPoint("RIGHT", sizeText, "LEFT", -12, 0)
    nameText:SetText(name)
    nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local descText = OneWoW_GUI:CreateFS(container, 10)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetPoint("TOPLEFT", container, "TOPLEFT", 12, -28)
    descText:SetPoint("RIGHT", sizeText, "LEFT", -12, 0)
    descText:SetText(description)
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local function UpdateSize()
        local count = getEntryCount and getEntryCount()
        if count ~= nil then
            sizeText:SetText(string.format(L["DATABASE_MANAGER_ENTRIES"], count))
            sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        else
            sizeText:SetText(L["DATABASE_MANAGER_NOT_LOADED"])
            sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        end
    end
    UpdateSize()

    if resetEnabled then
        resetBtn:SetScript("OnClick", function()
            local confirmResult = OneWoW_GUI:CreateConfirmDialog({
                title = string.format(L["DATABASE_MANAGER_RESET_TITLE"], name),
                message = string.format(L["DATABASE_MANAGER_RESET_TEXT"], name),
                showBrand = true,
                buttons = {
                    { text = RESET, onClick = function(f)
                        if addonKey then
                            _G[addonKey .. "_DB"] = nil
                        end
                        f:Hide()
                        C_UI.Reload()
                    end },
                    { text = CANCEL, onClick = function(f) f:Hide() end },
                },
            })
            OneWoW_GUI:ApplyFontToFrame(confirmResult.frame)
            confirmResult.frame:Show()
        end)
    else
        if resetBtn.text then
            resetBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        resetBtn:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
            GameTooltip:SetText(L["DATABASE_MANAGER_RESET_DISABLED"], nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        resetBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        resetBtn:SetScript("OnClick", nil)
    end

    return ROW_HEIGHT + ROW_GAP
end

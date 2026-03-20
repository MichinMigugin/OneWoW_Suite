local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

function Addon.UI:CreateLuaConsoleTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local clearBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_CLEAR"] or "Clear", width = 80, height = 22 })
    clearBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    clearBtn:SetScript("OnClick", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:ClearErrors()
        end
    end)

    local countLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    countLabel:SetText((Addon.L and Addon.L["LABEL_ERRORS"] or "Errors:") .. " 0")
    countLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local soundCheck = OneWoW_GUI:CreateCheckbox(tab, {
        label = Addon.L and Addon.L["ERR_PLAY_ALERT"] or "Play Alert",
    })
    soundCheck:SetPoint("LEFT", countLabel, "RIGHT", 15, 0)
    soundCheck:SetChecked(Addon.db and Addon.db.errorDB and Addon.db.errorDB.playSound or false)
    soundCheck:SetScript("OnClick", function(self)
        if Addon.db and Addon.db.errorDB then
            Addon.db.errorDB.playSound = self:GetChecked() and true or false
        end
    end)


    local listPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 250 })
    listPanel:ClearAllPoints()
    listPanel:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -5)
    listPanel:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -5, 0)
    listPanel:SetHeight(250)
    self:StyleContentPanel(listPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(listPanel, { name = "ErrorLoggerListScroll" })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 4)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.errorButtons = {}
    for i = 1, 100 do
        local btn = OneWoW_GUI:CreateListRowBasic(listContent, {
            height = 20,
            label = "",
            onClick = function(self)
                if Addon.ErrorLogger and self.errorData then
                    Addon.ErrorLogger:ShowErrorDetails(self.errorData)
                end
            end,
        })
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i-1) * 20 - 2)
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        btn.label:SetFontObject(GameFontNormalSmall)

        tab.errorButtons[i] = btn
    end

    local detailsPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    detailsPanel:ClearAllPoints()
    detailsPanel:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    detailsPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    self:StyleContentPanel(detailsPanel)

    local detailsScroll, detailsContent = OneWoW_GUI:CreateScrollFrame(detailsPanel, { name = "ErrorLoggerDetailsScroll" })
    detailsScroll:ClearAllPoints()
    detailsScroll:SetPoint("TOPLEFT", detailsPanel, "TOPLEFT", 4, -4)
    detailsScroll:SetPoint("BOTTOMRIGHT", detailsPanel, "BOTTOMRIGHT", -14, 4)

    detailsScroll:HookScript("OnSizeChanged", function(self, w)
        detailsContent:SetWidth(w)
    end)

    tab.detailsText = detailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.detailsText:SetPoint("TOPLEFT", 2, -2)
    tab.detailsText:SetPoint("RIGHT", detailsContent, "RIGHT", -2, 0)
    tab.detailsText:SetJustifyH("LEFT")
    tab.detailsText:SetText(Addon.L and Addon.L["LABEL_NO_ERROR"] or "No error selected")
    tab.detailsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_COPY_ERROR"] or "Copy Error", width = 100, height = 25 })
    copyBtn:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    copyBtn:SetScript("OnClick", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:CopyCurrentError()
        end
    end)

    tab.listScroll = listScroll
    tab.detailsScroll = detailsScroll
    tab.countLabel = countLabel

    tab:SetScript("OnShow", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:UpdateUI()
        end
    end)

    Addon.LuaConsoleTab = tab
    return tab
end

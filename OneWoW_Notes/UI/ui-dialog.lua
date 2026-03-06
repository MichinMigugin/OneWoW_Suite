-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/ui-dialog.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
ns.UI = ns.UI or {}
ns.UI.Dialog = {}

ns.UI.Dialog.openDialogs = ns.UI.Dialog.openDialogs or {}
ns.UI.Dialog.currentFrameLevel = ns.UI.Dialog.currentFrameLevel or 100

function ns.UI.Dialog.BringToFront(dialog)
    if not dialog or InCombatLockdown() then return end
    local strata = dialog:GetFrameStrata()
    if strata == "MEDIUM" or strata == "HIGH" then
        dialog:Raise()
        if dialog.header then dialog.header:Raise() end
        if dialog.footer then dialog.footer:Raise() end
    else
        ns.UI.Dialog.currentFrameLevel = ns.UI.Dialog.currentFrameLevel + 10
        dialog:SetFrameLevel(ns.UI.Dialog.currentFrameLevel)
        if dialog.header then dialog.header:SetFrameLevel(dialog:GetFrameLevel() + 1) end
        if dialog.footer then dialog.footer:SetFrameLevel(dialog:GetFrameLevel() + 1) end
    end
end

function ns.UI.Dialog.RegisterDialog(dialog)
    if not dialog then return end
    table.insert(ns.UI.Dialog.openDialogs, dialog)
    ns.UI.Dialog.BringToFront(dialog)
end

function ns.UI.Dialog.UnregisterDialog(dialog)
    if not dialog then return end
    for i, d in ipairs(ns.UI.Dialog.openDialogs) do
        if d == dialog then
            table.remove(ns.UI.Dialog.openDialogs, i)
            break
        end
    end
end

function ns.UI.Dialog.DestroyDialog(dialog)
    if not dialog then return end
    for _, area in ipairs({"content", "content1", "content2", "footer"}) do
        if dialog[area] then
            local children = {dialog[area]:GetChildren()}
            for _, child in ipairs(children) do
                child:Hide()
                child:SetParent(nil)
            end
            dialog[area]:Hide()
            dialog[area]:SetParent(nil)
        end
    end
    dialog:Hide()
    dialog:SetParent(nil)
    dialog:ClearAllPoints()
end

function ns.UI.Dialog.Create(config)
    local dialogName = config.name or "OneWoW_NotesDialog"

    local cachedDialog = ns.UI.Dialog.openDialogs[dialogName]

    if config.destroyOnClose and cachedDialog then
        ns.UI.Dialog.DestroyDialog(cachedDialog)
        ns.UI.Dialog.openDialogs[dialogName] = nil
        cachedDialog = nil
    end

    if cachedDialog and cachedDialog:IsShown() then
        if not InCombatLockdown() then cachedDialog:Raise() end
        return cachedDialog
    end

    if cachedDialog then
        cachedDialog:Show()
        if not InCombatLockdown() then cachedDialog:Raise() end
        return cachedDialog
    end

    local dialog = CreateFrame("Frame", dialogName, UIParent, "BasicFrameTemplate")
    dialog.dialogName = dialogName
    ns.UI.Dialog.openDialogs[dialogName] = dialog

    local width = config.width or 500
    local height = config.height or 400

    dialog:SetSize(width, height)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetClipsChildren(true)
    dialog:SetMovable(true)
    dialog:SetResizable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self)
        ns.UI.Dialog.BringToFront(self)
        self:StartMoving()
    end)
    dialog:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    if config.resizable then
        local minW = config.minWidth or 300
        local minH = config.minHeight or 200
        local maxW = config.maxWidth or 2000
        local maxH = config.maxHeight or 2000
        dialog:SetResizeBounds(minW, minH, maxW, maxH)

        local resizeButton = CreateFrame("Button", nil, dialog)
        resizeButton:SetSize(16, 16)
        resizeButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -2, 2)
        resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeButton:SetFrameLevel(dialog:GetFrameLevel() + 10)
        resizeButton:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then dialog:StartSizing("BOTTOMRIGHT") end
        end)
        resizeButton:SetScript("OnMouseUp", function(self, button)
            dialog:StopMovingOrSizing()
        end)
        dialog.resizeButton = resizeButton
    end

    dialog.TitleText:SetText(config.title or "Dialog")
    dialog.TitleText:SetPoint("TOP", dialog, "TOP", 0, -5)

    dialog.CloseButton:HookScript("OnClick", function()
        if config.onClose then config.onClose() end
        if config.destroyOnClose then
            ns.UI.Dialog.DestroyDialog(dialog)
            ns.UI.Dialog.openDialogs[dialogName] = nil
        end
    end)

    local footerHeight = (config.buttons and #config.buttons > 0) and 40 or 4

    if config.twoContent then
        local contentTop = 32
        local contentBottom = footerHeight + 10
        local content1Height = config.content1Height or math.floor((height - contentTop - contentBottom) / 2) - 5

        local content1 = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        content1:SetPoint("TOPLEFT", dialog, "TOPLEFT", 4, -contentTop)
        content1:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -4, -contentTop)
        content1:SetHeight(content1Height)
        content1:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        content1:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        content1:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        content1:SetClipsChildren(true)

        local content2 = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        content2:SetPoint("TOPLEFT", content1, "BOTTOMLEFT", 0, -10)
        content2:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 4, footerHeight + 10)
        content2:SetPoint("RIGHT", dialog, "RIGHT", -4, 0)
        content2:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        content2:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        content2:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        content2:SetClipsChildren(true)

        dialog.content1 = content1
        dialog.content2 = content2
    else
        local content = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        content:SetPoint("TOPLEFT", dialog, "TOPLEFT", 4, -32)
        content:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 4, footerHeight + 10)
        content:SetPoint("RIGHT", dialog, "RIGHT", -4, 0)
        content:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        content:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        content:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        content:SetClipsChildren(true)
        dialog.content = content
    end

    dialog.header = dialog

    if config.buttons and #config.buttons > 0 then
        local footer = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
        footer:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 4, 4)
        footer:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -4, 4)
        footer:SetHeight(40)
        footer:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        footer:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        footer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        dialog.footer = footer

        local buttonSpacing = 10
        local totalButtons = #config.buttons
        local buttonWidth = 100
        local totalWidth = (buttonWidth * totalButtons) + (buttonSpacing * (totalButtons - 1))
        local startX = (width - totalWidth) / 2 - 4

        for i, buttonConfig in ipairs(config.buttons) do
            local button = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
            button:SetSize(buttonWidth, 30)
            button:SetPoint("LEFT", footer, "LEFT", startX + ((i - 1) * (buttonWidth + buttonSpacing)), 0)
            button:SetText(buttonConfig.text)
            button:SetScript("OnClick", function()
                if buttonConfig.onClick then buttonConfig.onClick(dialog) end
            end)
        end
    end

    dialog:SetScript("OnShow", function(self)
        ns.UI.Dialog.RegisterDialog(self)
    end)

    dialog:SetScript("OnHide", function(self)
        ns.UI.CloseAllOpenDropdowns()
        ns.UI.Dialog.UnregisterDialog(self)
    end)

    if dialogName then
        tinsert(UISpecialFrames, dialogName)
    end

    dialog:Hide()
    return dialog
end

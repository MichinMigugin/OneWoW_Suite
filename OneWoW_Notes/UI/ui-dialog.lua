-- NOTE: this code doesn't seem to be used anywhere (2026-04-27)

local addonName, ns = ...
ns.UI = ns.UI or {}
ns.UI.Dialog = {}

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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

    local width = config.width or 500
    local height = config.height or 400

    local buttonDefs = nil
    if config.buttons and #config.buttons > 0 then
        buttonDefs = {}
        for i, buttonConfig in ipairs(config.buttons) do
            buttonDefs[i] = {
                text = buttonConfig.text,
                onClick = buttonConfig.onClick,
            }
        end
    end

    local dialog = ns.UI.CreateThemedDialog({
        name = dialogName,
        title = config.title or "Dialog",
        width = width,
        height = height,
        buttons = buttonDefs,
        destroyOnClose = config.destroyOnClose,
        onClose = function()
            if config.onClose then config.onClose() end
            if config.destroyOnClose then
                ---@diagnostic disable-next-line: undefined-global
                ns.UI.Dialog.DestroyDialog(dialog)
                ns.UI.Dialog.openDialogs[dialogName] = nil
            end
        end,
    })

    dialog.dialogName = dialogName
    ns.UI.Dialog.openDialogs[dialogName] = dialog

    dialog:SetClipsChildren(true)

    if config.resizable then
        dialog:SetResizable(true)
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

    if config.twoContent then
        local contentParent = dialog.content
        local footerHeight = (config.buttons and #config.buttons > 0) and 40 or 4
        local contentTop = 0
        local contentBottom = 0
        local content1Height = config.content1Height or math.floor(contentParent:GetHeight() / 2) - 5

        local content1 = OneWoW_GUI:CreateFrame(contentParent, {
            width = contentParent:GetWidth() - 8,
            height = content1Height,
            backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
        })
        content1:ClearAllPoints()
        content1:SetPoint("TOPLEFT", contentParent, "TOPLEFT", 4, -4)
        content1:SetPoint("TOPRIGHT", contentParent, "TOPRIGHT", -4, -4)
        content1:SetHeight(content1Height)
        content1:SetClipsChildren(true)

        local content2 = OneWoW_GUI:CreateFrame(contentParent, {
            width = contentParent:GetWidth() - 8,
            height = 100,
            backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
        })
        content2:ClearAllPoints()
        content2:SetPoint("TOPLEFT", content1, "BOTTOMLEFT", 0, -OneWoW_GUI:GetSpacing("SM"))
        content2:SetPoint("BOTTOMRIGHT", contentParent, "BOTTOMRIGHT", -4, 4)
        content2:SetClipsChildren(true)

        dialog.content1 = content1
        dialog.content2 = content2
    end

    dialog.header = dialog

    dialog:HookScript("OnShow", function(self)
        ns.UI.Dialog.RegisterDialog(self)
    end)

    dialog:HookScript("OnHide", function(self)
        ns.UI.CloseAllOpenDropdowns()
        ns.UI.Dialog.UnregisterDialog(self)
    end)

    dialog:Hide()
    return dialog
end

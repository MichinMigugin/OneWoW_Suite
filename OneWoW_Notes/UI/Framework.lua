local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function ns.UI.AutoResizeButton(btn, minWidth, maxWidth)
    if not btn or not btn.text then return end
    local textWidth = btn.text:GetStringWidth()
    local padding = 20
    local currentWidth, currentHeight = btn:GetSize()
    local calculatedWidth = math.max(minWidth or currentWidth, textWidth + padding)
    if maxWidth then
        calculatedWidth = math.min(calculatedWidth, maxWidth)
    end
    btn:SetSize(calculatedWidth, currentHeight)
end

function ns.UI.CreateSplitPanel(parent)
    local panels = OneWoW_GUI:CreateSplitPanel(parent)
    panels.listPanel:ClearAllPoints()
    panels.listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panels.listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)

    panels.detailPanel:ClearAllPoints()
    panels.detailPanel:SetPoint("TOPLEFT", panels.listPanel, "TOPRIGHT", 10, 0)
    panels.detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    return {
        listPanel         = panels.listPanel,
        listTitle         = panels.listTitle,
        listScrollFrame   = panels.listScrollFrame,
        listScrollChild   = panels.listScrollChild,
        UpdateListThumb   = function() end,
        detailPanel       = panels.detailPanel,
        detailTitle       = panels.detailTitle,
        detailScrollFrame = panels.detailScrollFrame,
        detailScrollChild = panels.detailScrollChild,
        UpdateDetailThumb = function() end,
    }
end

local _openDropdowns = {}

function ns.UI.CreateThemedDropdown(parent, labelPrefix, width, height)
    width  = width  or 150
    height = height or 26

    local dropdown, textFS = OneWoW_GUI:CreateDropdown(parent, {
        width  = width,
        height = height,
    })

    dropdown._value       = nil
    dropdown._displayText = ""
    dropdown._labelPrefix = labelPrefix or ""
    dropdown._options     = {}
    dropdown.onSelect     = nil

    local function RefreshText()
        if dropdown._labelPrefix ~= "" then
            textFS:SetText(dropdown._labelPrefix .. ": " .. dropdown._displayText)
        else
            textFS:SetText(dropdown._displayText)
        end
    end

    function dropdown:SetOptions(options) self._options = options end

    function dropdown:SetSelected(value)
        for _, opt in ipairs(self._options) do
            if opt.value == value then
                self._value       = value
                self._displayText = opt.text
                self._activeValue = value
                RefreshText()
                return
            end
        end
    end

    function dropdown:SetText(txt)
        self._displayText = txt
        RefreshText()
    end

    function dropdown:GetText()  return self._displayText end
    function dropdown:GetValue() return self._value       end

    function dropdown:ClosePopup()
        if self._menu and self._menu:IsShown() then
            self._menu:Hide()
        end
    end

    OneWoW_GUI:AttachFilterMenu(dropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(dropdown._options) do
                table.insert(items, { value = opt.value, text = opt.text })
            end
            return items
        end,
        onSelect = function(value, displayText)
            dropdown._value       = value
            dropdown._displayText = displayText
            dropdown._activeValue = value
            RefreshText()
            if dropdown.onSelect then dropdown.onSelect(value, displayText) end
        end,
        getActiveValue = function() return dropdown._value end,
    })

    table.insert(_openDropdowns, dropdown)
    return dropdown
end

function ns.UI.CreateFontDropdown(parent, width, height)
    width  = width  or 150
    height = height or 26

    local dropdown, textFS = OneWoW_GUI:CreateDropdown(parent, {
        width  = width,
        height = height,
    })

    dropdown._value       = nil
    dropdown._displayText = ""
    dropdown._options     = {}
    dropdown.onSelect     = nil

    local function RefreshText()
        textFS:SetText(dropdown._displayText)

        if dropdown._value and dropdown._value ~= "default" then
            local fontPath = OneWoW_GUI:GetFontByKey(dropdown._value)
            if fontPath then
                textFS:SetFont(fontPath, 11, "")
                return
            end
        end
        textFS:SetFontObject("GameFontNormalSmall")
    end

    function dropdown:SetOptions(options) self._options = options end

    function dropdown:SetSelected(value)
        for _, opt in ipairs(self._options) do
            if opt.value == value then
                self._value       = value
                self._displayText = opt.text
                self._activeValue = value
                RefreshText()
                return
            end
        end
    end

    function dropdown:SetText(txt)
        self._displayText = txt
        RefreshText()
    end

    function dropdown:GetText()  return self._displayText end
    function dropdown:GetValue() return self._value       end

    function dropdown:ClosePopup()
        if self._menu and self._menu:IsShown() then
            self._menu:Hide()
        end
    end

    OneWoW_GUI:AttachFilterMenu(dropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(dropdown._options) do
                table.insert(items, { value = opt.value, text = opt.text })
            end
            return items
        end,
        onSelect = function(value, displayText)
            dropdown._value       = value
            dropdown._displayText = displayText
            dropdown._activeValue = value
            RefreshText()
            if dropdown.onSelect then dropdown.onSelect(value, displayText) end
        end,
        getActiveValue = function() return dropdown._value end,
    })

    table.insert(_openDropdowns, dropdown)
    return dropdown
end

function ns.UI.ApplyFontToFrame(frame)
    if not frame then return end
    local fontPath = OneWoW_GUI:GetFont()
    if not fontPath then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont and not region._skipGlobalFont then
            local _, sz = region:GetFont()
            if sz and sz > 0 then region:SetFont(fontPath, sz) end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child._skipGlobalFont then
        elseif child:GetObjectType() == "EditBox" and child.GetFont then
            local _, sz, flags = child:GetFont()
            if sz and sz > 0 then child:SetFont(fontPath, sz, flags or "") end
        end
        ns.UI.ApplyFontToFrame(child)
    end
end

function ns.UI.CloseAllOpenDropdowns()
    for _, dd in ipairs(_openDropdowns) do
        if dd._menu and dd._menu:IsShown() then
            dd._menu:Hide()
        end
    end
end

local _themedDialogs = {}

function ns.UI.CreateThemedDialog(config)
    local dialogName     = config.name or "OneWoW_NotesThemedDialog"
    local destroyOnClose = config.destroyOnClose

    local cached = _themedDialogs[dialogName]
    if destroyOnClose and cached then
        cached:Hide()
        cached:SetParent(nil)
        _themedDialogs[dialogName] = nil
        cached = nil
    end
    if cached then
        if cached:IsShown() then cached:Raise() return cached end
        cached:Show()
        cached:Raise()
        return cached
    end

    local result = OneWoW_GUI:CreateDialog({
        name       = dialogName,
        title      = config.title or "",
        width      = config.width or 500,
        height     = config.height or 400,
        buttons    = config.buttons,
        onClose    = function()
            if config.onClose then config.onClose() end
            if destroyOnClose then
                _themedDialogs[dialogName] = nil
            end
        end,
    })

    local frame       = result.frame
    frame.content     = result.contentFrame
    frame.titleLabel  = result.titleBar._titleText
    frame.closeBtn    = result.titleBar._closeBtn
    frame.footer      = nil
    _themedDialogs[dialogName] = frame

    frame:SetScript("OnHide", function()
        ns.UI.CloseAllOpenDropdowns()
    end)

    frame:HookScript("OnShow", function(self)
        C_Timer.After(0, function()
            ns.UI.ApplyFontToFrame(self)
        end)
    end)

    frame:Hide()
    return frame
end

function ns.UI.CreateCustomScroll(parent)
    local container = CreateFrame("Frame", nil, parent)

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(container, {})
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -14, 0)

    return {
        container   = container,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        UpdateThumb = function() end,
    }
end

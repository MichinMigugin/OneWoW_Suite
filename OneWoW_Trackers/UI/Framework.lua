local addonName, ns = ...

ns.UI = ns.UI or {}

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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

function ns.UI.CloseAllOpenDropdowns()
    for _, dd in ipairs(_openDropdowns) do
        if dd._menu and dd._menu:IsShown() then
            dd._menu:Hide()
        end
    end
end

local _themedDialogs = {}

function ns.UI.CreateThemedDialog(config)
    local dialogName     = config.name or "OneWoW_TrackersThemedDialog"
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
        showBrand  = true,
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
            OneWoW_GUI:ApplyFontToFrame(self)
        end)
    end)

    frame:Hide()
    return frame
end


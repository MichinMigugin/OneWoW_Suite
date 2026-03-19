local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ldb = LibStub("LibDataBroker-1.1", true)
local libDBIcon = LibStub("LibDBIcon-1.0", true)

local noop = OneWoW_GUI.noop

local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME_ICON = Constants.DEFAULT_THEME_ICON

local function CreateStub()
    return {
        Initialize = noop,
        Show = noop,
        Hide = noop,
        Toggle = noop,
        IsShown = function()
            local btn = _G.OneWoW_MinimapButton
            return btn and btn:IsShown()
        end,
        UpdateIcon = noop,
        SetShown = noop,
    }
end

function OneWoW_GUI:CreateMinimapLauncher(addonName, options)
    options = options or {}

    if _G.OneWoW then
        return CreateStub()
    end

    if not ldb or not libDBIcon then
        return CreateStub()
    end

    local label = options.label or addonName
    local onClick = options.onClick or noop
    local onRightClick = options.onRightClick or noop
    local onTooltip = options.onTooltip or noop

    local launcherDB = self._settingsDB and self._settingsDB.minimapLaunchers or {}
    if self._settingsDB then
        self._settingsDB.minimapLaunchers = launcherDB
    end
    if not launcherDB[addonName] then
        launcherDB[addonName] = { minimapPos = 225 }
    end
    local db = launcherDB[addonName]

    local function GetIcon()
        return self:GetBrandIcon(self:GetSetting("minimap.theme") or DEFAULT_THEME_ICON)
    end

    local dataObj = ldb:NewDataObject(addonName, {
        type = "launcher",
        icon = GetIcon(),
        OnClick = function(clickFrame, button)
            if button == "RightButton" then
                onRightClick(clickFrame, button)
            else
                onClick(clickFrame, button)
            end
        end,
        OnEnter = function(clickFrame)
            onTooltip(clickFrame)
        end,
        OnLeave = function()
            GameTooltip:Hide()
        end,
    })

    libDBIcon:Register(addonName, dataObj, db)

    if db.hide then
        libDBIcon:Hide(addonName)
    end

    if not self._launchers then self._launchers = {} end

    local launcher = {
        Initialize = noop,
        Show = function()
            db.hide = false
            libDBIcon:Show(addonName)
        end,
        Hide = function()
            db.hide = true
            libDBIcon:Hide(addonName)
        end,
        Toggle = function()
            local btn = libDBIcon:GetMinimapButton(addonName)
            if btn and btn:IsShown() then
                db.hide = true
                libDBIcon:Hide(addonName)
            else
                db.hide = false
                libDBIcon:Show(addonName)
            end
        end,
        IsShown = function()
            local btn = libDBIcon:GetMinimapButton(addonName)
            return btn and btn:IsShown()
        end,
        UpdateIcon = function()
            dataObj.icon = GetIcon()
        end,
        SetShown = function(_, show)
            if show then
                db.hide = false
                libDBIcon:Show(addonName)
            else
                db.hide = true
                libDBIcon:Hide(addonName)
            end
        end,
    }

    self._launchers[addonName] = launcher
    return launcher
end

function OneWoW_GUI:GetMinimapButton(addonName)
    if _G.OneWoW and _G.OneWoW_MinimapButton then
        return _G.OneWoW_MinimapButton
    end
    if libDBIcon then
        return libDBIcon:GetMinimapButton(addonName)
    end
    return nil
end

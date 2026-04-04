local _, OneWoW_Bags = ...

OneWoW_Bags.WindowLayoutController = {}
local WindowLayoutController = OneWoW_Bags.WindowLayoutController

function WindowLayoutController:UpdateFixedWidth(config)
    local db = self.addon:GetDB()
    if not db or not config.mainWindow then return end

    local cols = db.global[config.columnsKey] or config.defaultColumns
    local iconSize = self.addon.Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = self.addon.Constants.GUI.ITEM_BUTTON_SPACING
    local scrollbarSpace = db.global[config.hideScrollKey] and 0 or 12
    local newWidth = cols * (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 * config.outerPadding)

    config.mainWindow:SetWidth(newWidth)
    config.mainWindow:SetResizeBounds(newWidth, 300, newWidth, 1200)
end

function WindowLayoutController:Refresh(config)
    if not config.mainWindow or not config.mainWindow:IsShown() then return end
    if not config.isBuilt or not config.isBuilt() then return end

    if config.updateWindowWidth then
        config.updateWindowWidth()
    end

    if config.beforeLayout then
        config.beforeLayout()
    end

    if config.contentFrame and config.containerFrames then
        for _, frame in pairs(config.containerFrames) do
            frame:SetParent(config.contentFrame)
        end
    end

    if config.cleanup then
        config.cleanup()
    end

    local buttons = config.getButtons and config.getButtons() or {}
    if config.filterButtons then
        buttons = config.filterButtons(buttons)
    end

    local layoutHeight = config.layoutButtons and config.layoutButtons(buttons) or 1
    if config.contentFrame then
        config.contentFrame:SetHeight(layoutHeight)
    end

    if config.afterLayout then
        config.afterLayout(buttons, layoutHeight)
    end
end

function WindowLayoutController:BindScrollFrame(config)
    if not config.scrollFrame then return end

    local scrollbarOffset = config.hideScrollBar and 0 or -12
    if config.scrollFrame.ScrollBar then
        if config.hideScrollBar then
            config.scrollFrame.ScrollBar:Hide()
            config.scrollFrame.ScrollBar:SetAlpha(0)
        else
            config.scrollFrame.ScrollBar:Show()
            config.scrollFrame.ScrollBar:SetAlpha(1)
        end
    end

    config.scrollFrame:ClearAllPoints()
    if config.topAnchor and config.topAnchor:IsShown() then
        config.scrollFrame:SetPoint("TOPLEFT", config.topAnchor, "BOTTOMLEFT", 0, -2)
    else
        config.scrollFrame:SetPoint("TOPLEFT", config.contentArea, "TOPLEFT", 0, 0)
    end

    if config.bottomAnchor and config.bottomAnchor:IsShown() then
        config.scrollFrame:SetPoint("BOTTOMRIGHT", config.bottomAnchor, "TOPRIGHT", scrollbarOffset, 2)
    else
        config.scrollFrame:SetPoint("BOTTOMRIGHT", config.contentArea, "BOTTOMRIGHT", scrollbarOffset, 0)
    end
end

function WindowLayoutController:CreateViewContext(config)
    local context = {}

    context.sortButtons = function(buttons, overrideSortMode)
        self.addon:SortButtons(buttons, overrideSortMode)
    end

    context.acquireSection = function(parent)
        if config.sectionManager and config.sectionManager.AcquireSection then
            return config.sectionManager:AcquireSection(parent)
        end
    end

    context.acquireSectionHeader = function(parent)
        if config.sectionManager and config.sectionManager.AcquireSectionHeader then
            return config.sectionManager:AcquireSectionHeader(parent)
        end
        if config.sectionManager and config.sectionManager.AcquireSection then
            return config.sectionManager:AcquireSection(parent)
        end
    end

    context.acquireDivider = function(parent)
        if config.sectionManager and config.sectionManager.AcquireDivider then
            return config.sectionManager:AcquireDivider(parent)
        end
    end

    context.getCollapsed = function(kind, key)
        if config.getCollapsed then
            return config.getCollapsed(kind, key)
        end
        return nil
    end

    context.setCollapsed = function(kind, key, collapsed)
        if config.setCollapsed then
            config.setCollapsed(kind, key, collapsed)
        end
        if config.requestRelayout then
            config.requestRelayout()
        end
    end

    context.requestRelayout = function()
        if config.requestRelayout then
            config.requestRelayout()
        end
    end

    context.containerType = config.containerType

    return context
end

function WindowLayoutController:Create(addon)
    local controller = {}
    controller.addon = addon
    setmetatable(controller, { __index = self })
    return controller
end

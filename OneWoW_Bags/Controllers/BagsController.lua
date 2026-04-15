local _, OneWoW_Bags = ...

local L = OneWoW_Bags.L
local C_Container = C_Container
local C_CurrencyInfo = C_CurrencyInfo
local tinsert, tremove = tinsert, tremove
local tonumber = tonumber
local ipairs = ipairs

local function IsAlreadyTracked(trackers, trackType, id)
    for _, entry in ipairs(trackers) do
        if entry.type == trackType and entry.id == id then
            return true
        end
    end
    return false
end

OneWoW_Bags.BagsController = {}
local BagsController = OneWoW_Bags.BagsController

function BagsController:Create(addon)
    local controller = {}
    controller.addon = addon
    setmetatable(controller, { __index = self })
    return controller
end

function BagsController:GetViewMode()
    local db = self.addon:GetDB()
    return db.global.viewMode
end

function BagsController:SetViewMode(mode)
    local db = self.addon:GetDB()
    if db.global.viewMode == mode then return end
    db.global.viewMode = mode
    self.addon:RequestLayoutRefresh("bags")
end

function BagsController:GetSelectedBag()
    local db = self.addon:GetDB()
    return db.global.selectedBag
end

function BagsController:ToggleSelectedBag(bagIndex)
    local db = self.addon:GetDB()

    if db.global.selectedBag == bagIndex then
        db.global.selectedBag = nil
    else
        db.global.selectedBag = bagIndex
        db.global.viewMode = "bag"
    end

    if self.addon.BagsBar then
        self.addon.BagsBar:UpdateBagHighlights()
    end
    if self.addon.InfoBar then
        self.addon.InfoBar:UpdateViewButtons()
    end
    self.addon:RequestLayoutRefresh("bags")
end

function BagsController:GetShowEmptySlots()
    local db = self.addon:GetDB()
    return db.global.showEmptySlots
end

function BagsController:ToggleEmptySlots()
    local db = self.addon:GetDB()
    db.global.showEmptySlots = not db.global.showEmptySlots
    self.addon:RequestLayoutRefresh("bags")
end

function BagsController:GetExpansionFilter()
    return self.addon.activeExpansionFilter
end

function BagsController:SetExpansionFilter(value)
    if value == "ALL" then
        self.addon.activeExpansionFilter = nil
    else
        self.addon.activeExpansionFilter = value
    end
    self.addon:RequestLayoutRefresh("bags")
end

function BagsController:ToggleCategoryManager()
    if self.addon.CategoryManagerUI then
        self.addon.CategoryManagerUI:Toggle()
    end
end

function BagsController:ToggleSettings()
    if self.addon.Settings then
        self.addon.Settings:Toggle()
    end
end

function BagsController:SortBags()
    C_Container.SortBags()
end

function BagsController:OnSearchChanged(text)
    if self.addon.GUI then
        self.addon.GUI:OnSearchChanged(text)
    end
end

function BagsController:AddTrackedEntryFromID(rawID)
    local db = self.addon:GetDB()
    local id = tonumber(rawID)
    if not id or id <= 0 then return false end

    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(id)
    local trackType = "item"
    if currencyInfo and currencyInfo.name and currencyInfo.name ~= "" then
        trackType = "currency"
    end

    local list = db.global.trackedCurrencies
    if IsAlreadyTracked(list, trackType, id) then
        print("|cffff4444OneWoW_Bags:|r " .. (L["TRACKER_ALREADY_TRACKED"] or ""))
        return false
    end

    tinsert(list, { type = trackType, id = id })
    if self.addon.BagsBar then
        self.addon.BagsBar:UpdateTrackers()
        self.addon.BagsBar:UpdateRowVisibility()
    end
    return true
end

function BagsController:AddTrackedItem(itemID)
    local db = self.addon:GetDB()
    if not itemID then return false end

    local list = db.global.trackedCurrencies
    if IsAlreadyTracked(list, "item", itemID) then
        print("|cffff4444OneWoW_Bags:|r " .. (L["TRACKER_ALREADY_TRACKED"] or ""))
        return false
    end

    tinsert(list, { type = "item", id = itemID })
    if self.addon.BagsBar then
        self.addon.BagsBar:UpdateTrackers()
        self.addon.BagsBar:UpdateRowVisibility()
    end
    return true
end

function BagsController:RemoveTrackedEntry(index)
    local db = self.addon:GetDB()
    if not db then return end

    tremove(db.global.trackedCurrencies, index)
    if self.addon.BagsBar then
        self.addon.BagsBar:UpdateTrackers()
        self.addon.BagsBar:UpdateRowVisibility()
    end
end

local _, ns = ...

local L = ns.L
local BagTypes = OneWoW.Inventory.BagTypes
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

ns.BagsController = {}
local BagsController = ns.BagsController

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
    local selected = db.global.selectedBag
    if selected ~= nil and not BagTypes:IsBagEquipped(selected) then
        return nil
    end
    return selected
end

function BagsController:RefreshBagFilterUI()
    if self.addon.BagsBar then
        self.addon.BagsBar:UpdateBagHighlights()
    end
    if self.addon.InfoBar then
        self.addon.InfoBar:UpdateViewButtons()
    end
    self.addon:RequestLayoutRefresh("bags")
end

function BagsController:ClearBagFilter()
    local db = self.addon:GetDB()
    if db.global.selectedBag == nil then
        return
    end
    db.global.selectedBag = nil
    self:RefreshBagFilterUI()
end

function BagsController:ShowOnlyBag(bagIndex)
    if BagTypes:IsSwappableBag(bagIndex) and not BagTypes:IsBagEquipped(bagIndex) then
        return
    end

    local db = self.addon:GetDB()
    if db.global.selectedBag == bagIndex and db.global.viewMode == "bag" then
        return
    end

    db.global.selectedBag = bagIndex
    db.global.viewMode = "bag"
    self:RefreshBagFilterUI()
end

function BagsController:ToggleSelectedBag(bagIndex)
    if BagTypes:IsSwappableBag(bagIndex) and not BagTypes:IsBagEquipped(bagIndex) then
        return
    end

    local db = self.addon:GetDB()

    if db.global.selectedBag == bagIndex then
        db.global.selectedBag = nil
    else
        db.global.selectedBag = bagIndex
        db.global.viewMode = "bag"
    end

    self:RefreshBagFilterUI()
end

--- Clears bag-view filter when the equipped container at bagIndex was removed.
---@param bagIndex number
function BagsController:OnBagUnequipped(bagIndex)
    local db = self.addon:GetDB()
    if db.global.selectedBag ~= bagIndex then
        return
    end
    db.global.selectedBag = nil
    self.addon:RequestLayoutRefresh("bags", "bag_unequipped")
    if self.addon.BagsBar then
        self.addon.BagsBar:UpdateBagHighlights()
    end
    if self.addon.InfoBar then
        self.addon.InfoBar:UpdateViewButtons()
    end
end

function BagsController:GetShowEmptySlots()
    local db = self.addon:GetDB()
    return db.global.showEmptySlots
end

function BagsController:GetExpansionFilter()
    return self.addon.activeExpansionFilter
end

function BagsController:SetExpansionFilter(value)
    self.addon.activeExpansionFilter = ns.WindowHelpers:NormalizeExpansionFilter(value)
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
        print("|cffff4444" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. L["TRACKER_ALREADY_TRACKED"])
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
        print("|cffff4444" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. L["TRACKER_ALREADY_TRACKED"])
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

    tremove(db.global.trackedCurrencies, index)
    if self.addon.BagsBar then
        self.addon.BagsBar:UpdateTrackers()
        self.addon.BagsBar:UpdateRowVisibility()
    end
end

function BagsController:MoveTrackedEntry(fromIndex, toIndex)
    local db = self.addon:GetDB()
    local list = db.global.trackedCurrencies
    local n = #list
    if fromIndex < 1 or fromIndex > n or toIndex < 1 or toIndex > n or fromIndex == toIndex then
        return
    end

    local entry = tremove(list, fromIndex)
    tinsert(list, toIndex, entry)

    if self.addon.BagsBar then
        self.addon.BagsBar:UpdateTrackers()
        self.addon.BagsBar:UpdateRowVisibility()
    end
end

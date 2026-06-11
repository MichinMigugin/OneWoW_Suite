-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/inspectmog/inspectpanel.lua
-- Ported from standalone OneWoW_InspectMog (transmog-aware inspect side panel).
local addonName, ns = ...

local OneWoW_GUI = OneWoW_GUI

local function GetInspectMogDb()
    local addon = OneWoW_QoL
    if not addon or not addon.db or not addon.db.global then
        return { enabled = true, attachSide = "RIGHT", hideUnchanged = false, showEmptySlots = false }
    end
    local modules = addon.db.global.modules
    modules.inspectmog = modules.inspectmog or {}
    local db = modules.inspectmog
    if db.attachSide == nil then db.attachSide = "RIGHT" end
    if db.hideUnchanged == nil then db.hideUnchanged = false end
    if db.showEmptySlots == nil then db.showEmptySlots = false end
    if db.enabled == nil then db.enabled = true end
    return db
end

local function IsInspectMogEnabled()
    return ns.ModuleRegistry:IsEnabled("inspectmog") and GetInspectMogDb().enabled
end

ns.InspectMogUI = {}
local UI = ns.InspectMogUI
ns.Panel = UI

local ROW_HEIGHT = 42
local PANEL_WIDTH = 360
local PANEL_HEIGHT = 530
local PAD = 10
local FALLBACK_ICON = 134400
local HEADER_HEIGHT = 26

local itemResolver = nil
local localItemCache = {}
local localItemPending = {}

local function ThemeColor(key, fallbackR, fallbackG, fallbackB, fallbackA)
    local r, g, b, a = OneWoW_GUI:GetThemeColor(key)
    if r then
        return r, g, b, a
    end

    return fallbackR, fallbackG, fallbackB, fallbackA or 1
end

local function CreateFontString(parent, size)
    return OneWoW_GUI:CreateFS(parent, size)
end

local function AnchorToInspect(frame)
    frame:ClearAllPoints()

    if InspectFrame then
        frame:SetParent(InspectFrame)
        if InspectFrame.GetFrameStrata then
            frame:SetFrameStrata(InspectFrame:GetFrameStrata())
        end
        if InspectFrame.GetFrameLevel then
            frame:SetFrameLevel(InspectFrame:GetFrameLevel() + 8)
        end
    else
        frame:SetParent(UIParent)
        frame:SetFrameStrata("MEDIUM")
    end

    local side = GetInspectMogDb().attachSide or "RIGHT"
    if InspectFrame and side == "LEFT" then
        frame:SetPoint("TOPRIGHT", InspectFrame, "TOPLEFT", -6, 0)
    elseif InspectFrame then
        frame:SetPoint("TOPLEFT", InspectFrame, "TOPRIGHT", 6, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 340, 0)
    end
end

local inspectGuildUpdateGuardInstalled = false

local function CanUpdateInspectGuildFrame()
    local inspectFrame = _G["InspectFrame"]
    local unit = inspectFrame and inspectFrame.unit
    if not unit or not UnitExists(unit) then
        return false
    end

    local achievementPoints, numMembers, guildName = C_PaperDollInfo.GetInspectGuildInfo(unit)
    return type(guildName) == "string"
        and guildName ~= ""
        and type(achievementPoints) == "number"
        and type(numMembers) == "number"
end

local function HideInspectGuildFrame()
    local guildFrame = _G["InspectGuildFrame"]
    if guildFrame and guildFrame.Hide then
        guildFrame:Hide()
    end
end

local function CallInspectGuildScriptWhenReady(scriptFunc, self, ...)
    if not scriptFunc then
        return
    end

    if not CanUpdateInspectGuildFrame() then
        if self and self.Hide then
            self:Hide()
        else
            HideInspectGuildFrame()
        end
        return
    end

    return scriptFunc(self, ...)
end

local function InstallInspectGuildFrameGuard()
    local updateFunc = _G["InspectGuildFrame_Update"]
    local guildFrame = _G["InspectGuildFrame"]
    if type(updateFunc) ~= "function" and not guildFrame then
        return
    end

    if type(updateFunc) == "function" and not inspectGuildUpdateGuardInstalled then
        inspectGuildUpdateGuardInstalled = true
        _G["InspectGuildFrame_Update"] = function(...)
            if not CanUpdateInspectGuildFrame() then
                HideInspectGuildFrame()
                return
            end

            return updateFunc(...)
        end
    end

    if guildFrame then
        local oldOnEvent = guildFrame:GetScript("OnEvent")
        if oldOnEvent and oldOnEvent ~= guildFrame.OneWoWInspectMogOnEventWrapper then
            guildFrame.OneWoWInspectMogOriginalOnEvent = oldOnEvent
            guildFrame.OneWoWInspectMogOnEventWrapper = function(self, event, ...)
                CallInspectGuildScriptWhenReady(self.OneWoWInspectMogOriginalOnEvent, self, event, ...)
            end
            guildFrame:SetScript("OnEvent", guildFrame.OneWoWInspectMogOnEventWrapper)
        end

        if not oldOnEvent then
            guildFrame:SetScript("OnEvent", function(self)
                if not CanUpdateInspectGuildFrame() then
                    self:Hide()
                end
            end)
        end

        local oldOnShow = guildFrame:GetScript("OnShow")
        if oldOnShow ~= guildFrame.OneWoWInspectMogOnShowWrapper then
            guildFrame.OneWoWInspectMogOriginalOnShow = oldOnShow
            guildFrame.OneWoWInspectMogOnShowWrapper = function(self, ...)
                CallInspectGuildScriptWhenReady(self.OneWoWInspectMogOriginalOnShow, self, ...)
            end
            guildFrame:SetScript("OnShow", guildFrame.OneWoWInspectMogOnShowWrapper)
        end
    end
end

local function GetCatalogItemLoader()
    if itemResolver then
        return itemResolver
    end

    itemResolver = false

    if C_AddOns.IsAddOnLoaded("OneWoW_Catalog")
        and OneWoW_Catalog
        and OneWoW_Catalog.CreateItemDataLoader
        and OneWoW_Catalog_DB
    then
        OneWoW_Catalog_DB.global = OneWoW_Catalog_DB.global or {}
        itemResolver = OneWoW_Catalog:CreateItemDataLoader(OneWoW_Catalog_DB.global)
        if itemResolver and itemResolver.Initialize then
            itemResolver:Initialize()
        end
    end

    return itemResolver or nil
end

local function EnsureLocalItemEventFrame()
    if UI.itemEventFrame then
        return
    end

    local f = CreateFrame("Frame")
    UI.itemEventFrame = f
    f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    f:SetScript("OnEvent", function(_, _, itemID, success)
        itemID = tonumber(itemID)
        if not itemID or not localItemPending[itemID] then
            return
        end

        if success then
            local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
            if name then
                localItemCache[itemID] = {
                    name = name,
                    link = link,
                    quality = quality or 1,
                    icon = icon or FALLBACK_ICON,
                }
            end
        end

        local callbacks = localItemPending[itemID]
        localItemPending[itemID] = nil
        local data = localItemCache[itemID]
        if data then
            for _, callback in ipairs(callbacks) do
                callback(itemID, data)
            end
        end
    end)
end

local function ResolveItemData(itemID, callback)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    local loader = GetCatalogItemLoader()
    if loader and loader.LoadItemData then
        return loader:LoadItemData(itemID, callback)
    end

    local cached = localItemCache[itemID]
    if cached and cached.name then
        if callback then callback(itemID, cached) end
        return cached
    end

    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    if name then
        cached = {
            name = name,
            link = link,
            quality = quality or 1,
            icon = icon or FALLBACK_ICON,
        }
        localItemCache[itemID] = cached
        if callback then callback(itemID, cached) end
        return cached
    end

    EnsureLocalItemEventFrame()
    C_Item.RequestLoadItemDataByID(itemID)
    localItemPending[itemID] = localItemPending[itemID] or {}
    if callback then
        table.insert(localItemPending[itemID], callback)
    end

    return nil
end

local IsHiddenAppearance

local function GetAppearanceItemID(rowData)
    if not rowData then
        return nil
    end

    return rowData.appearanceItemID or rowData.itemID
end

local function GetAddAllAppearanceItemID(rowData)
    if not rowData or IsHiddenAppearance(rowData) then
        return nil
    end

    return rowData.appearanceItemID
end

local function GetEquippedItemID(rowData)
    return rowData and rowData.itemID or nil
end

local function GetAppearanceItemLink(rowData)
    if not rowData then
        return nil
    end

    return rowData.appearanceItemLink or rowData.itemLink
end

local function GetEquippedItemLink(rowData)
    return rowData and rowData.itemLink or nil
end

function IsHiddenAppearance(rowData)
    if not rowData then
        return false
    end

    local name = rowData.appearanceName or rowData.appearanceItemName
    return type(name) == "string" and name:lower():match("^hidden%s+")
end

local function HandleItemPreviewClick(itemID, itemLink)
    if not IsControlKeyDown() then
        return false
    end

    itemID = tonumber(itemID)
    itemLink = itemLink
        or (itemID and select(2, C_Item.GetItemInfo(itemID)))
        or (itemID and ("item:" .. tostring(itemID)))

    if not itemLink then
        return false
    end

    if HandleModifiedItemClick and HandleModifiedItemClick(itemLink) then
        return true
    end

    if DressUpItemLink then
        DressUpItemLink(itemLink)
        return true
    end

    return false
end

local function AddItemToNotes(itemID, itemName, itemLink, icon, quality, quiet)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local notesItems = OneWoW_Notes and OneWoW_Notes.Items
    if not notesItems or not notesItems.AddItem then
        return false
    end

    local existing = notesItems.GetItem and notesItems:GetItem(itemID)
    if existing then
        existing.category = "Transmog"
        existing.link = existing.link or itemLink
        existing.icon = existing.icon or icon
        existing.name = existing.name or itemName
        existing.content = existing.content or "Added from Inspect Mog."
        notesItems:SaveItem(itemID, existing)
    else
        notesItems:AddItem(itemID, {
            name = itemName,
            link = itemLink,
            icon = icon,
            quality = quality,
            rarity = quality,
            category = "Transmog",
            storage = "account",
            content = "Added from Inspect Mog.",
        })
    end

    if OneWoW_Notes and OneWoW_Notes.UI and OneWoW_Notes.UI.RefreshItemsList then
        OneWoW_Notes.UI.RefreshItemsList()
    end

    return true
end

local function AddEquippedItemToNotes(rowData, quiet)
    local itemID = tonumber(GetEquippedItemID(rowData))
    if not itemID then return false end

    local itemName = rowData.itemName
    local itemLink = GetEquippedItemLink(rowData)
    local icon = rowData.texture
    local quality = rowData.quality

    if not itemName or not itemLink or not icon then
        local cached = ResolveItemData(itemID, function(_, itemData)
            rowData.itemName = rowData.itemName or itemData.name
            rowData.itemLink = rowData.itemLink or itemData.link
            rowData.texture = rowData.texture or itemData.icon
            rowData.quality = rowData.quality or itemData.quality
            AddEquippedItemToNotes(rowData, quiet)
        end)
        if not cached then return true end
        itemName = itemName or cached.name
        itemLink = itemLink or cached.link
        icon = icon or cached.icon
        quality = quality or cached.quality
    end

    return AddItemToNotes(itemID, itemName, itemLink, icon, quality, quiet)
end

local function AddAppearanceToNotes(rowData, quiet)
    if IsHiddenAppearance(rowData) then
        return false
    end

    local itemID = tonumber(GetAppearanceItemID(rowData))
    if not itemID then
        return false
    end

    local itemName = rowData.appearanceItemName
        or rowData.appearanceName
        or rowData.itemName
    local itemLink = GetAppearanceItemLink(rowData)
    local icon = rowData.appearanceIcon or rowData.texture

    if (not itemName or tostring(itemName):match("^Source #"))
        and ResolveItemData
    then
        ResolveItemData(itemID, function(_, itemData)
            rowData.appearanceItemName = itemData.name
            rowData.appearanceName = itemData.name
            rowData.appearanceItemLink = rowData.appearanceItemLink or itemData.link
            rowData.appearanceIcon = rowData.appearanceIcon or itemData.icon
            rowData.appearanceQuality = rowData.appearanceQuality or itemData.quality
            AddAppearanceToNotes(rowData, quiet)
        end)
        return true
    end

    return AddItemToNotes(itemID, itemName, itemLink, icon, rowData.appearanceQuality, quiet)
end

local function AddAllVisibleAppearancesToNotes(frame)
    if not frame or not frame.rows then
        return
    end

    local seen = {}
    local count = 0
    for _, row in ipairs(frame.rows) do
        if row:IsShown() and row.data then
            local itemID = tonumber(GetAddAllAppearanceItemID(row.data))
            if itemID and not seen[itemID] then
                seen[itemID] = true
                if AddAppearanceToNotes(row.data, true) then
                    count = count + 1
                end
            end
        end
    end
end

local function ShowInspectMogTooltip(owner, itemID, itemLink, sourceID, clickText, previewText, hiddenText)
    if not itemID and not itemLink then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if itemLink then
        GameTooltip:SetHyperlink(itemLink)
    else
        GameTooltip:SetItemByID(itemID)
    end
    if sourceID then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Appearance source: " .. tostring(sourceID), 0.4, 1, 0.45)
    end
    GameTooltip:AddLine(" ")
    if hiddenText then
        GameTooltip:AddLine(hiddenText, 0.8, 0.8, 0.8, true)
    else
        GameTooltip:AddLine(clickText, 0, 1, 0)
    end
    GameTooltip:AddLine(previewText, 0, 1, 0)
    GameTooltip:Show()
end

local function SetRowText(row, snapshotRow)
    local itemName = snapshotRow.itemName or snapshotRow.itemLink or "Empty"
    local appearanceName =
        snapshotRow.appearanceName
        or snapshotRow.appearanceItemName
        or (
            snapshotRow.appearanceSourceID
            and ("Source #" .. tostring(snapshotRow.appearanceSourceID))
        )
        or "Native appearance"

    row.slot:SetText(snapshotRow.slotName)
    row.item:SetText(itemName)
    row.appearance:SetText(appearanceName)

    local icon = snapshotRow.appearanceIcon or snapshotRow.texture
    if icon then
        row.icon:SetTexture(icon)
    else
        row.icon:SetTexture(FALLBACK_ICON)
    end

    if snapshotRow.isChanged then
        row.appearance:SetTextColor(ThemeColor("TEXT_ACCENT", 0.4, 1, 0.45))
    else
        row.appearance:SetTextColor(ThemeColor("TEXT_MUTED", 0.7, 0.7, 0.7))
    end
end

function UI:IsShownForInspect()
    return self.frame and self.frame:IsShown()
end

function UI:EnsureFrame()
    if self.frame then
        return
    end

    local frame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoWInspectMogPanel",
        width = PANEL_WIDTH,
        height = PANEL_HEIGHT,
        backdrop = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS,
        bgColor = "BG_PRIMARY",
        borderColor = "BORDER_DEFAULT",
    })
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local titleBar = OneWoW_GUI:CreateTitleBar(frame, {
        title = "Inspect Transmog Tool",
        height = HEADER_HEIGHT,
        showBrand = true,
        onClose = function()
            frame:Hide()
        end,
    })
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame.titleBar = titleBar
    frame.title = titleBar._titleText
    frame.closeBtn = titleBar._closeBtn

    local addAllBtn = OneWoW_GUI:CreateFitTextButton(frame, {
        text = "Add All",
        height = 22,
        minWidth = 72,
    })
    addAllBtn:SetText("Add All")
    addAllBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(HEADER_HEIGHT + 6))
    addAllBtn:SetScript("OnClick", function()
        AddAllVisibleAppearancesToNotes(frame)
    end)
    addAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Add All Transmog", 1, 1, 1)
        GameTooltip:AddLine("Add all visible transmog appearance items to Notes > Items.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addAllBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.addAllBtn = addAllBtn

    local sub = CreateFontString(frame, 10)
    sub:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(HEADER_HEIGHT + 9))
    sub:SetPoint("TOPRIGHT", addAllBtn, "TOPLEFT", -8, -2)
    sub:SetJustifyH("LEFT")
    sub:SetTextColor(ThemeColor("TEXT_SECONDARY", 0.7, 0.7, 0.7))
    frame.subtitle = sub

    local scrollFrame, child = OneWoW_GUI:CreateScrollFrame(frame, {
        name = "OneWoWInspectMogPanelScroll",
    })
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -68)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, PAD)

    frame.scrollFrame = scrollFrame
    frame.scrollChild = child
    frame.rows = {}

    self.frame = frame
    AnchorToInspect(frame)
    frame:Hide()
end

function UI:GetRow(index)
    local frame = self.frame
    local row = frame.rows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, frame.scrollChild)
    row:SetSize(PANEL_WIDTH - 48, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.slot = CreateFontString(row, 10)
    row.slot:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
    row.slot:SetWidth(82)
    row.slot:SetJustifyH("LEFT")
    row.slot:SetTextColor(0.7, 0.7, 0.7)

    row.item = CreateFontString(row, 11)
    row.item:SetPoint("TOPLEFT", row.slot, "TOPRIGHT", 8, 0)
    row.item:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -2)
    row.item:SetJustifyH("LEFT")
    row.item:SetWordWrap(false)
    row.item:SetTextColor(1, 1, 1)

    row.appearance = CreateFontString(row, 11)
    row.appearance:SetPoint("TOPLEFT", row.item, "BOTTOMLEFT", 0, -4)
    row.appearance:SetPoint("TOPRIGHT", row.item, "BOTTOMRIGHT", 0, -4)
    row.appearance:SetJustifyH("LEFT")
    row.appearance:SetWordWrap(false)

    row.itemHit = CreateFrame("Button", nil, row)
    row.itemHit:SetPoint("TOPLEFT", row.item, "TOPLEFT", 0, 2)
    row.itemHit:SetPoint("BOTTOMRIGHT", row.item, "BOTTOMRIGHT", 0, -2)

    row.appearanceHit = CreateFrame("Button", nil, row)
    row.appearanceHit:SetPoint("TOPLEFT", row.appearance, "TOPLEFT", 0, 2)
    row.appearanceHit:SetPoint("BOTTOMRIGHT", row.appearance, "BOTTOMRIGHT", 0, -2)

    frame.rows[index] = row
    return row
end

function UI:ResolveRowAppearance(row)
    if not row or not row.data then
        return
    end

    local data = row.data
    local itemID = data.appearanceItemID
    if not itemID then
        return
    end

    local function ApplyResolvedItem(resolvedItemID, itemData)
        if not row.data
            or tonumber(row.data.appearanceItemID) ~= tonumber(resolvedItemID)
        then
            return
        end

        row.data.appearanceItemName = itemData.name
        row.data.appearanceName = row.data.appearanceName or itemData.name
        row.data.appearanceItemLink = row.data.appearanceItemLink or itemData.link
        row.data.appearanceIcon = itemData.icon
        row.data.appearanceQuality = row.data.appearanceQuality or itemData.quality

        SetRowText(row, row.data)
    end

    local cached = ResolveItemData(itemID, ApplyResolvedItem)
    if cached then
        ApplyResolvedItem(itemID, cached)
    end
end

function UI:Refresh(unit)
    self:EnsureFrame()
    AnchorToInspect(self.frame)
    self.frame.title:SetText("Inspect Transmog Tool")
    if self.frame.addAllBtn then
        self.frame.addAllBtn:SetText("Add All")
    end

    local snapshot =
        ns.Scanner
        and ns.Scanner.BuildInspectSnapshot
        and ns.Scanner:BuildInspectSnapshot(unit)

    if not snapshot then
        self.frame.subtitle:SetText("No inspect data available.")
        for _, row in ipairs(self.frame.rows) do
            row:Hide()
        end
        return
    end

    self.frame.subtitle:SetText(snapshot.name or "Inspected player")

    for i, data in ipairs(snapshot.rows) do
        local row = self:GetRow(i)
        SetRowText(row, data)
        row.data = data
        self:ResolveRowAppearance(row)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", nil)

        row.itemHit:SetScript("OnEnter", function(self)
            local rowData = self:GetParent().data
            ShowInspectMogTooltip(
                self,
                GetEquippedItemID(rowData),
                GetEquippedItemLink(rowData),
                nil,
                "Click to add equipped item to Item Notes",
                "Ctrl-click to preview equipped item"
            )
        end)
        row.itemHit:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row.itemHit:SetScript("OnClick", function(self)
            local rowData = self:GetParent().data
            if HandleItemPreviewClick(GetEquippedItemID(rowData), GetEquippedItemLink(rowData)) then
                return
            end
            AddEquippedItemToNotes(rowData)
        end)

        row.appearanceHit:SetScript("OnEnter", function(self)
            local rowData = self:GetParent().data
            local hiddenText = IsHiddenAppearance(rowData)
                and "Hidden appearances are not added to Item Notes"
                or nil
            ShowInspectMogTooltip(
                self,
                GetAppearanceItemID(rowData),
                GetAppearanceItemLink(rowData),
                rowData.appearanceSourceID,
                "Click to add transmog appearance to Item Notes",
                "Ctrl-click to preview transmog appearance",
                hiddenText
            )
        end)
        row.appearanceHit:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row.appearanceHit:SetScript("OnClick", function(self)
            local rowData = self:GetParent().data
            if HandleItemPreviewClick(GetAppearanceItemID(rowData), GetAppearanceItemLink(rowData)) then
                return
            end
            AddAppearanceToNotes(rowData)
        end)
        row:Show()
    end

    for i = #snapshot.rows + 1, #self.frame.rows do
        self.frame.rows[i]:Hide()
    end

    self.frame.scrollChild:SetHeight(math.max(100, #snapshot.rows * ROW_HEIGHT))
end

function UI:Show()
    self:EnsureFrame()
    AnchorToInspect(self.frame)
    self.frame:Show()

    if ns.Scanner and ns.Scanner.Request then
        ns.Scanner:Request()
    end
end

function UI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function UI:Initialize()
    self:EnsureFrame()

    local function LoadInspectUI()
        if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then
            return true
        end

        C_AddOns.LoadAddOn("Blizzard_InspectUI")
        return C_AddOns.IsAddOnLoaded("Blizzard_InspectUI")
    end

    local function HookInspectFrame()
        if self.inspectHooked or not InspectFrame then
            return
        end

        self.inspectHooked = true

        InspectFrame:HookScript("OnShow", function()
            InstallInspectGuildFrameGuard()
            if GetInspectMogDb().enabled then
                UI:Show()
            end
        end)

        InspectFrame:HookScript("OnHide", function()
            UI:Hide()
        end)

        if InspectFrame:IsShown() and GetInspectMogDb().enabled then
            UI:Show()
        end
    end

    LoadInspectUI()
    InstallInspectGuildFrameGuard()
    HookInspectFrame()

    if InspectFrame then
        return
    end

    OneWoW:RegisterAddonLoadedWatcher("Blizzard_InspectUI", function()
        InstallInspectGuildFrameGuard()
        HookInspectFrame()
    end)
end

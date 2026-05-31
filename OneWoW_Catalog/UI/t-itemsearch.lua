local _, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.UI = ns.UI or {}

local selectedItem   = nil
local currentSearch  = ""
local currentSource  = "all"
local favoritesOnly  = false
local panels         = nil
local listElements   = {}
local detailElements = {}
local sourceButtons  = {}
local favoriteFilterButton = nil
local searchBox      = nil
local emptyList      = nil
local emptyDetail    = nil
local searchTimer    = nil
local scanAHButtonRef = nil
local itemDataLoader = nil

local ITEM_ROW_HEIGHT  = 30
local SOURCE_BTN_H     = 22
local SOURCE_BTN_PAD_X = 10
local SOURCE_BTN_GAP   = 3
local HEADER_H         = 58
local FILTER_BUTTONS_MIN_WIDTH = 640

local SOURCE_DEFS = {
    { key = "all",     labelKey = "TT_IS_FILTER_ALL",     descKey = "TT_IS_FILTER_ALL_DESC"     },
    { key = "drops",   labelKey = "TT_IS_FILTER_DROPS",   descKey = "TT_IS_FILTER_DROPS_DESC"   },
    { key = "vendors", labelKey = "TT_IS_FILTER_VENDORS", descKey = "TT_IS_FILTER_VENDORS_DESC" },
    { key = "crafted", labelKey = "TT_IS_FILTER_CRAFTED", descKey = "TT_IS_FILTER_CRAFTED_DESC" },
    { key = "owned",   labelKey = "TT_IS_FILTER_OWNED",   descKey = "TT_IS_FILTER_OWNED_DESC"   },
    { key = "quests",  labelKey = "TT_IS_FILTER_QUESTS",  descKey = "TT_IS_FILTER_QUESTS_DESC"  },
}

local RefreshItemList
local ShowItemDetail

local function GetItemDataLoader()
    if itemDataLoader ~= nil then
        return itemDataLoader or nil
    end

    itemDataLoader = false

    if not OneWoW_Catalog
        or not OneWoW_Catalog.CreateItemDataLoader
    then
        return nil
    end

    local catalogDB =
        OneWoW_Catalog.db
        and OneWoW_Catalog.db.global

    if not catalogDB and OneWoW_Catalog_DB then
        OneWoW_Catalog_DB.global = OneWoW_Catalog_DB.global or {}
        catalogDB = OneWoW_Catalog_DB.global
    end

    if not catalogDB then
        return nil
    end

    itemDataLoader = OneWoW_Catalog:CreateItemDataLoader(catalogDB)
    if itemDataLoader and itemDataLoader.Initialize then
        itemDataLoader:Initialize()
    end

    return itemDataLoader
end

local function UpdateItemSearchScanButton()
    if not scanAHButtonRef then return end
    local hide = OneWoW.ItemPrices and OneWoW.ItemPrices:IsAuctionatorAHSourceActive()
    scanAHButtonRef:SetShown(not hide)
end

local function HandleItemPreviewClick(itemID, itemLink)
    if not IsControlKeyDown or not IsControlKeyDown() then
        return false
    end

    itemLink = itemLink
        or (C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(itemID)))
        or select(2, GetItemInfo(itemID))
        or ("item:" .. tostring(itemID))

    if HandleModifiedItemClick and HandleModifiedItemClick(itemLink) then
        return true
    end

    if DressUpItemLink then
        DressUpItemLink(itemLink)
        return true
    end

    return false
end

local function GetNotesItems()
    local notes = _G["OneWoW_Notes"]
    return notes and notes.Items
end

local function IsItemFavorite(itemID)
    if not itemID then return false end
    if ns.Favorites and ns.Favorites:IsFavorite("itemSearch", itemID) then
        return true
    end

    local notesItems = GetNotesItems()
    local note = notesItems and notesItems:GetItem(itemID)
    return note and note.favorite == true
end

local function OpenNotesItemFromSearch(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end

    local notes = _G["OneWoW_Notes"]
    if notes and notes.UI and notes.UI.OpenNotesItem then
        notes.UI.OpenNotesItem(itemID)
        return
    end

    if OneWoW and OneWoW.GUI then
        OneWoW.GUI:Show("notes")
        if OneWoW.GUI.SelectSubTab then
            OneWoW.GUI:SelectSubTab("notes", "items")
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
            local notesAgain = _G["OneWoW_Notes"]
            if notesAgain and notesAgain.UI and notesAgain.UI.OpenNotesItem then
                notesAgain.UI.OpenNotesItem(itemID)
            end
        end)
    end
end

local function SetItemSearchFavorite(result, on)
    if not result or not result.itemID then return end

    if ns.Favorites then
        ns.Favorites:SetFavorite("itemSearch", result.itemID, on)
    end

    local notesItems = GetNotesItems()
    if not notesItems then return end

    if on then
        local note = notesItems:GetItem(result.itemID)
        if note then
            note.favorite = true
            notesItems:SaveItem(result.itemID, note)
        else
            notesItems:AddItem(result.itemID, {
                name = result.name,
                link = result.itemLink,
                icon = result.icon,
                quality = result.quality,
                rarity = result.quality,
                category = "General",
                storage = "account",
                favorite = true,
                content = "Added from Catalog Item Search.",
            })
        end
    else
        local note = notesItems:GetItem(result.itemID)
        if note then
            note.favorite = false
            notesItems:SaveItem(result.itemID, note)
        end
    end

    if _G["OneWoW_Notes"] and _G["OneWoW_Notes"].UI and _G["OneWoW_Notes"].UI.RefreshItemsList then
        _G["OneWoW_Notes"].UI.RefreshItemsList()
    end

    if on then
        OpenNotesItemFromSearch(result.itemID)
    end
end

local function ItemMatchesSource(result)
    if currentSource == "all" then return true end
    if currentSource == "drops" then return result.isJournal == true end
    if currentSource == "vendors" then return result.isVendor == true end
    if currentSource == "crafted" then return result.isCrafted == true end
    if currentSource == "owned" then return (result.ownedCount or 0) > 0 end
    if currentSource == "quests" then return result.isQuest == true end
    return true
end

local function GetFavoriteItemResults()
    local results = {}
    if not ns.ItemSearch then return results end

    local seen = {}
    local favBucket = ns.addon
        and ns.addon.db
        and ns.addon.db.global
        and ns.addon.db.global.favorites
        and ns.addon.db.global.favorites.itemSearch

    if favBucket then
        for id in pairs(favBucket) do
            local itemID = tonumber(id)
            if itemID and not seen[itemID] then
                local result = ns.ItemSearch:GetItemEntry(itemID)
                if result and ItemMatchesSource(result) then
                    table.insert(results, result)
                    seen[itemID] = true
                end
            end
        end
    end

    local notesItems = GetNotesItems()
    local allNotesItems = notesItems and notesItems:GetAllItems()
    if allNotesItems then
        for itemID, itemData in pairs(allNotesItems) do
            itemID = tonumber(itemID)
            if itemID and itemData.favorite and not seen[itemID] then
                local result = ns.ItemSearch:GetItemEntry(itemID)
                if result and ItemMatchesSource(result) then
                    table.insert(results, result)
                    seen[itemID] = true
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    return results
end

local function GetVisibleTooltipItemName()
    local tooltipTitle = _G.GameTooltipTextLeft1
    local text =
        tooltipTitle
        and tooltipTitle.GetText
        and tooltipTitle:GetText()

    if text and text ~= "" and not text:find("Retrieving", 1, true) then
        return text
    end

    return nil
end

local function RememberItemSearchName(itemID, itemName)
    if not itemID or not itemName or itemName == "" then
        return false
    end

    local questAddon = ns.Catalog and ns.Catalog:GetDataAddon("quests")
    if questAddon
        and questAddon.QuestData
        and questAddon.QuestData.RememberItemName
    then
        questAddon.QuestData:RememberItemName(itemID, itemName)
        return true
    end

    return false
end

local function RefreshResultNameFromTooltip(result, nameText)
    if not result or not result.itemID then
        return false
    end

    local currentName = result.name
    if currentName and not currentName:match("^Item #%d+$") then
        return false
    end

    local tooltipName = GetVisibleTooltipItemName()
    if not tooltipName then
        return false
    end

    result.name = tooltipName
    RememberItemSearchName(result.itemID, tooltipName)

    if nameText and nameText.SetText then
        nameText:SetText(tooltipName)
    end

    if selectedItem and selectedItem.itemID == result.itemID then
        selectedItem.name = tooltipName
    end

    return true
end

local function ApplyItemDisplayRecord(result, itemData, nameText, iconTexture)
    if not result or not result.itemID then return false end
    if not itemData then return false end

    local changed = false
    local itemName = itemData.name
    local itemLink = itemData.link
    local quality = itemData.quality
    local icon = itemData.icon

    if itemName and itemName ~= "" and (not result.name or result.name:match("^Item #%d+$")) then
        result.name = itemName
        changed = true
    end
    if itemLink and result.itemLink ~= itemLink then
        result.itemLink = itemLink
        changed = true
    end
    if quality and result.quality ~= quality then
        result.quality = quality
        changed = true
    end
    if icon and result.icon ~= icon then
        result.icon = icon
        changed = true
    end

    if nameText and nameText.SetText and result.name then
        nameText:SetText(result.name)
        nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))
    end
    if iconTexture and iconTexture.SetTexture and result.icon then
        iconTexture:SetTexture(result.icon)
    end
    if selectedItem and selectedItem.itemID == result.itemID then
        selectedItem.name = result.name
        selectedItem.itemLink = result.itemLink
        selectedItem.quality = result.quality
        selectedItem.icon = result.icon
    end

    return changed or (itemName ~= nil and icon ~= nil)
end

local function ApplyItemDisplayData(result, nameText, iconTexture)
    if not result or not result.itemID then return false end

    local loader = GetItemDataLoader()
    local cached =
        loader
        and loader.GetCachedItem
        and loader:GetCachedItem(result.itemID)

    if cached and cached.name then
        return ApplyItemDisplayRecord(result, cached, nameText, iconTexture)
    end

    local itemName, itemLink, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(result.itemID)
    if itemName or icon then
        return ApplyItemDisplayRecord(result, {
            name = itemName,
            link = itemLink,
            quality = quality,
            icon = icon,
        }, nameText, iconTexture)
    end

    return false
end

local function RequestItemDisplayData(result, nameText, iconTexture)
    if not result or not result.itemID then return end
    if ApplyItemDisplayData(result, nameText, iconTexture) then return end

    local itemID = tonumber(result.itemID)
    if not itemID then return end

    local loader = GetItemDataLoader()
    if loader and loader.LoadItemData then
        loader:LoadItemData(itemID, function(_, itemData)
            ApplyItemDisplayRecord(result, itemData, nameText, iconTexture)
        end)
        return
    end

    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

local function ClearListElements()
    for _, el in ipairs(listElements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    wipe(listElements)
end

local function ClearDetailElements()
    for _, el in ipairs(detailElements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    wipe(detailElements)
end

local function UpdateSourceButtonStates()
    for _, btn in ipairs(sourceButtons) do
        if btn.sourceKey == currentSource then
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn.highlight:Show()
        else
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            btn.highlight:Hide()
        end
    end
end

local function UpdateFavoriteFilterButton()
    if not favoriteFilterButton then return end
    if favoritesOnly then
        favoriteFilterButton:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        favoriteFilterButton:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        favoriteFilterButton.highlight:Show()
    else
        favoriteFilterButton:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        favoriteFilterButton:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        favoriteFilterButton.highlight:Hide()
    end
end

local function CreateSourceButton(parent, def)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(SOURCE_BTN_H)
    btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local label = OneWoW_GUI:CreateFS(btn, 10)
    label:SetPoint("CENTER", 0, 0)
    label:SetText(L[def.labelKey])
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local textWidth = label:GetStringWidth()
    btn:SetWidth(math.max(36, textWidth + SOURCE_BTN_PAD_X * 2))

    btn.label     = label
    btn.sourceKey = def.key

    btn.highlight = btn:CreateTexture(nil, "OVERLAY")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    btn.highlight:SetAlpha(0.15)
    btn.highlight:Hide()

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L[def.labelKey], 1, 1, 1)
        GameTooltip:AddLine(L[def.descKey], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        if self.sourceKey == currentSource then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self)
        currentSource = self.sourceKey
        selectedItem  = nil
        UpdateSourceButtonStates()
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
            emptyDetail:Show()
        end
        RefreshItemList()
    end)

    return btn
end

local function CreateItemRow(parent, result, yOffset, rowIdx, onClick)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ITEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    row:SetBackdrop(BACKDROP_SIMPLE)

    if rowIdx % 2 == 0 then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    else
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    end
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    iconFrame:SetSize(22, 22)
    iconFrame:SetPoint("LEFT", 4, 0)
    iconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    iconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    iconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    if result.icon then
        icon:SetTexture(result.icon)
    else
        icon:SetTexture(134400)
        local tsAddon = ns.Catalog and ns.Catalog:GetDataAddon("tradeskills")
        if tsAddon and tsAddon.DataLoader then
            tsAddon.DataLoader:LoadItemData(result.itemID, function(_, itemData)
                if row:IsVisible() and itemData and itemData.icon then
                    icon:SetTexture(itemData.icon)
                end
            end)
        end
    end

    local hasOwned = result.ownedCount and result.ownedCount > 0
    local showFav = ns.Favorites and result.itemID
    local useRightChrome = hasOwned or showFav

    local rightCluster, qtyBadge, favBtn
    if useRightChrome then
        -- Right cluster, LTR: name … xN … star (quantity left of star, star flush right).
        rightCluster = CreateFrame("Frame", nil, row)
        rightCluster:SetHeight(ITEM_ROW_HEIGHT)
        rightCluster:SetPoint("RIGHT", row, "RIGHT", -4, 0)

        if showFav then
            favBtn = OneWoW_GUI:CreateFavoriteToggleButton(rightCluster, {
                size     = 16,
                favorite = IsItemFavorite(result.itemID),
                tooltipTitle = L["CATALOG_FAVORITE"],
                tooltipText  = L["ITEMSEARCH_FAVORITE_TT"] or L["CATALOG_FAVORITE_TT"],
                onClick = function(_, on)
                    SetItemSearchFavorite(result, on)
                    RefreshItemList()
                end,
            })
            favBtn:SetPoint("RIGHT", rightCluster, "RIGHT", 0, 0)
        end

        if hasOwned then
            qtyBadge = OneWoW_GUI:CreateFS(rightCluster, 10)
            qtyBadge:SetText("x" .. result.ownedCount)
            qtyBadge:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            if favBtn then
                qtyBadge:SetPoint("RIGHT", favBtn, "LEFT", -4, 0)
            else
                qtyBadge:SetPoint("RIGHT", rightCluster, "RIGHT", 0, 0)
            end
        end

        local clusterW = 4
        if favBtn then
            clusterW = clusterW + 20
        end
        if qtyBadge then
            clusterW = clusterW + math.max(22, qtyBadge:GetStringWidth() + 4)
        end
        rightCluster:SetWidth(math.max(clusterW, 28))
    end

    local nameText = OneWoW_GUI:CreateFS(row, 10)
    nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
    if rightCluster then
        nameText:SetPoint("RIGHT", rightCluster, "LEFT", -6, 0)
    else
        nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    end
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(result.name or ("Item #" .. result.itemID))
    nameText:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))
    RequestItemDisplayData(result, nameText, icon)

    row.result = result
    row.rowIdx = rowIdx

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(result.itemID)
        RefreshResultNameFromTooltip(result, nameText)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Ctrl-click to preview", 0, 1, 0)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if selectedItem and selectedItem.itemID == result.itemID then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        elseif self.rowIdx % 2 == 0 then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self)
        if HandleItemPreviewClick(self.result.itemID, self.result.itemLink) then
            return
        end

        if onClick then onClick(self.result) end
    end)

    return row
end

ShowItemDetail = function(result)
    if not panels or not result then return end

    selectedItem = result
    ClearDetailElements()
    if emptyDetail then emptyDetail:Hide() end

    local child   = panels.detailScrollChild
    local yOffset = -8

    local headerFrame = CreateFrame("Frame", nil, child, "BackdropTemplate")
    headerFrame:SetHeight(50)
    headerFrame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
    headerFrame:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
    headerFrame:SetBackdrop(BACKDROP_SIMPLE)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    headerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    table.insert(detailElements, headerFrame)

    local hIconFrame = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
    hIconFrame:SetSize(40, 40)
    hIconFrame:SetPoint("LEFT", 8, 0)
    hIconFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    hIconFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    hIconFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local hIcon = hIconFrame:CreateTexture(nil, "ARTWORK")
    hIcon:SetPoint("TOPLEFT", 1, -1)
    hIcon:SetPoint("BOTTOMRIGHT", -1, 1)
    hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    hIcon:SetTexture(result.icon or 134400)

    hIconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(result.itemID)
        RefreshResultNameFromTooltip(result, itemName)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Ctrl-click to preview", 0, 1, 0)
        GameTooltip:Show()
    end)
    hIconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    hIconFrame:SetScript("OnClick", function()
        HandleItemPreviewClick(result.itemID, result.itemLink)
    end)

    local itemName = OneWoW_GUI:CreateFS(headerFrame, 16)
    itemName:SetPoint("TOPLEFT", hIconFrame, "TOPRIGHT", 8, -2)
    itemName:SetPoint("RIGHT", headerFrame, "RIGHT", -8, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(false)
    itemName:SetText(result.name or ("Item #" .. result.itemID))
    itemName:SetTextColor(OneWoW_GUI:GetItemQualityColor(result.quality))
    RequestItemDisplayData(result, itemName, hIcon)

    local itemIDText = OneWoW_GUI:CreateFS(headerFrame, 10)
    itemIDText:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -2)
    itemIDText:SetText(L["ITEMSEARCH_ITEM_ID"] .. ": " .. result.itemID)
    itemIDText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 58

    local detail = ns.ItemSearch and ns.ItemSearch:GetDetail(result.itemID)
        or { drops = {}, vendors = {}, crafted = {}, owned = {} }

    local function AddSectionHeader(titleKey)
        local sec = CreateFrame("Frame", nil, child, "BackdropTemplate")
        sec:SetHeight(24)
        sec:SetPoint("TOPLEFT", child, "TOPLEFT", 0, yOffset)
        sec:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, yOffset)
        sec:SetBackdrop(BACKDROP_SIMPLE)
        sec:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        sec:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        table.insert(detailElements, sec)

        local title = OneWoW_GUI:CreateFS(sec, 12)
        title:SetPoint("LEFT", 8, 0)
        title:SetText(L[titleKey])
        title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        yOffset = yOffset - 28
    end

    local function AddTextRow(text, indent, colorKey, onClick)
        local r = CreateFrame(onClick and "Button" or "Frame", nil, child)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", child, "TOPLEFT", indent or 12, yOffset)
        r:SetPoint("TOPRIGHT", child, "TOPRIGHT", -8, yOffset)
        table.insert(detailElements, r)

        local fs = OneWoW_GUI:CreateFS(r, 10)
        fs:SetPoint("LEFT", 0, 0)
        fs:SetText(text)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey or "TEXT_PRIMARY"))

        if onClick then
            r:SetScript("OnEnter", function()
                fs:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end)
            r:SetScript("OnLeave", function()
                fs:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey or "TEXT_PRIMARY"))
            end)
            r:SetScript("OnClick", onClick)
        end

        yOffset = yOffset - 18
    end

    AddSectionHeader("ITEMSEARCH_SECTION_DROPS")
    if #detail.drops > 0 then
        for _, drop in ipairs(detail.drops) do
            local line = drop.instanceName or ""
            if drop.encounterName then
                line = line .. "  -  " .. drop.encounterName
            end
            AddTextRow(line, 12, "TEXT_PRIMARY", function()
                if drop.mapID and ns.UI and ns.UI.OpenToInstance then
                    ns.UI.OpenToInstance(drop.mapID)
                end
            end)
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_DROPS"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 6

    AddSectionHeader("ITEMSEARCH_SECTION_VENDORS")
    if #detail.vendors > 0 then
        for _, v in ipairs(detail.vendors) do
            local line = v.name or L["VENDORS_UNKNOWN"]
            if v.zone and v.zone ~= "" then
                line = line .. "  (" .. v.zone .. ")"
            end
            AddTextRow(line, 12, "TEXT_PRIMARY", function()
                if ns.UI and ns.UI.OpenVendorSearch then
                    ns.UI.OpenVendorSearch(v.name or tostring(v.npcID or ""))
                end
            end)
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_VENDORS"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 6

    if detail.isRecipe then
        AddSectionHeader("ITEMSEARCH_SECTION_KNOWNBY")
        if detail.recipeKnownBy and #detail.recipeKnownBy > 0 then
            for _, charKey in ipairs(detail.recipeKnownBy) do
                local charName = charKey:match("^([^%-]+)") or charKey
                AddTextRow(charName, 12, "TEXT_PRIMARY")
            end
        else
            AddTextRow(L["ITEMSEARCH_NO_KNOWNBY"], 12, "TEXT_MUTED")
        end
    else
        AddSectionHeader("ITEMSEARCH_SECTION_CRAFTED")
        if #detail.crafted > 0 then
            for _, c in ipairs(detail.crafted) do
                AddTextRow(c.profName or "", 12, "TEXT_PRIMARY", function()
                    if ns.UI and ns.UI.OpenTradeskillSearch then
                        ns.UI.OpenTradeskillSearch(result.name or tostring(result.itemID), c.profName)
                    end
                end)
                if c.knownBy and #c.knownBy > 0 then
                    for _, charKey in ipairs(c.knownBy) do
                        AddTextRow(charKey, 24, "TEXT_SECONDARY")
                    end
                else
                    AddTextRow(L["TRADESKILLS_NOT_SCANNED"], 24, "TEXT_MUTED")
                end
            end
        else
            AddTextRow(L["ITEMSEARCH_NO_CRAFTED"], 12, "TEXT_MUTED")
        end
    end

    yOffset = yOffset - 6

    AddSectionHeader("ITEMSEARCH_SECTION_QUESTS")
    if detail.quests and #detail.quests > 0 then
        for _, quest in ipairs(detail.quests) do
            local line = quest.name or ("Quest #" .. tostring(quest.questID))
            if quest.questID then
                line = line .. "  |cFF888888(" .. tostring(quest.questID) .. ")|r"
            end
            AddTextRow(line, 12, "TEXT_PRIMARY", function()
                if ns.UI and ns.UI.OpenQuest then
                    ns.UI.OpenQuest(quest.questID)
                end
            end)
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_QUESTS"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 6

    local locLabels = {
        bags    = L["ITEMSEARCH_LOC_BAGS"],
        bank    = L["ITEMSEARCH_LOC_BANK"],
        mail    = L["ITEMSEARCH_LOC_MAIL"],
        warband = L["ITEMSEARCH_LOC_WARBAND"],
        guild   = L["ITEMSEARCH_LOC_GUILD"],
        ah      = L["ITEMSEARCH_LOC_AH"],
    }

    AddSectionHeader("ITEMSEARCH_SECTION_INVENTORY")
    if #detail.owned > 0 then
        for _, owned in ipairs(detail.owned) do
            local locLabel = locLabels[owned.locLabel] or owned.locLabel
            local line = owned.charName .. "  -  " .. locLabel .. "  x" .. owned.count
            AddTextRow(line, 12, "TEXT_PRIMARY", function()
                if _G["OneWoW_Notes"] and _G["OneWoW_Notes"].UI and _G["OneWoW_Notes"].UI.OpenNotesItem then
                    _G["OneWoW_Notes"].UI.OpenNotesItem(result.itemID)
                end
            end)
        end
    else
        AddTextRow(L["ITEMSEARCH_NO_INVENTORY"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 6

    AddSectionHeader("ITEMSEARCH_SECTION_VALUE")

    local _, itemLink, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(result.itemID)
    local vendorSellPrice = sellPrice or 0

    if vendorSellPrice > 0 then
        AddTextRow(L["ITEMSEARCH_VENDOR_PRICE"] .. ":  " .. OneWoW_GUI:FormatGold(vendorSellPrice), 12, "TEXT_PRIMARY")
    else
        AddTextRow(L["ITEMSEARCH_NOT_SELLABLE"], 12, "TEXT_MUTED")
    end

    local ahPrice, ahMeta
    local ow = OneWoW
    if ow and ow.ItemPrices then
        ahPrice, ahMeta = ow.ItemPrices:GetUnitAHPrice(result.itemID, itemLink)
    end
    if not ahPrice or ahPrice <= 0 then
        local priceDB = OneWoW_AHPrices
        local ahData = priceDB and priceDB[result.itemID]
        if ahData and ahData.price and ahData.price > 0 then
            ahPrice = ahData.price
            ahMeta = { source = "onewow", timestamp = ahData.timestamp }
        end
    end
    if ahPrice and ahPrice > 0 then
        local ageText
        if ahMeta and ahMeta.timestamp and ahMeta.timestamp > 0 then
            local ageSeconds = GetServerTime() - ahMeta.timestamp
            if ageSeconds < 3600 then
                ageText = math.max(1, math.floor(ageSeconds / 60)) .. "m " .. L["ITEMSEARCH_AH_AGO"]
            elseif ageSeconds < 86400 then
                ageText = math.floor(ageSeconds / 3600) .. "h " .. L["ITEMSEARCH_AH_AGO"]
            else
                ageText = math.floor(ageSeconds / 86400) .. "d " .. L["ITEMSEARCH_AH_AGO"]
            end
        elseif ahMeta and ahMeta.ageDays ~= nil then
            ageText = string.format(L["ITEMSEARCH_AH_AGE_DAYS"] or "%d d", ahMeta.ageDays) .. " " .. L["ITEMSEARCH_AH_AGO"]
        end
        local row = L["ITEMSEARCH_AH_PRICE"] .. ":  " .. OneWoW_GUI:FormatGold(ahPrice)
        if ageText then
            row = row .. "  |cFF888888(" .. ageText .. ")|r"
        end
        AddTextRow(row, 12, "TEXT_PRIMARY")
    else
        AddTextRow(L["ITEMSEARCH_NO_AH_DATA"], 12, "TEXT_MUTED")
    end

    yOffset = yOffset - 10
    child:SetHeight(math.abs(yOffset) + 20)
end

RefreshItemList = function()
    if not panels then return end
    UpdateItemSearchScanButton()
    ClearListElements()
    panels.listScrollFrame:SetVerticalScroll(0)

    if not ns.ItemSearch then
        panels.listScrollChild:SetHeight(100)
        if emptyList then emptyList:SetText(L["ITEMSEARCH_EMPTY"]); emptyList:Show() end
        return
    end

    local results, limitReached

    if favoritesOnly and (currentSearch == "" or #currentSearch < 2) then
        results = GetFavoriteItemResults()
        limitReached = false
        if not results or #results == 0 then
            panels.listScrollChild:SetHeight(100)
            if emptyList then emptyList:SetText(L["ITEMSEARCH_NO_RESULTS"]); emptyList:Show() end
            if panels.leftStatusText then panels.leftStatusText:SetText("") end
            return
        end
    elseif currentSearch == "" or #currentSearch < 2 then
        results = ns.ItemSearch:GetDefaultItems(50)
        limitReached = false
        if not results or #results == 0 then
            panels.listScrollChild:SetHeight(100)
            if emptyList then emptyList:SetText(L["ITEMSEARCH_EMPTY"]); emptyList:Show() end
            if panels.leftStatusText then panels.leftStatusText:SetText("") end
            return
        end
    else
        results, limitReached = ns.ItemSearch:Query(currentSearch, currentSource)
        if favoritesOnly and results then
            local filtered = {}
            for _, result in ipairs(results) do
                if IsItemFavorite(result.itemID) then
                    table.insert(filtered, result)
                end
            end
            results = filtered
        end
        if not results or #results == 0 then
            panels.listScrollChild:SetHeight(100)
            if emptyList then emptyList:SetText(L["ITEMSEARCH_NO_RESULTS"]); emptyList:Show() end
            if panels.leftStatusText then panels.leftStatusText:SetText("") end
            return
        end
    end

    if emptyList then emptyList:Hide() end

    if #results > 0 then
        local origOrder = {}
        for i, r in ipairs(results) do
            if r.itemID then origOrder[tostring(r.itemID)] = i end
        end
        table.sort(results, function(a, b)
            local fa = IsItemFavorite(a.itemID)
            local fb = IsItemFavorite(b.itemID)
            if fa ~= fb then return fa end
            local oa = a.itemID and origOrder[tostring(a.itemID)] or 0
            local ob = b.itemID and origOrder[tostring(b.itemID)] or 0
            return oa < ob
        end)
    end

    local yOffset = -4
    local rowIdx  = 0

    for _, result in ipairs(results) do
        local row = CreateItemRow(panels.listScrollChild, result, yOffset, rowIdx, function(r)
            selectedItem = r
            for _, el in ipairs(listElements) do
                if el.result and el.result.itemID == r.itemID then
                    el:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                    el:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                elseif el.rowIdx and el.rowIdx % 2 == 0 then
                    el:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
                    el:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                else
                    el:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    el:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end
            end
            ShowItemDetail(r)
        end)
        table.insert(listElements, row)
        yOffset = yOffset - ITEM_ROW_HEIGHT
        rowIdx  = rowIdx + 1
    end

    panels.listScrollChild:SetHeight(math.abs(yOffset) + 10)

    if panels.leftStatusText then
        local n = #results
        if currentSearch == "" or #currentSearch < 2 then
            panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_BROWSE_DEFAULT"], n))
        elseif limitReached then
            panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_RESULTS_CAPPED"], n))
        else
            panels.leftStatusText:SetText(string.format(L["ITEMSEARCH_RESULTS"], n))
        end
    end
end

function ns.UI.CreateItemSearchTab(parent)
    local LEFT_W = ns.Constants.GUI.LEFT_PANEL_WIDTH
    local GAP    = ns.Constants.GUI.PANEL_GAP

    local searchHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HEADER_H, offset = 0 })
    searchHeader:ClearAllPoints()
    searchHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    searchHeader:SetWidth(LEFT_W)

    local filterHeader = OneWoW_GUI:CreateFilterBar(parent, { height = HEADER_H, offset = 0 })
    filterHeader:ClearAllPoints()
    filterHeader:SetPoint("TOPLEFT", searchHeader, "TOPRIGHT", GAP, 0)
    filterHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local noticeBar = OneWoW_GUI:CreateFilterBar(parent, { height = 28, offset = 0 })
    noticeBar:ClearAllPoints()
    noticeBar:SetPoint("TOPLEFT", searchHeader, "BOTTOMLEFT", 0, -2)
    noticeBar:SetPoint("TOPRIGHT", filterHeader, "BOTTOMRIGHT", 0, -2)

    local noticeText = OneWoW_GUI:CreateFS(noticeBar, 12)
    noticeText:SetPoint("LEFT", noticeBar, "LEFT", 12, 0)
    noticeText:SetPoint("RIGHT", noticeBar, "RIGHT", -12, 0)
    noticeText:SetJustifyH("LEFT")
    noticeText:SetWordWrap(true)
    noticeText:SetText(L["ITEMSEARCH_NOTICE"])
    noticeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", noticeBar, "BOTTOMLEFT", 0, -2)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    panels = OneWoW_GUI:CreateSplitPanel(contentArea)
    panels.listTitle:SetText(L["ITEMSEARCH_LIST_TITLE"])
    panels.detailTitle:SetText(L["ITEMSEARCH_DETAIL_TITLE"])

    for _, def in ipairs(SOURCE_DEFS) do
        local btn = CreateSourceButton(filterHeader, def)
        table.insert(sourceButtons, btn)
    end

    favoriteFilterButton = CreateFrame("Button", nil, filterHeader, "BackdropTemplate")
    favoriteFilterButton:SetHeight(SOURCE_BTN_H)
    favoriteFilterButton:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    favoriteFilterButton:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    favoriteFilterButton:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    local favLabel = OneWoW_GUI:CreateFS(favoriteFilterButton, 10)
    favLabel:SetPoint("CENTER", 0, 0)
    favLabel:SetText(L["ITEMSEARCH_FILTER_FAVORITES"] or "Favorites")
    favLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    favoriteFilterButton:SetWidth(math.max(62, favLabel:GetStringWidth() + SOURCE_BTN_PAD_X * 2))
    favoriteFilterButton.highlight = favoriteFilterButton:CreateTexture(nil, "OVERLAY")
    favoriteFilterButton.highlight:SetAllPoints()
    favoriteFilterButton.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    favoriteFilterButton.highlight:SetAlpha(0.15)
    favoriteFilterButton.highlight:Hide()
    favoriteFilterButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["ITEMSEARCH_FILTER_FAVORITES"] or "Favorites", 1, 1, 1)
        GameTooltip:AddLine(L["ITEMSEARCH_FILTER_FAVORITES_DESC"] or "Show only favorite items.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    favoriteFilterButton:SetScript("OnLeave", function()
        UpdateFavoriteFilterButton()
        GameTooltip:Hide()
    end)
    favoriteFilterButton:SetScript("OnClick", function()
        favoritesOnly = not favoritesOnly
        selectedItem = nil
        UpdateFavoriteFilterButton()
        ClearDetailElements()
        if emptyDetail then
            emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
            emptyDetail:Show()
        end
        RefreshItemList()
    end)

    local containerWidth = parent:GetWidth() - LEFT_W - GAP
    if not containerWidth or containerWidth < FILTER_BUTTONS_MIN_WIDTH then
        containerWidth = FILTER_BUTTONS_MIN_WIDTH
    end
    local padLeft = 6
    local padTop  = 5
    local xOff    = padLeft
    local btnRow  = 0
    local filterButtons = {}
    for _, btn in ipairs(sourceButtons) do table.insert(filterButtons, btn) end
    table.insert(filterButtons, favoriteFilterButton)
    for _, btn in ipairs(filterButtons) do
        local btnWidth = btn:GetWidth()
        if xOff + btnWidth + SOURCE_BTN_GAP > containerWidth - padLeft and xOff > padLeft then
            btnRow = btnRow + 1
            xOff   = padLeft
        end
        local yOff = -padTop - (btnRow * (SOURCE_BTN_H + SOURCE_BTN_GAP))
        btn:SetPoint("TOPLEFT", filterHeader, "TOPLEFT", xOff, yOff)
        xOff = xOff + btnWidth + SOURCE_BTN_GAP
    end

    searchBox = OneWoW_GUI:CreateEditBox(searchHeader, {
        height = 26,
        maxLetters = 50,
        placeholderText = L["ITEMSEARCH_PLACEHOLDER"],
        onTextChanged = function(text)
            if searchTimer then searchTimer:Cancel() end
            searchTimer = C_Timer.NewTimer(0.3, function()
                currentSearch = text
                selectedItem = nil
                ClearDetailElements()
                if emptyDetail then
                    emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
                    emptyDetail:Show()
                end
                RefreshItemList()
            end)
        end,
    })
    searchBox:SetPoint("TOPLEFT", searchHeader, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -118, -8)

    local scanAHButton = OneWoW_GUI:CreateFitTextButton(searchHeader, { text = L["ITEMSEARCH_SCAN_AH"], height = 26, minWidth = 100 })
    scanAHButton:SetPoint("TOPRIGHT", searchHeader, "TOPRIGHT", -8, -8)
    scanAHButton.isScanning = false
    scanAHButtonRef = scanAHButton
    UpdateItemSearchScanButton()

    local scanBarContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scanBarContainer:SetPoint("TOPLEFT", noticeBar, "BOTTOMLEFT", 0, -2)
    scanBarContainer:SetPoint("TOPRIGHT", noticeBar, "BOTTOMRIGHT", 0, -2)
    scanBarContainer:SetHeight(20)
    scanBarContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    scanBarContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    scanBarContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    scanBarContainer:Hide()

    local scanProgressBar = OneWoW_GUI:CreateProgressBar(scanBarContainer, { height = 14, min = 0, max = 1, value = 0 })
    scanProgressBar:SetPoint("TOPLEFT", scanBarContainer, "TOPLEFT", 4, -3)
    scanProgressBar:SetPoint("TOPRIGHT", scanBarContainer, "TOPRIGHT", -4, -3)

    local function UpdateContentAnchor()
        if scanBarContainer:IsShown() then
            contentArea:SetPoint("TOPLEFT", scanBarContainer, "BOTTOMLEFT", 0, -2)
        else
            contentArea:SetPoint("TOPLEFT", noticeBar, "BOTTOMLEFT", 0, -2)
        end
    end

    scanAHButton:SetScript("OnClick", function(self)
        if self.isScanning then
            local Auctions = OneWoW_AltTracker_Auctions
            if Auctions and Auctions.FullAHScanner then
                Auctions.FullAHScanner:StopScan()
            end
            return
        end

        if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
            print("|cFFFFD100OneWoW:|r " .. L["ITEMSEARCH_AH_NOT_OPEN"])
            return
        end

        local Auctions = OneWoW_AltTracker_Auctions
        if not Auctions or not Auctions.FullAHScanner then
            print("|cFFFFD100OneWoW:|r " .. L["ITEMSEARCH_ALTTRACKER_AUCTIONS_REQUIRED"])
            return
        end

        local canScan, minutesLeft = Auctions.FullAHScanner:CanScan()
        if not canScan then
            print("|cFFFFD100OneWoW:|r " .. string.format(L["ITEMSEARCH_AH_SCAN_COOLDOWN"], minutesLeft))
            return
        end

        self.isScanning = true
        self:SetText(L["ITEMSEARCH_SCAN_STOP"])

        scanBarContainer:Show()
        UpdateContentAnchor()

        Auctions.FullAHScanner:StartScan(function(status, progress, extra)
            if status == "scanStarted" then
                scanProgressBar:UpdateProgress(0, 1)
                scanProgressBar._text:SetText(L["ITEMSEARCH_SCAN_WAITING"])
            elseif status == "scanWaiting" then
                local elapsed = extra or 0
                scanProgressBar:UpdateProgress(0.1, 1)
                scanProgressBar._text:SetText(L["ITEMSEARCH_SCAN_WAITING"] .. " (" .. elapsed .. "s)")
            elseif status == "scanProgress" then
                local pct = progress or 0
                local totalItems = extra
                local pctDisplay = math.floor(pct * 100)
                local text = string.format(L["ITEMSEARCH_SCAN_PROCESSING"], pctDisplay)
                if totalItems and totalItems > 0 then
                    text = text .. "  (" .. totalItems .. " " .. L["ITEMSEARCH_AH_AUCTIONS"] .. ")"
                end
                scanProgressBar:UpdateProgress(pct, 1)
                scanProgressBar._text:SetText(text)
            elseif status == "scanCompleted" then
                local found = extra or 0
                scanProgressBar:UpdateProgress(1, 1)
                scanProgressBar._text:SetText(L["ITEMSEARCH_SCAN_COMPLETE"] .. "  (" .. found .. " " .. L["ITEMSEARCH_PRICES_FOUND"] .. ")")
                self.isScanning = false
                self:SetText(L["ITEMSEARCH_SCAN_AH"])
                if selectedItem then
                    ShowItemDetail(selectedItem)
                end
                C_Timer.After(3, function()
                    scanBarContainer:Hide()
                    UpdateContentAnchor()
                end)
            elseif status == "scanStopped" then
                self.isScanning = false
                self:SetText(L["ITEMSEARCH_SCAN_AH"])
                scanBarContainer:Hide()
                UpdateContentAnchor()
                if selectedItem then
                    ShowItemDetail(selectedItem)
                end
            elseif status == "scanFailed" then
                self.isScanning = false
                self:SetText(L["ITEMSEARCH_SCAN_AH"])
                scanBarContainer:Hide()
                UpdateContentAnchor()
                print("|cFFFFD100OneWoW:|r AH closed during scan.")
            end
        end)
    end)

    emptyList = OneWoW_GUI:CreateFS(panels.listScrollChild, 12)
    emptyList:SetPoint("CENTER", panels.listScrollChild, "CENTER", 0, 0)
    emptyList:SetText(L["ITEMSEARCH_EMPTY"])
    emptyList:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    emptyDetail = OneWoW_GUI:CreateFS(panels.detailScrollChild, 12)
    emptyDetail:SetPoint("CENTER", panels.detailScrollChild, "CENTER", 0, 0)
    emptyDetail:SetText(L["ITEMSEARCH_SELECT"])
    emptyDetail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    panels.detailScrollChild:SetHeight(100)

    UpdateSourceButtonStates()
    UpdateFavoriteFilterButton()
    RefreshItemList()

    ns.UI.RefreshItemSearchList = RefreshItemList

    ns.UI.OpenItemSearch = function(itemID, itemName)
        itemID = tonumber(itemID)
        if not itemID or not ns.ItemSearch then
            return false
        end

        local result = ns.ItemSearch:GetItemEntry(itemID)
        if not result then
            return false
        end

        currentSource = "all"
        favoritesOnly = false
        currentSearch = itemName or result.name or tostring(itemID)
        if currentSearch:match("^Item #%d+$") then
            currentSearch = tostring(itemID)
        end
        selectedItem = result

        if searchBox then
            searchBox:SetText(currentSearch)
            searchBox:ClearFocus()
        end

        UpdateSourceButtonStates()
        UpdateFavoriteFilterButton()
        RefreshItemList()
        ShowItemDetail(result)
        return true
    end
end

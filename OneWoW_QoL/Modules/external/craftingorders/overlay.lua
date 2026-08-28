local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local floor = math.floor

local SPACING = OneWoW_GUI.Constants.SPACING

local HEADER_H = 24
local ROW_H = 60
local ICON_SIZE = 36
local MAT_SIZE = 24
local REWARD_SIZE = 24
local MAX_YOU = 4
local MAX_CUST = 4
local MAX_REWARDS = 4
local MAT_GAP = SPACING.XS
local STATUS_H = 20
local COL_H = 32
local TIME_W = 72
local CART_W = 40
local COL_GAP = SPACING.MD
local COL_PAD = SPACING.SM
local ROW_INSET = 4
-- Must match OneWoW_GUI:CreateVirtualizer owned-scroll insets (4 / 14).
local VIRT_LEFT = 4
local VIRT_RIGHT = 14
local LIST_LEFT = 2
local LIST_RIGHT = 4
local HEADER_LEFT = LIST_LEFT + VIRT_LEFT + ROW_INSET
local HEADER_RIGHT = LIST_RIGHT + VIRT_RIGHT + ROW_INSET

local function ClusterW(n, size)
    return n * (size + MAT_GAP) - MAT_GAP
end

local YOU_W = ClusterW(MAX_YOU, MAT_SIZE)
local CUST_W = ClusterW(MAX_CUST, MAT_SIZE)
local REWARD_W = ClusterW(MAX_REWARDS, REWARD_SIZE)

-- Same right-edge insets for column labels and row lanes. Each icon
-- cluster lives in a fixed-width lane so unused slots cannot slide
-- visible icons into the next column.
local COL_TIME_RIGHT = COL_PAD
local COL_REWARD_RIGHT = COL_TIME_RIGHT + TIME_W + COL_GAP
local COL_CUST_RIGHT = COL_REWARD_RIGHT + REWARD_W + COL_GAP
local COL_CART_RIGHT = COL_CUST_RIGHT + CUST_W + COL_GAP
local COL_YOU_RIGHT = COL_CART_RIGHT + CART_W + COL_GAP
local COL_ORDER_RIGHT = COL_YOU_RIGHT + YOU_W + COL_GAP

local function PlaceColLabel(fs, parent, rightInset, width, justifyH)
    fs:ClearAllPoints()
    -- TOPRIGHT/BOTTOMRIGHT give the label the parent's height. RIGHT is a
    -- single midpoint, so TOP+BOTTOM on it would collapse the fontstring.
    fs:SetPoint("TOPLEFT", parent, "TOPRIGHT", -(rightInset + width), 0)
    fs:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -rightInset, 0)
    fs:SetJustifyH(justifyH or "LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(true)
    fs:SetMaxLines(2)
end

local function PlaceIconLane(frame, parent, rightInset, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("RIGHT", parent, "RIGHT", -rightInset, 0)
    frame:SetSize(width, height)
end

local function ModuleOn()
    return ns.ModuleRegistry:IsEnabled("craftingorders")
end

function M:WantsOverlay()
    return ModuleOn() and not ns.ModuleRegistry:GetToggleValue("craftingorders", "useBlizzardList")
end

local function GetOrdersPage()
    local pf = ProfessionsFrame
    return pf and pf.OrdersPage
end

local function GetBrowseFrame()
    local page = GetOrdersPage()
    return page and page.BrowseFrame, page
end

local function GetOrderList()
    local browse = GetBrowseFrame()
    return browse and browse.OrderList
end

local function QualityColor(quality)
    if quality and quality > 0 then
        return OneWoW_GUI:GetItemQualityColor(quality)
    end
    return OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
end

local function ApplyOverlayTheme(overlay)
    local bgR, bgG, bgB = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
    local bdR, bdG, bdB = OneWoW_GUI:GetThemeColor("BORDER_DEFAULT")
    overlay:SetBackdropColor(bgR, bgG, bgB, 0.97)
    overlay:SetBackdropBorderColor(bdR, bdG, bdB, 1)
    overlay.colCraft:SetText(L["CRAFTORDERS_COL_CRAFT"])
    overlay.colYou:SetText(L["CRAFTORDERS_COL_YOU"])
    overlay.colCart:SetText(L["CRAFTORDERS_COL_CART"])
    overlay.colCustomer:SetText(L["CRAFTORDERS_COL_CUSTOMER"])
    overlay.colReward:SetText(L["CRAFTORDERS_COL_REWARD"])
    overlay.colTime:SetText(CLOSES_IN)
    local tpR, tpG, tpB = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
    overlay.statusText:SetTextColor(tpR, tpG, tpB)
    overlay.colCraft:SetTextColor(tpR, tpG, tpB)
    overlay.colYou:SetTextColor(tpR, tpG, tpB)
    overlay.colCart:SetTextColor(tpR, tpG, tpB)
    overlay.colCustomer:SetTextColor(tpR, tpG, tpB)
    overlay.colReward:SetTextColor(tpR, tpG, tpB)
    overlay.colTime:SetTextColor(tpR, tpG, tpB)
    overlay.emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    if overlay.headerBar then
        overlay.headerBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        overlay.headerBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
end

local function HideBlizzardOrderList()
    local list = GetOrderList()
    if list then
        list:Hide()
    end
end

local function ShowBlizzardOrderList()
    local list = GetOrderList()
    if list then
        list:Show()
    end
end

function M:IsOverlayActive()
    return M:WantsOverlay() and M._overlay and M._overlay:IsShown()
end

local function ApplyRowChrome(row, index, entry, selected, hover)
    if entry and entry.kind == "header" then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        return
    end
    if selected then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        return
    end
    if hover then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        return
    end
    local fill = (index % 2 == 1) and "BG_PRIMARY" or "BG_SECONDARY"
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor(fill))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
end

local function HideStrip(icons)
    for i = 1, #icons do
        icons[i]:Hide()
    end
end

local function OnDataIconEnter(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
    if icon._itemLink then
        GameTooltip:SetHyperlink(icon._itemLink)
    elseif icon._itemID then
        GameTooltip:SetItemByID(icon._itemID)
        if icon._youProvide then
            GameTooltip:AddLine(PROFESSIONS_CUSTOMER_ORDER_REAGENT_NOTPROVIDED, OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            local tip = M:GetElsewhereTooltip({ missingReagents = { { itemID = icon._itemID } } })
            if tip then
                GameTooltip:AddLine(tip, OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        elseif icon._customerProvide then
            GameTooltip:AddLine(PROFESSIONS_CUSTOMER_ORDER_REAGENT_PROVIDED, OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    elseif icon._currencyType then
        local info = C_CurrencyInfo.GetCurrencyInfo(icon._currencyType)
        GameTooltip:SetText(info and info.name or "")
        if icon._count and icon._count > 1 then
            GameTooltip:AddLine("x" .. icon._count, OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    elseif icon._gold then
        GameTooltip:SetText(GetMoneyString(icon._gold, true))
        if icon._tipAvg and icon._tipMax then
            GameTooltip:AddLine(GetMoneyString(icon._tipAvg, true) .. " / " .. GetMoneyString(icon._tipMax, true), OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    else
        GameTooltip:Hide()
        return
    end
    GameTooltip:Show()
end

local function SetCountText(icon, text, warning)
    local fs = icon._countText
    if not fs then return end
    fs:SetText(text or "")
    if warning then
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    else
        fs:SetTextColor(1, 1, 1, 1)
    end
end

local function BindDataIcon(icon, data, role)
    icon._itemID = nil
    icon._itemLink = nil
    icon._currencyType = nil
    icon._gold = nil
    icon._count = nil
    icon._tipAvg = nil
    icon._tipMax = nil
    icon._youProvide = role == "you"
    icon._customerProvide = role == "customer"
    if not data then
        icon:Hide()
        SetCountText(icon, "")
        return
    end
    icon:Show()
    if data.kind == "gold" then
        OneWoW_GUI:UpdateIconTexture(icon, data.icon)
        icon._gold = data.amount
        icon._tipAvg = data.tipAvg
        icon._tipMax = data.tipMax
        local goldAmt = floor((data.amount or 0) / COPPER_PER_GOLD)
        SetCountText(icon, goldAmt > 0 and tostring(goldAmt) or "")
        return
    end
    if data.kind == "currency" then
        OneWoW_GUI:UpdateIconTexture(icon, data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        icon._currencyType = data.currencyType
        icon._count = data.count
        SetCountText(icon, (data.count and data.count > 1) and tostring(data.count) or "")
        return
    end
    local itemID = data.itemID
    local tex = data.icon or (itemID and C_Item.GetItemIconByID(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
    OneWoW_GUI:UpdateIconTexture(icon, tex)
    icon._itemID = itemID
    icon._itemLink = data.itemLink
    if role == "you" then
        SetCountText(icon, (data.have or 0) .. "/" .. (data.need or 1), data.short and data.short > 0)
    elseif data.count and data.count > 1 then
        SetCountText(icon, tostring(data.count))
    elseif data.need and data.need > 1 then
        SetCountText(icon, tostring(data.need))
    else
        SetCountText(icon, "")
    end
end

local function BindStrip(icons, list, role)
    list = list or {}
    for i = 1, #icons do
        BindDataIcon(icons[i], list[i], role)
    end
end

local function FormatTimeLeft(entry)
    if entry.kind == "bucket" then return "" end
    local remaining = entry.remaining or 0
    if remaining <= 0 then return "" end
    local noSeconds = true
    return SecondsToTime(remaining, noSeconds)
end

local function BindHeader(row, entry)
    row.product:Hide()
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    if entry.section == "ready" then
        row.nameText:SetText(L["CRAFTORDERS_SECTION_READY"] .. " (" .. entry.count .. ")")
    elseif entry.section == "unknown" then
        row.nameText:SetText(PROFESSIONS_RECIPE_UNLEARNED .. " (" .. entry.count .. ")")
    else
        row.nameText:SetText(L["CRAFTORDERS_SECTION_MISSING"] .. " (" .. entry.count .. ")")
    end
    row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    row.timeText:SetText("")
    row.unlearnedText:SetText("")
    row.addBtn:Hide()
    row.addBtn._entry = nil
    HideStrip(row.youMats)
    HideStrip(row.customerMats)
    HideStrip(row.rewards)
end

local function BindRow(row, entry)
    row.product:Show()
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("LEFT", row.product, "RIGHT", 6, 8)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -COL_ORDER_RIGHT, 8)
    local icon = entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    OneWoW_GUI:UpdateIconTexture(row.product, icon)
    OneWoW_GUI:SetIconDesaturated(row.product, not entry.learned)
    row.product._itemID = entry.itemID
    row.nameText:SetText(entry.name or "")
    row.nameText:SetTextColor(QualityColor(entry.quality))
    if not entry.learned then
        row.unlearnedText:SetText(PROFESSIONS_CRAFTER_CANT_CLAIM_UNLEARNED)
        row.unlearnedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    elseif entry.isRecraft then
        row.unlearnedText:SetText(PROFESSIONS_CRAFTING_RECRAFT)
        row.unlearnedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    elseif entry.kind == "bucket" then
        row.unlearnedText:SetText(L["CRAFTORDERS_BUCKET_COUNT"]:format(entry.numAvailable or 0))
        row.unlearnedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    elseif entry.customerName and entry.customerName ~= "" then
        row.unlearnedText:SetText(entry.customerName)
        row.unlearnedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    else
        row.unlearnedText:SetText("")
    end
    row.timeText:SetText(FormatTimeLeft(entry))
    row.timeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    BindStrip(row.youMats, entry.youReagents, "you")
    BindStrip(row.customerMats, entry.customerReagents, "customer")
    BindStrip(row.rewards, entry.rewardIcons, "reward")

    local showAdd = entry.kind == "order" and entry.section ~= "ready"
        and entry.missingReagents and #entry.missingReagents > 0
    row.addBtn._entry = entry
    row.addBtn:SetShown(showAdd)
end

function M:EnsureOverlay()
    if M._overlay then return M._overlay end
    local browse = GetBrowseFrame()
    if not browse then return nil end

    local overlay = CreateFrame("Frame", nil, browse, "BackdropTemplate")
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", browse.RecipeList, "TOPRIGHT")
    overlay:SetPoint("BOTTOMLEFT", browse.RecipeList, "BOTTOMRIGHT")
    overlay:SetPoint("TOPRIGHT", browse, "TOPRIGHT")
    overlay:SetPoint("BOTTOMRIGHT", browse, "BOTTOMRIGHT")
    overlay:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    overlay:EnableMouse(true)
    overlay:Hide()
    OneWoW_GUI:RegisterFontRoot(overlay, function()
        if M:IsOverlayActive() then
            M:RefreshOverlay()
        end
    end)

    local statusText = OneWoW_GUI:CreateFS(overlay, 12)
    statusText:SetPoint("TOPLEFT", overlay, "TOPLEFT", 8, -4)
    statusText:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -8, -4)
    statusText:SetJustifyH("LEFT")
    overlay.statusText = statusText

    local headerBar = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
    headerBar:SetPoint("TOPLEFT", overlay, "TOPLEFT", HEADER_LEFT, -(4 + STATUS_H))
    headerBar:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -HEADER_RIGHT, -(4 + STATUS_H))
    headerBar:SetHeight(COL_H)
    headerBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    overlay.headerBar = headerBar

    local colCraft = OneWoW_GUI:CreateFS(headerBar, 11)
    colCraft:SetPoint("LEFT", headerBar, "LEFT", 4, 0)
    colCraft:SetPoint("RIGHT", headerBar, "RIGHT", -COL_ORDER_RIGHT, 0)
    colCraft:SetJustifyH("LEFT")
    colCraft:SetText(L["CRAFTORDERS_COL_CRAFT"])
    overlay.colCraft = colCraft

    local colTime = OneWoW_GUI:CreateFS(headerBar, 11)
    PlaceColLabel(colTime, headerBar, COL_TIME_RIGHT, TIME_W, "RIGHT")
    colTime:SetText(CLOSES_IN)
    overlay.colTime = colTime

    local colReward = OneWoW_GUI:CreateFS(headerBar, 11)
    PlaceColLabel(colReward, headerBar, COL_REWARD_RIGHT, REWARD_W)
    colReward:SetText(L["CRAFTORDERS_COL_REWARD"])
    overlay.colReward = colReward

    local colCustomer = OneWoW_GUI:CreateFS(headerBar, 11)
    PlaceColLabel(colCustomer, headerBar, COL_CUST_RIGHT, CUST_W)
    colCustomer:SetText(L["CRAFTORDERS_COL_CUSTOMER"])
    overlay.colCustomer = colCustomer

    local colCart = OneWoW_GUI:CreateFS(headerBar, 11)
    PlaceColLabel(colCart, headerBar, COL_CART_RIGHT, CART_W, "CENTER")
    colCart:SetText(L["CRAFTORDERS_COL_CART"])
    overlay.colCart = colCart

    local colYou = OneWoW_GUI:CreateFS(headerBar, 11)
    PlaceColLabel(colYou, headerBar, COL_YOU_RIGHT, YOU_W)
    colYou:SetText(L["CRAFTORDERS_COL_YOU"])
    overlay.colYou = colYou

    local listHost = CreateFrame("Frame", nil, overlay)
    listHost:SetPoint("TOPLEFT", overlay, "TOPLEFT", LIST_LEFT, -(4 + STATUS_H + COL_H))
    listHost:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -LIST_RIGHT, 4)
    overlay.listHost = listHost

    local emptyText = OneWoW_GUI:CreateFS(overlay, 12)
    emptyText:SetPoint("CENTER", listHost, "CENTER")
    emptyText:SetWidth(280)
    emptyText:SetJustifyH("CENTER")
    overlay.emptyText = emptyText

    ApplyOverlayTheme(overlay)

    M._entries = {}
    local virt = OneWoW_GUI:CreateVirtualizer(listHost, {
        getCount = function()
            return M._entries and #M._entries or 0
        end,
        getEntry = function(i)
            return M._entries[i]
        end,
        isSelectable = function(_, entry)
            return entry and entry.kind ~= "header"
        end,
        rowInset = ROW_INSET,
        rowHeight = ROW_H,
        getRowHeight = function(i)
            local entry = M._entries[i]
            if entry and entry.kind == "header" then return HEADER_H end
            return ROW_H
        end,
        numVisibleRows = 16,
        onSelect = function(_, entry)
            M:OnRowActivate(entry)
        end,
        createRow = function(content)
            local row = CreateFrame("Button", nil, content, "BackdropTemplate")
            row:SetHeight(ROW_H)
            row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetScript("OnClick", function(myself, button)
                if button == "RightButton" then
                    M:OnRowRightClick(myself._entry)
                end
            end)
            row:SetScript("OnEnter", function(myself)
                if myself._entry and myself._entry.kind ~= "header" then
                    ApplyRowChrome(myself, myself._rowIndex, myself._entry, myself._selected, true)
                end
            end)
            row:SetScript("OnLeave", function(myself)
                ApplyRowChrome(myself, myself._rowIndex, myself._entry, myself._selected, false)
            end)

            local function ActivateRow(button)
                local entry = row._entry
                if not entry or entry.kind == "header" then return end
                if button == "RightButton" then
                    M:OnRowRightClick(entry)
                else
                    M:OnRowActivate(entry)
                end
            end

            local function MakeIcon(size)
                local icon = OneWoW_GUI:CreateSkinnedIcon(row, {
                    size = size,
                    preset = "clean",
                    showCount = true,
                    onClick = function(_, button)
                        ActivateRow(button)
                    end,
                    onEnter = OnDataIconEnter,
                    onLeave = GameTooltip_Hide,
                })
                icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                return icon
            end

            local product = OneWoW_GUI:CreateSkinnedIcon(row, {
                size = ICON_SIZE,
                preset = "clean",
                onClick = function(_, button)
                    ActivateRow(button)
                end,
                onEnter = OnDataIconEnter,
                onLeave = GameTooltip_Hide,
            })
            product:SetPoint("LEFT", row, "LEFT", 4, 0)
            product:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.product = product

            local nameText = OneWoW_GUI:CreateFS(row, 12)
            nameText:SetPoint("LEFT", product, "RIGHT", 6, 8)
            nameText:SetPoint("RIGHT", row, "RIGHT", -COL_ORDER_RIGHT, 8)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText

            local unlearnedText = OneWoW_GUI:CreateFS(row, 10)
            unlearnedText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -1)
            unlearnedText:SetPoint("RIGHT", nameText, "RIGHT")
            unlearnedText:SetJustifyH("LEFT")
            row.unlearnedText = unlearnedText

            local timeText = OneWoW_GUI:CreateFS(row, 11)
            PlaceColLabel(timeText, row, COL_TIME_RIGHT, TIME_W, "RIGHT")
            timeText:SetMaxLines(1)
            timeText:SetWordWrap(false)
            row.timeText = timeText

            local function FillIconLane(count, size, rightInset, width)
                local lane = CreateFrame("Frame", nil, row)
                PlaceIconLane(lane, row, rightInset, width, size)
                lane:SetClipsChildren(true)
                local icons = {}
                for i = 1, count do
                    local icon = MakeIcon(size)
                    if i == 1 then
                        icon:SetPoint("LEFT", lane, "LEFT", 0, 0)
                    else
                        icon:SetPoint("LEFT", icons[i - 1], "RIGHT", MAT_GAP, 0)
                    end
                    icons[i] = icon
                end
                return icons
            end

            row.rewards = FillIconLane(MAX_REWARDS, REWARD_SIZE, COL_REWARD_RIGHT, REWARD_W)
            row.customerMats = FillIconLane(MAX_CUST, MAT_SIZE, COL_CUST_RIGHT, CUST_W)

            local cartLane = CreateFrame("Frame", nil, row)
            PlaceIconLane(cartLane, row, COL_CART_RIGHT, CART_W, 20)

            local addBtn = OneWoW_GUI:CreateIconButton(row, {
                atlas = "Perks-ShoppingCart",
                size = 20,
                onClick = function(btn, button)
                    M:OnAddButtonClick(btn, button)
                end,
            })
            addBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            addBtn:SetPoint("CENTER", cartLane, "CENTER")
            addBtn:SetScript("OnEnter", function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                local active = M:GetActiveShoppingListName()
                if not M:HasShoppingList() then
                    GameTooltip:SetText(L["CRAFTORDERS_NO_SHOPPING"])
                elseif active then
                    GameTooltip:SetText(L["CRAFTORDERS_ADD_ACTIVE"]:format(active))
                    GameTooltip:AddLine(L["CRAFTORDERS_ADD_MENU_HINT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                else
                    GameTooltip:SetText(L["CRAFTORDERS_MAKE_LIST"])
                end
                GameTooltip:Show()
            end)
            addBtn:SetScript("OnLeave", GameTooltip_Hide)
            row.addBtn = addBtn

            row.youMats = FillIconLane(MAX_YOU, MAT_SIZE, COL_YOU_RIGHT, YOU_W)

            return row
        end,
        bindRow = function(row, index, entry, state)
            row._entry = entry
            row._rowIndex = index
            row._selected = state and state.selected
            if not entry then
                return
            end
            ApplyRowChrome(row, index, entry, row._selected, false)
            if entry.kind == "header" then
                BindHeader(row, entry)
            else
                BindRow(row, entry)
            end
        end,
    })
    overlay.virt = virt
    M._overlay = overlay
    M._virt = virt
    virt.listScroll:HookScript("OnVerticalScroll", function()
        local page = GetOrdersPage()
        if page then
            page:RequestMoreOrders()
        end
    end)
    return overlay
end

function M:OnAddButtonClick(btn, button)
    if not M:HasShoppingList() then return end
    local entry = btn._entry
    if not entry or not entry.missingReagents then return end
    if button == "RightButton" then
        M:ShowAddMenu(btn, entry)
        return
    end
    M:AddReagentsToActive(entry.missingReagents)
end

function M:OnRowActivate(entry)
    if not entry or entry.kind == "header" then return end
    local page = GetOrdersPage()
    if not page then return end
    if entry.kind == "bucket" then
        page:SelectRecipeFromBucket(entry.raw)
    else
        page:ViewOrder(entry.raw)
    end
end

function M:OnRowRightClick(entry)
    if not entry or entry.kind == "header" then return end
    local page = GetOrdersPage()
    if not page then return end
    MenuUtil.CreateContextMenu(M._overlay, function(_, rootDescription)
        local recipeID = entry.spellID
        if recipeID then
            local currentlyFavorite = C_TradeSkillUI.IsRecipeFavorite(recipeID)
            local text = currentlyFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE
            rootDescription:CreateButton(text, function()
                C_TradeSkillUI.SetRecipeFavorite(recipeID, not currentlyFavorite)
            end)
        end
        if entry.kind == "order" and entry.orderType == Enum.CraftingOrderType.Personal then
            local professionInfo = page.professionInfo
            rootDescription:CreateButton(PROFESSIONS_DECLINE_ORDER, function()
                C_CraftingOrders.RejectOrder(entry.orderID, "", professionInfo.profession)
            end)
        end
    end)
end

function M:UpdateStatusHeader()
    local overlay = M._overlay
    if not overlay then return end
    local page = GetOrdersPage()
    local text = ""
    if page and page.orderType == Enum.CraftingOrderType.Npc then
        local profession = page.professionInfo and page.professionInfo.profession
        text = M:FormatWeeklyHeader(profession) or ""
    elseif page and page.orderType == Enum.CraftingOrderType.Public then
        local profession = page.professionInfo and page.professionInfo.profession
        if profession then
            local info = C_CraftingOrders.GetOrderClaimInfo(profession)
            text = PROFESSIONS_CRAFTING_ORDERS_REMAINING_ORDERS:format(info.claimsRemaining)
        end
    end
    overlay.statusText:SetText(text)
end

function M:PullCurrentOrders()
    local page = GetOrdersPage()
    if not page then return end
    -- Patron / Guild / Personal are always a flat list. Leftover public
    -- buckets from the previous tab must not be treated as the current browse.
    if page.orderType ~= Enum.CraftingOrderType.Public then
        M._rawOrders = C_CraftingOrders.GetCrafterOrders()
        M._browseIsBucket = false
        return
    end
    local last = page.lastRequest
    if last and last.selectedSkillLineAbility then
        M._rawOrders = C_CraftingOrders.GetCrafterOrders()
        M._browseIsBucket = false
        return
    end
    local buckets = C_CraftingOrders.GetCrafterBuckets()
    if buckets and #buckets > 0 then
        M._rawOrders = buckets
        M._browseIsBucket = true
        return
    end
    M._rawOrders = C_CraftingOrders.GetCrafterOrders()
    M._browseIsBucket = false
end

function M:EnsureModeButton()
    if M._modeBtn then
        M:UpdateModeButton()
        return M._modeBtn
    end
    local browse = GetBrowseFrame()
    if not browse or not browse.PersonalOrdersButton then return nil end
    local btn = OneWoW_GUI:CreateFitTextButton(browse, {
        text = L["CRAFTORDERS_USE_WOWUI"],
        height = 22,
        minWidth = 48,
        paddingX = 16,
    })
    btn:SetPoint("LEFT", browse.PersonalOrdersButton, "RIGHT", 8, 0)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(browse.PersonalOrdersButton:GetFrameLevel() + 2)
    btn:SetScript("OnClick", function()
        local useBlizzard = ns.ModuleRegistry:GetToggleValue("craftingorders", "useBlizzardList")
        ns.ModuleRegistry:SetToggleValue("craftingorders", "useBlizzardList", not useBlizzard)
    end)
    btn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["CRAFTORDERS_TOGGLE_WOWUI"])
        GameTooltip:AddLine(L["CRAFTORDERS_TOGGLE_WOWUI_DESC"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    M._modeBtn = btn

    local settingsBtn = OneWoW_GUI:CreateIconButton(browse, {
        iconTexture = OneWoW_GUI.Constants.MEDIA_BASE .. "icon-gears.png",
        size = 22,
        tooltipTitle = L["OPEN_SETTINGS"],
        onClick = function()
            ns.UI.SelectFeature("craftingorders")
        end,
    })
    settingsBtn:SetPoint("LEFT", btn, "RIGHT", SPACING.SM, 0)
    settingsBtn:SetFrameStrata("HIGH")
    settingsBtn:SetFrameLevel(browse.PersonalOrdersButton:GetFrameLevel() + 2)
    M._settingsBtn = settingsBtn

    OneWoW_GUI:RegisterFontRoot(btn, function()
        M:UpdateModeButton()
    end)
    M:UpdateModeButton()
    return btn
end

function M:UpdateModeButton()
    local btn = M._modeBtn
    if not btn then return end
    if not ModuleOn() then
        btn:Hide()
        if M._settingsBtn then
            M._settingsBtn:Hide()
        end
        return
    end
    btn:Show()
    M._settingsBtn:Show()
    if M:WantsOverlay() then
        btn:SetFitText(L["CRAFTORDERS_USE_WOWUI"])
    else
        btn:SetFitText(L["CRAFTORDERS_USE_ONEUI"])
    end
end

function M:RefreshOverlay()
    if not ModuleOn() then return end
    M:EnsureModeButton()
    if not M:WantsOverlay() then
        if M._overlay then
            M._overlay:Hide()
        end
        ShowBlizzardOrderList()
        return
    end
    local overlay = M:EnsureOverlay()
    if not overlay then return end
    local browse = GetBrowseFrame()
    if not browse or not browse:IsShown() then
        overlay:Hide()
        return
    end

    overlay:Show()
    HideBlizzardOrderList()
    ApplyOverlayTheme(overlay)
    M:UpdateStatusHeader()

    if not M._holdPull then
        M:PullCurrentOrders()
    end

    local page = GetOrdersPage()
    local orderType = page and page.orderType
    local entries, readyN, missingN = M:BuildOverlayEntries(M._rawOrders, M._browseIsBucket, orderType)
    M._entries = entries
    overlay.virt.Refresh()

    if M._loading and #entries == 0 then
        overlay.emptyText:SetText(L["CRAFTORDERS_LOADING"])
        overlay.emptyText:Show()
    elseif #entries == 0 then
        if orderType == Enum.CraftingOrderType.Public then
            overlay.emptyText:SetText(CRAFTER_CRAFTING_ORDERS_BROWSE_FAVORITES_TIP)
        else
            overlay.emptyText:SetText(PROFESSIONS_CUSTOMER_NO_ORDERS)
        end
        overlay.emptyText:Show()
    else
        overlay.emptyText:Hide()
    end
    return readyN, missingN
end

function M:ShowOverlay()
    if not ModuleOn() then return end
    M:EnsureModeButton()
    if not M:WantsOverlay() then
        M:HideOverlay()
        return
    end
    local overlay = M:EnsureOverlay()
    if not overlay then return end
    overlay:Show()
    HideBlizzardOrderList()
    M:RefreshOverlay()
end

function M:HideOverlay()
    if M._overlay then
        M._overlay:Hide()
    end
    ShowBlizzardOrderList()
    M:UpdateModeButton()
end

function M:OnOrdersShown(page, orders)
    if not ModuleOn() then return end
    M._ordersPage = page
    M._loading = false
    if orders then
        M._rawOrders = orders
        local first = orders[1]
        M._browseIsBucket = first ~= nil and first.numAvailable ~= nil and first.orderID == nil
        if page.orderType ~= Enum.CraftingOrderType.Public then
            M._browseIsBucket = false
        end
    else
        M:PullCurrentOrders()
    end
    M._holdPull = true
    M:RefreshOverlay()
    M._holdPull = false
end

function M:OnOrderTypeChanged(page)
    if not ModuleOn() then return end
    M._ordersPage = page
    M._rawOrders = nil
    M._browseIsBucket = false
    -- Tab click still has the previous search in C_CraftingOrders until the
    -- new request returns. Do not pull that leftover list onto this tab.
    M._holdPull = true
    M._loading = false
    M:RefreshOverlay()
end

function M:OnOrdersRequestSent(page, request)
    if not ModuleOn() then return end
    M._ordersPage = page
    if request and request.offset and request.offset > 0 then
        return
    end
    M._holdPull = true
    M._loading = true
    M:RefreshOverlay()
end

function M:ApplyOverlayTheme()
    if M._overlay then
        ApplyOverlayTheme(M._overlay)
        M:RefreshOverlay()
    end
end

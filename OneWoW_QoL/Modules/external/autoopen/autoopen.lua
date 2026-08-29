local _, ns = ...

local AutoOpenModule, L = ns.ModuleRegistry:Current()
if not AutoOpenModule then return end

local Restriction = OneWoW.Restriction
local OneWoW_GUI = OneWoW_GUI
local PE = OneWoW.PredicateEngine
local Inventory = OneWoW.Inventory

local AO = AutoOpenModule
local OWNER = "QoL_autoopen"

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

-- #openable reads the bag tooltip; hasLoot/isLocked alone cannot detect lockpicking-locked lockboxes.
local OPEN_PREDICATE_EXPR = "#hasloot&!#locked& #openable"
local openPredicate = PE:Compile(OPEN_PREDICATE_EXPR)

-- Bag updates while mail/bank/merchant/tradeskill are open are suppressed; those
-- UIs do not themselves dirty bags on close, so schedule one catch-up scan.
local RESCAN_AFTER_SUPPRESS = 0.25

local function ScheduleRescanAfterSuppress()
    C_Timer.After(RESCAN_AFTER_SUPPRESS, function()
        if not ns.ModuleRegistry:IsEnabled("autoopen") then return end
        AO:ScanAndOpen()
    end)
end

local function GetBlacklist()
    local bucket = ns.ModuleRegistry:GetModuleBucket("autoopen")
    if not bucket.blacklist then bucket.blacklist = {} end
    return bucket.blacklist
end

function AutoOpenModule:IsBlacklisted(itemID)
    if self._tempBlacklist[itemID] then return true end
    local bl = GetBlacklist()
    return bl[itemID] == true
end

function AutoOpenModule:AddToBlacklist(itemID, permanent)
    if permanent then
        GetBlacklist()[itemID] = true
    else
        self._tempBlacklist[itemID] = true
    end
end

function AutoOpenModule:RemoveFromBlacklist(itemID)
    self._tempBlacklist[itemID] = nil
    GetBlacklist()[itemID] = nil
end

function AutoOpenModule:ScanAndOpen()
    -- Merchant and trade-skill state are read live from the core funnels
    -- (OneWoW.Merchant / OneWoW.ProfessionRecipe). Character + guild bank open
    -- state come from OneWoW.Inventory; mail suppress stays local.
    if Inventory.IsBankOpen() or Inventory.IsGuildBankOpen() or self._atMail
        or OneWoW.Merchant.IsMerchantOpen()
        or OneWoW.ProfessionRecipe.IsTradeskillOpen() then
        return
    end
    if Restriction.IsProtectedActionBlocked() then return end

    local items = ns.AutoOpenItems
    if not items then return end

    Inventory.ForEachSlot("player", function(bag, slot, info)
        local itemID = info and info.itemID
        if not itemID or not items[itemID] or AO:IsBlacklisted(itemID) then
            return
        end
        if not openPredicate then return end
        local props = PE:BuildProps(itemID, bag, slot, info)
        if not PE:SafeEvaluate(openPredicate, props) then return end
        local itemLink = props.hyperlink or C_Container.GetContainerItemLink(bag, slot)
        if itemLink then
            print(string.format(L["AUTOOPEN_OPENING"], itemLink))
        end
        C_Container.UseContainerItem(bag, slot)
        return true
    end)
end

function AutoOpenModule:OnEnable()
    Inventory.RegisterDelayedCallback(OWNER, function()
        AO:ScanAndOpen()
    end)
    Inventory.RegisterBankClosedCallback(OWNER, ScheduleRescanAfterSuppress)
    Inventory.RegisterGuildClosedCallback(OWNER, ScheduleRescanAfterSuppress)
    OneWoW.Merchant.RegisterClosedCallback(OWNER, ScheduleRescanAfterSuppress)
    OneWoW.ProfessionRecipe.RegisterClosedCallback(OWNER, ScheduleRescanAfterSuppress)

    -- Mail is not Inventory-owned yet; keep a thin local frame.
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoOpen")
        self._frame:SetScript("OnEvent", function(_, event)
            if event == "MAIL_SHOW" then
                AO._atMail = true
            elseif event == "MAIL_CLOSED" then
                AO._atMail = false
                ScheduleRescanAfterSuppress()
            end
        end)
    end
    OneWoW_QoL:RegisterEnteringWorldHandler("autoopen", function()
        C_Timer.After(2.5, function() AO:ScanAndOpen() end)
    end)
    self._frame:RegisterEvent("MAIL_SHOW")
    self._frame:RegisterEvent("MAIL_CLOSED")
end

function AutoOpenModule:OnDisable()
    Inventory.UnregisterCallback(OWNER)
    OneWoW.Merchant.UnregisterCallback(OWNER)
    OneWoW.ProfessionRecipe.UnregisterCallback(OWNER)
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
    OneWoW_QoL:UnregisterEnteringWorldHandler("autoopen")
    self._atMail = false
end

function AutoOpenModule:OnToggle()
end

function AutoOpenModule:CreateCustomDetail(detailScrollChild, yOffset, _, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, detailScrollChild)
    cardsHost:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if detailScrollChild.UpdateDetailHeight then
            detailScrollChild:SetHeight(h)
            detailScrollChild.UpdateDetailHeight()
        else
            detailScrollChild:SetHeight(math.abs(yOffset) + h + 20)
            if detailScrollChild.updateThumb then
                detailScrollChild.updateThumb()
            end
        end
    end
    stack.OnRelayout = applyHostHeight

    local blacklistRefresh

    stack:AddCard("autoopen:blacklist", L["BLACKLIST"], function(content, contentWidth)
        local gap = 8
        local blDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        blDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        blDesc:SetJustifyH("LEFT")
        blDesc:SetWordWrap(true)
        blDesc:SetSpacing(2)
        local w = tonumber(contentWidth) or 0
        if w < 1 then
            w = content:GetWidth() or 0
        end
        if w >= 1 then
            blDesc:SetWidth(w)
        else
            blDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        blDesc:SetText(L["AUTOOPEN_BLACKLIST_DESC"])

        local function BuildBlacklistEntries()
            local entries = {}
            for itemID in pairs(GetBlacklist()) do
                C_Item.RequestLoadItemDataByID(itemID)
                local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
                local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
                tinsert(entries, { id = itemID, label = itemName, icon = icon })
            end
            return entries
        end

        local introH = blDesc:GetStringHeight() or 14
        local editor
        local listY
        listY, editor = OneWoW_GUI:CreateItemListEditor(content, {
            yOffset = -(introH + gap),
            x = 0,
            rightInset = 0,
            label = L["ITEM_ID"],
            addText = ADD,
            emptyText = L["NO_ITEMS"],
            drop = { text = L["DRAG_ITEM_HERE"] },
            height = 120,
            sortKey = "autoopen:blacklist",
            getEntries = BuildBlacklistEntries,
            onAdd = function(itemID)
                AO:AddToBlacklist(itemID, true)
                local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
                print(string.format("|cFFFFD700OneWoW QoL:|r " .. (L["AUTOOPEN_BLACKLIST_ADDED"]), itemName))
                C_Item.RequestLoadItemDataByID(itemID)
                C_Timer.After(0.3, function()
                    if editor then editor:Refresh() end
                end)
            end,
            onRemove = function(itemID)
                AO:RemoveFromBlacklist(itemID)
                local rName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
                print(string.format("|cFFFFD700OneWoW QoL:|r " .. (L["AUTOOPEN_BLACKLIST_REMOVED"]), rName))
            end,
        })

        blacklistRefresh = function()
            local isEnabledNow = ns.ModuleRegistry:IsEnabled("autoopen")
            blDesc:SetTextColor(OneWoW_GUI:GetThemeColor(isEnabledNow and "TEXT_SECONDARY" or "TEXT_MUTED"))
            editor:SetEnabled(isEnabledNow)
        end
        blacklistRefresh()

        return math.max(1, math.abs(listY))
    end)

    stack:Finish()
    applyHostHeight()

    if registerRefresh then
        registerRefresh(function()
            if blacklistRefresh then
                blacklistRefresh()
            end
        end)
    end

    return yOffset - cardsHost:GetHeight()
end

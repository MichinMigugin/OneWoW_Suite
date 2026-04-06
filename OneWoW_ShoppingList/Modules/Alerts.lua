local ADDON_NAME, ns = ...
local L = ns.L

ns.Alerts = {}
local Alerts = ns.Alerts

local function ShowAlert(itemID, itemName, alertType)
    if not ns.ShoppingList then return end
    if not ns.ShoppingList:CanShowAlert(itemID, alertType) then return end

    local isOnList, lists = ns.ShoppingList:IsOnAnyList(itemID)
    if not isOnList then return end

    local listName = lists[1]
    local status   = ns.ShoppingList:GetItemStatus(itemID, listName)
    if not status then return end

    if status.totalOwned >= status.needed then
        if alertType == "loot" then
            ns.ShoppingList:CanShowAlert(itemID, alertType)
        end
    end

    print(string.format("%s %s: |cFFFFFFFF%s|r (%d/%d)", L["ADDON_CHAT_PREFIX"], L["OWSL_ALERT_TITLE"], itemName or tostring(itemID), status.totalOwned, status.needed))
end

local function HandleBagUpdate()
    if not ns.ShoppingList then return end
    local isOnList
    for listName, list in pairs(ns.ShoppingList:GetAllLists()) do
        for itemID in pairs(list.items or {}) do
            isOnList = true
            break
        end
        if isOnList then break end
    end

    if not isOnList then return end

    if ns.BagOverlays and ns.BagOverlays.RefreshAll then
        ns.BagOverlays:RefreshAll()
    end
end

local function HandleLoot(_, message)
    if not ns.ShoppingList then return end
    if issecretvalue and issecretvalue(message) then return end
    local link = string.match(message, "|H(item:[^|]+)|h")
    if not link then return end

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    local isOnList = ns.ShoppingList:IsOnAnyList(itemID)
    if not isOnList then return end

    local itemName = C_Item.GetItemNameByID(itemID) or tostring(itemID)
    ShowAlert(itemID, itemName, "loot")
end

local function HandleAHShow()
    if not ns.ShoppingList then return end
    local db = GetDB()
    if not db then return end

    local lists = ns.ShoppingList:GetAllLists()
    for _, list in pairs(lists) do
        for itemID in pairs(list.items or {}) do
            C_AuctionHouse.GetReplicateItemInfo(itemID)
        end
    end
end

local function GetDB()
    return OneWoW_ShoppingList_DB
end

function Alerts:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:RegisterEvent("AUCTION_HOUSE_SHOW")

    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "BAG_UPDATE_DELAYED" then
            C_Timer.After(0.3, HandleBagUpdate)
        elseif event == "CHAT_MSG_LOOT" then
            HandleLoot(event, ...)
        elseif event == "AUCTION_HOUSE_SHOW" then
            HandleAHShow()
        end
    end)
end

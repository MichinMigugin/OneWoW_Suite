local addonName, ns = ...

ns.DataManager = {}
local DataManager = ns.DataManager

local eventFrame = nil
local initialized = false
local auctionHouseOpen = false
local ignoreUpdateEvent = false
local scanPending = false
local scanFrame = nil

function DataManager:Initialize()
    if initialized then return end
    initialized = true

    if not scanFrame then
        scanFrame = CreateFrame("Frame")
        scanFrame.ticksRemaining = 0
        scanFrame:SetScript("OnUpdate", function(self, elapsed)
            if self.ticksRemaining > 0 then
                self.ticksRemaining = self.ticksRemaining - 1
                if self.ticksRemaining == 0 then
                    DataManager:ExecuteScan()
                end
            end
        end)
    end
end

function DataManager:RegisterEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    local events = {
        "AUCTION_HOUSE_SHOW",
        "AUCTION_HOUSE_CLOSED",
        "OWNED_AUCTIONS_UPDATED",
        "AUCTION_CANCELED",
        "AUCTION_HOUSE_AUCTIONS_EXPIRED",
        "AUCTION_HOUSE_AUCTION_CREATED",
        "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
        "AUCTION_HOUSE_SHOW_NOTIFICATION",
        "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION",
    }

    for _, event in ipairs(events) do
        eventFrame:RegisterEvent(event)
    end

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        DataManager:HandleEvent(event, ...)
    end)
end

function DataManager:HandleEvent(event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        auctionHouseOpen = true
        self:ScheduleScan(60)

    elseif event == "AUCTION_HOUSE_CLOSED" then
        auctionHouseOpen = false
        scanPending = false

    elseif event == "OWNED_AUCTIONS_UPDATED" then
        if ignoreUpdateEvent then
            return
        end
        if auctionHouseOpen then
            self:ScheduleScan(2)
        end

    elseif event == "AUCTION_CANCELED" then
        local auctionID = ...
        if auctionID and auctionID ~= 0 then
            self:ScheduleScan(2)
        else
            self:ScheduleScan(2)
        end

    elseif event == "AUCTION_HOUSE_AUCTIONS_EXPIRED" or event == "AUCTION_HOUSE_AUCTION_CREATED" then
        if auctionHouseOpen then
            self:ScheduleScan(2)
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if interactionType == Enum.PlayerInteractionType.Auctioneer then
            auctionHouseOpen = true
            if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
                C_AuctionHouse.QueryOwnedAuctions({})
            end
            self:ScheduleScan(60)
        end

    elseif event == "AUCTION_HOUSE_SHOW_NOTIFICATION" then
        local notificationType, itemName = ...
        self:HandleNotification(notificationType, itemName)

    elseif event == "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION" then
        local notificationType, text, itemLink = ...
        local itemName = nil
        if itemLink and type(itemLink) == "string" then
            itemName = itemLink:match("%[(.+)%]")
        end
        if itemName then
            self:HandleNotification(notificationType, itemName)
        end
    end
end

function DataManager:HandleNotification(notificationType, itemName)
    if not notificationType then return end

    local charKey = ns:GetCharacterKey()
    if not charKey then return end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return end

    local serverTime = GetServerTime()

    if notificationType == Enum.AuctionHouseNotification.AuctionSold then
        self:RecordNotificationSale(charData, itemName, serverTime)

    elseif notificationType == Enum.AuctionHouseNotification.AuctionExpired then
        self:RecordNotificationExpired(charData, itemName, serverTime)

    elseif notificationType == Enum.AuctionHouseNotification.AuctionRemoved then
        self:RecordNotificationCanceled(charData, itemName, serverTime)
    end
end

function DataManager:RecordNotificationSale(charData, itemName, serverTime)
    local found = false

    if charData.activeAuctions then
        for _, auction in ipairs(charData.activeAuctions) do
            if auction.itemName == itemName or (itemName and auction.itemName and auction.itemName:find(itemName, 1, true)) then
                if ns.ActiveAuctions and ns.ActiveAuctions.RecordHistoryEvent then
                    local salePrice = auction.bidAmount > 0 and auction.bidAmount or auction.buyoutAmount
                    ns.ActiveAuctions:RecordHistoryEvent(charData, auction, "sold", salePrice, serverTime, "notification")
                    --print("|cFF00FF00SUCCESS:|r Recorded sale for " .. auction.itemName)
                end
                found = true
                break
            end
        end
    end

    if not found and charData.auctionHistory then
        for _, event in ipairs(charData.auctionHistory) do
            if event.itemName == itemName and event.outcome ~= "sold" then
                event.outcome = "sold"
                event.detectionMethod = "notification"
                event.timestamp = serverTime
                --print("|cFF00FF00SUCCESS:|r Updated history event to sold for " .. itemName)
                found = true
                break
            end
        end
    end

    if not found then
        --print("|cFFFF0000ERROR:|r Could not find auction for " .. tostring(itemName))
    end
end

function DataManager:RecordNotificationExpired(charData, itemName, serverTime)
    if not charData.activeAuctions then return end

    for _, auction in ipairs(charData.activeAuctions) do
        if auction.itemName == itemName then
            if ns.ActiveAuctions and ns.ActiveAuctions.RecordHistoryEvent then
                ns.ActiveAuctions:RecordHistoryEvent(charData, auction, "expired", 0, serverTime, "notification")
            end
            return
        end
    end
end

function DataManager:RecordNotificationCanceled(charData, itemName, serverTime)
    if not charData.activeAuctions then return end

    for _, auction in ipairs(charData.activeAuctions) do
        if auction.itemName == itemName then
            if ns.ActiveAuctions and ns.ActiveAuctions.RecordHistoryEvent then
                ns.ActiveAuctions:RecordHistoryEvent(charData, auction, "canceled", 0, serverTime, "notification")
            end
            return
        end
    end
end

function DataManager:ScheduleScan(numFrames)
    if not scanFrame then return end
    if scanFrame.ticksRemaining > 0 then return end
    scanFrame.ticksRemaining = numFrames or 2
    scanPending = true
end

function DataManager:ExecuteScan()
    if not auctionHouseOpen then return false end
    if not C_AuctionHouse then return false end

    scanPending = false

    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ignoreUpdateEvent = true

    local success = ns.ActiveAuctions:CollectData(charKey, charData)
    if success then
        ns.ActiveBids:CollectData(charKey, charData)
        charData.lastUpdate = GetServerTime()
    end

    ignoreUpdateEvent = false

    return true
end


function DataManager:GetCharacterData(charKey)
    return ns:GetCharacterData(charKey)
end

function DataManager:GetAllCharacters()
    return ns:GetAllCharacters()
end

function DataManager:DeleteCharacter(charKey)
    return ns:DeleteCharacter(charKey)
end

function DataManager:IsAuctionHouseOpen()
    return auctionHouseOpen
end

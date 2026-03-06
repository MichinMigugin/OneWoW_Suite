local AddonName, Addon = ...

local function T(key)
    if Addon.Constants and Addon.Constants.THEME and Addon.Constants.THEME[key] then
        return unpack(Addon.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local EventMonitor = {}
Addon.EventMonitor = EventMonitor

EventMonitor.events = {}
EventMonitor.monitoring = false
EventMonitor.firehose = false
EventMonitor.maxEvents = 500
EventMonitor.selectedEvents = {}
EventMonitor.selectedRegistryEvents = {}
EventMonitor.registryCallbackRegistered = {}
EventMonitor.allEventsRegistered = false

function EventMonitor:Initialize()
    if self.frame then return end

    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        EventMonitor:OnEvent(event, ...)
    end)

    self:RegisterAllPossibleEvents()
end

function EventMonitor:RegisterAllPossibleEvents()
    if self.allEventsRegistered then return end

    local eventsToRegister = {
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGIN", "PLAYER_LOGOUT",
        "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_AURA",
        "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_LOCKED", "ITEM_UNLOCKED",
        "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY",
        "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_RAID", "CHAT_MSG_SYSTEM",
        "ADDON_LOADED", "VARIABLES_LOADED",
        "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE", "QUEST_REMOVED",
        "MERCHANT_SHOW", "MERCHANT_CLOSED",
        "MAIL_INBOX_UPDATE", "MAIL_SHOW", "MAIL_CLOSED",
        "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
        "LOOT_OPENED", "LOOT_CLOSED", "LOOT_READY",
        "TRADE_SHOW", "TRADE_CLOSED",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
        "TAXIMAP_OPENED", "TAXIMAP_CLOSED",
        "GOSSIP_SHOW", "GOSSIP_CLOSED",
        "TRANSMOGRIFY_OPEN", "TRANSMOGRIFY_CLOSE", "TRANSMOGRIFY_SUCCESS", "TRANSMOGRIFY_UPDATE",
        "VIEWED_TRANSMOG_OUTFIT_CHANGED", "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED",
        "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH", "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS",
        "TRANSMOG_SEARCH_UPDATED",
        "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED",
        "AUCTION_HOUSE_AUCTION_CREATED", "BLACK_MARKET_OPEN", "BLACK_MARKET_BID_RESULT",
        "CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG",
        "PLAYER_MONEY", "PLAYER_DEAD", "PLAYER_UNGHOST",
        "UPDATE_INVENTORY_DURABILITY",
        "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANK_UPDATE_MONEY",
        "TRADE_SHOW", "TRADE_ACCEPT_UPDATE", "TRADE_MONEY_CHANGED",
        "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED",
        "UI_INFO_MESSAGE",
        "TRAIT_CONFIG_COMMIT_FAILED", "TRAIT_COND_INFO_CHANGED", "TRAIT_CONFIG_CREATED",
        "TRAIT_CONFIG_DELETED", "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_CONFIG_UPDATED",
        "TRAIT_NODE_CHANGED", "TRAIT_NODE_CHANGED_PARTIAL", "TRAIT_NODE_ENTRY_UPDATED",
        "TRAIT_SUB_TREE_CHANGED", "TRAIT_SYSTEM_INTERACTION_STARTED", "TRAIT_SYSTEM_NPC_CLOSED",
        "TRAIT_TREE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRY_PURCHASE_TO_NODE_PARTIAL_SUCCESS",
        "ACTIVE_COMBAT_CONFIG_CHANGED", "SELECTED_LOADOUT_CHANGED", "SPECIALIZATION_CHANGE_CAST_FAILED",
        "STARTER_BUILD_ACTIVATION_FAILED", "TALENTS_INVOLUNTARILY_RESET",
        "PORTRAITS_UPDATED", "PLAYER_LEVEL_UP",
    }

    for _, event in ipairs(eventsToRegister) do
        pcall(function() self.frame:RegisterEvent(event) end)
    end

    self.allEventsRegistered = true
end

function EventMonitor:Start()
    if self.monitoring then
        Addon:Print("Event monitor already running")
        return
    end

    if self:GetEventCount() == 0 then
        self:RegisterCommonEvents()
        Addon:Print("Auto-selected common events (first time)")
    end

    self:Initialize()
    self.monitoring = true

    local count = self:GetEventCount()
    Addon:Print("Event monitoring started (" .. count .. " events selected)")
    self:UpdateUI()
end

function EventMonitor:Stop()
    if not self.monitoring then
        Addon:Print("Event monitor not running")
        return
    end

    if self.firehose then
        self:FirehoseStop()
    end

    self.monitoring = false
    Addon:Print("Event monitoring stopped")
    self:UpdateUI()
end

function EventMonitor:Clear()
    self.events = {}
    self:UpdateUI()
    Addon:Print("Event log cleared")
end

function EventMonitor:OnEvent(event, ...)
    if not self.monitoring then return end

    if not self.firehose and not self.selectedEvents[event] and not self.selectedRegistryEvents[event] then return end

    local args = {...}
    local timestamp = date("%H:%M:%S")

    local eventData = {
        event = event,
        args = args,
        timestamp = timestamp,
        time = GetTime(),
    }

    table.insert(self.events, 1, eventData)

    if #self.events > self.maxEvents then
        table.remove(self.events, self.maxEvents + 1)
    end

    self:UpdateUI()
end

function EventMonitor:UpdateUI()
    if not Addon.EventMonitorTab then return end

    local tab = Addon.EventMonitorTab

    if tab.startBtn then
        if self.monitoring then
            tab.startBtn:Disable()
            tab.stopBtn:Enable()
        else
            tab.startBtn:Enable()
            tab.stopBtn:Disable()
        end
    end

    if tab.firehoseBtn then
        if self.firehose then
            tab.firehoseBtn:SetBackdropColor(T("BG_ACTIVE"))
            tab.firehoseBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            tab.firehoseBtn.text:SetTextColor(T("TEXT_ACCENT"))
        else
            tab.firehoseBtn:SetBackdropColor(T("BTN_NORMAL"))
            tab.firehoseBtn:SetBackdropBorderColor(T("BTN_BORDER"))
            tab.firehoseBtn.text:SetTextColor(T("TEXT_PRIMARY"))
        end
    end

    local lines = {}

    if #self.events == 0 then
        if self.monitoring then
            table.insert(lines, "Monitoring events... (0 captured)")
        else
            table.insert(lines, "Click Start to monitor events")
        end
    else
        local filterText = tab.filterBox and tab.filterBox:GetText() or ""
        local filter = filterText ~= "" and filterText:upper() or nil

        local displayCount = 0
        for _, data in ipairs(self.events) do
            if not filter or string.find(data.event:upper(), filter, 1, true) then
                local argsText = ""
                if #data.args > 0 then
                    local argStrings = {}
                    for i, arg in ipairs(data.args) do
                        if i > 5 then
                            table.insert(argStrings, "...")
                            break
                        end
                        local argStr = tostring(arg)
                        if #argStr > 30 then
                            argStr = argStr:sub(1, 27) .. "..."
                        end
                        table.insert(argStrings, argStr)
                    end
                    argsText = " | " .. table.concat(argStrings, ", ")
                end

                table.insert(lines, string.format("[%s] %s%s", data.timestamp, data.event, argsText))
                displayCount = displayCount + 1

                if displayCount >= 200 then
                    table.insert(lines, "... (showing first 200 events)")
                    break
                end
            end
        end

        if filter and displayCount == 0 then
            table.insert(lines, string.format("No events matching '%s' (total: %d)", filterText, #self.events))
        end
    end

    tab.logText:SetText(table.concat(lines, "\n"))

    local height = tab.logText:GetStringHeight()
    tab.scroll:GetScrollChild():SetHeight(math.max(height + 10, tab.scroll:GetHeight()))
end

function EventMonitor:ToggleEvent(event)
    if self.selectedEvents[event] then
        self.selectedEvents[event] = nil
        return false
    else
        self.selectedEvents[event] = true
        return true
    end
end

function EventMonitor:IsEventRegistered(event)
    return self.selectedEvents[event] == true
end

function EventMonitor:GetEventCount()
    local count = 0
    for _ in pairs(self.selectedEvents) do
        count = count + 1
    end
    return count
end

function EventMonitor:RegisterRegistryEvent(eventId)
    if self.registryCallbackRegistered[eventId] then return end

    pcall(function()
        EventRegistry:RegisterCallback(eventId, function(owner, ...)
            EventMonitor:OnEvent(eventId, ...)
        end, EventMonitor)
    end)

    self.registryCallbackRegistered[eventId] = true
end

function EventMonitor:ImportEvents(text)
    local count = 0

    for line in text:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")

        if line ~= "" then
            local eventId = line:match("^event%s+Event[%.%s]+(.-)%s*%->") or
                            line:match("^event%s+Event[%.%s]+(.-)%s*$")

            if eventId then
                eventId = eventId:gsub("%s+", "")
                if eventId ~= "" then
                    self.selectedRegistryEvents[eventId] = true
                    self:Initialize()
                    self:RegisterRegistryEvent(eventId)
                    count = count + 1
                end
            else
                local plainEvent = line:match("^([A-Z][A-Z_]+[A-Z])%s*$")
                if plainEvent then
                    self.selectedEvents[plainEvent] = true
                    self:Initialize()
                    pcall(function() self.frame:RegisterEvent(plainEvent) end)
                    count = count + 1
                end
            end
        end
    end

    return count
end

function EventMonitor:FirehoseStart()
    self:Initialize()
    self.frame:RegisterAllEvents()
    self.firehose = true
    self.monitoring = true
    Addon:Print("Firehose mode ON - capturing ALL events")
    self:UpdateUI()
end

function EventMonitor:FirehoseStop()
    self.frame:UnregisterAllEvents()
    self.firehose = false
    self.allEventsRegistered = false
    self:RegisterAllPossibleEvents()
    for event in pairs(self.selectedEvents) do
        pcall(function() self.frame:RegisterEvent(event) end)
    end
    Addon:Print("Firehose mode OFF")
    self:UpdateUI()
end

function EventMonitor:FirehoseToggle()
    if self.firehose then
        self:FirehoseStop()
    else
        self:FirehoseStart()
    end
end

function EventMonitor:RegisterCommonEvents()
    local commonEvents = {
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGIN", "PLAYER_LOGOUT",
        "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_AURA",
        "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_LOCKED", "ITEM_UNLOCKED",
        "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY",
        "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_RAID", "CHAT_MSG_SYSTEM",
        "ADDON_LOADED", "VARIABLES_LOADED",
        "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE", "QUEST_REMOVED",
        "MERCHANT_SHOW", "MERCHANT_CLOSED",
        "MAIL_INBOX_UPDATE", "MAIL_SHOW", "MAIL_CLOSED",
        "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
        "LOOT_OPENED", "LOOT_CLOSED", "LOOT_READY",
        "TRADE_SHOW", "TRADE_CLOSED",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
        "TAXIMAP_OPENED", "TAXIMAP_CLOSED",
        "GOSSIP_SHOW", "GOSSIP_CLOSED",
        "TRANSMOGRIFY_OPEN", "TRANSMOGRIFY_CLOSE", "TRANSMOGRIFY_SUCCESS", "TRANSMOGRIFY_UPDATE",
        "VIEWED_TRANSMOG_OUTFIT_CHANGED", "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED",
        "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH", "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS",
        "TRANSMOG_SEARCH_UPDATED",
        "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED",
        "AUCTION_HOUSE_AUCTION_CREATED", "BLACK_MARKET_OPEN", "BLACK_MARKET_BID_RESULT",
        "CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG",
        "PLAYER_MONEY", "PLAYER_DEAD", "PLAYER_UNGHOST",
        "UPDATE_INVENTORY_DURABILITY",
        "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANK_UPDATE_MONEY",
        "TRADE_SHOW", "TRADE_ACCEPT_UPDATE", "TRADE_MONEY_CHANGED",
        "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED",
        "UI_INFO_MESSAGE",
        "TRAIT_CONFIG_COMMIT_FAILED", "TRAIT_COND_INFO_CHANGED", "TRAIT_CONFIG_CREATED",
        "TRAIT_CONFIG_DELETED", "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_CONFIG_UPDATED",
        "TRAIT_NODE_CHANGED", "TRAIT_NODE_CHANGED_PARTIAL", "TRAIT_NODE_ENTRY_UPDATED",
        "TRAIT_SUB_TREE_CHANGED", "TRAIT_SYSTEM_INTERACTION_STARTED", "TRAIT_SYSTEM_NPC_CLOSED",
        "TRAIT_TREE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRY_PURCHASE_TO_NODE_PARTIAL_SUCCESS",
        "ACTIVE_COMBAT_CONFIG_CHANGED", "SELECTED_LOADOUT_CHANGED", "SPECIALIZATION_CHANGE_CAST_FAILED",
        "STARTER_BUILD_ACTIVATION_FAILED", "TALENTS_INVOLUNTARILY_RESET",
        "PORTRAITS_UPDATED", "PLAYER_LEVEL_UP",
    }

    for _, event in ipairs(commonEvents) do
        self.selectedEvents[event] = true
    end
end

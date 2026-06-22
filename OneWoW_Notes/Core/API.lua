local _, ns = ...

-- Public, cross-addon read surface for the Notes hub. ns stays private.
OneWoW_Notes_API = {}

--- Returns an NPC note.
---@param npcID number
---@return table|nil npcData
function OneWoW_Notes_API.GetNPC(npcID)
    return ns.NPCs:GetNPC(npcID)
end

--- Adds or updates an NPC note.
---@param npcID number
---@param npcData table
---@return boolean saved
function OneWoW_Notes_API.AddOrUpdateNPC(npcID, npcData)
    npcID = tonumber(npcID)
    if not npcID then
        return false
    end

    local existing = ns.NPCs:GetNPC(npcID)
    if existing then
        for key, value in pairs(npcData) do
            if value ~= nil then
                existing[key] = value
            end
        end
        ns.NPCs:SaveNPC(npcID, existing)
    else
        ns.NPCs:AddNPC(npcID, npcData)
    end

    return true
end

--- Adds a new NPC note (fails if the NPC already exists).
---@param npcID number
---@param npcData table
---@return boolean saved
function OneWoW_Notes_API.AddNPC(npcID, npcData)
    npcID = tonumber(npcID)
    if not npcID or not ns.NPCs then
        return false
    end
    ns.NPCs:AddNPC(npcID, npcData)
    return true
end

--- Saves an existing NPC note.
---@param npcID number
---@param npcData table
---@return boolean saved
function OneWoW_Notes_API.SaveNPC(npcID, npcData)
    npcID = tonumber(npcID)
    if not npcID or not ns.NPCs then
        return false
    end
    ns.NPCs:SaveNPC(npcID, npcData)
    return true
end

--- Opens an NPC note, selecting it when the NPCs tab is ready.
---@param npcID number
---@return boolean opened
function OneWoW_Notes_API.OpenNPC(npcID)
    npcID = tonumber(npcID)
    if not npcID then
        return false
    end

    ns.pendingNPCSelect = npcID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "npcs")

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "npcs")
    if tabFrame and tabFrame.SelectNPC then
        tabFrame.SelectNPC(npcID)
        ns.pendingNPCSelect = nil
    end

    return true
end

--- Returns a player note.
---@param fullName string
---@return table|nil playerData
function OneWoW_Notes_API.GetPlayer(fullName)
    if not fullName or fullName == "" or not ns.Players then
        return nil
    end
    return ns.Players:GetPlayer(fullName)
end

--- Adds a new player note.
---@param fullName string
---@param playerData table
---@return boolean saved
function OneWoW_Notes_API.AddPlayer(fullName, playerData)
    if not fullName or fullName == "" or not ns.Players then
        return false
    end
    ns.Players:AddPlayer(fullName, playerData)
    return true
end

--- Saves an existing player note.
---@param fullName string
---@param playerData table
---@return boolean saved
function OneWoW_Notes_API.SavePlayer(fullName, playerData)
    if not fullName or fullName == "" or not ns.Players then
        return false
    end
    ns.Players:SavePlayer(fullName, playerData)
    return true
end

--- Opens a player note, selecting it when the Players tab is ready.
---@param fullName string
---@return boolean opened
function OneWoW_Notes_API.OpenPlayer(fullName)
    if not fullName or fullName == "" then
        return false
    end

    ns.pendingPlayerSelect = fullName
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "players")

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "players")
    if tabFrame and tabFrame.SelectPlayer then
        tabFrame.SelectPlayer(fullName)
        ns.pendingPlayerSelect = nil
    end

    return true
end

--- Returns an item note.
---@param itemID number
---@return table|nil itemData
function OneWoW_Notes_API.GetItem(itemID)
    return ns.Items:GetItem(itemID)
end

--- Adds or updates an item note.
---@param itemID number
---@param itemData table
---@return boolean saved
function OneWoW_Notes_API.AddOrUpdateItem(itemID, itemData)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local existing = ns.Items:GetItem(itemID)
    if existing then
        for key, value in pairs(itemData) do
            if value ~= nil then
                existing[key] = value
            end
        end
        ns.Items:SaveItem(itemID, existing)
    else
        ns.Items:AddItem(itemID, itemData)
    end

    return true
end

--- Opens an item note, selecting it when the Items tab is ready.
---@param itemID number
---@return boolean opened
function OneWoW_Notes_API.OpenItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    ns.pendingItemSelect = itemID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "items")

    if ns.UI.OpenNotesItem and ns.UI.OpenNotesItem(itemID) then
        ns.pendingItemSelect = nil
    end

    return true
end

--- Show or toggle the Notes module (hub or standalone).
function OneWoW_Notes_API.OpenNotes()
    if ns.SlashCommandHandler then
        ns:SlashCommandHandler()
    end
end

--- Hide the notes help panel when hub navigation changes.
function OneWoW_Notes_API.CloseHelpPanel()
    if ns.CloseHelpPanel then
        ns:CloseHelpPanel()
    end
end

--- Keybinding entry: opens Notes (no dedicated quick-note UI yet).
function OneWoW_Notes_API.QuickNote()
    OneWoW_Notes_API.OpenNotes()
end

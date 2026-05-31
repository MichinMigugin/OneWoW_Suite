local _, ns = ...

ns.Navigation = ns.Navigation or {}

local function NormalizeMapCoord(value)
    value = tonumber(value)
    if not value then return nil end
    if value > 1 then
        value = value / 100
    end
    return value
end

function ns.Navigation:OpenMapPin(mapID, x, y, label)
    mapID = tonumber(mapID)
    if not mapID or mapID == 0 then return false end

    x = NormalizeMapCoord(x)
    y = NormalizeMapCoord(y)

    if WorldMapFrame and not WorldMapFrame:IsShown() then
        ToggleWorldMap()
    end

    if WorldMapFrame and WorldMapFrame.SetMapID then
        WorldMapFrame:SetMapID(mapID)
    end

    if x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint then
        if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
            print("|cFFFFD100OneWoW:|r Cannot set a waypoint on this map.")
            return true
        end

        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))

        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end

        if label then
            print("|cFFFFD100OneWoW:|r Map pin set for " .. tostring(label) .. ".")
        end
    end

    return true
end

function ns.Navigation:OpenNPC(npcID, npcInfo)
    npcID = tonumber(npcID)
    if not npcID then return end

    local notes = _G.OneWoW_Notes
    if not notes then return end

    if notes.NPCs and notes.NPCs.EnsureNPC then
        notes.NPCs:EnsureNPC(npcID, npcInfo)
    end

    notes.pendingNPCSelect = npcID

    if _G.OneWoW and OneWoW.GUI and OneWoW.GUI.Show then
        OneWoW.GUI:Show("notes")

        if OneWoW.GUI.SelectSubTab then
            OneWoW.GUI:SelectSubTab("notes", "npcs")
        end

        if OneWoW.GUI.GetContentFrame then
            local tabFrame = OneWoW.GUI:GetContentFrame("notes", "npcs")
            if tabFrame and tabFrame.SelectNPC then
                tabFrame.SelectNPC(npcID)
                notes.pendingNPCSelect = nil
            end
        end

        return
    elseif notes.UI and notes.UI.Show then
        notes.UI:Show("npcs")
    end

    local frame = notes.mainFrame or notes.MainFrame or _G.OneWoW_NotesMainFrame
    if frame and frame.SelectNPC then
        frame.SelectNPC(npcID)
        notes.pendingNPCSelect = nil
    end
end

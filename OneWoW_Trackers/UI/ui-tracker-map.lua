local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

ns.TrackerMapUI = {}
local TMU = ns.TrackerMapUI

local format = format

local dialogCache = {}

local function CreateDialog(config)
    local dialogName = config.name or "OneWoW_TrackersMapDialog"
    local destroyOnClose = config.destroyOnClose
    local cached = dialogCache[dialogName]
    if destroyOnClose and cached then
        cached:Hide()
        cached:SetParent(nil)
        dialogCache[dialogName] = nil
        cached = nil
    end
    if cached then
        if cached:IsShown() then cached:Raise() return cached end
        cached:Show()
        cached:Raise()
        return cached
    end

    local result = OneWoW_GUI:CreateDialog({
        name = dialogName,
        title = config.title or "",
        width = config.width or 500,
        height = config.height or 400,
        showBrand = true,
        buttons = config.buttons,
        onClose = function()
            if destroyOnClose then
                dialogCache[dialogName] = nil
            end
        end,
    })

    local frame = result.frame
    frame.content = result.contentFrame
    dialogCache[dialogName] = frame
    frame:HookScript("OnShow", function(myself)
        C_Timer.After(0, function()
            OneWoW_GUI:ApplyFontToFrame(myself)
        end)
    end)
    frame:Hide()
    return frame
end

local initialized = false

function TMU:Initialize()
    if initialized then return end
    initialized = true

    local TM = ns.TrackerMap
    if not TM then return end

    if WorldMapFrame then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            TM:RefreshWorldMap()
        end)
    end

    TM:StartMinimapDriver()
end

function TMU:ShowWaypointList(listID)
    local TD = ns.TrackerData
    if not TD then return end

    local list = TD:GetList(listID)
    if not list then return end

    local waypoints = {}
    for _, sec in ipairs(list.sections) do
        for _, step in ipairs(sec.steps or {}) do
            if step.mapID and step.coordX and step.coordY then
                local completed = TD:IsStepComplete(listID, sec.key, step.key)
                tinsert(waypoints, {
                    label = step.label,
                    mapID = step.mapID,
                    x = step.coordX,
                    y = step.coordY,
                    completed = completed,
                    sectionLabel = sec.label,
                })
            end

            for _, obj in ipairs(step.objectives or {}) do
                if obj.type == "coordinates" and obj.params then
                    local completed = TD:GetObjectiveProgress(listID, sec.key, step.key, obj.key)
                    tinsert(waypoints, {
                        label = obj.description ~= "" and obj.description or step.label,
                        mapID = tonumber(obj.params.mapID),
                        x = tonumber(obj.params.x),
                        y = tonumber(obj.params.y),
                        completed = completed,
                        sectionLabel = sec.label,
                    })
                end
            end
        end
    end

    if #waypoints == 0 then
        print((L["ADDON_CHAT_PREFIX"]) .. " No waypoints found in this list.")
        return
    end

    local dialog = CreateDialog({
        name = "TrackerWaypointList",
        title = format("Waypoints: %s", list.title or ""),
        width = 400,
        height = 500,
        destroyOnClose = true,
        buttons = {
            { text = CLOSE, onClick = function(frame) frame:Hide(); frame:SetParent(nil) end },
        },
    })
    if not dialog then return end
    local content = dialog.content

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(content, {})
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -4, 4)

    local yOffset = 0
    local incomplete = 0
    local complete = 0

    for _, wp in ipairs(waypoints) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)
        row:SetHeight(24)

        local dot = OneWoW_GUI:CreateStatusDot(row, { size = 8, enabled = wp.completed })
        dot:SetPoint("LEFT", row, "LEFT", 4, 0)

        local label = OneWoW_GUI:CreateFS(row, 10)
        label:SetPoint("LEFT", dot, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -80, 0)
        label:SetJustifyH("LEFT")
        label:SetText(wp.label or "Waypoint")

        if wp.completed then
            label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            complete = complete + 1
        else
            label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            incomplete = incomplete + 1
        end

        local coordStr = format("%.1f, %.1f", wp.x or 0, wp.y or 0)
        local coordLabel = OneWoW_GUI:CreateFS(row, 10)
        coordLabel:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        coordLabel:SetText(coordStr)
        coordLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        yOffset = yOffset - 26
    end

    scrollChild:SetHeight(math.max(1, math.abs(yOffset)))

    local summaryLabel = OneWoW_GUI:CreateFS(content, 10)
    summaryLabel:SetPoint("BOTTOMLEFT", content, "TOPLEFT", 10, 4)
    summaryLabel:SetText(format("Complete: %d  |  Remaining: %d  |  Total: %d", complete, incomplete, #waypoints))
    summaryLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
end

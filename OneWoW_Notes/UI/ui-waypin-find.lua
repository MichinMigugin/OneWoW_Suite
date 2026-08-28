local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local C = OneWoW_GUI.Constants

-- ============================================================================
-- Find Location
-- ============================================================================
-- Search Catalog vendor NPCs (and Notes NPC records) in a named zone. Filter
-- tokens are AND-matched against name, type, roles, and subtitle. A leading
-- ! excludes. Catalog Vendors is loaded on demand; Notes NPCs still search
-- if that pack is off.
-- ============================================================================

ns.UI = ns.UI or {}

local MAX_RESULTS = 80
local ROW_H = 36

local dialog
local fields = {}
local resultRows = {}
local resultChild
local resultStatus

local function ParseTokens(text)
    local include, exclude = {}, {}
    if type(text) ~= "string" then
        return include, exclude
    end
    for token in text:gmatch("%S+") do
        token = token:gsub(",", "")
        if token ~= "" then
            if token:sub(1, 1) == "!" then
                local t = token:sub(2):lower()
                if t ~= "" then
                    tinsert(exclude, t)
                end
            else
                tinsert(include, token:lower())
            end
        end
    end
    return include, exclude
end

local function HayMatches(hay, include, exclude)
    for _, token in ipairs(include) do
        if not hay:find(token, 1, true) then
            return false
        end
    end
    for _, token in ipairs(exclude) do
        if hay:find(token, 1, true) then
            return false
        end
    end
    return true
end

local function BuildHay(name, subtitle, category, roles, zone, subzone, extra)
    local parts = {
        name or "",
        subtitle or "",
        category or "",
        zone or "",
        subzone or "",
        extra or "",
    }
    if type(roles) == "table" then
        for _, role in ipairs(roles) do
            tinsert(parts, tostring(role))
        end
    end
    return table.concat(parts, " "):lower()
end

local function ZoneHit(loc, mapID, needle, currentMapID)
    mapID = tonumber(mapID)
    if needle == "" then
        return mapID == currentMapID
    end
    if loc.zone and loc.zone:lower():find(needle, 1, true) then
        return true
    end
    if loc.subzone and loc.subzone:lower():find(needle, 1, true) then
        return true
    end
    local info = mapID and C_Map.GetMapInfo(mapID)
    if info and info.name and info.name:lower():find(needle, 1, true) then
        return true
    end
    if tonumber(needle) and tonumber(needle) == mapID then
        return true
    end
    return false
end

local function EnsureVendorsAPI()
    if OneWoW_CatalogData_Vendors_API and OneWoW_CatalogData_Vendors_API.GetAllVendors then
        return OneWoW_CatalogData_Vendors_API
    end
    OneWoW:BringUp("OneWoW_CatalogData_Vendors")
    if OneWoW_CatalogData_Vendors_API and OneWoW_CatalogData_Vendors_API.GetAllVendors then
        return OneWoW_CatalogData_Vendors_API
    end
    return nil
end

local function CollectResults(zoneText, filterText)
    local out = {}
    local seen = {}
    local currentMapID = Location.GetPlayerMapID()
    local zoneNeedle = (zoneText or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local include, exclude = ParseTokens(filterText)

    local api = EnsureVendorsAPI()
    if api then
        for npcID, vendor in pairs(api.GetAllVendors()) do
            if type(vendor) == "table" and vendor.locations then
                for mapID, loc in pairs(vendor.locations) do
                    if type(loc) == "table" and loc.x and loc.y and ZoneHit(loc, mapID, zoneNeedle, currentMapID) then
                        local extra = ""
                        if vendor.items and next(vendor.items) then
                            extra = extra .. " sells vendor"
                        end
                        local cat = vendor.category or ""
                        if cat:find("profession", 1, true) then
                            extra = extra .. " professions profession"
                        end
                        if cat == "repair" then
                            extra = extra .. " repair"
                        end
                        if cat == "banker" then
                            extra = extra .. " banker bank"
                        end
                        local hay = BuildHay(
                            vendor.name,
                            vendor.subtitle,
                            vendor.category,
                            vendor.roles,
                            loc.zone,
                            loc.subzone,
                            extra
                        )
                        if HayMatches(hay, include, exclude) then
                            local key = tostring(npcID) .. ":" .. tostring(mapID)
                            if not seen[key] then
                                seen[key] = true
                                tinsert(out, {
                                    title = vendor.name or tostring(npcID),
                                    sub = vendor.subtitle or vendor.category or "",
                                    mapID = tonumber(mapID),
                                    x = loc.x,
                                    y = loc.y,
                                    source = "catalog",
                                    sourceKey = npcID,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    for npcID, npc in pairs(ns.NPCs:GetAllNPCs()) do
        if type(npc) == "table" and npc.mapID and npc.coords then
            local loc = {
                zone = npc.zone,
                subzone = npc.subzone,
                x = npc.coords.x,
                y = npc.coords.y,
            }
            if loc.x and loc.y and ZoneHit(loc, npc.mapID, zoneNeedle, currentMapID) then
                local key = tostring(npcID) .. ":" .. tostring(npc.mapID)
                if not seen[key] then
                    local hay = BuildHay(npc.name, npc.category, npc.category, nil, npc.zone, npc.subzone, "npc")
                    if HayMatches(hay, include, exclude) then
                        seen[key] = true
                        tinsert(out, {
                            title = npc.name or tostring(npcID),
                            sub = npc.category or "",
                            mapID = tonumber(npc.mapID),
                            x = npc.coords.x,
                            y = npc.coords.y,
                            source = "npc",
                            sourceKey = npcID,
                        })
                    end
                end
            end
        end
    end

    sort(out, function(a, b)
        if a.title == b.title then
            return (a.mapID or 0) < (b.mapID or 0)
        end
        return a.title < b.title
    end)

    if #out > MAX_RESULTS then
        local trimmed = {}
        for i = 1, MAX_RESULTS do
            trimmed[i] = out[i]
        end
        return trimmed, api ~= nil, #out
    end
    return out, api ~= nil, #out
end

local function PaintResults(list, catalogOk, total)
    for _, row in ipairs(resultRows) do
        row:Hide()
    end
    local y = 0
    for i, hit in ipairs(list) do
        local row = resultRows[i]
        if not row then
            row = CreateFrame("Button", nil, resultChild, "BackdropTemplate")
            row:SetHeight(ROW_H)
            row:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)

            local title = OneWoW_GUI:CreateFS(row, 12)
            title:SetPoint("TOPLEFT", 8, -4)
            title:SetPoint("RIGHT", -88, 0)
            title:SetJustifyH("LEFT")
            title:SetWordWrap(false)
            row.title = title

            local sub = OneWoW_GUI:CreateFS(row, 10)
            sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
            sub:SetPoint("RIGHT", -88, 0)
            sub:SetJustifyH("LEFT")
            sub:SetWordWrap(false)
            row.sub = sub

            local goBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["WAYPINS_GO"], height = 22, minWidth = 36 })
            goBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            goBtn:SetScript("OnClick", function(myself)
                local data = myself:GetParent().hit
                if data then
                    Location.SetWaypoint(data.mapID, data.x, data.y, { format = "percent" })
                end
            end)
            row.goBtn = goBtn

            local addBtn = OneWoW_GUI:CreateFitTextButton(row, { text = ADD, height = 22, minWidth = 40 })
            addBtn:SetPoint("RIGHT", goBtn, "LEFT", -4, 0)
            addBtn:SetScript("OnClick", function(myself)
                local data = myself:GetParent().hit
                if not data then return end
                local pinID = ns.WayPins:Add({
                    title = data.title,
                    mapID = data.mapID,
                    x = data.x,
                    y = data.y,
                    source = data.source,
                    sourceKey = data.sourceKey,
                })
                local pin = pinID and ns.WayPins:GetPin(pinID)
                if pin then
                    ns.UI.OpenWayPinDialog(pin)
                end
            end)
            row.addBtn = addBtn

            resultRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", resultChild, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", resultChild, "TOPRIGHT", 0, -y)
        row.hit = hit
        row.title:SetText(hit.title)
        row.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        local zoneName = ns.WayPins:MapDisplayName(hit.mapID)
        local extra = hit.sub ~= "" and (hit.sub .. "  ") or ""
        row.sub:SetText(string.format("%s%s (%d)  %.1f, %.1f", extra, zoneName, hit.mapID or 0, hit.x or 0, hit.y or 0))
        row.sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row:Show()
        y = y + ROW_H + 2
    end
    resultChild:SetHeight(math.max(y, 1))

    if #list == 0 then
        if not catalogOk then
            resultStatus:SetText(L["WAYPINS_FIND_NEED_CATALOG"])
        else
            resultStatus:SetText(L["WAYPINS_FIND_EMPTY"])
        end
    else
        resultStatus:SetText(string.format(L["UI_COUNT_FORMAT"], L["WAYPINS_FIND_LOCATION"], total or #list))
    end
end

local function RunSearch()
    local zoneText = fields.zone:GetSearchText()
    local filterText = fields.filters:GetSearchText()
    local list, catalogOk, total = CollectResults(zoneText, filterText)
    PaintResults(list, catalogOk, total)
end

local function EnsureDialog()
    if dialog then return dialog end

    dialog = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_NotesWayPinFindDialog",
        title  = L["WAYPINS_FIND_LOCATION"],
        width  = 520,
        height = 520,
        buttons = {
            { text = SEARCH, onClick = function() RunSearch() end },
            { text = CANCEL, onClick = function(f) f:Hide() end },
        },
    })

    local content = dialog.contentFrame
    local y = -12

    local zoneLabel = OneWoW_GUI:CreateFS(content, 12)
    zoneLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    zoneLabel:SetText(ZONE)
    zoneLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - 18

    fields.zone = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = ZONE,
        maxLetters = 80,
    })
    fields.zone:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    fields.zone:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    y = y - 32

    local filterLabel = OneWoW_GUI:CreateFS(content, 12)
    filterLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    filterLabel:SetText(FILTERS)
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - 18

    fields.filters = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = L["WAYPINS_FIND_FILTERS_PH"],
        maxLetters = 120,
    })
    fields.filters:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    fields.filters:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    fields.filters:HookScript("OnEnterPressed", RunSearch)
    fields.zone:HookScript("OnEnterPressed", RunSearch)
    y = y - 32

    local hint = OneWoW_GUI:CreateFS(content, 10)
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L["WAYPINS_FIND_HINT"])
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    y = y - 32

    resultStatus = OneWoW_GUI:CreateFS(content, 11)
    resultStatus:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    resultStatus:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 20

    local scroll, child = OneWoW_GUI:CreateScrollFrame(content, {})
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 8)
    resultChild = child

    return dialog
end

function ns.UI.OpenWayPinFindDialog()
    EnsureDialog()
    local mapID = Location.GetPlayerMapID()
    local info = mapID and C_Map.GetMapInfo(mapID)
    fields.zone:SetText((info and info.name) or "")
    fields.filters:SetText("")
    RunSearch()
    dialog.frame:Show()
    dialog.frame:Raise()
end

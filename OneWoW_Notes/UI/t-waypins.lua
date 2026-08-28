local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local C = OneWoW_GUI.Constants

ns.UI = ns.UI or {}

local selectedID
local listRows = {}
local mapFilter = "current"
local storageFilter = "All"
local searchFilter = ""
local scrollChild
local emptyMessage
local leftStatusText
local detailWidgets = {}

local ROW_H = 38

local function MatchesFilters(pin)
    if storageFilter ~= "All" and pin.storage ~= storageFilter then
        return false
    end
    if mapFilter == "current" then
        local mapID = Location.GetPlayerMapID()
        if tonumber(pin.mapID) ~= mapID then
            return false
        end
    end
    if searchFilter ~= "" then
        local hay = (pin.title or "") .. " " .. ns.WayPins:MapDisplayName(pin.mapID)
        if not hay:lower():find(searchFilter, 1, true) then
            return false
        end
    end
    return true
end

local function FilteredList()
    local out = {}
    for _, pin in pairs(ns.WayPins:GetAll()) do
        if type(pin) == "table" and MatchesFilters(pin) then
            tinsert(out, pin)
        end
    end
    sort(out, function(a, b)
        local za = ns.WayPins:MapDisplayName(a.mapID)
        local zb = ns.WayPins:MapDisplayName(b.mapID)
        if za == zb then
            return (a.title or "") < (b.title or "")
        end
        return za < zb
    end)
    return out
end

local function HideDetail()
    emptyMessage:Show()
    for _, w in pairs(detailWidgets) do
        if w.Hide then w:Hide() end
    end
end

local function PaintDetail()
    local pin = selectedID and ns.WayPins:GetPin(selectedID)
    if not pin then
        HideDetail()
        return
    end
    emptyMessage:Hide()
    for _, w in pairs(detailWidgets) do
        if w.Show then w:Show() end
    end
    OneWoW.OverlayIcons:ApplyIconSpec(detailWidgets.icon, pin.icon)
    detailWidgets.title:SetText(pin.title or L["WAYPINS_UNTITLED"])
    detailWidgets.zone:SetText(string.format("%s (%d)", ns.WayPins:MapDisplayName(pin.mapID), pin.mapID))
    detailWidgets.coords:SetText(string.format("%.1f, %.1f", pin.x or 0, pin.y or 0))
    local stor = pin.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"]
    detailWidgets.storage:SetText(string.format(L["UI_STORAGE_WITH_VALUE"], stor))
end

function ns.UI.RefreshWayPinsTab()
    if not scrollChild then return end
    local list = FilteredList()
    for _, row in ipairs(listRows) do
        row:Hide()
    end
    local y = 0
    local soloID = ns.WayPinsMap and ns.WayPinsMap:GetSoloPinID()
    for i, pin in ipairs(list) do
        local row = listRows[i]
        if not row then
            row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetHeight(ROW_H)
            row:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(22, 22)
            icon:SetPoint("LEFT", 8, 0)
            row.icon = icon

            local goBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["WAYPINS_GO"], height = 22, minWidth = 36 })
            goBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            goBtn:SetScript("OnClick", function(myself)
                local id = myself:GetParent().pinID
                if id then
                    ns.WayPins:Track(id)
                end
            end)
            row.goBtn = goBtn

            local onlyBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["WAYPINS_ONLY_THIS"], height = 22, minWidth = 58 })
            onlyBtn:SetPoint("RIGHT", goBtn, "LEFT", -4, 0)
            onlyBtn:SetScript("OnClick", function(myself)
                local id = myself:GetParent().pinID
                if id and ns.WayPinsMap then
                    ns.WayPinsMap:ToggleSolo(id)
                end
            end)
            onlyBtn:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["WAYPINS_ONLY_THIS"], 1, 1, 1)
                GameTooltip:AddLine(L["WAYPINS_ONLY_THIS_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                GameTooltip:Show()
            end)
            onlyBtn:SetScript("OnLeave", GameTooltip_Hide)
            row.onlyBtn = onlyBtn

            local title = OneWoW_GUI:CreateFS(row, 12)
            title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 2)
            title:SetPoint("RIGHT", onlyBtn, "LEFT", -6, 0)
            title:SetJustifyH("LEFT")
            title:SetWordWrap(false)
            row.title = title

            local sub = OneWoW_GUI:CreateFS(row, 10)
            sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
            sub:SetPoint("RIGHT", onlyBtn, "LEFT", -6, 0)
            sub:SetJustifyH("LEFT")
            sub:SetWordWrap(false)
            row.sub = sub

            row:SetScript("OnClick", function(myself, button)
                selectedID = myself.pinID
                if button == "RightButton" then
                    local data = ns.WayPins:GetPin(myself.pinID)
                    MenuUtil.CreateContextMenu(myself, function(_, rootDescription)
                        rootDescription:CreateButton(L["WAYPINS_GO"], function()
                            ns.WayPins:Track(myself.pinID)
                        end)
                        rootDescription:CreateButton(EDIT, function()
                            ns.UI.OpenWayPinDialog(data)
                        end)
                        rootDescription:CreateButton(L["WAYPINS_ADD_TO_ZONE"], function()
                            ns.WayPins:AttachToZoneNotes(myself.pinID)
                        end)
                        if ns.WayPinsMap and ns.WayPinsMap:GetSoloPinID() == myself.pinID then
                            rootDescription:CreateButton(L["WAYPINS_SHOW_ALL"], function()
                                ns.WayPinsMap:ClearSolo()
                            end)
                        else
                            rootDescription:CreateButton(L["WAYPINS_ONLY_THIS"], function()
                                ns.WayPinsMap:ToggleSolo(myself.pinID)
                            end)
                        end
                        rootDescription:CreateButton(DELETE, function()
                            ns.WayPins:Remove(myself.pinID)
                            selectedID = nil
                            ns.UI.RefreshWayPinsTab()
                        end)
                    end)
                end
                ns.UI.RefreshWayPinsTab()
            end)
            listRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)
        row.pinID = pin.id
        row.title:SetText(pin.title or L["WAYPINS_UNTITLED"])
        row.sub:SetText(string.format("%s (%d)", ns.WayPins:MapDisplayName(pin.mapID), pin.mapID))
        OneWoW.OverlayIcons:ApplyIconSpec(row.icon, pin.icon)
        local selected = selectedID == pin.id
        if selected then
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            row.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            row.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        row.sub:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        if soloID == pin.id then
            row.onlyBtn:SetText(L["WAYPINS_SHOW_ALL"])
        else
            row.onlyBtn:SetText(L["WAYPINS_ONLY_THIS"])
        end
        row:Show()
        y = y + ROW_H + 2
    end
    scrollChild:SetHeight(math.max(y, 1))
    if leftStatusText then
        leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_WAYPINS"], #list))
    end
    PaintDetail()
end

function ns.UI.CreateWayPinsTab(parent)
    local panels = ns.UI.CreateSplitPanel(parent)

    local controlPanel = ns.UI.CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(45)

    panels.listPanel:ClearAllPoints()
    panels.listPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -6)
    panels.listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 28)
    panels.detailPanel:ClearAllPoints()
    panels.detailPanel:SetPoint("TOPLEFT", panels.listPanel, "TOPRIGHT", 10, 0)
    panels.detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 28)

    local addHereBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["WAYPINS_ADD_HERE"], height = 25 })
    addHereBtn:SetPoint("LEFT", controlPanel, "LEFT", 8, 0)
    addHereBtn:SetScript("OnClick", function()
        local mapID, x, y = Location.GetPlayerLocation()
        if not mapID or not x then
            return
        end
        ns.UI.OpenWayPinDialog({
            mapID  = mapID,
            x      = x,
            y      = y,
            source = "manual",
        })
    end)

    local findBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["WAYPINS_FIND_LOCATION"], height = 25 })
    findBtn:SetPoint("LEFT", addHereBtn, "RIGHT", 8, 0)
    findBtn:SetScript("OnClick", function()
        ns.UI.OpenWayPinFindDialog()
    end)

    local mapDD = ns.UI.CreateThemedDropdown(controlPanel, ZONE, 140, 25)
    mapDD:SetPoint("LEFT", findBtn, "RIGHT", 8, 0)
    mapDD:SetOptions({
        { text = L["WAYPINS_FILTER_CURRENT"], value = "current" },
        { text = ALL, value = "all" },
    })
    mapDD:SetSelected(mapFilter)
    mapDD.onSelect = function(value)
        mapFilter = value
        ns.UI.RefreshWayPinsTab()
    end

    local storeDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storeDD:SetPoint("LEFT", mapDD, "RIGHT", 8, 0)
    storeDD:SetOptions({
        { text = ALL, value = "All" },
        { text = L["UI_STORAGE_ACCOUNT"], value = "account" },
        { text = CHARACTER, value = "character" },
    })
    storeDD:SetSelected(storageFilter)
    storeDD.onSelect = function(value)
        storageFilter = value
        ns.UI.RefreshWayPinsTab()
    end

    local searchBox = OneWoW_GUI:CreateEditBox(controlPanel, {
        placeholderText = SEARCH,
        width = 160,
    })
    searchBox:SetPoint("RIGHT", controlPanel, "RIGHT", -8, 0)
    searchBox:HookScript("OnTextChanged", function(myself)
        searchFilter = (myself.GetSearchText and myself:GetSearchText() or myself:GetText()):lower()
        ns.UI.RefreshWayPinsTab()
    end)

    panels.listTitle:SetText(L["WAYPINS_LIST_TITLE"])
    scrollChild = panels.listScrollChild

    local leftStatusBar = ns.UI.CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT", panels.listPanel, "BOTTOMLEFT", 0, -4)
    leftStatusBar:SetPoint("TOPRIGHT", panels.listPanel, "BOTTOMRIGHT", 0, -4)
    leftStatusBar:SetHeight(24)
    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 11)
    leftStatusText:SetPoint("LEFT", 8, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    panels.detailTitle:SetText(L["WAYPINS_DETAIL_TITLE"])

    emptyMessage = OneWoW_GUI:CreateFS(panels.detailPanel, 12)
    emptyMessage:SetPoint("CENTER")
    emptyMessage:SetText(L["WAYPINS_SELECT"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local header = ns.UI.CreateDetailHeader(panels.detailPanel)
    detailWidgets.header = header

    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 10, 8)
    detailWidgets.icon = icon

    local title = OneWoW_GUI:CreateFS(header, 14)
    title:SetPoint("LEFT", icon, "RIGHT", 10, 8)
    title:SetPoint("RIGHT", header, "RIGHT", -10, 8)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    detailWidgets.title = title

    local goBtn = OneWoW_GUI:CreateFitTextButton(header, { text = L["WAYPINS_GO"], height = 24 })
    goBtn:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 8)
    goBtn:SetScript("OnClick", function()
        if selectedID then
            ns.WayPins:Track(selectedID)
        end
    end)
    detailWidgets.goBtn = goBtn

    local editBtn = OneWoW_GUI:CreateFitTextButton(header, { text = EDIT, height = 24 })
    editBtn:SetPoint("RIGHT", goBtn, "LEFT", -6, 0)
    editBtn:SetScript("OnClick", function()
        local pin = selectedID and ns.WayPins:GetPin(selectedID)
        if pin then
            ns.UI.OpenWayPinDialog(pin)
        end
    end)
    detailWidgets.editBtn = editBtn

    local zoneBtn = OneWoW_GUI:CreateFitTextButton(header, { text = L["WAYPINS_ADD_TO_ZONE"], height = 24 })
    zoneBtn:SetPoint("RIGHT", editBtn, "LEFT", -6, 0)
    zoneBtn:SetScript("OnClick", function()
        if selectedID then
            ns.WayPins:AttachToZoneNotes(selectedID)
        end
    end)
    detailWidgets.zoneBtn = zoneBtn

    local delBtn = OneWoW_GUI:CreateFitTextButton(header, { text = DELETE, height = 24 })
    delBtn:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 10, 8)
    delBtn:SetScript("OnClick", function()
        if not selectedID then return end
        ns.WayPins:Remove(selectedID)
        selectedID = nil
        ns.UI.RefreshWayPinsTab()
    end)
    detailWidgets.delBtn = delBtn

    local infoBar = ns.UI.CreateThemedBar(nil, panels.detailPanel)
    infoBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    infoBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -8)
    infoBar:SetHeight(72)
    detailWidgets.infoBar = infoBar

    local zone = OneWoW_GUI:CreateFS(infoBar, 12)
    zone:SetPoint("TOPLEFT", 12, -10)
    zone:SetPoint("RIGHT", -12, 0)
    zone:SetJustifyH("LEFT")
    zone:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    detailWidgets.zone = zone

    local coords = OneWoW_GUI:CreateFS(infoBar, 11)
    coords:SetPoint("TOPLEFT", zone, "BOTTOMLEFT", 0, -6)
    coords:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    detailWidgets.coords = coords

    local storageFS = OneWoW_GUI:CreateFS(infoBar, 11)
    storageFS:SetPoint("TOPLEFT", coords, "BOTTOMLEFT", 0, -4)
    storageFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    detailWidgets.storage = storageFS

    parent:HookScript("OnShow", function()
        ns.UI.RefreshWayPinsTab()
    end)

    ns.UI.RefreshWayPinsTab()
end

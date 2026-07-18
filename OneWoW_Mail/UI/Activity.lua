local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.ActivityUI = {}
local ActivityUI = ns.ActivityUI

local panel
local pendingScroll, pendingChild
local logScroll, logChild
local processBtn, discardBtn, clearBtn
-- Line pools: WoW never garbage-collects regions, and both lists re-render on
-- every queue event, so recreating FontStrings each refresh would leak.
local pendingLines = {}
local logLines = {}

local HEADER_H = 30
local PENDING_H = 170
local SECTION_GAP = 14
local LINE_H = 16
local SCROLLBAR_W = 24

local SEVERITY_COLOR = {
    error = "TEXT_FEATURES_DISABLED",
    warn = "TEXT_WARNING",
    info = "TEXT_SECONDARY",
}

local function AttachTooltip(frame, title, body)
    frame:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function SetWidgetEnabled(widget, on)
    if on then
        widget:Enable()
        widget:SetAlpha(1)
    else
        widget:Disable()
        widget:SetAlpha(0.45)
    end
end

local function ResetPool(pool)
    for _, fs in ipairs(pool) do
        fs:Hide()
        fs:ClearAllPoints()
    end
end

local function AcquireLine(pool, parent)
    for _, fs in ipairs(pool) do
        if not fs:IsShown() then
            fs:Show()
            return fs
        end
    end
    local fs = OneWoW_GUI:CreateFS(parent, 11)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    tinsert(pool, fs)
    return fs
end

local function PlaceLine(pool, parent, y, indent)
    local fs = AcquireLine(pool, parent)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", indent or 0, -y)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
    return fs
end

local function SyncChildWidth(scroll, child)
    child:SetWidth(math.max(100, scroll:GetWidth() or 600))
end

local function RefreshPending()
    ResetPool(pendingLines)
    SyncChildWidth(pendingScroll, pendingChild)
    local intents = ns.AutoRun:GetPendingIntents()
    local y = 0
    if #intents == 0 then
        local fs = PlaceLine(pendingLines, pendingChild, y)
        fs:SetText(L["ACTIVITY_EMPTY"])
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        y = y + LINE_H
    else
        local lastShipment
        for _, intent in ipairs(intents) do
            if intent.shipmentId ~= lastShipment then
                lastShipment = intent.shipmentId
                if y > 0 then
                    y = y + 4
                end
                local fs = PlaceLine(pendingLines, pendingChild, y)
                fs:SetText(intent.shipmentName .. " → " .. (intent.target or "?"))
                fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                y = y + LINE_H + 2
            end
            local fs = PlaceLine(pendingLines, pendingChild, y, 12)
            local name = intent.link or C_Item.GetItemNameByID(intent.itemID) or tostring(intent.itemID)
            fs:SetText(name .. " ×" .. intent.quantity)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            y = y + LINE_H
        end
    end
    pendingChild:SetHeight(math.max(1, y))

    local canAct = #intents > 0
    SetWidgetEnabled(processBtn, canAct and not ns.SendQueue:IsRunning() and not ns.AutoRun:IsProcessing())
    SetWidgetEnabled(discardBtn, canAct)
end

local function RefreshLog()
    ResetPool(logLines)
    SyncChildWidth(logScroll, logChild)
    local entries = ns.RunLog:GetAll()
    local y = 0
    if #entries == 0 then
        local fs = PlaceLine(logLines, logChild, y)
        fs:SetText(L["ACTIVITY_LOG_EMPTY"])
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        y = y + LINE_H
    else
        for i = #entries, 1, -1 do -- newest first
            local e = entries[i]
            local context = ""
            if e.shipmentName and e.shipmentName ~= "" then
                context = e.shipmentName
                if e.target and e.target ~= "" then
                    context = context .. " → " .. e.target
                end
                context = context .. ": "
            elseif e.target and e.target ~= "" then
                context = e.target .. ": "
            end
            local fs = PlaceLine(logLines, logChild, y)
            fs:SetText(date("%H:%M ", e.time) .. context .. e.message)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor(SEVERITY_COLOR[e.severity] or "TEXT_SECONDARY"))
            y = y + LINE_H
        end
    end
    logChild:SetHeight(math.max(1, y))
    SetWidgetEnabled(clearBtn, #entries > 0)
end

function ActivityUI:Refresh()
    if not panel then
        return
    end
    RefreshPending()
    RefreshLog()
end

function ActivityUI:Reset()
    panel = nil
    pendingScroll, pendingChild = nil, nil
    logScroll, logChild = nil, nil
    processBtn, discardBtn, clearBtn = nil, nil, nil
    wipe(pendingLines)
    wipe(logLines)
end

local function CreateSectionScroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    OneWoW_GUI:ApplyScrollBarStyle(scroll.ScrollBar, scroll, -2)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    return scroll, child
end

function ActivityUI:Create(parent)
    panel = parent

    local pendingHeader = OneWoW_GUI:CreateFS(parent, 13)
    pendingHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -6)
    pendingHeader:SetText(L["ACTIVITY_PENDING_HEADER"])
    pendingHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    discardBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["DISCARD"], height = 24 })
    discardBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SCROLLBAR_W, 0)
    discardBtn:SetScript("OnClick", function()
        ns.AutoRun:Discard()
    end)
    AttachTooltip(discardBtn, L["DISCARD"], L["TT_BTN_DISCARD"])

    processBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["BTN_PROCESS"], height = 24 })
    processBtn:SetPoint("RIGHT", discardBtn, "LEFT", -6, 0)
    processBtn:SetScript("OnClick", function()
        ns.AutoRun:Process()
    end)
    AttachTooltip(processBtn, L["BTN_PROCESS"], L["TT_BTN_PROCESS"])

    pendingScroll, pendingChild = CreateSectionScroll(parent)
    pendingScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -HEADER_H)
    pendingScroll:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SCROLLBAR_W, -HEADER_H)
    pendingScroll:SetHeight(PENDING_H)

    local logHeader = OneWoW_GUI:CreateFS(parent, 13)
    logHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(HEADER_H + PENDING_H + SECTION_GAP + 6))
    logHeader:SetText(L["ACTIVITY_LOG_HEADER"])
    logHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    clearBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = CLEAR_ALL, height = 24 })
    clearBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SCROLLBAR_W, -(HEADER_H + PENDING_H + SECTION_GAP))
    clearBtn:SetScript("OnClick", function()
        ns.RunLog:Clear()
    end)

    logScroll, logChild = CreateSectionScroll(parent)
    logScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(HEADER_H + PENDING_H + SECTION_GAP + HEADER_H))
    logScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -SCROLLBAR_W, 0)

    ns.RunLog:SetOnChanged(function()
        ActivityUI:Refresh()
    end)
end

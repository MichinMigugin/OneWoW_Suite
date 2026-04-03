local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = ns.L
local Constants = OneWoW_GUI.Constants

ns.UI = ns.UI or {}
local UI = ns.UI

local mainFrame

local function GetDB()
    local addon = _G.OneWoW_Trackers
    if not addon or not addon.db then return nil end
    return addon.db
end

local function SavePosition()
    local db = GetDB()
    if not db or not mainFrame then return end
    local point, _, relativePoint, xOfs, yOfs = mainFrame:GetPoint()
    db.global.mainFramePosition = { point = point, relativePoint = relativePoint, x = xOfs, y = yOfs }
end

local function SaveSize()
    local db = GetDB()
    if not db or not mainFrame then return end
    db.global.mainFrameSize = { width = mainFrame:GetWidth(), height = mainFrame:GetHeight() }
end

local function RestorePosition()
    local db = GetDB()
    if not db or not mainFrame then return end
    local sz = db.global.mainFrameSize
    if sz and sz.width and sz.height then
        mainFrame:SetSize(sz.width, sz.height)
    end
    local pos = db.global.mainFramePosition
    if pos and pos.point then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER")
    end
end

function UI:Create()
    if mainFrame then return end

    mainFrame = OneWoW_GUI:CreateFrame(UIParent, {
        name    = "OneWoW_Trackers_MainFrame",
        width   = 1400,
        height  = 900,
        backdrop = Constants.BACKDROP_SOFT,
    })
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetToplevel(true)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:SetResizeBounds(900, 600, 1800, 1200)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    tinsert(UISpecialFrames, "OneWoW_Trackers_MainFrame")

    local titleBar = OneWoW_GUI:CreateTitleBar(mainFrame, {
        title = L["ADDON_TITLE_FRAME"] or "OneWoW Trackers",
        showBrand = true,
        onClose = function() mainFrame:Hide() end,
    })
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        SavePosition()
    end)

    local resizeBtn = CreateFrame("Button", nil, mainFrame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:RegisterForDrag("LeftButton")
    resizeBtn:SetScript("OnDragStart", function() mainFrame:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        SavePosition()
        SaveSize()
    end)

    local SM = OneWoW_GUI:GetSpacing("SM")

    local tabButtonContainer = CreateFrame("Frame", nil, mainFrame)
    tabButtonContainer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", SM, -SM)
    tabButtonContainer:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -SM, -SM)
    tabButtonContainer:SetHeight(28)

    local tabContainer = CreateFrame("Frame", nil, mainFrame)
    tabContainer:SetPoint("TOPLEFT", tabButtonContainer, "BOTTOMLEFT", 0, -SM)
    tabContainer:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -SM, 20)

    local trackerContent = CreateFrame("Frame", nil, tabContainer)
    trackerContent:SetAllPoints(tabContainer)

    local settingsContent = CreateFrame("Frame", nil, tabContainer)
    settingsContent:SetAllPoints(tabContainer)
    settingsContent:Hide()

    local tabButtons = {}
    local tabFrames  = { tracker = trackerContent, settings = settingsContent }

    local function SelectTab(name)
        for n, frame in pairs(tabFrames) do
            frame:SetShown(n == name)
        end
        for n, btn in pairs(tabButtons) do
            if n == name then
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            else
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end
    end

    local tabDefs = {
        { name = "tracker",  label = L["TAB_TRACKER"]  or "Tracker"  },
        { name = "settings", label = L["TAB_SETTINGS"] or "Settings" },
    }

    local prevBtn
    for _, def in ipairs(tabDefs) do
        local btn = OneWoW_GUI:CreateButton(tabButtonContainer, { text = def.label, height = 28 })
        btn:SetWidth(120)
        if not prevBtn then
            btn:SetPoint("TOPLEFT", tabButtonContainer, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", prevBtn, "TOPRIGHT", SM, 0)
        end
        btn:SetScript("OnClick", function() SelectTab(def.name) end)
        btn:SetScript("OnEnter", function(self)
            if not tabFrames[def.name]:IsShown() then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not tabFrames[def.name]:IsShown() then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            end
        end)
        tabButtons[def.name] = btn
        prevBtn = btn
    end

    ns.UI.CreateTrackerTab(trackerContent)
    OneWoW_GUI:CreateSettingsPanel(settingsContent, { addonName = "OneWoW_Trackers" })

    SelectTab("tracker")

    mainFrame:SetScript("OnHide", function()
        SavePosition()
    end)

    RestorePosition()
    mainFrame:Hide()
end

function UI:Show()
    if not mainFrame then self:Create() end
    mainFrame:Show()
end

function UI:Hide()
    if mainFrame then mainFrame:Hide() end
end

function UI:Toggle()
    if not mainFrame then
        self:Create()
        mainFrame:Show()
    elseif mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

function UI:IsShown()
    return mainFrame and mainFrame:IsShown() or false
end

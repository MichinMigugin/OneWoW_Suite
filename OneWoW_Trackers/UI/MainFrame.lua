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

local function RestorePosition()
    local db = GetDB()
    if not db or not mainFrame then return end
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

    mainFrame = CreateFrame("Frame", "OneWoW_Trackers_MainFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(1400, 900)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetToplevel(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    if Constants and Constants.BACKDROP_SOFT then
        mainFrame:SetBackdrop(Constants.BACKDROP_SOFT)
        local r, g, b = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
        if r then mainFrame:SetBackdropColor(r, g, b, 1) end
        local br, bg, bb = OneWoW_GUI:GetThemeColor("BORDER")
        if br then mainFrame:SetBackdropBorderColor(br, bg, bb, 1) end
    end

    tinsert(UISpecialFrames, "OneWoW_Trackers_MainFrame")

    local titleBar = OneWoW_GUI:CreateTitleBar(mainFrame, {
        title = L["ADDON_TITLE_FRAME"] or "OneWoW Trackers",
        showBrand = true,
        onClose = function() mainFrame:Hide() end,
    })

    local contentFrame = CreateFrame("Frame", nil, mainFrame)
    contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -35)
    contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)

    ns.UI.CreateTrackerTab(contentFrame)

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
